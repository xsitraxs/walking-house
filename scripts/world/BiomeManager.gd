# scripts/world/BiomeManager.gd
class_name BiomeManager
extends Node2D

## Active Biome Detector, Atmosphere Coordinator & Procedural Palette Interpolator.
## Features: F48 (5 Distinct Biomes), F49 (Parallax coordination), F50 (Native vector art).

signal biome_changed(biome_index: int, biome_info: Dictionary)
signal biome_transition_updated(from_index: int, to_index: int, blend_factor: float)
signal ambient_palette_updated(palette: Dictionary)

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")

const TRANSITION_HALF_WIDTH_METERS: float = 50.0 # 100m total blend zone

# ------------------------------------------------------------------------------
# BIOME PALETTE SPECIFICATIONS (Pure Godot Colors)
# ------------------------------------------------------------------------------
const BIOME_PALETTES: Array[Dictionary] = [
	{
		"index": 0,
		"id": "snowy_plains",
		"name": "Заснеженная равнина",
		"start_m": 0.0,
		"end_m": 1000.0,
		"sky_zenith": Color(0.20, 0.32, 0.44, 1.0),
		"sky_horizon": Color(0.65, 0.78, 0.86, 1.0),
		"ambient_modulate": Color(0.92, 0.96, 1.0, 1.0),
		"mountain_tint": Color(0.35, 0.45, 0.58, 0.85),
		"mountain_snow": Color(0.80, 0.88, 0.95, 0.70),
		"midground_tint": Color(0.50, 0.60, 0.72, 1.0),
		"dunes_tint": Color(0.75, 0.84, 0.92, 1.0),
		"ground_snow_base": Color(0.92, 0.95, 0.98, 1.0),
		"ground_snow_top": Color(1.0, 1.0, 1.0, 1.0),
		"ground_soil_dark": Color(0.12, 0.15, 0.20, 1.0),
		"wind_intensity": 0.45,
		"aurora_alpha": 1.0,
		"star_alpha": 0.8
	},
	{
		"index": 1,
		"id": "abandoned_camp",
		"name": "Заброшенный лагерь геологов",
		"start_m": 1000.0,
		"end_m": 2000.0,
		"sky_zenith": Color(0.18, 0.22, 0.28, 1.0),
		"sky_horizon": Color(0.48, 0.54, 0.60, 1.0),
		"ambient_modulate": Color(0.84, 0.86, 0.90, 1.0),
		"mountain_tint": Color(0.24, 0.28, 0.35, 0.90),
		"mountain_snow": Color(0.68, 0.74, 0.80, 0.60),
		"midground_tint": Color(0.38, 0.42, 0.48, 1.0),
		"dunes_tint": Color(0.65, 0.70, 0.76, 1.0),
		"ground_snow_base": Color(0.85, 0.87, 0.90, 1.0),
		"ground_snow_top": Color(0.95, 0.96, 0.98, 1.0),
		"ground_soil_dark": Color(0.14, 0.14, 0.16, 1.0),
		"wind_intensity": 0.35,
		"aurora_alpha": 0.25,
		"star_alpha": 0.4
	},
	{
		"index": 2,
		"id": "machinery_graveyard",
		"name": "Кладбище техники",
		"start_m": 2000.0,
		"end_m": 3000.0,
		"sky_zenith": Color(0.16, 0.15, 0.22, 1.0),
		"sky_horizon": Color(0.44, 0.34, 0.36, 1.0),
		"ambient_modulate": Color(0.82, 0.76, 0.78, 1.0),
		"mountain_tint": Color(0.20, 0.18, 0.24, 0.95),
		"mountain_snow": Color(0.55, 0.52, 0.58, 0.50),
		"midground_tint": Color(0.32, 0.28, 0.30, 1.0),
		"dunes_tint": Color(0.58, 0.54, 0.56, 1.0),
		"ground_snow_base": Color(0.78, 0.76, 0.78, 1.0),
		"ground_snow_top": Color(0.90, 0.88, 0.90, 1.0),
		"ground_soil_dark": Color(0.18, 0.14, 0.12, 1.0),
		"wind_intensity": 0.40,
		"aurora_alpha": 0.50,
		"star_alpha": 0.6
	},
	{
		"index": 3,
		"id": "frozen_forest",
		"name": "Замёрзший лес",
		"start_m": 3000.0,
		"end_m": 4000.0,
		"sky_zenith": Color(0.10, 0.17, 0.15, 1.0),
		"sky_horizon": Color(0.28, 0.38, 0.34, 1.0),
		"ambient_modulate": Color(0.74, 0.82, 0.80, 1.0),
		"mountain_tint": Color(0.16, 0.22, 0.20, 0.95),
		"mountain_snow": Color(0.50, 0.62, 0.58, 0.55),
		"midground_tint": Color(0.22, 0.30, 0.26, 1.0),
		"dunes_tint": Color(0.48, 0.58, 0.54, 1.0),
		"ground_snow_base": Color(0.72, 0.78, 0.82, 1.0),
		"ground_snow_top": Color(0.88, 0.92, 0.95, 1.0),
		"ground_soil_dark": Color(0.10, 0.14, 0.12, 1.0),
		"wind_intensity": 0.20,
		"aurora_alpha": 0.85,
		"star_alpha": 0.9
	},
	{
		"index": 4,
		"id": "station_outskirts",
		"name": "Окрестности станции «Полюс»",
		"start_m": 4000.0,
		"end_m": 5000.0,
		"sky_zenith": Color(0.12, 0.15, 0.22, 1.0),
		"sky_horizon": Color(0.48, 0.38, 0.32, 1.0),
		"ambient_modulate": Color(0.92, 0.88, 0.84, 1.0),
		"mountain_tint": Color(0.18, 0.20, 0.28, 0.95),
		"mountain_snow": Color(0.65, 0.70, 0.80, 0.65),
		"midground_tint": Color(0.30, 0.32, 0.38, 1.0),
		"dunes_tint": Color(0.62, 0.64, 0.70, 1.0),
		"ground_snow_base": Color(0.85, 0.88, 0.94, 1.0),
		"ground_snow_top": Color(1.0, 0.98, 0.92, 1.0),
		"ground_soil_dark": Color(0.14, 0.15, 0.18, 1.0),
		"wind_intensity": 0.30,
		"aurora_alpha": 0.95,
		"star_alpha": 0.85
	}
]

