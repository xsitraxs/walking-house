# tests/suites/test_adversarial_thermo_deadlock.gd
# Adversarial Stress Testing Harness by Challenger 2
# Focus: Thermodynamics, Newton Cooling Convergence, Blizzard Multipliers,
#        Outside Hypothermia, and Deadlock Detection (False/True Positives).
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const CONFIG_PATH: String = "res://scripts/core/BalanceConfig.gd"
const ORACLE_PATH: String = "res://tests/test_oracle.gd"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

func _init() -> void:
	print("\n" + "=".repeat(76))
	print("  ADVERSARIAL STRESS TEST HARNESS — CHALLENGER 2")
	print("  Scope: Thermodynamics, Weather, Hypothermia & Deadlock Oracles")
	print("=".repeat(76) + "\n")
	
	var sim = load(SIM_PATH)
	if sim == null:
		printerr("[FATAL] Could not load SimulationLogic at " + SIM_PATH)
		quit(1)
		return
	
	var oracle = load(ORACLE_PATH)
	
	# Execute all adversarial tracks
	run_test("Track 1A: Newton Cooling Asymptotic Convergence (Stove OFF)", Callable(self, "test_track_1a_cooling_convergence").bind(sim))
	run_test("Track 1B: Stove Active Equilibrium Convergence & Max Ceiling", Callable(self, "test_track_1b_stove_equilibrium").bind(sim))
	run_test("Track 1C: Blizzard Accelerated Cooling Rate & Insulation Discount", Callable(self, "test_track_1c_blizzard_insulation_rates").bind(sim))
	run_test("Track 1D: Thermal Extreme Boundary & Negative Delta Invariance", Callable(self, "test_track_1d_thermal_boundaries_and_deltas").bind(sim))
	run_test("Track 2A: Outside Exposure Tether Boundary & Penalty Scaling", Callable(self, "test_track_2a_tether_boundary").bind(sim))
	run_test("Track 2B: Outside Cold Damage Buffer & Blizzard Amplification", Callable(self, "test_track_2b_outside_damage").bind(sim))
	run_test("Track 2C: Cabin Freezing vs Warmth Recovery Hysteresis", Callable(self, "test_track_2c_cabin_freeze_and_recovery").bind(sim))
	run_test("Track 3A: Deadlock False-Positive Resistance (Scavenging & Proximity)", Callable(self, "test_track_3a_deadlock_false_positives").bind(sim))
	run_test("Track 3B: Deadlock True-Positive Triggering (Unrecoverable States)", Callable(self, "test_track_3b_deadlock_true_positives").bind(sim))
	run_test("Track 3C: Deadlock Combinatorial Matrix & Boundary Edge Cases", Callable(self, "test_track_3c_deadlock_combinatorial").bind(sim))
	run_test("Track 3D: Deadlock Hysteresis Grace Period & Transient Reset", Callable(self, "test_track_3d_deadlock_hysteresis").bind(sim))
	
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

# ==============================================================================
# TRACK 1: THERMODYNAMICS & NEWTON COOLING
# ==============================================================================

## Stress tests multi-step Newton cooling convergence towards ambient outside temperature.
## Verifies asymptotic convergence, monotonic decrease, and no overshoot.
func test_track_1a_cooling_convergence(sim) -> void:
	var outside_temps = [-10.0, -20.0, -35.0, -45.0]
	
	for out_temp in outside_temps:
		var t_cabin: float = 20.0 # start at warm 20°C
		var delta: float = 0.1 # 100ms ticks
		var total_time: float = 300.0 # 5 minutes of cooling (3000 steps)
		var steps: int = int(total_time / delta)
		
		var prev_temp: float = t_cabin
		for step in range(steps):
			t_cabin = sim.calculate_cabin_temperature(t_cabin, out_temp, false, false, false, delta)
			# Strictly monotonic decrease towards outside temp
			assert_true(t_cabin <= prev_temp, "Cooling must be monotonically decreasing at step %d" % step)
			# Never drop below outside temp
			assert_true(t_cabin >= out_temp - 0.001, "Cabin temp cannot drop below outside temp: %.4f < %.4f" % [t_cabin, out_temp])
			prev_temp = t_cabin
		
		# Analytical expected: T(t) = T_out + (T_0 - T_out) * exp(-k * t)
		# k = 0.025, t = 300.0 => exp(-0.025 * 300) = exp(-7.5) = ~0.000553
		# Analytical T(300) ≈ T_out + (20 - T_out) * 0.000553
		var expected_analytical = out_temp + (20.0 - out_temp) * exp(-0.025 * total_time)
		assert_almost_eq(t_cabin, expected_analytical, 0.05, "Multi-step Euler matches analytical Newton solution for T_out=%.1f" % out_temp)

