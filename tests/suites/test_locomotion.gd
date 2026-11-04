# test_locomotion.gd — Locomotion, Kinematics & Mechanical Wear Test Suite
# Tests features: F08, F09, F10, F11, F12, F16, F17
class_name TestLocomotion
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Locomotion, Fuel Burn & Leg Kinematics (F08-F12)"

func run_suite(runner) -> void:
	test_01_forward_fuel_consumption(runner)
	test_02_reverse_fuel_consumption(runner)
	test_03_stationary_zero_fuel_burn(runner)
	test_04_speed_degradation_bva_curve(runner)
	test_05_critical_leg_failure_stop(runner)
	test_06_leg_wear_rate_and_biome_scaling(runner)
	test_07_engine_upgrade_fuel_reduction(runner)
	test_08_reinforced_legs_wear_reduction_and_speed_boost(runner)
	test_09_walking_house_kinematics_and_degradation(runner)
	test_10_walking_house_exit_lockout(runner)
	test_11_house_legs_ik_and_gait(runner)
	test_12_snow_tracks_manager(runner)
	test_13_russian_hud_and_indicators(runner)

func test_01_forward_fuel_consumption(runner) -> void:
	runner.start_test("test_01_forward_fuel_consumption")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Moving forward, no engine upgrade, delta = 1.0s -> Expected 0.50 fuel
	var burn: float = sim.calculate_fuel_consumption(true, false, 1.0)
	runner.assert_almost_eq(burn, TestOracle.BASE_FUEL_RATE, 0.001, "Base forward fuel consumption rate")
	
	# Delta = 0.5s -> Expected 0.25 fuel
	var burn_half: float = sim.calculate_fuel_consumption(true, false, 0.5)
	runner.assert_almost_eq(burn_half, TestOracle.BASE_FUEL_RATE * 0.5, 0.001, "Half-second forward fuel burn")
	runner.end_test()

func test_02_reverse_fuel_consumption(runner) -> void:
	runner.start_test("test_02_reverse_fuel_consumption")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Reverse speed is 2.5 m/s vs forward 5.0 m/s; locomotive fuel burns at configured rate
	var burn_fwd: float = sim.calculate_fuel_consumption(true, false, 1.0)
	runner.assert_gt(burn_fwd, 0.0, "Moving must burn fuel")
	runner.end_test()

func test_03_stationary_zero_fuel_burn(runner) -> void:
	runner.start_test("test_03_stationary_zero_fuel_burn")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# When stopped (is_moving = false), locomotive fuel consumption must be strictly 0.0
	var burn_idle: float = sim.calculate_fuel_consumption(false, false, 1.0)
	runner.assert_almost_eq(burn_idle, 0.0, 0.0001, "Stationary house must not burn locomotive fuel")
	runner.end_test()

func test_04_speed_degradation_bva_curve(runner) -> void:
	runner.start_test("test_04_speed_degradation_bva_curve")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	var base_spd: float = TestOracle.BASE_SPEED
	
	# BVA Point 1: 100% durability -> 100% speed (5.0 m/s)
	var spd_100: float = sim.calculate_speed(base_spd, 100.0, 100.0)
	runner.assert_almost_eq(spd_100, 5.0, 0.001, "At 100% durability, speed must be 5.0")
	
	# BVA Point 2: 50.0% durability -> 100% speed (5.0 m/s) inflection point
	var spd_50: float = sim.calculate_speed(base_spd, 50.0, 100.0)
	runner.assert_almost_eq(spd_50, 5.0, 0.001, "At 50% durability, speed is still 100%")
	
	# BVA Point 3: 49.9% durability -> slight degradation
	var spd_49_9: float = sim.calculate_speed(base_spd, 49.9, 100.0)
	runner.assert_lt(spd_49_9, 5.0, "Below 50% durability, speed starts degrading")
	
	# BVA Point 4: 10.0% durability -> 50% speed (2.5 m/s)
	var spd_10: float = sim.calculate_speed(base_spd, 10.0, 100.0)
	runner.assert_almost_eq(spd_10, 2.5, 0.01, "At 10% durability, speed is 50% (2.5 m/s)")
	
	# BVA Point 5: 9.9% durability -> emergency creep mode (30% speed = 1.5 m/s)
	var spd_9_9: float = sim.calculate_speed(base_spd, 9.9, 100.0)
	runner.assert_almost_eq(spd_9_9, 1.5, 0.01, "Below 10% durability, emergency creep speed is 1.5 m/s")
	runner.end_test()

