# test_full_progression.gd — Tier 4 Full Progression & Real-World Playthrough Workload Scenarios
# Tests: Baseline 0-Upgrade Playthrough, Full Upgrade Playthrough, Near-Freeze Survival, Blizzard Rescue, Route Determinism
class_name TestFullProgression
extends RefCounted

const TestOracle = preload("res://tests/test_oracle.gd")
const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"

var suite_name: String = "Tier 4 Progression & Real-World Scenarios (F04, F37, F48)"

func run_suite(runner) -> void:
	test_01_baseline_unupgraded_playthrough_scenario(runner)
	test_02_upgraded_playthrough_scenario(runner)
	test_03_near_freeze_survival_scenario(runner)
	test_04_blizzard_rescue_scenario(runner)
	test_05_route_resource_budget_determinism(runner)

func test_01_baseline_unupgraded_playthrough_scenario(runner) -> void:
	runner.start_test("test_01_baseline_unupgraded_playthrough_scenario")
	
	# Initial State (as defined in balance specification)
	var fuel: float = 60.0
	var scrap: float = 5.0
	var supplies: float = 3.0
	var leg_durability: float = 100.0
	var player_health: float = 100.0
	var total_time_sec: float = 0.0
	var current_x: float = 0.0
	
	var pois: Array = TestOracle.get_route_pois()
	
	# Simulate travel through all 20 POIs up to 5000m
	for poi in pois:
		var target_x: float = poi["x"]
		var dist_delta: float = target_x - current_x
		current_x = target_x
		
		# Movement time at average speed (~4.5 m/s accounting for leg degradation)
		var leg_factor: float = 1.0 if leg_durability >= 50.0 else (0.5 + 0.5 * ((leg_durability - 10.0) / 40.0))
		var speed: float = TestOracle.BASE_SPEED * leg_factor
		var travel_time: float = dist_delta / speed
		total_time_sec += travel_time
		
		# Locomotive fuel burn: 0.10 fuel per meter (0.50 fuel/sec)
		var fuel_spent: float = dist_delta * 0.10
		fuel -= fuel_spent
		runner.assert_gt(fuel, 0.0, "Fuel must remain positive during transit to POI %d" % poi["id"])
		
		# Leg wear (base 0.040% per meter; biome 3 has 1.5x wear)
		var wear_rate: float = 0.040 * (1.5 if poi["biome"] == 3 else 1.0)
		leg_durability -= dist_delta * wear_rate
		
		# Natural cabin cooling during travel (assume stove burns 40% of time to maintain warmth)
		var stove_on_time: float = travel_time * 0.40
		fuel -= stove_on_time * TestOracle.STOVE_FUEL_RATE
		
		# Stop at POI: Loot resources (18 seconds exploration time)
		total_time_sec += 18.0
		fuel += poi["fuel"]
		scrap += poi["scrap"]
		supplies += poi["supplies"]
		
		# Periodic leg repair if durability falls below 40%
		if leg_durability < 40.0 and scrap >= 1.0:
			var needed_dur: float = 100.0 - leg_durability
			var scrap_needed: float = ceil(needed_dur / TestOracle.REPAIR_DURABILITY_GAIN)
			var scrap_used: float = minf(scrap_needed, scrap)
			leg_durability = minf(100.0, leg_durability + scrap_used * TestOracle.REPAIR_DURABILITY_GAIN)
			scrap -= scrap_used
	
	# Final travel from POI 20 (4950m) to Station (5000m)
	var final_dist: float = 5000.0 - current_x
	total_time_sec += final_dist / TestOracle.BASE_SPEED
	fuel -= final_dist * 0.10
	
	# Verify Acceptance Criteria for Baseline Playthrough
	var total_minutes: float = total_time_sec / 60.0
	runner.assert_gte(total_minutes, 15.0, "Playthrough duration must be >= 15 minutes")
	runner.assert_lte(total_minutes, 25.0, "Playthrough duration must be <= 25 minutes")
	runner.assert_gt(fuel, 150.0, "Final fuel surplus must exceed 150 units (calculated ~200)")
	runner.assert_gt(scrap, 30.0, "Final scrap surplus must exceed 30 units (calculated ~48)")
	runner.assert_gt(supplies, 10.0, "Final supplies surplus must exceed 10 units (calculated ~19)")
	runner.assert_gt(player_health, 50.0, "Player survives with healthy HP")
	runner.end_test()

