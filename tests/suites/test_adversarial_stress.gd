# tests/suites/test_adversarial_stress.gd
# Adversarial Stress Test Suite for Milestone 1 (M1_CORE_SIMULATION_PROJECT)
# Executed by Challenger to empirically probe edge cases, invariants, and failure modes.
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const BALANCE_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const TestOracle = preload("res://tests/test_oracle.gd")

var total_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("\n" + "=".repeat(74))
	print("  M1 ADVERSARIAL STRESS TEST HARNESS — EMPIRICAL CHALLENGER")
	print("=".repeat(74))
	
	var passed: int = 0
	var failed: int = 0
	
	var tests: Array[Callable] = [
		Callable(self, "test_01_zero_fuel_locomotion_blocking"),
		Callable(self, "test_02_negative_durability_clamping"),
		Callable(self, "test_03_over_repair_scrap_clamping"),
		Callable(self, "test_04_upgrade_multiplier_stacking_and_affordability"),
		Callable(self, "test_05_route_step_simulation_baseline_winnability"),
		Callable(self, "test_06_route_step_simulation_upgraded_winnability"),
		Callable(self, "test_07_extreme_boundary_and_numerical_stress"),
		Callable(self, "test_08_gamestate_lifecycle_and_reset_invariants")
	]
	
	for t in tests:
		var test_name: String = t.get_method()
		print("\n[CHALLENGE RUN] %s" % test_name)
		var ok: bool = t.call()
		if ok:
			passed += 1
			print("  -> PASS")
		else:
			failed += 1
			printerr("  -> FAIL (Vulnerability detected)")
			
	print("\n" + "=".repeat(74))
	print("  CHALLENGER RESULTS: %d PASSED, %d FAILED (Total Assertions: %d)" % [passed, failed, total_assertions])
	print("=".repeat(74) + "\n")
	
	if failed == 0:
		quit(0)
	else:
		quit(1)

func chk(condition: bool, msg: String) -> bool:
	total_assertions += 1
	if not condition:
		failed_assertions += 1
		printerr("    [ASSERTION FAILED] %s" % msg)
		return false
	return true

# ==============================================================================
# CHALLENGE 1: ZERO FUEL LOCOMOTION BLOCKING
# ==============================================================================
func test_01_zero_fuel_locomotion_blocking() -> bool:
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	root.add_child(gs)
	gs.reset_state()
	
	var all_ok: bool = true
	
	# 1. House cannot initiate movement when fuel is 0.0
	gs.set_fuel(0.0)
	var can_move = gs.set_house_moving(true)
	all_ok = chk(can_move == false, "set_house_moving(true) must return false when fuel is 0.0") and all_ok
	all_ok = chk(gs.is_house_moving == false, "is_house_moving must be false when fuel is 0.0") and all_ok
	
	# 2. Moving house halts immediately when fuel is drained to 0.0
	gs.set_fuel(10.0)
	var move_ok = gs.set_house_moving(true)
	gs.set_house_speed(5.0)
	all_ok = chk(move_ok == true and gs.is_house_moving == true, "House successfully starts moving with fuel") and all_ok
	
	# Drain fuel to zero
	var consumed = gs.consume_fuel(15.0)
	all_ok = chk(consumed == 10.0, "consume_fuel capped at available fuel (10.0)") and all_ok
	all_ok = chk(gs.fuel == 0.0, "Fuel strictly clamped to 0.0") and all_ok
	all_ok = chk(gs.is_house_moving == false, "is_house_moving must automatically halt on fuel exhaustion") and all_ok
	all_ok = chk(gs.house_speed == 0.0, "house_speed must drop to 0.0 on fuel exhaustion") and all_ok
	
	# 3. Stove auto-extinguishes on fuel exhaustion
	gs.set_fuel(5.0)
	var stove_on = gs.set_stove(true)
	all_ok = chk(stove_on == true and gs.is_stove_on == true, "Stove turns on with fuel") and all_ok
	gs.consume_fuel(5.0)
	all_ok = chk(gs.is_stove_on == false, "Stove must auto-extinguish when fuel reaches 0.0") and all_ok
	
	# 4. Stove cannot be turned on when fuel is 0.0
	var stove_attempt = gs.set_stove(true)
	all_ok = chk(stove_attempt == false and gs.is_stove_on == false, "Stove cannot be ignited with 0 fuel") and all_ok
	var toggle_attempt = gs.toggle_stove()
	all_ok = chk(toggle_attempt == false and gs.is_stove_on == false, "toggle_stove rejected with 0 fuel") and all_ok
	
	# 5. SimulationLogic fuel calculation with idle or negative delta
	var sim = load(SIM_PATH)
	all_ok = chk(sim.calculate_fuel_consumption(false, false, 1.0) == 0.0, "Stationary fuel burn is strictly 0.0") and all_ok
	all_ok = chk(sim.calculate_fuel_consumption(true, false, 0.0) == 0.0, "Zero delta fuel burn is 0.0") and all_ok
	all_ok = chk(sim.calculate_fuel_consumption(true, false, -5.0) == 0.0, "Negative delta fuel burn is 0.0") and all_ok
	
	root.remove_child(gs)
	gs.free()
	return all_ok