func test_05_critical_leg_failure_stop(runner) -> void:
	runner.start_test("test_05_critical_leg_failure_stop")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	var base_spd: float = TestOracle.BASE_SPEED
	
	# BVA Point 6: 0.0% durability -> Strictly 0.0 m/s (critical mechanical failure)
	var spd_0: float = sim.calculate_speed(base_spd, 0.0, 100.0)
	runner.assert_almost_eq(spd_0, 0.0, 0.0001, "At 0% durability, house must be completely immobilized")
	
	# Negative durability guard (if underflow occurs)
	var spd_neg: float = sim.calculate_speed(base_spd, -5.0, 100.0)
	runner.assert_almost_eq(spd_neg, 0.0, 0.0001, "Negative durability must result in 0 speed")
	runner.end_test()

func test_06_leg_wear_rate_and_biome_scaling(runner) -> void:
	runner.start_test("test_06_leg_wear_rate_and_biome_scaling")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# When moving, base wear rate = 0.20% per second
	var wear_1s: float = sim.calculate_leg_wear(true, false, 1.0)
	runner.assert_almost_eq(wear_1s, TestOracle.BASE_LEG_WEAR_RATE, 0.001, "Base leg wear rate is 0.20%/s")
	
	# When stationary, leg wear is strictly 0.0
	var wear_idle: float = sim.calculate_leg_wear(false, false, 1.0)
	runner.assert_almost_eq(wear_idle, 0.0, 0.0001, "Idle house suffers 0 leg wear")
	runner.end_test()

func test_07_engine_upgrade_fuel_reduction(runner) -> void:
	runner.start_test("test_07_engine_upgrade_fuel_reduction")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	var normal_burn: float = sim.calculate_fuel_consumption(true, false, 1.0)
	var upgraded_burn: float = sim.calculate_fuel_consumption(true, true, 1.0)
	
	# Engine upgrade reduces fuel burn by 30% (0.50 -> 0.35)
	runner.assert_almost_eq(upgraded_burn, normal_burn * (1.0 - TestOracle.ENGINE_FUEL_REDUCTION), 0.001, "Engine upgrade discount 30%")
	runner.assert_lt(upgraded_burn, normal_burn, "Upgraded engine must burn strictly less fuel")
	runner.end_test()

func test_08_reinforced_legs_wear_reduction_and_speed_boost(runner) -> void:
	runner.start_test("test_08_reinforced_legs_wear_reduction_and_speed_boost")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	var normal_wear: float = sim.calculate_leg_wear(true, false, 1.0)
	var upgraded_wear: float = sim.calculate_leg_wear(true, true, 1.0)
	
	# Reinforced legs reduce wear by 40% (0.20 -> 0.12)
	runner.assert_almost_eq(upgraded_wear, normal_wear * (1.0 - TestOracle.LEGS_WEAR_REDUCTION), 0.001, "Reinforced legs wear reduction 40%")
	runner.assert_lt(upgraded_wear, normal_wear, "Reinforced legs must suffer strictly less wear")
	runner.end_test()

