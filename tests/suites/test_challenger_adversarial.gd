# test_challenger_adversarial.gd — Challenger Adversarial Stress Suite for Milestone 1
# Tests: Zero Fuel Blocking, Durability Clamping, Over-Repair Clamping, Multipliers, Winnability
class_name TestChallengerAdversarial
extends RefCounted

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const BALANCE_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const TestOracle = preload("res://tests/test_oracle.gd")

var suite_name: String = "Adversarial Stress Testing & Edge Cases (Challenger M1)"

func run_suite(runner) -> void:
	test_01_zero_fuel_locomotion_blocking(runner)
	test_02_negative_durability_clamping(runner)
	test_03_over_repair_scrap_clamping(runner)
	test_04_upgrade_multiplier_stacking_and_affordability(runner)
	test_05_route_step_simulation_baseline_winnability(runner)
	test_06_route_step_simulation_upgraded_winnability(runner)
	test_07_extreme_boundary_and_numerical_stress(runner)
	test_08_gamestate_lifecycle_and_reset_invariants(runner)

func test_01_zero_fuel_locomotion_blocking(runner) -> void:
	runner.start_test("test_01_zero_fuel_locomotion_blocking")
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	gs.reset_state()
	
	# 1. House cannot initiate movement when fuel is 0.0
	gs.set_fuel(0.0)
	var can_move = gs.set_house_moving(true)
	runner.assert_false(can_move, "set_house_moving(true) must return false when fuel is 0.0")
	runner.assert_false(gs.is_house_moving, "is_house_moving must be false when fuel is 0.0")
	
	# 2. Moving house halts immediately when fuel is drained to 0.0
	gs.set_fuel(10.0)
	var move_ok = gs.set_house_moving(true)
	gs.set_house_speed(5.0)
	runner.assert_true(move_ok and gs.is_house_moving, "House starts moving with fuel")
	
	# Drain fuel to zero
	var consumed = gs.consume_fuel(15.0)
	runner.assert_almost_eq(consumed, 10.0, 0.001, "consume_fuel capped at available fuel")
	runner.assert_almost_eq(gs.fuel, 0.0, 0.001, "Fuel strictly clamped to 0.0")
	runner.assert_false(gs.is_house_moving, "is_house_moving halts automatically on fuel exhaustion")
	runner.assert_almost_eq(gs.house_speed, 0.0, 0.001, "house_speed drops to 0.0 on fuel exhaustion")
	
	# 3. Stove auto-extinguishes on fuel exhaustion
	gs.set_fuel(5.0)
	var stove_on = gs.set_stove(true)
	runner.assert_true(stove_on and gs.is_stove_on, "Stove turns on with fuel")
	gs.consume_fuel(5.0)
	runner.assert_false(gs.is_stove_on, "Stove auto-extinguishes when fuel hits 0.0")
	
	# 4. Stove cannot be turned on when fuel is 0.0
	var stove_attempt = gs.set_stove(true)
	runner.assert_false(stove_attempt or gs.is_stove_on, "Stove cannot be ignited with 0 fuel")
	var toggle_attempt = gs.toggle_stove()
	runner.assert_false(toggle_attempt or gs.is_stove_on, "toggle_stove rejected with 0 fuel")
	
	# 5. SimulationLogic fuel calculation with idle or negative delta
	var sim = load(SIM_PATH)
	runner.assert_almost_eq(sim.calculate_fuel_consumption(false, false, 1.0), 0.0, 0.0001, "Stationary fuel burn is 0.0")
	runner.assert_almost_eq(sim.calculate_fuel_consumption(true, false, 0.0), 0.0, 0.0001, "Zero delta fuel burn is 0.0")
	runner.assert_almost_eq(sim.calculate_fuel_consumption(true, false, -5.0), 0.0, 0.0001, "Negative delta fuel burn is 0.0")
	
	gs.free()
	runner.end_test()

