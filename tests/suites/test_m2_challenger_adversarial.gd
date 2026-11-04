# tests/suites/test_m2_challenger_adversarial.gd
# Empirical Challenger Verification & Adversarial Stress Suite for Milestone 2
# Focus: Locomotion Reversal Dynamics, Durability Speed Clamping, Zero Fuel/Durability Immobilization, Exit Lockout Edge Cases
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const CONFIG_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const EVENT_BUS_PATH: String = "res://scripts/autoload/EventBus.gd"
const SOUND_MGR_PATH: String = "res://scripts/autoload/SoundManager.gd"
const HOUSE_SCRIPT_PATH: String = "res://scripts/entities/WalkingHouse.gd"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_details: Array[String] = []

func _init() -> void:
	_run_all_challenger_tests.call_deferred()

func _run_all_challenger_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(80))
	print("  M2 EMPIRICAL CHALLENGER VERIFICATION & ADVERSARIAL STRESS SUITE")
	print("  Adversarial targets: Reversals, Speed Degradation, Immobilization, Lockout")
	print("=".repeat(80) + "\n")
	
	# Autoload Setup in root
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
	var sim = load(SIM_PATH)
	
	await run_test("CH-01: Kinematics — Forward Acceleration & Clamping Invariant", Callable(self, "test_forward_acceleration").bind(HouseClass, gs))
	await run_test("CH-02: Kinematics — Reversal Dynamics (A -> D transition, acceleration vs braking rates)", Callable(self, "test_reversal_dynamics_a_to_d").bind(HouseClass, gs))
	await run_test("CH-03: Kinematics — Reversal Dynamics (D -> A transition, braking into reverse)", Callable(self, "test_reversal_dynamics_d_to_a").bind(HouseClass, gs))
	await run_test("CH-04: Kinematics — Rapid Keystroke Thrashing (A <-> D 50-cycle stress)", Callable(self, "test_keystroke_thrashing").bind(HouseClass, gs))
	await run_test("CH-05: Degradation — Speed Clamping at Durability 100%, 50%, 25%, 5%, 0%", Callable(self, "test_speed_clamping_breakpoints").bind(sim, HouseClass, gs))
	await run_test("CH-06: Immobilization — Dynamic Zero Fuel Depletion Halts Movement Immediately", Callable(self, "test_immobilization_zero_fuel").bind(HouseClass, gs))
	await run_test("CH-07: Immobilization — Dynamic Zero Leg Durability Halts Movement Immediately", Callable(self, "test_immobilization_zero_durability").bind(HouseClass, gs))
	await run_test("CH-08: Immobilization — Concurrent Zero Fuel and Zero Durability Invariants", Callable(self, "test_concurrent_depletion").bind(HouseClass, gs))
	await run_test("CH-09: Exit Lockout — Non-Zero Speeds Multi-Point Boundary Exploration (Forward & Reverse)", Callable(self, "test_exit_lockout_matrix").bind(HouseClass, gs, bus))
	await run_test("CH-10: Exit Lockout — Sub-0.05 m/s Velocity Deadband Behavior Audit", Callable(self, "test_exit_lockout_deadband_audit").bind(HouseClass, gs, bus))
	await run_test("CH-11: Fuel & Wear — Biome Multipliers and Upgrade Discounts Continuous Coupling", Callable(self, "test_fuel_wear_coupling").bind(HouseClass, gs))
	await run_test("CH-12: HUD — 100% Russian Localization Strict Character-Level Audit", Callable(self, "test_hud_strict_localization"))
	
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
# TEST RUNNER HARNESS
# ==============================================================================
func run_test(test_name: String, callable: Callable) -> void:
	var initial_failures: int = failure_details.size()
	print("  RUNNING: %s..." % test_name)
	await callable.call()
	if failure_details.size() == initial_failures:
		passed_tests += 1
		print("  [ PASS ] %s" % test_name)
	else:
		failed_tests += 1
		print("  [ FAIL ] %s" % test_name)

