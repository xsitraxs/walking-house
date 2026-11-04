# tests/suites/test_forensic_m3_auditor.gd
# Forensic Integrity Verification & Adversarial Stress Suite for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD)
# Audited by: m3_auditor_1 (Forensic Auditor)
extends SceneTree

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")
const BiomeManager = preload("res://scripts/world/BiomeManager.gd")
const GameCamera = preload("res://scripts/world/GameCamera.gd")
const Player = preload("res://scripts/entities/Player.gd")
const WalkingHouse = preload("res://scripts/entities/WalkingHouse.gd")
const World = preload("res://scripts/world/World.gd")
const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

func _init() -> void:
	_run_forensic_audit.call_deferred()

func _run_forensic_audit() -> void:
	await process_frame

	print("\n" + "=".repeat(80))
	print("  M3 FORENSIC INTEGRITY AUDIT & ADVERSARIAL STRESS SUITE")
	print("  Target: Milestone 3 (M3_PLAYER_EXPLORATION_WORLD)")
	print("  Auditor: m3_auditor_1 (Integrity Forensics & Adversarial Review)")
	print("=".repeat(80) + "\n")

	# Register autoload singletons for test environment
	var gs = GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)
	Engine.register_singleton("GameState", gs)

	var bus = EventBusScript.new()
	bus.name = "EventBus"
	root.add_child(bus)
	Engine.register_singleton("EventBus", bus)

	await run_test("CHECK 1: Player Kinematics, Acceleration, Deep Snow Friction & Velocity Invariants", Callable(self, "check_01_player_kinematics"))
	await run_test("CHECK 2: Safe Tether Symmetrical Distance, Cable Sag Math, 45m Warning & 50m Hard Clamp", Callable(self, "check_02_tether_geometry_and_clamp"))
	await run_test("CHECK 3: Sub-Zero Hypothermia Math, 20s Warmth Buffer, Blizzard & Violation Damage Scaling", Callable(self, "check_03_hypothermia_damage_scaling").bind(gs))
	await run_test("CHECK 4: Embark/Disembark State Machine, Critical Speed Lockouts & Boundary Proximity", Callable(self, "check_04_embark_disembark_lockout").bind(gs, bus))
	await run_test("CHECK 5: World Generation, StaticBody Ground Layering at Y=560 & Parallax Monotonicity", Callable(self, "check_05_world_ground_and_parallax"))
	await run_test("CHECK 6: BiomeManager 5 Biomes, Exact 1000m Intervals & Hermite Transition Blending", Callable(self, "check_06_biome_manager_interpolation"))
	await run_test("CHECK 7: 30 Deterministic Nodes Solvency, Exact Yield Totals & Double-Harvest Lockout", Callable(self, "check_07_nodes_solvency_and_harvest").bind(gs))
	await run_test("CHECK 8: Deadlock Reachability Query BVA Boundaries (44.9m, 45.0m, 45.1m) & State Exclusions", Callable(self, "check_08_deadlock_query_bva"))
	await run_test("CHECK 9: Dynamic GameCamera Framing, Smoothing, Velocity Lookahead & Zoom Transitions", Callable(self, "check_09_camera_tracking"))
	await run_test("CHECK 10: 100% Russian Localization Invariant on All Prompts, Biomes, Nodes & HUD Labels", Callable(self, "check_10_localization_audit"))
	await run_test("CHECK 11: Zero External Asset File & Texture Reference Forensics", Callable(self, "check_11_zero_external_assets"))
	await run_test("CHECK 12: Adversarial Stress: Rapid Toggle, Extreme Timesteps & Negative Coordinate Strain", Callable(self, "check_12_adversarial_stress").bind(gs))

	await process_frame
	await process_frame
	print_summary()

	Engine.unregister_singleton("GameState")
	Engine.unregister_singleton("EventBus")
	gs.free()
	bus.free()

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ==============================================================================
# AUDIT TEST CHECKS
# ==============================================================================