func test_02_negative_durability_clamping(runner) -> void:
	runner.start_test("test_02_negative_durability_clamping")
	var sim = load(SIM_PATH)
	
	# 1. calculate_speed with negative and zero durability
	runner.assert_almost_eq(sim.calculate_speed(5.0, 0.0, 100.0), 0.0, 0.0001, "Zero durability -> 0.0 speed")
	runner.assert_almost_eq(sim.calculate_speed(5.0, -0.001, 100.0), 0.0, 0.0001, "Slightly negative durability -> 0.0 speed")
	runner.assert_almost_eq(sim.calculate_speed(5.0, -100.0, 100.0), 0.0, 0.0001, "Massively negative durability -> 0.0 speed")
	runner.assert_almost_eq(sim.calculate_speed(5.0, 50.0, -100.0), 0.0, 0.0001, "Negative max_durability -> 0.0 speed")
	runner.assert_almost_eq(sim.calculate_speed(-5.0, 50.0, 100.0), 0.0, 0.0001, "Negative base_speed -> 0.0 speed")
	
	# 2. apply_repair with negative durability input
	var rep_neg = sim.apply_repair(-50.0, 2.0, 100.0, 20.0)
	runner.assert_almost_eq(rep_neg["new_durability"], 40.0, 0.01, "Repairing negative durability restores from 0.0 clamp")
	runner.assert_almost_eq(rep_neg["scrap_spent"], 2.0, 0.01, "2 scrap spent on negative durability repair")
	
	var rep_zero_scrap = sim.apply_repair(-50.0, 0.0, 100.0, 20.0)
	runner.assert_almost_eq(rep_zero_scrap["new_durability"], 0.0, 0.01, "Zero scrap repair on negative durability clamps to 0.0")
	runner.assert_almost_eq(rep_zero_scrap["scrap_spent"], 0.0, 0.01, "Zero scrap spent")
	
	# 3. GameState durability bounds
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	gs.reset_state()
	
	gs.set_leg_durability(-25.0)
	runner.assert_almost_eq(gs.leg_durability, 0.0, 0.0001, "set_leg_durability clamps negative value to 0.0")
	runner.assert_false(gs.set_house_moving(true), "Cannot move house when legs collapsed")
	
	# wear_legs overflow and negative wear
	gs.set_leg_durability(30.0)
	var worn = gs.wear_legs(50.0)
	runner.assert_almost_eq(worn, 30.0, 0.001, "wear_legs capped at current durability")
	runner.assert_almost_eq(gs.leg_durability, 0.0, 0.0001, "leg_durability clamped to 0.0 after massive wear")
	
	var neg_wear = gs.wear_legs(-10.0)
	runner.assert_almost_eq(neg_wear, 0.0, 0.0001, "Negative wear rejected (returns 0.0)")
	runner.assert_almost_eq(gs.leg_durability, 0.0, 0.0001, "Durability unaffected by negative wear")
	
	gs.free()
	runner.end_test()