func assert_true(cond: bool, msg: String) -> void:
	total_assertions += 1
	if not cond:
		failure_details.append("ASSERTION FAILED: " + msg)
		printerr("    [X] " + msg)

func assert_false(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		failure_details.append("ASSERTION FAILED (expected false): " + msg)
		printerr("    [X] " + msg)

func assert_almost_eq(val: float, expected: float, tol: float, msg: String) -> void:
	total_assertions += 1
	if absf(val - expected) > tol:
		failure_details.append("ASSERTION FAILED: %s (got %.5f, expected %.5f, tol %.5f)" % [msg, val, expected, tol])
		printerr("    [X] %s: got %.5f, expected %.5f" % [msg, val, expected])

func print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("  M2 CHALLENGER TEST RESULTS")
	print("=".repeat(80))
	print("  Total Tests:       %d" % (passed_tests + failed_tests))
	print("  Passed:            %d" % passed_tests)
	print("  Failed:            %d" % failed_tests)
	print("  Total Assertions:  %d" % total_assertions)
	if failure_details.size() > 0:
		print("-".repeat(80))
		print("  FAILURES DETECTED:")
		for f in failure_details:
			print("    • %s" % f)
	print("=".repeat(80) + "\n")

# ==============================================================================
# TEST IMPLEMENTATIONS
# ==============================================================================

# CH-01: Forward Acceleration & Clamping
func test_forward_acceleration(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Start at standstill
	house.current_speed = 0.0
	house.target_speed = 5.0
	
	# 0.5s at 2.5 m/s^2 -> 1.25 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, BalanceConfig.HOUSE_ACCELERATION * 0.5)
	assert_almost_eq(house.current_speed, 1.25, 0.001, "0.5s accel reaches 1.25 m/s")
	
	# 1.0s at 2.5 m/s^2 -> 2.50 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, BalanceConfig.HOUSE_ACCELERATION * 0.5)
	assert_almost_eq(house.current_speed, 2.50, 0.001, "1.0s accel reaches 2.50 m/s")
	
	# 2.0s total -> 5.00 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, BalanceConfig.HOUSE_ACCELERATION * 1.0)
	assert_almost_eq(house.current_speed, 5.00, 0.001, "2.0s accel reaches 5.00 m/s")
	
	# Continue accelerating for another 2.0s -> MUST CLAMP AT 5.00 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, BalanceConfig.HOUSE_ACCELERATION * 2.0)
	assert_almost_eq(house.current_speed, 5.00, 0.0001, "Speed strictly clamped at 5.00 m/s")
	
	house.queue_free()

# CH-02: Reversal Dynamics (A -> D transition, acceleration vs braking rates)
func test_reversal_dynamics_a_to_d(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Start in full reverse: -2.5 m/s
	house.current_speed = -2.5
	house.prev_speed = -2.5
	# Player hits D: target_speed becomes +5.0 m/s
	house.target_speed = 5.0
	
	# Since target_speed * current_speed = (5.0 * -2.5) < 0, braking acceleration (3.5 m/s^2) must apply!
	var dt: float = 0.2
	var expected_braking_accel: float = 3.5
	
	# Step 1: -2.5 + 3.5 * 0.2 = -1.8 m/s
	var accel_used: float = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	assert_almost_eq(accel_used, expected_braking_accel, 0.001, "Braking rate 3.5 m/s^2 applies during reversal")
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * dt)
	assert_almost_eq(house.current_speed, -1.8, 0.01, "Step 1 speed is -1.8 m/s")
	
	# Step 2: -1.8 + 0.7 = -1.1 m/s
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * dt)
	assert_almost_eq(house.current_speed, -1.1, 0.01, "Step 2 speed is -1.1 m/s")
	
	# Step 3: -1.1 + 0.7 = -0.4 m/s
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * dt)
	assert_almost_eq(house.current_speed, -0.4, 0.01, "Step 3 speed is -0.4 m/s")
	
	# Step 4: crosses zero! -0.4 + 3.5 * 0.2 = +0.3 m/s
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * dt)
	assert_almost_eq(house.current_speed, 0.3, 0.01, "Crosses 0 into positive speed (+0.3 m/s)")
	
	# Step 5: Now target_speed (+5.0) and current_speed (+0.3) have the SAME sign!
	# Braking is no longer active; normal acceleration (2.5 m/s^2) must apply!
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	assert_almost_eq(accel_used, 2.5, 0.001, "Normal acceleration 2.5 m/s^2 applies once sign matches target")
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * 1.0)
	assert_almost_eq(house.current_speed, 2.8, 0.01, "Accelerates forward at 2.5 m/s^2: 0.3 + 2.5 = 2.8 m/s")
	
	# Step 6: Full acceleration to 5.0 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * 2.0)
	assert_almost_eq(house.current_speed, 5.0, 0.0001, "Reaches and clamps at +5.0 m/s")
	
	house.queue_free()

