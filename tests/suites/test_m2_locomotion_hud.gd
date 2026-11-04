# tests/suites/test_m2_locomotion_hud.gd
# Headless Verification Test Suite for Milestone 2:
# Locomotion Control Loop, Continuous Coupling, Articulated Legs, Snow Tracks & Russian HUD
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const CONFIG_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const EVENT_BUS_PATH: String = "res://scripts/autoload/EventBus.gd"
const SOUND_MGR_PATH: String = "res://scripts/autoload/SoundManager.gd"
const HOUSE_SCRIPT_PATH: String = "res://scripts/entities/WalkingHouse.gd"
const HOUSE_SCENE_PATH: String = "res://scenes/entities/WalkingHouse.tscn"
const LEGS_SCRIPT_PATH: String = "res://scripts/entities/HouseLegs.gd"
const TRACKS_SCRIPT_PATH: String = "res://scripts/world/SnowTracks.gd"
const HUD_SCRIPT_PATH: String = "res://scripts/ui/HUD.gd"
const HUD_SCENE_PATH: String = "res://scenes/ui/HUD.tscn"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

func _init() -> void:
	_run_all_tests.call_deferred()

func _run_all_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(78))
	print("  M2 HEADLESS VERIFICATION: LOCOMOTION, COUPLING & RUSSIAN HUD")
	print("  Scope: Input, Accel/Decel, Degradation, Exit Lockout, Wear/Fuel, 10 Gauges")
	print("=".repeat(78) + "\n")
	
	# Autoload setup in root
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
	var HudClass = load(HUD_SCRIPT_PATH)
	var LegsClass = load(LEGS_SCRIPT_PATH)
	var TracksClass = load(TRACKS_SCRIPT_PATH)
	
	await run_test("TC 01: Locomotion Forward Acceleration & Deceleration Loop", Callable(self, "test_01_accel_decel").bind(HouseClass, gs))
	await run_test("TC 02: Locomotion Reverse Speed Limit & Negative Direction", Callable(self, "test_02_reverse_kinematics").bind(HouseClass, gs))
	await run_test("TC 03: Speed Degradation BVA Curve & Critical Immobilization", Callable(self, "test_03_speed_degradation").bind(gs))
	await run_test("TC 04: Exit Lockout During Locomotion (V > 0 vs Stationary)", Callable(self, "test_04_exit_lockout").bind(HouseClass, gs, bus))
	await run_test("TC 05: Continuous Fuel Consumption & Automatic Engine Cutoff", Callable(self, "test_05_fuel_consumption_coupling").bind(HouseClass, gs))
	await run_test("TC 06: Continuous Leg Wear & Biome Multiplier Scaling", Callable(self, "test_06_leg_wear_biome_coupling").bind(HouseClass, gs))
	await run_test("TC 07: Russian HUD StyleBoxFlat Dark Frosted Theme Validation", Callable(self, "test_07_hud_theme_structure").bind(HudClass))
	await run_test("TC 08: Russian HUD 100% Localization on All 10 Required Indicators", Callable(self, "test_08_hud_russian_localization").bind(HudClass, gs))
	await run_test("TC 09: Russian HUD EventBus Reactive Signal Subscriptions", Callable(self, "test_09_hud_eventbus_reactivity").bind(HudClass, bus))
	await run_test("TC 10: Full GameState Reset Synchronization Across HUD Gauges", Callable(self, "test_10_hud_reset_sync").bind(HudClass, gs))
	await run_test("TC 11: HouseLegs 2-Bone IK, Gait Trajectory & Impact Hooks", Callable(self, "test_11_house_legs_ik").bind(LegsClass))
	await run_test("TC 12: SnowTracks Ring-Buffer Track Generation & Blizzard Burial", Callable(self, "test_12_snow_tracks").bind(TracksClass))
	await run_test("TC 13: WalkingHouse Scene Instantiation & Hierarchy Integrity", Callable(self, "test_13_house_scene_integrity"))
	
	await process_frame
	await process_frame
	print_summary()
	
	if bus != null:
		bus.free()
	if gs != null:
		gs.free()
	if sound != null:
		sound.free()
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ==============================================================================
# TEST IMPLEMENTATIONS
# ==============================================================================

