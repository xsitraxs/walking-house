# test_economy_repairs.gd — Economy, Leg Repairs & Upgrades Test Suite
# Tests features: F26, F27, F28, F32, F33, F34, F35, F36
class_name TestEconomyRepairs
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Economy, Leg Repairs & Upgrades (F26-F36)"

func run_suite(runner) -> void:
	test_01_single_scrap_repair(runner)
	test_02_multi_scrap_full_restoration(runner)
	test_03_repair_capped_at_100_percent(runner)
	test_04_repair_rejected_when_zero_scrap(runner)
	test_05_repair_rejected_when_already_full(runner)
	test_06_can_afford_insulation_upgrade(runner)
	test_07_can_afford_efficient_engine_upgrade(runner)
	test_08_can_afford_reinforced_legs_upgrade(runner)
	test_09_upgrade_rejection_insufficient_resources(runner)

func test_01_single_scrap_repair(runner) -> void:
	runner.start_test("test_01_single_scrap_repair")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Durability 50.0%, 1 scrap available -> restores to 70.0%, spends 1 scrap
	var res: Dictionary = sim.apply_repair(50.0, 1.0)
	runner.assert_almost_eq(res["new_durability"], 70.0, 0.01, "1 scrap restores +20% durability")
	runner.assert_almost_eq(res["scrap_spent"], 1.0, 0.01, "Exact 1 scrap spent")
	runner.end_test()

func test_02_multi_scrap_full_restoration(runner) -> void:
	runner.start_test("test_02_multi_scrap_full_restoration")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Durability 0.0% (broken), 5 scrap available -> 5 * 20 = 100%, spends 5 scrap
	var res: Dictionary = sim.apply_repair(0.0, 5.0)
	runner.assert_almost_eq(res["new_durability"], 100.0, 0.01, "5 scrap restores from 0% to 100%")
	runner.assert_almost_eq(res["scrap_spent"], 5.0, 0.01, "5 scrap spent")
	runner.end_test()

func test_03_repair_capped_at_100_percent(runner) -> void:
	runner.start_test("test_03_repair_capped_at_100_percent")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Durability 90.0%, 4 scrap available -> only needs 1 scrap (+20% -> 100%), surplus scrap not wasted
	var res: Dictionary = sim.apply_repair(90.0, 4.0)
	runner.assert_almost_eq(res["new_durability"], 100.0, 0.01, "Durability capped at 100%")
	runner.assert_almost_eq(res["scrap_spent"], 1.0, 0.01, "Only 1 scrap needed and spent, 3 preserved")
	runner.end_test()

func test_04_repair_rejected_when_zero_scrap(runner) -> void:
	runner.start_test("test_04_repair_rejected_when_zero_scrap")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Durability 20.0%, 0 scrap available -> repair rejected, 0 spent, durability remains 20%
	var res: Dictionary = sim.apply_repair(20.0, 0.0)
	runner.assert_almost_eq(res["new_durability"], 20.0, 0.01, "Durability unchanged without scrap")
	runner.assert_almost_eq(res["scrap_spent"], 0.0, 0.01, "0 scrap spent")
	runner.end_test()

func test_05_repair_rejected_when_already_full(runner) -> void:
	runner.start_test("test_05_repair_rejected_when_already_full")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Durability 100.0%, 10 scrap available -> 0 spent, durability stays 100%
	var res: Dictionary = sim.apply_repair(100.0, 10.0)
	runner.assert_almost_eq(res["new_durability"], 100.0, 0.01, "Durability remains 100%")
	runner.assert_almost_eq(res["scrap_spent"], 0.0, 0.01, "No scrap spent when already fully repaired")
	runner.end_test()

func test_06_can_afford_insulation_upgrade(runner) -> void:
	runner.start_test("test_06_can_afford_insulation_upgrade")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Insulation requires 12 scrap, 6 supplies
	runner.assert_true(sim.can_afford_upgrade("insulation", 12.0, 6.0), "Can afford with exact resources")
	runner.assert_true(sim.can_afford_upgrade("insulation", 20.0, 10.0), "Can afford with surplus resources")
	runner.assert_false(sim.can_afford_upgrade("insulation", 11.0, 6.0), "Cannot afford with 11 scrap")
	runner.assert_false(sim.can_afford_upgrade("insulation", 12.0, 5.0), "Cannot afford with 5 supplies")
	runner.end_test()

func test_07_can_afford_efficient_engine_upgrade(runner) -> void:
	runner.start_test("test_07_can_afford_efficient_engine_upgrade")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Engine requires 15 scrap and 20 fuel
	runner.assert_true(sim.can_afford_upgrade("engine", 15.0, 0.0, 20.0), "Can afford engine with 15 scrap and 20 fuel")
	runner.assert_false(sim.can_afford_upgrade("engine", 14.0, 0.0, 20.0), "Cannot afford engine with 14 scrap")
	runner.assert_false(sim.can_afford_upgrade("engine", 15.0, 0.0, 19.0), "Cannot afford engine with 19 fuel")
	runner.end_test()

func test_08_can_afford_reinforced_legs_upgrade(runner) -> void:
	runner.start_test("test_08_can_afford_reinforced_legs_upgrade")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Reinforced legs require 18 scrap, 8 supplies
	runner.assert_true(sim.can_afford_upgrade("legs", 18.0, 8.0), "Can afford legs with exact resources")
	runner.assert_false(sim.can_afford_upgrade("legs", 17.0, 8.0), "Cannot afford with 17 scrap")
	runner.assert_false(sim.can_afford_upgrade("legs", 18.0, 7.0), "Cannot afford with 7 supplies")
	runner.end_test()

func test_09_upgrade_rejection_insufficient_resources(runner) -> void:
	runner.start_test("test_09_upgrade_rejection_insufficient_resources")
	if not FileAccess.file_exists(SIM_PATH):
		runner.mark_pending("SimulationLogic.gd pending implementation in M1")
		runner.end_test()
		return
	
	var sim = load(SIM_PATH)
	# Unknown upgrade type must return false
	runner.assert_false(sim.can_afford_upgrade("invalid_upgrade_id", 100.0, 100.0), "Invalid upgrade returns false")
	runner.end_test()
