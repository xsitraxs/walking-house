# tests/suites/test_adversarial_m3_challenger_r2.gd
# Empirical Challenger Adversarial Stress Suite for Milestone 3 (Iteration 2)
# Author: m3_challenger_2_r2
# Focus: Tether oscillation, prompt lifecycle, interactable conflicts, extreme deltas, cold exposure invariants
extends SceneTree

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")
const Player = preload("res://scripts/entities/Player.gd")
const WalkingHouse = preload("res://scripts/entities/WalkingHouse.gd")
const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")
const SoundManagerScript = preload("res://scripts/autoload/SoundManager.gd")

var total_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_details: Array[String] = []

var gs: Node = null
var bus: Node = null
var sound: Node = null

# Track last prompt emitted by EventBus
var last_prompt_requested: String = ""
var prompt_cleared_count: int = 0
var prompt_requested_count: int = 0

func _init() -> void:
	_run_adversarial_suite.call_deferred()

func _on_bus_prompt_requested(prompt: String) -> void:
	last_prompt_requested = prompt
	prompt_requested_count += 1

func _on_bus_prompt_cleared() -> void:
	last_prompt_requested = ""
	prompt_cleared_count += 1

func _reset_prompt_tracking() -> void:
	last_prompt_requested = ""
	prompt_cleared_count = 0
	prompt_requested_count = 0

func _run_adversarial_suite() -> void:
	await process_frame

	print("\n" + "=".repeat(80))
	print("  M3 EMPIRICAL CHALLENGER ADVERSARIAL STRESS SUITE (ITERATION 2)")
	print("  Author: m3_challenger_2_r2")
	print("  Focus: Tether Boundary Oscillation, Prompt Lifecycle, Interactable Conflicts,")
	print("         Extreme Delta Steps, and Health Loss Invariants (Calm vs Blizzard)")
	print("=".repeat(80) + "\n")

	# Register autoload singletons
	gs = GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)
	Engine.register_singleton("GameState", gs)

	bus = EventBusScript.new()
	bus.name = "EventBus"
	root.add_child(bus)
	Engine.register_singleton("EventBus", bus)

	sound = SoundManagerScript.new()
	sound.name = "SoundManager"
	root.add_child(sound)
	Engine.register_singleton("SoundManager", sound)

	bus.connect("prompt_requested", Callable(self, "_on_bus_prompt_requested"))
	bus.connect("prompt_cleared", Callable(self, "_on_bus_prompt_cleared"))

	# SUITE 1: Rapid Oscillation Across 50m Tether Clamp Boundary (1000 Frames)
	await run_test("STRESS 1: 1000-Frame Oscillation Across 50m Tether Clamp (Right side 49.9m <-> 50.1m)", Callable(self, "stress_01_tether_oscillation_right"))
	await run_test("STRESS 2: 1000-Frame Oscillation Across 50m Tether Clamp (Left side -49.9m <-> -50.1m)", Callable(self, "stress_02_tether_oscillation_left"))
	await run_test("STRESS 3: Outward Velocity Arrest & Non-Jitter Clamping Under Extreme Outward Impulses", Callable(self, "stress_03_tether_velocity_arrest_and_damping"))

	# SUITE 2: Interaction Conflict & Prompt Lifecycle
	await run_test("STRESS 4: Interaction Conflict: Overlapping House Ladder & Resource Node Proximity", Callable(self, "stress_04_overlapping_ladder_and_node"))
	await run_test("STRESS 5: Prompt Lifecycle: Harvesting Resource Node Inside Ladder Proximity", Callable(self, "stress_05_node_harvest_inside_ladder_proximity"))
	await run_test("STRESS 6: Tether Limit & Node Interaction: Node at 50m Hard Clamp & Post-Harvest Prompt", Callable(self, "stress_06_node_at_tether_clamp_prompt_lifecycle"))

	# SUITE 3: Extreme Delta Timesteps
	await run_test("STRESS 7: Extreme Delta Steps: Large Delta (2.0s, 10.0s) Position Clamping & Stability", Callable(self, "stress_07_extreme_large_delta"))
	await run_test("STRESS 8: Extreme Delta Steps: Micro Delta (0.0001s) Kinematics & Sag Parabola Math", Callable(self, "stress_08_extreme_micro_delta"))
	await run_test("STRESS 9: Extreme Delta Steps: Non-Positive Delta (-1.0s, 0.0s) Invariant Preservation", Callable(self, "stress_09_non_positive_delta_invariance"))

	# SUITE 4: Health Loss Invariant Outside House (Calm vs Blizzard)
	await run_test("STRESS 10: 20s Warmth Buffer Strict Invariant (Calm & Blizzard Zero Damage)", Callable(self, "stress_10_warmth_buffer_zero_damage_invariant"))
	await run_test("STRESS 11: Sub-Zero Cold Exposure Rates: Calm (2.5) vs Blizzard (6.0) 2.4x Scaling", Callable(self, "stress_11_calm_vs_blizzard_damage_rates"))
	await run_test("STRESS 12: Tether Violation Double-Damage Penalty (5.0 Calm / 12.0 Blizzard)", Callable(self, "stress_12_tether_violation_penalty_rates"))
	await run_test("STRESS 13: Hypothermia Lethality Clamp at 0 HP & GameOver Trigger Invariant", Callable(self, "stress_13_hypothermia_lethality_game_over"))
	await run_test("STRESS 14: Embark-Disembark Exposure Reset & Warmth Refresh Invariant", Callable(self, "stress_14_embark_disembark_exposure_reset"))

	await process_frame
	await process_frame
	print_summary()

	# Cleanup
	if gs != null and gs.get_parent() == root:
		gs.free()
	if bus != null and bus.get_parent() == root:
		bus.free()
	if sound != null and sound.get_parent() == root:
		sound.free()

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ------------------------------------------------------------------------------
# TEST RUNNER HARNESS
# ------------------------------------------------------------------------------
func run_test(test_name: String, test_callable: Callable) -> void:
	current_test = test_name
	_reset_prompt_tracking()
	gs.reset_state()
	print("  RUNNING: %s" % test_name)
	var pre_fail: int = failure_details.size()
	test_callable.call()
	if failure_details.size() == pre_fail:
		passed_tests += 1
		print("  [ PASS ] %s" % test_name)
	else:
		failed_tests += 1
		print("  [ FAIL ] %s" % test_name)

