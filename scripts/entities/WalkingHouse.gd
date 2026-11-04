# scripts/entities/WalkingHouse.gd
class_name WalkingHouse
extends CharacterBody2D

## Master Locomotion & Visual Entity Controller for «Шагающий дом».
## Integrates 2-bone IK legs, stance/swing stepping gait, procedural vector drawing,
## dynamic PointLight2D illumination, CPUParticles2D smoke, procedural hull sway,
## input controls (A/D & arrows), and exit lockout when moving.

const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const HouseLegs = preload("res://scripts/entities/HouseLegs.gd")
const SnowTracks = preload("res://scripts/world/SnowTracks.gd")

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------
@onready var leg_back: HouseLegs = get_node_or_null("Leg_Back")
@onready var leg_front: HouseLegs = get_node_or_null("Leg_Front")
@onready var cabin_pivot: Node2D = get_node_or_null("CabinPivot")
@onready var window_light_main: PointLight2D = get_node_or_null("CabinPivot/WindowLightMain")
@onready var window_light_porthole: PointLight2D = get_node_or_null("CabinPivot/WindowLightPorthole")
@onready var hearth_light: PointLight2D = get_node_or_null("CabinPivot/HearthLight")
@onready var ladder_light: PointLight2D = get_node_or_null("CabinPivot/LadderWorkLight")
@onready var chimney_smoke: CPUParticles2D = get_node_or_null("CabinPivot/ChimneySmoke")

# ------------------------------------------------------------------------------
# LOCOMOTION & KINEMATIC STATE
# ------------------------------------------------------------------------------
var current_speed: float = 0.0 # signed m/s (+ forward, - reverse)
var target_speed: float = 0.0  # signed m/s
var prev_speed: float = 0.0
var gait_phase: float = 0.0    # radians [0, 2*PI)
var is_house_moving: bool = false

# Hull sway constants
const SWAY_HEAVE_AMP: float = 4.5    # px
const SWAY_PITCH_AMP: float = 0.035  # radians (~2.0 deg)
const ACCEL_INERTIA_K: float = 0.012

# Visual & lighting state
var window_glow_alpha: float = 0.0
var flame_timer: float = 0.0
var stove_active: bool = false
var cabin_temp: float = 18.0

# ------------------------------------------------------------------------------
# COLOR PALETTE SPECIFICATION (Zero external textures)
# ------------------------------------------------------------------------------
const C_WOOD_BASE := Color(0.24, 0.20, 0.17, 1.0)
const C_WOOD_SEAM := Color(0.12, 0.10, 0.08, 0.95)
const C_WOOD_HIGHLIGHT := Color(0.33, 0.28, 0.23, 0.6)
const C_WOOD_GRAIN := Color(0.18, 0.15, 0.12, 0.35)
const C_POST_DARK := Color(0.20, 0.17, 0.14, 1.0)

const C_IRON_BASE := Color(0.18, 0.20, 0.23, 1.0)
const C_IRON_HIGHLIGHT := Color(0.35, 0.40, 0.46, 0.9)
const C_IRON_SHADOW := Color(0.10, 0.11, 0.13, 1.0)
const C_RIVET_DOME := Color(0.44, 0.48, 0.52, 1.0)
const C_RIVET_SHADOW := Color(0.08, 0.09, 0.10, 1.0)
const C_RIVET_GLINT := Color(0.85, 0.88, 0.92, 1.0)

const C_ROOF_SURFACE := Color(0.17, 0.19, 0.22, 1.0)
const C_ROOF_FASCIA := Color(0.15, 0.16, 0.18, 1.0)
const C_SNOW_FILL := Color(0.92, 0.95, 0.98, 1.0)
const C_SNOW_TOP := Color(1.0, 1.0, 1.0, 1.0)
const C_ICICLE := Color(0.80, 0.90, 1.0, 0.75)

const C_WINDOW_FRAME := Color(0.14, 0.12, 0.10, 1.0)
const C_GLASS_COLD := Color(0.18, 0.26, 0.32, 0.95)
const C_GLASS_FROST := Color(0.80, 0.90, 1.0, 0.45)
const C_GLASS_WARM := Color(1.0, 0.82, 0.38, 0.95)
const C_GLASS_CORE := Color(1.0, 0.94, 0.65, 1.0)

