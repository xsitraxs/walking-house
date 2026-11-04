# scripts/world/DunesCanvas.gd
class_name DunesCanvas
extends Node2D

## Rapid foreground snow dunes and wind-carved drifts sitting directly behind the track line.
## Motion scale: (0.60, 0.0).

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
	var local_cam_x: float = cx * 0.60
	var half_span: float = _vis_half_span()
	var left_x: float = local_cam_x - half_span
	var right_x: float = local_cam_x + half_span

	var pal: Dictionary = biome_mgr.get_active_palette() if biome_mgr != null else {}
	var c_dune: Color = pal.get("dunes_tint", Color(0.75, 0.84, 0.92))
	var c_top: Color = pal.get("ground_snow_top", Color(1.0, 1.0, 1.0))

	var pts := PackedVector2Array()
	pts.append(Vector2(left_x, 560.0))

	var step: float = 20.0
	var cur_x: float = left_x - step
	while cur_x <= right_x + step:
		var y: float = 525.0 + sin(cur_x * 0.008 + 1.0) * 18.0 + cos(cur_x * 0.021) * 8.0
		pts.append(Vector2(cur_x, y))
		cur_x += step

	pts.append(Vector2(right_x + step, 560.0))
	draw_colored_polygon(pts, c_dune)

	var crest_pts := PackedVector2Array()
	for k in range(1, pts.size() - 2):
		crest_pts.append(pts[k])
	if crest_pts.size() >= 2:
		draw_polyline(crest_pts, c_top, 1.8)