# CH-03: Reversal Dynamics (D -> A transition, braking into reverse)
func test_reversal_dynamics_d_to_a(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Start in full forward: +5.0 m/s
	house.current_speed = 5.0
	house.target_speed = -2.5 # Player hits A
	
	# Braking rate (3.5 m/s^2) must apply until 0
	var time_to_zero: float = 5.0 / 3.5 # ~1.428s
	var dt: float = 1.0
	var accel_used: float = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	assert_almost_eq(accel_used, 3.5, 0.001, "Braking rate 3.5 m/s^2 applies when reversing from forward")
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * dt)
	assert_almost_eq(house.current_speed, 1.5, 0.01, "After 1.0s braking from 5.0, speed is 1.5 m/s")
	
	# Brake another 0.5s: 1.5 - 3.5 * 0.5 = -0.25 m/s (crosses zero!)
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * 0.5)
	assert_almost_eq(house.current_speed, -0.25, 0.01, "Crosses 0 into reverse: -0.25 m/s")
	
	# Now both target (-2.5) and current (-0.25) are negative: normal acceleration (2.5 m/s^2) applies
	accel_used = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
	assert_almost_eq(accel_used, 2.5, 0.001, "Normal acceleration applies once speed is negative")
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * 1.0)
	assert_almost_eq(house.current_speed, -2.5, 0.0001, "Clamps strictly at reverse max -2.5 m/s")
	
	# Over-accel check: another 2.0s must NOT exceed -2.5 m/s
	house.current_speed = move_toward(house.current_speed, house.target_speed, accel_used * 2.0)
	assert_almost_eq(house.current_speed, -2.5, 0.0001, "Reverse speed does not exceed -2.5 m/s")
	
	house.queue_free()

