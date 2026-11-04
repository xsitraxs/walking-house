# tests/suites/test_simulation_math.gd
# Mathematical models and pure simulation unit tests for «Шагающий дом»
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

func _init() -> void:
	print("\n" + "=".repeat(70))
	print(" M1 TEST SUITE: SimulationLogic Pure Mathematical Models")
	print("=".repeat(70))
	
	var passed: int = 0
	var failed: int = 0
	
	var tests: Array[Callable] = [
		Callable(self, "test_01_speed_degradation"),
		Callable(self, "test_02_fuel_consumption"),
		Callable(self, "test_03_leg_wear_and_biomes"),
		Callable(self, "test_04_scrap_repairs"),
		Callable(self, "test_05_thermodynamics_cooling_and_stove"),
		Callable(self, "test_06_player_outside_exposure_and_cold_damage"),
		Callable(self, "test_07_cabin_freezing_damage_and_warmth_recovery"),
		Callable(self, "test_08_deadlock_detection_zero_false_positives"),
		Callable(self, "test_09_deadlock_hysteresis_timer"),
		Callable(self, "test_10_upgrade_affordability")
	]
	
	for t in tests:
		var test_name: String = t.get_method()
		print("[RUN] %s" % test_name)
		var ok: bool = t.call()
		if ok:
			passed += 1
			print("  -> PASS")
		else:
			failed += 1
			printerr("  -> FAIL")
			
	print("=".repeat(70))
	print(" RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("=".repeat(70) + "\n")
	
	if failed == 0:
		quit(0)
	else:
		quit(1)

func test_01_speed_degradation() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
	var base_spd: float = 5.0
	
	# 100% durability -> 5.0 m/s
	assert(is_equal_approx(sim.calculate_speed(base_spd, 100.0, 100.0), 5.0))
	# 50% durability -> 5.0 m/s (inflection point)
	assert(is_equal_approx(sim.calculate_speed(base_spd, 50.0, 100.0), 5.0))
	# 49.9% durability -> < 5.0 m/s
	assert(sim.calculate_speed(base_spd, 49.9, 100.0) < 5.0)
	# 30% durability -> 3.75 m/s
	assert(is_equal_approx(sim.calculate_speed(base_spd, 30.0, 100.0), 3.75))
	# 10% durability -> 2.5 m/s (50% speed)
	assert(is_equal_approx(sim.calculate_speed(base_spd, 10.0, 100.0), 2.5))
	# 9.9% durability -> 1.5 m/s (emergency creep)
	assert(is_equal_approx(sim.calculate_speed(base_spd, 9.9, 100.0), 1.5))
	# 1% durability -> 1.5 m/s (emergency creep)
	assert(is_equal_approx(sim.calculate_speed(base_spd, 1.0, 100.0), 1.5))
	# 0% durability (critical stop) -> strictly 0.0
	assert(sim.calculate_speed(base_spd, 0.0, 100.0) == 0.0)
	# Negative durability guard -> strictly 0.0
	assert(sim.calculate_speed(base_spd, -10.0, 100.0) == 0.0)
	return true

func test_02_fuel_consumption() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Stationary -> 0.0
	assert(sim.calculate_fuel_consumption(false, false, 2.0) == 0.0)
	# Moving without upgrade -> 0.50 * 2.0 = 1.0
	assert(is_equal_approx(sim.calculate_fuel_consumption(true, false, 2.0), 1.0))
	# Moving with engine upgrade (-30% fuel burn) -> 0.35 * 2.0 = 0.70
	assert(is_equal_approx(sim.calculate_fuel_consumption(true, true, 2.0), 0.70))
	# Negative or zero delta -> 0.0
	assert(sim.calculate_fuel_consumption(true, false, 0.0) == 0.0)
	assert(sim.calculate_fuel_consumption(true, false, -1.0) == 0.0)
	return true

func test_03_leg_wear_and_biomes() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Stationary -> 0.0
	assert(sim.calculate_leg_wear(false, false, 5.0) == 0.0)
	# Normal biome without upgrade -> 0.20 * 5.0 = 1.0%
	assert(is_equal_approx(sim.calculate_leg_wear(true, false, 5.0), 1.0))
	# Normal biome with reinforced legs upgrade (-40% wear) -> 0.12 * 5.0 = 0.60%
	assert(is_equal_approx(sim.calculate_leg_wear(true, true, 5.0), 0.60))
	# Tough biome (1.5x) without upgrade -> 0.20 * 1.5 * 5.0 = 1.50%
	assert(is_equal_approx(sim.calculate_leg_wear(true, false, 5.0, 0.20, 0.40, 1.5), 1.50))
	# Forest biome (1.25x) with upgrade -> 0.12 * 1.25 * 5.0 = 0.75%
	assert(is_equal_approx(sim.calculate_leg_wear(true, true, 5.0, 0.20, 0.40, 1.25), 0.75))
	return true

func test_04_scrap_repairs() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Standard repair: 50% durability, 1 scrap available -> restores to 70%, 1 scrap spent
	var rep1: Dictionary = sim.apply_repair(50.0, 1.0)
	assert(is_equal_approx(rep1.new_durability, 70.0))
	assert(is_equal_approx(rep1.scrap_spent, 1.0))

	# Full repair: 0% durability, 5 scrap available -> restores to 100%, 5 scrap spent
	var rep2: Dictionary = sim.apply_repair(0.0, 5.0)
	assert(is_equal_approx(rep2.new_durability, 100.0))
	assert(is_equal_approx(rep2.scrap_spent, 5.0))

	# Surplus protection: 90% durability, 4 scrap -> spends only 1 scrap, reaches 100%
	var rep3: Dictionary = sim.apply_repair(90.0, 4.0)
	assert(is_equal_approx(rep3.new_durability, 100.0))
	assert(is_equal_approx(rep3.scrap_spent, 1.0))

	# Zero scrap available: 20% durability, 0 scrap -> 0 spent, remains 20%
	var rep4: Dictionary = sim.apply_repair(20.0, 0.0)
	assert(is_equal_approx(rep4.new_durability, 20.0))
	assert(is_equal_approx(rep4.scrap_spent, 0.0))

	# Full durability: 100% durability, 10 scrap -> spends 0, remains 100%
	var rep5: Dictionary = sim.apply_repair(100.0, 10.0)
	assert(is_equal_approx(rep5.new_durability, 100.0))
	assert(is_equal_approx(rep5.scrap_spent, 0.0))
	return true

func test_05_thermodynamics_cooling_and_stove() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Newton cooling: 15°C inside, -15°C outside, stove off, delta 1s (k=0.025)
	# Cooling = 0.025 * 30 * 1 = 0.75 -> 14.25°C
	var t1: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	assert(is_equal_approx(t1, 14.25))

	# Stove active: +1.1°C/s heating -> net = -0.75 + 1.10 = +0.35 -> 15.35°C
	var t2: float = sim.calculate_cabin_temperature(15.0, -15.0, true, false, false, 1.0)
	assert(is_equal_approx(t2, 15.35))

	# Insulated cooling (-45% loss): loss = 0.75 * 0.55 = 0.4125 -> 14.5875°C
	var t3: float = sim.calculate_cabin_temperature(15.0, -15.0, false, true, false, 1.0)
	assert(absf(t3 - 14.5875) < 0.001)

	# Blizzard cooling (1.8x): loss = 0.75 * 1.8 = 1.35 -> 13.65°C
	var t4: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, true, 1.0)
	assert(is_equal_approx(t4, 13.65))

	# Equilibrium ceiling (+24.0°C maximum)
	var t5: float = sim.calculate_cabin_temperature(24.0, 0.0, true, true, false, 10.0)
	assert(t5 <= 24.0)

	# Stove fuel consumption: 0.25 fuel/sec
	assert(is_equal_approx(sim.calculate_stove_fuel(true, 4.0), 1.0))
	assert(sim.calculate_stove_fuel(false, 4.0) == 0.0)
	return true

