# scripts/world/DunesCanvas.gd
class_name DunesCanvas
extends Node2D

## Rapid foreground snow dunes and wind-carved drifts sitting directly behind the track line.
## Motion scale: (0.60, 0.0).

var _last_origin_x: float = NAN

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

## Слой обязан перерисовываться при движении камеры: ParallaxLayer сдвигает
## содержимое, а видимая область (её считает _visible_local_rect) меняется
## вместе с ней. Без этого _draw() вызывался один раз в _ready(), и дальше
## слой рисовал устаревшую область.
## Перерисовываем только когда слой реально сдвинулся — полная перерисовка
## полигонов каждый кадр на 60 fps не нужна.

func _process(_delta: float) -> void:
	var x: float = get_global_transform_with_canvas().origin.x
	if is_nan(_last_origin_x) or absf(x - _last_origin_x) > 0.5:
		_last_origin_x = x
		queue_redraw()

## Видимая область в ЛОКАЛЬНЫХ координатах этого узла.
## Никакой арифметики с motion_scale: берём фактическую трансформацию узла
## (её уже выставил ParallaxLayer) и переводим углы экрана в локальные
## координаты. Пусть Godot сам решает, куда сдвинулся слой — сколько бы
## раз мы ни ошибались в формуле, здесь ошибки быть не может.
func _visible_local_rect() -> Rect2:
	var size: Vector2 = Vector2(1280.0, 720.0)
	if get_viewport() != null:
		size = get_viewport_rect().size
	var xf: Transform2D = get_global_transform_with_canvas()
	var inv: Transform2D = xf.affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * size
	var pad: float = 64.0 # запас на дрожание камеры и сглаживание
	return Rect2(Vector2(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad),
		Vector2(absf(b.x - a.x) + pad * 2.0, absf(b.y - a.y) + pad * 2.0))


func _draw() -> void:
	# Никакого cam.x здесь: ParallaxLayer уже сдвигает содержимое сам.
	var vis: Rect2 = _visible_local_rect()
	var left_x: float = vis.position.x
	var right_x: float = vis.end.x

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