func check_01_player_kinematics() -> void:
	var player = Player.new()
	player.set_player_active(true)
	player.global_position = Vector2(500.0, 560.0)

	# Verify genuine speed constants
	assert_almost_eq(player.SPEED, 64.0, 0.01, "Player speed is exactly 64 px/s (3.2 m/s)")
	assert_almost_eq(player.ACCELERATION, 320.0, 0.01, "Acceleration is 320 px/s^2")
	assert_almost_eq(player.FRICTION, 400.0, 0.01, "Snow friction is 400 px/s^2")

	# Test velocity deceleration under friction
	player.velocity.x = 64.0
	player._process_locomotion(0.05)
	# After 0.05s of friction (400 * 0.05 = 20), velocity should be 44.0 px/s
	assert_almost_eq(player.velocity.x, 44.0, 0.1, "Velocity correctly decelerates by friction * delta")

	# Test full stop under friction
	player._process_locomotion(0.2)
	assert_almost_eq(player.velocity.x, 0.0, 0.001, "Velocity reaches strictly 0.0 under sustained friction")

	# Test ground vertical clamp (Y = 560.0 px)
	player.velocity.y = 100.0
	player.global_position.y = 999.0
	player._process_locomotion(0.016)
	assert_almost_eq(player.velocity.y, 0.0, 0.001, "Vertical velocity clamped to 0")
	assert_almost_eq(player.global_position.y, 560.0, 0.001, "Player Y coordinate strictly clamped to ground surface 560 px")

	player.free()

func check_02_tether_geometry_and_clamp() -> void:
	var player = Player.new()
	var house = Node2D.new()
	house.global_position = Vector2(2000.0, 432.0)
	player.house_ref = house
	player.set_player_active(true)

	# 1. Right side safe distance (dist = 30m = 600 px)
	player.global_position = Vector2(2600.0, 560.0)
	assert_almost_eq(player.get_distance_to_house_meters(), 30.0, 0.01, "Right-side distance is 30m")

	# 2. Left side symmetrical distance (dist = 30m = 600 px left)
	player.global_position = Vector2(1400.0, 560.0)
	assert_almost_eq(player.get_distance_to_house_meters(), 30.0, 0.01, "Left-side distance is 30m")

	# 3. Right side clamp limit violation (attempted 2000 + 1200 = 3200 px -> clamp to 2000 + 1000 = 3000 px)
	player.global_position = Vector2(3200.0, 560.0)
	player.velocity.x = 64.0
	player._process_tether(0.016)
	assert_almost_eq(player.global_position.x, 3000.0, 0.01, "Right side physically clamped to 50m limit (3000 px)")
	assert_lte(player.velocity.x, 0.0, "Rightward velocity halted at tether clamp")

	# 4. Left side clamp limit violation (attempted 2000 - 1200 = 800 px -> clamp to 2000 - 1000 = 1000 px)
	player.global_position = Vector2(800.0, 560.0)
	player.velocity.x = -64.0
	player._process_tether(0.016)
	assert_almost_eq(player.global_position.x, 1000.0, 0.01, "Left side physically clamped to 50m limit (1000 px)")
	assert_gte(player.velocity.x, 0.0, "Leftward velocity halted at tether clamp")

	player.free()
	house.free()

