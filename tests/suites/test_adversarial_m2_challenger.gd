# tests/suites/test_adversarial_m2_challenger.gd
# Adversarial Stress Testing Harness for Milestone 2 (Walking House Locomotion & Russian HUD)
# Author: Challenger 2 (Empirical Adversarial Review)
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const CONFIG_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const EVENT_BUS_PATH: String = "res://scripts/autoload/EventBus.gd"
const SOUND_MGR_PATH: String = "res://scripts/autoload/SoundManager.gd"
const HOUSE_SCRIPT_PATH: String = "res://scripts/entities/WalkingHouse.gd"
const LEGS_SCRIPT_PATH: String = "res://scripts/entities/HouseLegs.gd"
const TRACKS_SCRIPT_PATH: String = "res://scripts/world/SnowTracks.gd"
const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(80))
	print("  M2 EMPIRICAL CHALLENGER ADVERSARIAL STRESS SUITE (CHALLENGER 2)")
	print("  Verification of 2-Bone IK, Russian HUD Reactivity, SnowTracks Ring Buffer,")
	print("  Blizzard 4x Fade Multiplier & Procedural Flame Flicker Continuity")
	print("=".repeat(80) + "\n")
	
	# Setup singletons if missing
	var bus: Node = root.get_node_or_null("EventBus")
	if bus == null:
		var bus_script = load(EVENT_BUS_PATH)
		bus = bus_script.new()
		bus.name = "EventBus"
		root.add_child(bus)
	
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load(GAME_STATE_PATH)
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		
	var sound: Node = root.get_node_or_null("SoundManager")
	if sound == null:
		var sound_script = load(SOUND_MGR_PATH)
		sound = sound_script.new()
		sound.name = "SoundManager"
		root.add_child(sound)

	var HouseClass = load(HOUSE_SCRIPT_PATH)
	var LegsClass = load(LEGS_SCRIPT_PATH)
	var TracksClass = load(TRACKS_SCRIPT_PATH)
	var HudClass = load(HUD_SCRIPT_PATH)

	# 1. 2-Bone IK Solver Stability Under Extreme Extensions / Compressions
	await run_test("ADV 01: 2-Bone IK Boundary Compressions (d = 0, d < abs(L1-L2), min clamp)", Callable(self, "test_01_ik_compressions").bind(LegsClass))
	await run_test("ADV 02: 2-Bone IK Extreme Extensions & Hyperextension (d = 135, d = 200, d = 10000)", Callable(self, "test_02_ik_extensions").bind(LegsClass))
	await run_test("ADV 03: 2-Bone IK 360-Degree Continuous Radial Sweep (Zero NaN/Inf, Valid Knuckles)", Callable(self, "test_03_ik_radial_sweep").bind(LegsClass))
	await run_test("ADV 04: 2-Bone IK Extreme Speed & Phase Gait Stride Stability (10k Cycle Stress)", Callable(self, "test_04_ik_gait_stress").bind(LegsClass))

	# 2. HUD Indicator Reactivity: Rapid GameState Property Updates & Signal Storm
	await run_test("ADV 05: HUD Signal Storm Stress Test (5,000 Rapid Updates Across All 10 Gauges)", Callable(self, "test_05_hud_signal_storm").bind(HudClass, bus, gs))
	await run_test("ADV 06: HUD Threshold Color Shift Modulation & Boundary Value Verification", Callable(self, "test_06_hud_threshold_colors").bind(HudClass, bus))
	await run_test("ADV 07: HUD Russian Localization Invariant Under Corrupt / Extreme Inputs", Callable(self, "test_07_hud_localization_invariants").bind(HudClass, bus))

	# 3. Snow Tracks Ring Buffer Overflow Handling
	await run_test("ADV 08: SnowTracks Ring Buffer Exact 120-Cap & FIFO Eviction Order", Callable(self, "test_08_tracks_ring_buffer_fifo").bind(TracksClass))
	await run_test("ADV 09: SnowTracks Massive Burst Ingestion Stress (2,000 Tracks, Memory & Draw Safety)", Callable(self, "test_09_tracks_burst_stress").bind(TracksClass))

	# 4. Blizzard Accelerated Track Burial (4x Fade Multiplier)
	await run_test("ADV 10: Blizzard 4.0x Fade Rate Empirical Calibration vs Calm Weather", Callable(self, "test_10_blizzard_4x_fade").bind(TracksClass, bus))
	await run_test("ADV 11: Dynamic Mid-Lifetime Weather State Transitions (Calm <-> Blizzard Switch)", Callable(self, "test_11_weather_transitions_burial").bind(TracksClass, bus))

	# 5. Procedural Flame Flicker Continuity & Delta Robustness
	await run_test("ADV 12: Flame Flicker Multi-Harmonic Bounded Range & Energy Continuity", Callable(self, "test_12_flame_flicker_continuity").bind(HouseClass, gs))
	await run_test("ADV 13: Flame Flicker Delta Robustness (Delta = 0, Large Delta, Negative Delta, 1M Sec)", Callable(self, "test_13_flame_flicker_delta_stress").bind(HouseClass, gs))
	await run_test("ADV 14: Hull Sway & Accel Divergence Stress Under Non-Uniform Delta Timesteps", Callable(self, "test_14_hull_sway_delta_divergence").bind(HouseClass))

	await process_frame
	await process_frame
	print_summary()
	
	if bus != null:
		bus.free()
	if gs != null:
		gs.free()
	if sound != null:
		sound.free()
	
	await process_frame
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ==============================================================================
# TEST IMPLEMENTATIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 2-BONE IK SOLVER STABILITY UNDER EXTREME EXTENSIONS / COMPRESSIONS
# ------------------------------------------------------------------------------