var current_distance_m: float = 0.0
var active_biome_index: int = 0
var current_palette: Dictionary = {}

@onready var world_modulate: CanvasModulate = get_node_or_null("../WorldCanvasModulate")

func _ready() -> void:
	current_palette = BIOME_PALETTES[0].duplicate(true)
	_connect_event_bus()
	update_distance(0.0)

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("house_moved"):
		bus.connect("house_moved", Callable(self, "_on_house_moved"))

func _on_house_moved(_delta_m: float, total_distance: float) -> void:
	update_distance(total_distance)

func update_distance(dist_m: float) -> void:
	current_distance_m = clampf(dist_m, 0.0, BalanceConfig.ROUTE_LENGTH_METERS)
	
	# Transition detection: check proximity to boundary
	var nearest_boundary_idx: int = int(round(current_distance_m / BalanceConfig.BIOME_LENGTH_METERS))
	if nearest_boundary_idx >= 1 and nearest_boundary_idx <= 4:
		var boundary_m: float = float(nearest_boundary_idx) * BalanceConfig.BIOME_LENGTH_METERS
		var delta_boundary: float = current_distance_m - boundary_m
		if absf(delta_boundary) <= TRANSITION_HALF_WIDTH_METERS:
			var idx_from: int = nearest_boundary_idx - 1
			var idx_to: int = nearest_boundary_idx
			var s: float = (delta_boundary + TRANSITION_HALF_WIDTH_METERS) / (2.0 * TRANSITION_HALF_WIDTH_METERS)
			var blend_factor: float = s * s * (3.0 - 2.0 * s)
			_blend_palettes(idx_from, idx_to, blend_factor)
			emit_signal("biome_transition_updated", idx_from, idx_to, blend_factor)
			_apply_palette()
			emit_signal("ambient_palette_updated", current_palette)
			return

	var base_idx: int = clampi(int(current_distance_m / BalanceConfig.BIOME_LENGTH_METERS), 0, 4)
	if base_idx != active_biome_index:
		active_biome_index = base_idx
		emit_signal("biome_changed", active_biome_index, BIOME_PALETTES[active_biome_index])
	_copy_palette(base_idx)
	_apply_palette()
	emit_signal("ambient_palette_updated", current_palette)

func _blend_palettes(idx_a: int, idx_b: int, t: float) -> void:
	var pal_a: Dictionary = BIOME_PALETTES[idx_a]
	var pal_b: Dictionary = BIOME_PALETTES[idx_b]
	
	for key in pal_a.keys():
		var val_a = pal_a[key]
		var val_b = pal_b[key]
		if val_a is Color and val_b is Color:
			current_palette[key] = val_a.lerp(val_b, t)
		elif val_a is float and val_b is float:
			current_palette[key] = lerpf(val_a, val_b, t)
		else:
			current_palette[key] = val_b if t >= 0.5 else val_a

func _copy_palette(idx: int) -> void:
	var pal: Dictionary = BIOME_PALETTES[idx]
	for key in pal.keys():
		current_palette[key] = pal[key]

func _apply_palette() -> void:
	if world_modulate == null:
		world_modulate = get_node_or_null("../WorldCanvasModulate")
	if world_modulate != null and current_palette.has("ambient_modulate"):
		world_modulate.color = current_palette["ambient_modulate"]
		
	var sm: Node = _get_sound_manager()
	var gs: Node = _get_game_state()
	# Only update wind intensity if not in an active blizzard squall
	if sm != null and (gs == null or not gs.is_blizzard):
		var target_wind: float = current_palette.get("wind_intensity", 0.3)
		if sm.has_method("set_wind_intensity"):
			sm.set_wind_intensity(target_wind)

func get_active_palette() -> Dictionary:
	return current_palette.duplicate(true)

func get_biome_at(distance_m: float) -> Dictionary:
	var idx: int = clampi(int(distance_m / BalanceConfig.BIOME_LENGTH_METERS), 0, 4)
	return BIOME_PALETTES[idx]

func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null

func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState")
	return null

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null