const C_LADDER_RAIL := Color(0.20, 0.22, 0.25, 1.0)
const C_LADDER_RUNG := Color(0.32, 0.36, 0.40, 1.0)
const C_LADDER_RUNG_HI := Color(0.55, 0.62, 0.70, 0.9)

# ------------------------------------------------------------------------------
# INITIALIZATION
# ------------------------------------------------------------------------------
func _ready() -> void:
	_ensure_child_nodes()
	_setup_legs()
	_setup_lighting()
	_setup_chimney_smoke()
	_connect_event_bus()
	
	var gs: Node = _get_game_state()
	if gs != null:
		stove_active = gs.is_stove_on
		cabin_temp = gs.cabin_temperature
		position.x = gs.distance_traveled * BalanceConfig.METERS_TO_PIXELS

func _ensure_child_nodes() -> void:
	if cabin_pivot == null:
		cabin_pivot = Node2D.new()
		cabin_pivot.name = "CabinPivot"
		add_child(cabin_pivot)
		
	if leg_back == null:
		var back_node := get_node_or_null("Leg_Back")
		if back_node is HouseLegs:
			leg_back = back_node
		else:
			leg_back = HouseLegs.new()
			leg_back.name = "Leg_Back"
			leg_back.z_index = -1
			add_child(leg_back)
			
	if leg_front == null:
		var front_node := get_node_or_null("Leg_Front")
		if front_node is HouseLegs:
			leg_front = front_node
		else:
			leg_front = HouseLegs.new()
			leg_front.name = "Leg_Front"
			leg_front.z_index = 1
			add_child(leg_front)

	var ladder_area := get_node_or_null("LadderArea")
	if ladder_area == null:
		ladder_area = Area2D.new()
		ladder_area.name = "LadderArea"
		ladder_area.add_to_group("house_ladder")
		ladder_area.collision_layer = 8
		ladder_area.collision_mask = 4
		var c_shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(50.0, 80.0)
		c_shape.shape = rect
		c_shape.position = Vector2(-60.0, 115.0)
		ladder_area.add_child(c_shape)
		add_child(ladder_area)

func _setup_legs() -> void:
	if leg_back != null:
		leg_back.leg_id = "back"
		leg_back.phase_offset = 0.0
		leg_back.is_foreground = false
		leg_back.hip_offset = Vector2(-49.0, 13.0)
		if not leg_back.footstep_impact.is_connected(_on_footstep_impact):
			leg_back.footstep_impact.connect(_on_footstep_impact)
			
	if leg_front != null:
		leg_front.leg_id = "front"
		leg_front.phase_offset = PI
		leg_front.is_foreground = true
		leg_front.hip_offset = Vector2(49.0, 13.0)
		if not leg_front.footstep_impact.is_connected(_on_footstep_impact):
			leg_front.footstep_impact.connect(_on_footstep_impact)

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
		
	if bus.has_signal("stove_toggled"):
		bus.connect("stove_toggled", Callable(self, "_on_stove_toggled"))
	if bus.has_signal("cabin_temperature_changed"):
		bus.connect("cabin_temperature_changed", Callable(self, "_on_cabin_temperature_changed"))

var game_state: Node = null
var event_bus: Node = null
var sound_manager: Node = null

func _get_game_state() -> Node:
	if game_state != null:
		return game_state
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("GameState"):
		return loop.root.get_node("GameState")
	return null

func _get_event_bus() -> Node:
	if event_bus != null:
		return event_bus
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("EventBus"):
		return loop.root.get_node("EventBus")
	return null

func _get_sound_manager() -> Node:
	if sound_manager != null:
		return sound_manager
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("SoundManager"):
		return loop.root.get_node("SoundManager")
	return null

# ------------------------------------------------------------------------------
# LIGHTING & TEXTURE SYNTHESIS
# ------------------------------------------------------------------------------
static func create_radial_gradient_texture(radius: int, inner: Color, mid: Color, outer: Color = Color(0, 0, 0, 0)) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.40, 1.0])
	grad.colors = PackedColorArray([inner, mid, outer])
	
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = radius * 2
	tex.height = radius * 2
	return tex