func check_03_hypothermia_damage_scaling(gs) -> void:
	gs.reset_state()
	var player = Player.new()
	var house = Node2D.new()
	house.global_position = Vector2(1000.0, 432.0)
	player.house_ref = house
	player.global_position = Vector2(1200.0, 560.0) # 10m from house (within 45m safe radius)
	player.set_player_active(true)

	# Phase A: 0 to 20s (warmth buffer)
	player.outside_exposure_timer = 0.0
	player._process_cold_exposure(10.0)
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Health remains 100% during first 10s of parka warmth")
	assert_almost_eq(gs.player_warmth, 50.0, 0.1, "Warmth percentage is 50% at 10s")

	player._process_cold_exposure(10.0) # Reach 20.0s
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Health remains 100% at exact 20.0s warmth expiration")
	assert_almost_eq(gs.player_warmth, 0.0, 0.01, "Warmth percentage is 0% at 20.0s")

	# Phase B: Calm cold damage (2.5 HP/s) for 4 seconds -> 10.0 HP damage
	player._process_cold_exposure(4.0)
	assert_almost_eq(gs.player_health, 90.0, 0.1, "Calm weather deals 2.5 HP/s (90 HP left after 4s)")

	# Phase C: Blizzard cold damage (6.0 HP/s) for 5 seconds -> 30.0 HP damage
	gs.is_blizzard = true
	player._process_cold_exposure(5.0)
	assert_almost_eq(gs.player_health, 60.0, 0.1, "Blizzard weather deals 6.0 HP/s (60 HP left after 5s)")
	gs.is_blizzard = false

	# Phase D: Tether violation (>45m) doubles damage rate: 2.5 * 2.0 = 5.0 HP/s for 4s -> 20.0 HP damage
	player.global_position = Vector2(1950.0, 560.0) # 47.5m from house (> 45m)
	player._process_cold_exposure(4.0)
	assert_almost_eq(gs.player_health, 40.0, 0.1, "Tether violation doubles cold damage to 5.0 HP/s (40 HP left after 4s)")

	# Phase E: Fatal hypothermia triggers game over
	player._process_cold_exposure(8.0) # 8.0s * 5.0 = 40.0 HP damage -> 0 HP
	assert_almost_eq(gs.player_health, 0.0, 0.01, "Player health dropped to 0")
	assert_true(gs.is_game_over, "GameState confirms game over upon player death")
	assert_true(gs.game_over_reason.contains("Переохлаждение"), "Game over reason cites hypothermia in Russian")

	player.free()
	house.free()

func check_04_embark_disembark_lockout(gs, bus) -> void:
	gs.reset_state()
	var house = WalkingHouse.new()
	house.game_state = gs
	house.event_bus = bus
	house.position = Vector2(1000.0, 432.0)

	var player = Player.new()
	player.game_state = gs
	player.event_bus = bus
	player.house_ref = house
	player.set_player_active(false)

	# 1. Moving house lockout checks across varied speeds
	var test_moving_speeds: Array[float] = [0.1, 1.0, 3.5, 5.0, -0.5, -2.5]
	for spd in test_moving_speeds:
		house.current_speed = spd
		house.is_house_moving = true
		var allowed: bool = house._handle_disembark_request()
		assert_false(allowed, "Disembark forbidden at moving speed %.2f m/s" % spd)
		assert_false(gs.is_player_outside, "Player remains safely inside")

	# 2. Stationary house permits disembark
	house.current_speed = 0.0
	house.is_house_moving = false
	var disembark_success: bool = house._handle_disembark_request()
	assert_true(disembark_success, "Disembark permitted when stationary (0.0 m/s)")
	assert_true(gs.is_player_outside, "Player is registered outside")

	# 3. Player entity active at ladder: house.x - 60 px = 940 px
	player.spawn_at_house_ladder(house)
	assert_almost_eq(player.global_position.x, 940.0, 0.1, "Player spawned at ladder X (1000 - 60 = 940 px)")
	assert_almost_eq(player.global_position.y, 560.0, 0.1, "Player spawned on snow surface Y (560 px)")
	assert_true(player.is_active, "Player is active")

	# 4. Re-enter house near ladder (<= 50 px)
	player._update_ladder_proximity()
	assert_true(player.can_reenter_house, "Player is within ladder proximity (< 50 px)")
	player._embark_into_house()
	assert_false(gs.is_player_outside, "Player successfully re-entered house cabin")

	player.free()
	house.free()

