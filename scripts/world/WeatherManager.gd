# scripts/world/WeatherManager.gd
class_name WeatherManager
extends Node2D

## Master Weather, Day/Night Cycle & Atmospheric Cataclysm Coordinator.
## Features: F42 (Day/Night Cycle), F43 (Dynamic Blizzard), F44 (Advance Warning), F51 (Lighting Modulation).

const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")

# ------------------------------------------------------------------------------
# CONSTANTS
# ------------------------------------------------------------------------------
const CYCLE_DURATION: float = BalanceConfig.DAY_NIGHT_CYCLE_DURATION
const DAY_DURATION: float = BalanceConfig.DAY_DURATION
const DUSK_DURATION: float = BalanceConfig.DUSK_DURATION
const NIGHT_DURATION: float = BalanceConfig.NIGHT_DURATION
const DAWN_DURATION: float = BalanceConfig.DAWN_DURATION

const BLIZZARD_WARNING_LEAD_TIME: float = BalanceConfig.BLIZZARD_WARNING_LEAD_TIME
const BLIZZARD_EVENTS: Array[Dictionary] = BalanceConfig.BLIZZARD_EVENTS

# ------------------------------------------------------------------------------
# BLIZZARD EVENT STATE MACHINE
# ------------------------------------------------------------------------------
enum BlizzardPhase {
	IDLE = 0,
	WARNING = 1,
	ACTIVE = 2,
	DISSIPATING = 3
}

var blizzard_phase: int = BlizzardPhase.IDLE
var active_event_index: int = -1
var warning_timer: float = 0.0
var active_timer: float = 0.0
var total_event_duration: float = 0.0
var blizzard_intensity: float = 0.0
var triggered_events: Dictionary = {} # event_id -> bool

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------
@onready var world_modulate: CanvasModulate = get_node_or_null("../WorldCanvasModulate")
@onready var biome_mgr: Node = get_node_or_null("../BiomeManager")
@onready var world_camera: Camera2D = get_node_or_null("../WorldCamera")
var snow_particles: CPUParticles2D = null
var game_state: Node = null

# ------------------------------------------------------------------------------
# PURE STATIC MATHEMATICAL & ATMOSPHERIC FUNCTIONS (Headlessly testable)
# ------------------------------------------------------------------------------

## Advances the 24-hour time of day over delta seconds.
## 300.0s real time = 24.0 in-game hours (0.08 hours/second).
## Feature: F42.
static func advance_time_of_day(current_time: float, delta: float, cycle_duration: float = 300.0) -> float:
	if delta <= 0.0 or cycle_duration <= 0.0:
		return current_time
	var hours_per_sec: float = 24.0 / cycle_duration
	var new_time: float = fmod(current_time + hours_per_sec * delta, 24.0)
	if new_time < 0.0:
		new_time += 24.0
	return new_time

## Formats time_of_day (float hours) into Russian HH:MM clock string.
static func format_time_string(time_of_day: float) -> String:
	var t: float = fmod(time_of_day, 24.0)
	if t < 0.0:
		t += 24.0
	var hrs: int = int(floor(t))
	var mins: int = int(floor((t - float(hrs)) * 60.0))
	return "%02d:%02d" % [hrs, mins]

## Calculates normalized sun factor [0.0, 1.0] (1.0 = full daylight, 0.0 = deep night).
## Polar schedule: Day (08:00 - 20:00, 150s), Dusk (20:00 - 22:24, 30s),
## Night (22:24 - 05:36, 90s), Dawn (05:36 - 08:00, 30s).
## Feature: F42.
static func calculate_sun_factor(time_of_day: float) -> float:
	var t: float = fmod(time_of_day, 24.0)
	if t < 0.0:
		t += 24.0
	# Day: 08:00 to 20:00
	if t >= 8.0 and t < 20.0:
		return 1.0
	# Dusk: 20:00 to 22.4 (2.4 hours transition)
	elif t >= 20.0 and t < 22.4:
		var s: float = (t - 20.0) / 2.4
		return 1.0 - (s * s * (3.0 - 2.0 * s))
	# Night: 22.4 to 24.0 or 0.0 to 5.6 (7.2 hours deep night)
	elif t >= 22.4 or t < 5.6:
		return 0.0
	# Dawn: 5.6 to 8.0 (2.4 hours transition)
	else:
		var s: float = (t - 5.6) / 2.4
		return s * s * (3.0 - 2.0 * s)