func test_03_over_repair_scrap_clamping(runner) -> void:
	runner.start_test("test_03_over_repair_scrap_clamping")
	var sim = load(SIM_PATH)
	
	# 1. Durability 99.0%, available scrap 10.0 -> Needs 1% durability (<=20%), spends only 1 scrap
	var r1 = sim.apply_repair(99.0, 10.0, 100.0, 20.0)
	runner.assert_almost_eq(r1["new_durability"], 100.0, 0.01, "Over-repair: Durability capped at 100.0")
	runner.assert_almost_eq(r1["scrap_spent"], 1.0, 0.01, "Over-repair: Only 1 scrap consumed, 9 scrap preserved")
	
	# 2. Durability 100.0%, available scrap 10.0 -> Needs 0, spends 0
	var r2 = sim.apply_repair(100.0, 10.0, 100.0, 20.0)
	runner.assert_almost_eq(r2["new_durability"], 100.0, 0.01, "Full durability: Stays 100.0")
	runner.assert_almost_eq(r2["scrap_spent"], 0.0, 0.01, "Full durability: 0 scrap spent")
	
	# 3. Durability 120.0% (over-cap), available scrap 5.0 -> Needs 0, spends 0
	var r3 = sim.apply_repair(120.0, 5.0, 100.0, 20.0)
	runner.assert_almost_eq(r3["new_durability"], 100.0, 0.01, "Over-cap durability: Clamped to 100.0")
	runner.assert_almost_eq(r3["scrap_spent"], 0.0, 0.01, "Over-cap durability: 0 scrap spent")
	
	# 4. Durability 1.0%, available scrap 100.0 -> Needs 99%, requires 5 scrap (5*20 = 100%)
	var r4 = sim.apply_repair(1.0, 100.0, 100.0, 20.0)
	runner.assert_almost_eq(r4["new_durability"], 100.0, 0.01, "Severe damage repair: Capped at 100.0")
	runner.assert_almost_eq(r4["scrap_spent"], 5.0, 0.01, "Severe damage repair: Spends 5 scrap, 95 preserved")
	
	# 5. GameState repair_legs when already at max durability
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	gs.reset_state()
	gs.set_scrap(10.0)
	
	var full_rep = gs.repair_legs(20.0, 1.0)
	runner.assert_false(full_rep, "repair_legs returns false when durability is already 100.0")
	runner.assert_almost_eq(gs.scrap, 10.0, 0.001, "repair_legs does not deduct scrap when full")
	
	# GameState repair with slight damage (95.0%)
	gs.set_leg_durability(95.0)
	var slight_rep = gs.repair_legs(20.0, 1.0)
	runner.assert_true(slight_rep, "repair_legs succeeds when damaged")
	runner.assert_almost_eq(gs.leg_durability, 100.0, 0.001, "repair_legs clamps durability to max (100.0)")
	runner.assert_almost_eq(gs.scrap, 9.0, 0.001, "repair_legs deducts exactly 1.0 scrap")
	
	gs.free()
	runner.end_test()

