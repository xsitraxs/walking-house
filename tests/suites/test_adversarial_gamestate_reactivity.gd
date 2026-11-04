# tests/suites/test_adversarial_gamestate_reactivity.gd
# Adversarial Stress Testing Harness for GameState Reactive Hooks & Cutoffs
# Author: Challenger 2
extends SceneTree

const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const EVENT_BUS_PATH: String = "res://scripts/autoload/EventBus.gd"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(76))
	print("  GAMESTATE REACTIVE HOOKS & SURVIVAL LIFECYCLE ADVERSARIAL HARNESS")
	print("  Scope: Auto-Cutoffs, Critical Stops, Freeze Game Over, Disembark Locks")
	print("=".repeat(76) + "\n")
	
	# Use autoload singletons in root
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
	
	run_test("Hook 1: Fuel Depletion Auto-Cutoff (Stove Extinguish & Critical Stop)", Callable(self, "test_hook_1_fuel_cutoff").bind(gs, bus))
	run_test("Hook 2: Leg Collapse Critical Stop & Motion Invalidation", Callable(self, "test_hook_2_leg_collapse").bind(gs, bus))
	run_test("Hook 3: Player Hypothermia Freeze Defeat Lifecycle", Callable(self, "test_hook_3_freeze_defeat").bind(gs, bus))
	run_test("Hook 4: Disembark Lockout During Locomotion & Safe Tethering", Callable(self, "test_hook_4_disembark_lockout").bind(gs, bus))
	run_test("Hook 5: Deadlock Signal & State Transition Integrity", Callable(self, "test_hook_5_deadlock_trigger").bind(gs, bus))
	run_test("Hook 6: Comprehensive State Reset & Idempotence", Callable(self, "test_hook_6_state_reset").bind(gs, bus))
	
	print_summary()
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	var before_fails = failure_details.size()
	test_callable.call()
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

func test_hook_1_fuel_cutoff(gs, bus) -> void:
	gs.reset_state()
	gs.set_fuel(10.0)
	gs.set_house_moving(true)
	gs.set_house_speed(5.0)
	var stove_lit = gs.toggle_stove()
	assert_true(stove_lit, "Stove lights when fuel > 0")
	assert_true(gs.is_stove_on, "Stove is active")
	
	var flags = {
		"stove_extinguished": false,
		"critical_stop": false
	}
	
	var cb1 = func(reason): flags["stove_extinguished"] = true
	var cb2 = func(reason): flags["critical_stop"] = true
	
	bus.connect("stove_extinguished", cb1)
	bus.connect("critical_stop_triggered", cb2)
	
	# Consume all remaining fuel down to 0
	gs.consume_fuel(15.0)
	
	assert_almost_eq(gs.fuel, 0.0, 0.001, "Fuel depleted to exactly 0.0")
	assert_false(gs.is_stove_on, "Stove auto-cut off when fuel hits 0")
	assert_false(gs.is_house_moving, "House movement halted when fuel hits 0")
	assert_almost_eq(gs.house_speed, 0.0, 0.001, "House speed reset to 0.0")
	assert_true(flags["stove_extinguished"], "EventBus emitted stove_extinguished")
	assert_true(flags["critical_stop"], "EventBus emitted critical_stop_triggered")
	
	# Attempting to re-light stove with 0 fuel must fail
	var relit = gs.toggle_stove()
	assert_false(relit, "Cannot light stove with 0 fuel")
	assert_false(gs.is_stove_on, "Stove remains off")
	
	bus.disconnect("stove_extinguished", cb1)
	bus.disconnect("critical_stop_triggered", cb2)

func test_hook_2_leg_collapse(gs, bus) -> void:
	gs.reset_state()
	gs.set_fuel(50.0)
	gs.set_leg_durability(5.0)
	gs.set_house_moving(true)
	gs.set_house_speed(2.5)
	
	var flags = {"critical_stop": false}
	var cb = func(reason): flags["critical_stop"] = true
	bus.connect("critical_stop_triggered", cb)
	
	# Wear legs to 0
	gs.wear_legs(10.0)
	
	assert_almost_eq(gs.leg_durability, 0.0, 0.001, "Legs depleted to 0.0")
	assert_false(gs.is_house_moving, "Movement halted upon leg collapse")
	assert_almost_eq(gs.house_speed, 0.0, 0.001, "Speed set to 0.0")
	assert_true(flags["critical_stop"], "Critical stop signal fired on leg collapse")
	
	# Attempting to move with collapsed legs must fail
	var move_attempt = gs.set_house_moving(true)
	assert_false(move_attempt, "Cannot start moving when legs are collapsed")
	assert_false(gs.is_house_moving, "House remains stationary")
	
	bus.disconnect("critical_stop_triggered", cb)