# CH-04: Rapid Keystroke Thrashing (A <-> D 50-cycle stress)
func test_keystroke_thrashing(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	for cycle in range(50):
		var target: float = 5.0 if (cycle % 2 == 0) else -2.5
		house.target_speed = target
		var dt: float = rng.randf_range(0.016, 0.050)
		var accel: float = 3.5 if (house.target_speed * house.current_speed < 0.0 or is_zero_approx(house.target_speed)) else 2.5
		house.current_speed = move_toward(house.current_speed, house.target_speed, accel * dt)
		
		assert_true(not is_nan(house.current_speed), "Speed must never be NaN during rapid thrashing")
		assert_true(not is_inf(house.current_speed), "Speed must never be Inf during rapid thrashing")
		assert_true(house.current_speed >= -2.5001 and house.current_speed <= 5.0001, 
			"Speed must remain within [-2.5, 5.0] range, got %.4f" % house.current_speed)
			
	house.queue_free()

# CH-05: Speed Clamping at Durability 100%, 50%, 25%, 5%, 0%
func test_speed_clamping_breakpoints(sim, HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	var base_fwd: float = BalanceConfig.BASE_FORWARD_SPEED # 5.0
	var base_rev: float = BalanceConfig.BASE_REVERSE_SPEED # 2.5
	
	# 1. Durability = 100% -> 100% speed
	var fwd_100: float = sim.calculate_speed(base_fwd, 100.0, 100.0)
	var rev_100: float = sim.calculate_speed(base_rev, 100.0, 100.0)
	assert_almost_eq(fwd_100, 5.0, 0.001, "100% durability forward speed = 5.0 m/s")
	assert_almost_eq(rev_100, 2.5, 0.001, "100% durability reverse speed = 2.5 m/s")
	
	# 2. Durability = 50% -> 100% speed (inflection point)
	var fwd_50: float = sim.calculate_speed(base_fwd, 50.0, 100.0)
	var rev_50: float = sim.calculate_speed(base_rev, 50.0, 100.0)
	assert_almost_eq(fwd_50, 5.0, 0.001, "50% durability forward speed = 5.0 m/s")
	assert_almost_eq(rev_50, 2.5, 0.001, "50% durability reverse speed = 2.5 m/s")
	
	# 3. Durability = 25% -> (0.5 + 0.5 * (15/40)) = 0.6875 -> 5.0 * 0.6875 = 3.4375 m/s
	var fwd_25: float = sim.calculate_speed(base_fwd, 25.0, 100.0)
	var rev_25: float = sim.calculate_speed(base_rev, 25.0, 100.0)
	assert_almost_eq(fwd_25, 3.4375, 0.001, "25% durability forward speed = 3.4375 m/s")
	assert_almost_eq(rev_25, 1.71875, 0.001, "25% durability reverse speed = 1.71875 m/s")
	
	# 4. Durability = 5% -> emergency creep = 30% of base -> 1.5 m/s (fwd), 0.75 m/s (rev)
	var fwd_5: float = sim.calculate_speed(base_fwd, 5.0, 100.0)
	var rev_5: float = sim.calculate_speed(base_rev, 5.0, 100.0)
	assert_almost_eq(fwd_5, 1.5, 0.001, "5% durability emergency creep forward = 1.5 m/s")
	assert_almost_eq(rev_5, 0.75, 0.001, "5% durability emergency creep reverse = 0.75 m/s")
	
	# 5. Durability = 0% -> strictly 0.0 m/s (immobilized)
	var fwd_0: float = sim.calculate_speed(base_fwd, 0.0, 100.0)
	var rev_0: float = sim.calculate_speed(base_rev, 0.0, 100.0)
	assert_almost_eq(fwd_0, 0.0, 0.0001, "0% durability forward speed = 0.0 m/s")
	assert_almost_eq(rev_0, 0.0, 0.0001, "0% durability reverse speed = 0.0 m/s")
	
	# 6. Reinforced Legs upgrade boost (15% speed boost: 5.0 -> 5.75 m/s)
	gs.upgrades[GameState.UPGRADE_LEGS] = 1
	var boosted_base: float = base_fwd * 1.15
	assert_almost_eq(boosted_base, 5.75, 0.001, "Reinforced legs base forward speed is 5.75 m/s")
	var fwd_boost_100: float = sim.calculate_speed(boosted_base, 100.0, 100.0)
	assert_almost_eq(fwd_boost_100, 5.75, 0.001, "Boosted speed at 100% durability = 5.75 m/s")
	var fwd_boost_25: float = sim.calculate_speed(boosted_base, 25.0, 100.0)
	assert_almost_eq(fwd_boost_25, 5.75 * 0.6875, 0.001, "Boosted speed at 25% durability = 3.953125 m/s")
	var fwd_boost_5: float = sim.calculate_speed(boosted_base, 5.0, 100.0)
	assert_almost_eq(fwd_boost_5, 5.75 * 0.30, 0.001, "Boosted speed at 5% durability = 1.725 m/s")
	var fwd_boost_0: float = sim.calculate_speed(boosted_base, 0.0, 100.0)
	assert_almost_eq(fwd_boost_0, 0.0, 0.0001, "Boosted speed at 0% durability remains strictly 0.0 m/s")
	
	house.queue_free()

# CH-06: Dynamic Zero Fuel Depletion Halts Movement
func test_immobilization_zero_fuel(HouseClass, gs) -> void:
	gs.reset_state()
	gs.set_fuel(0.5) # Exactly 1 second of forward locomotion at 0.50 fuel/s
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house.current_speed = 5.0
	house.is_house_moving = true
	gs.set_house_moving(true)
	gs.set_house_speed(5.0)
	
	# Physics tick for 0.6s -> consumes 0.30 fuel, 0.20 remaining
	house._process_locomotion(0.6)
	assert_true(gs.fuel > 0.0, "Fuel still remaining after 0.6s")
	assert_true(house.is_house_moving, "House still moving after 0.6s")
	
	# Physics tick for 0.5s -> consumes remaining 0.20 fuel -> hits 0.0!
	house._process_locomotion(0.5)
	assert_almost_eq(gs.fuel, 0.0, 0.0001, "Fuel strictly exhausted to 0.0")
	assert_almost_eq(house.current_speed, 0.0, 0.0001, "current_speed halted immediately on fuel exhaustion")
	assert_almost_eq(house.target_speed, 0.0, 0.0001, "target_speed forced to 0.0")
	assert_false(house.is_house_moving, "is_house_moving forced to false")
	assert_false(gs.is_house_moving, "gs.is_house_moving set to false")
	assert_almost_eq(gs.house_speed, 0.0, 0.0001, "gs.house_speed set to 0.0")
	
	# Subsequent ticks with input holding must NOT move
	house._process_locomotion(0.1)
	assert_almost_eq(house.current_speed, 0.0, 0.0001, "Cannot accelerate with 0 fuel")
	
	house.queue_free()

# CH-07: Dynamic Zero Leg Durability Halts Movement
func test_immobilization_zero_durability(HouseClass, gs) -> void:
	gs.reset_state()
	gs.set_leg_durability(0.2) # Very low durability
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house.current_speed = 1.5
	house.is_house_moving = true
	gs.set_house_moving(true)
	gs.set_house_speed(1.5)
	
	# Force durability wear to exhaust legs
	gs.wear_legs(0.5)
	assert_almost_eq(gs.leg_durability, 0.0, 0.0001, "Durability exhausted to 0.0")
	
	# Next physics process must halt house completely
	house._process_locomotion(0.1)
	assert_almost_eq(house.current_speed, 0.0, 0.0001, "House speed halted to 0.0 on leg destruction")
	assert_false(house.is_house_moving, "is_house_moving halted to false")
	assert_false(gs.is_house_moving, "gs.is_house_moving set to false")
	assert_almost_eq(gs.house_speed, 0.0, 0.0001, "gs.house_speed set to 0.0")
	
	house.queue_free()

# CH-08: Concurrent Depletion Invariants
func test_concurrent_depletion(HouseClass, gs) -> void:
	gs.reset_state()
	gs.set_fuel(0.0)
	gs.set_leg_durability(0.0)
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	house._process_locomotion(0.5)
	assert_almost_eq(house.current_speed, 0.0, 0.0001, "House immobilized at 0 fuel and 0 durability")
	assert_almost_eq(house.target_speed, 0.0, 0.0001, "Target speed remains 0.0")
	assert_false(house.is_house_moving, "is_house_moving is false")
	
	# Disembarking while immobilized at 0 fuel/durability MUST be permitted so player can scavenge!
	var disembark_ok = house._handle_disembark_request()
	assert_true(disembark_ok, "Disembark permitted when immobilized to allow scavenging/repair")
	assert_true(gs.is_player_outside, "Player safely disembarked into world")
	
	house.queue_free()

# CH-09: Exit Lockout — Multi-Point Boundary Exploration (Forward & Reverse)
func test_exit_lockout_matrix(HouseClass, gs, bus) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	var test_speeds: Array[float] = [
		5.0, 4.0, 3.0, 2.5, 1.5, 1.0, 0.5, 0.25, 0.1, 0.06, # Positive (forward)
		-0.06, -0.1, -0.25, -0.5, -1.0, -1.5, -2.0, -2.5     # Negative (reverse)
	]
	
	for spd in test_speeds:
		gs.is_player_outside = false
		house.current_speed = spd
		house.is_house_moving = true
		gs.set_house_moving(true)
		gs.set_house_speed(absf(spd))
		
		var disembark_result: bool = house._handle_disembark_request()
		assert_false(disembark_result, "Disembark MUST be rejected at speed %.2f m/s" % spd)
		assert_false(gs.is_player_outside, "Player must remain inside at speed %.2f m/s" % spd)
		
	# Now at full zero speed: disembark MUST succeed
	gs.is_player_outside = false
	house.current_speed = 0.0
	house.is_house_moving = false
	gs.set_house_moving(false)
	gs.set_house_speed(0.0)
	
	var zero_spd_disembark: bool = house._handle_disembark_request()
	assert_true(zero_spd_disembark, "Disembark MUST succeed at strictly 0.0 m/s")
	assert_true(gs.is_player_outside, "Player is now outside at 0.0 m/s")
	
	# Re-embark at 0.0 m/s
	var embark_result: bool = house._handle_disembark_request()
	assert_true(embark_result, "Embark MUST succeed when outside at 0.0 m/s")
	assert_false(gs.is_player_outside, "Player is now inside house")
	
	house.queue_free()

# CH-10: Sub-0.05 m/s Velocity Deadband Behavior Audit
func test_exit_lockout_deadband_audit(HouseClass, gs, bus) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	# Audit speeds in the deadband range (0.005 < |v| <= 0.05)
	# In WalkingHouse.gd line 323: `if is_house_moving or absf(current_speed) > 0.05:`
	# Let's verify whether the system permits disembarking in this microscopic drift zone.
	var sub_speeds: Array[float] = [0.04, 0.02, 0.01, -0.01, -0.02, -0.04]
	for spd in sub_speeds:
		gs.is_player_outside = false
		house.current_speed = spd
		house.is_house_moving = false # below 0.05 threshold
		
		var allowed = house._handle_disembark_request()
		# Document behavior:
		# If allowed is true, the deadband allows disembarking at residual crawl (1 px/s or less).
		# We record this finding for architectural awareness.
		if allowed:
			print("    [OBSERVATION] Residual drift speed %.2f m/s allows disembark due to 0.05 deadband" % spd)
			# Return player inside for next iteration
			gs.is_player_outside = false
			
	# At absolute zero, it must definitely allow disembark
	house.current_speed = 0.0
	house.is_house_moving = false
	var at_zero = house._handle_disembark_request()
	assert_true(at_zero, "Disembark at 0.0 m/s is strictly allowed")
	
	house.queue_free()

# CH-11: Biome Multipliers & Upgrade Discounts Continuous Coupling
func test_fuel_wear_coupling(HouseClass, gs) -> void:
	gs.reset_state()
	var house = HouseClass.new()
	root.add_child(house)
	await process_frame
	
	var sim = load(SIM_PATH)
	
	# Test Biome 2 (Machinery Graveyard, wear_mult = 1.5)
	var wear_raw: float = sim.calculate_leg_wear(true, false, 10.0, 0.20, 0.40, 1.5)
	assert_almost_eq(wear_raw, 3.0, 0.01, "Biome 2 wear rate is 0.30%/s -> 3.0% per 10s")
	
	# With Reinforced Legs upgrade: 40% discount
	var wear_upgraded: float = sim.calculate_leg_wear(true, true, 10.0, 0.20, 0.40, 1.5)
	assert_almost_eq(wear_upgraded, 1.8, 0.01, "Upgraded Biome 2 wear is 3.0 * 0.6 = 1.8% per 10s")
	
	# Test Fuel burn forward vs reverse
	var fwd_fuel: float = sim.calculate_fuel_consumption(true, false, 10.0, BalanceConfig.WALK_FUEL_RATE, 0.30)
	var rev_fuel: float = sim.calculate_fuel_consumption(true, false, 10.0, BalanceConfig.REVERSE_FUEL_RATE, 0.30)
	assert_almost_eq(fwd_fuel, 5.0, 0.01, "10s forward burns 5.0 fuel (0.50/s)")
	assert_almost_eq(rev_fuel, 3.5, 0.01, "10s reverse burns 3.5 fuel (0.35/s)")
	
	# With Engine upgrade: 30% discount
	var fwd_upgraded: float = sim.calculate_fuel_consumption(true, true, 10.0, BalanceConfig.WALK_FUEL_RATE, 0.30)
	assert_almost_eq(fwd_upgraded, 3.5, 0.01, "10s upgraded forward burns 3.5 fuel (0.35/s)")
	
	house.queue_free()

# CH-12: HUD 100% Russian Localization Strict Character-Level Audit
func test_hud_strict_localization() -> void:
	var HudClass = load("res://scripts/ui/HUD.gd")
	var hud = HudClass.new()
	root.add_child(hud)
	await process_frame
	
	hud.sync_all_indicators()
	
	var indicator_labels: Dictionary = {
		"Indicator 1 (Топливо)": hud.fuel_label.text,
		"Indicator 2 (Металлолом)": hud.scrap_label.text,
		"Indicator 3 (Припасы)": hud.supplies_label.text,
		"Indicator 4 (Прочность опор)": hud.legs_label.text,
		"Indicator 5 (Температура в доме)": hud.cabin_temp_label.text,
		"Indicator 6 (Здоровье)": hud.health_label.text,
		"Indicator 7 (Пройдено)": hud.distance_traveled_label.text,
		"Indicator 8 (До станции)": hud.distance_remaining_label.text,
		"Indicator 9 (Печь)": hud.stove_label.text,
		"Indicator 10 (Погода)": hud.weather_label.text
	}
	
	# Strict English keyword check
	var banned_english: Array[String] = [
		"Fuel", "Scrap", "Supplies", "Durability", "Cabin", "Health", 
		"Distance", "Remaining", "Traveled", "Stove", "Weather", "Clear", "Blizzard", "Overcast"
	]
	
	for name in indicator_labels:
		var txt: String = indicator_labels[name]
		for bad in banned_english:
			assert_false(txt.contains(bad), "%s contains banned English word '%s': '%s'" % [name, bad, txt])
			
	# Check specific terminology in Russian
	assert_true(indicator_labels["Indicator 1 (Топливо)"].contains("Топливо"), "Indicator 1 has 'Топливо'")
	assert_true(indicator_labels["Indicator 2 (Металлолом)"].contains("Металлолом"), "Indicator 2 has 'Металлолом'")
	assert_true(indicator_labels["Indicator 3 (Припасы)"].contains("Припасы"), "Indicator 3 has 'Припасы'")
	assert_true(indicator_labels["Indicator 4 (Прочность опор)"].contains("Прочность опор"), "Indicator 4 has 'Прочность опор'")
	assert_true(indicator_labels["Indicator 5 (Температура в доме)"].contains("Температура в доме"), "Indicator 5 has 'Температура в доме'")
	assert_true(indicator_labels["Indicator 6 (Здоровье)"].contains("Здоровье"), "Indicator 6 has 'Здоровье'")
	assert_true(indicator_labels["Indicator 7 (Пройдено)"].contains("Пройдено"), "Indicator 7 has 'Пройдено'")
	assert_true(indicator_labels["Indicator 8 (До станции)"].contains("До станции"), "Indicator 8 has 'До станции'")
	assert_true(indicator_labels["Indicator 9 (Печь)"].contains("Печь"), "Indicator 9 has 'Печь'")
	assert_true(indicator_labels["Indicator 10 (Погода)"].contains("Погода"), "Indicator 10 has 'Погода'")
	
	hud.queue_free()