## Tests stove active heating convergence, equilibrium temperatures, and maximum ceiling clamping (+24°C).
func test_track_1b_stove_equilibrium(sim) -> void:
	# 1. Calm weather equilibrium test
	# Equilibrium: -k*(T_eq - T_out) + q_stove = 0 => T_eq = T_out + q_stove / k
	# q_stove = 1.1, k = 0.025 => q_stove / k = 44.0°C.
	# If T_out = -15°C, uncapped T_eq = -15 + 44 = +29°C.
	# But CABIN_MAX_TEMP = 24.0°C, so cabin must clamp at exactly +24.0°C!
	var t_cabin: float = 0.0
	for i in range(2000): # 200 seconds of stove heating
		t_cabin = sim.calculate_cabin_temperature(t_cabin, -15.0, true, false, false, 0.1)
	assert_almost_eq(t_cabin, 24.0, 0.01, "Cabin temperature capped at exactly 24.0°C ceiling")
	
	# 2. Blizzard equilibrium (uninsulated):
	# k = 0.025 * 1.8 = 0.045 => q_stove / k = 1.1 / 0.045 = 24.444°C
	# If T_out = -20°C: T_eq = -20 + 24.444 = +4.444°C.
	# Does the cabin converge to +4.444°C?
	var t_blizz: float = 0.0
	for i in range(3000): # 300 seconds
		t_blizz = sim.calculate_cabin_temperature(t_blizz, -20.0, true, false, true, 0.1)
	var expected_eq_blizz = -20.0 + (1.1 / 0.045)
	assert_almost_eq(t_blizz, expected_eq_blizz, 0.05, "Blizzard uninsulated equilibrium matches analytical 4.44°C")
	
	# 3. Severe blizzard freezing hazard without insulation:
	# If T_out = -30°C: T_eq = -30 + 24.444 = -5.556°C (SUB-ZERO despite active stove!)
	var t_severe: float = 0.0
	for i in range(3000):
		t_severe = sim.calculate_cabin_temperature(t_severe, -30.0, true, false, true, 0.1)
	assert_true(t_severe < 0.0, "Severe blizzard (-30°C) without insulation drops cabin below freezing even with stove")
	
	# 4. Insulation saving effect in severe blizzard:
	# With insulation: k = 0.045 * 0.55 = 0.02475 => q_stove / k = 1.1 / 0.02475 = 44.444°C
	# If T_out = -30°C: T_eq = -30 + 44.444 = +14.444°C (SURVIVABLE!)
	var t_insulated: float = 0.0
	for i in range(3000):
		t_insulated = sim.calculate_cabin_temperature(t_insulated, -30.0, true, true, true, 0.1)
	var expected_insulated = -30.0 + (1.1 / 0.02475)
	assert_almost_eq(t_insulated, expected_insulated, 0.05, "Insulation upgrade enables survivable +14.44°C in severe blizzard")