func _setup_lighting() -> void:
	if cabin_pivot == null:
		return
		
	if window_light_main == null:
		window_light_main = PointLight2D.new()
		window_light_main.name = "WindowLightMain"
		cabin_pivot.add_child(window_light_main)
	window_light_main.position = Vector2(22, -60)
	window_light_main.color = Color(1.0, 0.82, 0.42, 1.0)
	window_light_main.texture = create_radial_gradient_texture(
		160,
		Color(1.0, 0.90, 0.60, 1.0),
		Color(0.95, 0.60, 0.15, 0.5),
		Color(0.80, 0.30, 0.05, 0.0)
	)
	
	if window_light_porthole == null:
		window_light_porthole = PointLight2D.new()
		window_light_porthole.name = "WindowLightPorthole"
		cabin_pivot.add_child(window_light_porthole)
	window_light_porthole.position = Vector2(-40, -65)
	window_light_porthole.color = Color(1.0, 0.78, 0.38, 1.0)
	window_light_porthole.texture = create_radial_gradient_texture(
		80,
		Color(1.0, 0.85, 0.50, 0.9),
		Color(0.90, 0.50, 0.10, 0.4),
		Color(0.70, 0.20, 0.0, 0.0)
	)
	
	if hearth_light == null:
		hearth_light = PointLight2D.new()
		hearth_light.name = "HearthLight"
		cabin_pivot.add_child(hearth_light)
	hearth_light.position = Vector2(25, -50)
	hearth_light.color = Color(1.0, 0.55, 0.15, 1.0)
	hearth_light.texture = create_radial_gradient_texture(
		120,
		Color(1.0, 0.70, 0.20, 1.0),
		Color(0.95, 0.40, 0.05, 0.6),
		Color(0.60, 0.15, 0.0, 0.0)
	)
	
	if ladder_light == null:
		ladder_light = PointLight2D.new()
		ladder_light.name = "LadderWorkLight"
		cabin_pivot.add_child(ladder_light)
	ladder_light.position = Vector2(-60, -2)
	ladder_light.color = Color(0.95, 0.90, 0.70, 0.8)
	ladder_light.texture = create_radial_gradient_texture(
		70,
		Color(1.0, 0.95, 0.75, 0.8),
		Color(0.85, 0.75, 0.45, 0.3),
		Color(0.5, 0.4, 0.2, 0.0)
	)

func _setup_chimney_smoke() -> void:
	if cabin_pivot == null:
		return
		
	if chimney_smoke == null:
		chimney_smoke = CPUParticles2D.new()
		chimney_smoke.name = "ChimneySmoke"
		cabin_pivot.add_child(chimney_smoke)
		
	chimney_smoke.position = Vector2(46, -180)
	chimney_smoke.emitting = false
	chimney_smoke.amount = 32
	chimney_smoke.lifetime = 3.2
	chimney_smoke.preprocess = 1.0
	chimney_smoke.explosiveness = 0.0
	chimney_smoke.randomness = 0.35
	chimney_smoke.draw_order = CPUParticles2D.DRAW_ORDER_INDEX
	chimney_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chimney_smoke.emission_rect_extents = Vector2(3, 1)
	chimney_smoke.direction = Vector2(0, -1)
	chimney_smoke.spread = 18.0
	chimney_smoke.initial_velocity_min = 35.0
	chimney_smoke.initial_velocity_max = 55.0
	chimney_smoke.damping_min = 5.0
	chimney_smoke.damping_max = 9.0
	chimney_smoke.gravity = Vector2(-20.0, -28.0)
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.3, 1.2))
	curve.add_point(Vector2(1.0, 2.8))
	chimney_smoke.scale_amount_curve = curve
	chimney_smoke.scale_amount_min = 4.0
	chimney_smoke.scale_amount_max = 8.0
	
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.60, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.85, 0.85, 0.88, 0.0),
		Color(0.80, 0.82, 0.85, 0.65),
		Color(0.65, 0.68, 0.72, 0.40),
		Color(0.50, 0.55, 0.60, 0.0)
	])
	chimney_smoke.color_ramp = ramp

# ------------------------------------------------------------------------------
# INPUT & EXIT LOCKOUT PROCESSING
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var gs: Node = _get_game_state()
		if gs != null and gs.is_player_outside:
			return
		_handle_disembark_request()