# ==============================================================================
# CHALLENGE 2: NEGATIVE DURABILITY CLAMPING
# ==============================================================================
func test_02_negative_durability_clamping() -> bool:
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
	# 1. calculate_speed with negative and zero durability
	all_ok = chk(sim.calculate_speed(5.0, 0.0, 100.0) == 0.0, "Zero durability -> 0.0 speed") and all_ok
	all_ok = chk(sim.calculate_speed(5.0, -0.001, 100.0) == 0.0, "Slightly negative durability -> 0.0 speed") and all_ok
	all_ok = chk(sim.calculate_speed(5.0, -100.0, 100.0) == 0.0, "Massively negative durability -> 0.0 speed") and all_ok
	all_ok = chk(sim.calculate_speed(5.0, 50.0, -100.0) == 0.0, "Negative max_durability -> 0.0 speed") and all_ok
	all_ok = chk(sim.calculate_speed(-5.0, 50.0, 100.0) == 0.0, "Negative base_speed -> 0.0 speed") and all_ok
	
	# 2. apply_repair with negative durability input
	# Negative durability should clamp to 0.0, so needed = 100.0, 2 scrap restores to 40.0, NOT -50 + 40 = -10!
	var rep_neg = sim.apply_repair(-50.0, 2.0, 100.0, 20.0)
	all_ok = chk(rep_neg["new_durability"] == 40.0, "Repairing negative durability restores from 0.0 clamp") and all_ok
	all_ok = chk(rep_neg["scrap_spent"] == 2.0, "2 scrap spent on negative durability repair") and all_ok
	
	var rep_zero_scrap = sim.apply_repair(-50.0, 0.0, 100.0, 20.0)
	all_ok = chk(rep_zero_scrap["new_durability"] == 0.0, "Zero scrap repair on negative durability clamps to 0.0") and all_ok
	all_ok = chk(rep_zero_scrap["scrap_spent"] == 0.0, "Zero scrap spent") and all_ok
	
	# 3. GameState durability bounds
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	root.add_child(gs)
	gs.reset_state()
	
	gs.set_leg_durability(-25.0)
	all_ok = chk(gs.leg_durability == 0.0, "set_leg_durability clamps negative value to 0.0") and all_ok
	all_ok = chk(gs.set_house_moving(true) == false, "Cannot move house when legs collapsed") and all_ok
	
	# wear_legs overflow and negative wear
	gs.set_leg_durability(30.0)
	var worn = gs.wear_legs(50.0)
	all_ok = chk(worn == 30.0, "wear_legs capped at current durability (30.0)") and all_ok
	all_ok = chk(gs.leg_durability == 0.0, "leg_durability strictly clamped to 0.0 after massive wear") and all_ok
	
	var neg_wear = gs.wear_legs(-10.0)
	all_ok = chk(neg_wear == 0.0, "Negative wear amount rejected (returns 0.0)") and all_ok
	all_ok = chk(gs.leg_durability == 0.0, "Durability unaffected by negative wear") and all_ok
	
	root.remove_child(gs)
	gs.free()
	return all_ok