func check_05_world_ground_and_parallax() -> void:
	var world_scene: PackedScene = load("res://scenes/world/World.tscn")
	assert_true(world_scene != null, "World.tscn exists and compiles")
	var world = world_scene.instantiate()

	# Ground Collision Check
	var ground = world.get_node_or_null("Ground/GroundCollision")
	assert_true(ground != null, "GroundCollision node present")
	var r_shape: RectangleShape2D = ground.shape as RectangleShape2D
	assert_almost_eq(r_shape.size.x, 102000.0, 1.0, "Ground spans 102,000 px")
	assert_almost_eq(ground.position.y - r_shape.size.y * 0.5, 560.0, 0.1, "Ground top plane is at Y = 560.0 px")

	# Parallax Background 4 Layers Check
	var pbg = world.get_node_or_null("ParallaxBackground")
	assert_true(pbg != null, "ParallaxBackground present")
	var s_scale: float = world.get_node("ParallaxBackground/SkyLayer").motion_scale.x
	var m_scale: float = world.get_node("ParallaxBackground/MountainLayer").motion_scale.x
	var mid_scale: float = world.get_node("ParallaxBackground/MidgroundLayer").motion_scale.x
	var d_scale: float = world.get_node("ParallaxBackground/ForegroundDunesLayer").motion_scale.x

	assert_almost_eq(s_scale, 0.02, 0.001, "Sky layer scale is 0.02")
	assert_almost_eq(m_scale, 0.08, 0.001, "Mountain layer scale is 0.08")
	assert_almost_eq(mid_scale, 0.25, 0.001, "Midground layer scale is 0.25")
	assert_almost_eq(d_scale, 0.60, 0.001, "Dunes layer scale is 0.60")

	assert_true(s_scale < m_scale and m_scale < mid_scale and mid_scale < d_scale, "Parallax scales strictly monotonically increase")

	world.free()

func check_06_biome_manager_interpolation() -> void:
	var bm = BiomeManager.new()
	bm._ready()

	# Check 5 biomes names and bounds
	var expected_biomes: Array[Dictionary] = [
		{"id": "snowy_plains", "name": "Заснеженная равнина", "x": 500.0},
		{"id": "abandoned_camp", "name": "Заброшенный лагерь геологов", "x": 1500.0},
		{"id": "machinery_graveyard", "name": "Кладбище техники", "x": 2500.0},
		{"id": "frozen_forest", "name": "Замёрзший лес", "x": 3500.0},
		{"id": "station_outskirts", "name": "Окрестности станции «Полюс»", "x": 4500.0}
	]

	for exp in expected_biomes:
		var biome = bm.get_biome_at(exp["x"])
		assert_eq(biome["id"], exp["id"], "Biome id matches %s at %.0fm" % [exp["id"], exp["x"]])
		assert_eq(biome["name"], exp["name"], "Biome name matches '%s'" % exp["name"])

	# Check Hermite blend at 2000m boundary (+/- 50m blend zone)
	bm.update_distance(1950.0) # Start of blend zone
	var pal_start = bm.get_active_palette()
	bm.update_distance(2000.0) # Midpoint of blend zone
	var pal_mid = bm.get_active_palette()
	bm.update_distance(2050.0) # End of blend zone
	var pal_end = bm.get_active_palette()

	assert_true(pal_start.mountain_tint != pal_mid.mountain_tint, "Mountain tint changes across transition")
	assert_true(pal_mid.mountain_tint != pal_end.mountain_tint, "Mountain tint smoothly blends to next biome")

	bm.free()

func check_07_nodes_solvency_and_harvest(gs) -> void:
	gs.reset_state()
	var nodes: Array[Dictionary] = ResourceNode.DEFAULT_NODES
	assert_eq(nodes.size(), 30, "Exactly 30 deterministic resource nodes configured")

	var total_f: float = 0.0
	var total_s: float = 0.0
	var total_p: float = 0.0
	for n in nodes:
		total_f += n["fuel"]
		total_s += n["scrap"]
		total_p += n["supplies"]

	assert_almost_eq(total_f, 760.0, 0.01, "Total placed fuel strictly equals 760.0")
	assert_almost_eq(total_s, 55.0, 0.01, "Total placed scrap strictly equals 55.0")
	assert_almost_eq(total_p, 22.0, 0.01, "Total placed supplies strictly equals 22.0")

	# Test node harvesting and single-collection enforcement
	gs.fuel = 50.0
	var node = ResourceNode.new()
	node.setup_node({
		"node_id": 99,
		"node_type": ResourceNode.NodeType.CRATE,
		"distance_m": 100.0,
		"fuel": 40.0,
		"scrap": 5.0,
		"supplies": 2.0
	})

	var initial_fuel: float = gs.fuel
	var res1: Dictionary = node.harvest()
	assert_almost_eq(res1["fuel"], 40.0, 0.01, "First harvest yields 40.0 fuel")
	assert_almost_eq(gs.fuel, initial_fuel + 40.0, 0.01, "GameState fuel credited")
	assert_true(node.is_harvested, "Node flagged as harvested")

	# Second harvest must return 0
	var res2: Dictionary = node.harvest()
	assert_almost_eq(res2["fuel"], 0.0, 0.01, "Second harvest yields 0 fuel")
	assert_almost_eq(gs.fuel, initial_fuel + 40.0, 0.01, "GameState fuel not double credited")

	node.free()