func _handle_disembark_request() -> bool:
	var gs: Node = _get_game_state()
	var bus: Node = _get_event_bus()
	var sm: Node = _get_sound_manager()
	
	if gs == null:
		return false
		
	# Exit Lockout Check: Cannot disembark while moving ($V > 0$)
	if is_house_moving or absf(current_speed) > 0.05:
		if bus != null and bus.has_signal("prompt_requested"):
			bus.emit_signal("prompt_requested", "Нельзя покинуть дом на ходу! Полностью остановите машину.")
		if sm != null:
			sm.play_sfx("error")
		return false
		
	# House is stationary: ensure GameState reflects stopped state
	gs.set_house_moving(false)
	gs.set_house_speed(0.0)
	
	if gs.is_player_outside:
		return gs.embark_player()
	else:
		return gs.disembark_player()

# ------------------------------------------------------------------------------
# PHYSICS LOOP & CONTINUOUS STATE COUPLING
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
		
	_process_locomotion(delta)
	_update_lighting_and_particles(delta)
	_update_gait_and_legs(delta)
	_update_hull_sway(delta)
	queue_redraw()

func _process_locomotion(delta: float) -> void:
	var gs: Node = _get_game_state()
	var sm: Node = _get_sound_manager()
	
	var fuel: float = gs.fuel if gs != null else 100.0
	var durability: float = gs.leg_durability if gs != null else 100.0
	var max_durability: float = gs.max_leg_durability if gs != null else 100.0
	var is_outside: bool = gs.is_player_outside if gs != null else false
	var is_dead: bool = gs.is_game_over if gs != null else false
	var is_won: bool = gs.is_victory if gs != null else false
	
	# Early guard: Lock out movement if dead, won, player outside, or resources empty
	if is_dead or is_won or is_outside or fuel <= 0.0 or durability <= 0.0:
		target_speed = 0.0
	else:
		var input_axis: float = Input.get_axis("move_left", "move_right")
		var base_fwd: float = BalanceConfig.BASE_FORWARD_SPEED
		if gs != null and gs.has_legs_upgrade():
			base_fwd *= 1.15 # Reinforced legs 15% speed boost
		var base_rev: float = BalanceConfig.BASE_REVERSE_SPEED
		
		var max_fwd: float = SimulationLogic.calculate_speed(base_fwd, durability, max_durability)
		var max_rev: float = SimulationLogic.calculate_speed(base_rev, durability, max_durability)
		
		if input_axis > 0.05:
			target_speed = input_axis * max_fwd
		elif input_axis < -0.05:
			target_speed = input_axis * max_rev
		else:
			target_speed = 0.0
			
	# Smooth acceleration / deceleration
	prev_speed = current_speed
	var accel: float = BalanceConfig.HOUSE_ACCELERATION
	if is_zero_approx(target_speed) or (target_speed * current_speed < 0.0):
		accel = 3.5 # Slightly snappier braking
		
	current_speed = move_toward(current_speed, target_speed, accel * delta)
	if absf(current_speed) < 0.005:
		current_speed = 0.0
		
	is_house_moving = absf(current_speed) > 0.05
	
	if gs != null:
		gs.set_house_moving(is_house_moving)
		gs.set_house_speed(absf(current_speed))
		
	# Continuous state coupling
	if is_house_moving and gs != null:
		var delta_meters: float = current_speed * delta
		gs.add_distance(delta_meters)
		
		position.x += delta_meters * BalanceConfig.METERS_TO_PIXELS
		position.x = clampf(position.x, 0.0, BalanceConfig.WORLD_WIDTH_PIXELS)
		
		# Fuel consumption
		var base_fuel_rate: float = BalanceConfig.WALK_FUEL_RATE if current_speed >= 0.0 else BalanceConfig.REVERSE_FUEL_RATE
		var fuel_burn: float = SimulationLogic.calculate_fuel_consumption(
			true,
			gs.has_engine_upgrade(),
			delta,
			base_fuel_rate,
			0.30
		)
		gs.consume_fuel(fuel_burn)
		
		# Leg wear with biome multiplier
		var biome: Dictionary = BalanceConfig.get_biome_at_distance(gs.distance_traveled)
		var biome_mult: float = biome.get("wear_mult", 1.0)
		var speed_ratio: float = absf(current_speed) / BalanceConfig.BASE_FORWARD_SPEED
		var leg_wear: float = SimulationLogic.calculate_leg_wear(
			true,
			gs.has_legs_upgrade(),
			delta,
			0.20 * speed_ratio,
			0.40,
			biome_mult
		)
		gs.wear_legs(leg_wear)
		
		# Critical stop check
		if gs.fuel <= 0.0 or gs.leg_durability <= 0.0:
			current_speed = 0.0
			target_speed = 0.0
			is_house_moving = false
			gs.set_house_moving(false)
			gs.set_house_speed(0.0)
			
	# Update engine hum audio
	if sm != null:
		var hum_intensity: float = 0.0
		if is_house_moving:
			hum_intensity = clampf(absf(current_speed) / BalanceConfig.BASE_FORWARD_SPEED, 0.2, 1.0)
		sm.set_engine_hum(hum_intensity)