# ==============================================================================
# CHALLENGE 3: OVER-REPAIR SCRAP CLAMPING
# ==============================================================================
func test_03_over_repair_scrap_clamping() -> bool:
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
	# 1. Durability 99.0%, available scrap 10.0 -> Needs 1% durability (<=20%), spends only 1 scrap
	var r1 = sim.apply_repair(99.0, 10.0, 100.0, 20.0)
	all_ok = chk(r1["new_durability"] == 100.0, "Over-repair: Durability capped at 100.0") and all_ok
	all_ok = chk(r1["scrap_spent"] == 1.0, "Over-repair: Only 1 scrap consumed, 9 scrap preserved") and all_ok
	
	# 2. Durability 100.0%, available scrap 10.0 -> Needs 0, spends 0
	var r2 = sim.apply_repair(100.0, 10.0, 100.0, 20.0)
	all_ok = chk(r2["new_durability"] == 100.0, "Full durability: Stays 100.0") and all_ok
	all_ok = chk(r2["scrap_spent"] == 0.0, "Full durability: 0 scrap spent") and all_ok
	
	# 3. Durability 120.0% (over-cap), available scrap 5.0 -> Needs 0, spends 0
	var r3 = sim.apply_repair(120.0, 5.0, 100.0, 20.0)
	all_ok = chk(r3["new_durability"] == 100.0, "Over-cap durability: Clamped to 100.0") and all_ok
	all_ok = chk(r3["scrap_spent"] == 0.0, "Over-cap durability: 0 scrap spent") and all_ok
	
	# 4. Durability 1.0%, available scrap 100.0 -> Needs 99%, requires 5 scrap (5*20 = 100%)
	var r4 = sim.apply_repair(1.0, 100.0, 100.0, 20.0)
	all_ok = chk(r4["new_durability"] == 100.0, "Severe damage full repair: Capped at 100.0") and all_ok
	all_ok = chk(r4["scrap_spent"] == 5.0, "Severe damage full repair: Spends exactly 5 scrap, 95 preserved") and all_ok
	
	# 5. GameState repair_legs when already at max durability
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	root.add_child(gs)
	gs.reset_state()
	gs.set_scrap(10.0)
	
	var full_rep = gs.repair_legs(20.0, 1.0)
	all_ok = chk(full_rep == false, "repair_legs returns false when durability is already 100.0") and all_ok
	all_ok = chk(gs.scrap == 10.0, "repair_legs does not deduct scrap when already full") and all_ok
	
	# GameState repair with slight damage (95.0%)
	gs.set_leg_durability(95.0)
	var slight_rep = gs.repair_legs(20.0, 1.0)
	all_ok = chk(slight_rep == true, "repair_legs succeeds when damaged") and all_ok
	all_ok = chk(gs.leg_durability == 100.0, "repair_legs clamps durability to max (100.0)") and all_ok
	all_ok = chk(gs.scrap == 9.0, "repair_legs deducts exactly 1.0 scrap") and all_ok
	
	root.remove_child(gs)
	gs.free()
	return all_ok

