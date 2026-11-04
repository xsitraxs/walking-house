# scripts/entities/Player.gd
class_name Player
extends CharacterBody2D

## Player Entity Controller for «Шагающий дом» (Milestone 3).
## Features: Outside locomotion (F20), vector procedural art (_draw),
## walking animation, storm lantern lighting, deep snow friction,
## 45m safe tether cable (F24), outside hypothermia exposure (F23),
## and interaction detection for POI scavenging and house re-entry (F18, F21, F25).

const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SnowTracks = preload("res://scripts/world/SnowTracks.gd")

# ------------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# ------------------------------------------------------------------------------
const SPEED: float = 64.0              # 3.2 m/s * 20 px/m (BalanceConfig.PLAYER_SPEED)
const ACCELERATION: float = 320.0       # Snappy snow acceleration
const FRICTION: float = 400.0           # Snow braking friction
const STEP_INTERVAL: float = 0.35       # Stride duration in seconds

const SAFE_RADIUS_PX: float = 900.0     # 45m * 20 px/m (BalanceConfig.PLAYER_SAFE_RADIUS)
const WARNING_RADIUS_PX: float = 780.0  # 39m (Start warning)
const CLAMP_LIMIT_PX: float = 1000.0    # 50m Hard physical cable constraint

# Palette specification (Zero external textures)
const C_PARKA_MAIN := Color(0.74, 0.52, 0.22, 1.0)       # Weathered mustard canvas
const C_PARKA_DARK := Color(0.24, 0.20, 0.17, 1.0)       # Reinforced shoulder yoke
const C_PARKA_FUR := Color(0.88, 0.84, 0.76, 1.0)        # Arctic wolf fur ruff
const C_PANTS := Color(0.22, 0.26, 0.30, 1.0)            # Slate snow pants
const C_BOOTS := Color(0.14, 0.13, 0.12, 1.0)            # Heavy muck boots
const C_GOGGLES_RIM := Color(0.12, 0.12, 0.14, 1.0)
const C_GOGGLES_LENS := Color(0.95, 0.68, 0.22, 0.95)    # Amber reflective visor
const C_MITTEN := Color(0.22, 0.18, 0.15, 1.0)
const C_LANTERN_BRASS := Color(0.70, 0.55, 0.25, 1.0)
const C_LANTERN_CORE := Color(1.0, 0.96, 0.75, 1.0)
const C_BACKPACK := Color(0.28, 0.24, 0.20, 1.0)
const C_BEDROLL := Color(0.35, 0.38, 0.35, 1.0)

# Tether cable palette
const C_TETHER_NORMAL := Color(0.32, 0.36, 0.40, 0.85)
const C_TETHER_WARN := Color(0.90, 0.75, 0.20, 0.95)
const C_TETHER_DANGER := Color(0.95, 0.25, 0.25, 1.0)

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var visuals_pivot: Node2D = get_node_or_null("Visuals")
@onready var lantern_light: PointLight2D = get_node_or_null("LanternLight")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var step_particles: CPUParticles2D = get_node_or_null("StepParticles")
@onready var breath_particles: CPUParticles2D = get_node_or_null("BreathParticles")

# ------------------------------------------------------------------------------
# RUNTIME STATE
# ------------------------------------------------------------------------------
var is_active: bool = false
var facing: float = 1.0                 # +1.0 right, -1.0 left
var walk_phase: float = 0.0             # Walk animation radians
var step_timer: float = 0.0
var breath_timer: float = 0.0
var flame_timer: float = 0.0

var outside_exposure_timer: float = 0.0 # Time spent outside since disembarking
var can_reenter_house: bool = false
var current_interactable: Node = null

var house_ref: Node2D = null            # Reference to WalkingHouse for tethering
var alarm_audio_cooldown: float = 0.0
var is_at_tether_limit: bool = false

# ------------------------------------------------------------------------------
# INITIALIZATION & LIFECYCLE
# ------------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("player")
	_ensure_nodes()
	_setup_lantern_light()
	_setup_particles()
	_connect_event_bus()
	
	# Start inactive (inside house)
	set_player_active(false)

