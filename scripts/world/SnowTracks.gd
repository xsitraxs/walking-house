# scripts/world/SnowTracks.gd
class_name SnowTracks
extends Node2D

## High-performance snow tracks manager for «Шагающий дом».
## Renders footprints in a single CanvasItem._draw() call using a fixed-size ring buffer.
## Positioned in World coordinates so tracks remain fixed on the ground as the house moves.

const MAX_TRACKS: int = 120
const TRACK_LIFETIME_BASE: float = 45.0 # Seconds before track completely fills with snow

# Data record per footprint
class FootTrack:
	var pos: Vector2
	var width: float
	var facing: float
	var age: float = 0.0
	var max_age: float = TRACK_LIFETIME_BASE

var tracks: Array[FootTrack] = []
var blizzard_active: bool = false

func _ready() -> void:
	var bus: Node = null
	if Engine.has_singleton("EventBus"):
		bus = Engine.get_singleton("EventBus")
	elif is_inside_tree() and get_tree().root.has_node("EventBus"):
		bus = get_tree().root.get_node("EventBus")
		
	if bus != null:
		if bus.has_signal("blizzard_started"):
			bus.connect("blizzard_started", Callable(self, "_on_blizzard_started"))
		if bus.has_signal("blizzard_ended"):
			bus.connect("blizzard_ended", Callable(self, "_on_blizzard_ended"))

func add_track(world_pos: Vector2, width: float = 28.0, facing: float = 1.0) -> void:
	var t := FootTrack.new()
	t.pos = world_pos
	t.width = width
	t.facing = facing
	t.age = 0.0
	t.max_age = TRACK_LIFETIME_BASE
	
	if tracks.size() >= MAX_TRACKS:
		tracks.pop_front()
	tracks.append(t)
	queue_redraw()

func clear_tracks() -> void:
	tracks.clear()
	queue_redraw()

func get_track_count() -> int:
	return tracks.size()

func has_track_near(target_pos: Vector2, radius: float = 20.0) -> bool:
	for t in tracks:
		if t.pos.distance_to(target_pos) <= radius:
			return true
	return false

func _on_blizzard_started() -> void:
	blizzard_active = true

func _on_blizzard_ended() -> void:
	blizzard_active = false

func _process(delta: float) -> void:
	if tracks.is_empty():
		return
	
	# Accelerated burial during blizzards (4x faster)
	var age_mult: float = 4.0 if blizzard_active else 1.0
	var needs_redraw: bool = false
	var i: int = tracks.size() - 1
	
	while i >= 0:
		tracks[i].age += delta * age_mult
		if tracks[i].age >= tracks[i].max_age:
			tracks.remove_at(i)
			needs_redraw = true
		else:
			needs_redraw = true
		i -= 1
	
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var view_left: float = -1000000.0
	var view_right: float = 1000000.0
	
	var vp = get_viewport()
	if vp != null:
		var cam = vp.get_camera_2d()
		if cam != null:
			var cam_x: float = cam.global_position.x
			view_left = cam_x - 700.0
			view_right = cam_x + 700.0
	
	for t in tracks:
		# Frustum culling
		if t.pos.x < view_left or t.pos.x > view_right:
			continue
		
		var alpha: float = clampf(1.0 - (t.age / t.max_age), 0.0, 1.0)
		_draw_footprint(t.pos, t.width, alpha)

func _draw_footprint(pos: Vector2, w: float, alpha: float) -> void:
	var half_w: float = w * 0.5
	var depth: float = 6.0
	
	# 1. Compacted Shadow Trench (Pressed snow bed)
	var trench := PackedVector2Array([
		pos + Vector2(-half_w, 0),
		pos + Vector2(-half_w + 2.0, depth),
		pos + Vector2(half_w - 2.0, depth),
		pos + Vector2(half_w, 0)
	])
	draw_colored_polygon(trench, Color(0.55, 0.65, 0.78, alpha * 0.65))
	
	# 2. Pushed Snow Berm (Displaced ridges on sides)
	draw_line(pos + Vector2(-half_w - 3.0, -1.0), pos + Vector2(-half_w, 0), Color(0.98, 0.99, 1.0, alpha * 0.75), 2.0)
	draw_line(pos + Vector2(half_w, 0), pos + Vector2(half_w + 3.0, -1.0), Color(0.98, 0.99, 1.0, alpha * 0.75), 2.0)
	
	# 3. Transverse Cleat / Tread Marks
	var cleat_color := Color(0.42, 0.50, 0.62, alpha * 0.6)
	draw_line(pos + Vector2(-half_w * 0.5, 1.0), pos + Vector2(-half_w * 0.5, depth - 1.0), cleat_color, 1.5)
	draw_line(pos + Vector2(0, 1.0), pos + Vector2(0, depth - 1.0), cleat_color, 1.5)
	draw_line(pos + Vector2(half_w * 0.5, 1.0), pos + Vector2(half_w * 0.5, depth - 1.0), cleat_color, 1.5)