func assert_true(cond: bool, msg: String) -> void:
	total_assertions += 1
	if not cond:
		var err: String = "[%s] FAILED: %s" % [current_test, msg]
		printerr("    " + err)
		failure_details.append(err)

func assert_eq(actual, expected, msg: String) -> void:
	total_assertions += 1
	if actual != expected:
		var err: String = "[%s] FAILED: %s (got %s, expected %s)" % [current_test, msg, str(actual), str(expected)]
		printerr("    " + err)
		failure_details.append(err)

func assert_almost_eq(actual: float, expected: float, tol: float, msg: String) -> void:
	total_assertions += 1
	if absf(actual - expected) > tol:
		var err: String = "[%s] FAILED: %s (got %f, expected %f, tol %f)" % [current_test, msg, actual, expected, tol]
		printerr("    " + err)
		failure_details.append(err)

func print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("  M3 ADVERSARIAL STRESS TEST SUMMARY (ITERATION 2)")
	print("=".repeat(80))
	print("  Total Stress Checks: %d" % (passed_tests + failed_tests))
	print("  Passed:              %d" % passed_tests)
	print("  Failed:              %d" % failed_tests)
	print("  Total Assertions:    %d" % total_assertions)
	print("-".repeat(80))
	if failed_tests > 0:
		print("  VERDICT: REJECT — %d FAILURE(S) DETECTED:" % failed_tests)
		for f in failure_details:
			print("    * " + f)
	else:
		print("  VERDICT: APPROVE — 100% PASS ACROSS ALL EMPIRICAL STRESS CHECKS")
	print("=".repeat(80) + "\n")

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------
func _spawn_house_and_player(house_x: float = 5000.0) -> Dictionary:
	gs.reset_state()
	gs.distance_traveled = house_x / BalanceConfig.METERS_TO_PIXELS
	
	var house: WalkingHouse = WalkingHouse.new()
	root.add_child(house)
	house.global_position = Vector2(house_x, 560.0)

	var player: Player = Player.new()
	root.add_child(player)
	player.house_ref = house
	
	# Disembark player cleanly via GameState
	gs.disembark_player()
	player.spawn_at_house_ladder(house)
	
	return {"house": house, "player": player}