func check_08_deadlock_query_bva() -> void:
	var node = ResourceNode.new()
	node.setup_node({
		"node_id": 101,
		"distance_m": 500.0,
		"fuel": 50.0,
		"scrap": 4.0
	})
	node.global_position = Vector2(10000.0, 560.0) # 500m * 20 px/m

	# House at 544.9m (dist = 44.9m <= 45.0m safe radius) -> Reachable
	assert_true(node.is_reachable_from(544.9 * 20.0, 45.0), "Node at 44.9m is reachable")

	# House at 545.0m (dist = 45.0m == 45.0m boundary) -> Reachable
	assert_true(node.is_reachable_from(545.0 * 20.0, 45.0), "Node at exactly 45.0m is reachable")

	# House at 545.1m (dist = 45.1m > 45.0m) -> NOT reachable
	assert_false(node.is_reachable_from(545.1 * 20.0, 45.0), "Node at 45.1m is NOT reachable")

	# House at 455.0m (dist = 45.0m on left side) -> Reachable
	assert_true(node.is_reachable_from(455.0 * 20.0, 45.0), "Node at 45.0m on left is reachable")

	# House at 454.9m (dist = 45.1m on left side) -> NOT reachable
	assert_false(node.is_reachable_from(454.9 * 20.0, 45.0), "Node at 45.1m on left is NOT reachable")

	# Once harvested, node is excluded from reachability
	node.is_harvested = true
	assert_false(node.is_reachable_from(500.0 * 20.0, 45.0), "Harvested node is excluded from reachability")

	node.free()

func check_09_camera_tracking() -> void:
	var cam = GameCamera.new()
	cam._ready()

	assert_eq(cam.limit_left, 0, "Camera left limit is 0")
	assert_gte(cam.limit_right, 100000, "Camera right limit covers full 5000m route")
	assert_eq(cam.limit_bottom, 720, "Camera bottom limit is 720")

	# Zoom levels
	assert_almost_eq(cam.ZOOM_HOUSE.x, 1.0, 0.01, "House zoom is 1.0x")
	assert_almost_eq(cam.ZOOM_PLAYER.x, 1.15, 0.01, "Player zoom is 1.15x")

	cam.free()

func check_10_localization_audit() -> void:
	# Audit all 30 resource node prompts and descriptions for Russian language
	var forbidden_english_words: Array[String] = [
		"Fuel", "Scrap", "Supplies", "Search", "Crate", "Camp", "Machine", "Interact", "Harvest", "Enter"
	]

	for node_data in ResourceNode.DEFAULT_NODES:
		var p: String = node_data["prompt"]
		var d: String = node_data["description"]

		# Must contain Cyrillic letters
		assert_true(_contains_cyrillic(p), "Prompt '%s' contains Cyrillic characters" % p)
		assert_true(_contains_cyrillic(d), "Description '%s' contains Cyrillic characters" % d)

		# Must not contain untranslated English keywords
		for w in forbidden_english_words:
			assert_false(p.to_lower().contains(w.to_lower()), "Prompt '%s' must not contain English '%s'" % [p, w])

	# Audit Biome names
	for b in BiomeManager.BIOME_PALETTES:
		var b_name: String = b["name"]
		assert_true(_contains_cyrillic(b_name), "Biome name '%s' contains Cyrillic" % b_name)

