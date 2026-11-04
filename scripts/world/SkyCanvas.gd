# scripts/world/SkyCanvas.gd
class_name SkyCanvas
extends Node2D

## Полуширина окна отрисовки в экранных координатах. Слой, который уже
## скомпенсирован по cam.x, всё равно должен покрывать весь вьюпорт
## (1280 px) с запасом, иначе справа/слева проступает clear color окна.
const PARALLAX_SPAN: float = 1400.0

## Procedural sky dome, twinkling star field & flowing Aurora Borealis curtains.
## Motion scale: (0.02, 0.0).

@onready var biome_mgr = get_node_or_null("../../../BiomeManager")

var anim_time: float = 0.0
var redraw_accum: float = 0.0

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

func _process(delta: float) -> void:
	anim_time += delta
	redraw_accum += delta
	if redraw_accum >= 0.05: # Throttle redraw to 20 FPS for performance
		redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	var cam: Camera2D = null
	if get_viewport() != null:
		cam = get_viewport().get_camera_2d()
	var cx: float = cam.global_position.x if cam != null else 0.0
	var local_cam_x: float = cx * 0.02
	var left_x: float = local_cam_x - PARALLAX_SPAN
	var right_x: float = local_cam_x + PARALLAX_SPAN

	var pal: Dictionary = biome_mgr.get_active_palette() if biome_mgr != null else {}
	var c_zenith: Color = pal.get("sky_zenith", Color(0.20, 0.32, 0.44))
	var c_horizon: Color = pal.get("sky_horizon", Color(0.65, 0.78, 0.86))
	var aurora_alpha: float = pal.get("aurora_alpha", 1.0)
	var star_alpha: float = pal.get("star_alpha", 0.8)

	# 1. Sky Gradient (Zenith -> Horizon) via 4-vertex quad
	var sky_pts := PackedVector2Array([
		Vector2(left_x, 0.0),
		Vector2(right_x, 0.0),
		Vector2(right_x, 560.0),
		Vector2(left_x, 560.0)
	])
	var sky_cols := PackedColorArray([c_zenith, c_zenith, c_horizon, c_horizon])
	draw_polygon(sky_pts, sky_cols)

	# 2. Twinkling Sub-Polar Stars (upper sky Y in [20, 280])
	if star_alpha > 0.05:
		var start_col_idx: int = int(left_x / 30.0)
		var end_col_idx: int = int(right_x / 30.0) + 1
		for i in range(start_col_idx, end_col_idx):
			var h: int = int(absf(sin(float(i) * 127.1) * 43758.5453))
			var star_x: float = float(i) * 30.0 + float(h % 25)
			var star_y: float = 20.0 + float((h / 100) % 240)
			var twinkle: float = 0.5 + 0.5 * sin(anim_time * 2.5 + float(h % 10))
			var col := Color(0.9, 0.95, 1.0, star_alpha * twinkle * 0.75)
			draw_circle(Vector2(star_x, star_y), 1.2, col)

	# 3. Sinusoidal Aurora Borealis Curtain Wave
	if aurora_alpha > 0.05:
		_draw_aurora_ribbon(left_x, right_x, anim_time, aurora_alpha)

func _draw_aurora_ribbon(left_x: float, right_x: float, t: float, alpha: float) -> void:
	var pts_top := PackedVector2Array()
	var pts_mid := PackedVector2Array()
	var pts_bot := PackedVector2Array()

	var step: float = 25.0
	var cur_x: float = left_x - step
	while cur_x <= right_x + step:
		var w1: float = sin(cur_x * 0.003 + t * 0.6) * 35.0
		var w2: float = cos(cur_x * 0.007 - t * 0.4) * 18.0
		var y_base: float = 120.0 + w1 + w2
		var curtain_h: float = 70.0 + sin(cur_x * 0.005 + t * 0.8) * 20.0

		pts_top.append(Vector2(cur_x, y_base - curtain_h * 0.5))
		pts_mid.append(Vector2(cur_x, y_base))
		pts_bot.append(Vector2(cur_x, y_base + curtain_h * 0.5))
		cur_x += step

	for j in range(pts_top.size() - 1):
		var quad1 := PackedVector2Array([pts_top[j], pts_top[j+1], pts_mid[j+1], pts_mid[j]])
		var col_top := Color(0.2, 0.9, 0.6, 0.0)
		var col_mid := Color(0.25, 0.95, 0.65, 0.35 * alpha)
		draw_polygon(quad1, PackedColorArray([col_top, col_top, col_mid, col_mid]))

		var quad2 := PackedVector2Array([pts_mid[j], pts_mid[j+1], pts_bot[j+1], pts_bot[j]])
		var col_bot := Color(0.55, 0.20, 0.85, 0.0)
		draw_polygon(quad2, PackedColorArray([col_mid, col_mid, col_bot, col_bot]))