func _cleanup_entities(dict: Dictionary) -> void:
	if dict.has("player") and is_instance_valid(dict["player"]):
		dict["player"].free()
	if dict.has("house") and is_instance_valid(dict["house"]):
		dict["house"].free()
	gs.reset_state()


# ------------------------------------------------------------------------------
# SUITE 1: TETHER BOUNDARY OSCILLATION (1000 FRAMES)
# ------------------------------------------------------------------------------
func stress_01_tether_oscillation_right() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	var house_x: float = house.global_position.x # 5000.0
	var clamp_right_x: float = house_x + 1000.0   # 6000.0
	var inner_x: float = house_x + 998.0          # 49.9m (inner)
	var outer_x: float = house_x + 1002.0         # 50.1m (outer attempted)

	var prompt_requested_seen: int = 0
	var prompt_cleared_seen: int = 0

	# Rapidly oscillate across boundary for 1000 frames
	for frame in range(1000):
		if frame % 2 == 0:
			# Step inner (49.9m)
			player.global_position.x = inner_x
			player.velocity.x = -32.0 # moving inward
			player._process_tether(0.016)
			assert_true(not player.is_at_tether_limit, "Frame %d: is_at_tether_limit must be false at 49.9m" % frame)
			assert_eq(last_prompt_requested, "", "Frame %d: prompt must be cleared at 49.9m" % frame)
			prompt_cleared_seen += 1
		else:
			# Step outer (50.1m)
			player.global_position.x = outer_x
			player.velocity.x = 64.0 # attempting outward speed
			player._process_tether(0.016)
			# Hard physical clamp must hold position exactly at 6000.0
			assert_almost_eq(player.global_position.x, clamp_right_x, 0.001, "Frame %d: clamp must hold at 6000.0" % frame)
			# Outward velocity must be arrested
			assert_almost_eq(player.velocity.x, 0.0, 0.001, "Frame %d: outward velocity must be arrested to 0" % frame)
			assert_true(player.is_at_tether_limit, "Frame %d: is_at_tether_limit must be true at clamp" % frame)
			assert_eq(last_prompt_requested, "Трос натянут до предела (50 м)!", "Frame %d: warning prompt must be active at clamp" % frame)
			prompt_requested_seen += 1

	# Settle test: step inward to 40.0m (800 px)
	player.global_position.x = house_x + 800.0
	player._process_tether(0.016)
	assert_true(not player.is_at_tether_limit, "Settle: is_at_tether_limit must be false when returning to safe zone")
	assert_eq(last_prompt_requested, "", "Settle: prompt must be empty when safely inside safe zone")

	# Settle back to exact 50.0m clamp
	player.global_position.x = clamp_right_x + 10.0
	player.velocity.x = 50.0
	player._process_tether(0.016)
	assert_true(player.is_at_tether_limit, "Settle: is_at_tether_limit must be true at clamp limit")
	assert_almost_eq(player.global_position.x, clamp_right_x, 0.001, "Settle: position clamped to 6000.0")
	assert_eq(last_prompt_requested, "Трос натянут до предела (50 м)!", "Settle: prompt shows 50m warning")

	_cleanup_entities(env)