## Calculates outdoor ambient temperature given biome day/night temps, sun factor, and blizzard drop.
## Features: F42, F43.
static func calculate_outside_temperature(
	day_temp: float, 
	night_temp: float, 
	sun_factor: float, 
	p_blizzard_intensity: float = 0.0, 
	blizzard_temp_drop: float = -15.0
) -> float:
	var base_temp: float = lerpf(night_temp, day_temp, clampf(sun_factor, 0.0, 1.0))
	var storm_drop: float = blizzard_temp_drop * clampf(p_blizzard_intensity, 0.0, 1.0)
	return base_temp + storm_drop

## Calculates ambient daylight tint color based on time of day.
## Features: F42, F51.
static func calculate_day_night_tint(time_of_day: float) -> Color:
	var t: float = fmod(time_of_day, 24.0)
	if t < 0.0:
		t += 24.0
	
	var c_day := Color(1.0, 1.0, 1.0, 1.0)
	var c_dusk := Color(0.85, 0.55, 0.45, 1.0)
	var c_night := Color(0.18, 0.22, 0.38, 1.0) # Crisp polar navy blue for high contrast
	var c_dawn := Color(0.82, 0.68, 0.62, 1.0)
	
	if t >= 8.0 and t < 20.0:
		return c_day
	elif t >= 20.0 and t < 21.2:
		var s: float = (t - 20.0) / 1.2
		return c_day.lerp(c_dusk, s * s * (3.0 - 2.0 * s))
	elif t >= 21.2 and t < 22.4:
		var s: float = (t - 21.2) / 1.2
		return c_dusk.lerp(c_night, s * s * (3.0 - 2.0 * s))
	elif t >= 22.4 or t < 5.6:
		return c_night
	elif t >= 5.6 and t < 6.8:
		var s: float = (t - 5.6) / 1.2
		return c_night.lerp(c_dawn, s * s * (3.0 - 2.0 * s))
	else:
		var s: float = (t - 6.8) / 1.2
		return c_dawn.lerp(c_day, s * s * (3.0 - 2.0 * s))

## Calculates continuous blizzard intensity factor [0.0, 1.0] across an Attack-Sustain-Release envelope.
## Features: F43.
static func calculate_blizzard_intensity(
	elapsed_time: float, 
	total_duration: float, 
	attack_time: float = 4.0, 
	release_time: float = 4.0
) -> float:
	if elapsed_time <= 0.0 or total_duration <= 0.0:
		return 0.0
	if elapsed_time >= total_duration:
		return 0.0
	if elapsed_time < attack_time:
		var s: float = elapsed_time / attack_time
		return s * s * (3.0 - 2.0 * s)
	elif elapsed_time > (total_duration - release_time):
		var s: float = (total_duration - elapsed_time) / release_time
		return s * s * (3.0 - 2.0 * s)
	else:
		return 1.0

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------
func _ready() -> void:
	_ensure_components()
	_setup_snow_particles()
	_connect_event_bus()

func _ensure_components() -> void:
	if world_modulate == null:
		world_modulate = get_node_or_null("../WorldCanvasModulate")
	if biome_mgr == null:
		biome_mgr = get_node_or_null("../BiomeManager")
	if world_camera == null:
		world_camera = get_node_or_null("../WorldCamera")