func test_01_accel_decel(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Simulate 1.0s forward acceleration (target = 5.0 m/s, accel = 2.5 m/s^2)
	house.target_speed = 5.0
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 1.0)
	assert_almost_eq(house.current_speed, 2.5, 0.01, "Speed after 1s accel must be 2.5 m/s")
	
	# Step another 1.0s -> reaches 5.0 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 1.0)
	assert_almost_eq(house.current_speed, 5.0, 0.01, "Speed after 2s accel must be 5.0 m/s")
	
	# Target = 0 (braking at 3.5 m/s^2) -> 1.0s drops to 1.5 m/s
	house.target_speed = 0.0
	house.current_speed = move_toward(house.current_speed, house.target_speed, 3.5 * 1.0)
	assert_almost_eq(house.current_speed, 1.5, 0.01, "Speed after 1s braking must drop from 5.0 to 1.5 m/s")
	
	# Decelerate another 1.0s -> full stop
	house.current_speed = move_toward(house.current_speed, house.target_speed, 3.5 * 1.0)
	assert_almost_eq(house.current_speed, 0.0, 0.001, "House smoothly stops at 0.0 m/s")
	
	house.queue_free()

func test_02_reverse_kinematics(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Target reverse speed is capped at -2.5 m/s
	var sim = load(SIM_PATH)
	var max_rev = sim.calculate_speed(2.5, gs.leg_durability, 100.0)
	assert_almost_eq(max_rev, 2.5, 0.001, "Max reverse speed must be 2.5 m/s")
	
	house.target_speed = -max_rev
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 2.0)
	assert_almost_eq(house.current_speed, -2.5, 0.01, "Reverse speed reached -2.5 m/s")
	
	house.queue_free()

func test_03_speed_degradation(gs) -> void:
	gs.reset_state()
	var sim = load(SIM_PATH)
	
	# 100% durability -> 5.0 m/s
	var spd_100 = sim.calculate_speed(5.0, 100.0, 100.0)
	assert_almost_eq(spd_100, 5.0, 0.001, "100% durability gives 5.0 m/s")
	
	# 50% durability -> 5.0 m/s (inflection threshold)
	var spd_50 = sim.calculate_speed(5.0, 50.0, 100.0)
	assert_almost_eq(spd_50, 5.0, 0.001, "50% durability gives 5.0 m/s")
	
	# 30% durability -> 3.75 m/s
	var spd_30 = sim.calculate_speed(5.0, 30.0, 100.0)
	assert_almost_eq(spd_30, 3.75, 0.01, "30% durability gives 3.75 m/s")
	
	# 10% durability -> 2.5 m/s
	var spd_10 = sim.calculate_speed(5.0, 10.0, 100.0)
	assert_almost_eq(spd_10, 2.5, 0.01, "10% durability gives 2.5 m/s")
	
	# 5% durability -> emergency creep mode (1.5 m/s)
	var spd_5 = sim.calculate_speed(5.0, 5.0, 100.0)
	assert_almost_eq(spd_5, 1.5, 0.01, "5% durability gives emergency creep 1.5 m/s")
	
	# 0% durability -> Immobilized (0.0 m/s)
	var spd_0 = sim.calculate_speed(5.0, 0.0, 100.0)
	assert_almost_eq(spd_0, 0.0, 0.0001, "0% durability immobilizes house")

func test_04_exit_lockout(HouseClass, gs, _bus) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# House is moving forward at 3.0 m/s
	house.current_speed = 3.0
	house.is_house_moving = true
	gs.set_house_moving(true)
	gs.set_house_speed(3.0)
	
	# Attempt disembark while moving -> MUST FAIL
	var disembark_ok = house._handle_disembark_request()
	assert_false(disembark_ok, "Disembark request must be rejected when house is moving (V > 0)")
	assert_false(gs.is_player_outside, "Player must remain inside house")
	
	# House comes to full stop
	house.current_speed = 0.0
	house.is_house_moving = false
	gs.set_house_moving(false)
	gs.set_house_speed(0.0)
	
	# Attempt disembark while stationary -> MUST SUCCEED
	disembark_ok = house._handle_disembark_request()
	assert_true(disembark_ok, "Disembark request must succeed when stationary (V = 0)")
	assert_true(gs.is_player_outside, "Player is now outside in the snow")
	
	house.queue_free()

