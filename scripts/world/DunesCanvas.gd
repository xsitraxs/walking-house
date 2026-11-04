# scripts/world/DunesCanvas.gd
class_name DunesCanvas
extends Node2D

## Полуширина окна отрисовки в экранных координатах. Слой, который уже
## скомпенсирован по cam.x, всё равно должен покрывать весь вьюпорт
## (1280 px) с запасом, иначе справа/слева проступает clear color окна.
const PARALLAX_SPAN: float = 1400.0

## Rapid foreground snow dunes and wind-carved drifts sitting directly behind the track line.
## Motion scale: (0.60, 0.0).

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

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
	var local_cam_x: float = cx * 0.60
	var left_x: float = local_cam_x - PARALLAX_SPAN
	var right_x: float = local_cam_x + PARALLAX_SPAN

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