## Verifies exact blizzard cooling multiplier (1.8x) and insulation retention (-45%).
func test_track_1c_blizzard_insulation_rates(sim) -> void:
	var delta = 1.0
	var t_init = 10.0
	var t_out = -20.0
	var diff = t_init - t_out # 30.0°C
	
	# Rate 1: Calm, uninsulated -> loss = 0.025 * 30 = 0.75°C
	var loss_calm = t_init - sim.calculate_cabin_temperature(t_init, t_out, false, false, false, delta)
	assert_almost_eq(loss_calm, 0.75, 0.001, "Calm baseline cooling loss is 0.75°C")
	
	# Rate 2: Blizzard, uninsulated -> loss = 0.025 * 1.8 * 30 = 1.35°C
	var loss_blizz = t_init - sim.calculate_cabin_temperature(t_init, t_out, false, false, true, delta)
	assert_almost_eq(loss_blizz, 1.35, 0.001, "Blizzard cooling loss is 1.35°C (exactly 1.8x)")
	assert_almost_eq(loss_blizz / loss_calm, 1.8, 0.001, "Blizzard multiplier is strictly 1.800x")
	
	# Rate 3: Calm, insulated -> loss = 0.025 * 0.55 * 30 = 0.4125°C
	var loss_ins = t_init - sim.calculate_cabin_temperature(t_init, t_out, false, true, false, delta)
	assert_almost_eq(loss_ins, 0.4125, 0.001, "Insulation cooling loss is 0.4125°C (-45% loss)")
	assert_almost_eq(loss_ins / loss_calm, 0.55, 0.001, "Insulation multiplier is strictly 0.550x")
	
	# Rate 4: Blizzard, insulated -> loss = 0.025 * 1.8 * 0.55 * 30 = 0.7425°C
	var loss_both = t_init - sim.calculate_cabin_temperature(t_init, t_out, false, true, true, delta)
	assert_almost_eq(loss_both, 0.7425, 0.001, "Blizzard + Insulation loss is 0.7425°C (1.8 * 0.55 = 0.99x calm)")

## Adversarial edge case stress: zero delta, negative delta, boundary clamping at -50°C and +24°C.
func test_track_1d_thermal_boundaries_and_deltas(sim) -> void:
	# Zero delta -> unchanged
	assert_almost_eq(sim.calculate_cabin_temperature(12.5, -20.0, false, false, false, 0.0), 12.5, 0.0001, "Zero delta returns identical temp")
	# Negative delta -> unchanged
	assert_almost_eq(sim.calculate_cabin_temperature(12.5, -20.0, false, false, false, -5.0), 12.5, 0.0001, "Negative delta returns identical temp")
	
	# Boundary clamping at -50.0°C minimum
	var extreme_cold = sim.calculate_cabin_temperature(-49.5, -100.0, false, false, true, 10.0)
	assert_true(extreme_cold >= -50.0, "Cabin temp cannot drop below -50.0°C clamp")
	
	# Boundary clamping at +24.0°C maximum
	var extreme_hot = sim.calculate_cabin_temperature(23.9, 50.0, true, true, false, 10.0)
	assert_true(extreme_hot <= 24.0, "Cabin temp cannot exceed +24.0°C clamp")
	
	# Reverse thermal gradient (inside colder than outside: ambient heating)
	# Inside -20°C, Outside -5°C -> should warm up towards -5°C
	var warmed = sim.calculate_cabin_temperature(-20.0, -5.0, false, false, false, 1.0)
	assert_true(warmed > -20.0, "Cabin warms towards ambient when colder than outside")

# ==============================================================================
# TRACK 2: OUTSIDE EXPOSURE & HYPOTHERMIA
# ==============================================================================

## Tests the 45m safe tether radius BVA and 2.0x exposure penalty outside.
func test_track_2a_tether_boundary(sim) -> void:
	var safe_r = 45.0
	var base_rate = 2.5
	var penalty_rate = 5.0
	
	# Within safe radius
	assert_almost_eq(sim.calculate_player_outside_exposure(1.0, 0.0, safe_r), base_rate, 0.001, "At house (0m): 2.5 HP/s")
	assert_almost_eq(sim.calculate_player_outside_exposure(1.0, 44.99, safe_r), base_rate, 0.001, "At 44.99m: 2.5 HP/s")
	assert_almost_eq(sim.calculate_player_outside_exposure(1.0, 45.00, safe_r), base_rate, 0.001, "At exact 45.00m boundary: 2.5 HP/s")
	
	# Outside safe radius (tether penalty 2.0x)
	assert_almost_eq(sim.calculate_player_outside_exposure(1.0, 45.01, safe_r), penalty_rate, 0.001, "At 45.01m: 5.0 HP/s")
	assert_almost_eq(sim.calculate_player_outside_exposure(1.0, 100.0, safe_r), penalty_rate, 0.001, "At 100m: 5.0 HP/s")
	
	# Zero and negative delta
	assert_almost_eq(sim.calculate_player_outside_exposure(0.0, 10.0, safe_r), 0.0, 0.0001, "Zero delta yields 0 exposure")
	assert_almost_eq(sim.calculate_player_outside_exposure(-2.0, 10.0, safe_r), 0.0, 0.0001, "Negative delta yields 0 exposure")