func _setup_snow_particles() -> void:
	var parent_node: Node = world_camera if world_camera != null else self
	snow_particles = parent_node.get_node_or_null("WeatherSnowParticles")
	if snow_particles == null:
		snow_particles = CPUParticles2D.new()
		snow_particles.name = "WeatherSnowParticles"
		snow_particles.z_index = 10 # Foreground snowfall
		parent_node.add_child(snow_particles)
		
	snow_particles.position = Vector2(0.0, -380.0) # Just above 720px viewport
	snow_particles.amount = 60 # Calm rate: 60
	snow_particles.lifetime = 3.5
	snow_particles.preprocess = 2.0
	snow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_particles.emission_rect_extents = Vector2(750.0, 20.0)
	snow_particles.direction = Vector2(-0.35, 1.0).normalized()
	snow_particles.spread = 15.0
	snow_particles.initial_velocity_min = 60.0
	snow_particles.initial_velocity_max = 110.0
	snow_particles.gravity = Vector2(-30.0, 90.0)
	snow_particles.scale_amount_min = 1.5
	snow_particles.scale_amount_max = 3.0
	
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(0.92, 0.96, 1.0, 0.85),
		Color(0.92, 0.96, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	snow_particles.color_ramp = ramp
	snow_particles.emitting = true

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("game_restarted"):
		bus.connect("game_restarted", Callable(self, "_on_game_restarted"))

func _on_game_restarted() -> void:
	blizzard_phase = BlizzardPhase.IDLE
	active_event_index = -1
	warning_timer = 0.0
	active_timer = 0.0
	blizzard_intensity = 0.0
	triggered_events.clear()

# ------------------------------------------------------------------------------
# FRAME SIMULATION LOOP
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var gs: Node = _get_game_state()
	if gs == null or not gs.is_game_active or gs.is_game_over or gs.is_victory:
		return
		
	_process_day_night_clock(gs, delta)
	_process_blizzard_lifecycle(gs, delta)
	_update_ambient_temperature(gs)
	_update_world_lighting(gs)
	_update_snow_particles(delta)
	_update_wind_sound(gs)

func _process_day_night_clock(gs: Node, delta: float) -> void:
	var new_time: float = advance_time_of_day(
		gs.time_of_day, 
		delta, 
		CYCLE_DURATION
	)
	gs.set_time_of_day(new_time)

func _process_blizzard_lifecycle(gs: Node, delta: float) -> void:
	var bus: Node = _get_event_bus()
	var sm: Node = _get_sound_manager()
	var cur_dist: float = gs.distance_traveled

	match blizzard_phase:
		BlizzardPhase.IDLE:
			blizzard_intensity = 0.0
			for i in range(BLIZZARD_EVENTS.size()):
				var ev: Dictionary = BLIZZARD_EVENTS[i]
				var ev_id: String = ev.get("id", "blizzard_%d" % i)
				if not triggered_events.get(ev_id, false):
					if cur_dist >= ev["trigger_distance_m"]:
						# Trigger Warning Phase (20s advance warning)
						triggered_events[ev_id] = true
						active_event_index = i
						total_event_duration = ev["duration_sec"]
						warning_timer = BLIZZARD_WARNING_LEAD_TIME
						blizzard_phase = BlizzardPhase.WARNING
						
						gs.trigger_blizzard_warning(warning_timer)
						if sm != null and sm.has_method("play_sfx"):
							sm.play_sfx("alarm")
						break

		BlizzardPhase.WARNING:
			blizzard_intensity = 0.0
			warning_timer = maxf(0.0, warning_timer - delta)
			if bus != null and bus.has_signal("blizzard_warning_triggered"):
				bus.emit_signal("blizzard_warning_triggered", warning_timer)
				
			if warning_timer <= 0.0:
				# Strike! Transition to Active Blizzard
				blizzard_phase = BlizzardPhase.ACTIVE
				active_timer = total_event_duration
				gs.blizzard_warning_active = false
				gs.set_weather(GameState.WeatherState.BLIZZARD, gs.outside_temperature)

		BlizzardPhase.ACTIVE:
			active_timer = maxf(0.0, active_timer - delta)
			var elapsed: float = total_event_duration - active_timer
			blizzard_intensity = calculate_blizzard_intensity(
				elapsed, 
				total_event_duration, 
				4.0, 
				4.0
			)
			
			if active_timer <= 0.0:
				# Blizzard ends
				blizzard_phase = BlizzardPhase.DISSIPATING
				active_timer = 3.0

		BlizzardPhase.DISSIPATING:
			active_timer = maxf(0.0, active_timer - delta)
			blizzard_intensity = (active_timer / 3.0)
			if active_timer <= 0.0:
				blizzard_phase = BlizzardPhase.IDLE
				blizzard_intensity = 0.0
				active_event_index = -1
				gs.set_weather(GameState.WeatherState.CLEAR, gs.outside_temperature)

func _update_ambient_temperature(gs: Node) -> void:
	var biome: Dictionary = BalanceConfig.get_biome_at_distance(gs.distance_traveled)
	var day_temp: float = biome.get("day_temp", -12.0)
	var night_temp: float = biome.get("night_temp", -24.0)
	var sun_factor: float = calculate_sun_factor(gs.time_of_day)
	
	var storm_drop: float = -15.0
	if active_event_index >= 0 and active_event_index < BLIZZARD_EVENTS.size():
		storm_drop = BLIZZARD_EVENTS[active_event_index].get("temp_drop", -15.0)
		
	var out_temp: float = calculate_outside_temperature(
		day_temp, 
		night_temp, 
		sun_factor, 
		blizzard_intensity, 
		storm_drop
	)
	gs.outside_temperature = out_temp

func _update_world_lighting(gs: Node) -> void:
	if world_modulate == null:
		world_modulate = get_node_or_null("../WorldCanvasModulate")
	if world_modulate == null:
		return
		
	var biome_mod: Color = Color.WHITE
	if biome_mgr != null and biome_mgr.has_method("get_active_palette"):
		var pal: Dictionary = biome_mgr.get_active_palette()
		biome_mod = pal.get("ambient_modulate", Color.WHITE)
		
	var day_night_mod: Color = calculate_day_night_tint(gs.time_of_day)
	var blizzard_tint := Color(0.65, 0.70, 0.78, 1.0)
	var storm_mod: Color = Color.WHITE.lerp(blizzard_tint, blizzard_intensity)
	
	# Product of all atmospheric modulate layers
	world_modulate.color = biome_mod * day_night_mod * storm_mod

func _update_snow_particles(_delta: float) -> void:
	if snow_particles == null:
		return
	var target_amount: int = int(lerpf(60.0, 400.0, blizzard_intensity))
	if snow_particles.amount != target_amount:
		snow_particles.amount = target_amount
	
	var dir_calm := Vector2(-0.35, 1.0).normalized()
	var dir_storm := Vector2(-1.0, 0.45).normalized()
	snow_particles.direction = dir_calm.lerp(dir_storm, blizzard_intensity).normalized()
	
	snow_particles.initial_velocity_min = lerpf(60.0, 320.0, blizzard_intensity)
	snow_particles.initial_velocity_max = lerpf(110.0, 580.0, blizzard_intensity)
	snow_particles.gravity = Vector2(lerpf(-30.0, -250.0, blizzard_intensity), lerpf(90.0, 130.0, blizzard_intensity))
	snow_particles.scale_amount_max = lerpf(3.0, 5.0, blizzard_intensity)

func _update_wind_sound(_gs: Node) -> void:
	var sm: Node = _get_sound_manager()
	if sm == null or not sm.has_method("set_wind_intensity"):
		return
	var biome_wind: float = 0.35
	if biome_mgr != null and biome_mgr.has_method("get_active_palette"):
		biome_wind = biome_mgr.get_active_palette().get("wind_intensity", 0.35)
		
	var final_wind: float = lerpf(biome_wind, 1.0, blizzard_intensity)
	if blizzard_phase == BlizzardPhase.WARNING:
		final_wind = maxf(final_wind, 0.45) # Foreboding wind buildup during warning countdown
	sm.set_wind_intensity(final_wind)

func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null

func _get_game_state() -> Node:
	if game_state != null:
		return game_state
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