func test_06_player_outside_exposure_and_cold_damage() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Inside safe tether (30m <= 45m) -> 2.5 HP/s
	assert(is_equal_approx(sim.calculate_player_outside_exposure(1.0, 30.0, 45.0), 2.5))
	# At exact boundary (45m) -> 2.5 HP/s
	assert(is_equal_approx(sim.calculate_player_outside_exposure(1.0, 45.0, 45.0), 2.5))
	# Outside safe tether (50m > 45m) -> 2.0x penalty = 5.0 HP/s
	assert(is_equal_approx(sim.calculate_player_outside_exposure(1.0, 50.0, 45.0), 5.0))

	# Outside cold damage after warm clothes buffer (20s):
	# Exposure 15s <= 20s -> 0.0 damage
	assert(sim.calculate_outside_cold_damage(15.0, 20.0, false, 1.0) == 0.0)
	# Exposure 25s > 20s calm -> 2.5 * 1.0 = 2.5 HP
	assert(is_equal_approx(sim.calculate_outside_cold_damage(25.0, 20.0, false, 1.0), 2.5))
	# Exposure 25s in blizzard -> 6.0 * 1.0 = 6.0 HP
	assert(is_equal_approx(sim.calculate_outside_cold_damage(25.0, 20.0, true, 1.0), 6.0))
	return true