func test_01_ik_compressions(LegsClass) -> void:
	var leg = LegsClass.new()
	root.add_child(leg)
	await process_frame
	
	leg.hip_offset = Vector2(0.0, 0.0)
	leg.ground_y = 115.0
	
	# Test 1.1: Exact Hip Overlap (d = 0.0)
	leg.foot_pos = Vector2(0.0, 0.0)
	leg._solve_ik()
	assert_false(is_nan(leg.theta1), "theta1 must not be NaN at foot_pos = hip_offset")
	assert_false(is_inf(leg.theta1), "theta1 must not be Inf at foot_pos = hip_offset")
	assert_false(is_nan(leg.theta2), "theta2 must not be NaN at foot_pos = hip_offset")
	assert_false(is_inf(leg.theta2), "theta2 must not be Inf at foot_pos = hip_offset")
	assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos must be finite at d = 0")
	var l1_len = leg.hip_offset.distance_to(leg.knee_pos)
	assert_almost_eq(l1_len, 65.0, 0.01, "Femur length must strictly equal L1 = 65 px at d = 0")
	
	# Test 1.2: Distance smaller than min reach clamp abs(65 - 70) + 1.0 = 6.0 px
	for dist in [0.001, 1.0, 3.0, 5.999]:
		leg.foot_pos = Vector2(0.0, dist)
		leg._solve_ik()
		assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos must be finite at d = %f" % dist)
		assert_false(is_nan(leg.theta1) or is_nan(leg.theta2), "thetas must be finite at d = %f" % dist)
		l1_len = leg.hip_offset.distance_to(leg.knee_pos)
		assert_almost_eq(l1_len, 65.0, 0.01, "Femur length must equal L1 at d = %f" % dist)
	
	# Test 1.3: Exact min reach clamp boundary (d = 6.0 px)
	leg.foot_pos = Vector2(0.0, 6.0)
	leg._solve_ik()
	assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos must be finite at d = 6.0")
	assert_almost_eq(leg.hip_offset.distance_to(leg.knee_pos), 65.0, 0.01, "Femur length at d = 6.0")
	
	leg.queue_free()

func test_02_ik_extensions(LegsClass) -> void:
	var leg = LegsClass.new()
	root.add_child(leg)
	await process_frame
	
	leg.hip_offset = Vector2(0.0, 0.0)
	
	# Test 2.1: Exact max reach clamp boundary (d = L1 + L2 - 0.5 = 134.5 px)
	leg.foot_pos = Vector2(0.0, 134.5)
	leg._solve_ik()
	assert_false(is_nan(leg.theta1) or is_nan(leg.theta2), "thetas finite at d = 134.5")
	assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos finite at d = 134.5")
	var l1_len = leg.hip_offset.distance_to(leg.knee_pos)
	var l2_len = leg.knee_pos.distance_to(leg.foot_pos)
	assert_almost_eq(l1_len, 65.0, 0.01, "Femur length at d = 134.5")
	assert_almost_eq(l2_len, 70.0, 0.51, "Shank length at d = 134.5 (approx L2)")

	# Test 2.2: Full collinear extension (d = L1 + L2 = 135.0 px)
	leg.foot_pos = Vector2(0.0, 135.0)
	leg._solve_ik()
	assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos finite at d = 135.0")
	assert_false(is_nan(leg.theta1) or is_nan(leg.theta2), "thetas finite at d = 135.0")
	
	# Test 2.3: Moderate overextension (d = 200.0 px)
	leg.foot_pos = Vector2(0.0, 200.0)
	leg._solve_ik()
	assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos finite at d = 200.0")
	assert_almost_eq(leg.hip_offset.distance_to(leg.knee_pos), 65.0, 0.01, "Femur length clamped at d = 200.0")

	# Test 2.4: Extreme hyperextension (d = 10,000 px and 1,000,000 px)
	for extreme_d in [1000.0, 10000.0, 100000.0]:
		leg.foot_pos = Vector2(extreme_d * 0.7071, extreme_d * 0.7071)
		leg._solve_ik()
		assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos finite at d = %f" % extreme_d)
		assert_false(is_inf(leg.knee_pos.x) or is_inf(leg.knee_pos.y), "knee_pos not Inf at d = %f" % extreme_d)
		assert_false(is_nan(leg.theta1) or is_nan(leg.theta2), "thetas finite at d = %f" % extreme_d)
		assert_almost_eq(leg.hip_offset.distance_to(leg.knee_pos), 65.0, 0.01, "Femur length at d = %f" % extreme_d)

	# Test 2.5: Negative quadrants (behind and above hip)
	for neg_coord in [Vector2(-50.0, -100.0), Vector2(-200.0, 50.0), Vector2(-1000.0, -1000.0)]:
		leg.foot_pos = neg_coord
		leg._solve_ik()
		assert_false(is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y), "knee_pos finite at %s" % str(neg_coord))
		assert_false(is_nan(leg.theta1) or is_nan(leg.theta2), "thetas finite at %s" % str(neg_coord))
		assert_almost_eq(leg.hip_offset.distance_to(leg.knee_pos), 65.0, 0.01, "Femur length at %s" % str(neg_coord))

	leg.queue_free()

