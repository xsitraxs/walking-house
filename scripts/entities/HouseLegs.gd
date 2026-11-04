# scripts/entities/HouseLegs.gd
class_name HouseLegs
extends Node2D

## Procedural 2-bone articulated mechanical leg with telescoping hydraulic cylinder.
## Designed for «Шагающий дом» (Walking House).

signal footstep_impact(global_pos: Vector2)
signal foot_planted(global_pos: Vector2)
signal foot_lifted(global_pos: Vector2)

@export var leg_id: String = "back"
@export var phase_offset: float = 0.0 # 0.0 for back leg, PI for front leg
@export var is_foreground: bool = false
@export var hip_offset: Vector2 = Vector2(-49.0, 13.0)

const L1: float = 65.0       # Upper leg length (px)
const L2: float = 70.0       # Lower leg length (px)
const STRIDE_HALF: float = 38.0 # Half-stride length (px)
const STEP_HEIGHT: float = 18.0 # Step lift clearance (px)
const KNEE_DIR: float = 1.0  # 1.0 = forward bend

# Kinematic State
var foot_pos: Vector2 = Vector2.ZERO
var knee_pos: Vector2 = Vector2.ZERO
var theta1: float = 0.0
var theta2: float = 0.0
var was_in_swing: bool = false
var ground_y: float = 115.0 # Relative to hip

# Palette Colors
var col_steel_dark: Color = Color(0.18, 0.20, 0.25, 1.0)
var col_steel_mid: Color = Color(0.26, 0.30, 0.37, 1.0)
var col_steel_light: Color = Color(0.38, 0.43, 0.52, 1.0)
var col_chrome: Color = Color(0.90, 0.92, 0.95, 1.0)
var col_brass: Color = Color(0.75, 0.52, 0.28, 1.0)
var col_sole: Color = Color(0.12, 0.13, 0.16, 1.0)

@onready var particles: CPUParticles2D = get_node_or_null("FootstepParticles")

func _ready() -> void:
	if not is_foreground:
		# Darken background leg for visual depth perspective
		col_steel_mid = col_steel_mid.darkened(0.35)
		col_steel_light = col_steel_light.darkened(0.35)
		col_chrome = col_chrome.darkened(0.25)
		col_brass = col_brass.darkened(0.30)
	
	if particles == null:
		var p_node := get_node_or_null("FootstepParticles")
		if p_node != null and p_node is CPUParticles2D:
			particles = p_node
		else:
			particles = CPUParticles2D.new()
			particles.name = "FootstepParticles"
			add_child(particles)
			_setup_footstep_particles(particles)
	else:
		_setup_footstep_particles(particles)
	
	# Initial resting foot placement
	foot_pos = hip_offset + Vector2(0.0, ground_y)
	_solve_ik()

func _setup_footstep_particles(p: CPUParticles2D) -> void:
	p.emitting = false
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.65
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 2)
	p.direction = Vector2(0, -1)
	p.spread = 65.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 120.0
	p.damping_min = 30.0
	p.damping_max = 50.0
	p.gravity = Vector2(0, 140.0)
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.2))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.95),
		Color(0.90, 0.95, 1.0, 0.70),
		Color(0.80, 0.90, 0.98, 0.0)
	])
	p.color_ramp = ramp

func update_leg(master_phase: float, speed_ratio: float, _delta: float) -> void:
	var local_phase: float = fmod(master_phase + phase_offset, TAU)
	if local_phase < 0.0:
		local_phase += TAU
		
	var is_swing: bool = (local_phase >= PI)
	
	if not is_swing:
		# STANCE PHASE: Foot translates backwards in local frame
		var x_local: float = hip_offset.x + STRIDE_HALF * cos(local_phase)
		var y_local: float = hip_offset.y + ground_y
		foot_pos = Vector2(x_local, y_local)
		
		# Check for touchdown event
		if was_in_swing:
			_on_foot_touchdown()
	else:
		# SWING PHASE: Foot lifts and advances forward
		var s: float = (local_phase - PI) / PI # 0.0 -> 1.0
		var x_local: float = hip_offset.x - STRIDE_HALF * cos(PI * s)
		var lift: float = STEP_HEIGHT * sin(PI * s) * clampf(speed_ratio, 0.2, 1.0)
		var y_local: float = hip_offset.y + ground_y - lift
		foot_pos = Vector2(x_local, y_local)
		
		if not was_in_swing:
			_on_foot_liftoff()
	
	was_in_swing = is_swing
	_solve_ik()
	queue_redraw()

func _solve_ik() -> void:
	var d_vec: Vector2 = foot_pos - hip_offset
	var d: float = clampf(d_vec.length(), absf(L1 - L2) + 1.0, L1 + L2 - 0.5)
	var alpha: float = d_vec.angle()
	
	var cos_beta: float = clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var beta: float = acos(cos_beta)
	
	theta1 = alpha - KNEE_DIR * beta
	knee_pos = hip_offset + Vector2(cos(theta1), sin(theta1)) * L1
	
	var shank_vec: Vector2 = foot_pos - knee_pos
	theta2 = shank_vec.angle()