func _ensure_nodes() -> void:
	collision_layer = 4
	collision_mask = 1
	
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 7.0
		capsule.height = 32.0
		collision_shape.shape = capsule
		collision_shape.position = Vector2(0, -16)
		add_child(collision_shape)
		
	if interaction_area == null:
		interaction_area = get_node_or_null("InteractionArea")
	if interaction_area == null:
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		interaction_area.collision_layer = 4
		interaction_area.collision_mask = 8
		var circle := CircleShape2D.new()
		circle.radius = BalanceConfig.PLAYER_INTERACT_RADIUS * BalanceConfig.METERS_TO_PIXELS # 50 px
		var area_shape := CollisionShape2D.new()
		area_shape.shape = circle
		interaction_area.add_child(area_shape)
		add_child(interaction_area)
		
	if not interaction_area.is_connected("area_entered", Callable(self, "_on_interaction_area_entered")):
		interaction_area.area_entered.connect(_on_interaction_area_entered)
	if not interaction_area.is_connected("area_exited", Callable(self, "_on_interaction_area_exited")):
		interaction_area.area_exited.connect(_on_interaction_area_exited)

func _setup_lantern_light() -> void:
	if lantern_light == null:
		lantern_light = get_node_or_null("LanternLight")
	if lantern_light == null:
		lantern_light = PointLight2D.new()
		lantern_light.name = "LanternLight"
		add_child(lantern_light)
		
	lantern_light.position = Vector2(8, -18)
	lantern_light.color = Color(1.0, 0.88, 0.58, 1.0)
	lantern_light.energy = 1.15
	lantern_light.texture = _create_lantern_radial_texture(120)