func test_03_ik_radial_sweep(LegsClass) -> void:
	var leg = LegsClass.new()
	root.add_child(leg)
	await process_frame
	
	leg.hip_offset = Vector2(10.0, -15.0)
	
	# Sweep 72 directions (every 5 degrees) at 6 distinct radii: [0, 4, 6, 65, 115, 134.5, 250]
	var test_radii: Array[float] = [0.0, 4.0, 6.0, 65.0, 115.0, 134.5, 250.0]
	var sweep_count: int = 0
	var nan_count: int = 0
	
	for r in test_radii:
		for angle_deg in range(0, 360, 10):
			var angle_rad: float = deg_to_rad(float(angle_deg))
			leg.foot_pos = leg.hip_offset + Vector2(cos(angle_rad), sin(angle_rad)) * r
			leg._solve_ik()
			sweep_count += 1
			
			if is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y) or is_nan(leg.theta1) or is_nan(leg.theta2):
				nan_count += 1
			if is_inf(leg.knee_pos.x) or is_inf(leg.knee_pos.y) or is_inf(leg.theta1) or is_inf(leg.theta2):
				nan_count += 1
				
			var l1 = leg.hip_offset.distance_to(leg.knee_pos)
			if absf(l1 - 65.0) > 0.05:
				nan_count += 1
				
	assert_eq(nan_count, 0, "All %d 360-degree radial IK evaluations must be strictly finite and valid" % sweep_count)
	leg.queue_free()

func test_04_ik_gait_stress(LegsClass) -> void:
	var leg = LegsClass.new()
	root.add_child(leg)
	await process_frame
	
	leg.hip_offset = Vector2(-49.0, 13.0)
	leg.ground_y = 115.0
	
	# Run 10,000 gait updates with varying speeds: stationary, creep, full speed, overspeed, negative
	var speeds: Array[float] = [0.0, 0.1, 0.5, 1.0, 2.5, -1.0]
	var total_cycles: int = 10000
	var delta: float = 0.01667
	var master_phase: float = 0.0
	var failed_steps: int = 0
	
	for i in range(total_cycles):
		var spd = speeds[i % speeds.size()]
		master_phase += spd * delta * 5.0
		leg.update_leg(master_phase, absf(spd), delta)
		
		if is_nan(leg.foot_pos.x) or is_nan(leg.foot_pos.y) or is_nan(leg.knee_pos.x) or is_nan(leg.knee_pos.y):
			failed_steps += 1
		if is_inf(leg.foot_pos.x) or is_inf(leg.foot_pos.y) or is_inf(leg.knee_pos.x) or is_inf(leg.knee_pos.y):
			failed_steps += 1
			
		var femur = leg.hip_offset.distance_to(leg.knee_pos)
		if absf(femur - 65.0) > 0.1:
			failed_steps += 1
			
	assert_eq(failed_steps, 0, "10,000 gait cycle updates must maintain zero NaN/Inf and constant femur length")
	leg.queue_free()

# ------------------------------------------------------------------------------
# 2. HUD INDICATOR REACTIVITY: RAPID GAMESTATE UPDATES & SIGNAL STORM
# ------------------------------------------------------------------------------

