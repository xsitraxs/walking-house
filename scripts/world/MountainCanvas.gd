# scripts/world/MountainCanvas.gd
class_name MountainCanvas
extends Node2D

## Procedural distant alpine crags, jagged peaks & atmospheric depth.
## Motion scale: (0.08, 0.0).

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

## Полуширина отрисовки в координатах слоя. Считается от реального размера
## вьюпорта с учётом зума, а не от константы: окно бывает шире 1280 px, а зум
## меняется между режимами дома (1.0) и игрока (1.15). Прежние фиксированные
## +-750 px не покрывали широкое окно, и справа проступал незакрашенный фон.
func _vis_half_span() -> float:
	var half: float = 640.0 # запасной минимум, если вьюпорта ещё нет
	if get_viewport() != null:
		half = get_viewport_rect().size.x * 0.5
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			half *= cam.zoom.x
	# Полтора экрана в каждую сторону — с запасом на сдвиг слоя.
	return half * 1.5 + 80.0

func _draw() -> void:
	var cam: Camera2D = null
	if get_viewport() != null:
		cam = get_viewport().get_camera_2d()
	var cx: float = cam.global_position.x if cam != null else 0.0
	var local_cam_x: float = cx * 0.08
	var half_span: float = _vis_half_span()
	var left_x: float = local_cam_x - half_span
	var right_x: float = local_cam_x + half_span

	var pal: Dictionary = biome_mgr.get_active_palette() if biome_mgr != null else {}
	var c_mount: Color = pal.get("mountain_tint", Color(0.35, 0.45, 0.58, 0.85))
	var c_snow: Color = pal.get("mountain_snow", Color(0.80, 0.88, 0.95, 0.70))

	# 1. Back Mountain Ridge (Taller, hazier, deep silhouettes)
	_draw_ridge(left_x, right_x, 290.0, 110.0, 50.0, 0.0018, 0.0042, c_mount.darkened(0.25), c_snow.darkened(0.2))

	# 2. Front Mountain Ridge (Sharper rocky crags)
	_draw_ridge(left_x, right_x, 350.0, 80.0, 40.0, 0.0028, 0.0065, c_mount, c_snow)

func _draw_ridge(left_x: float, right_x: float, base_y: float, a1: float, a2: float, f1: float, f2: float, col_rock: Color, col_snow: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(left_x, 560.0))

	var step: float = 20.0
	var cur_x: float = left_x - step
	while cur_x <= right_x + step:
		var h1: float = absf(sin(cur_x * f1)) * a1
		var h2: float = absf(cos(cur_x * f2 + 1.2)) * a2
		var y: float = base_y - h1 - h2
		pts.append(Vector2(cur_x, y))
		cur_x += step

	pts.append(Vector2(right_x + step, 560.0))
	draw_colored_polygon(pts, col_rock)

	var crest_pts := PackedVector2Array()
	for k in range(1, pts.size() - 2):
		crest_pts.append(pts[k])
	if crest_pts.size() >= 2:
		draw_polyline(crest_pts, col_snow, 2.0)