func test_07_cabin_freezing_damage_and_warmth_recovery() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Cabin cold damage at -4°C: 0.5 * |-4| * 1.0 = 2.0 HP
	assert(is_equal_approx(sim.calculate_cabin_cold_damage(-4.0, 1.0), 2.0))
	# Cabin temp >= 0°C -> 0.0 damage
	assert(sim.calculate_cabin_cold_damage(0.0, 1.0) == 0.0)
	assert(sim.calculate_cabin_cold_damage(15.0, 1.0) == 0.0)

	# Warmth recovery in warm cabin (temp >= 10°C): 0.5 HP/s
	assert(is_equal_approx(sim.calculate_warmth_recovery(15.0, 2.0), 1.0))
	# Warmth recovery when cold (temp < 10°C) -> 0.0
	assert(sim.calculate_warmth_recovery(8.0, 2.0) == 0.0)
	return true

func test_08_deadlock_detection_zero_false_positives() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# 1. Normal mobile house -> false
	assert(not sim.check_deadlock_condition(50.0, 100.0, 5.0, 1.0, 0.0, 0.0, false))

	# 2. Player outside -> strictly false (zero false positives guarantee)
	assert(not sim.check_deadlock_condition(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, true))

	# 3. Fuel 0, but reachable fuel within 45m -> false
	assert(not sim.check_deadlock_condition(0.0, 80.0, 2.0, 1.0, 35.0, 0.0, false))

	# 4. Legs 0, but scrap available for repair -> false
	assert(not sim.check_deadlock_condition(40.0, 0.0, 2.0, 1.0, 0.0, 0.0, false))

	# 5. Legs 0, scrap 0, but reachable scrap nearby -> false
	assert(not sim.check_deadlock_condition(40.0, 0.0, 0.0, 1.0, 0.0, 4.0, false))

	# 6. Fuel 0, no reachable fuel anywhere, player inside -> TRUE (Fuel deadlock)
	assert(sim.check_deadlock_condition(0.0, 50.0, 2.0, 1.0, 0.0, 0.0, false))

	# 7. Legs 0, scrap 0, no reachable scrap, player inside -> TRUE (Mechanical deadlock)
	assert(sim.check_deadlock_condition(50.0, 0.0, 0.0, 1.0, 0.0, 0.0, false))
	return true

func test_09_deadlock_hysteresis_timer() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# At 2.0s stall, 3.0s grace period not expired
	var h1: Dictionary = sim.update_deadlock_timer(0.0, true, 2.0, 3.0)
	assert(is_equal_approx(h1.timer, 2.0))
	assert(not h1.is_confirmed)

	# At 3.0s stall, grace period expired -> confirmed!
	var h2: Dictionary = sim.update_deadlock_timer(2.0, true, 1.0, 3.0)
	assert(is_equal_approx(h2.timer, 3.0))
	assert(h2.is_confirmed)

	# Condition cleared mid-timer -> resets to 0.0
	var h3: Dictionary = sim.update_deadlock_timer(2.5, false, 0.5, 3.0)
	assert(h3.timer == 0.0)
	assert(not h3.is_confirmed)
	return true

func test_10_upgrade_affordability() -> bool:
	var sim = load(SIM_PATH)
	if sim == null:
		return false
		
	# Insulation (12 scrap, 6 supplies)
	assert(sim.can_afford_upgrade("insulation", 12.0, 6.0))
	assert(not sim.can_afford_upgrade("insulation", 11.0, 6.0))
	assert(not sim.can_afford_upgrade("insulation", 12.0, 5.0))

	# Engine (15 scrap, 20 fuel) — test both canonical and short IDs
	assert(sim.can_afford_upgrade("engine", 15.0, 0.0, 20.0))
	assert(sim.can_afford_upgrade("efficient_engine", 15.0, 0.0, 20.0))
	assert(not sim.can_afford_upgrade("engine", 14.0, 0.0, 20.0))
	assert(not sim.can_afford_upgrade("engine", 15.0, 0.0, 19.0))

	# Legs (18 scrap, 8 supplies) — test both canonical and short IDs
	assert(sim.can_afford_upgrade("legs", 18.0, 8.0))
	assert(sim.can_afford_upgrade("reinforced_legs", 18.0, 8.0))
	assert(not sim.can_afford_upgrade("legs", 17.0, 8.0))
	assert(not sim.can_afford_upgrade("legs", 18.0, 7.0))

	# Unknown upgrade
	assert(not sim.can_afford_upgrade("warp_drive", 100.0, 100.0))
	return true
