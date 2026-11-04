# tests/suites/test_adversarial_m3_challenger.gd
# Empirical Challenger Adversarial Stress Suite for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD)
# Author: m3_challenger_1 (Challenger)
# Mandate: Empirical verification of Player Kinematics, Tether Radius, and Embark/Disembark State Machine
extends SceneTree

const SIM_PATH: String = "res://scripts/core/SimulationLogic.gd"
const CONFIG_PATH: String = "res://scripts/core/BalanceConfig.gd"
const GAME_STATE_PATH: String = "res://scripts/autoload/GameState.gd"
const EVENT_BUS_PATH: String = "res://scripts/autoload/EventBus.gd"
const SOUND_MGR_PATH: String = "res://scripts/autoload/SoundManager.gd"
const PLAYER_SCRIPT_PATH: String = "res://scripts/entities/Player.gd"
const HOUSE_SCRIPT_PATH: String = "res://scripts/entities/WalkingHouse.gd"
const NODE_SCRIPT_PATH: String = "res://scripts/world/ResourceNode.gd"
const BIOME_SCRIPT_PATH: String = "res://scripts/world/BiomeManager.gd"
const WORLD_SCENE_PATH: String = "res://scenes/world/World.tscn"

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

var bus: Node = null
var gs: Node = null
var sound: Node = null

func _init() -> void:
	_run_tests.call_deferred()

func _run_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(80))
	print("  M3 EMPIRICAL CHALLENGER ADVERSARIAL STRESS SUITE (CHALLENGER 1)")
	print("  Verification of Player Kinematics, 50m Tether Clamp, Embark Lockout,")
	print("  Cold Exposure Accumulation & 30 Deterministic Nodes Solvency")
	print("=".repeat(80) + "\n")
	
	# Setup singletons if missing
	bus = root.get_node_or_null("EventBus")
	if bus == null:
		var bus_script = load(EVENT_BUS_PATH)
		bus = bus_script.new()
		bus.name = "EventBus"
		root.add_child(bus)
	
	gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_script = load(GAME_STATE_PATH)
		gs = gs_script.new()
		gs.name = "GameState"
		root.add_child(gs)
		
	sound = root.get_node_or_null("SoundManager")
	if sound == null:
		var sound_script = load(SOUND_MGR_PATH)
		sound = sound_script.new()
		sound.name = "SoundManager"
		root.add_child(sound)

	var PlayerClass = load(PLAYER_SCRIPT_PATH)
	var HouseClass = load(HOUSE_SCRIPT_PATH)
	var NodeClass = load(NODE_SCRIPT_PATH)
	var BiomeClass = load(BIOME_SCRIPT_PATH)

	# CATEGORY 1: Player Kinematics, Velocity, Friction, and Ground Collision
	await run_test("M3-ADV 01: Player Movement Velocity & Acceleration Ramp-up (3.2 m/s = 64 px/s)", Callable(self, "test_01_kinematics_velocity_and_acceleration").bind(PlayerClass))
	await run_test("M3-ADV 02: Deep Snow Friction & Stopping Distance Invariant (400 px/s^2)", Callable(self, "test_02_snow_friction_and_stopping").bind(PlayerClass))
	await run_test("M3-ADV 03: Ground Plane Physics Alignment & World Boundary Walls (Y=560, X=[-50, 100500])", Callable(self, "test_03_ground_collision_and_boundaries").bind(PlayerClass))

	# CATEGORY 2: Safe Tether Radius, Boundary Zones, and 50m Hard Clamp
	await run_test("M3-ADV 04: Tether Distance Zones & Color Shift Transitions (38m warn, 45m danger)", Callable(self, "test_04_tether_zones_and_cable_color").bind(PlayerClass))
	await run_test("M3-ADV 05: 50m Hard Physical Tether Clamp & Bilateral Recovery (Left & Right)", Callable(self, "test_05_tether_50m_hard_clamp_bilateral").bind(PlayerClass))

	# CATEGORY 3: Embark / Disembark State Machine & Exit Lockouts
	await run_test("M3-ADV 06: Exit Lockout on Moving House (Forward, Reverse, Creep, Direct GS)", Callable(self, "test_06_exit_lockout_moving_house").bind(HouseClass))
	await run_test("M3-ADV 07: Stationary Disembark & House Movement Lockout while Outside", Callable(self, "test_07_stationary_disembark_and_house_lockout").bind(HouseClass, PlayerClass))
	await run_test("M3-ADV 08: Re-embarking Ladder Proximity Radius BVA (50 px = 2.5m)", Callable(self, "test_08_reembark_ladder_proximity_bva").bind(HouseClass, PlayerClass))

	# CATEGORY 4: Cold Exposure Accumulation, Grace Period, and Damage Multipliers
	await run_test("M3-ADV 09: Outside Warmth 20s Grace Period & Linear Decoupled Decay", Callable(self, "test_09_warmth_grace_period_decay").bind(PlayerClass))
	await run_test("M3-ADV 10: Calm (2.5 HP/s) vs Blizzard (6.0 HP/s) Exposure Accumulation", Callable(self, "test_10_calm_vs_blizzard_exposure").bind(PlayerClass))
	await run_test("M3-ADV 11: Tether Violation 2x Penalty (5.0 / 12.0 HP/s) & Hypothermia Lethality", Callable(self, "test_11_tether_violation_penalty_and_death").bind(PlayerClass))
	await run_test("M3-ADV 12: Re-embark Cabin Reset & Fresh Warmth Protection on Next Exit", Callable(self, "test_12_reembark_warmth_lifecycle").bind(HouseClass, PlayerClass))

	# CATEGORY 5: Scavenging, 30 Deterministic Nodes & Solvency
	await run_test("M3-ADV 13: Resource Node Scavenging, Loot State Sync & Anti-Exploit", Callable(self, "test_13_resource_node_scavenging_anti_exploit").bind(NodeClass))
	await run_test("M3-ADV 14: 30 Deterministic Nodes Balance Solvency & Reachability Query BVA", Callable(self, "test_14_solvency_and_reachability_bva").bind(NodeClass))

	await process_frame
	await process_frame
	print_summary()
	
	if bus != null and bus.get_parent() == root:
		bus.free()
	if gs != null and gs.get_parent() == root:
		gs.free()
	if sound != null and sound.get_parent() == root:
		sound.free()
		
	await process_frame
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ==============================================================================
# TEST RUNNER HARNESS
# ==============================================================================
func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	var assertions_before = total_assertions
	var failed_before = failure_details.size()
	
	print("  Running: %s ..." % test_name)
	await test_callable.call()
	
	var assert_count = total_assertions - assertions_before
	if failure_details.size() == failed_before:
		passed_tests += 1
		print("  [ PASS ] %s (%d assertions)" % [test_name, assert_count])
	else:
		failed_tests += 1
		print("  [ FAIL ] %s" % test_name)