func test_04_upgrade_multiplier_stacking_and_affordability(runner) -> void:
	runner.start_test("test_04_upgrade_multiplier_stacking_and_affordability")
	var sim = load(SIM_PATH)
	
	# 1. Engine upgrade discount (-30%)
	var base_fuel_10s = sim.calculate_fuel_consumption(true, false, 10.0)
	var upg_fuel_10s = sim.calculate_fuel_consumption(true, true, 10.0)
	runner.assert_almost_eq(base_fuel_10s, 5.0, 0.01, "Base fuel for 10s is 5.0")
	runner.assert_almost_eq(upg_fuel_10s, 3.5, 0.01, "Upgraded fuel for 10s is 3.5 (-30%)")
	
	# 2. Reinforced legs wear discount (-40%) across biomes
	var wear_plain_base = sim.calculate_leg_wear(true, false, 10.0, 0.20, 0.40, 1.0)
	var wear_plain_upg = sim.calculate_leg_wear(true, true, 10.0, 0.20, 0.40, 1.0)
	runner.assert_almost_eq(wear_plain_base, 2.0, 0.01, "Base wear 10s plain is 2.0%")
	runner.assert_almost_eq(wear_plain_upg, 1.2, 0.01, "Upgraded wear 10s plain is 1.2% (-40%)")
	
	var wear_graveyard_base = sim.calculate_leg_wear(true, false, 10.0, 0.20, 0.40, 1.5)
	var wear_graveyard_upg = sim.calculate_leg_wear(true, true, 10.0, 0.20, 0.40, 1.5)
	runner.assert_almost_eq(wear_graveyard_base, 3.0, 0.01, "Base wear 10s graveyard (1.5x) is 3.0%")
	runner.assert_almost_eq(wear_graveyard_upg, 1.8, 0.01, "Upgraded wear 10s graveyard (1.5x) is 1.8%")
	
	# 3. Insulation thermal retention (-45%) in calm and blizzard
	var t_calm_base = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	runner.assert_almost_eq(t_calm_base, 14.25, 0.01, "Calm uninsulated temp drops 0.75°C")
	
	var t_calm_ins = sim.calculate_cabin_temperature(15.0, -15.0, false, true, false, 1.0)
	runner.assert_almost_eq(t_calm_ins, 15.0 - 0.4125, 0.01, "Calm insulated temp drops 0.4125°C")
	
	var t_blizz_base = sim.calculate_cabin_temperature(15.0, -15.0, false, false, true, 1.0)
	runner.assert_almost_eq(t_blizz_base, 15.0 - 1.35, 0.01, "Blizzard uninsulated temp drops 1.35°C")
	
	var t_blizz_ins = sim.calculate_cabin_temperature(15.0, -15.0, false, true, true, 1.0)
	runner.assert_almost_eq(t_blizz_ins, 15.0 - 0.7425, 0.01, "Blizzard insulated temp drops 0.7425°C")
	runner.assert_gt(t_blizz_ins, t_blizz_base, "Insulation significantly protects during blizzard")
	
	# 4. Affordability check boundary tests
	runner.assert_true(sim.can_afford_upgrade("insulation", 12.0, 6.0), "Insulation exact cost passes")
	runner.assert_false(sim.can_afford_upgrade("insulation", 11.99, 6.0), "Insulation 11.99 scrap fails")
	runner.assert_false(sim.can_afford_upgrade("insulation", 12.0, 5.99), "Insulation 5.99 supplies fails")
	
	runner.assert_true(sim.can_afford_upgrade("legs", 18.0, 8.0), "Legs exact cost passes")
	runner.assert_false(sim.can_afford_upgrade("legs", 17.99, 8.0), "Legs 17.99 scrap fails")
	runner.assert_false(sim.can_afford_upgrade("legs", 18.0, 7.99), "Legs 7.99 supplies fails")
	
	# Unknown upgrade rejection
	runner.assert_false(sim.can_afford_upgrade("warp_drive", 100.0, 100.0), "Unknown upgrade rejected")
	runner.assert_false(sim.can_afford_upgrade("", 100.0, 100.0), "Empty upgrade string rejected")
	runner.end_test()