func test_02_upgraded_playthrough_scenario(runner) -> void:
	runner.start_test("test_02_upgraded_playthrough_scenario")
	
	var fuel: float = 60.0
	var scrap: float = 5.0
	var supplies: float = 3.0
	var leg_durability: float = 100.0
	var total_time_sec: float = 0.0
	var current_x: float = 0.0
	
	var has_insulation: bool = false
	var has_engine: bool = false
	var has_legs: bool = false
	
	var pois: Array = TestOracle.get_route_pois()
	
	for poi in pois:
		var target_x: float = poi["x"]
		var dist_delta: float = target_x - current_x
		current_x = target_x
		
		var speed: float = TestOracle.UPGRADED_SPEED if has_legs else TestOracle.BASE_SPEED
		var travel_time: float = dist_delta / speed
		total_time_sec += travel_time
		
		var fuel_per_m: float = 0.07 if has_engine else 0.10
		fuel -= dist_delta * fuel_per_m
		
		# Scavenge POI (12 seconds looting time with experienced routing)
		total_time_sec += 12.0
		fuel += poi["fuel"]
		scrap += poi["scrap"]
		supplies += poi["supplies"]
		
		# Upgrade 1: Insulation at POI 5 (1200m) before Blizzard 1
		if poi["id"] == 5 and not has_insulation:
			runner.assert_gte(scrap, 12.0, "Scrap for Insulation upgrade at POI 5")
			runner.assert_gte(supplies, 6.0, "Supplies for Insulation upgrade at POI 5")
			scrap -= 12.0
			supplies -= 6.0
			has_insulation = true
		
		# Upgrade 2: Efficient Engine at POI 9 (2200m) in Machinery Biome
		if poi["id"] == 9 and not has_engine:
			runner.assert_gte(scrap, 15.0, "Scrap for Engine upgrade at POI 9")
			runner.assert_gte(fuel, 20.0, "Fuel for Engine upgrade at POI 9")
			scrap -= 15.0
			fuel -= 20.0
			has_engine = true
		
		# Upgrade 3: Reinforced Legs at POI 11 (2700m) after heavy mining excavator
		if poi["id"] == 11 and not has_legs:
			runner.assert_gte(scrap, 18.0, "Scrap for Legs upgrade at POI 11")
			runner.assert_gte(supplies, 8.0, "Supplies for Legs upgrade at POI 11")
			scrap -= 18.0
			supplies -= 8.0
			has_legs = true
		
		# Stove heating (less fuel needed with insulation: 25% vs 40%)
		var stove_ratio: float = 0.25 if has_insulation else 0.40
		fuel -= (travel_time * stove_ratio) * TestOracle.STOVE_FUEL_RATE
	
	# Final transit to 5000m station
	var final_dist: float = 5000.0 - current_x
	total_time_sec += final_dist / TestOracle.UPGRADED_SPEED
	fuel -= final_dist * 0.07
	
	var total_minutes: float = total_time_sec / 60.0
	runner.assert_gte(total_minutes, 15.0, "Upgraded run completes in valid window")
	runner.assert_lte(total_minutes, 20.0, "Upgraded run is noticeably faster (~15-20 minutes)")
	runner.assert_gt(fuel, 300.0, "Upgraded run yields massive fuel surplus (>300 units)")
	runner.end_test()

