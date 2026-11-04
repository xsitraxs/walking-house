# scripts/world/DunesCanvas.gd
class_name DunesCanvas
extends Node2D

## Совпадает с motion_scale этого ParallaxLayer в World.tscn.
const MOTION_SCALE: float = 0.60

## Rapid foreground snow dunes and wind-carved drifts sitting directly behind the track line.
## Motion scale: (0.60, 0.0).

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

## Полуширина отрисовки в координатах слоя.
## Компенсацию параллакса делает сам ParallaxLayer, поэтому рисовать нужно
## вокруг локального нуля, а ширину брать с запасом на сдвиг -cam.x * MOTION_SCALE.
func _vis_half_span() -> float:
	var half: float = 640.0 # запасной минимум, если вьюпорта ещё нет
	if get_viewport() != null:
		half = get_viewport_rect().size.x * 0.5
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			half *= cam.zoom.x
	# ParallaxLayer сдвигает содержимое на -cam.x * MOTION_SCALE, поэтому
	# слабопараллаксный слой уезжает почти настолько же, насколько сдвинут
	# сам экран: ему нужна почти полная полуширина плюс запас на зум.
	# Раньше стояло span = half * 1.5 без учёта слоя — для Sky при cam.x = 640
	# правый край приходился ровно на x = 1066, и дальше был чистый фон.
	return half * (1.0 + MOTION_SCALE) + 80.0

func _draw() -> void:
	# Никакого cam.x здесь: ParallaxLayer уже сдвигает содержимое сам.
	var half_span: float = _vis_half_span()
	var left_x: float = -half_span
	var right_x: float = half_span

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
