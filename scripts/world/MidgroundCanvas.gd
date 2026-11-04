# scripts/world/MidgroundCanvas.gd
class_name MidgroundCanvas
extends Node2D

## Полуширина окна отрисовки в экранных координатах. Слой, который уже
## скомпенсирован по cam.x, всё равно должен покрывать весь вьюпорт
## (1280 px) с запасом, иначе справа/слева проступает clear color окна.
const PARALLAX_SPAN: float = 1400.0

## Procedural midground rolling hills and biome-specific visual storytelling props.
## Renders ruined tents, weathered posts, scrap cranes, dead pines, and outpost towers.
## Motion scale: (0.25, 0.0).

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

const CELL_SIZE: float = 120.0 # px per prop slot

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

func _draw() -> void:
	var cam: Camera2D = null
	if get_viewport() != null:
		cam = get_viewport().get_camera_2d()
	var cx: float = cam.global_position.x if cam != null else 0.0
	var local_cam_x: float = cx * 0.25
	var left_x: float = local_cam_x - PARALLAX_SPAN
	var right_x: float = local_cam_x + PARALLAX_SPAN

	var pal: Dictionary = biome_mgr.get_active_palette() if biome_mgr != null else {}
	var c_mid: Color = pal.get("midground_tint", Color(0.50, 0.60, 0.72))

	# 1. Rolling Midground Foothills Base Poly
	var hill_pts := PackedVector2Array()
	hill_pts.append(Vector2(left_x, 560.0))
	var step: float = 24.0
	var cur_x: float = left_x - step
	while cur_x <= right_x + step:
		var y: float = 460.0 - sin(cur_x * 0.004) * 35.0 - cos(cur_x * 0.011) * 15.0
		hill_pts.append(Vector2(cur_x, y))
		cur_x += step
	hill_pts.append(Vector2(right_x + step, 560.0))
	draw_colored_polygon(hill_pts, c_mid)

	# 2. Procedural Biome Props via Deterministic Cell Hashing
	var first_cell: int = int(left_x / CELL_SIZE) - 1
	var last_cell: int = int(right_x / CELL_SIZE) + 1

	for ci in range(first_cell, last_cell):
		var prop_local_x: float = float(ci) * CELL_SIZE + 60.0
		var world_dist_m: float = (prop_local_x / 0.25) / 20.0
		if world_dist_m < 0.0 or world_dist_m > 5050.0:
			continue

		var biome_idx: int = clampi(int(world_dist_m / 1000.0), 0, 4)
		var hill_y: float = 460.0 - sin(prop_local_x * 0.004) * 35.0 - cos(prop_local_x * 0.011) * 15.0
		var p_pos := Vector2(prop_local_x, hill_y)

		var h: int = int(absf(sin(float(ci) * 12.9898 + 31.337) * 43758.5453))
		var chance: float = float(h % 100) / 100.0

		match biome_idx:
			0: # Snowy Plains (Sparse dunes & stakes, 30% chance)
				if chance < 0.30:
					if (h % 2) == 0:
						_draw_waypoint_stake(p_pos, c_mid)
					else:
						_draw_sastrugi_dune(p_pos, c_mid)
			1: # Abandoned Camp (Tents, poles, fences, 45% chance)
				if chance < 0.45:
					var prop_type: int = h % 3
					if prop_type == 0:
						_draw_collapsed_tent(p_pos, c_mid)
					elif prop_type == 1:
						_draw_telegraph_pole(p_pos, c_mid)
					else:
						_draw_snow_fence(p_pos, c_mid)
			2: # Machinery Graveyard (Wrecks, cranes, scrap, 50% chance)
				if chance < 0.50:
					var prop_type: int = h % 3
					if prop_type == 0:
						_draw_vehicle_wreck(p_pos, c_mid)
					elif prop_type == 1:
						_draw_lattice_crane(p_pos, c_mid)
					else:
						_draw_scrap_heap(p_pos, c_mid)
			3: # Frozen Forest (Dead pines & birches, 80% dense forest)
				if chance < 0.80:
					if (h % 3) == 0:
						_draw_birch_tree(p_pos, c_mid)
					else:
						_draw_pine_tree(p_pos, c_mid, 50.0 + float(h % 35))
			4: # Station Outskirts (Towers, lights, signals, 55% chance)
				if chance < 0.55:
					var prop_type: int = h % 3
					if prop_type == 0:
						_draw_radio_antenna(p_pos, c_mid)
					elif prop_type == 1:
						_draw_floodlight_tower(p_pos, c_mid)
					else:
						_draw_rail_semaphore(p_pos, c_mid)

	# Terminus: Polar Station Goal Gate (at 5000m -> local X ≈ 25000)
	var goal_local_x: float = (5000.0 * 20.0) * 0.25 # 25,000 px
	if right_x >= goal_local_x - 300.0 and left_x <= goal_local_x + 300.0:
		_draw_station_gate_monolith(Vector2(goal_local_x, 430.0), c_mid)

