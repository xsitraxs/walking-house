# scripts/world/GroundVisual.gd
class_name GroundVisual
extends Node2D

## High-performance procedural ground surface renderer.
## Features: F48 (Snow surface), F50 (Native vector graphics).
## Draws the layered permafrost ground plane from Y = 560 to Y = 720 px.

@onready var biome_mgr = get_node_or_null("../../BiomeManager")

const GROUND_SURFACE_Y: float = 560.0
const SCREEN_BOTTOM_Y: float = 720.0

func _ready() -> void:
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../../BiomeManager")
	if biome_mgr != null:
		biome_mgr.ambient_palette_updated.connect(func(_p): queue_redraw())

func _draw() -> void:
	var cam: Camera2D = null
	if get_viewport() != null:
		cam = get_viewport().get_camera_2d()
	var view_left: float = -100.0
	var view_right: float = 1380.0
	if cam != null:
		var cx: float = cam.global_position.x
		# Полуширина считается от реального вьюпорта: при окне шире 1280 px
		# (или зуме игрока 1.15) прежние +-740 px не доставали до краёв, и
		# справа/слева земля обрывалась прямой вертикальной границей.
		var half: float = 640.0
		if get_viewport() != null:
			half = get_viewport_rect().size.x * 0.5 * cam.zoom.x
		# Запас в 2 экрана: на скриншоте земля обрывалась на экранной x≈817,
		# хотя старый код считал, что покрывает +-740 — реальная видимая
		# область с учётом параллакса и стрейча оказалась шире.
		view_left = cx - half * 2.0
		view_right = cx + half * 2.0

	var palette: Dictionary = biome_mgr.get_active_palette() if biome_mgr != null else {}
	var c_snow_base: Color = palette.get("ground_snow_base", Color(0.92, 0.95, 0.98, 1.0))
	var c_snow_top: Color = palette.get("ground_snow_top", Color(1.0, 1.0, 1.0, 1.0))
	var c_soil_dark: Color = palette.get("ground_soil_dark", Color(0.12, 0.15, 0.20, 1.0))
	var c_sub_ice: Color = c_snow_base.lerp(c_soil_dark, 0.45)

	# 1. Deep Substratum Permafrost / Tundra Bed (Y: 580 to 720)
	var soil_rect := Rect2(view_left, 580.0, view_right - view_left, SCREEN_BOTTOM_Y - 580.0)
	draw_rect(soil_rect, c_soil_dark)

	# 2. Compacted Sub-Snow Ice Layer (Y: 566 to 580)
	var ice_rect := Rect2(view_left, 566.0, view_right - view_left, 14.0)
	draw_rect(ice_rect, c_sub_ice)

	# 3. Surface Crisp Snow Crust (Y: 560 to 566)
	var snow_rect := Rect2(view_left, GROUND_SURFACE_Y, view_right - view_left, 6.0)
	draw_rect(snow_rect, c_snow_base)

	# 4. Top Glimmer Snow Edge Line (Y = 560.0, width 2.0)
	draw_line(Vector2(view_left, GROUND_SURFACE_Y), Vector2(view_right, GROUND_SURFACE_Y), c_snow_top, 2.0)