# ==============================================================================
# CHALLENGE 4: UPGRADE MULTIPLIER STACKING & AFFORDABILITY
# ==============================================================================
func test_04_upgrade_multiplier_stacking_and_affordability() -> bool:
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
	# 1. Engine upgrade discount (-30%)
	var base_fuel_10s = sim.calculate_fuel_consumption(true, false, 10.0)
	var upg_fuel_10s = sim.calculate_fuel_consumption(true, true, 10.0)
	all_ok = chk(is_equal_approx(base_fuel_10s, 5.0), "Base fuel for 10s is 5.0") and all_ok
	all_ok = chk(is_equal_approx(upg_fuel_10s, 3.5), "Upgraded fuel for 10s is 3.5 (-30%)") and all_ok
	
	# 2. Reinforced legs wear discount (-40%) across biomes
	var wear_plain_base = sim.calculate_leg_wear(true, false, 10.0, 0.20, 0.40, 1.0)
	var wear_plain_upg = sim.calculate_leg_wear(true, true, 10.0, 0.20, 0.40, 1.0)
	all_ok = chk(is_equal_approx(wear_plain_base, 2.0), "Base wear 10s plain is 2.0%") and all_ok
	all_ok = chk(is_equal_approx(wear_plain_upg, 1.2), "Upgraded wear 10s plain is 1.2% (-40%)") and all_ok
	
	var wear_graveyard_base = sim.calculate_leg_wear(true, false, 10.0, 0.20, 0.40, 1.5)
	var wear_graveyard_upg = sim.calculate_leg_wear(true, true, 10.0, 0.20, 0.40, 1.5)
	all_ok = chk(is_equal_approx(wear_graveyard_base, 3.0), "Base wear 10s graveyard (1.5x) is 3.0%") and all_ok
	all_ok = chk(is_equal_approx(wear_graveyard_upg, 1.8), "Upgraded wear 10s graveyard (1.5x) is 1.8%") and all_ok
	
	# 3. Insulation thermal retention (-45%) in calm and blizzard
	# Delta T = 30°C, k_base = 0.025
	# Calm uninsulated: loss = 0.025 * 30 * 1 = 0.75°C
	var t_calm_base = sim.calculate_cabin_temperature(15.0, -15.0, false, false, false, 1.0)
	all_ok = chk(is_equal_approx(t_calm_base, 14.25), "Calm uninsulated temp drops 0.75°C") and all_ok
	
	# Calm insulated: loss = 0.025 * (1 - 0.45) * 30 * 1 = 0.4125°C
	var t_calm_ins = sim.calculate_cabin_temperature(15.0, -15.0, false, true, false, 1.0)
	all_ok = chk(is_equal_approx(t_calm_ins, 15.0 - 0.4125), "Calm insulated temp drops 0.4125°C") and all_ok
	
	# Blizzard uninsulated: k = 0.025 * 1.8 = 0.045 -> loss = 0.045 * 30 = 1.35°C
	var t_blizz_base = sim.calculate_cabin_temperature(15.0, -15.0, false, false, true, 1.0)
	all_ok = chk(is_equal_approx(t_blizz_base, 15.0 - 1.35), "Blizzard uninsulated temp drops 1.35°C") and all_ok
	
	# Blizzard insulated: k = 0.025 * 1.8 * 0.55 = 0.02475 -> loss = 0.7425°C
	var t_blizz_ins = sim.calculate_cabin_temperature(15.0, -15.0, false, true, true, 1.0)
	all_ok = chk(is_equal_approx(t_blizz_ins, 15.0 - 0.7425), "Blizzard insulated temp drops 0.7425°C") and all_ok
	all_ok = chk(t_blizz_ins > t_blizz_base, "Insulation significantly protects during blizzard") and all_ok
	
	# 4. Affordability check boundary tests
	all_ok = chk(sim.can_afford_upgrade("insulation", 12.0, 6.0), "Insulation exact cost passes") and all_ok
	all_ok = chk(not sim.can_afford_upgrade("insulation", 11.99, 6.0), "Insulation 11.99 scrap fails") and all_ok
	all_ok = chk(not sim.can_afford_upgrade("insulation", 12.0, 5.99), "Insulation 5.99 supplies fails") and all_ok
	
	all_ok = chk(sim.can_afford_upgrade("legs", 18.0, 8.0), "Legs exact cost passes") and all_ok
	all_ok = chk(not sim.can_afford_upgrade("legs", 17.99, 8.0), "Legs 17.99 scrap fails") and all_ok
	all_ok = chk(not sim.can_afford_upgrade("legs", 18.0, 7.99), "Legs 7.99 supplies fails") and all_ok
	
	# Unknown upgrade rejection
	all_ok = chk(not sim.can_afford_upgrade("warp_drive", 100.0, 100.0), "Unknown upgrade rejected") and all_ok
	all_ok = chk(not sim.can_afford_upgrade("", 100.0, 100.0), "Empty upgrade string rejected") and all_ok
	
	return all_ok