func _update_gait_and_legs(delta: float) -> void:
	var speed_ratio: float = absf(current_speed) / BalanceConfig.BASE_FORWARD_SPEED
	
	if is_house_moving:
		# Stride = 2.0 meters -> omega = PI * speed
		var omega: float = PI * current_speed
		gait_phase = fmod(gait_phase + omega * delta, TAU)
		if gait_phase < 0.0:
			gait_phase += TAU
			
	if leg_back != null:
		leg_back.update_leg(gait_phase, speed_ratio, delta)
	if leg_front != null:
		leg_front.update_leg(gait_phase, speed_ratio, delta)

func _update_hull_sway(delta: float) -> void:
	if cabin_pivot == null:
		return
		
	var speed_ratio: float = clampf(absf(current_speed) / BalanceConfig.BASE_FORWARD_SPEED, 0.0, 1.0)
	var accel: float = (current_speed - prev_speed) / maxf(delta, 0.001)
	
	# Heave (vertical bobbing at 2x gait frequency)
	var target_heave: float = -SWAY_HEAVE_AMP * absf(sin(gait_phase)) * speed_ratio
	cabin_pivot.position.y = lerpf(cabin_pivot.position.y, target_heave, 12.0 * delta)
	
	# Pitch tilt (gait rocking + inertial lag)
	var gait_pitch: float = SWAY_PITCH_AMP * sin(gait_phase) * speed_ratio
	var inertia_pitch: float = -ACCEL_INERTIA_K * accel
	var target_pitch: float = gait_pitch + inertia_pitch
	cabin_pivot.rotation = lerpf(cabin_pivot.rotation, target_pitch, 12.0 * delta)

func _update_lighting_and_particles(delta: float) -> void:
	var target_alpha: float = 1.0 if stove_active else (0.3 if cabin_temp > 5.0 else 0.0)
	if not is_equal_approx(window_glow_alpha, target_alpha):
		window_glow_alpha = move_toward(window_glow_alpha, target_alpha, delta * 2.5)
		
	if chimney_smoke != null:
		chimney_smoke.emitting = stove_active
		
	if window_light_main == null or hearth_light == null:
		return
		
	if not stove_active:
		hearth_light.enabled = false
		var residual_energy: float = 0.25 if cabin_temp > 0.0 else 0.0
		window_light_main.energy = lerpf(window_light_main.energy, residual_energy, delta * 2.0)
		if window_light_porthole != null:
			window_light_porthole.energy = lerpf(window_light_porthole.energy, residual_energy * 0.7, delta * 2.0)
		return
		
	hearth_light.enabled = true
	flame_timer += delta
	
	# Multi-harmonic organic flame flicker formula
	var n1: float = sin(flame_timer * 7.3) * 0.18
	var n2: float = sin(flame_timer * 16.7) * 0.09
	var n3: float = sin(flame_timer * 29.1) * 0.04
	var flicker: float = n1 + n2 + n3
	
	hearth_light.energy = clampf(1.4 + flicker, 0.9, 1.9)
	hearth_light.texture_scale = clampf(1.0 + flicker * 0.15, 0.85, 1.25)
	
	window_light_main.energy = clampf(1.3 + flicker * 0.5, 0.9, 1.7)
	if window_light_porthole != null:
		window_light_porthole.energy = clampf(0.9 + flicker * 0.4, 0.6, 1.2)

func _on_stove_toggled(is_on: bool) -> void:
	stove_active = is_on

func _on_cabin_temperature_changed(temp: float) -> void:
	cabin_temp = temp

func _on_footstep_impact(impact_world_pos: Vector2) -> void:
	var snow_tracks: SnowTracks = _find_snow_tracks()
	if snow_tracks != null:
		var facing: float = 1.0 if current_speed >= 0.0 else -1.0
		snow_tracks.add_track(impact_world_pos, 28.0, facing)