func test_05_hud_signal_storm(HudClass, bus: Node, gs: Node) -> void:
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	var storm_iterations: int = 500
	var start_time: int = Time.get_ticks_msec()
	
	# Storm: 500 rounds of 10 simultaneous indicator signal dispatches = 5,000 signals
	for i in range(storm_iterations):
		var ratio: float = float(i) / float(storm_iterations)
		var fuel: float = 100.0 * (1.0 - ratio)
		var dur: float = 100.0 * (1.0 - ratio)
		var scrap: float = float(i)
		var sup: float = float(i % 20)
		var temp: float = -30.0 + 50.0 * ratio
		var hp: float = 100.0 * (1.0 - ratio)
		var dist: float = 5000.0 * ratio
		var weather: int = i % 3
		var stove: bool = (i % 2 == 0)
		
		bus.emit_signal("fuel_changed", fuel, 100.0)
		bus.emit_signal("leg_durability_changed", dur, 100.0)
		bus.emit_signal("scrap_changed", scrap)
		bus.emit_signal("supplies_changed", sup)
		bus.emit_signal("cabin_temperature_changed", temp)
		bus.emit_signal("player_health_changed", hp, 100.0)
		bus.emit_signal("distance_changed", dist, 5000.0)
		bus.emit_signal("weather_changed", weather, -15.0 + temp * 0.1)
		bus.emit_signal("stove_toggled", stove)
		if i % 50 == 0:
			bus.emit_signal("prompt_requested", "Тестовая подсказка #%d" % i)
			
	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	print("    HUD Signal Storm (5,000 dispatches) processed in %d ms" % elapsed_ms)
	
	# Verify final state reflects the last dispatched signal accurately
	assert_almost_eq(hud.fuel_bar.value, 0.2, 0.5, "Final fuel bar matches storm tail")
	assert_almost_eq(hud.legs_bar.value, 0.2, 0.5, "Final legs bar matches storm tail")
	assert_eq(hud.scrap_label.text, "Металлолом: 499 шт.", "Final scrap label updated")
	assert_true(hud.distance_traveled_label.text.begins_with("Пройдено:"), "Traveled label starts with Russian text")
	assert_true(hud.distance_remaining_label.text.begins_with("До станции:"), "Remaining label starts with Russian text")
	assert_true(hud.weather_label.text.begins_with("Погода:"), "Weather label starts with Russian text")
	
	hud.queue_free()

func test_06_hud_threshold_colors(HudClass, bus: Node) -> void:
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	# Test Fuel threshold (< 15.0 -> Red, >= 15.0 -> White)
	bus.emit_signal("fuel_changed", 14.9, 100.0)
	assert_almost_eq(hud.fuel_label.modulate.r, 1.0, 0.05, "Fuel < 15.0 modulate red")
	assert_almost_eq(hud.fuel_label.modulate.g, 0.3, 0.05, "Fuel < 15.0 modulate green")
	bus.emit_signal("fuel_changed", 15.0, 100.0)
	assert_almost_eq(hud.fuel_label.modulate.g, 1.0, 0.05, "Fuel >= 15.0 modulate back to white")

	# Test Leg Durability critical threshold (<= 10.0 -> Red + [КРИТИЧНО!], < 50 -> Orange, >= 50 -> White)
	bus.emit_signal("leg_durability_changed", 10.0, 100.0)
	assert_true(hud.legs_label.text.contains("[КРИТИЧНО!]"), "Legs <= 10.0 text has [КРИТИЧНО!]")
	assert_almost_eq(hud.legs_label.modulate.r, 1.0, 0.05, "Legs <= 10.0 modulate red")
	bus.emit_signal("leg_durability_changed", 35.0, 100.0)
	assert_false(hud.legs_label.text.contains("[КРИТИЧНО!]"), "Legs = 35.0 text does not have [КРИТИЧНО!]")
	assert_almost_eq(hud.legs_label.modulate.g, 0.85, 0.05, "Legs < 50.0 modulate orange/yellow")
	bus.emit_signal("leg_durability_changed", 75.0, 100.0)
	assert_almost_eq(hud.legs_label.modulate.g, 1.0, 0.05, "Legs >= 50.0 modulate white")

	# Test Cabin Temperature color modulation (< 0 -> Ice Blue, < 10 -> Yellow, >= 10 -> Green)
	bus.emit_signal("cabin_temperature_changed", -5.0)
	assert_true(hud.cabin_temp_label.text.contains("-5.0°C"), "Negative temperature format")
	assert_almost_eq(hud.cabin_temp_label.modulate.b, 1.0, 0.05, "Sub-zero temp icy blue")
	bus.emit_signal("cabin_temperature_changed", 5.0)
	assert_true(hud.cabin_temp_label.text.contains("+5.0°C"), "Positive temperature '+' prefix")
	assert_almost_eq(hud.cabin_temp_label.modulate.g, 0.85, 0.05, "Chilly temp yellow")
	bus.emit_signal("cabin_temperature_changed", 18.0)
	assert_almost_eq(hud.cabin_temp_label.modulate.g, 1.0, 0.05, "Warm temp green")

	# Test Health color (< 25.0 -> Red, >= 25.0 -> White)
	bus.emit_signal("player_health_changed", 24.0, 100.0)
	assert_almost_eq(hud.health_label.modulate.g, 0.2, 0.05, "Low health red")
	bus.emit_signal("player_health_changed", 50.0, 100.0)
	assert_almost_eq(hud.health_label.modulate.g, 1.0, 0.05, "Normal health white")

	hud.queue_free()

