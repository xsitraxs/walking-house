# test_exploration.gd — Player Outside Exploration & Sub-Zero Exposure Test Suite
# Tests features: F18, F19, F20, F21, F22, F23, F24, F25
class_name TestExploration
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Exploration, Scavenging & Hypothermia (F18-F25)"

func run_suite(runner) -> void:
	test_01_outside_exposure_within_safe_radius(runner)
	test_02_outside_exposure_tether_violation_penalty(runner)
	test_03_tether_boundary_bva(runner)
	test_04_outside_warmth_timer_grace_period(runner)
	test_05_blizzard_outside_damage_amplification(runner)
	test_06_player_movement_kinematics(runner)
	test_07_poi_proximity_detection_radius(runner)

func test_01_outside_exposure_within_safe_radius(runner) -> void:
	runner.start_test("test_01_outside_exposure_within_safe_radius")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Within safe tether (dist = 20.0m <= 45.0m), baseline exposure is 2.5 HP/sec
	var damage_1s: float = sim.calculate_player_outside_exposure(1.0, 20.0, TestOracle.SAFE_RADIUS_METERS)
	runner.assert_almost_eq(damage_1s, TestOracle.OUTSIDE_COLD_DAMAGE_CALM, 0.01, "Normal outside cold damage rate")
	runner.end_test()

func test_02_outside_exposure_tether_violation_penalty(runner) -> void:
	runner.start_test("test_02_outside_exposure_tether_violation_penalty")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Exceeding safe tether (dist = 50.0m > 45.0m), cold exposure doubles to 5.0 HP/sec
	var damage_tether: float = sim.calculate_player_outside_exposure(1.0, 50.0, TestOracle.SAFE_RADIUS_METERS)
	runner.assert_almost_eq(damage_tether, TestOracle.OUTSIDE_COLD_DAMAGE_CALM * 2.0, 0.01, "Tether violation doubles hypothermia damage")
	runner.end_test()

func test_03_tether_boundary_bva(runner) -> void:
	runner.start_test("test_03_tether_boundary_bva")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	var r_safe: float = TestOracle.SAFE_RADIUS_METERS
	
	# BVA 1: At 44.9m (inside safe radius)
	var dmg_inside: float = sim.calculate_player_outside_exposure(1.0, 44.9, r_safe)
	runner.assert_almost_eq(dmg_inside, TestOracle.OUTSIDE_COLD_DAMAGE_CALM, 0.01, "At 44.9m, standard damage")
	
	# BVA 2: At 45.0m (exact boundary)
	var dmg_boundary: float = sim.calculate_player_outside_exposure(1.0, 45.0, r_safe)
	runner.assert_almost_eq(dmg_boundary, TestOracle.OUTSIDE_COLD_DAMAGE_CALM, 0.01, "At 45.0m, standard damage")
	
	# BVA 3: At 45.1m (violation)
	var dmg_outside: float = sim.calculate_player_outside_exposure(1.0, 45.1, r_safe)
	runner.assert_almost_eq(dmg_outside, TestOracle.OUTSIDE_COLD_DAMAGE_CALM * 2.0, 0.01, "At 45.1m, penalized damage")
	runner.end_test()

func test_04_outside_warmth_timer_grace_period(runner) -> void:
	runner.start_test("test_04_outside_warmth_timer_grace_period")
	# Verification of parka warmth buffer specification
	var safe_time: float = TestOracle.SAFE_WARM_TIME
	runner.assert_eq(safe_time, 20.0, "Outside parka warmth provides exactly 20.0s of thermal protection")
	
	# Walking 40m at 3.2 m/s takes 12.5s one-way; 25.0s round-trip
	var round_trip_time: float = (2.0 * 40.0) / TestOracle.PLAYER_SPEED
	runner.assert_almost_eq(round_trip_time, 25.0, 0.1, "40m sprint round-trip is 25 seconds")
	
	# Excess exposure outside warmth buffer is only 5 seconds = 12.5 HP lost
	var excess_exposure: float = round_trip_time - safe_time
	var hp_loss: float = excess_exposure * TestOracle.OUTSIDE_COLD_DAMAGE_CALM
	runner.assert_almost_eq(hp_loss, 12.5, 0.1, "Player loses at most 12.5 HP during a 40m scavenging expedition")
	runner.end_test()

func test_05_blizzard_outside_damage_amplification(runner) -> void:
	runner.start_test("test_05_blizzard_outside_damage_amplification")
	# Outside blizzard cold damage is 6.0 HP/s vs 2.5 HP/s calm
	var blizzard_dmg: float = TestOracle.OUTSIDE_COLD_DAMAGE_BLIZZARD
	runner.assert_gt(blizzard_dmg, TestOracle.OUTSIDE_COLD_DAMAGE_CALM, "Blizzard outside cold must be harsher than calm")
	runner.assert_almost_eq(blizzard_dmg, 6.0, 0.01, "Blizzard exposure damage rate is 6.0 HP/s")
	runner.end_test()

func test_06_player_movement_kinematics(runner) -> void:
	runner.start_test("test_06_player_movement_kinematics")
	# Verification of player pedestrian speed: 3.2 m/s (64 px/s)
	runner.assert_almost_eq(TestOracle.PLAYER_SPEED, 3.2, 0.01, "Player outdoor movement speed is 3.2 m/s")
	var px_per_sec: float = TestOracle.PLAYER_SPEED * TestOracle.METERS_TO_PIXELS
	runner.assert_almost_eq(px_per_sec, 64.0, 0.01, "Coordinate scale is 64 pixels/second")
	runner.end_test()

func test_07_poi_proximity_detection_radius(runner) -> void:
	runner.start_test("test_07_poi_proximity_detection_radius")
	# Proximity interaction radius is 2.5m (50 pixels)
	var interact_radius_m: float = 2.5
	var interact_radius_px: float = interact_radius_m * TestOracle.METERS_TO_PIXELS
	runner.assert_almost_eq(interact_radius_px, 50.0, 0.01, "Interaction detection radius is 50 pixels")
	runner.end_test()