func _find_snow_tracks() -> SnowTracks:
	if get_parent() != null:
		var st = get_parent().get_node_or_null("SnowTracks")
		if st is SnowTracks:
			return st
	if is_inside_tree() and get_tree().current_scene != null:
		var st = get_tree().current_scene.get_node_or_null("SnowTracks")
		if st is SnowTracks:
			return st
	return null

# ------------------------------------------------------------------------------
# PROCEDURAL VECTOR DRAWING (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	var heave: float = cabin_pivot.position.y if cabin_pivot != null else 0.0
	var pitch: float = cabin_pivot.rotation if cabin_pivot != null else 0.0
	
	draw_set_transform(Vector2(0.0, heave), pitch, Vector2.ONE)
	
	_draw_chassis_base()
	_draw_cabin_walls_and_planks()
	_draw_corner_posts_and_framing()
	_draw_door()
	_draw_ladder()
	_draw_windows()
	_draw_roof_and_snow()
	_draw_chimney()
	_draw_chassis_rivets()
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# 1. Main Iron Chassis Girder
func _draw_chassis_base() -> void:
	draw_rect(Rect2(-86, 0, 172, 16), C_IRON_BASE)
	draw_line(Vector2(-86, 1), Vector2(86, 1), C_IRON_HIGHLIGHT, 2.0)
	draw_line(Vector2(-86, 16), Vector2(86, 16), C_IRON_SHADOW, 2.0)
	
	# Leg Hip Mounting Bosses (Left: -49, Right: +49)
	draw_rect(Rect2(-60, 6, 22, 14), C_IRON_BASE)
	draw_rect(Rect2(38, 6, 22, 14), C_IRON_BASE)
	draw_circle(Vector2(-49, 13), 5.5, C_IRON_SHADOW)
	draw_circle(Vector2(-49, 13), 4.0, C_RIVET_DOME)
	draw_circle(Vector2(49, 13), 5.5, C_IRON_SHADOW)
	draw_circle(Vector2(49, 13), 4.0, C_RIVET_DOME)

# 2. Wooden Walls & Horizontal Planking
func _draw_cabin_walls_and_planks() -> void:
	draw_rect(Rect2(-80, -110, 160, 110), C_WOOD_BASE)
	
	var plank_h: float = 11.0
	for i in range(10):
		var y_top: float = -110.0 + (i * plank_h)
		var y_bot: float = y_top + plank_h
		
		var plank_c := Color(
			C_WOOD_BASE.r + sin(i * 1.7) * 0.02,
			C_WOOD_BASE.g + cos(i * 2.3) * 0.015,
			C_WOOD_BASE.b + sin(i * 3.1) * 0.015,
			1.0
		)
		draw_rect(Rect2(-80, y_top, 160, plank_h), plank_c)
		draw_line(Vector2(-80, y_top + 1.0), Vector2(80, y_top + 1.0), C_WOOD_HIGHLIGHT, 1.0)
		draw_line(Vector2(-80, y_bot), Vector2(80, y_bot), C_WOOD_SEAM, 1.5)
		draw_line(Vector2(-75, y_top + 4.0), Vector2(75, y_top + 4.0), C_WOOD_GRAIN, 1.0)
		draw_line(Vector2(-70, y_top + 8.0), Vector2(70, y_top + 8.0), C_WOOD_GRAIN, 1.0)
	
	var butts: Array[Vector2] = [
		Vector2(-20, -110 + 1 * plank_h),
		Vector2(35, -110 + 3 * plank_h),
		Vector2(-45, -110 + 5 * plank_h),
		Vector2(15, -110 + 7 * plank_h),
		Vector2(-10, -110 + 9 * plank_h)
	]
	for b in butts:
		draw_line(b, Vector2(b.x, b.y + plank_h), C_WOOD_SEAM, 1.5)

# 3. Corner Timber Posts & Framing
func _draw_corner_posts_and_framing() -> void:
	draw_rect(Rect2(-82, -110, 12, 110), C_POST_DARK)
	draw_line(Vector2(-70, -110), Vector2(-70, 0), C_WOOD_SEAM, 1.5)
	
	draw_rect(Rect2(70, -110, 12, 110), C_POST_DARK)
	draw_line(Vector2(70, -110), Vector2(70, 0), C_WOOD_SEAM, 1.5)
	
	draw_rect(Rect2(-82, -16, 16, 16), C_IRON_BASE)
	draw_rect(Rect2(66, -16, 16, 16), C_IRON_BASE)
	_draw_single_rivet(Vector2(-74, -8))
	_draw_single_rivet(Vector2(74, -8))