# ==============================================================================
# CHALLENGE 5: ROUTE STEP-BY-STEP SIMULATION (UNUPGRADED BASELINE WINNABILITY)
# ==============================================================================
func test_05_route_step_simulation_baseline_winnability() -> bool:
	var cfg = load(BALANCE_PATH)
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
	# High-frequency empirical simulation: delta = 0.5s along the 5000m route
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
		# Check active blizzard
		var is_blizzard: bool = false
		for blizz in blizzards:
			if house_dist >= blizz["trigger_distance_m"] and house_dist < (blizz["trigger_distance_m"] + 150.0):
				is_blizzard = true
				break
				
		var biome = cfg.get_biome_at_distance(house_dist)
		var outside_temp: float = biome["day_temp"]
		if is_blizzard:
			outside_temp -= 15.0
			
		# Check if at next POI
		if poi_idx < pois.size() and house_dist >= pois[poi_idx]["distance_m"]:
			var current_poi = pois[poi_idx]
			# Stop to scavenge (18 seconds exploration time)
			var scavenge_time: float = 18.0
			total_time_sec += scavenge_time
			fuel += current_poi["fuel"]
			scrap += current_poi["scrap"]
			supplies += current_poi["supplies"]
			poi_idx += 1
			
			# Leg maintenance: Repair when durability falls below 50%
			if leg_durability < 50.0 and scrap >= 1.0:
				var rep = sim.apply_repair(leg_durability, scrap)
				leg_durability = rep["new_durability"]
				scrap -= rep["scrap_spent"]
		
		# Movement step
		var speed = sim.calculate_speed(5.0, leg_durability, 100.0)
		var step_dist = speed * delta
		house_dist = minf(5000.0, house_dist + step_dist)
		total_time_sec += delta
		
		# Fuel consumption: walk fuel
		var fuel_burn = sim.calculate_fuel_consumption(true, false, delta)
		fuel -= fuel_burn
		
		# Leg wear
		var wear = sim.calculate_leg_wear(true, false, delta, 0.20, 0.40, biome["wear_mult"])
		leg_durability = maxf(0.0, leg_durability - wear)
		
		# Cabin thermodynamics: stove maintains comfort if temp < 12°C
		var stove_on: bool = cabin_temp < 12.0 and fuel > 0.0
		if stove_on:
			fuel -= sim.calculate_stove_fuel(true, delta)
		cabin_temp = sim.calculate_cabin_temperature(cabin_temp, outside_temp, stove_on, false, is_blizzard, delta)
		
		# Cabin hypothermia check
		if cabin_temp < 0.0:
			player_health -= sim.calculate_cabin_cold_damage(cabin_temp, delta)
			
		min_fuel_seen = minf(min_fuel_seen, fuel)
		min_durability_seen = minf(min_durability_seen, leg_durability)
		min_health_seen = minf(min_health_seen, player_health)
		
		if fuel <= 0.0 or leg_durability <= 0.0 or player_health <= 0.0:
			break
			
	print("    [Baseline Run Metrics] Dist=%.1fm, Time=%.1f min, MinFuel=%.1f, MinDur=%.1f%%, MinHP=%.1f" % [
		house_dist, total_time_sec / 60.0, min_fuel_seen, min_durability_seen, min_health_seen
	])
	
	all_ok = chk(house_dist >= 5000.0, "Baseline unupgraded house reached 5000m destination") and all_ok
	all_ok = chk(min_fuel_seen > 10.0, "Fuel never dropped below safety margin (min %.1f)" % min_fuel_seen) and all_ok
	all_ok = chk(min_durability_seen > 20.0, "Leg durability never collapsed (min %.1f%%)" % min_durability_seen) and all_ok
	all_ok = chk(min_health_seen > 75.0, "Player health remained strong despite blizzard (min %.1f HP)" % min_health_seen) and all_ok
	all_ok = chk((total_time_sec / 60.0) >= 15.0 and (total_time_sec / 60.0) <= 25.0, "Duration within 15-25 min target") and all_ok
	return all_ok

