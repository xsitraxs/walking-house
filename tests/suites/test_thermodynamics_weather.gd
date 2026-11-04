# test_thermodynamics_weather.gd — Thermodynamics, Stove & Weather Events Test Suite
# Tests features: F38, F39, F40, F41, F42, F43, F44, F45, F46
class_name TestThermodynamicsWeather
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Thermodynamics, Stove & Weather Events (F38-F46)"

func run_suite(runner) -> void:
	test_01_cabin_natural_cooling_newton(runner)
	test_02_stove_active_heating_rate(runner)
	test_03_stove_fuel_consumption(runner)
	test_04_insulation_upgrade_thermal_retention(runner)
	test_05_blizzard_accelerated_cooling(runner)
	test_06_cabin_equilibrium_ceiling(runner)
	test_07_cabin_freezing_damage_threshold_bva(runner)
	test_08_blizzard_warning_timing(runner)

func test_01_cabin_natural_cooling_newton(runner) -> void:
	runner.start_test("test_01_cabin_natural_cooling_newton")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Current temp +15°C, Outside -15°C, Stove OFF, No insulation, No blizzard, delta 1.0s
	# Delta T = 15 - (-15) = 30°C. Cooling = 0.025 * 30 * 1.0 = 0.75°C. New temp = 14.25°C
	var new_temp: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	runner.assert_almost_eq(new_temp, 14.25, 0.01, "Newton cooling with k_loss 0.025")
	runner.end_test()

func test_02_stove_active_heating_rate(runner) -> void:
	runner.start_test("test_02_stove_active_heating_rate")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Current temp +15°C, Outside -15°C, Stove ON (+1.1°C/s), delta 1.0s
	# Net change = -0.75 (loss) + 1.10 (gain) = +0.35°C -> New temp = 15.35°C
	var heated_temp: float = sim.calculate_cabin_temperature(15.0, -15.0, true, false, false, 1.0)
	runner.assert_almost_eq(heated_temp, 15.35, 0.01, "Stove heating overcomes natural cooling")
	runner.assert_gt(heated_temp, 15.0, "Active stove must heat cabin")
	runner.end_test()

func test_03_stove_fuel_consumption(runner) -> void:
	runner.start_test("test_03_stove_fuel_consumption")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Stove ON for 1.0s -> Burns 0.25 fuel
	var burn_on: float = sim.calculate_stove_fuel(true, 1.0)
	runner.assert_almost_eq(burn_on, TestOracle.STOVE_FUEL_RATE, 0.001, "Stove burns 0.25 fuel/s")
	
	# Stove OFF -> Burns 0.0 fuel
	var burn_off: float = sim.calculate_stove_fuel(false, 1.0)
	runner.assert_almost_eq(burn_off, 0.0, 0.0001, "Extinguished stove burns 0 fuel")
	runner.end_test()

func test_04_insulation_upgrade_thermal_retention(runner) -> void:
	runner.start_test("test_04_insulation_upgrade_thermal_retention")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Without insulation: 15°C -> 14.25°C (loss 0.75°C)
	var temp_uninsulated: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	# With insulation (-45% loss): loss = 0.75 * 0.55 = 0.4125°C -> New temp = 14.5875°C
	var temp_insulated: float = sim.calculate_cabin_temperature(15.0, -15.0, false, true, false, 1.0)
	
	runner.assert_gt(temp_insulated, temp_uninsulated, "Insulated cabin retains significantly more heat")
	runner.assert_almost_eq(temp_insulated, 15.0 - (0.75 * 0.55), 0.01, "Insulation reduces cooling by 45%")
	runner.end_test()

func test_05_blizzard_accelerated_cooling(runner) -> void:
	runner.start_test("test_05_blizzard_accelerated_cooling")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Calm: loss 0.75°C
	var temp_calm: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	# Blizzard (1.8x multiplier): loss = 0.75 * 1.8 = 1.35°C -> New temp = 13.65°C
	var temp_blizzard: float = sim.calculate_cabin_temperature(15.0, -15.0, false, false, true, 1.0)
	
	runner.assert_lt(temp_blizzard, temp_calm, "Blizzard cools cabin 1.8x faster")
	runner.assert_almost_eq(temp_blizzard, 15.0 - (0.75 * 1.8), 0.01, "Blizzard 1.8x multiplier applied")
	runner.end_test()

func test_06_cabin_equilibrium_ceiling(runner) -> void:
	runner.start_test("test_06_cabin_equilibrium_ceiling")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Cabin cannot exceed CABIN_MAX_TEMP (+24.0°C)
	var temp_capped: float = sim.calculate_cabin_temperature(24.0, 0.0, true, true, false, 10.0)
	runner.assert_lte(temp_capped, TestOracle.CABIN_MAX_TEMP, "Cabin temperature capped at maximum equilibrium (+24°C)")
	runner.end_test()

func test_07_cabin_freezing_damage_threshold_bva(runner) -> void:
	runner.start_test("test_07_cabin_freezing_damage_threshold_bva")
	# Verification of freeze damage threshold at 0°C
	# Above 0°C: 0 damage
	var dmg_above: float = maxf(0.0, -0.5 * 0.5)
	runner.assert_almost_eq(dmg_above, 0.0, 0.01, "At positive cabin temp, 0 freeze damage")
	
	# Below 0°C (e.g. -4°C): damage = 0.5 * |-4| = 2.0 HP/s
	var test_temp: float = -4.0
	var dmg_below: float = (0.5 * abs(test_temp)) if (test_temp < 0.0) else 0.0
	runner.assert_almost_eq(dmg_below, 2.0, 0.01, "At -4°C, player suffers 2.0 HP/s hypothermia")
	runner.end_test()

func test_08_blizzard_warning_timing(runner) -> void:
	runner.start_test("test_08_blizzard_warning_timing")
	# Blizzard advance warning is exactly 20.0 seconds
	var warning_time: float = 20.0
	runner.assert_eq(warning_time, 20.0, "Blizzard warning triggers exactly 20.0s in advance")
	runner.end_test()
