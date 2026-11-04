# scripts/world/GameCamera.gd
class_name GameCamera
extends Camera2D

## Dynamic Follow Camera for «Шагающий дом».
## Smoothly transitions tracking, lookahead, and zoom between WalkingHouse and Player.
## Constrained to world bounds [0, 101000] px horizontally and [0, 720] px vertically.

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")

@export var target_house: Node2D
@export var target_player: Node2D

const ZOOM_HOUSE := Vector2(1.0, 1.0)
const ZOOM_PLAYER := Vector2(1.15, 1.15)
const SMOOTH_SPEED: float = 3.5
const ZOOM_SPEED: float = 2.5

var is_player_focused: bool = false
var lookahead_x: float = 0.0
var target_lookahead_x: float = 0.0
var shake_trauma: float = 0.0

func _ready() -> void:
	# World limits (0 to 101,000 px horizontally, -250 to 720 vertically)
	limit_left = 0
	limit_right = int(BalanceConfig.WORLD_WIDTH_PIXELS + 1000.0)
	limit_top = -250
	limit_bottom = 720
	position_smoothing_enabled = false # Custom lerp in process gives precise control
	
	_connect_event_bus()

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus != null:
		if bus.has_signal("player_mode_changed"):
			bus.connect("player_mode_changed", Callable(self, "_on_player_mode_changed"))
		if bus.has_signal("player_disembarked"):
			bus.connect("player_disembarked", Callable(self, "_on_player_disembarked"))
		if bus.has_signal("player_embarked"):
			bus.connect("player_embarked", Callable(self, "_on_player_embarked"))

func _on_player_mode_changed(is_outside: bool) -> void:
	is_player_focused = is_outside

func _on_player_disembarked() -> void:
	is_player_focused = true

func _on_player_embarked() -> void:
	is_player_focused = false

func add_trauma(amount: float) -> void:
	shake_trauma = clampf(shake_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
		
	var target_node: Node2D = target_player if (is_player_focused and target_player != null and target_player.visible) else target_house
	if target_node == null:
		return
		
	# Compute lookahead based on active entity velocity/direction
	if is_player_focused and target_player is CharacterBody2D:
		var vel_x: float = target_player.velocity.x
		target_lookahead_x = signf(vel_x) * 40.0 if absf(vel_x) > 2.0 else 0.0
	elif target_house != null and "current_speed" in target_house:
		var spd: float = target_house.current_speed
		target_lookahead_x = signf(spd) * 80.0 if absf(spd) > 0.05 else 0.0
	else:
		target_lookahead_x = 0.0
		
	lookahead_x = lerpf(lookahead_x, target_lookahead_x, delta * 2.0)
	
	# Target world position (center vertically at Y=360 so sky and snow ground are balanced)
	var desired_y: float = 360.0
	var desired_pos := Vector2(target_node.global_position.x + lookahead_x, desired_y)
	global_position = global_position.lerp(desired_pos, delta * SMOOTH_SPEED)
	
	# Target zoom
	var desired_zoom: Vector2 = ZOOM_PLAYER if is_player_focused else ZOOM_HOUSE
	zoom = zoom.lerp(desired_zoom, delta * ZOOM_SPEED)
	
	# Camera shake trauma decay
	if shake_trauma > 0.0:
		shake_trauma = maxf(0.0, shake_trauma - delta * 1.5)
		var shake_offset := Vector2(
			(randf() * 2.0 - 1.0) * 8.0 * shake_trauma,
			(randf() * 2.0 - 1.0) * 8.0 * shake_trauma
		)
		offset = shake_offset
	else:
		offset = Vector2.ZERO

func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null