func _create_lantern_radial_texture(radius: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.95, 0.70, 1.0),
		Color(0.95, 0.60, 0.15, 0.45),
		Color(0.80, 0.30, 0.05, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = radius * 2
	tex.height = radius * 2
	return tex

func _setup_particles() -> void:
	if step_particles == null:
		step_particles = get_node_or_null("StepParticles")
	if step_particles == null:
		step_particles = CPUParticles2D.new()
		step_particles.name = "StepParticles"
		step_particles.emitting = false
		step_particles.one_shot = true
		step_particles.amount = 6
		step_particles.lifetime = 0.5
		step_particles.direction = Vector2(0, -1)
		step_particles.spread = 45.0
		step_particles.initial_velocity_min = 15.0
		step_particles.initial_velocity_max = 30.0
		step_particles.gravity = Vector2(0, 98.0)
		step_particles.color = Color(0.95, 0.98, 1.0, 0.8)
		add_child(step_particles)
		
	if breath_particles == null:
		breath_particles = get_node_or_null("BreathParticles")
	if breath_particles == null:
		breath_particles = CPUParticles2D.new()
		breath_particles.name = "BreathParticles"
		breath_particles.emitting = false
		breath_particles.one_shot = true
		breath_particles.amount = 8
		breath_particles.lifetime = 1.2
		breath_particles.position = Vector2(6, -26)
		breath_particles.direction = Vector2(1, -0.3)
		breath_particles.spread = 20.0
		breath_particles.initial_velocity_min = 10.0
		breath_particles.initial_velocity_max = 22.0
		breath_particles.gravity = Vector2(-8.0, -12.0)
		breath_particles.color = Color(0.90, 0.95, 1.0, 0.4)
		add_child(breath_particles)

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	if bus.has_signal("player_disembarked"):
		bus.connect("player_disembarked", Callable(self, "_on_player_disembarked"))
	if bus.has_signal("player_embarked"):
		bus.connect("player_embarked", Callable(self, "_on_player_embarked"))

# ------------------------------------------------------------------------------
# STATE CONTROL & EMBARK/DISEMBARK
# ------------------------------------------------------------------------------
func set_player_active(active: bool) -> void:
	is_active = active
	visible = active
	set_physics_process(active)
	set_process_unhandled_input(active)
	if collision_shape != null:
		collision_shape.disabled = not active

func spawn_at_house_ladder(house: Node2D) -> void:
	house_ref = house
	# Ground surface is Y = 560. Ladder is at house X - 60 px
	var ladder_pos := Vector2(house.global_position.x - 60.0, 560.0)
	global_position = ladder_pos
	velocity = Vector2.ZERO
	facing = 1.0
	outside_exposure_timer = 0.0
	is_at_tether_limit = false
	set_player_active(true)
	
	# Spawn initial disembark footprints
	var st = _find_snow_tracks()
	if st != null:
		st.add_track(global_position, 8.0, facing)

func _on_player_disembarked() -> void:
	if house_ref == null:
		house_ref = _find_walking_house()
	if house_ref != null:
		spawn_at_house_ladder(house_ref)

func _on_player_embarked() -> void:
	set_player_active(false)
	is_at_tether_limit = false
	var bus: Node = _get_event_bus()
	if bus != null:
		bus.emit_signal("prompt_cleared")

# ------------------------------------------------------------------------------
# INPUT & INTERACTION DISPATCH
# ------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	if event.is_action_pressed("interact"):
		# Check if close to house ladder
		_update_ladder_proximity()
		
		if can_reenter_house:
			_embark_into_house()
			get_viewport().set_input_as_handled()
		elif current_interactable != null:
			if current_interactable.has_method("harvest"):
				current_interactable.harvest()
			elif current_interactable.has_method("interact"):
				current_interactable.interact(self)
			get_viewport().set_input_as_handled()

func _embark_into_house() -> void:
	var gs: Node = _get_game_state()
	var sm: Node = _get_sound_manager()
	if gs != null:
		gs.embark_player()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("step")

# ------------------------------------------------------------------------------
# PHYSICS LOOP & CONTINUOUS KINEMATICS
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
		
	_process_locomotion(delta)
	_process_tether(delta)
	_process_cold_exposure(delta)
	_process_cosmetic_fx(delta)
	_update_ladder_proximity()
	queue_redraw()

func _process_locomotion(delta: float) -> void:
	var input_axis: float = Input.get_axis("move_left", "move_right")
	
	if absf(input_axis) > 0.05:
		velocity.x = move_toward(velocity.x, input_axis * SPEED, ACCELERATION * delta)
		facing = signf(input_axis)
		if lantern_light != null:
			lantern_light.position.x = 8.0 * facing
		if breath_particles != null:
			breath_particles.position.x = 6.0 * facing
			breath_particles.direction.x = 1.0 * facing
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		
	# Ground gravity clamp
	velocity.y = 0.0
	global_position.y = 560.0
	
	if is_inside_tree():
		move_and_slide()
	else:
		global_position.x += velocity.x * delta
	
	# Walking animation & footstep timing
	var is_moving: bool = absf(velocity.x) > 2.0
	if is_moving:
		walk_phase += 14.0 * delta * (absf(velocity.x) / SPEED)
		step_timer += delta
		if step_timer >= STEP_INTERVAL:
			step_timer = 0.0
			_on_footstep()
	else:
		walk_phase = lerp_angle(walk_phase, 0.0, 10.0 * delta)

func _on_footstep() -> void:
	if step_particles != null:
		step_particles.position = Vector2(facing * 3.0, 0.0)
		step_particles.restart()
		step_particles.emitting = true
		
	var st = _find_snow_tracks()
	if st != null:
		st.add_track(global_position + Vector2(facing * 4.0, 0.0), 8.0, facing)
		
	var sm: Node = _get_sound_manager()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("step")

# ------------------------------------------------------------------------------
# TETHER RADIUS & BOUNDARY ENFORCEMENT (F24)
# ------------------------------------------------------------------------------
func get_distance_to_house_meters() -> float:
	if house_ref == null:
		house_ref = _find_walking_house()
	if house_ref == null:
		return 0.0
	return absf(global_position.x - house_ref.global_position.x) / BalanceConfig.METERS_TO_PIXELS

func _process_tether(delta: float) -> void:
	if house_ref == null:
		house_ref = _find_walking_house()
	if house_ref == null:
		return
		
	var dist_px: float = absf(global_position.x - house_ref.global_position.x)
	var dist_m: float = dist_px / BalanceConfig.METERS_TO_PIXELS
	var sm: Node = _get_sound_manager()
	var bus: Node = _get_event_bus()
	
	# 1. Hard Physical Tether Lockout (50m = 1000 px clamp)
	if dist_px >= CLAMP_LIMIT_PX:
		var dir: float = signf(global_position.x - house_ref.global_position.x)
		if dir == 0.0:
			dir = 1.0
		global_position.x = house_ref.global_position.x + dir * CLAMP_LIMIT_PX
		if (velocity.x * dir) > 0.0:
			velocity.x = 0.0
		if not is_at_tether_limit:
			is_at_tether_limit = true
			if bus != null:
				bus.emit_signal("prompt_requested", "Трос натянут до предела (50 м)!")
	else:
		if is_at_tether_limit:
			is_at_tether_limit = false
			if bus != null and not can_reenter_house and current_interactable == null:
				bus.emit_signal("prompt_cleared")
			
	# 2. Alarm siren pulse when exceeding safe radius (45m = 900 px)
	if dist_m > BalanceConfig.PLAYER_SAFE_RADIUS:
		alarm_audio_cooldown -= delta
		if alarm_audio_cooldown <= 0.0:
			alarm_audio_cooldown = 2.0
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("alarm")

# ------------------------------------------------------------------------------
# COLD EXPOSURE & HYPOTHERMIA (F23)
# ------------------------------------------------------------------------------
func _process_cold_exposure(delta: float) -> void:
	var gs: Node = _get_game_state()
	if gs == null or gs.is_game_over or gs.is_victory:
		return
		
	outside_exposure_timer += delta
	
	# 1. Warmth buffer (20.0 seconds of parka protection)
	var warmth_sec_left: float = maxf(0.0, BalanceConfig.OUTDOOR_WARMTH_DURATION - outside_exposure_timer)
	var warmth_pct: float = (warmth_sec_left / BalanceConfig.OUTDOOR_WARMTH_DURATION) * 100.0
	gs.set_player_warmth(warmth_pct)
	
	# 2. Hypothermia damage calculation via SimulationLogic
	var dist_m: float = get_distance_to_house_meters()
	var base_dmg: float = SimulationLogic.calculate_outside_cold_damage(
		outside_exposure_timer,
		BalanceConfig.OUTDOOR_WARMTH_DURATION,
		gs.is_blizzard,
		delta,
		BalanceConfig.OUTDOOR_FREEZE_DAMAGE_RATE,
		BalanceConfig.OUTDOOR_BLIZZARD_DAMAGE_RATE
	)
	
	# 3. Tether violation doubles damage (dist_m > 45m)
	var tether_mult: float = 2.0 if dist_m > BalanceConfig.PLAYER_SAFE_RADIUS else 1.0
	var final_damage: float = base_dmg * tether_mult
	
	if final_damage > 0.0:
		gs.damage_player(final_damage)

# ------------------------------------------------------------------------------
# COSMETIC PARTICLES & BREATH
# ------------------------------------------------------------------------------
func _process_cosmetic_fx(delta: float) -> void:
	flame_timer += delta
	if lantern_light != null:
		lantern_light.energy = 1.15 + sin(flame_timer * 9.0) * 0.06
	
	breath_timer += delta
	if breath_timer >= 2.8:
		breath_timer = 0.0
		if breath_particles != null:
			breath_particles.restart()
			breath_particles.emitting = true

# ------------------------------------------------------------------------------
# LADDER PROXIMITY & INTERACTION DETECTION
# ------------------------------------------------------------------------------
func _update_ladder_proximity() -> void:
	if house_ref == null:
		house_ref = _find_walking_house()
	if house_ref == null:
		return
		
	var ladder_x: float = house_ref.global_position.x - 60.0
	var dist_to_ladder: float = absf(global_position.x - ladder_x)
	var was_near: bool = can_reenter_house
	can_reenter_house = dist_to_ladder <= 50.0 # 2.5m interact radius
	
	var bus: Node = _get_event_bus()
	if can_reenter_house and not was_near and current_interactable == null:
		if bus != null:
			bus.emit_signal("prompt_requested", "[E] Войти в дом")
	elif not can_reenter_house and was_near and current_interactable == null:
		if bus != null:
			bus.emit_signal("prompt_cleared")

func _on_interaction_area_entered(area: Area2D) -> void:
	var bus: Node = _get_event_bus()
	if area.name == "LadderArea" or area.is_in_group("house_ladder"):
		can_reenter_house = true
		if bus != null:
			bus.emit_signal("prompt_requested", "[E] Войти в дом")
	elif area.is_in_group("resource_nodes") or area.is_in_group("poi") or area.has_method("get_interaction_prompt"):
		current_interactable = area
		var prompt: String = area.get_interaction_prompt() if area.has_method("get_interaction_prompt") else "[E] Обыскать объект"
		if bus != null:
			bus.emit_signal("prompt_requested", prompt)

func _on_interaction_area_exited(area: Area2D) -> void:
	var bus: Node = _get_event_bus()
	if area.name == "LadderArea" or area.is_in_group("house_ladder"):
		can_reenter_house = false
		if bus != null and current_interactable == null:
			bus.emit_signal("prompt_cleared")
	elif area == current_interactable:
		current_interactable = null
		if bus != null and not can_reenter_house:
			bus.emit_signal("prompt_cleared")

# ------------------------------------------------------------------------------
# PROCEDURAL VECTOR DRAWING (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	_draw_tether_cable()
	_draw_character()

func _draw_tether_cable() -> void:
	if house_ref == null:
		house_ref = _find_walking_house()
	if house_ref == null:
		return
		
	var house_winch_world: Vector2 = house_ref.global_position + Vector2(-60.0, 30.0)
	var anchor_local: Vector2 = to_local(house_winch_world)
	var harness_local := Vector2(0.0, -18.0)
	
	var dist_px: float = harness_local.distance_to(anchor_local)
	var dist_m: float = dist_px / BalanceConfig.METERS_TO_PIXELS
	
	# Determine cable color based on tether state
	var cable_color: Color = C_TETHER_NORMAL
	if dist_m > BalanceConfig.PLAYER_SAFE_RADIUS:
		cable_color = C_TETHER_DANGER
	elif dist_m > 38.0:
		cable_color = C_TETHER_WARN
		
	# Catenary parabolic sag
	var max_sag: float = maxf(0.0, 32.0 * pow(1.0 - clampf(dist_px / SAFE_RADIUS_PX, 0.0, 1.0), 2.0))
	var points := PackedVector2Array()
	var seg_count: int = 14
	
	for i in range(seg_count + 1):
		var u: float = float(i) / float(seg_count)
		var pt: Vector2 = harness_local.lerp(anchor_local, u)
		var sag_y: float = 4.0 * max_sag * u * (1.0 - u)
		pt.y += sag_y
		points.append(pt)
		
	draw_polyline(points, cable_color, 2.0)
	draw_circle(harness_local, 2.2, Color(0.65, 0.70, 0.75)) # Carabiner ring

func _draw_character() -> void:
	var f: float = facing
	var heave: float = -absf(sin(walk_phase)) * 2.0
	var leg_swing: float = sin(walk_phase) * 0.35
	
	draw_set_transform(Vector2(0, heave), 0.0, Vector2.ONE)
	
	# 1. Survival Backpack (Behind Torso)
	var pack_x: float = -6.0 * f
	draw_rect(Rect2(pack_x - 3.5, -28.0, 7.0, 14.0), C_BACKPACK)
	draw_rect(Rect2(pack_x - 4.5, -32.0, 9.0, 5.0), C_BEDROLL)
	
	# 2. Back Leg & Boot
	var back_leg_angle: float = -leg_swing
	var back_foot_x: float = sin(back_leg_angle) * 12.0
	draw_line(Vector2(-2.0 * f, -12.0), Vector2(back_foot_x, 0.0), C_PANTS, 4.0)
	draw_circle(Vector2(back_foot_x, 0.0), 3.2, C_BOOTS)
	
	# 3. Front Leg & Boot
	var front_leg_angle: float = leg_swing
	var front_foot_x: float = sin(front_leg_angle) * 12.0
	draw_line(Vector2(2.0 * f, -12.0), Vector2(front_foot_x, 0.0), C_PANTS, 4.5)
	draw_circle(Vector2(front_foot_x, 0.0), 3.5, C_BOOTS)
	
	# 4. Quilted Parka Torso & Hem
	var torso_poly := PackedVector2Array([
		Vector2(-5.0 * f, -26.0),
		Vector2(5.0 * f, -26.0),
		Vector2(7.0 * f, -10.0),
		Vector2(-7.0 * f, -10.0)
	])
	draw_colored_polygon(torso_poly, C_PARKA_MAIN)
	draw_rect(Rect2(-7.0, -11.0, 14.0, 2.5), C_PARKA_FUR)
	
	# Shoulder reinforcement yoke
	var yoke_poly := PackedVector2Array([
		Vector2(-5.0 * f, -26.0),
		Vector2(5.0 * f, -26.0),
		Vector2(5.5 * f, -20.0),
		Vector2(-5.5 * f, -20.0)
	])
	draw_colored_polygon(yoke_poly, C_PARKA_DARK)
	
	# Utility Belt & Brass Buckle
	draw_rect(Rect2(-6.0, -14.0, 12.0, 3.0), Color(0.18, 0.16, 0.14))
	draw_rect(Rect2(-1.5, -14.5, 3.0, 4.0), Color(0.80, 0.65, 0.25))
	
	# 5. Arctic Fur Hood & Head
	var head_center := Vector2(1.0 * f, -30.0)
	draw_circle(head_center, 7.5, C_PARKA_FUR)
	draw_circle(head_center, 5.5, C_PARKA_MAIN)
	
	# Balaclava Face Mask & Visor
	var face_pos: Vector2 = head_center + Vector2(2.5 * f, 1.0)
	draw_circle(face_pos, 3.5, Color(0.18, 0.18, 0.20))
	draw_rect(Rect2(face_pos.x - 1.0, face_pos.y - 2.0, 4.0 * f, 2.5), C_GOGGLES_RIM)
	draw_rect(Rect2(face_pos.x, face_pos.y - 1.5, 3.0 * f, 1.5), C_GOGGLES_LENS)
	
	# 6. Front Arm & Brass Storm Lantern
	var arm_swing: float = -leg_swing
	var hand_pos := Vector2(8.0 * f, -16.0 + sin(arm_swing) * 4.0)
	draw_line(Vector2(2.0 * f, -22.0), hand_pos, C_PARKA_MAIN, 3.5)
	draw_circle(hand_pos, 2.2, C_MITTEN)
	
	# Storm Lantern Hanging from Mitten
	var lantern_pos: Vector2 = hand_pos + Vector2(0.0, 6.0)
	draw_line(hand_pos, lantern_pos, Color(0.4, 0.35, 0.25), 1.0)
	draw_rect(Rect2(lantern_pos.x - 2.5, lantern_pos.y - 1.0, 5.0, 2.0), C_LANTERN_BRASS)
	draw_rect(Rect2(lantern_pos.x - 2.0, lantern_pos.y + 1.0, 4.0, 5.0), C_LANTERN_CORE)
	draw_rect(Rect2(lantern_pos.x - 2.5, lantern_pos.y + 6.0, 5.0, 2.0), C_LANTERN_BRASS)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------------------
# SINGLETON ACCESSORS & WIRING
# ------------------------------------------------------------------------------
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

func _find_walking_house() -> Node2D:
	if house_ref != null:
		return house_ref
	if get_parent() != null:
		var h = get_parent().get_node_or_null("WalkingHouse")
		if h is Node2D:
			return h
	if is_inside_tree() and get_tree().current_scene != null:
		var h = get_tree().current_scene.get_node_or_null("WalkingHouse")
		if h is Node2D:
			return h
	return null

func _find_snow_tracks() -> Node2D:
	if get_parent() != null:
		var st = get_parent().get_node_or_null("SnowTracks")
		if st != null:
			return st
	if is_inside_tree() and get_tree().current_scene != null:
		var st = get_tree().current_scene.get_node_or_null("SnowTracks")
		if st != null:
			return st
	return null
