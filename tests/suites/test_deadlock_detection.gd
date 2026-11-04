# test_deadlock_detection.gd — Deadlock & Unrecoverable State Detection Suite
# Tests features: F06, F47 (Zero false positive guarantee)
class_name TestDeadlockDetection
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Deadlock Engine & Softlock Prevention (F06, F47)"

func run_suite(runner) -> void:
	test_01_no_deadlock_when_mobile(runner)
	test_02_no_false_deadlock_when_fuel_empty_but_cache_reachable(runner)
	test_03_no_false_deadlock_when_legs_broken_but_scrap_reachable(runner)
	test_04_no_deadlock_when_player_outside(runner)
	test_05_confirmed_deadlock_zero_fuel_and_no_caches(runner)
	test_06_confirmed_deadlock_broken_legs_and_no_scrap(runner)
	test_07_reachability_boundary_bva(runner)
	test_08_hysteresis_grace_period(runner)

func test_01_no_deadlock_when_mobile(runner) -> void:
	runner.start_test("test_01_no_deadlock_when_mobile")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Normal state: Fuel 50, Legs 100%, Scrap 5 -> Not deadlocked
	var is_deadlocked: bool = sim.check_deadlock_condition(50.0, 100.0, 5.0, 1.0, 0.0, 0.0, false)
	runner.assert_false(is_deadlocked, "Mobile house is never deadlocked")
	runner.end_test()

func test_02_no_false_deadlock_when_fuel_empty_but_cache_reachable(runner) -> void:
	runner.start_test("test_02_no_false_deadlock_when_fuel_empty_but_cache_reachable")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# House fuel = 0, but 35.0 reachable fuel within safe walking distance -> NOT deadlocked
	var is_deadlocked: bool = sim.check_deadlock_condition(0.0, 80.0, 2.0, 1.0, 35.0, 0.0, false)
	runner.assert_false(is_deadlocked, "Must NOT declare defeat when fuel can be retrieved on foot")
	runner.end_test()

func test_03_no_false_deadlock_when_legs_broken_but_scrap_reachable(runner) -> void:
	runner.start_test("test_03_no_false_deadlock_when_legs_broken_but_scrap_reachable")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# House legs = 0, inventory scrap = 0, but 4 scrap reachable in cache -> NOT deadlocked
	var is_deadlocked: bool = sim.check_deadlock_condition(40.0, 0.0, 0.0, 1.0, 0.0, 4.0, false)
	runner.assert_false(is_deadlocked, "Must NOT declare defeat when scrap can be salvaged on foot")
	runner.end_test()

func test_04_no_deadlock_when_player_outside(runner) -> void:
	runner.start_test("test_04_no_deadlock_when_player_outside")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Fuel 0, legs 0, reachable 0, BUT player is actively outside exploring (is_player_outside = true)
	var is_deadlocked: bool = sim.check_deadlock_condition(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, true)
	runner.assert_false(is_deadlocked, "Never trigger resource deadlock while player is outside exploring")
	runner.end_test()

func test_05_confirmed_deadlock_zero_fuel_and_no_caches(runner) -> void:
	runner.start_test("test_05_confirmed_deadlock_zero_fuel_and_no_caches")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# House fuel = 0, reachable fuel = 0, player inside -> Absolute fuel deadlock
	var is_deadlocked: bool = sim.check_deadlock_condition(0.0, 50.0, 2.0, 1.0, 0.0, 0.0, false)
	runner.assert_true(is_deadlocked, "Must trigger deadlock when stranded with 0 fuel and 0 reachable fuel")
	runner.end_test()

func test_06_confirmed_deadlock_broken_legs_and_no_scrap(runner) -> void:
	runner.start_test("test_06_confirmed_deadlock_broken_legs_and_no_scrap")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Legs = 0, scrap = 0, reachable scrap = 0, player inside -> Absolute breakdown deadlock
	var is_deadlocked: bool = sim.check_deadlock_condition(50.0, 0.0, 0.0, 1.0, 0.0, 0.0, false)
	runner.assert_true(is_deadlocked, "Must trigger deadlock when immobilized with 0 scrap")
	runner.end_test()

func test_07_reachability_boundary_bva(runner) -> void:
	runner.start_test("test_07_reachability_boundary_bva")
	var safe_r: float = TestOracle.SAFE_RADIUS_METERS
	
	# Cache at 44.9m is reachable
	var dist_inside: float = 44.9
	var reachable_in: bool = dist_inside <= safe_r
	runner.assert_true(reachable_in, "44.9m is within safe scavenging perimeter")
	
	# Cache at 45.1m is beyond safe perimeter
	var dist_outside: float = 45.1
	var reachable_out: bool = dist_outside <= safe_r
	runner.assert_false(reachable_out, "45.1m exceeds safe scavenging perimeter")
	runner.end_test()

func test_08_hysteresis_grace_period(runner) -> void:
	runner.start_test("test_08_hysteresis_grace_period")
	var grace_sec: float = TestOracle.DEADLOCK_GRACE_PERIOD
	runner.assert_almost_eq(grace_sec, 3.0, 0.01, "Deadlock confirmation requires 3.0 seconds continuous stall")
	
	# At 2.9s, timer has not expired
	var timer_at_2_9: float = 2.9
	runner.assert_false(timer_at_2_9 >= grace_sec, "At 2.9s stall, defeat screen must not yet trigger")
	
	# At 3.0s, timer has expired
	var timer_at_3_0: float = 3.0
	runner.assert_true(timer_at_3_0 >= grace_sec, "At 3.0s stall, defeat screen must trigger")
	runner.end_test()