# 4. Arctic Bulkhead Door
func _draw_door() -> void:
	var door_rect := Rect2(-72, -94, 26, 88)
	draw_rect(door_rect, Color(0.20, 0.16, 0.13))
	draw_rect(door_rect, C_WOOD_SEAM, false, 2.0)
	
	draw_line(Vector2(-70, -92), Vector2(-48, -92), C_IRON_BASE, 3.0)
	draw_line(Vector2(-70, -92), Vector2(-48, -8), C_IRON_BASE, 3.0)
	draw_line(Vector2(-70, -8), Vector2(-48, -8), C_IRON_BASE, 3.0)
	
	draw_circle(Vector2(-49, -48), 3.0, Color(0.65, 0.55, 0.35))
	draw_circle(Vector2(-49, -48), 1.5, Color(0.2, 0.15, 0.1))

# 5. Exterior Boarding Ladder
func _draw_ladder() -> void:
	draw_line(Vector2(-68, -6), Vector2(-68, 66), C_LADDER_RAIL, 3.0)
	draw_line(Vector2(-52, -6), Vector2(-52, 66), C_LADDER_RAIL, 3.0)
	
	var rung_y: Array[float] = [6.0, 18.0, 30.0, 42.0, 54.0, 66.0]
	for ry in rung_y:
		draw_line(Vector2(-67, ry), Vector2(-53, ry), C_LADDER_RUNG, 2.5)
		draw_line(Vector2(-67, ry - 1.0), Vector2(-53, ry - 1.0), C_LADDER_RUNG_HI, 1.0)

# 6. Windows & Reactive Hearth Glass
func _draw_windows() -> void:
	# Main Observation Window
	var win_outer := Rect2(2, -78, 40, 34)
	draw_rect(win_outer, C_WINDOW_FRAME)
	
	var win_inner := Rect2(5, -75, 34, 28)
	var current_glass: Color = C_GLASS_COLD.lerp(C_GLASS_WARM, window_glow_alpha)
	draw_rect(win_inner, current_glass)
	
	if window_glow_alpha > 0.1:
		var core_rect := Rect2(12, -68, 20, 14)
		var core_c := Color(C_GLASS_CORE.r, C_GLASS_CORE.g, C_GLASS_CORE.b, window_glow_alpha * 0.8)
		draw_rect(core_rect, core_c)
	else:
		draw_line(Vector2(6, -55), Vector2(16, -74), C_GLASS_FROST, 1.0)
		draw_line(Vector2(12, -48), Vector2(24, -70), C_GLASS_FROST, 1.0)
	
	draw_line(Vector2(5, -61), Vector2(39, -61), C_WINDOW_FRAME, 2.0)
	draw_line(Vector2(16, -75), Vector2(16, -47), C_WINDOW_FRAME, 2.0)
	draw_line(Vector2(28, -75), Vector2(28, -47), C_WINDOW_FRAME, 2.0)
	draw_rect(Rect2(3, -47, 38, 3), C_SNOW_FILL)
	
	# Circular Porthole
	var porthole_center := Vector2(-40, -65)
	draw_circle(porthole_center, 13.0, C_IRON_BASE)
	draw_circle(porthole_center, 10.5, C_WINDOW_FRAME)
	draw_circle(porthole_center, 9.0, current_glass)
	draw_line(porthole_center - Vector2(9, 0), porthole_center + Vector2(9, 0), C_WINDOW_FRAME, 1.5)
	draw_line(porthole_center - Vector2(0, 9), porthole_center + Vector2(0, 9), C_WINDOW_FRAME, 1.5)