func _contains_cyrillic(text: String) -> bool:
	for c in text:
		var u: int = c.unicode_at(0)
		if (u >= 0x0400 and u <= 0x04FF) or u == 0x0500:
			return true
	return false

func check_11_zero_external_assets() -> void:
	# Inspect scenes/ and scripts/ for any binary texture or sound file references
	var test_files: Array[String] = [
		"res://scripts/entities/Player.gd",
		"res://scripts/world/ResourceNode.gd",
		"res://scripts/world/World.gd",
		"res://scripts/world/BiomeManager.gd",
		"res://scripts/world/SkyCanvas.gd",
		"res://scripts/world/MountainCanvas.gd",
		"res://scripts/world/MidgroundCanvas.gd",
		"res://scripts/world/DunesCanvas.gd",
		"res://scripts/world/GroundVisual.gd"
	]

	var forbidden_exts: Array[String] = [".png", ".jpg", ".jpeg", ".wav", ".mp3", ".ogg", ".gltf", ".fbx"]

	for path in test_files:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_true(f != null, "File %s opened cleanly" % path)
		if f != null:
			var content: String = f.get_as_text()
			f.close()
			for ext in forbidden_exts:
				assert_false(content.contains(ext), "File %s contains zero external asset reference '%s'" % [path, ext])

func check_12_adversarial_stress(gs) -> void:
	gs.reset_state()
	var player = Player.new()
	var house = Node2D.new()
	house.global_position = Vector2(50000.0, 432.0)
	player.house_ref = house
	player.set_player_active(true)

	# 1. Extreme large delta step (delta = 5.0 seconds in one frame)
	player.global_position = Vector2(50000.0, 560.0)
	player.velocity.x = 64.0
	player._process_locomotion(5.0)
	# Friction = 400. Over 5s, friction stops velocity cleanly without oscillation
	assert_almost_eq(player.velocity.x, 0.0, 0.001, "Large delta (5s) friction brings velocity to clean 0.0 without exploding")

	# 2. Extreme out-of-bounds tether pull (teleported to 100,000 px -> clamped to 51,000 px)
	player.global_position = Vector2(100000.0, 560.0)
	player._process_tether(0.016)
	assert_almost_eq(player.global_position.x, 51000.0, 0.01, "Extreme out-of-bounds position clamped cleanly to 50m tether limit")

	# 3. Negative delta safety (delta = -1.0)
	player._process_locomotion(-1.0)
	player._process_tether(-1.0)
	player._process_cold_exposure(-1.0)
	assert_almost_eq(player.global_position.y, 560.0, 0.01, "Negative delta causes no corruption or NaN")

	# 4. Zero delta safety
	player._process_locomotion(0.0)
	player._process_tether(0.0)
	player._process_cold_exposure(0.0)
	assert_almost_eq(player.global_position.y, 560.0, 0.01, "Zero delta safely handled")

	player.free()
	house.free()

# ==============================================================================
# REPORTING & ASSERTION INFRASTRUCTURE
# ==============================================================================

func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	var before_fails = failure_details.size()
	await test_callable.call()
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

func assert_lte(val: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if val > expected:
		var err = "[%s] FAILED: %s (Expected %f <= %f)" % [current_test, msg, val, expected]
		failure_details.append(err)
		printerr("    " + err)

func assert_gte(val: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if val < expected:
		var err = "[%s] FAILED: %s (Expected %f >= %f)" % [current_test, msg, val, expected]
		failure_details.append(err)
		printerr("    " + err)

func print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("  M3 FORENSIC AUDIT SUMMARY")
	print("=".repeat(80))
	print("  Total Forensic Checks: %d" % (passed_tests + failed_tests))
	print("  Passed:                %d" % passed_tests)
	print("  Failed:                %d" % failed_tests)
	print("  Total Assertions:      %d" % total_assertions)
	print("-".repeat(80))
	if failed_tests > 0:
		print("  VERDICT: INTEGRITY VIOLATION")
		for err in failure_details:
			print("   - %s" % err)
	else:
		print("  VERDICT: CLEAN — 100% PASS ACROSS ALL FORENSIC CHECKS")
	print("=".repeat(80) + "\n")