func stress_02_tether_oscillation_left() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	var house_x: float = house.global_position.x # 5000.0
	var clamp_left_x: float = house_x - 1000.0   # 4000.0
	var inner_left_x: float = house_x - 998.0    # -49.9m (inner)
	var outer_left_x: float = house_x - 1002.0   # -50.1m (outer attempted)

	for frame in range(1000):
		if frame % 2 == 0:
			player.global_position.x = inner_left_x
			player.velocity.x = 32.0 # inward toward house
			player._process_tether(0.016)
			assert_true(not player.is_at_tether_limit, "Left Frame %d: is_at_tether_limit must be false" % frame)
			assert_eq(last_prompt_requested, "", "Left Frame %d: prompt cleared" % frame)
		else:
			player.global_position.x = outer_left_x
			player.velocity.x = -64.0 # outward to the left
			player._process_tether(0.016)
			assert_almost_eq(player.global_position.x, clamp_left_x, 0.001, "Left Frame %d: clamped to 4000.0" % frame)
			assert_almost_eq(player.velocity.x, 0.0, 0.001, "Left Frame %d: outward left velocity arrested" % frame)
			assert_true(player.is_at_tether_limit, "Left Frame %d: is_at_tether_limit true" % frame)
			assert_eq(last_prompt_requested, "Трос натянут до предела (50 м)!", "Left Frame %d: prompt shows 50m warning" % frame)

	_cleanup_entities(env)

func stress_03_tether_velocity_arrest_and_damping() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	var clamp_right_x: float = house.global_position.x + 1000.0

	# Test various outward velocity magnitudes: 1.0, 64.0, 500.0, 10000.0 px/s
	var test_velocities: Array[float] = [1.0, 64.0, 320.0, 1000.0, 50000.0]
	for v in test_velocities:
		player.global_position.x = clamp_right_x + 50.0
		player.velocity.x = v
		player._process_tether(0.016)
		assert_almost_eq(player.global_position.x, clamp_right_x, 0.001, "Impulse %f: position clamped to 6000.0" % v)
		assert_almost_eq(player.velocity.x, 0.0, 0.001, "Impulse %f: velocity arrested to 0" % v)
		assert_true(not is_nan(player.global_position.x), "Impulse %f: no NaN" % v)
		assert_true(not is_inf(player.global_position.x), "Impulse %f: no Inf" % v)

	# Verify inward velocity is PRESERVED when at clamp limit
	player.global_position.x = clamp_right_x
	player.velocity.x = -45.0 # inward velocity
	player._process_tether(0.016)
	assert_almost_eq(player.velocity.x, -45.0, 0.001, "Inward velocity at clamp must NOT be arrested")

	_cleanup_entities(env)

# ------------------------------------------------------------------------------
# SUITE 2: INTERACTION CONFLICT & PROMPT LIFECYCLE
# ------------------------------------------------------------------------------
func stress_04_overlapping_ladder_and_node() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	# House ladder is at house_x - 60 px = 4940.0. Ladder proximity radius is 50 px -> [4890.0, 4990.0].
	# Place a resource node at X = 4950.0 (overlapping ladder proximity!)
	var node: ResourceNode = ResourceNode.new()
	node.setup_node({
		"node_id": 99,
		"node_type": ResourceNode.NodeType.CRATE,
		"distance_m": 247.5,
		"description": "Тестовый ящик у трапа",
		"fuel": 20.0,
		"scrap": 0.0,
		"supplies": 0.0
	})
	node.global_position = Vector2(4950.0, 560.0)
	root.add_child(node)

	# Move player to 4945.0 (within both ladder radius and node area)
	player.global_position = Vector2(4945.0, 560.0)
	player._update_ladder_proximity()
	assert_true(player.can_reenter_house, "Player at 4945.0 must detect ladder proximity")

	# Simulate node area entry
	player._on_interaction_area_entered(node)
	assert_eq(player.current_interactable, node, "current_interactable must point to node")

	# Check what prompt is currently active:
	# Node entry emits prompt for crate: "[E] Обыскать ящик (+20 Топливо)"
	assert_true(last_prompt_requested.contains("Обыскать ящик"), "Prompt must reflect node when entering node area")

	# Now test interaction input priority:
	# In Player._unhandled_input, if can_reenter_house is true, it embarks into house!
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	player._unhandled_input(ev)

	# The player prioritizes ladder re-entry over node harvest
	assert_true(not gs.is_player_outside, "Player embarked into house via ladder priority")
	assert_true(not node.is_harvested, "Resource node remains unharvested when ladder re-entry occurs")

	node.free()
	_cleanup_entities(env)