func test_05_route_step_simulation_baseline_winnability(runner) -> void:
	runner.start_test("test_05_route_step_simulation_baseline_winnability")
	var cfg = load(BALANCE_PATH)
	var sim = load(SIM_PATH)
	
	var fuel: float = 60.0
	var scrap: float = 5.0
	var supplies: float = 3.0
	var leg_durability: float = 100.0
	var cabin_temp: float = 18.0
	var player_health: float = 100.0
	var house_dist: float = 0.0
	
	var pois = cfg.POI_SITES
	var poi_idx: int = 0
	var delta: float = 0.5
	var total_time_sec: float = 0.0
	var blizzards = cfg.BLIZZARD_EVENTS
	
	var min_fuel_seen: float = 9999.0
	var min_durability_seen: float = 9999.0
	var min_health_seen: float = 9999.0
	
	while house_dist < 5000.0 and total_time_sec < 2400.0:
		var is_blizzard: bool = false
		for blizz in blizzards:
			if house_dist >= blizz["trigger_distance_m"] and house_dist < (blizz["trigger_distance_m"] + 150.0):
				is_blizzard = true
				break
				
		var biome = cfg.get_biome_at_distance(house_dist)
		var outside_temp: float = biome["day_temp"]
		if is_blizzard:
			outside_temp -= 15.0
			
		if poi_idx < pois.size() and house_dist >= pois[poi_idx]["distance_m"]:
			var current_poi = pois[poi_idx]
			total_time_sec += 18.0
			fuel += current_poi["fuel"]
			scrap += current_poi["scrap"]
			supplies += current_poi["supplies"]
			poi_idx += 1
			
			if leg_durability < 50.0 and scrap >= 1.0:
				var rep = sim.apply_repair(leg_durability, scrap)
				leg_durability = rep["new_durability"]
				scrap -= rep["scrap_spent"]
		
		var speed = sim.calculate_speed(5.0, leg_durability, 100.0)
		var step_dist = speed * delta
		house_dist = minf(5000.0, house_dist + step_dist)
		total_time_sec += delta
		
		var fuel_burn = sim.calculate_fuel_consumption(true, false, delta)
		fuel -= fuel_burn
		
		var wear = sim.calculate_leg_wear(true, false, delta, 0.20, 0.40, biome["wear_mult"])
		leg_durability = maxf(0.0, leg_durability - wear)
		
		var stove_on: bool = cabin_temp < 12.0 and fuel > 0.0
		if stove_on:
			fuel -= sim.calculate_stove_fuel(true, delta)
		cabin_temp = sim.calculate_cabin_temperature(cabin_temp, outside_temp, stove_on, false, is_blizzard, delta)
		
		if cabin_temp < 0.0:
			player_health -= sim.calculate_cabin_cold_damage(cabin_temp, delta)
			
		min_fuel_seen = minf(min_fuel_seen, fuel)
		min_durability_seen = minf(min_durability_seen, leg_durability)
		min_health_seen = minf(min_health_seen, player_health)
		
		if fuel <= 0.0 or leg_durability <= 0.0 or player_health <= 0.0:
			break
			
	runner.assert_gte(house_dist, 5000.0, "Baseline unupgraded house reached 5000m destination")
	runner.assert_gt(min_fuel_seen, 10.0, "Fuel never dropped below safety margin")
	runner.assert_gt(min_durability_seen, 20.0, "Leg durability never collapsed")
	runner.assert_gt(min_health_seen, 75.0, "Player health remained strong despite blizzard")
	
	var total_min: float = total_time_sec / 60.0
	runner.assert_gte(total_min, 15.0, "Playthrough duration >= 15 min")
	runner.assert_lte(total_min, 25.0, "Playthrough duration <= 25 min")
	runner.end_test()