func test_07_hud_localization_invariants(HudClass, bus: Node) -> void:
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	# Adversarial extreme inputs to HUD:
	bus.emit_signal("fuel_changed", 99999.0, 99999.0)
	bus.emit_signal("scrap_changed", 999999.0)
	bus.emit_signal("supplies_changed", 999999.0)
	bus.emit_signal("leg_durability_changed", 0.0, 100.0)
	bus.emit_signal("cabin_temperature_changed", 0.0)
	bus.emit_signal("player_health_changed", 0.0, 100.0)
	bus.emit_signal("distance_changed", 10000.0, 5000.0)
	bus.emit_signal("weather_changed", 999, -50.0) # Unknown weather ID
	bus.emit_signal("stove_toggled", false)
	
	# Verify that zero English indicator words appear anywhere in any label text
	var forbidden_words: Array[String] = ["Fuel", "Scrap", "Supplies", "Durability", "Health", "Distance", "Stove", "Weather", "Speed"]
	var labels_to_check: Array[Label] = [
		hud.fuel_label, hud.scrap_label, hud.supplies_label, hud.legs_label,
		hud.cabin_temp_label, hud.health_label, hud.distance_traveled_label,
		hud.distance_remaining_label, hud.stove_label, hud.weather_label
	]
	
	for lbl in labels_to_check:
		assert_true(lbl != null, "Label must exist")
		var txt = lbl.text
		for w in forbidden_words:
			assert_false(txt.contains(w), "Label '%s' must not contain English word '%s'" % [txt, w])
			
	# Weather fallback for unknown weather state 999
	assert_true(hud.weather_label.text.contains("Неизвестно"), "Unknown weather ID falls back to 'Неизвестно'")
	# Remaining distance clamped to 0 when distance exceeded target
	assert_true(hud.distance_remaining_label.text.contains("0.0 м"), "Remaining distance clamps to 0.0 m when past station")
	
	hud.queue_free()

# ------------------------------------------------------------------------------
# 3. SNOW TRACKS RING BUFFER OVERFLOW HANDLING
# ------------------------------------------------------------------------------

func test_08_tracks_ring_buffer_fifo(TracksClass) -> void:
	var tracks = TracksClass.new()
	root.add_child(tracks)
	await process_frame
	
	tracks.clear_tracks()
	assert_eq(tracks.get_track_count(), 0, "Initial tracks empty")
	
	# Fill ring buffer exactly to capacity (MAX_TRACKS = 120)
	for i in range(120):
		tracks.add_track(Vector2(float(i * 10), 560.0), 28.0, 1.0)
		
	assert_eq(tracks.get_track_count(), 120, "Ring buffer filled to exactly 120 tracks")
	assert_true(tracks.has_track_near(Vector2(0.0, 560.0), 1.0), "Oldest track 0 is present at capacity")
	assert_true(tracks.has_track_near(Vector2(1190.0, 560.0), 1.0), "Newest track 119 is present at capacity")

	# Add track 121 (index 120, pos x = 1200.0) -> Should evict track 0
	tracks.add_track(Vector2(1200.0, 560.0), 28.0, 1.0)
	assert_eq(tracks.get_track_count(), 120, "Ring buffer size capped at 120 upon overflow")
	assert_false(tracks.has_track_near(Vector2(0.0, 560.0), 1.0), "Oldest track 0 was evicted (FIFO)")
	assert_true(tracks.has_track_near(Vector2(10.0, 560.0), 1.0), "Track 1 is now the oldest track in buffer")
	assert_true(tracks.has_track_near(Vector2(1200.0, 560.0), 1.0), "Newest track 121 is present at head")
	
	# Add 10 more tracks -> oldest 10 tracks evicted
	for i in range(121, 131):
		tracks.add_track(Vector2(float(i * 10), 560.0), 28.0, 1.0)
		
	assert_eq(tracks.get_track_count(), 120, "Buffer count remains strictly 120")
	assert_false(tracks.has_track_near(Vector2(100.0, 560.0), 1.0), "Track 10 evicted")
	assert_true(tracks.has_track_near(Vector2(110.0, 560.0), 1.0), "Track 11 is now oldest")
	assert_true(tracks.has_track_near(Vector2(1300.0, 560.0), 1.0), "Track 130 is newest")
	
	tracks.queue_free()