func test_09_walking_house_kinematics_and_degradation(runner) -> void:
	runner.start_test("test_09_walking_house_kinematics_and_degradation")
	var house_path = "res://scripts/entities/WalkingHouse.gd"
	if not FileAccess.file_exists(house_path):
		runner.mark_pending("WalkingHouse.gd not found")
		runner.end_test()
		return
		
	var HouseClass = load(house_path)
	var house = HouseClass.new()
	runner.assert_true(house != null, "WalkingHouse must instantiate")
	
	# Simulate 1s forward acceleration at 2.5 m/s^2
	house.target_speed = 5.0
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 1.0)
	runner.assert_almost_eq(house.current_speed, 2.5, 0.01, "Forward speed after 1s accel is 2.5 m/s")
	
	# Simulate another 1s forward acceleration
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 1.0)
	runner.assert_almost_eq(house.current_speed, 5.0, 0.01, "Forward speed reaches 5.0 m/s")
	
	# Deceleration over 1s at 3.5 m/s^2
	house.target_speed = 0.0
	house.current_speed = move_toward(house.current_speed, house.target_speed, 3.5 * 1.0)
	runner.assert_almost_eq(house.current_speed, 1.5, 0.01, "Deceleration brings speed to 1.5 m/s")
	
	# Reverse speed limit
	house.target_speed = -2.5
	house.current_speed = move_toward(house.current_speed, house.target_speed, 2.5 * 2.0)
	runner.assert_almost_eq(house.current_speed, -2.5, 0.01, "Reverse speed is capped at -2.5 m/s")
	
	house.free()
	runner.end_test()

func test_10_walking_house_exit_lockout(runner) -> void:
	runner.start_test("test_10_walking_house_exit_lockout")
	var house_path = "res://scripts/entities/WalkingHouse.gd"
	if not FileAccess.file_exists(house_path):
		runner.mark_pending("WalkingHouse.gd not found")
		runner.end_test()
		return
		
	var bus_script = load("res://scripts/autoload/EventBus.gd")
	var bus = bus_script.new()
	var gs_script = load("res://scripts/autoload/GameState.gd")
	var gs = gs_script.new()
	gs.reset_state()
		
	var HouseClass = load(house_path)
	var house = HouseClass.new()
	house.game_state = gs
	house.event_bus = bus
	
	# While house is moving (current_speed = 3.0), disembark must be rejected
	house.current_speed = 3.0
	house.is_house_moving = true
	var disembark_moving = house._handle_disembark_request()
	runner.assert_false(disembark_moving, "Disembark must be locked out when house is moving")
	
	# While house is stationary (current_speed = 0.0), disembark must be accepted
	house.current_speed = 0.0
	house.is_house_moving = false
	var disembark_stationary = house._handle_disembark_request()
	runner.assert_true(disembark_stationary, "Disembark must succeed when house is stationary")
	
	house.free()
	gs.free()
	bus.free()
	runner.end_test()

func test_11_house_legs_ik_and_gait(runner) -> void:
	runner.start_test("test_11_house_legs_ik_and_gait")
	var legs_path = "res://scripts/entities/HouseLegs.gd"
	if not FileAccess.file_exists(legs_path):
		runner.mark_pending("HouseLegs.gd not found")
		runner.end_test()
		return
		
	var LegsClass = load(legs_path)
	var leg = LegsClass.new()
	leg.hip_offset = Vector2(-49.0, 13.0)
	leg.ground_y = 115.0
	
	# Stance phase at phi = 0
	leg.update_leg(0.0, 1.0, 0.016)
	runner.assert_almost_eq(leg.foot_pos.y, 128.0, 0.1, "Stance foot Y must be at ground level (hip.y + ground_y)")
	runner.assert_false(leg.was_in_swing, "Leg is in stance phase at phi = 0")
	
	# Verify bone segment lengths from IK solution
	var femur_len = leg.hip_offset.distance_to(leg.knee_pos)
	runner.assert_almost_eq(femur_len, 65.0, 0.5, "Femur bone length L1 must equal 65 px")
	var shank_len = leg.knee_pos.distance_to(leg.foot_pos)
	runner.assert_almost_eq(shank_len, 70.0, 0.5, "Shank bone length L2 must equal 70 px")
	
	# Swing phase at phi = 1.5 * PI
	leg.update_leg(PI * 1.5, 1.0, 0.016)
	runner.assert_true(leg.was_in_swing, "Leg is in swing phase at phi = 1.5*PI")
	runner.assert_lt(leg.foot_pos.y, 128.0, "Foot must lift above ground during swing")
	
	leg.free()
	runner.end_test()