func test_06_route_step_simulation_upgraded_winnability(runner) -> void:
	runner.start_test("test_06_route_step_simulation_upgraded_winnability")
	var cfg = load(BALANCE_PATH)
	var sim = load(SIM_PATH)
	
	var fuel: float = 60.0
	var scrap: float = 5.0
	var supplies: float = 3.0
	var leg_durability: float = 100.0
	var cabin_temp: float = 18.0
	var player_health: float = 100.0
	var house_dist: float = 0.0
	
	var has_insulation: bool = false
	var has_engine: bool = false
	var has_legs: bool = false
	
	var pois = cfg.POI_SITES
	var poi_idx: int = 0
	var delta: float = 0.5
	var total_time_sec: float = 0.0
	var blizzards = cfg.BLIZZARD_EVENTS
	
	while house_dist < 5000.0 and total_time_sec < 2000.0:
		var is_blizzard: bool = false
		for blizz in blizzards:
			if house_dist >= blizz["trigger_distance_m"] and house_dist < (blizz["trigger_distance_m"] + 150.0):
				is_blizzard = true
				break
				
		var biome = cfg.get_biome_at_distance(house_dist)
		var outside_temp: float = biome["day_temp"]
		if is_blizzard:
			outside_temp -= 15.0
			
		if poi_idx < pois.size() and house_dist >= pois[poi_idx]["distance_m"]:
			var current_poi = pois[poi_idx]
			total_time_sec += 12.0
			fuel += current_poi["fuel"]
			scrap += current_poi["scrap"]
			supplies += current_poi["supplies"]
			var p_id = current_poi["id"]
			poi_idx += 1
			
			# Purchase Insulation at POI 5 (1200m)
			if p_id == 5 and not has_insulation:
				scrap -= 12.0
				supplies -= 6.0
				has_insulation = true
				
			# Purchase Efficient Engine at POI 9 (2200m)
			if p_id == 9 and not has_engine:
				scrap -= 15.0
				fuel -= 20.0
				has_engine = true
				
			# Purchase Reinforced Legs at POI 12 (2950m) after maintaining legs in graveyard
			if p_id == 12 and not has_legs:
				scrap -= 18.0
				supplies -= 8.0
				has_legs = true
				
			# Leg maintenance
			if leg_durability < 40.0 and scrap >= 1.0:
				var rep = sim.apply_repair(leg_durability, scrap)
				leg_durability = rep["new_durability"]
				scrap -= rep["scrap_spent"]
		
		var base_spd = 5.75 if has_legs else 5.0
		var speed = sim.calculate_speed(base_spd, leg_durability, 100.0)
		var step_dist = speed * delta
		house_dist = minf(5000.0, house_dist + step_dist)
		total_time_sec += delta
		
		fuel -= sim.calculate_fuel_consumption(true, has_engine, delta)
		
		var wear = sim.calculate_leg_wear(true, has_legs, delta, 0.20, 0.40, biome["wear_mult"])
		leg_durability = maxf(0.0, leg_durability - wear)
		
		var stove_on: bool = cabin_temp < 10.0 and fuel > 0.0
		if stove_on:
			fuel -= sim.calculate_stove_fuel(true, delta)
		cabin_temp = sim.calculate_cabin_temperature(cabin_temp, outside_temp, stove_on, has_insulation, is_blizzard, delta)
		
		if cabin_temp < 0.0:
			player_health -= sim.calculate_cabin_cold_damage(cabin_temp, delta)
			
	runner.assert_gte(house_dist, 5000.0, "Upgraded house reached 5000m destination")
	runner.assert_true(has_insulation and has_engine and has_legs, "All 3 upgrades successfully acquired")
	runner.assert_gt(fuel, 250.0, "Upgraded run final fuel surplus is large (>250 units)")
	runner.assert_gte(scrap, 0.0, "Remaining scrap is non-negative")
	runner.assert_lt(total_time_sec / 60.0, 22.0, "Upgraded run completes faster than unupgraded (~20 min)")
	runner.end_test()

func test_07_extreme_boundary_and_numerical_stress(runner) -> void:
	runner.start_test("test_07_extreme_boundary_and_numerical_stress")
	var sim = load(SIM_PATH)
	
	# 1. Cabin temperature clamping
	var temp_superheated = sim.calculate_cabin_temperature(23.9, 30.0, true, true, false, 100.0)
	runner.assert_lte(temp_superheated, 24.0, "Cabin temp capped at max ceiling (24.0°C)")
	
	var temp_deepfreeze = sim.calculate_cabin_temperature(-45.0, -80.0, false, false, true, 1000.0)
	runner.assert_gte(temp_deepfreeze, -50.0, "Cabin temp clamped at physical floor (-50.0°C)")
	
	# 2. Outside cold damage buffer boundary
	runner.assert_almost_eq(sim.calculate_outside_cold_damage(19.99, 20.0, false, 1.0), 0.0, 0.001, "No damage at 19.99s")
	runner.assert_almost_eq(sim.calculate_outside_cold_damage(20.00, 20.0, false, 1.0), 0.0, 0.001, "No damage at exact 20.0s")
	runner.assert_gt(sim.calculate_outside_cold_damage(20.01, 20.0, false, 1.0), 0.0, "Damage triggers after 20.0s")
	runner.assert_almost_eq(sim.calculate_outside_cold_damage(30.0, 20.0, true, 1.0), 6.0, 0.01, "Blizzard outside damage is 6.0 HP/s")
	
	# 3. Safe radius tether penalty boundary
	var expo_inside = sim.calculate_player_outside_exposure(1.0, 45.0, 45.0, 2.5, 2.0)
	var expo_outside = sim.calculate_player_outside_exposure(1.0, 45.01, 45.0, 2.5, 2.0)
	runner.assert_almost_eq(expo_inside, 2.5, 0.01, "Safe radius exposure at 45.0m is 2.5")
	runner.assert_almost_eq(expo_outside, 5.0, 0.01, "Tether breach exposure at 45.01m is 5.0")
	
	# 4. Deadlock hysteresis timer reset
	var timer_res1 = sim.update_deadlock_timer(2.5, true, 0.4)
	runner.assert_almost_eq(timer_res1["timer"], 2.9, 0.01, "Timer advances to 2.9s")
	runner.assert_false(timer_res1["is_confirmed"], "Not confirmed at 2.9s")
	
	var timer_cleared = sim.update_deadlock_timer(2.9, false, 0.1)
	runner.assert_almost_eq(timer_cleared["timer"], 0.0, 0.001, "Timer resets to 0.0 on condition clearing")
	runner.assert_false(timer_cleared["is_confirmed"], "Not confirmed on reset")
	runner.end_test()