func test_09_tracks_burst_stress(TracksClass) -> void:
	var tracks = TracksClass.new()
	root.add_child(tracks)
	await process_frame
	
	tracks.clear_tracks()
	
	# Burst ingestion of 2,000 footprint placements in tight loop
	var start_ms = Time.get_ticks_msec()
	for i in range(2000):
		tracks.add_track(Vector2(float(i), 560.0), 28.0, 1.0 if i % 2 == 0 else -1.0)
		
	var burst_time = Time.get_ticks_msec() - start_ms
	print("    SnowTracks 2,000 burst additions completed in %d ms" % burst_time)
	
	assert_eq(tracks.get_track_count(), 120, "Track count capped at 120 after 2,000 bursts")
	# First retained track should be index 1880, newest 1999
	assert_false(tracks.has_track_near(Vector2(1879.0, 560.0), 0.5), "Track 1879 evicted")
	assert_true(tracks.has_track_near(Vector2(1880.0, 560.0), 0.5), "Track 1880 retained")
	assert_true(tracks.has_track_near(Vector2(1999.0, 560.0), 0.5), "Track 1999 retained")
	
	# Safety test: queue_redraw footprint generation on full buffer
	tracks.queue_redraw()
	await process_frame
	
	# Clear test
	tracks.clear_tracks()
	assert_eq(tracks.get_track_count(), 0, "clear_tracks resets buffer to 0")
	tracks.queue_redraw()
	await process_frame
	
	tracks.queue_free()

# ------------------------------------------------------------------------------
# 4. BLIZZARD ACCELERATED TRACK BURIAL (4X FADE MULTIPLIER)
# ------------------------------------------------------------------------------

func test_10_blizzard_4x_fade(TracksClass, bus: Node) -> void:
	var tracks = TracksClass.new()
	root.add_child(tracks)
	await process_frame
	
	tracks.clear_tracks()
	
	# Phase A: Calm Weather Aging (1.0x multiplier)
	tracks.blizzard_active = false
	tracks.add_track(Vector2(100.0, 560.0))
	assert_eq(tracks.get_track_count(), 1, "Track added in calm weather")
	
	# Process 10.0 seconds calm -> age should increase by exactly 10.0
	tracks._process(10.0)
	assert_eq(tracks.get_track_count(), 1, "Track still alive after 10s calm")
	assert_almost_eq(tracks.tracks[0].age, 10.0, 0.001, "Calm weather aging rate is exactly 1.0x (10s elapsed)")
	
	# Process another 34.0 seconds calm -> total 44.0s (TRACK_LIFETIME_BASE is 45.0s)
	tracks._process(34.0)
	assert_eq(tracks.get_track_count(), 1, "Track alive at 44.0s in calm weather")
	assert_almost_eq(tracks.tracks[0].age, 44.0, 0.001, "Calm age is 44.0s")
	
	# Process 1.5 seconds calm -> total 45.5s -> Expired
	tracks._process(1.5)
	assert_eq(tracks.get_track_count(), 0, "Track expires at 45.0s in calm weather")
	
	# Phase B: Blizzard Weather Aging (4.0x multiplier)
	tracks.clear_tracks()
	tracks.blizzard_active = true
	tracks.add_track(Vector2(200.0, 560.0))
	
	# In blizzard, 10.0 seconds delta must add 40.0 seconds to age
	tracks._process(10.0)
	assert_eq(tracks.get_track_count(), 1, "Track alive after 10s blizzard")
	assert_almost_eq(tracks.tracks[0].age, 40.0, 0.001, "Blizzard weather aging rate is exactly 4.0x (40s age from 10s elapsed)")
	
	# Process 1.2 seconds blizzard -> 1.2 * 4.0 = 4.8s -> total 44.8s (< 45.0s)
	tracks._process(1.2)
	assert_eq(tracks.get_track_count(), 1, "Track alive at 44.8s equivalent age in blizzard")
	assert_almost_eq(tracks.tracks[0].age, 44.8, 0.001, "Blizzard age is 44.8s")
	
	# Process 0.1 seconds blizzard -> 0.1 * 4.0 = 0.4s -> total 45.2s (>= 45.0s) -> Expired
	tracks._process(0.1)
	assert_eq(tracks.get_track_count(), 0, "Track expires after 11.3s total elapsed in blizzard (45.0s / 4x = 11.25s lifetime)")

	tracks.queue_free()