# ==============================================================================
# CHALLENGE 6: ROUTE STEP-BY-STEP SIMULATION (UPGRADED PLAYTHROUGH WINNABILITY)
# ==============================================================================
func test_06_route_step_simulation_upgraded_winnability() -> bool:
	var cfg = load(BALANCE_PATH)
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
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
			
		# Check POI
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
				all_ok = chk(scrap >= 12.0 and supplies >= 6.0, "Afford insulation at POI 5") and all_ok
				scrap -= 12.0
				supplies -= 6.0
				has_insulation = true
				
			# Purchase Efficient Engine at POI 9 (2200m)
			if p_id == 9 and not has_engine:
				all_ok = chk(scrap >= 15.0 and fuel >= 20.0, "Afford engine at POI 9") and all_ok
				scrap -= 15.0
				fuel -= 20.0
				has_engine = true
				
			# Purchase Reinforced Legs at POI 12 (2950m) after maintaining legs in machinery graveyard
			if p_id == 12 and not has_legs:
				all_ok = chk(scrap >= 18.0 and supplies >= 8.0, "Afford legs at POI 12") and all_ok
				scrap -= 18.0
				supplies -= 8.0
				has_legs = true
				
			# Leg repair if needed
			if leg_durability < 40.0 and scrap >= 1.0:
				var rep = sim.apply_repair(leg_durability, scrap)
				leg_durability = rep["new_durability"]
				scrap -= rep["scrap_spent"]
		
		# Movement step: Upgraded speed = 5.75 m/s when legs installed
		var base_spd = 5.75 if has_legs else 5.0
		var speed = sim.calculate_speed(base_spd, leg_durability, 100.0)
		var step_dist = speed * delta
		house_dist = minf(5000.0, house_dist + step_dist)
		total_time_sec += delta
		
		# Fuel consumption with engine discount
		fuel -= sim.calculate_fuel_consumption(true, has_engine, delta)
		
		# Leg wear with reinforced legs discount
		var wear = sim.calculate_leg_wear(true, has_legs, delta, 0.20, 0.40, biome["wear_mult"])
		leg_durability = maxf(0.0, leg_durability - wear)
		
		# Cabin thermodynamics with insulation
		var stove_on: bool = cabin_temp < 10.0 and fuel > 0.0
		if stove_on:
			fuel -= sim.calculate_stove_fuel(true, delta)
		cabin_temp = sim.calculate_cabin_temperature(cabin_temp, outside_temp, stove_on, has_insulation, is_blizzard, delta)
		
		if cabin_temp < 0.0:
			player_health -= sim.calculate_cabin_cold_damage(cabin_temp, delta)
			
	print("    [Upgraded Run Metrics] Dist=%.1fm, Time=%.1f min, Fuel=%.1f, Scrap=%.0f, Supplies=%.0f" % [
		house_dist, total_time_sec / 60.0, fuel, scrap, supplies
	])
	
	all_ok = chk(house_dist >= 5000.0, "Upgraded house reached 5000m destination") and all_ok
	all_ok = chk(has_insulation and has_engine and has_legs, "All 3 upgrades successfully acquired during playthrough") and all_ok
	all_ok = chk(fuel > 250.0, "Upgraded run final fuel surplus is large (>250 units)") and all_ok
	all_ok = chk(scrap >= 0.0, "Remaining scrap is non-negative") and all_ok
	all_ok = chk((total_time_sec / 60.0) < 22.0, "Upgraded run is faster than baseline (~20 min)") and all_ok
	return all_ok