## Tests warm clothing buffer (20.0s) and outside cold damage rates (calm 2.5 HP/s, blizzard 6.0 HP/s).
func test_track_2b_outside_damage(sim) -> void:
	# Inside 20s warm buffer -> 0 damage
	assert_almost_eq(sim.calculate_outside_cold_damage(0.0, 20.0, false, 1.0), 0.0, 0.0001, "0s exposure: 0 damage")
	assert_almost_eq(sim.calculate_outside_cold_damage(19.99, 20.0, false, 1.0), 0.0, 0.0001, "19.99s exposure: 0 damage")
	assert_almost_eq(sim.calculate_outside_cold_damage(20.00, 20.0, false, 1.0), 0.0, 0.0001, "20.00s exposure: 0 damage")
	assert_almost_eq(sim.calculate_outside_cold_damage(19.99, 20.0, true, 1.0), 0.0, 0.0001, "19.99s blizzard: 0 damage")
	
	# Exceeded buffer in calm weather: 2.5 HP/s
	assert_almost_eq(sim.calculate_outside_cold_damage(20.01, 20.0, false, 1.0), 2.5, 0.001, "Past buffer calm: 2.5 HP/s")
	assert_almost_eq(sim.calculate_outside_cold_damage(30.00, 20.0, false, 2.0), 5.0, 0.001, "Past buffer calm 2s: 5.0 HP")
	
	# Exceeded buffer in blizzard: 6.0 HP/s (2.4x damage multiplier!)
	assert_almost_eq(sim.calculate_outside_cold_damage(20.01, 20.0, true, 1.0), 6.0, 0.001, "Past buffer blizzard: 6.0 HP/s")
	assert_almost_eq(sim.calculate_outside_cold_damage(30.00, 20.0, true, 2.0), 12.0, 0.001, "Past buffer blizzard 2s: 12.0 HP")
	
	# Lethality simulation: At 6.0 HP/s, 100 HP is drained in 16.67 seconds after the 20s buffer
	var exposure = 20.0
	var hp = 100.0
	var seconds = 0.0
	while hp > 0.0:
		exposure += 0.5
		seconds += 0.5
		var dmg = sim.calculate_outside_cold_damage(exposure, 20.0, true, 0.5)
		hp -= dmg
	assert_almost_eq(seconds, 16.67, 0.5, "Fatal blizzard outside hypothermia occurs in ~16.7s after buffer")

## Tests cabin freezing damage (<0°C) and warmth recovery (>=10°C).
func test_track_2c_cabin_freeze_and_recovery(sim) -> void:
	# Freezing damage: 0.5 * |temp| * delta for temp < 0
	assert_almost_eq(sim.calculate_cabin_cold_damage(5.0, 1.0), 0.0, 0.0001, "No damage at +5°C")
	assert_almost_eq(sim.calculate_cabin_cold_damage(0.0, 1.0), 0.0, 0.0001, "No damage at 0.0°C")
	assert_almost_eq(sim.calculate_cabin_cold_damage(-0.1, 1.0), 0.05, 0.001, "Damage at -0.1°C: 0.05 HP/s")
	assert_almost_eq(sim.calculate_cabin_cold_damage(-10.0, 1.0), 5.0, 0.001, "Damage at -10.0°C: 5.0 HP/s")
	assert_almost_eq(sim.calculate_cabin_cold_damage(-20.0, 2.0), 20.0, 0.001, "Damage at -20.0°C for 2s: 20.0 HP")
	
	# Warmth recovery: 0.5 HP/s for temp >= 10°C
	assert_almost_eq(sim.calculate_warmth_recovery(9.99, 1.0), 0.0, 0.0001, "No recovery at 9.99°C")
	assert_almost_eq(sim.calculate_warmth_recovery(10.00, 1.0), 0.5, 0.001, "Recovery at 10.0°C: 0.5 HP/s")
	assert_almost_eq(sim.calculate_warmth_recovery(20.00, 4.0), 2.0, 0.001, "Recovery at 20.0°C for 4s: 2.0 HP")
	
	# Neutral dead-zone (0.0°C to 9.99°C): neither damage nor healing
	for t in [0.0, 2.5, 5.0, 7.5, 9.9]:
		assert_almost_eq(sim.calculate_cabin_cold_damage(t, 1.0), 0.0, 0.0001, "Dead zone temp %.1f has 0 damage" % t)
		assert_almost_eq(sim.calculate_warmth_recovery(t, 1.0), 0.0, 0.0001, "Dead zone temp %.1f has 0 recovery" % t)