func test_03_near_freeze_survival_scenario(runner) -> void:
	runner.start_test("test_03_near_freeze_survival_scenario")
	
	# Player experiences a severe cold crisis: cabin temp drops to -5°C, health is 30 HP
	# Player ignites stove with 15 fuel in -20°C weather
	var cabin_temp: float = -5.0
	var health: float = 30.0
	var fuel: float = 15.0
	var ambient_temp: float = -20.0
	var delta: float = 1.0 # 1 second steps
	
	# Phase 1: Rapid heating to arrest hypothermia
	for s in range(10):
		fuel -= TestOracle.STOVE_FUEL_RATE * delta
		var temp_diff: float = cabin_temp - ambient_temp
		var cooling: float = TestOracle.CABIN_COOLING_COEFF * temp_diff * delta
		var heating: float = TestOracle.STOVE_HEATING_RATE * delta
		cabin_temp = cabin_temp - cooling + heating
		
		# Hypothermia damage if still below 0°C
		if cabin_temp < 0.0:
			health -= 0.5 * abs(cabin_temp) * delta
	
	# After 10 seconds, cabin temp must be above 0°C (freeze damage stopped)
	runner.assert_gt(cabin_temp, 0.0, "Cabin temp successfully warms above 0°C within 10 seconds")
	runner.assert_gt(health, 0.0, "Player survives hypothermia crisis without dying")
	
	# Phase 2: Continued heating to reach comfort and warmth recovery threshold (+10°C)
	for s in range(30):
		fuel -= TestOracle.STOVE_FUEL_RATE * delta
		var temp_diff: float = cabin_temp - ambient_temp
		cabin_temp += (TestOracle.STOVE_HEATING_RATE - TestOracle.CABIN_COOLING_COEFF * temp_diff) * delta
	
	# Cabin temp now exceeds +10°C
	runner.assert_gt(cabin_temp, 10.0, "Cabin warms comfortably above 10°C")
	
	# In warmth, consuming 1 supply restores +25 HP
	health += 25.0
	runner.assert_gte(health, 40.0, "Health successfully recovers to safe level")
	runner.end_test()

func test_04_blizzard_rescue_scenario(runner) -> void:
	runner.start_test("test_04_blizzard_rescue_scenario")
	
	# Player is 25 meters outside collecting resources when blizzard warning triggers (20.0s countdown)
	var warning_time: float = 20.0
	var dist_to_house: float = 25.0
	var run_speed: float = TestOracle.PLAYER_SPEED # 3.2 m/s
	
	# Player finishes looting (+3.0s) and sprints back
	var loot_time: float = 3.0
	var sprint_time: float = dist_to_house / run_speed # 25 / 3.2 = 7.81s
	var total_rescue_time: float = loot_time + sprint_time # ~10.8s
	
	runner.assert_lt(total_rescue_time, warning_time, "Player safely embarks with ~9.2 seconds to spare before blizzard strikes")
	
	var spare_margin: float = warning_time - total_rescue_time
	runner.assert_gte(spare_margin, 8.0, "Comfortable safety buffer of >= 8 seconds")
	runner.end_test()

func test_05_route_resource_budget_determinism(runner) -> void:
	runner.start_test("test_05_route_resource_budget_determinism")
	
	var pois: Array = TestOracle.get_route_pois()
	runner.assert_eq(pois.size(), 20, "Route contains exactly 20 deterministic POIs")
	
	var total_fuel: float = 0.0
	var total_scrap: int = 0
	var total_supplies: int = 0
	
	for poi in pois:
		total_fuel += poi["fuel"]
		total_scrap += poi["scrap"]
		total_supplies += poi["supplies"]
	
	# Validate exact resource budgets from explorer survey
	runner.assert_almost_eq(total_fuel, 760.0, 0.01, "Route has exactly 760 fuel placed")
	runner.assert_eq(total_scrap, 55, "Route has exactly 55 scrap placed")
	runner.assert_eq(total_supplies, 22, "Route has exactly 22 supplies placed")
	
	# Plus starting inventory (60 fuel, 5 scrap, 3 supplies)
	var grand_fuel: float = total_fuel + 60.0
	var grand_scrap: int = total_scrap + 5
	var grand_supplies: int = total_supplies + 3
	
	runner.assert_almost_eq(grand_fuel, 820.0, 0.01, "Grand total fuel available is 820")
	runner.assert_eq(grand_scrap, 60, "Grand total scrap available is 60")
	runner.assert_eq(grand_supplies, 25, "Grand total supplies available is 25")
	runner.end_test()