# ------------------------------------------------------------------------------
# PROCEDURAL PROP VECTOR DRAWING ROUTINES (F50)
# ------------------------------------------------------------------------------
func _draw_waypoint_stake(pos: Vector2, col: Color) -> void:
	draw_line(pos, pos - Vector2(0, 32), col.darkened(0.4), 2.0)
	var flag := PackedVector2Array([
		pos - Vector2(0, 32),
		pos - Vector2(-14, 26),
		pos - Vector2(0, 20)
	])
	draw_colored_polygon(flag, Color(0.85, 0.32, 0.22, col.a))

func _draw_sastrugi_dune(pos: Vector2, col: Color) -> void:
	var dune := PackedVector2Array([
		pos + Vector2(-35, 0),
		pos + Vector2(-10, -9),
		pos + Vector2(25, -4),
		pos + Vector2(35, 0)
	])
	draw_colored_polygon(dune, col.lightened(0.15))

func _draw_collapsed_tent(pos: Vector2, col: Color) -> void:
	var tent := PackedVector2Array([
		pos + Vector2(-22, 0),
		pos + Vector2(-5, -20),
		pos + Vector2(16, 0)
	])
	draw_colored_polygon(tent, col.darkened(0.35))
	draw_line(pos + Vector2(-5, -20), pos + Vector2(-5, 0), col.darkened(0.6), 1.5)
	draw_line(pos + Vector2(-5, -20), pos + Vector2(24, 0), col.darkened(0.6), 1.0)

func _draw_telegraph_pole(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.5)
	draw_line(pos, pos - Vector2(2, 45), dark, 2.5)
	draw_line(pos - Vector2(12, 40), pos - Vector2(-8, 38), dark, 2.0)
	draw_line(pos - Vector2(12, 40), pos - Vector2(45, 30), dark, 1.0)

func _draw_snow_fence(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.4)
	for ox in [-15, -7, 1, 9, 17]:
		draw_line(pos + Vector2(ox, 0), pos + Vector2(ox + 2, -16), dark, 2.0)
	draw_line(pos + Vector2(-16, -10), pos + Vector2(18, -8), dark, 1.5)

func _draw_vehicle_wreck(pos: Vector2, col: Color) -> void:
	var rust: Color = col.lerp(Color(0.45, 0.22, 0.15), 0.6)
	var hull := PackedVector2Array([
		pos + Vector2(-28, 0),
		pos + Vector2(-22, -14),
		pos + Vector2(15, -14),
		pos + Vector2(24, 0)
	])
	draw_colored_polygon(hull, rust)
	draw_rect(Rect2(pos.x - 10, pos.y - 24, 16, 10), rust.darkened(0.2))
	draw_circle(pos + Vector2(-15, -3), 4.0, rust.darkened(0.4))
	draw_circle(pos + Vector2(12, -3), 4.0, rust.darkened(0.4))

func _draw_lattice_crane(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.55)
	draw_line(pos + Vector2(-8, 0), pos + Vector2(-2, -60), dark, 2.0)
	draw_line(pos + Vector2(8, 0), pos + Vector2(2, -60), dark, 2.0)
	for y_sub in [12, 24, 36, 48]:
		draw_line(pos + Vector2(-7, -y_sub), pos + Vector2(5, -y_sub - 8), dark, 1.0)