func test_08_gamestate_lifecycle_and_reset_invariants(runner) -> void:
	runner.start_test("test_08_gamestate_lifecycle_and_reset_invariants")
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	
	# Corrupt/mutate all fields
	gs.fuel = 3.14
	gs.leg_durability = 12.34
	gs.distance_traveled = 4999.0
	gs.house_speed = 99.0
	gs.is_house_moving = true
	gs.is_player_outside = true
	gs.cabin_temperature = -20.0
	gs.player_health = 5.0
	gs.player_warmth = 10.0
	gs.scrap = 999.0
	gs.supplies = 888.0
	gs.upgrades["insulation"] = 3
	gs.upgrades["engine"] = 3
	gs.upgrades["reinforced_legs"] = 3
	gs.is_blizzard = true
	gs.is_game_over = true
	gs.is_victory = true
	gs.elapsed_time = 12345.0
	gs.stats["repairs_count"] = 55
	
	# Execute reset_state
	gs.reset_state()
	
	# Verify pristine defaults
	runner.assert_almost_eq(gs.fuel, 100.0, 0.001, "Reset: fuel == 100.0")
	runner.assert_almost_eq(gs.leg_durability, 100.0, 0.001, "Reset: leg_durability == 100.0")
	runner.assert_almost_eq(gs.distance_traveled, 0.0, 0.001, "Reset: distance_traveled == 0.0")
	runner.assert_almost_eq(gs.house_speed, 0.0, 0.001, "Reset: house_speed == 0.0")
	runner.assert_false(gs.is_house_moving, "Reset: is_house_moving == false")
	runner.assert_false(gs.is_player_outside, "Reset: is_player_outside == false")
	runner.assert_almost_eq(gs.cabin_temperature, 18.0, 0.001, "Reset: cabin_temperature == 18.0")
	runner.assert_almost_eq(gs.player_health, 100.0, 0.001, "Reset: player_health == 100.0")
	runner.assert_almost_eq(gs.scrap, 0.0, 0.001, "Reset: scrap == 0.0")
	runner.assert_almost_eq(gs.supplies, 5.0, 0.001, "Reset: supplies == 5.0")
	runner.assert_eq(gs.upgrades["insulation"], 0, "Reset: insulation upgrade == 0")
	runner.assert_eq(gs.upgrades["engine"], 0, "Reset: engine upgrade == 0")
	runner.assert_eq(gs.upgrades["reinforced_legs"], 0, "Reset: reinforced_legs upgrade == 0")
	runner.assert_false(gs.is_blizzard, "Reset: is_blizzard == false")
	runner.assert_false(gs.is_game_over, "Reset: is_game_over == false")
	runner.assert_false(gs.is_victory, "Reset: is_victory == false")
	runner.assert_eq(gs.stats["repairs_count"], 0, "Reset: stats repairs_count == 0")
	
	gs.free()
	runner.end_test()