# ==============================================================================
# TRACK 3: DEADLOCK DETECTION ENGINE (ZERO FALSE POSITIVES & TRUE POSITIVES)
# ==============================================================================

## Adversarially tests false-positive resistance:
## Verifies that NO deadlock is reported when resources exist nearby or player is outside.
func test_track_3a_deadlock_false_positives(sim) -> void:
	# 1. Player is outside scavenging: MUST NEVER DECLARE DEADLOCK, even if fuel=0, legs=0, reachable=0!
	assert_false(sim.check_deadlock_condition(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, true),
		"Player actively scavenging outside must NEVER trigger deadlock")
	assert_false(sim.check_deadlock_condition(0.0, 50.0, 0.0, 1.0, 0.0, 0.0, true),
		"Player outside with 0 fuel must not trigger deadlock")
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 0.0, 1.0, 0.0, 0.0, true),
		"Player outside with broken legs must not trigger deadlock")
	
	# 2. Fuel is 0, but reachable fuel exists within safe perimeter:
	assert_false(sim.check_deadlock_condition(0.0, 100.0, 0.0, 1.0, 0.001, 0.0, false),
		"0.001 reachable fuel prevents deadlock")
	assert_false(sim.check_deadlock_condition(0.0, 100.0, 0.0, 1.0, 30.0, 0.0, false),
		"30.0 reachable fuel prevents deadlock")
	
	# 3. Legs are broken (0%), but scrap is in inventory:
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 1.0, 1.0, 0.0, 0.0, false),
		"1.0 scrap in inventory prevents deadlock when legs broken")
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 10.0, 1.0, 0.0, 0.0, false),
		"10.0 scrap in inventory prevents deadlock when legs broken")
	
	# 4. Legs are broken (0%), inventory scrap is 0, but reachable scrap exists:
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 0.0, 1.0, 0.0, 1.0, false),
		"1.0 reachable scrap prevents deadlock when legs broken")
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 0.0, 1.0, 0.0, 5.0, false),
		"5.0 reachable scrap prevents deadlock when legs broken")
	
	# 5. Combined fractional scrap: 0.5 in inventory + 0.5 reachable = 1.0 >= min_repair_cost:
	assert_false(sim.check_deadlock_condition(50.0, 0.0, 0.5, 1.0, 0.0, 0.5, false),
		"Combined scrap (0.5 inv + 0.5 cache >= 1.0) prevents deadlock")
	
	# 6. Legs at creep threshold (0.01%):
	# House can still creep at 30% speed! Not stalled!
	assert_false(sim.check_deadlock_condition(50.0, 0.01, 0.0, 1.0, 0.0, 0.0, false),
		"Creep speed legs (0.01%) allows reaching caches ahead, not deadlocked")
	
	# 7. Fuel at trace level (0.01):
	assert_false(sim.check_deadlock_condition(0.01, 50.0, 0.0, 1.0, 0.0, 0.0, false),
		"Trace fuel (0.01) allows creeping to cache, not deadlocked")

## Adversarially tests true-positive triggering:
## Verifies that deadlock is PROMPTLY and STRICTLY detected when continuation is impossible.
func test_track_3b_deadlock_true_positives(sim) -> void:
	# 1. Pure fuel exhaustion with 0 reachable fuel (even with pristine 100% legs & scrap):
	assert_true(sim.check_deadlock_condition(0.0, 100.0, 50.0, 1.0, 0.0, 50.0, false),
		"Zero fuel + zero reachable fuel is fatal deadlock regardless of legs/scrap")
	
	# 2. Pure chassis collapse with 0 scrap & 0 reachable scrap (even with 100% fuel):
	assert_true(sim.check_deadlock_condition(100.0, 0.0, 0.0, 1.0, 100.0, 0.0, false),
		"Zero leg durability + zero scrap is fatal deadlock regardless of fuel")
	
	# 3. Sub-repair scrap shortage: scrap in inv = 0.4, reachable = 0.5 -> total 0.9 < 1.0 min repair cost:
	assert_true(sim.check_deadlock_condition(100.0, 0.0, 0.4, 1.0, 50.0, 0.5, false),
		"Total scrap 0.9 < 1.0 cannot repair legs -> fatal deadlock")
	
	# 4. Total compound collapse: 0 fuel, 0 legs, 0 scrap, 0 caches:
	assert_true(sim.check_deadlock_condition(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, false),
		"Total system collapse is absolute fatal deadlock")

