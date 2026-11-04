# tests/suites/test_balance_sound.gd
# BalanceConfig and SoundManager procedural synthesis unit tests for «Шагающий дом»
extends SceneTree

const BALANCE_PATH: String = "res://scripts/core/BalanceConfig.gd"
const SOUND_PATH: String = "res://scripts/autoload/SoundManager.gd"

func _init() -> void:
	print("\n" + "=".repeat(70))
	print(" M1 TEST SUITE: BalanceConfig & SoundManager Procedural Audio")
	print("=".repeat(70))
	
	var passed: int = 0
	var failed: int = 0
	
	var tests: Array[Callable] = [
		Callable(self, "test_01_balance_constants"),
		Callable(self, "test_02_deterministic_route_table"),
		Callable(self, "test_03_route_mathematical_winnability"),
		Callable(self, "test_04_upgrades_math_and_affordability"),
		Callable(self, "test_05_sound_manager_synthesis_and_buses"),
		Callable(self, "test_06_event_bus_and_game_state_reactivity")
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

func test_01_balance_constants() -> bool:
	var cfg = load(BALANCE_PATH)
	if cfg == null:
		printerr("FAIL: BalanceConfig.gd could not be loaded")
		return false
		
	assert(cfg.ROUTE_LENGTH_METERS == 5000.0)
	assert(cfg.METERS_TO_PIXELS == 20.0)
	assert(cfg.WORLD_WIDTH_PIXELS == 100000.0)
	assert(cfg.BIOMES.size() == 5)
	
	assert(cfg.INITIAL_FUEL == 100.0)
	assert(cfg.INITIAL_LEG_DURABILITY == 100.0)
	assert(cfg.INITIAL_SCRAP == 0)
	assert(cfg.INITIAL_SUPPLIES == 5)
	assert(cfg.INITIAL_CABIN_TEMP == 18.0)
	assert(cfg.CABIN_FREEZE_THRESHOLD == 0.0)
	
	assert(cfg.BASE_FORWARD_SPEED == 5.0)
	assert(cfg.BASE_REVERSE_SPEED == 2.5)
	assert(cfg.WALK_FUEL_RATE == 0.50)
	assert(cfg.STOVE_FUEL_RATE == 0.25)
	assert(cfg.BASE_LEG_WEAR_PER_METER == 0.040)
	assert(cfg.DEADLOCK_GRACE_PERIOD == 3.0)
	return true

func test_02_deterministic_route_table() -> bool:
	var cfg = load(BALANCE_PATH)
	if cfg == null:
		return false
	var sites = cfg.POI_SITES
	if sites.size() != 20:
		printerr("FAIL: Expected 20 POIs, got ", sites.size())
		return false
		
	var prev_dist: float = 0.0
	for i in range(sites.size()):
		var p = sites[i]
		if p.distance_m <= prev_dist:
			printerr("FAIL: POI %d distance not strictly monotonic" % i)
			return false
		prev_dist = p.distance_m
		if p.distance_m <= 0.0 or p.distance_m >= 5000.0:
			printerr("FAIL: POI %d distance out of bounds" % i)
			return false
			
	var totals = cfg.get_total_poi_resources()
	print("  -> Route placed totals: Fuel=%.1f, Scrap=%d, Supplies=%d" % [totals.fuel, totals.scrap, totals.supplies])
	
	if totals.fuel != 760.0 or totals.scrap != 55 or totals.supplies != 22:
		printerr("FAIL: POI placed totals mismatch")
		return false
		
	var grand = cfg.get_grand_total_resources()
	print("  -> Route grand totals with reserves: Fuel=%.1f, Scrap=%d, Supplies=%d" % [grand.fuel, grand.scrap, grand.supplies])
	if grand.fuel != 820.0 or grand.scrap != 60 or grand.supplies != 25:
		printerr("FAIL: Route grand totals mismatch")
		return false
		
	return true

func test_03_route_mathematical_winnability() -> bool:
	var cfg = load(BALANCE_PATH)
	if cfg == null:
		return false
		
	# Locomotion fuel: 5000m * (0.50 fuel/sec / 5.0 m/s) = 500.0 fuel
	var locomotion_fuel: float = cfg.ROUTE_LENGTH_METERS * (cfg.WALK_FUEL_RATE / cfg.BASE_FORWARD_SPEED)
	# Stove fuel: 480 seconds * 0.25 fuel/sec = 120.0 fuel
	var heating_fuel: float = 480.0 * cfg.STOVE_FUEL_RATE
	var total_fuel_needed: float = locomotion_fuel + heating_fuel
	
	var grand = cfg.get_grand_total_resources()
	var total_fuel_available: float = grand.fuel
	var fuel_surplus: float = total_fuel_available - total_fuel_needed
	print("  -> Fuel balance: Needed=%.1f, Available=%.1f, Surplus=+%.1f (+%.1f%%)" % [
		total_fuel_needed, total_fuel_available, fuel_surplus, (fuel_surplus / total_fuel_needed) * 100.0
	])
	assert(fuel_surplus > 0.0)
		
	# Leg wear across 5 biomes
	var total_wear_percent: float = 0.0
	for b in cfg.BIOMES:
		var biome_len: float = b.end_m - b.start_m
		total_wear_percent += biome_len * cfg.BASE_LEG_WEAR_PER_METER * b.wear_mult
	assert(is_equal_approx(total_wear_percent, 230.0))
	
	var repairs_needed: int = int(ceil(total_wear_percent / cfg.REPAIR_DURABILITY_GAIN))
	var scrap_needed: int = repairs_needed * cfg.REPAIR_SCRAP_COST
	var total_scrap_available: int = grand.scrap
	var scrap_surplus: int = total_scrap_available - scrap_needed
	print("  -> Scrap balance: Needed=%d, Available=%d, Surplus=+%d" % [scrap_needed, total_scrap_available, scrap_surplus])
	assert(scrap_surplus > 0)
		
	# Playtime: 1000s moving + 20*18s scavenging = 1360s = 22.7 minutes
	var move_time_sec: float = cfg.ROUTE_LENGTH_METERS / cfg.BASE_FORWARD_SPEED
	var scavenge_time_sec: float = 20.0 * 18.0
	var total_time_min: float = (move_time_sec + scavenge_time_sec) / 60.0
	print("  -> Estimated unupgraded playtime: %.1f minutes (Target: 15-25 min)" % total_time_min)
	assert(total_time_min >= 15.0 and total_time_min <= 25.0)
	return true

func test_04_upgrades_math_and_affordability() -> bool:
	var cfg = load(BALANCE_PATH)
	if cfg == null:
		return false
	var upg = cfg.UPGRADES
	
	var total_cost_scrap: int = upg["insulation"].cost.scrap + upg["engine"].cost.scrap + upg["reinforced_legs"].cost.scrap
	var total_cost_supplies: int = upg["insulation"].cost.supplies + upg["engine"].cost.supplies + upg["reinforced_legs"].cost.supplies
	var total_cost_fuel: float = upg["insulation"].cost.fuel + upg["engine"].cost.fuel + upg["reinforced_legs"].cost.fuel
	
	assert(total_cost_scrap == 45)
	assert(total_cost_supplies == 14)
	assert(total_cost_fuel == 20.0)
	
	var grand = cfg.get_grand_total_resources()
	var total_scrap: int = grand.scrap
	# Reinforced legs reduce wear by 40%
	var reduced_wear: float = 230.0 * upg["reinforced_legs"].wear_multiplier
	var repair_scrap_needed: int = int(ceil(reduced_wear / cfg.REPAIR_DURABILITY_GAIN)) * cfg.REPAIR_SCRAP_COST
	var scrap_remaining: int = total_scrap - (total_cost_scrap + repair_scrap_needed)
	print("  -> Upgraded run remaining scrap: %d (Positive!)" % scrap_remaining)
	assert(scrap_remaining >= 0)
	return true

func test_05_sound_manager_synthesis_and_buses() -> bool:
	var sm_class = load(SOUND_PATH)
	if sm_class == null:
		printerr("FAIL: SoundManager.gd could not be loaded")
		return false
	var sm = sm_class.new()
	root.add_child(sm)
	
	var expected_sfx = ["step", "metal_clank", "loot", "stove_ignite", "stove_extinguish", "alarm", "click", "error"]
	for sfx in expected_sfx:
		assert(sm.sfx_streams.has(sfx))
		var wav = sm.sfx_streams[sfx] as AudioStreamWAV
		assert(wav != null and not wav.data.is_empty())
		assert(wav.format == AudioStreamWAV.FORMAT_16_BITS)
		assert(wav.mix_rate == 22050)
			
	var expected_loops = ["engine", "wind", "stove"]
	for l in expected_loops:
		assert(sm.loop_streams.has(l))
		var wav = sm.loop_streams[l] as AudioStreamWAV
		assert(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		assert(wav.format == AudioStreamWAV.FORMAT_16_BITS)
			
	sm.set_volume("SFX", 0.5)
	assert(is_equal_approx(sm.get_volume("SFX"), 0.5))
	
	sm.play_sfx("step")
	sm.play_sfx("click")
	sm.set_engine_hum(0.7)
	sm.set_wind_intensity(0.5)
	sm.set_stove_sound(true)
	sm.stop_all()
	
	root.remove_child(sm)
	sm.free()
	return true

func test_06_event_bus_and_game_state_reactivity() -> bool:
	var gs_class = load("res://scripts/autoload/GameState.gd")
	if gs_class == null:
		return false
	var gs = gs_class.new()
	root.add_child(gs)
	
	# Verify default values
	gs.reset_state()
	assert(gs.fuel == 100.0)
	assert(gs.leg_durability == 100.0)
	assert(gs.distance_traveled == 0.0)
	assert(gs.player_health == 100.0)
	assert(gs.cabin_temperature == 18.0)
	
	# Verify fuel consumption and auto-cutoff
	gs.set_stove(true)
	assert(gs.is_stove_on == true)
	gs.consume_fuel(100.0)
	assert(gs.fuel == 0.0)
	assert(gs.is_stove_on == false) # auto-cutoff at 0 fuel!
	
	# Verify leg repair
	gs.set_leg_durability(50.0)
	gs.set_scrap(2.0)
	var ok: bool = gs.repair_legs(20.0, 1.0)
	assert(ok == true)
	assert(gs.leg_durability == 70.0)
	assert(gs.scrap == 1.0)
	
	# Clean reset
	gs.reset_state()
	assert(gs.fuel == 100.0)
	assert(gs.leg_durability == 100.0)
	
	root.remove_child(gs)
	gs.free()
	return true