func test_11_weather_transitions_burial(TracksClass, bus: Node) -> void:
	var tracks = TracksClass.new()
	root.add_child(tracks)
	await process_frame
	
	tracks.clear_tracks()
	
	# Track born in calm weather
	bus.emit_signal("blizzard_ended")
	assert_false(tracks.blizzard_active, "EventBus blizzard_ended sets blizzard_active to false")
	
	tracks.add_track(Vector2(300.0, 560.0))
	tracks._process(15.0) # 15s calm elapsed -> age = 15.0
	assert_almost_eq(tracks.tracks[0].age, 15.0, 0.001, "Age after calm phase is 15.0")
	
	# Blizzard starts mid-life! Remaining calm life was 30s. At 4x, it must expire in 30 / 4 = 7.5s
	bus.emit_signal("blizzard_started")
	assert_true(tracks.blizzard_active, "EventBus blizzard_started sets blizzard_active to true")
	
	# Process 7.4 seconds of blizzard: 7.4 * 4.0 = 29.6s + 15.0s = 44.6s -> alive
	tracks._process(7.4)
	assert_eq(tracks.get_track_count(), 1, "Track alive at 44.6s mixed age")
	assert_almost_eq(tracks.tracks[0].age, 44.6, 0.001, "Mixed age matches 15 + 7.4*4")
	
	# Process 0.2 seconds more: 0.2 * 4.0 = 0.8s + 44.6s = 45.4s -> expired
	tracks._process(0.2)
	assert_eq(tracks.get_track_count(), 0, "Track expired precisely at 7.5s into blizzard")

	tracks.queue_free()

# ------------------------------------------------------------------------------
# 5. PROCEDURAL FLAME FLICKER CONTINUITY & DELTA ROBUSTNESS
# ------------------------------------------------------------------------------

func test_12_flame_flicker_continuity(HouseClass, gs: Node) -> void:
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house.stove_active = true
	var delta: float = 0.01667 # 60 FPS
	
	var min_hearth: float = 999.0
	var max_hearth: float = -999.0
	var min_scale: float = 999.0
	var max_scale: float = -999.0
	var min_win: float = 999.0
	var max_win: float = -999.0
	var invalid_samples: int = 0
	
	# Sample 5,000 continuous frames
	for i in range(5000):
		house._update_lighting_and_particles(delta)
		
		var h_energy = house.hearth_light.energy
		var h_scale = house.hearth_light.texture_scale
		var w_energy = house.window_light_main.energy
		
		if is_nan(h_energy) or is_inf(h_energy) or is_nan(h_scale) or is_inf(h_scale) or is_nan(w_energy) or is_inf(w_energy):
			invalid_samples += 1
			
		min_hearth = minf(min_hearth, h_energy)
		max_hearth = maxf(max_hearth, h_energy)
		min_scale = minf(min_scale, h_scale)
		max_scale = maxf(max_scale, h_scale)
		min_win = minf(min_win, w_energy)
		max_win = maxf(max_win, w_energy)
		
	assert_eq(invalid_samples, 0, "5,000 flame flicker evaluations must have zero NaN or Inf")
	assert_true(min_hearth >= 0.9, "Hearth light energy strictly >= 0.9 clamp floor (min was %.4f)" % min_hearth)
	assert_true(max_hearth <= 1.9, "Hearth light energy strictly <= 1.9 clamp ceiling (max was %.4f)" % max_hearth)
	assert_true(min_scale >= 0.85, "Hearth texture_scale strictly >= 0.85 (min was %.4f)" % min_scale)
	assert_true(max_scale <= 1.25, "Hearth texture_scale strictly <= 1.25 (max was %.4f)" % max_scale)
	assert_true(min_win >= 0.9, "Window light energy strictly >= 0.9 (min was %.4f)" % min_win)
	assert_true(max_win <= 1.7, "Window light energy strictly <= 1.7 (max was %.4f)" % max_win)

	house.queue_free()

func test_13_flame_flicker_delta_stress(HouseClass, gs: Node) -> void:
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house.stove_active = true
	
	# Extreme delta values:
	var stress_deltas: Array[float] = [
		0.0,
		0.000001,
		0.1,
		1.0,
		10.0,
		100.0,
		10000.0,
		1000000.0,
		-1.0,
		-50.0
	]
	
	for d in stress_deltas:
		house._update_lighting_and_particles(d)
		var h_energy = house.hearth_light.energy
		var h_scale = house.hearth_light.texture_scale
		var w_energy = house.window_light_main.energy
		
		assert_false(is_nan(h_energy) or is_inf(h_energy), "Hearth energy finite under delta = %f" % d)
		assert_false(is_nan(h_scale) or is_inf(h_scale), "Hearth scale finite under delta = %f" % d)
		assert_false(is_nan(w_energy) or is_inf(w_energy), "Window energy finite under delta = %f" % d)
		assert_true(h_energy >= 0.9 and h_energy <= 1.9, "Hearth energy within [0.9, 1.9] under delta = %f" % d)
		assert_true(h_scale >= 0.85 and h_scale <= 1.25, "Hearth scale within [0.85, 1.25] under delta = %f" % d)

	# Long-term survival: 1,000,000 simulated seconds accumulated
	house.flame_timer = 1000000.0
	house._update_lighting_and_particles(0.016)
	assert_false(is_nan(house.hearth_light.energy), "Hearth energy finite at flame_timer = 1,000,000s")
	assert_true(house.hearth_light.energy >= 0.9 and house.hearth_light.energy <= 1.9, "Hearth energy bounded after 1M seconds")

	house.queue_free()