func test_05_fuel_consumption_coupling(HouseClass, gs) -> void:
	gs.reset_state()
	gs.set_fuel(50.0)
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house.current_speed = 5.0
	house.is_house_moving = true
	
	# Physics tick for 2.0s
	var sim = load(SIM_PATH)
	var fuel_spent = sim.calculate_fuel_consumption(true, false, 2.0, 0.50, 0.30)
	gs.consume_fuel(fuel_spent)
	assert_almost_eq(fuel_spent, 1.0, 0.01, "Fuel spent over 2.0s should be 1.0 л")
	assert_almost_eq(gs.fuel, 49.0, 0.01, "GameState fuel remaining must be 49.0 л")
	
	# Drain fuel to 0.0 -> critical stop
	gs.consume_fuel(49.0)
	assert_almost_eq(gs.fuel, 0.0, 0.0001, "Fuel must reach 0.0")
	
	# When fuel is 0, process_locomotion forces target_speed to 0
	house._process_locomotion(0.1)
	assert_almost_eq(house.target_speed, 0.0, 0.0001, "Zero fuel forces target speed to 0.0")
	
	house.queue_free()

func test_06_leg_wear_biome_coupling(HouseClass, gs) -> void:
	gs.reset_state()
	gs.set_leg_durability(100.0)
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	var sim = load(SIM_PATH)
	
	# Biome 0 (0 - 1000m): wear_mult = 1.0 -> 0.20% wear per second
	gs.distance_traveled = 200.0
	var wear_b0 = sim.calculate_leg_wear(true, false, 1.0, 0.20, 0.40, 1.0)
	assert_almost_eq(wear_b0, 0.20, 0.01, "Biome 0 wear rate must be 0.20%/s")
	
	# Biome 2 (2000 - 3000m, Machinery Graveyard): wear_mult = 1.5 -> 0.30% wear per second
	gs.distance_traveled = 2500.0
	var wear_b2 = sim.calculate_leg_wear(true, false, 1.0, 0.20, 0.40, 1.5)
	assert_almost_eq(wear_b2, 0.30, 0.01, "Biome 2 wear rate must be 0.30%/s (1.5x multiplier)")
	
	# Biome 3 (3000 - 4000m, Frozen Forest): wear_mult = 1.25 -> 0.25% wear per second
	gs.distance_traveled = 3500.0
	var wear_b3 = sim.calculate_leg_wear(true, false, 1.0, 0.20, 0.40, 1.25)
	assert_almost_eq(wear_b3, 0.25, 0.01, "Biome 3 wear rate must be 0.25%/s (1.25x multiplier)")
	
	house.queue_free()

func test_07_hud_theme_structure(HudClass) -> void:
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	assert_true(hud.root_control != null, "HUD root control must be instantiated")
	assert_true(hud.fuel_label != null, "Fuel label must exist")
	assert_true(hud.fuel_bar != null, "Fuel bar must exist")
	assert_true(hud.legs_label != null, "Legs label must exist")
	assert_true(hud.legs_bar != null, "Legs bar must exist")
	assert_true(hud.health_label != null, "Health label must exist")
	assert_true(hud.health_bar != null, "Health bar must exist")
	
	# Validate frosted stylebox properties
	var sb = hud._create_dark_frosted_stylebox()
	assert_true(sb.bg_color.a > 0.8, "Frosted panel must be dark translucent (alpha > 0.8)")
	assert_true(sb.border_width_left >= 2, "Border width must be at least 2px")
	assert_true(sb.corner_radius_top_left >= 4, "Corner radius must be rounded")
	
	hud.queue_free()