# 7. Pitched Alpine Roof with Snow & Icicles
func _draw_roof_and_snow() -> void:
	var gable_poly := PackedVector2Array([
		Vector2(-80, -110),
		Vector2(0, -145),
		Vector2(80, -110)
	])
	draw_colored_polygon(gable_poly, Color(0.21, 0.18, 0.15))
	
	for gx in range(-70, 71, 12):
		var roof_y: float = -145.0 + (absf(float(gx)) / 80.0) * 35.0
		draw_line(Vector2(gx, -110), Vector2(gx, roof_y), C_WOOD_SEAM, 1.0)
	
	var roof_poly := PackedVector2Array([
		Vector2(-96, -106),
		Vector2(0, -145),
		Vector2(96, -106),
		Vector2(80, -110),
		Vector2(0, -140),
		Vector2(-80, -110)
	])
	draw_colored_polygon(roof_poly, C_ROOF_SURFACE)
	draw_line(Vector2(-96, -106), Vector2(0, -145), C_ROOF_FASCIA, 4.0)
	draw_line(Vector2(0, -145), Vector2(96, -106), C_ROOF_FASCIA, 4.0)
	
	var snow_cap := PackedVector2Array([
		Vector2(-98, -107),
		Vector2(-96, -114),
		Vector2(-75, -126),
		Vector2(-48, -137),
		Vector2(-20, -148),
		Vector2(0, -153),
		Vector2(22, -147),
		Vector2(52, -136),
		Vector2(78, -124),
		Vector2(96, -114),
		Vector2(98, -107),
		Vector2(94, -108),
		Vector2(0, -145),
		Vector2(-94, -108)
	])
	draw_colored_polygon(snow_cap, C_SNOW_FILL)
	
	var snow_top_edge := PackedVector2Array([
		Vector2(-96, -114),
		Vector2(-75, -126),
		Vector2(-48, -137),
		Vector2(-20, -148),
		Vector2(0, -153),
		Vector2(22, -147),
		Vector2(52, -136),
		Vector2(78, -124),
		Vector2(96, -114)
	])
	draw_polyline(snow_top_edge, C_SNOW_TOP, 2.0)
	
	var icicle_x: Array[float] = [-90.0, -68.0, -45.0, 42.0, 66.0, 86.0]
	var icicle_len: Array[float] = [8.0, 14.0, 7.0, 10.0, 13.0, 9.0]
	for idx in range(icicle_x.size()):
		var ix: float = icicle_x[idx]
		var l: float = icicle_len[idx]
		var base_y: float = -106.0 + (1.0 - absf(ix) / 96.0) * -39.0
		var tri := PackedVector2Array([
			Vector2(ix - 2, base_y),
			Vector2(ix + 2, base_y),
			Vector2(ix, base_y + l)
		])
		draw_colored_polygon(tri, C_ICICLE)

# 8. Cast-Iron Chimney
func _draw_chimney() -> void:
	draw_rect(Rect2(39, -178, 14, 48), C_IRON_BASE)
	draw_rect(Rect2(39, -178, 3, 48), C_IRON_SHADOW)
	draw_rect(Rect2(43, -178, 4, 48), C_IRON_HIGHLIGHT)
	
	draw_rect(Rect2(37, -145, 18, 4), C_IRON_BASE)
	draw_rect(Rect2(37, -165, 18, 4), C_IRON_BASE)
	_draw_single_rivet(Vector2(38, -143))
	_draw_single_rivet(Vector2(54, -143))
	
	if stove_active:
		draw_rect(Rect2(38, -136, 16, 6), Color(0.95, 0.45, 0.10, 0.6))
	
	draw_line(Vector2(41, -178), Vector2(41, -184), C_IRON_BASE, 1.5)
	draw_line(Vector2(51, -178), Vector2(51, -184), C_IRON_BASE, 1.5)
	
	var cowl_cone := PackedVector2Array([
		Vector2(34, -184),
		Vector2(46, -192),
		Vector2(58, -184)
	])
	draw_colored_polygon(cowl_cone, Color(0.15, 0.16, 0.17))
	draw_line(Vector2(34, -184), Vector2(58, -184), C_IRON_SHADOW, 1.5)

# 9. Shaded Rivets
func _draw_chassis_rivets() -> void:
	var rivet_x: Array[float] = [-80.0, -64.0, -48.0, -32.0, -16.0, 0.0, 16.0, 32.0, 48.0, 64.0, 80.0]
	for rx in rivet_x:
		_draw_single_rivet(Vector2(rx, 8.0))

func _draw_single_rivet(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, 1.0), 2.2, C_RIVET_SHADOW)
	draw_circle(pos, 1.8, C_RIVET_DOME)
	draw_circle(pos - Vector2(0.5, 0.5), 0.7, C_RIVET_GLINT)