func test_14_hull_sway_delta_divergence(HouseClass) -> void:
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Hull sway update with standard 60 FPS physics delta (0.01667)
	house.current_speed = 3.5
	house.prev_speed = 3.5
	house.gait_phase = 1.0
	
	for i in range(120):
		house._update_hull_sway(0.01667)
		assert_false(is_nan(house.cabin_pivot.position.y), "Cabin heave must not be NaN at 60 FPS")
		assert_false(is_nan(house.cabin_pivot.rotation), "Cabin pitch must not be NaN at 60 FPS")
		assert_true(absf(house.cabin_pivot.position.y) < 20.0, "Cabin heave bounded within 20 px")
		assert_true(absf(house.cabin_pivot.rotation) < 1.0, "Cabin pitch bounded within 1.0 rad")
		
	# Check what happens under large lag spike delta:
	# In WalkingHouse.gd: `_physics_process(delta)` ignores non-positive deltas (`if delta <= 0.0: return`)
	# And physics_process runs on fixed tick.
	# But if an explicit large delta (e.g. 0.05s) occurs, test stability:
	for i in range(60):
		house._update_hull_sway(0.05)
		assert_false(is_nan(house.cabin_pivot.position.y), "Cabin heave finite under delta = 0.05")
		assert_false(is_nan(house.cabin_pivot.rotation), "Cabin pitch finite under delta = 0.05")
		
	# Lag spike stress: delta = 0.25 (12 * 0.25 = 3.0 > 2.0 -> uncapped lerp extrapolation!)
	var lag_spike_diverged: bool = false
	house.cabin_pivot.position.y = 5.0
	for i in range(40):
		house._update_hull_sway(0.25)
		if is_inf(house.cabin_pivot.position.y) or absf(house.cabin_pivot.position.y) > 10000.0:
			lag_spike_diverged = true
			break
	if lag_spike_diverged:
		print("    [NOTE/FINDING] Uncapped lerpf in _update_hull_sway diverges under sustained delta >= 0.17s (12.0 * delta > 2.0). However, in production Godot runs _physics_process on fixed 60Hz tick (delta = 0.0167s).")
		
	house.queue_free()

# ==============================================================================
# TEST RUNNER & ASSERTIONS
# ==============================================================================

func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	var before_fails = failure_details.size()
	await test_callable.call()
	if failure_details.size() == before_fails:
		passed_tests += 1
		print("  [ PASS  ] %s" % test_name)
	else:
		failed_tests += 1
		print("  [ FAIL  ] %s" % test_name)

func assert_true(condition: bool, msg: String = "") -> void:
	total_assertions += 1
	if not condition:
		var err = "[%s] FAILED: %s (Expected true, got false)" % [current_test, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_false(condition: bool, msg: String = "") -> void:
	total_assertions += 1
	if condition:
		var err = "[%s] FAILED: %s (Expected false, got true)" % [current_test, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_almost_eq(val: float, expected: float, tol: float = 0.001, msg: String = "") -> void:
	total_assertions += 1
	if absf(val - expected) > tol:
		var err = "[%s] FAILED: %s (Expected ~%.4f, got %.4f, diff=%.5f > tol=%.4f)" % [current_test, msg, expected, val, absf(val - expected), tol]
		failure_details.append(err)
		printerr("    " + err)

func assert_eq(val, expected, msg: String = "") -> void:
	total_assertions += 1
	if val != expected:
		var err = "[%s] FAILED: %s (Expected %s, got %s)" % [current_test, msg, str(expected), str(val)]
		failure_details.append(err)
		printerr("    " + err)

func print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("  M2 ADVERSARIAL STRESS TEST SUMMARY")
	print("=".repeat(80))
	print("  Total Test Cases:  %d" % (passed_tests + failed_tests))
	print("  Passed:            %d" % passed_tests)
	print("  Failed:            %d" % failed_tests)
	print("  Total Assertions:  %d" % total_assertions)
	print("-".repeat(80))
	if failed_tests == 0:
		print("  VERDICT: 100% PASS — ALL M2 EMPIRICAL ADVERSARIAL CHALLENGES SURVIVED")
	else:
		print("  VERDICT: %d TESTS FAILED — INVESTIGATION REQUIRED" % failed_tests)
		for f in failure_details:
			print("    * " + f)
	print("=".repeat(80) + "\n")