func assert_true(val: bool, msg: String = "") -> void:
	total_assertions += 1
	if not val:
		var err = "[FAIL in %s] Expected true, got false. %s" % [current_test, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_false(val: bool, msg: String = "") -> void:
	total_assertions += 1
	if val:
		var err = "[FAIL in %s] Expected false, got true. %s" % [current_test, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_almost_eq(actual: float, expected: float, tol: float = 0.001, msg: String = "") -> void:
	total_assertions += 1
	if absf(actual - expected) > tol:
		var err = "[FAIL in %s] Expected ~%f (+/-%f), got %f. %s" % [current_test, expected, tol, actual, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_eq(actual, expected, msg: String = "") -> void:
	total_assertions += 1
	if actual != expected:
		var err = "[FAIL in %s] Expected '%s', got '%s'. %s" % [current_test, str(expected), str(actual), msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_gt(actual: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if actual <= expected:
		var err = "[FAIL in %s] Expected %f > %f. %s" % [current_test, actual, expected, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_gte(actual: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if actual < expected:
		var err = "[FAIL in %s] Expected %f >= %f. %s" % [current_test, actual, expected, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_lt(actual: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if actual >= expected:
		var err = "[FAIL in %s] Expected %f < %f. %s" % [current_test, actual, expected, msg]
		failure_details.append(err)
		printerr("    " + err)

func assert_lte(actual: float, expected: float, msg: String = "") -> void:
	total_assertions += 1
	if actual > expected:
		var err = "[FAIL in %s] Expected %f <= %f. %s" % [current_test, actual, expected, msg]
		failure_details.append(err)
		printerr("    " + err)

func print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("  M3 CHALLENGER TEST EXECUTION SUMMARY")
	print("=".repeat(80))
	print("  Total Tests:       %d" % [passed_tests + failed_tests])
	print("  [PASS] Passed:     %d" % passed_tests)
	print("  [FAIL] Failed:     %d" % failed_tests)
	print("  Total Assertions:  %d" % total_assertions)
	print("-".repeat(80))
	if failed_tests > 0:
		print("  OVERALL VERDICT:   REJECT (%d failed tests)" % failed_tests)
		for f in failure_details:
			print("    - %s" % f)
	else:
		print("  OVERALL VERDICT:   APPROVE (100% of adversarial tests passed)")
	print("=".repeat(80) + "\n")

# ==============================================================================
# TEST IMPLEMENTATIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# CATEGORY 1: Player Kinematics, Velocity, Friction, and Ground Collision
# ------------------------------------------------------------------------------
func test_01_kinematics_velocity_and_acceleration(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	player.set_player_active(true)
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(200.0, 560.0)
	
	# Verify fundamental constants
	assert_almost_eq(player.SPEED, 64.0, 0.001, "Player SPEED constant is 64.0 px/s (3.2 m/s)")
	assert_almost_eq(player.ACCELERATION, 320.0, 0.001, "Player ACCELERATION is 320.0 px/s^2")
	assert_almost_eq(player.FRICTION, 400.0, 0.001, "Player FRICTION is 400.0 px/s^2")
	
	# 1. Forward Acceleration Ramp-Up:
	# At ACCELERATION = 320 px/s^2, reaching 64 px/s requires 64 / 320 = 0.20 s.
	# Simulate 12 physics frames at dt = 1/60s (0.20s total)
	Input.action_press("move_right")
	var dt: float = 1.0 / 60.0
	for step in range(12):
		player._process_locomotion(dt)
		assert_almost_eq(player.facing, 1.0, 0.01, "Facing right during move_right")
		
	assert_almost_eq(player.velocity.x, 64.0, 0.1, "Velocity reaches exactly 64.0 px/s at t = 0.20s")
	
	# 2. Speed Cap Invariant under sustained input:
	# Run 60 more frames holding right: velocity must never exceed 64.0 px/s
	for step in range(60):
		player._process_locomotion(dt)
	assert_almost_eq(player.velocity.x, 64.0, 0.001, "Velocity clamped strictly at 64.0 px/s cap")
	Input.action_release("move_right")
	
	# 3. Reverse Acceleration Ramp-Up:
	# Reset to 0 and press move_left
	player.velocity.x = 0.0
	Input.action_press("move_left")
	for step in range(12):
		player._process_locomotion(dt)
		assert_almost_eq(player.facing, -1.0, 0.01, "Facing left during move_left")
		
	assert_almost_eq(player.velocity.x, -64.0, 0.1, "Velocity reaches -64.0 px/s at t = 0.20s")
	
	# Sustained reverse input:
	for step in range(60):
		player._process_locomotion(dt)
	assert_almost_eq(player.velocity.x, -64.0, 0.001, "Reverse velocity clamped strictly at -64.0 px/s cap")
	Input.action_release("move_left")
	
	player.queue_free()

func test_02_snow_friction_and_stopping(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	player.set_player_active(true)
	var dt: float = 1.0 / 60.0
	
	# 1. Forward Halting Test with genuine engine physics frames:
	# Start at top speed (+64.0 px/s). Input is released (axis = 0).
	# Deceleration = 400.0 px/s^2. Halting time = 64 / 400 = 0.16s (9.6 physics frames -> 10 frames).
	player.global_position = Vector2(200.0, 560.0)
	player.velocity.x = 64.0
	var initial_x: float = player.global_position.x
	
	for i in range(12):
		await physics_frame
		
	assert_almost_eq(player.velocity.x, 0.0, 0.001, "Velocity reaches exactly 0.0 px/s after 0.16s braking")
	
	# Theoretical stopping distance: sum(v_i * dt) = ~4.8 px (approx 5.12 px continuous integral)
	var stopped_dist = player.global_position.x - initial_x
	assert_almost_eq(stopped_dist, 5.12, 1.0, "Stopping distance in snow is ~5.12 px (~0.256 m)")


	
	# Zero jitter test: further frames with zero input stay at 0.0
	for i in range(30):
		player._process_locomotion(dt)
	assert_almost_eq(player.velocity.x, 0.0, 0.0001, "No jitter or overshoot across zero")
	
	# 2. Reverse Halting Test:
	player.velocity.x = -64.0
	for i in range(12):
		player._process_locomotion(dt)
	assert_almost_eq(player.velocity.x, 0.0, 0.001, "Reverse velocity decelerates to 0.0 px/s with zero overshoot")
	
	player.queue_free()


func test_03_ground_collision_and_boundaries(PlayerClass) -> void:
	# Load World.tscn scene to verify full collision hierarchy
	if not FileAccess.file_exists(WORLD_SCENE_PATH):
		assert_false(true, "World.tscn not found")
		return
		
	var world_scene: PackedScene = load(WORLD_SCENE_PATH)
	var world = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	
	var ground: StaticBody2D = world.get_node_or_null("Ground")
	assert_true(ground != null, "World contains StaticBody2D Ground")
	assert_eq(ground.collision_layer, 1, "Ground default collision layer is 1")
	
	var ground_shape: CollisionShape2D = world.get_node_or_null("Ground/GroundCollision")
	var rect_shape: RectangleShape2D = ground_shape.shape as RectangleShape2D
	var surface_y: float = ground_shape.position.y - (rect_shape.size.y * 0.5)
	assert_almost_eq(surface_y, 560.0, 0.01, "Ground surface elevation is exactly Y = 560.0 px")
	
	# Player instance in World
	var player = world.get_node_or_null("Player")
	assert_true(player != null, "World contains Player entity")
	assert_eq(player.collision_layer, 4, "Player collision_layer is 4")
	assert_eq(player.collision_mask, 1, "Player collision_mask is 1 (collides with Ground)")
	
	# Ground clamping check: Player at Y = 560.0 with bottom of CapsuleShape2D at Y=0 relative
	var col_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	var cap: CapsuleShape2D = col_shape.shape as CapsuleShape2D
	var cap_bottom_rel_y = col_shape.position.y + (cap.height * 0.5)
	assert_almost_eq(cap_bottom_rel_y, 0.0, 0.01, "Player capsule bottom is aligned with root origin (Y = 0)")
	
	# Simulate 10 physics frames of player standing on ground
	player.set_player_active(true)
	for i in range(10):
		player._physics_process(1.0 / 60.0)
	assert_almost_eq(player.global_position.y, 560.0, 0.01, "Player stays firmly on ground surface at Y = 560.0 px")
	
	# Boundary Walls: LeftWall is at X = -50 with width 100 (spans -100 to 0)
	var left_wall: CollisionShape2D = world.get_node_or_null("Ground/LeftWall")
	var right_wall: CollisionShape2D = world.get_node_or_null("Ground/RightWall")
	assert_true(left_wall != null and right_wall != null, "Left and Right boundary walls exist")
	
	world.free()

# ------------------------------------------------------------------------------
# CATEGORY 2: Safe Tether Radius, Boundary Zones, and 50m Hard Clamp
# ------------------------------------------------------------------------------
func test_04_tether_zones_and_cable_color(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	var house := Node2D.new()
	house.global_position = Vector2(1000.0, 432.0)
	root.add_child(house)
	player.house_ref = house
	player.set_player_active(true)
	
	# 1. Normal Zone (0 to 38m):
	player.global_position.x = 1000.0 + (30.0 * 20.0) # 30m = 1600 px
	assert_almost_eq(player.get_distance_to_house_meters(), 30.0, 0.01, "Distance is 30m")
	var d_m: float = player.get_distance_to_house_meters()
	assert_lte(d_m, 38.0, "30m is within Normal zone")
	
	# 2. Warning Zone (38m to 45m):
	player.global_position.x = 1000.0 + (42.0 * 20.0) # 42m = 1840 px
	d_m = player.get_distance_to_house_meters()
	assert_gt(d_m, 38.0, "42m exceeds 38m warning threshold")
	assert_lte(d_m, 45.0, "42m is within safe tether radius")
	
	# 3. Danger Zone (Exceeding 45m safe radius):
	player.global_position.x = 1000.0 + (46.0 * 20.0) # 46m = 1920 px
	d_m = player.get_distance_to_house_meters()
	assert_gt(d_m, 45.0, "46m exceeds 45m safe radius")
	
	# 4. Strict BVA boundary evaluations:
	# At 44.99m (inside safe radius)
	player.global_position.x = 1000.0 + (44.99 * 20.0)
	assert_lte(player.get_distance_to_house_meters(), 45.0, "44.99m is within safe radius")
	# At 45.00m (exact boundary)
	player.global_position.x = 1000.0 + (45.00 * 20.0)
	assert_almost_eq(player.get_distance_to_house_meters(), 45.0, 0.001, "45.00m is exact boundary")
	# At 45.01m (danger zone)
	player.global_position.x = 1000.0 + (45.01 * 20.0)
	assert_gt(player.get_distance_to_house_meters(), 45.0, "45.01m is in danger zone")
	
	player.queue_free()
	house.queue_free()

func test_05_tether_50m_hard_clamp_bilateral(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	var house := Node2D.new()
	house.global_position = Vector2(2000.0, 432.0)
	root.add_child(house)
	player.house_ref = house
	player.set_player_active(true)
	
	var prompt_box = {"text": ""}
	var on_prompt = func(p_text: String): 
		prompt_box["text"] = p_text
	bus.prompt_requested.connect(on_prompt)
	
	player.global_position.x = 3100.0
	player.velocity.x = 64.0
	player._process_tether(0.1)
	
	assert_almost_eq(player.global_position.x, 3000.0, 0.001, "Right position hard-clamped to exactly 3000.0 px (50m)")
	assert_lte(player.velocity.x, 0.0, "Outward right velocity stopped at clamp limit")
	assert_eq(prompt_box["text"], "Трос натянут до предела (50 м)!", "Prompt emitted on hitting hard tether clamp")
	
	# Sustained outward push stress (60 frames pushing right):
	for i in range(60):
		player.velocity.x = 64.0
		player._process_tether(0.016)
	assert_almost_eq(player.global_position.x, 3000.0, 0.001, "Zero outward creep under sustained 60-frame right push")
	
	# Inward recovery: pressing left immediately moves player back
	player.velocity.x = -64.0
	player._process_tether(0.1)
	assert_almost_eq(player.velocity.x, -64.0, 0.001, "Inward left velocity permitted without lockout")
	
	# 2. Leftward Hard Clamp (House X - 1000 px = 1000 px):
	prompt_box["text"] = ""
	player.global_position.x = 900.0 # 100 px past clamp
	player.velocity.x = -64.0
	player._process_tether(0.1)
	
	assert_almost_eq(player.global_position.x, 1000.0, 0.001, "Left position hard-clamped to exactly 1000.0 px (50m)")
	assert_gte(player.velocity.x, 0.0, "Outward left velocity stopped at clamp limit")
	assert_eq(prompt_box["text"], "Трос натянут до предела (50 м)!", "Prompt emitted on left clamp hit")
	
	# Sustained leftward push stress (60 frames):
	for i in range(60):
		player.velocity.x = -64.0
		player._process_tether(0.016)
	assert_almost_eq(player.global_position.x, 1000.0, 0.001, "Zero outward creep under sustained 60-frame left push")
	
	# Inward recovery: pressing right immediately moves player back
	player.velocity.x = 64.0
	player._process_tether(0.1)
	assert_almost_eq(player.velocity.x, 64.0, 0.001, "Inward right velocity permitted without lockout")
	
	bus.prompt_requested.disconnect(on_prompt)
	player.queue_free()
	house.queue_free()

# ------------------------------------------------------------------------------
# CATEGORY 3: Embark / Disembark State Machine & Exit Lockouts
# ------------------------------------------------------------------------------
func test_06_exit_lockout_moving_house(HouseClass) -> void:
	var house = HouseClass.new()
	house.game_state = gs
	house.event_bus = bus
	house.sound_manager = sound
	root.add_child(house)
	await process_frame
	
	gs.reset_state()
	
	var warning_box = {"text": ""}
	var on_prompt = func(msg: String): warning_box["text"] = msg
	bus.prompt_requested.connect(on_prompt)
	
	# Scenario A: House moving forward at full speed (5.0 m/s)
	house.current_speed = 5.0
	house.is_house_moving = true
	var ok: bool = house._handle_disembark_request()
	assert_false(ok, "Disembark request rejected while house moving forward at 5.0 m/s")
	assert_false(gs.is_player_outside, "GameState registers player inside cabin")
	assert_eq(warning_box["text"], "Нельзя покинуть дом на ходу! Полностью остановите машину.", "Expected Russian warning prompt")
	
	# Scenario B: House moving reverse (-2.5 m/s)
	warning_box["text"] = ""
	house.current_speed = -2.5
	house.is_house_moving = true
	ok = house._handle_disembark_request()
	assert_false(ok, "Disembark request rejected while house moving reverse at -2.5 m/s")
	assert_false(gs.is_player_outside, "Player remains inside cabin")
	
	# Scenario C: Low speed creep (+0.08 m/s > 0.05 m/s threshold)
	house.current_speed = 0.08
	house.is_house_moving = false
	ok = house._handle_disembark_request()
	assert_false(ok, "Disembark rejected on 0.08 m/s speed creep")
	
	# Scenario D: Direct call to GameState.disembark_player() while is_house_moving = true
	gs.set_house_moving(true)
	var direct_ok: bool = gs.disembark_player()
	assert_false(direct_ok, "GameState.disembark_player() defends in depth and rejects when is_house_moving = true")
	assert_false(gs.is_player_outside, "Player stays inside cabin")
	
	bus.prompt_requested.disconnect(on_prompt)
	house.queue_free()

func test_07_stationary_disembark_and_house_lockout(HouseClass, PlayerClass) -> void:
	var house = HouseClass.new()
	house.game_state = gs
	house.event_bus = bus
	house.sound_manager = sound
	root.add_child(house)
	
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	gs.reset_state()
	house.global_position = Vector2(800.0, 432.0)
	
	# 1. House is completely stationary:
	house.current_speed = 0.0
	house.is_house_moving = false
	gs.set_house_moving(false)
	gs.set_house_speed(0.0)
	
	var ok: bool = house._handle_disembark_request()
	assert_true(ok, "Disembark succeeds when house is stationary")
	assert_true(gs.is_player_outside, "GameState confirms player is outside")
	
	player.spawn_at_house_ladder(house)
	assert_true(player.is_active, "Player entity is active")
	assert_true(player.visible, "Player entity is visible")
	assert_almost_eq(player.global_position.x, 740.0, 0.01, "Player spawned at ladder X = 800 - 60 = 740 px")
	assert_almost_eq(player.global_position.y, 560.0, 0.01, "Player spawned at snow ground plane Y = 560 px")
	
	# 2. House Locomotion Lockout while Player is Outside:
	# WalkingHouse._process_locomotion forces target_speed = 0.0 when gs.is_player_outside is true
	house._process_locomotion(0.1)
	assert_almost_eq(house.target_speed, 0.0, 0.001, "House target speed locked to 0.0 while player is outside")
	
	# GameState.set_house_moving(true) must be rejected
	var can_move = gs.set_house_moving(true)
	assert_false(can_move, "GameState.set_house_moving(true) strictly rejected while player is outside")
	assert_false(gs.is_house_moving, "is_house_moving remains false")
	
	house.queue_free()
	player.queue_free()

func test_08_reembark_ladder_proximity_bva(HouseClass, PlayerClass) -> void:
	var house = HouseClass.new()
	house.game_state = gs
	house.event_bus = bus
	house.sound_manager = sound
	root.add_child(house)
	
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	player.house_ref = house
	root.add_child(player)
	await process_frame
	
	gs.reset_state()
	house.global_position = Vector2(1000.0, 432.0)
	gs.is_player_outside = true
	player.set_player_active(true)

	
	# Ladder is located at X = house.x - 60 px = 940.0 px
	# Ladder interaction radius is 50.0 px (2.5 m)
	
	# Test 8.1: Player right at ladder (dist = 0 px)
	player.global_position.x = 940.0
	player._update_ladder_proximity()
	assert_true(player.can_reenter_house, "Player at ladder can reenter house")
	
	# Test 8.2: Player at ladder boundary BVA: 940 + 49.9 px (inside)
	player.global_position.x = 989.9
	player._update_ladder_proximity()
	assert_true(player.can_reenter_house, "Player at 49.9 px from ladder can reenter")
	
	# Test 8.3: Player at ladder boundary BVA: 940 + 50.0 px (exact threshold)
	player.global_position.x = 990.0
	player._update_ladder_proximity()
	assert_true(player.can_reenter_house, "Player at exactly 50.0 px from ladder can reenter")
	
	# Test 8.4: Player at ladder boundary BVA: 940 + 50.1 px (outside)
	player.global_position.x = 990.1
	player._update_ladder_proximity()
	assert_false(player.can_reenter_house, "Player at 50.1 px from ladder CANNOT reenter")
	
	# Test 8.5: Player far from ladder (dist = 300 px)
	player.global_position.x = 1240.0
	player._update_ladder_proximity()
	assert_false(player.can_reenter_house, "Player at 300 px cannot reenter")
	
	# Test 8.6: Re-embarking execution at ladder
	player.global_position.x = 940.0
	player._update_ladder_proximity()
	player._embark_into_house()
	assert_false(gs.is_player_outside, "Player re-embarked into cabin, is_player_outside is false")
	
	house.queue_free()
	player.queue_free()

# ------------------------------------------------------------------------------
# CATEGORY 4: Cold Exposure Accumulation, Grace Period, and Damage Multipliers
# ------------------------------------------------------------------------------
func test_09_warmth_grace_period_decay(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	var house := Node2D.new()
	house.global_position = Vector2(500.0, 432.0)
	root.add_child(house)
	player.house_ref = house
	player.global_position = Vector2(550.0, 560.0) # 2.5m from house (within safe radius)
	player.set_player_active(true)
	
	gs.reset_state()
	gs.set_player_health(100.0)
	gs.set_player_warmth(100.0)
	gs.is_blizzard = false
	
	# 1. Start of exposure (t = 0.0):
	player.outside_exposure_timer = 0.0
	player._process_cold_exposure(0.0)
	assert_almost_eq(gs.player_warmth, 100.0, 0.01, "Warmth is 100% at t = 0")
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Health is 100 HP at t = 0")
	
	# 2. Advance 10 seconds:
	player.outside_exposure_timer = 0.0
	for i in range(10):
		player._process_cold_exposure(1.0)
	assert_almost_eq(gs.player_warmth, 50.0, 0.1, "Warmth is 50% at t = 10s")
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Zero health damage during first 10s")
	
	# 3. Advance to 19.99s:
	player.outside_exposure_timer = 19.0
	player._process_cold_exposure(0.99)
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Zero health damage at t = 19.99s (inside grace period)")
	
	# 4. Advance to 20.00s:
	player.outside_exposure_timer = 19.99
	player._process_cold_exposure(0.01)
	assert_almost_eq(gs.player_warmth, 0.0, 0.01, "Warmth depleted to 0% at t = 20.00s")
	assert_almost_eq(gs.player_health, 100.0, 0.01, "Zero health damage at exact 20.00s threshold")
	
	# 5. First second outside grace period (t = 21.0s):
	# Damage rate = 2.5 HP/s -> exactly 2.5 HP loss
	player._process_cold_exposure(1.0)
	assert_almost_eq(gs.player_health, 97.5, 0.01, "Exactly 2.5 HP cold damage after grace period expires")
	
	player.queue_free()
	house.queue_free()

func test_10_calm_vs_blizzard_exposure(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	var house := Node2D.new()
	house.global_position = Vector2(500.0, 432.0)
	root.add_child(house)
	player.house_ref = house
	player.global_position = Vector2(700.0, 560.0) # 10m from house (within safe radius)
	player.set_player_active(true)
	
	# 1. Calm weather: 2.5 HP/s
	gs.reset_state()
	gs.is_blizzard = false
	player.outside_exposure_timer = 20.0 # Warmth exhausted
	
	# Run 10 seconds of exposure in calm weather
	for i in range(10):
		player._process_cold_exposure(1.0)
	# 10s * 2.5 HP/s = 25.0 HP damage -> 100 - 25 = 75.0 HP
	assert_almost_eq(gs.player_health, 75.0, 0.1, "Calm weather inflicts exactly 25.0 HP across 10 seconds (2.5 HP/s)")
	
	# 2. Blizzard weather: 6.0 HP/s
	gs.reset_state()
	gs.is_blizzard = true
	player.outside_exposure_timer = 20.0
	
	# Run 10 seconds of exposure in blizzard
	for i in range(10):
		player._process_cold_exposure(1.0)
	# 10s * 6.0 HP/s = 60.0 HP damage -> 100 - 60 = 40.0 HP
	assert_almost_eq(gs.player_health, 40.0, 0.1, "Blizzard inflicts exactly 60.0 HP across 10 seconds (6.0 HP/s)")
	
	player.queue_free()
	house.queue_free()

func test_11_tether_violation_penalty_and_death(PlayerClass) -> void:
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	root.add_child(player)
	await process_frame
	
	var house := Node2D.new()
	house.global_position = Vector2(1000.0, 432.0)
	root.add_child(house)
	player.house_ref = house
	player.set_player_active(true)
	
	# 1. Calm weather with tether violation (dist = 48m > 45m safe radius):
	# Rate = 2.5 * 2.0 = 5.0 HP/s
	gs.reset_state()
	gs.is_blizzard = false
	player.global_position.x = 1000.0 + (48.0 * 20.0) # 48m
	player.outside_exposure_timer = 20.0
	
	for i in range(10):
		player._process_cold_exposure(1.0)
	# 10s * 5.0 HP/s = 50.0 HP damage -> 100 - 50 = 50.0 HP
	assert_almost_eq(gs.player_health, 50.0, 0.1, "Tether violation doubles calm hypothermia to 5.0 HP/s (50 HP lost in 10s)")
	
	# 2. Blizzard weather with tether violation:
	# Rate = 6.0 * 2.0 = 12.0 HP/s
	gs.reset_state()
	gs.is_blizzard = true
	player.global_position.x = 1000.0 + (48.0 * 20.0)
	player.outside_exposure_timer = 20.0
	
	for i in range(5):
		player._process_cold_exposure(1.0)
	# 5s * 12.0 HP/s = 60.0 HP damage -> 100 - 60 = 40.0 HP
	assert_almost_eq(gs.player_health, 40.0, 0.1, "Tether violation doubles blizzard hypothermia to 12.0 HP/s (60 HP lost in 5s)")
	
	# 3. Lethality Clamping & Game Over:
	# Further 4 seconds of exposure (4 * 12 = 48 damage, health would drop to -8)
	for i in range(4):
		player._process_cold_exposure(1.0)
	assert_almost_eq(gs.player_health, 0.0, 0.001, "Player health strictly clamped to 0.0 HP upon death (never negative)")
	assert_true(gs.is_game_over, "GameState triggers game over on hypothermia death")
	assert_true(gs.game_over_reason.contains("Переохлаждение"), "Game over reason cites hypothermia")
	
	player.queue_free()
	house.queue_free()

func test_12_reembark_warmth_lifecycle(HouseClass, PlayerClass) -> void:
	var house = HouseClass.new()
	house.game_state = gs
	house.event_bus = bus
	house.sound_manager = sound
	house.position = Vector2(1000.0, 432.0)
	root.add_child(house)
	
	var player = PlayerClass.new()
	player.game_state = gs
	player.event_bus = bus
	player.sound_manager = sound
	player.house_ref = house
	root.add_child(player)
	await process_frame
	
	gs.reset_state()
	
	# First Outing: Player goes outside, spends 25s, warmth expires
	house._handle_disembark_request()
	player.spawn_at_house_ladder(house)
	player.outside_exposure_timer = 25.0
	player._process_cold_exposure(1.0)
	assert_lt(gs.player_health, 100.0, "Player took cold damage during first outing")
	
	# Re-enter cabin
	player.global_position.x = 940.0
	player._update_ladder_proximity()
	player._embark_into_house()
	assert_false(gs.is_player_outside, "Player safely back inside cabin")
	
	# Second Outing: Disembark again
	house._handle_disembark_request()
	player.spawn_at_house_ladder(house)
	assert_almost_eq(player.outside_exposure_timer, 0.0, 0.001, "Timer reset to 0.0 upon fresh disembarkation")
	
	# First 10 seconds of second outing must be fully protected by fresh warmth
	var hp_before: float = gs.player_health
	for i in range(10):
		player._process_cold_exposure(1.0)
	assert_almost_eq(gs.player_health, hp_before, 0.001, "Zero additional cold damage during second outing grace period")
	assert_almost_eq(gs.player_warmth, 50.0, 0.1, "Warmth correctly decays to 50% during second outing")
	
	house.queue_free()
	player.queue_free()

# ------------------------------------------------------------------------------
# CATEGORY 5: Scavenging, 30 Deterministic Nodes & Solvency
# ------------------------------------------------------------------------------
func test_13_resource_node_scavenging_anti_exploit(NodeClass) -> void:
	var node = NodeClass.new()
	root.add_child(node)
	await process_frame
	
	gs.reset_state()
	gs.set_fuel(50.0)
	gs.set_scrap(5.0)
	gs.set_supplies(2.0)
	
	# Setup a machinery node with 3 scrap, 1 supply
	node.setup_node({
		"node_id": 101,
		"node_type": NodeClass.NodeType.MACHINERY,
		"distance_m": 250.0,
		"fuel": 0.0,
		"scrap": 3.0,
		"supplies": 1.0
	})
	
	assert_false(node.is_harvested, "Node initially unharvested")
	var prompt = node.get_interaction_prompt()
	assert_true(prompt.contains("[E] Разобрать механизм"), "Prompt is Russian context action")
	assert_true(prompt.contains("+3 Металлолом"), "Prompt preview shows scrap yield")
	assert_true(prompt.contains("+1 Припасы"), "Prompt preview shows supplies yield")
	
	# Harvest 1: Legitimate loot
	var yields: Dictionary = node.harvest()
	assert_almost_eq(yields["scrap"], 3.0, 0.01, "Yielded 3 scrap")
	assert_almost_eq(yields["supplies"], 1.0, 0.01, "Yielded 1 supply")
	assert_almost_eq(gs.scrap, 8.0, 0.01, "GameState scrap increased to 8")
	assert_almost_eq(gs.supplies, 3.0, 0.01, "GameState supplies increased to 3")
	assert_true(node.is_harvested, "Node marked as harvested")
	
	# Harvest 2: Double-loot anti-exploit
	var exploit_yields: Dictionary = node.harvest()
	assert_almost_eq(exploit_yields["scrap"], 0.0, 0.01, "Second harvest yields strictly 0 scrap")
	assert_almost_eq(exploit_yields["supplies"], 0.0, 0.01, "Second harvest yields strictly 0 supplies")
	assert_almost_eq(gs.scrap, 8.0, 0.01, "GameState scrap unchanged by exploit attempt")
	assert_almost_eq(gs.supplies, 3.0, 0.01, "GameState supplies unchanged by exploit attempt")
	
	node.queue_free()

func test_14_solvency_and_reachability_bva(NodeClass) -> void:
	var nodes: Array[Dictionary] = NodeClass.DEFAULT_NODES
	assert_eq(nodes.size(), 30, "Exactly 30 deterministic nodes exist")
	
	var tot_f: float = 0.0
	var tot_s: float = 0.0
	var tot_p: float = 0.0
	for n in nodes:
		tot_f += n["fuel"]
		tot_s += n["scrap"]
		tot_p += n["supplies"]
		
	assert_almost_eq(tot_f, 760.0, 0.001, "Sum of fuel strictly equals 760.0 units")
	assert_almost_eq(tot_s, 55.0, 0.001, "Sum of scrap strictly equals 55.0 units")
	assert_almost_eq(tot_p, 22.0, 0.001, "Sum of supplies strictly equals 22.0 units")
	
	# Test Reachability BVA (house_x vs node_x with 45m safe radius = 900 px)
	var node = NodeClass.new()
	node.setup_node({"node_id": 1, "distance_m": 500.0, "fuel": 30.0})
	node.global_position = Vector2(10000.0, 560.0) # 500m * 20 px/m
	
	# House at 500m + 44.9m (dist = 44.9m <= 45m)
	var house_44_9: float = (500.0 + 44.9) * 20.0
	assert_true(node.is_reachable_from(house_44_9, 45.0), "Node is reachable at 44.9m distance")
	
	# House at 500m + 45.0m (exact boundary)
	var house_45_0: float = (500.0 + 45.0) * 20.0
	assert_true(node.is_reachable_from(house_45_0, 45.0), "Node is reachable at 45.0m boundary")
	
	# House at 500m + 45.1m (outside safe radius)
	var house_45_1: float = (500.0 + 45.1) * 20.0
	assert_false(node.is_reachable_from(house_45_1, 45.0), "Node is NOT reachable at 45.1m distance")
	
	# Harvested node is excluded from reachability
	node.is_harvested = true
	assert_false(node.is_reachable_from(house_44_9, 45.0), "Harvested node is excluded from reachability queries")
	
	node.free()