func test_hook_3_freeze_defeat(gs, bus) -> void:
	gs.reset_state()
	gs.player_health = 10.0
	
	var flags = {
		"game_over": false,
		"reason": ""
	}
	var cb = func(reason, stats):
		flags["game_over"] = true
		flags["reason"] = reason
		
	bus.connect("game_over_triggered", cb)
	
	# Player suffers fatal hypothermia damage
	gs.damage_player(15.0)
	
	assert_almost_eq(gs.player_health, 0.0, 0.001, "Health clamped to 0.0")
	assert_true(gs.is_game_over, "is_game_over is true")
	assert_false(gs.is_game_active, "is_game_active is false")
	assert_true(flags["game_over"], "game_over_triggered emitted")
	assert_true("Переохлаждение" in flags["reason"], "Game over reason indicates hypothermia")
	
	bus.disconnect("game_over_triggered", cb)

func test_hook_4_disembark_lockout(gs, bus) -> void:
	gs.reset_state()
	gs.set_house_moving(true)
	
	# Disembark attempt while house is moving MUST be rejected (Lockout R2 / F19)
	var disembark_success = gs.disembark_player()
	assert_false(disembark_success, "Disembark must be rejected while house is moving")
	assert_false(gs.is_player_outside, "Player remains inside cabin")
	
	# Stop house
	gs.set_house_moving(false)
	disembark_success = gs.disembark_player()
	assert_true(disembark_success, "Disembark succeeds when house is stopped")
	assert_true(gs.is_player_outside, "Player is outside")
	
	# House CANNOT start moving while player is outside
	var move_attempt = gs.set_house_moving(true)
	assert_false(move_attempt, "House cannot move while player is outside")
	assert_false(gs.is_house_moving, "House remains stationary")
	
	# Re-embark
	var embark_success = gs.embark_player()
	assert_true(embark_success, "Player re-embarks successfully")
	assert_false(gs.is_player_outside, "Player is inside")
	
	# Now house can move
	move_attempt = gs.set_house_moving(true)
	assert_true(move_attempt, "House can move now that player is safely inside")

func test_hook_5_deadlock_trigger(gs, bus) -> void:
	gs.reset_state()
	
	var flags = {
		"deadlock": false,
		"game_over": false
	}
	var cb_dl = func(): flags["deadlock"] = true
	var cb_go = func(reason, stats): flags["game_over"] = true
	
	bus.connect("deadlock_detected", cb_dl)
	bus.connect("game_over_triggered", cb_go)
	
	gs.trigger_deadlock("Тестовый тупик")
	
	assert_true(flags["deadlock"], "deadlock_detected signal fired")
	assert_true(flags["game_over"], "game_over_triggered signal fired")
	assert_true(gs.is_game_over, "Game state reflects game over")
	assert_false(gs.is_game_active, "Game is no longer active")
	assert_true("тупик" in gs.game_over_reason.to_lower(), "Reason logged correctly")
	
	bus.disconnect("deadlock_detected", cb_dl)
	bus.disconnect("game_over_triggered", cb_go)

func test_hook_6_state_reset(gs, bus) -> void:
	# Dirty up all state
	gs.fuel = 12.3
	gs.leg_durability = 45.6
	gs.distance_traveled = 1234.5
	gs.cabin_temperature = -5.0
	gs.player_health = 33.0
	gs.scrap = 99.0
	gs.supplies = 88.0
	gs.is_game_over = true
	gs.is_victory = true
	gs.upgrades["insulation"] = 2
	
	# Reset
	gs.reset_state()
	
	assert_almost_eq(gs.fuel, 100.0, 0.001, "Fuel reset to 100.0")
	assert_almost_eq(gs.leg_durability, 100.0, 0.001, "Leg durability reset to 100.0")
	assert_almost_eq(gs.distance_traveled, 0.0, 0.001, "Distance reset to 0.0")
	assert_almost_eq(gs.cabin_temperature, 18.0, 0.001, "Cabin temp reset to 18.0°C")
	assert_almost_eq(gs.player_health, 100.0, 0.001, "Player health reset to 100.0")
	assert_almost_eq(gs.scrap, 0.0, 0.001, "Scrap reset to 0.0")
	assert_almost_eq(gs.supplies, 5.0, 0.001, "Supplies reset to 5.0")
	assert_false(gs.is_game_over, "is_game_over reset to false")
	assert_false(gs.is_victory, "is_victory reset to false")
	assert_true(gs.is_game_active, "is_game_active reset to true")
	assert_eq(gs.upgrades["insulation"], 0, "Upgrades reset to 0")

func print_summary() -> void:
	print("\n" + "=".repeat(76))
	print("  GAMESTATE REACTIVE HOOKS SUMMARY")
	print("=".repeat(76))
	print("  Total Tests:       %d" % (passed_tests + failed_tests))
	print("  Passed:            %d" % passed_tests)
	print("  Failed:            %d" % failed_tests)
	print("  Total Assertions:  %d" % total_assertions)
	print("-".repeat(76))
	if failed_tests > 0:
		print("  VERDICT: REQUEST_CHANGES (%d failure(s) detected)" % failed_tests)
		for f in failure_details:
			print("    * " + f)
	else:
		print("  VERDICT: 100% PASS — REACTIVE HOOKS FULLY INTEGRATED & PROTECTED")
	print("=".repeat(76) + "\n")