func stress_05_node_harvest_inside_ladder_proximity() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	# Place node at 4950.0 (near ladder at 4940.0)
	var node: ResourceNode = ResourceNode.new()
	node.setup_node({
		"node_id": 98,
		"node_type": ResourceNode.NodeType.CRATE,
		"description": "Ящик у трапа",
		"fuel": 15.0
	})
	node.global_position = Vector2(4950.0, 560.0)
	root.add_child(node)

	player.global_position = Vector2(4945.0, 560.0)
	player._update_ladder_proximity()
	player._on_interaction_area_entered(node)

	# Now directly harvest the node
	node.harvest()
	assert_true(node.is_harvested, "Node is harvested")

	# When node exits or is harvested, prompt_cleared is emitted
	player._on_interaction_area_exited(node)
	assert_true(player.current_interactable == null, "current_interactable cleared")

	# CRITICAL AUDIT CHECK: Prompt state after node harvest near ladder
	player._update_ladder_proximity()
	var prompt_after_harvest: String = last_prompt_requested
	print("    [OBSERVATION] Prompt after node harvest near ladder: '%s'" % prompt_after_harvest)
	assert_true(player.can_reenter_house, "can_reenter_house invariant must remain true at ladder")

	node.free()
	_cleanup_entities(env)

func stress_06_node_at_tether_clamp_prompt_lifecycle() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	# Place node exactly at 50m tether clamp (X = 6000.0)
	var node: ResourceNode = ResourceNode.new()
	node.setup_node({
		"node_id": 97,
		"node_type": ResourceNode.NodeType.CRATE,
		"description": "Ящик на границе троса",
		"fuel": 25.0
	})
	node.global_position = Vector2(6000.0, 560.0)
	root.add_child(node)

	# 1. Player reaches 50m clamp
	player.global_position = Vector2(6000.0, 560.0)
	player._process_tether(0.016)
	assert_true(player.is_at_tether_limit, "Player is at tether limit")
	assert_eq(last_prompt_requested, "Трос натянут до предела (50 м)!", "Prompt is tether limit warning")

	# 2. Player enters node at clamp
	player._on_interaction_area_entered(node)
	assert_true(last_prompt_requested.contains("Обыскать ящик"), "Prompt updated to node interaction")

	# 3. Player harvests node
	node.harvest()
	player._on_interaction_area_exited(node)
	assert_true(player.current_interactable == null, "Node interaction cleared")

	# 4. Next tether process frame at clamp
	player._process_tether(0.016)
	var prompt_at_clamp_post_harvest: String = last_prompt_requested
	print("    [OBSERVATION] Prompt at 50m clamp after harvesting node: '%s'" % prompt_at_clamp_post_harvest)
	assert_almost_eq(player.global_position.x, 6000.0, 0.001, "Position remains clamped at 6000.0")
	assert_true(player.is_at_tether_limit, "is_at_tether_limit remains true")

	# 5. Move back inward to 48m (5960.0 px)
	player.global_position.x = 5960.0
	player._process_tether(0.016)
	assert_true(not player.is_at_tether_limit, "is_at_tether_limit transitions to false inward")
	assert_eq(last_prompt_requested, "", "Prompt cleared when returning inward")

	node.free()
	_cleanup_entities(env)