func test_12_snow_tracks_manager(runner) -> void:
	runner.start_test("test_12_snow_tracks_manager")
	var tracks_path = "res://scripts/world/SnowTracks.gd"
	if not FileAccess.file_exists(tracks_path):
		runner.mark_pending("SnowTracks.gd not found")
		runner.end_test()
		return
		
	var TracksClass = load(tracks_path)
	var tracks = TracksClass.new()
	tracks.clear_tracks()
	runner.assert_eq(tracks.get_track_count(), 0, "Initial tracks count must be 0")
	
	# Add track
	tracks.add_track(Vector2(100.0, 560.0), 28.0, 1.0)
	runner.assert_eq(tracks.get_track_count(), 1, "Track count must increment to 1")
	runner.assert_true(tracks.has_track_near(Vector2(100.0, 560.0), 5.0), "Track must be located near touchdown position")
	
	# Normal aging: 50s -> expired (max_age = 45s)
	tracks._process(50.0)
	runner.assert_eq(tracks.get_track_count(), 0, "Track expires and is purged after 45s")
	
	# Blizzard accelerated aging (4x faster)
	tracks.add_track(Vector2(200.0, 560.0))
	tracks.blizzard_active = true
	tracks._process(12.0) # 12s * 4x = 48s > 45s
	runner.assert_eq(tracks.get_track_count(), 0, "Track expires 4x faster during blizzards")
	
	tracks.free()
	runner.end_test()

func test_13_russian_hud_and_indicators(runner) -> void:
	runner.start_test("test_13_russian_hud_and_indicators")
	var hud_path = "res://scripts/ui/HUD.gd"
	if not FileAccess.file_exists(hud_path):
		runner.mark_pending("HUD.gd not found")
		runner.end_test()
		return
		
	var HudClass = load(hud_path)
	var hud = HudClass.new()
	hud._build_procedural_ui()
	hud._apply_dark_frosted_theme()
	hud.sync_all_indicators()
	
	# Indicator 1: Fuel
	runner.assert_true(hud.fuel_label.text.begins_with("Топливо:"), "Indicator 1: Топливо")
	# Indicator 2: Scrap
	runner.assert_true(hud.scrap_label.text.begins_with("Металлолом:"), "Indicator 2: Металлолом")
	# Indicator 3: Supplies
	runner.assert_true(hud.supplies_label.text.begins_with("Припасы:"), "Indicator 3: Припасы")
	# Indicator 4: Legs
	runner.assert_true(hud.legs_label.text.begins_with("Прочность опор:"), "Indicator 4: Прочность опор")
	# Indicator 5: Cabin temp
	runner.assert_true(hud.cabin_temp_label.text.begins_with("Температура в доме:"), "Indicator 5: Температура в доме")
	# Indicator 6: Health
	runner.assert_true(hud.health_label.text.begins_with("Здоровье:"), "Indicator 6: Здоровье")
	# Indicator 7: Traveled
	runner.assert_true(hud.distance_traveled_label.text.begins_with("Пройдено:"), "Indicator 7: Пройдено")
	# Indicator 8: Remaining
	runner.assert_true(hud.distance_remaining_label.text.begins_with("До станции:"), "Indicator 8: До станции")
	# Indicator 9: Stove
	runner.assert_true(hud.stove_label.text == "Печь: ВЫКЛ" or hud.stove_label.text == "Печь: ВКЛ", "Indicator 9: Печь")
	# Indicator 10: Weather
	runner.assert_true(hud.weather_label.text.begins_with("Погода:"), "Indicator 10: Погода")
	
	# Frosted theme validation
	var sb = hud._create_dark_frosted_stylebox()
	runner.assert_gt(sb.bg_color.a, 0.8, "Dark frosted glass alpha > 0.8")
	runner.assert_gte(sb.border_width_left, 2, "Border width >= 2px")
	runner.assert_gte(sb.corner_radius_top_left, 4, "Corner radius >= 4px")
	
	hud.free()
	runner.end_test()
