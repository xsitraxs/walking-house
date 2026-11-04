# test_runner.gd — Headless E2E Test Runner for «Walking House»
# Invocation: & "E:\godot\Godot_v4.7.2-stable_win64.exe" --headless --path E:\project -s res://tests/test_runner.gd
extends SceneTree

const SUITE_PATHS: Array[String] = [
	"res://tests/suites/test_locomotion.gd",
	"res://tests/suites/test_exploration.gd",
	"res://tests/suites/test_economy_repairs.gd",
	"res://tests/suites/test_thermodynamics_weather.gd",
	"res://tests/suites/test_deadlock_detection.gd",
	"res://tests/suites/test_full_progression.gd",
	"res://tests/suites/test_challenger_adversarial.gd",
	"res://tests/test_m3_player_world.gd",
	"res://tests/test_m4_thermo_weather_upgrades.gd",
	"res://tests/test_m5_menus_lifecycle.gd"
]

var suite_count: int = 0
var tests_passed: int = 0
var tests_failed: int = 0
var tests_pending: int = 0
var total_tests: int = 0

var current_suite_name: String = ""
var current_test_name: String = ""
var current_test_failed: bool = false
var current_test_pending: bool = false
var current_pending_reason: String = ""
var current_assertion_count: int = 0
var failure_log: Array = []

func _init() -> void:
	print("\n" + "=".repeat(74))
	print("  «ШАГАЮЩИЙ ДОМ» (WALKING HOUSE) — HEADLESS E2E TEST RUNNER")
	print("  Godot Engine: %s" % Engine.get_version_info()["string"])
	print("  Dual Track: Category-Partition + BVA + Pairwise + Workload Scenarios")
	print("=".repeat(74) + "\n")
	
	var start_time: int = Time.get_ticks_msec()
	
	for suite_path in SUITE_PATHS:
		run_suite(suite_path)
	
	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	print_summary(elapsed_ms)
	
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func run_suite(path: String) -> void:
	if not FileAccess.file_exists(path):
		printerr("[ERROR] Test suite file not found: %s" % path)
		tests_failed += 1
		total_tests += 1
		failure_log.append("Suite file missing: %s" % path)
		return
	
	var script: GDScript = load(path)
	if script == null:
		printerr("[ERROR] Failed to load test suite script: %s" % path)
		tests_failed += 1
		total_tests += 1
		failure_log.append("Suite script failed to compile: %s" % path)
		return
	
	var suite_instance: Object = script.new()
	suite_count += 1
	var suite_title: String = suite_instance.get("suite_name") if ("suite_name" in suite_instance) else path.get_file()
	current_suite_name = suite_title
	
	print("\n" + "-".repeat(74))
	print(">> SUITE %d: %s" % [suite_count, suite_title])
	print("-".repeat(74))
	
	if suite_instance.has_method("run_suite"):
		suite_instance.call("run_suite", self)
	else:
		printerr("[ERROR] Test suite %s has no run_suite(runner) method" % path)
		tests_failed += 1
		total_tests += 1

func start_test(test_name: String) -> void:
	current_test_name = test_name
	current_test_failed = false
	current_test_pending = false
	current_pending_reason = ""
	current_assertion_count = 0
	total_tests += 1

func mark_pending(reason: String) -> void:
	current_test_pending = true
	current_pending_reason = reason

func end_test() -> void:
	if current_test_pending:
		tests_pending += 1
		print("  [PENDING] %-42s | Reason: %s" % [current_test_name, current_pending_reason])
	elif current_test_failed:
		tests_failed += 1
		print("  [ FAIL  ] %-42s | Failed assertions" % current_test_name)
	else:
		tests_passed += 1
		print("  [ PASS  ] %-42s | Assertions: %d" % [current_test_name, current_assertion_count])

func assert_true(condition: bool, message: String = "") -> void:
	current_assertion_count += 1
	if not condition:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected true, got false. %s" % [current_suite_name, current_test_name, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_false(condition: bool, message: String = "") -> void:
	current_assertion_count += 1
	if condition:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected false, got true. %s" % [current_suite_name, current_test_name, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_eq(actual, expected, message: String = "") -> void:
	current_assertion_count += 1
	if actual != expected:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected '%s', got '%s'. %s" % [current_suite_name, current_test_name, str(expected), str(actual), message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	current_assertion_count += 1
	if abs(actual - expected) > tolerance:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected ~%f (+/-%f), got %f. %s" % [current_suite_name, current_test_name, expected, tolerance, actual, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_gt(actual: float, expected: float, message: String = "") -> void:
	current_assertion_count += 1
	if actual <= expected:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected %f > %f. %s" % [current_suite_name, current_test_name, actual, expected, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_gte(actual: float, expected: float, message: String = "") -> void:
	current_assertion_count += 1
	if actual < expected:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected %f >= %f. %s" % [current_suite_name, current_test_name, actual, expected, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_lt(actual: float, expected: float, message: String = "") -> void:
	current_assertion_count += 1
	if actual >= expected:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected %f < %f. %s" % [current_suite_name, current_test_name, actual, expected, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func assert_lte(actual: float, expected: float, message: String = "") -> void:
	current_assertion_count += 1
	if actual > expected:
		current_test_failed = true
		var err_msg: String = "[FAIL in %s::%s] Expected %f <= %f. %s" % [current_suite_name, current_test_name, actual, expected, message]
		failure_log.append(err_msg)
		printerr("    Assertion Failed: " + err_msg)

func print_summary(elapsed_ms: int) -> void:
	print("\n" + "=".repeat(74))
	print("  TEST EXECUTION SUMMARY")
	print("=".repeat(74))
	print("  Suites Executed:  %d" % suite_count)
	print("  Total Tests:      %d" % total_tests)
	print("  [PASS] Passed:    %d" % tests_passed)
	print("  [PENDING] Queued: %d" % tests_pending)
	print("  [FAIL] Failed:    %d" % tests_failed)
	print("  Execution Time:   %d ms" % elapsed_ms)
	print("-".repeat(74))
	
	if tests_failed > 0:
		print("  OVERALL STATUS:   FAILED (%d failure(s) detected)" % tests_failed)
		print("  Failure Details:")
		for err in failure_log:
			print("   - %s" % err)
	elif tests_pending > 0:
		print("  OVERALL STATUS:   SUCCESS (All active tests passed; unbuilt modules pending)")
	else:
		print("  OVERALL STATUS:   SUCCESS (100% of all tests passed)")
	print("=".repeat(74) + "\n")