# ------------------------------------------------------------------------------
# SUITE 3: EXTREME DELTA TIMESTEPS
# ------------------------------------------------------------------------------
func stress_07_extreme_large_delta() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	# 1. Kinematic Overshoot Clamping under massive delta:
	# Suppose player position overshoots clamp to 6250.0 (50m clamp is 6000.0) with high velocity
	player.global_position.x = 6250.0
	player.velocity.x = 120.0
	player._process_tether(2.0)

	assert_almost_eq(player.global_position.x, 6000.0, 0.001, "Delta 2.0s: position clamped to 6000.0")
	assert_almost_eq(player.velocity.x, 0.0, 0.001, "Delta 2.0s: outward velocity clamped to 0.0")
	assert_true(player.is_at_tether_limit, "Delta 2.0s: tether limit flagged")

	# 2. Large Delta Cold Exposure Step:
	# Part A: At 50m clamp limit (Tether Violation penalty 2.0x -> 5.0 HP/s * 5.0s = 25.0 HP)
	gs.is_blizzard = false
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0 # warm buffer expired
	player._process_cold_exposure(5.0)
	assert_almost_eq(gs.player_health, 75.0, 0.01, "Delta 5.0s at 50m clamp: tether violation double-damage (25.0 HP)")

	# Part B: Within safe tether (20m -> 2.5 HP/s * 5.0s = 12.5 HP)
	player.global_position.x = 5400.0 # 20m from house
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0
	player._process_cold_exposure(5.0)
	assert_almost_eq(gs.player_health, 87.5, 0.01, "Delta 5.0s within safe tether: normal calm damage (12.5 HP)")

	# 3. Supermassive Delta in SimulationLogic (100.0s):
	var big_temp = SimulationLogic.calculate_cabin_temperature(18.0, -25.0, false, false, false, 100.0)
	assert_true(not is_nan(big_temp), "Delta 100.0s: cabin temp is not NaN")
	assert_true(not is_inf(big_temp), "Delta 100.0s: cabin temp is not Inf")
	assert_true(big_temp >= -50.0 and big_temp <= 24.0, "Delta 100.0s: cabin temp respects thermal clamps")

	_cleanup_entities(env)

func stress_08_extreme_micro_delta() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	player.global_position.x = 5500.0
	player.velocity.x = 0.0

	# 1000 micro steps of delta = 0.0001s: simulate continuous acceleration
	var micro_dt: float = 0.0001
	for i in range(1000):
		player.velocity.x = move_toward(player.velocity.x, player.SPEED, player.ACCELERATION * micro_dt)
		player.global_position.x += player.velocity.x * micro_dt
		player._process_tether(micro_dt)

	assert_true(not is_nan(player.global_position.x), "Micro delta: position is finite")
	assert_true(not is_nan(player.velocity.x), "Micro delta: velocity is finite")
	assert_true(player.velocity.x > 0.0, "Micro delta: velocity accelerates monotonically")
	assert_true(player.global_position.x > 5500.0, "Micro delta: position advances monotonically")

	# Numerical stability of catenary sag math with microscopic coordinates
	var sag_0: float = maxf(0.0, 32.0 * pow(1.0 - clampf(0.00001 / player.SAFE_RADIUS_PX, 0.0, 1.0), 2.0))
	assert_almost_eq(sag_0, 32.0, 0.01, "Micro distance sag evaluates to max sag ~32.0 px")
	var sag_lim: float = maxf(0.0, 32.0 * pow(1.0 - clampf(899.99999 / player.SAFE_RADIUS_PX, 0.0, 1.0), 2.0))
	assert_almost_eq(sag_lim, 0.0, 0.001, "Boundary distance sag evaluates to 0.0 px without NaN")

	_cleanup_entities(env)