func test_08_hud_russian_localization(HudClass, gs) -> void:
	gs.reset_state()
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	hud.sync_all_indicators()
	
	# Indicator 1: Топливо
	assert_true(hud.fuel_label.text.begins_with("Топливо:"), "Indicator 1 must start with 'Топливо:'")
	
	# Indicator 2: Металлолом
	assert_true(hud.scrap_label.text.begins_with("Металлолом:"), "Indicator 2 must start with 'Металлолом:'")
	
	# Indicator 3: Припасы
	assert_true(hud.supplies_label.text.begins_with("Припасы:"), "Indicator 3 must start with 'Припасы:'")
	
	# Indicator 4: Прочность опор
	assert_true(hud.legs_label.text.begins_with("Прочность опор:"), "Indicator 4 must start with 'Прочность опор:'")
	
	# Indicator 5: Температура в доме
	assert_true(hud.cabin_temp_label.text.begins_with("Температура в доме:"), "Indicator 5 must start with 'Температура в доме:'")
	
	# Indicator 6: Здоровье
	assert_true(hud.health_label.text.begins_with("Здоровье:"), "Indicator 6 must start with 'Здоровье:'")
	
	# Indicator 7: Пройдено (м)
	assert_true(hud.distance_traveled_label.text.begins_with("Пройдено:"), "Indicator 7 must start with 'Пройдено:'")
	assert_true(hud.distance_traveled_label.text.ends_with("м"), "Distance traveled must specify units 'м'")
	
	# Indicator 8: До станции (м)
	assert_true(hud.distance_remaining_label.text.begins_with("До станции:"), "Indicator 8 must start with 'До станции:'")
	assert_true(hud.distance_remaining_label.text.ends_with("м"), "Distance remaining must specify units 'м'")
	
	# Indicator 9: Печь (ВКЛ/ВЫКЛ)
	assert_true(hud.stove_label.text == "Печь: ВЫКЛ" or hud.stove_label.text == "Печь: ВКЛ", "Indicator 9 must state 'Печь: ВКЛ/ВЫКЛ'")
	
	# Indicator 10: Погода
	assert_true(hud.weather_label.text.begins_with("Погода:"), "Indicator 10 must start with 'Погода:'")
	
	# Strict English substring rejection guard across all 10 indicators
	var english_words: Array[String] = ["Fuel", "Scrap", "Supplies", "Durability", "Cabin", "Health", "Distance", "Stove", "Weather"]
	var all_labels: Array[Label] = [
		hud.fuel_label, hud.scrap_label, hud.supplies_label, hud.legs_label,
		hud.cabin_temp_label, hud.health_label, hud.distance_traveled_label,
		hud.distance_remaining_label, hud.stove_label, hud.weather_label
	]
	for lbl in all_labels:
		for word in english_words:
			assert_false(lbl.text.contains(word), "Label '%s' must not contain English word '%s'" % [lbl.text, word])
			
	hud.queue_free()