# ==============================================================================
# CHALLENGE 7: EXTREME BOUNDARY & NUMERICAL STRESS
# ==============================================================================
func test_07_extreme_boundary_and_numerical_stress() -> bool:
	var sim = load(SIM_PATH)
	var all_ok: bool = true
	
	# 1. Cabin temperature clamping under extreme heating/cooling
	var temp_superheated = sim.calculate_cabin_temperature(23.9, 30.0, true, true, false, 100.0)
	all_ok = chk(temp_superheated <= 24.0, "Cabin temp strictly capped at max ceiling (24.0°C)") and all_ok
	
	var temp_deepfreeze = sim.calculate_cabin_temperature(-45.0, -80.0, false, false, true, 1000.0)
	all_ok = chk(temp_deepfreeze >= -50.0, "Cabin temp clamped at lower physical floor (-50.0°C)") and all_ok
	
	# 2. Outside cold damage buffer boundary
	all_ok = chk(sim.calculate_outside_cold_damage(19.99, 20.0, false, 1.0) == 0.0, "No damage at 19.99s exposure") and all_ok
	all_ok = chk(sim.calculate_outside_cold_damage(20.00, 20.0, false, 1.0) == 0.0, "No damage at exact 20.0s buffer") and all_ok
	all_ok = chk(sim.calculate_outside_cold_damage(20.01, 20.0, false, 1.0) > 0.0, "Damage triggers immediately after 20.0s buffer") and all_ok
	all_ok = chk(sim.calculate_outside_cold_damage(30.0, 20.0, true, 1.0) == 6.0, "Blizzard outside damage is 6.0 HP/s") and all_ok
	
	# 3. Safe radius tether penalty boundary
	var expo_inside = sim.calculate_player_outside_exposure(1.0, 45.0, 45.0, 2.5, 2.0)
	var expo_outside = sim.calculate_player_outside_exposure(1.0, 45.01, 45.0, 2.5, 2.0)
	all_ok = chk(is_equal_approx(expo_inside, 2.5), "Safe radius exposure at 45.0m is 2.5") and all_ok
	all_ok = chk(is_equal_approx(expo_outside, 5.0), "Tether breach exposure at 45.01m is doubled to 5.0") and all_ok
	
	# 4. Deadlock hysteresis timer reset on temporary relief
	var timer_res1 = sim.update_deadlock_timer(2.5, true, 0.4)
	all_ok = chk(timer_res1["timer"] == 2.9 and timer_res1["is_confirmed"] == false, "Deadlock timer advances to 2.9s without triggering") and all_ok
	
	# Condition clears (e.g. player steps outside or fuel collected)
	var timer_cleared = sim.update_deadlock_timer(2.9, false, 0.1)
	all_ok = chk(timer_cleared["timer"] == 0.0 and timer_cleared["is_confirmed"] == false, "Deadlock timer instantly resets to 0.0 on condition clearing") and all_ok
	
	return all_ok

# ==============================================================================
# CHALLENGE 8: GAMESTATE LIFECYCLE & RESET INVARIANTS
# ==============================================================================
func test_08_gamestate_lifecycle_and_reset_invariants() -> bool:
	var gs_class = load(GAME_STATE_PATH)
	var gs = gs_class.new()
	root.add_child(gs)
	var all_ok: bool = true
	
	# Corrupt/mutate all fields to dirty state
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
	
	# Verify complete pristine invariant restoration
	all_ok = chk(gs.fuel == 100.0, "Reset: fuel == 100.0") and all_ok
	all_ok = chk(gs.leg_durability == 100.0, "Reset: leg_durability == 100.0") and all_ok
	all_ok = chk(gs.distance_traveled == 0.0, "Reset: distance_traveled == 0.0") and all_ok
	all_ok = chk(gs.house_speed == 0.0, "Reset: house_speed == 0.0") and all_ok
	all_ok = chk(gs.is_house_moving == false, "Reset: is_house_moving == false") and all_ok
	all_ok = chk(gs.is_player_outside == false, "Reset: is_player_outside == false") and all_ok
	all_ok = chk(gs.cabin_temperature == 18.0, "Reset: cabin_temperature == 18.0") and all_ok
	all_ok = chk(gs.player_health == 100.0, "Reset: player_health == 100.0") and all_ok
	all_ok = chk(gs.scrap == 0.0, "Reset: scrap == 0.0") and all_ok
	all_ok = chk(gs.supplies == 5.0, "Reset: supplies == 5.0") and all_ok
	all_ok = chk(gs.upgrades["insulation"] == 0, "Reset: insulation upgrade == 0") and all_ok
	all_ok = chk(gs.upgrades["engine"] == 0, "Reset: engine upgrade == 0") and all_ok
	all_ok = chk(gs.upgrades["reinforced_legs"] == 0, "Reset: reinforced_legs upgrade == 0") and all_ok
	all_ok = chk(gs.is_blizzard == false, "Reset: is_blizzard == false") and all_ok
	all_ok = chk(gs.is_game_over == false, "Reset: is_game_over == false") and all_ok
	all_ok = chk(gs.is_victory == false, "Reset: is_victory == false") and all_ok
	all_ok = chk(gs.stats["repairs_count"] == 0, "Reset: stats repairs_count == 0") and all_ok
	
	root.remove_child(gs)
	gs.free()
	return all_ok