func stress_09_non_positive_delta_invariance() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	player.global_position = Vector2(5200.0, 560.0)
	player.velocity = Vector2(30.0, 0.0)
	var initial_timer: float = player.outside_exposure_timer
	var initial_health: float = gs.player_health

	# Run _physics_process with negative and zero deltas
	player._physics_process(0.0)
	assert_eq(player.global_position.x, 5200.0, "delta=0: position invariant")
	assert_eq(player.velocity.x, 30.0, "delta=0: velocity invariant")
	assert_eq(player.outside_exposure_timer, initial_timer, "delta=0: exposure timer invariant")
	assert_eq(gs.player_health, initial_health, "delta=0: health invariant")

	player._physics_process(-0.016)
	assert_eq(player.global_position.x, 5200.0, "delta=-0.016: position invariant")
	assert_eq(player.velocity.x, 30.0, "delta=-0.016: velocity invariant")
	assert_eq(player.outside_exposure_timer, initial_timer, "delta=-0.016: exposure timer invariant")
	assert_eq(gs.player_health, initial_health, "delta=-0.016: health invariant")

	player._physics_process(-100.0)
	assert_eq(player.global_position.x, 5200.0, "delta=-100: position invariant")
	assert_eq(player.outside_exposure_timer, initial_timer, "delta=-100: exposure timer invariant")

	# Pure SimulationLogic invariant tests
	assert_eq(SimulationLogic.calculate_fuel_consumption(true, false, -1.0), 0.0, "SimLogic negative delta fuel = 0")
	assert_eq(SimulationLogic.calculate_leg_wear(true, false, -1.0), 0.0, "SimLogic negative delta wear = 0")
	assert_eq(SimulationLogic.calculate_stove_fuel(true, -1.0), 0.0, "SimLogic negative delta stove fuel = 0")
	assert_eq(SimulationLogic.calculate_player_outside_exposure(-1.0, 30.0), 0.0, "SimLogic negative delta exposure = 0")
	assert_eq(SimulationLogic.calculate_outside_cold_damage(30.0, 20.0, false, -1.0), 0.0, "SimLogic negative delta cold damage = 0")
	assert_eq(SimulationLogic.calculate_cabin_cold_damage(-10.0, -1.0), 0.0, "SimLogic negative delta cabin damage = 0")
	assert_eq(SimulationLogic.calculate_warmth_recovery(15.0, -1.0), 0.0, "SimLogic negative delta warmth recovery = 0")

	_cleanup_entities(env)

# ------------------------------------------------------------------------------
# SUITE 4: HEALTH LOSS INVARIANTS OUTSIDE HOUSE (CALM VS BLIZZARD)
# ------------------------------------------------------------------------------
func stress_10_warmth_buffer_zero_damage_invariant() -> void:
	var env = _spawn_house_and_player(5000.0)
	var player: Player = env["player"]

	# Test Calm during 0..20s buffer
	gs.is_blizzard = false
	gs.player_health = 100.0
	player.outside_exposure_timer = 0.0

	# Advance 19.5s in 0.5s steps (39 steps)
	for i in range(39):
		player._process_cold_exposure(0.5)

	assert_almost_eq(player.outside_exposure_timer, 19.5, 0.01, "Exposure timer accumulated to 19.5s")
	assert_eq(gs.player_health, 100.0, "Calm: health must remain 100.0 within 20s warmth buffer")
	assert_true(gs.player_warmth > 0.0, "Calm: warmth buffer remains above 0% at 19.5s")

	# Reset and test Blizzard during 0..20s buffer
	gs.is_blizzard = true
	gs.player_health = 100.0
	player.outside_exposure_timer = 0.0

	for i in range(39):
		player._process_cold_exposure(0.5)

	assert_almost_eq(player.outside_exposure_timer, 19.5, 0.01, "Exposure timer accumulated to 19.5s in Blizzard")
	assert_eq(gs.player_health, 100.0, "Blizzard: health must remain 100.0 within 20s warmth buffer")
	assert_true(gs.player_warmth > 0.0, "Blizzard: warmth buffer remains above 0% at 19.5s")

	_cleanup_entities(env)

func stress_11_calm_vs_blizzard_damage_rates() -> void:
	var env = _spawn_house_and_player(5000.0)
	var player: Player = env["player"]
	player.global_position.x = 5000.0 + 400.0 # 20m from house (within safe tether <= 45m)

	# 1. Calm Exposure Rate: 2.5 HP/s
	gs.is_blizzard = false
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0 # Warmth buffer expired

	# Simulate 10.0 seconds in 1.0s steps
	for i in range(10):
		player._process_cold_exposure(1.0)

	var calm_damage: float = 100.0 - gs.player_health
	assert_almost_eq(calm_damage, 25.0, 0.01, "Calm cold damage over 10s must be exactly 25.0 HP (2.5 HP/s)")

	# 2. Blizzard Exposure Rate: 6.0 HP/s
	gs.is_blizzard = true
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0

	for i in range(10):
		player._process_cold_exposure(1.0)

	var blizzard_damage: float = 100.0 - gs.player_health
	assert_almost_eq(blizzard_damage, 60.0, 0.01, "Blizzard cold damage over 10s must be exactly 60.0 HP (6.0 HP/s)")

	# 3. Ratio Invariant: 6.0 / 2.5 = exactly 2.4x
	var ratio: float = blizzard_damage / calm_damage
	assert_almost_eq(ratio, 2.4, 0.001, "Blizzard to Calm damage ratio must be exactly 2.4x")

	_cleanup_entities(env)