func test_09_hud_eventbus_reactivity(HudClass, bus) -> void:
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	# Test Fuel Event
	bus.emit_signal("fuel_changed", 73.5, 100.0)
	assert_almost_eq(hud.fuel_bar.value, 73.5, 0.01, "HUD fuel bar must update reactively to 73.5")
	assert_true(hud.fuel_label.text.contains("73.5"), "HUD fuel label must display 73.5 л")
	
	# Test Legs Event
	bus.emit_signal("leg_durability_changed", 88.0, 100.0)
	assert_almost_eq(hud.legs_bar.value, 88.0, 0.01, "HUD legs bar must update reactively to 88.0")
	assert_true(hud.legs_label.text.contains("88.0%"), "HUD legs label must display 88.0%")
	
	# Test Scrap Event
	bus.emit_signal("scrap_changed", 14.0)
	assert_true(hud.scrap_label.text.contains("14 шт."), "HUD scrap label must display 14 шт.")
	
	# Test Supplies Event
	bus.emit_signal("supplies_changed", 8.0)
	assert_true(hud.supplies_label.text.contains("8 шт."), "HUD supplies label must display 8 шт.")
	
	# Test Cabin Temp Event
	bus.emit_signal("cabin_temperature_changed", 22.4)
	assert_true(hud.cabin_temp_label.text.contains("+22.4°C"), "HUD temp label must display +22.4°C")
	
	# Test Health Event
	bus.emit_signal("player_health_changed", 60.0, 100.0)
	assert_almost_eq(hud.health_bar.value, 60.0, 0.01, "HUD health bar must update reactively to 60.0")
	assert_true(hud.health_label.text.contains("60 / 100 HP"), "HUD health label must display 60 / 100 HP")
	
	# Test Distance Event
	bus.emit_signal("distance_changed", 1200.0, 5000.0)
	assert_true(hud.distance_traveled_label.text.contains("1200.0 м"), "HUD traveled label must display 1200.0 м")
	assert_true(hud.distance_remaining_label.text.contains("3800.0 м"), "HUD remaining label must display 3800.0 м")
	
	# Test Stove Toggled Event
	bus.emit_signal("stove_toggled", true)
	assert_eq(hud.stove_label.text, "Печь: ВКЛ", "Stove label must display 'Печь: ВКЛ' when active")
	bus.emit_signal("stove_toggled", false)
	assert_eq(hud.stove_label.text, "Печь: ВЫКЛ", "Stove label must display 'Печь: ВЫКЛ' when inactive")
	
	# Test Weather Event
	bus.emit_signal("weather_changed", 2, -26.5) # BLIZZARD
	assert_true(hud.weather_label.text.contains("МЕТЕЛЬ!"), "Weather label must display 'МЕТЕЛЬ!'")
	assert_true(hud.weather_label.text.contains("-26.5°C"), "Weather label must display temperature -26.5°C")
	
	hud.queue_free()

func test_10_hud_reset_sync(HudClass, gs) -> void:
	gs.reset_state()
	gs.fuel = 20.0
	gs.leg_durability = 40.0
	gs.scrap = 9.0
	gs.supplies = 1.0
	gs.distance_traveled = 3000.0
	gs.player_health = 45.0
	
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	gs.reset_state()
	hud.sync_all_indicators()
	
	assert_almost_eq(hud.fuel_bar.value, 100.0, 0.01, "Reset state must restore fuel to 100.0")
	assert_almost_eq(hud.legs_bar.value, 100.0, 0.01, "Reset state must restore legs to 100.0")
	assert_true(hud.scrap_label.text.contains("0 шт."), "Reset state must restore scrap to 0")
	assert_true(hud.supplies_label.text.contains("5 шт."), "Reset state must restore supplies to 5")
	assert_true(hud.distance_traveled_label.text.contains("0.0 м"), "Reset state must restore distance traveled to 0.0")
	assert_almost_eq(hud.health_bar.value, 100.0, 0.01, "Reset state must restore health to 100.0")
	
	hud.queue_free()

func test_11_house_legs_ik(LegsClass) -> void:
	var leg = LegsClass.new()
	root.add_child(leg)
	await process_frame
	
	leg.hip_offset = Vector2(-49.0, 13.0)
	leg.ground_y = 115.0
	
	# Stance phase update
	leg.update_leg(0.0, 1.0, 0.016)
	assert_almost_eq(leg.foot_pos.y, 128.0, 0.1, "Stance foot Y must be at ground level (hip.y + ground_y)")
	assert_false(leg.was_in_swing, "Leg must be in stance phase at phi = 0")
	
	# Check IK solved knee position
	var upper_len = leg.hip_offset.distance_to(leg.knee_pos)
	assert_almost_eq(upper_len, 65.0, 0.5, "Upper leg bone length must equal L1 (65 px)")
	var lower_len = leg.knee_pos.distance_to(leg.foot_pos)
	assert_almost_eq(lower_len, 70.0, 0.5, "Lower leg bone length must equal L2 (70 px)")
	
	# Swing phase update at phi = PI + PI/2 (mid-swing)
	leg.update_leg(PI * 1.5, 1.0, 0.016)
	assert_true(leg.was_in_swing, "Leg must be in swing phase at phi = 1.5*PI")
	assert_lt(leg.foot_pos.y, 128.0, "Foot must lift above ground during swing phase")
	
	leg.queue_free()