func _draw_scrap_heap(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.4)
	var poly := PackedVector2Array([
		pos + Vector2(-20, 0),
		pos + Vector2(-12, -18),
		pos + Vector2(2, -12),
		pos + Vector2(14, -22),
		pos + Vector2(22, 0)
	])
	draw_colored_polygon(poly, dark)

func _draw_pine_tree(pos: Vector2, col: Color, height: float) -> void:
	var dark := col.darkened(0.65)
	draw_line(pos, pos - Vector2(0, height), dark, 3.0)
	var tiers: int = 4
	for ti in range(tiers):
		var frac: float = float(ti + 1) / float(tiers + 1)
		var by: float = pos.y - (height * frac)
		var bw: float = (1.0 - frac * 0.7) * 26.0
		var bough := PackedVector2Array([
			Vector2(pos.x - bw, by + 6),
			Vector2(pos.x, by - 8),
			Vector2(pos.x + bw, by + 6)
		])
		draw_colored_polygon(bough, dark)
		draw_line(Vector2(pos.x - bw + 2, by + 4), Vector2(pos.x + bw - 2, by + 4), col.lightened(0.3), 1.5)

func _draw_birch_tree(pos: Vector2, col: Color) -> void:
	var c_birch := Color(0.85, 0.88, 0.90, col.a)
	var dark := col.darkened(0.7)
	draw_line(pos, pos - Vector2(3, 42), c_birch, 2.5)
	for ky in [8, 18, 28, 36]:
		draw_line(pos - Vector2(4, ky), pos - Vector2(1, ky), dark, 1.5)
	draw_line(pos - Vector2(3, 42), pos - Vector2(14, 56), c_birch, 1.5)

func _draw_radio_antenna(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.5)
	draw_line(pos + Vector2(-10, 0), pos - Vector2(0, 90), dark, 2.0)
	draw_line(pos + Vector2(10, 0), pos - Vector2(0, 90), dark, 2.0)
	for y in range(15, 85, 15):
		draw_line(pos + Vector2(-8, -y), pos + Vector2(8, -y), dark, 1.0)
	var t: float = float(Time.get_ticks_msec()) * 0.005
	var beacon_alpha: float = 0.5 + 0.5 * sin(t * 3.0)
	draw_circle(pos - Vector2(0, 92), 3.5, Color(1.0, 0.2, 0.2, beacon_alpha))

func _draw_floodlight_tower(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.45)
	draw_line(pos, pos - Vector2(0, 60), dark, 3.0)
	draw_circle(pos - Vector2(0, 60), 4.0, Color(1.0, 0.9, 0.5))
	var cone := PackedVector2Array([
		pos - Vector2(0, 60),
		pos + Vector2(-45, 0),
		pos + Vector2(15, 0)
	])
	draw_colored_polygon(cone, Color(1.0, 0.85, 0.45, 0.18))

func _draw_rail_semaphore(pos: Vector2, col: Color) -> void:
	var dark := col.darkened(0.5)
	draw_line(pos, pos - Vector2(0, 40), dark, 2.5)
	draw_circle(pos - Vector2(0, 36), 3.0, Color(0.2, 0.9, 0.3, 0.9))

func _draw_station_gate_monolith(pos: Vector2, col: Color) -> void:
	var c_gate: Color = col.darkened(0.6)
	var gate_rect := Rect2(pos.x - 70, pos.y - 120, 140, 120)
	draw_rect(gate_rect, c_gate)
	draw_rect(Rect2(pos.x - 35, pos.y - 70, 70, 70), Color(0.95, 0.85, 0.55, 0.35))
	for cx in range(-60, 60, 18):
		draw_line(Vector2(pos.x + cx, pos.y - 110), Vector2(pos.x + cx + 10, pos.y - 95), Color(0.9, 0.75, 0.15), 3.0)