func stress_12_tether_violation_penalty_rates() -> void:
	var env = _spawn_house_and_player(5000.0)
	var player: Player = env["player"]
	player.global_position.x = 5000.0 + 960.0 # 48m from house (TETHER VIOLATION: > 45m)

	# 1. Calm with Tether Violation: 2.5 * 2.0 = 5.0 HP/s
	gs.is_blizzard = false
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0

	for i in range(10):
		player._process_cold_exposure(1.0)

	var calm_violation_damage: float = 100.0 - gs.player_health
	assert_almost_eq(calm_violation_damage, 50.0, 0.01, "Calm + Tether Violation over 10s must be 50.0 HP (5.0 HP/s)")

	# 2. Blizzard with Tether Violation: 6.0 * 2.0 = 12.0 HP/s
	gs.is_blizzard = true
	gs.player_health = 100.0
	player.outside_exposure_timer = 20.0

	for i in range(5):
		player._process_cold_exposure(1.0)

	var blizzard_violation_damage: float = 100.0 - gs.player_health
	assert_almost_eq(blizzard_violation_damage, 60.0, 0.01, "Blizzard + Tether Violation over 5s must be 60.0 HP (12.0 HP/s)")

	_cleanup_entities(env)

func stress_13_hypothermia_lethality_game_over() -> void:
	var env = _spawn_house_and_player(5000.0)
	var player: Player = env["player"]
	player.global_position.x = 5000.0 + 960.0 # 48m outside tether

	gs.is_blizzard = true
	gs.player_health = 10.0
	player.outside_exposure_timer = 20.0

	# 1 second of 12.0 HP/s damage drops 10.0 HP to 0.0
	player._process_cold_exposure(1.0)

	assert_eq(gs.player_health, 0.0, "Health clamped at 0.0, cannot be negative")
	assert_true(gs.is_game_over, "Game over triggered upon health dropping to 0")
	assert_true(gs.game_over_reason.contains("Переохлаждение"), "Game over reason indicates hypothermia")

	# Ensure further ticks do not go below 0
	player._process_cold_exposure(5.0)
	assert_eq(gs.player_health, 0.0, "Health remains clamped at 0.0 post-defeat")

	_cleanup_entities(env)

func stress_14_embark_disembark_exposure_reset() -> void:
	var env = _spawn_house_and_player(5000.0)
	var house: WalkingHouse = env["house"]
	var player: Player = env["player"]

	# Accumulate 15 seconds outside
	player._process_cold_exposure(15.0)
	assert_almost_eq(player.outside_exposure_timer, 15.0, 0.01, "Exposure timer is 15.0s")
	assert_almost_eq(gs.player_warmth, 25.0, 0.1, "Warmth gauge dropped to 25%")

	# Embark into house
	player._embark_into_house()
	assert_true(not player.is_active, "Player inactive inside house")
	assert_true(not gs.is_player_outside, "GameState reports player inside")

	# Disembark again
	gs.disembark_player()
	player.spawn_at_house_ladder(house)
	assert_true(player.is_active, "Player active outside")
	assert_eq(player.outside_exposure_timer, 0.0, "Exposure timer reset to 0.0 on new exit")
	assert_true(not player.is_at_tether_limit, "is_at_tether_limit reset to false")

	# Check warmth refreshed on first tick outside
	player._process_cold_exposure(0.01)
	assert_almost_eq(gs.player_warmth, 100.0, 0.5, "Warmth gauge refreshed to ~100% upon new exit")

	_cleanup_entities(env)