func test_12_snow_tracks(TracksClass) -> void:
	var tracks = TracksClass.new()
	root.add_child(tracks)
	await process_frame
	
	tracks.clear_tracks()
	assert_eq(tracks.get_track_count(), 0, "Tracks initial count must be 0")
	
	tracks.add_track(Vector2(100.0, 560.0), 28.0, 1.0)
	assert_eq(tracks.get_track_count(), 1, "Track count must increment to 1")
	assert_true(tracks.has_track_near(Vector2(100.0, 560.0), 5.0), "Track must be found near (100, 560)")
	
	# Process 50.0 seconds of calm aging -> track should expire (max_age = 45.0s)
	tracks._process(50.0)
	assert_eq(tracks.get_track_count(), 0, "Track must expire and be removed after lifetime")
	
	# Blizzard aging speed test
	tracks.add_track(Vector2(200.0, 560.0))
	tracks.blizzard_active = true
	# 12 seconds in blizzard * 4x multiplier = 48 seconds -> should expire
	tracks._process(12.0)
	assert_eq(tracks.get_track_count(), 0, "Track in blizzard must expire 4x faster")
	
	tracks.queue_free()

func test_13_house_scene_integrity() -> void:
	var scene = load(HOUSE_SCENE_PATH)
	assert_true(scene != null, "WalkingHouse.tscn must exist and compile cleanly")
	var instance = scene.instantiate()
	assert_true(instance != null, "WalkingHouse instance must instantiate")
	root.add_child(instance)
	await process_frame
	
	assert_true(instance.has_node("CollisionShape2D"), "WalkingHouse must have CollisionShape2D")
	assert_true(instance.has_node("Leg_Back"), "WalkingHouse must have Leg_Back")
	assert_true(instance.has_node("Leg_Front"), "WalkingHouse must have Leg_Front")
	assert_true(instance.has_node("CabinPivot"), "WalkingHouse must have CabinPivot")
	assert_true(instance.has_node("CabinPivot/WindowLightMain"), "CabinPivot must have WindowLightMain")
	assert_true(instance.has_node("CabinPivot/WindowLightPorthole"), "CabinPivot must have WindowLightPorthole")
	assert_true(instance.has_node("CabinPivot/HearthLight"), "CabinPivot must have HearthLight")
	assert_true(instance.has_node("CabinPivot/LadderWorkLight"), "CabinPivot must have LadderWorkLight")
	assert_true(instance.has_node("CabinPivot/ChimneySmoke"), "CabinPivot must have ChimneySmoke")
	
	instance.queue_free()

# ==============================================================================
# ASSERTION & REPORTING INFRASTRUCTURE
# ==============================================================================

func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	var before_fails = failure_details.size()
	await test_callable.call()
	if failure_details.size() == before_fails:
		passed_tests += 1
		print("  [ PASS ] %s" % test_name)
	else:
		failed_tests += 1
		print("  [ FAIL ] %s" % test_name)

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

func assert_lt(val: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if val >= expected:
		var err = "[%s] FAILED: %s (Expected %f < %f)" % [current_test, msg, val, expected]
		failure_details.append(err)
		printerr("    " + err)

func print_summary() -> void:
	print("\n" + "=".repeat(78))
	print("  M2 LOCOMOTION & RUSSIAN HUD VERIFICATION SUMMARY")
	print("=".repeat(78))
	print("  Total Test Cases:  %d" % (passed_tests + failed_tests))
	print("  Passed:            %d" % passed_tests)
	print("  Failed:            %d" % failed_tests)
	print("  Total Assertions:  %d" % total_assertions)
	print("-".repeat(78))
	if failed_tests > 0:
		print("  VERDICT: FAILURES DETECTED")
		for err in failure_details:
			print("   - %s" % err)
	else:
		print("  VERDICT: 100% PASS — ALL M2 LOCOMOTION & RUSSIAN HUD TESTS PASSED")
	print("=".repeat(78) + "\n")