## Combinatorial exhaustive truth-table evaluation.
func test_track_3c_deadlock_combinatorial(sim) -> void:
	var fuels = [0.0, 0.0001, 50.0]
	var legs = [0.0, 0.0001, 50.0]
	var scraps = [0.0, 0.5, 2.0]
	var reach_fuels = [0.0, 0.0001, 30.0]
	var reach_scraps = [0.0, 0.5, 2.0]
	var player_outsides = [false, true]
	
	var tested_combinations: int = 0
	
	for f in fuels:
		for l in legs:
			for s in scraps:
				for rf in reach_fuels:
					for rs in reach_scraps:
						for po in player_outsides:
							tested_combinations += 1
							var result = sim.check_deadlock_condition(f, l, s, 1.0, rf, rs, po)
							
							# Theoretical Oracle:
							var expected_oracle: bool = false
							if not po:
								var f_stalled: bool = (f <= 0.0) and (rf <= 0.0)
								var l_stalled: bool = (l <= 0.0) and ((s + rs) < 1.0)
								expected_oracle = f_stalled or l_stalled
							
							if result != expected_oracle:
								assert_true(false, "Combinatorial mismatch at f=%.4f l=%.4f s=%.1f rf=%.4f rs=%.1f po=%s: got %s expected %s" % [f, l, s, rf, rs, po, result, expected_oracle])
	
	assert_true(tested_combinations == (3 * 3 * 3 * 3 * 3 * 2), "Exhaustively verified all 486 parameter combinations")

## Tests the 3.0s temporal grace period hysteresis and transient reset.
func test_track_3d_deadlock_hysteresis(sim) -> void:
	var grace = 3.0
	
	# Step 1: Initial stall tick at 0.0s -> timer=1.0s, not confirmed
	var h1 = sim.update_deadlock_timer(0.0, true, 1.0, grace)
	assert_almost_eq(h1.timer, 1.0, 0.001, "Timer reaches 1.0s")
	assert_false(h1.is_confirmed, "1.0s is not confirmed")
	
	# Step 2: Next tick -> timer=2.99s, not confirmed
	var h2 = sim.update_deadlock_timer(h1.timer, true, 1.99, grace)
	assert_almost_eq(h2.timer, 2.99, 0.001, "Timer reaches 2.99s")
	assert_false(h2.is_confirmed, "2.99s is not yet confirmed (strictly < 3.0s)")
	
	# Step 3: Transient clearance! Player steps outside for 1 frame:
	var h_reset = sim.update_deadlock_timer(h2.timer, false, 0.016, grace)
	assert_almost_eq(h_reset.timer, 0.0, 0.0001, "Transient false condition resets timer completely to 0.0s")
	assert_false(h_reset.is_confirmed, "Condition cleared, not confirmed")
	
	# Step 4: Resume stall from 0:
	var h3 = sim.update_deadlock_timer(0.0, true, 2.5, grace)
	assert_almost_eq(h3.timer, 2.5, 0.001, "Timer at 2.5s")
	assert_false(h3.is_confirmed, "2.5s not confirmed")
	
	# Step 5: Exceed 3.0s grace period -> CONFIRMED!
	var h4 = sim.update_deadlock_timer(h3.timer, true, 0.5, grace)
	assert_almost_eq(h4.timer, 3.0, 0.001, "Timer reaches 3.0s")
	assert_true(h4.is_confirmed, "3.0s continuous stall triggers CONFIRMED deadlock defeat!")

# ==============================================================================
# SUMMARY REPORTING
# ==============================================================================
func print_summary() -> void:
	print("\n" + "=".repeat(76))
	print("  ADVERSARIAL SUITE SUMMARY")
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
		print("  VERDICT: EMPIRICALLY CONFIRMED & ROBUST (Zero failures)")
	print("=".repeat(76) + "\n")