func _on_foot_touchdown() -> void:
	# Audio trigger hook
	if Engine.has_singleton("SoundManager"):
		Engine.get_singleton("SoundManager").play_sfx("step")
	elif is_inside_tree() and get_tree().root.has_node("SoundManager"):
		get_tree().root.get_node("SoundManager").play_sfx("step")
		
	# Particle puff hook
	if particles != null:
		particles.position = foot_pos + Vector2(0.0, 4.0)
		particles.restart()
		particles.emitting = true
		
	var impact_world: Vector2 = global_position + foot_pos
	emit_signal("footstep_impact", impact_world)
	emit_signal("foot_planted", impact_world)

func _on_foot_liftoff() -> void:
	var liftoff_world: Vector2 = global_position + foot_pos
	emit_signal("foot_lifted", liftoff_world)

func _draw() -> void:
	# 1. Hydraulic Cylinder (Behind bone links)
	_draw_hydraulic_cylinder()
	
	# 2. Upper Leg (Thigh girder)
	_draw_segment(hip_offset, knee_pos, 12.0, 9.0, col_steel_mid, col_steel_light)
	
	# 3. Lower Leg (Shank strut)
	_draw_segment(knee_pos, foot_pos, 9.0, 6.5, col_steel_mid, col_steel_light)
	
	# 4. Joint Pivot Knuckles
	draw_circle(hip_offset, 7.5, col_steel_dark)
	draw_circle(hip_offset, 3.0, col_chrome)
	draw_circle(knee_pos, 6.5, col_steel_dark)
	draw_circle(knee_pos, 2.5, col_chrome)
	
	# 5. Articulated Footpad (Snowshoe)
	_draw_footpad()

func _draw_segment(from: Vector2, to: Vector2, w_from: float, w_to: float, base_col: Color, highlight_col: Color) -> void:
	var dir: Vector2 = (to - from).normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	
	var p1: Vector2 = from + normal * (w_from * 0.5)
	var p2: Vector2 = to + normal * (w_to * 0.5)
	var p3: Vector2 = to - normal * (w_to * 0.5)
	var p4: Vector2 = from - normal * (w_from * 0.5)
	
	var poly: PackedVector2Array = PackedVector2Array([p1, p2, p3, p4])
	draw_colored_polygon(poly, base_col)
	draw_polyline(poly, col_steel_dark, 1.5, true)
	
	# Inner highlight rib
	draw_line(from + dir * 6.0, to - dir * 6.0, highlight_col, 2.0, true)

func _draw_hydraulic_cylinder() -> void:
	var u1: Vector2 = Vector2(cos(theta1), sin(theta1))
	var n1: Vector2 = Vector2(-u1.y, u1.x)
	var p_cyl_base: Vector2 = hip_offset + u1 * 18.0 + n1 * 6.0
	
	var u2: Vector2 = Vector2(cos(theta2), sin(theta2))
	var n2: Vector2 = Vector2(-u2.y, u2.x)
	var p_cyl_rod: Vector2 = knee_pos + u2 * 24.0 + n2 * 6.0
	
	var cyl_vec: Vector2 = p_cyl_rod - p_cyl_base
	var cyl_dir: Vector2 = cyl_vec.normalized()
	
	var barrel_len: float = 26.0
	var rod_tip: Vector2 = p_cyl_base + cyl_dir * barrel_len
	
	# Chrome Piston Rod
	draw_line(rod_tip, p_cyl_rod, col_chrome, 3.0, true)
	# Bronze/Gunmetal Barrel Body
	draw_line(p_cyl_base, rod_tip, col_brass, 6.0, true)
	# End Pin Rings
	draw_circle(p_cyl_base, 3.5, col_steel_dark)
	draw_circle(p_cyl_rod, 3.0, col_steel_dark)

func _draw_footpad() -> void:
	# Ankle pivot pin
	draw_circle(foot_pos, 4.0, col_steel_dark)
	draw_circle(foot_pos, 1.5, col_chrome)
	
	# Footpad plate: 36 px wide, 7 px thick, with curved toe
	var toe_raise: float = -3.0 if was_in_swing else 0.0
	var sole_points: PackedVector2Array = PackedVector2Array([
		foot_pos + Vector2(-16.0, 1.0),
		foot_pos + Vector2(16.0, 1.0),
		foot_pos + Vector2(20.0, -2.0 + toe_raise), # upturned ski toe
		foot_pos + Vector2(22.0, 3.0),
		foot_pos + Vector2(14.0, 6.0),
		foot_pos + Vector2(-16.0, 6.0)
	])
	draw_colored_polygon(sole_points, col_steel_mid)
	draw_polyline(sole_points, col_steel_dark, 1.2, true)
	
	# Skid Cleat Teeth
	for ox in [-10.0, 0.0, 10.0]:
		draw_rect(Rect2(foot_pos.x + ox - 2.0, foot_pos.y + 6.0, 4.0, 2.5), col_sole, true)
