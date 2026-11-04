# tests/suites/test_m3_challenger_adversarial.gd
# Empirical Challenger Adversarial Stress Suite for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD)
# Focus: 30 Resource Nodes in World, 5000m Route Solvency, Harvesting Mechanics & Deadlock Accuracy
extends SceneTree

const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")
const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")
const SoundManagerScript = preload("res://scripts/autoload/SoundManager.gd")
const WORLD_SCENE_PATH: String = "res://scenes/world/World.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/Player.tscn"

var total_assertions: int = 0
var failed_assertions: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var current_test: String = ""
var failure_log: Array[String] = []

func _init() -> void:
	_run_all_tests.call_deferred()

func _run_all_tests() -> void:
	await process_frame
	
	print("\n" + "=".repeat(80))
	print("  M3 EMPIRICAL CHALLENGER ADVERSARIAL STRESS SUITE (CHALLENGER 2)")
	print("  Verification of 30 Nodes, 5000m Route Solvency, Key [E] & Deadlock Query")
	print("=".repeat(80) + "\n")
	
	# Setup singletons if missing
	_ensure_singletons()
	
	var tests: Array[Callable] = [
		Callable(self, "test_01_world_scene_30_resource_nodes_integrity"),
		Callable(self, "test_02_total_route_solvency_and_balance_config_sums"),
		Callable(self, "test_03_route_5000m_dynamic_solvency_simulation"),
		Callable(self, "test_04_harvesting_interaction_key_e_and_double_loot_prevention"),
		Callable(self, "test_05_deadlock_reachable_resources_query_accuracy"),
		Callable(self, "test_06_deadlock_detection_integration_with_zero_false_positives"),
		Callable(self, "test_07_ground_alignment_and_camera_boundary_invariants")
	]
	
	for t in tests:
		current_test = t.get_method()
		print("\n[CHALLENGE RUN] %s" % current_test)
		var test_failed_before: int = failed_assertions
		t.call()
		if failed_assertions == test_failed_before:
			passed_tests += 1
			print("  -> PASS")
		else:
			failed_tests += 1
			printerr("  -> FAIL (Adversarial vulnerability detected)")
			
	print("\n" + "=".repeat(80))
	print("  M3 CHALLENGER RESULTS: %d PASSED, %d FAILED (Total Assertions: %d)" % [passed_tests, failed_tests, total_assertions])
	print("=".repeat(80) + "\n")
	
	if failed_tests > 0:
		printerr("Failure details:")
		for err in failure_log:
			printerr(" - %s" % err)
		quit(1)
	else:
		quit(0)

func chk(condition: bool, msg: String) -> bool:
	total_assertions += 1
	if not condition:
		failed_assertions += 1
		var err_str: String = "[FAIL in %s] %s" % [current_test, msg]
		failure_log.append(err_str)
		printerr("    " + err_str)
		return false
	return true

func chk_almost_eq(actual: float, expected: float, tol: float = 0.001, msg: String = "") -> bool:
	total_assertions += 1
	if absf(actual - expected) > tol:
		failed_assertions += 1
		var err_str: String = "[FAIL in %s] Expected ~%f (+/-%f), got %f. %s" % [current_test, expected, tol, actual, msg]
		failure_log.append(err_str)
		printerr("    " + err_str)
		return false
	return true

func _ensure_singletons() -> void:
	if not root.has_node("EventBus"):
		var bus = EventBusScript.new()
		bus.name = "EventBus"
		root.add_child(bus)
		
	if not root.has_node("GameState"):
		var gs = GameStateScript.new()
		gs.name = "GameState"
		root.add_child(gs)
		
	if not root.has_node("SoundManager"):
		var sm = SoundManagerScript.new()
		sm.name = "SoundManager"
		root.add_child(sm)

# ------------------------------------------------------------------------------
# TEST 1: World Scene Instantiation & Exact 30 Resource Nodes Verification
# ------------------------------------------------------------------------------
func test_01_world_scene_30_resource_nodes_integrity() -> void:
	var world_scene: PackedScene = load(WORLD_SCENE_PATH)
	chk(world_scene != null, "World.tscn must load cleanly without parse errors")
	if world_scene == null:
		return
		
	var world = world_scene.instantiate()
	root.add_child(world)
	
	var resource_nodes_container: Node2D = world.get_node_or_null("ResourceNodes")
	chk(resource_nodes_container != null, "World scene must contain 'ResourceNodes' container node")
	var child_count: int = resource_nodes_container.get_child_count()
	chk(child_count == 30, "World/ResourceNodes must contain exactly 30 child nodes, found: %d" % child_count)
	
	var prev_x: float = -1.0
	var biome_node_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	
	for i in range(child_count):
		var node = resource_nodes_container.get_child(i)
		chk(node is ResourceNode, "Child %d must inherit from ResourceNode" % i)
		
		var node_id: int = node.node_id
		chk(node_id == (i + 1), "Node %d must have sequential node_id %d, got %d" % [i, i + 1, node_id])
		
		# Check position
		var px: float = node.position.x
		var py: float = node.position.y
		chk(px > prev_x, "Node %d world_x (%f) must be strictly greater than previous (%f)" % [node_id, px, prev_x])
		prev_x = px
		
		# Top of ground is Y = 560.0. Node position.y must be on ground plane
		chk_almost_eq(py, 560.0, 0.1, "Node %d position.y must align with ground elevation Y=560.0" % node_id)
		
		# Metric distance match
		var dist_m: float = node.distance_m
		chk_almost_eq(px, dist_m * 20.0, 0.1, "Node %d position.x must equal distance_m * 20 px/m" % node_id)
		chk(dist_m >= 0.0 and dist_m <= 5000.0, "Node %d distance (%f m) must be within 0..5000m" % [node_id, dist_m])
		
		# Biome index match
		var biome_idx: int = int(dist_m / 1000.0)
		if biome_idx > 4:
			biome_idx = 4
		biome_node_counts[biome_idx] = biome_node_counts.get(biome_idx, 0) + 1
		
		# Group registration
		chk(node.is_in_group("resource_nodes"), "Node %d must be in group 'resource_nodes'" % node_id)
		chk(node.is_in_group("poi"), "Node %d must be in group 'poi'" % node_id)
		
		# Collision properties
		chk(node.collision_layer == 8, "Node %d collision_layer must be 8 (Interactables)" % node_id)
		chk(node.collision_mask == 4, "Node %d collision_mask must be 4 (Player)" % node_id)
		var col_shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D")
		chk(col_shape != null and col_shape.shape is CircleShape2D, "Node %d has CircleShape2D" % node_id)
		if col_shape != null and col_shape.shape is CircleShape2D:
			chk_almost_eq(col_shape.shape.radius, 50.0, 0.1, "Node %d interaction radius is 50.0 px (2.5m)" % node_id)
			
		# Russian prompt verification
		var prompt: String = node.get_interaction_prompt()
		chk(prompt.begins_with("[E]"), "Node %d prompt must begin with '[E]', got: '%s'" % [node_id, prompt])
		chk(not prompt.to_lower().contains("crate") and not prompt.to_lower().contains("scrap"), 
			"Node %d prompt must be localized in Russian without raw English keys: '%s'" % [node_id, prompt])
			
	# Verify all 5 biomes have distributed resource nodes
	for b in range(5):
		chk(biome_node_counts[b] >= 4, "Biome %d must have at least 4 nodes, found %d" % [b, biome_node_counts[b]])
		
	world.free()

# ------------------------------------------------------------------------------
# TEST 2: Strict Total Route Solvency vs BalanceConfig (760 Fuel, 55 Scrap, 22 Supplies)
# ------------------------------------------------------------------------------
func test_02_total_route_solvency_and_balance_config_sums() -> void:
	var nodes: Array[Dictionary] = ResourceNode.DEFAULT_NODES
	chk(nodes.size() == 30, "DEFAULT_NODES array must contain exactly 30 entries")
	
	var total_fuel: float = 0.0
	var total_scrap: float = 0.0
	var total_supplies: float = 0.0
	
	for n in nodes:
		total_fuel += n.get("fuel", 0.0)
		total_scrap += n.get("scrap", 0.0)
		total_supplies += n.get("supplies", 0.0)
		chk(n.get("fuel", 0.0) >= 0.0, "Node %d fuel yield must be non-negative" % n.get("node_id", 0))
		chk(n.get("scrap", 0.0) >= 0.0, "Node %d scrap yield must be non-negative" % n.get("node_id", 0))
		chk(n.get("supplies", 0.0) >= 0.0, "Node %d supplies yield must be non-negative" % n.get("node_id", 0))
		
	chk_almost_eq(total_fuel, 760.0, 0.001, "Total route placed Fuel must strictly equal 760.0")
	chk_almost_eq(total_scrap, 55.0, 0.001, "Total route placed Scrap must strictly equal 55.0")
	chk_almost_eq(total_supplies, 22.0, 0.001, "Total route placed Supplies must strictly equal 22.0")
	
	# Verify match with BalanceConfig POI totals
	var poi_totals: Dictionary = BalanceConfig.get_total_poi_resources()
	chk_almost_eq(poi_totals.fuel, total_fuel, 0.001, "BalanceConfig.get_total_poi_resources().fuel must match DEFAULT_NODES")
	chk_almost_eq(float(poi_totals.scrap), total_scrap, 0.001, "BalanceConfig.get_total_poi_resources().scrap must match DEFAULT_NODES")
	chk_almost_eq(float(poi_totals.supplies), total_supplies, 0.001, "BalanceConfig.get_total_poi_resources().supplies must match DEFAULT_NODES")
	
	# Verify Grand Totals including starting baseline reserves
	var grand_totals: Dictionary = BalanceConfig.get_grand_total_resources()
	chk_almost_eq(grand_totals.fuel, 760.0 + BalanceConfig.STARTING_RESERVE_FUEL, 0.001, "Grand total fuel must be 820.0")
	chk_almost_eq(float(grand_totals.scrap), 55.0 + BalanceConfig.STARTING_RESERVE_SCRAP, 0.001, "Grand total scrap must be 60")
	chk_almost_eq(float(grand_totals.supplies), 22.0 + BalanceConfig.STARTING_RESERVE_SUPPLIES, 0.001, "Grand total supplies must be 25")

# ------------------------------------------------------------------------------
# TEST 3: Route 5000m Dynamic Solvency Simulation (Empirical Oracle)
# ------------------------------------------------------------------------------
func test_03_route_5000m_dynamic_solvency_simulation() -> void:
	var nodes: Array[Dictionary] = ResourceNode.DEFAULT_NODES.duplicate(true)
	
	# Baseline Run parameters
	var current_distance_m: float = 0.0
	var fuel: float = BalanceConfig.STARTING_RESERVE_FUEL # 60.0 starting fuel
	var scrap: float = float(BalanceConfig.STARTING_RESERVE_SCRAP) # 5 scrap
	var supplies: float = float(BalanceConfig.STARTING_RESERVE_SUPPLIES) # 3 supplies
	var leg_durability: float = 100.0
	
	var total_fuel_spent: float = 0.0
	var total_scrap_spent: float = 0.0
	var min_fuel_observed: float = fuel
	var min_durability_observed: float = leg_durability
	
	# Biome wear rates
	var biome_wear_mults: Array[float] = [1.0, 1.0, 1.5, 1.25, 1.0]
	
	for i in range(nodes.size()):
		var n: Dictionary = nodes[i]
		var next_dist: float = n["distance_m"]
		var segment_m: float = next_dist - current_distance_m
		chk(segment_m >= 0.0, "Segment distance must be non-negative")
		
		# Determine active biome for this segment
		var b_idx: int = clampi(int(current_distance_m / 1000.0), 0, 4)
		var wear_mult: float = biome_wear_mults[b_idx]
		
		# Drive to node
		var fuel_burned: float = segment_m * (BalanceConfig.WALK_FUEL_RATE / BalanceConfig.BASE_FORWARD_SPEED) # 0.10 fuel/m
		var wear_incurred: float = segment_m * BalanceConfig.BASE_LEG_WEAR_PER_METER * wear_mult
		
		fuel -= fuel_burned
		total_fuel_spent += fuel_burned
		leg_durability -= wear_incurred
		
		if fuel < min_fuel_observed:
			min_fuel_observed = fuel
		if leg_durability < min_durability_observed:
			min_durability_observed = leg_durability
			
		# Check: player MUST NOT run out of fuel before reaching this node!
		chk(fuel > 0.0, "Fuel must remain positive while en-route to node %d at %fm (remaining: %f)" % [n["node_id"], next_dist, fuel])
		chk(leg_durability > 0.0, "Leg durability must not drop to 0 before node %d at %fm (durability: %f)" % [n["node_id"], next_dist, leg_durability])
		
		# Harvest node
		fuel += n["fuel"]
		scrap += n["scrap"]
		supplies += n["supplies"]
		
		# Repair legs if durability dropped below 50%
		if leg_durability < 50.0 and scrap >= 1.0:
			var repair_res: Dictionary = SimulationLogic.apply_repair(leg_durability, scrap)
			var scrap_used: float = repair_res["scrap_spent"]
			leg_durability = repair_res["new_durability"]
			scrap -= scrap_used
			total_scrap_spent += scrap_used
			
		current_distance_m = next_dist
		
	# Drive final segment from last node (4950m) to station (5000m)
	var final_segment_m: float = 5000.0 - current_distance_m # 50m
	var final_fuel_burned: float = final_segment_m * 0.10
	var final_wear: float = final_segment_m * BalanceConfig.BASE_LEG_WEAR_PER_METER * 1.0
	fuel -= final_fuel_burned
	total_fuel_spent += final_fuel_burned
	leg_durability -= final_wear
	
	# Verify solvency at the Station Gate:
	chk(fuel >= 150.0, "Final fuel at station gate must be >= 150.0 (actual: %f)" % fuel)
	chk(scrap >= 30.0, "Final scrap at station gate must be >= 30.0 (actual: %f)" % scrap)
	chk(leg_durability >= 20.0, "Final leg durability must be positive (actual: %f)" % leg_durability)
	chk(min_fuel_observed >= 20.0, "Fuel never dropped below safety threshold (min: %f)" % min_fuel_observed)

# ------------------------------------------------------------------------------
# TEST 4: Empirical Harvesting Interaction (Key E), SFX, State & Double-Loot Prevention
# ------------------------------------------------------------------------------
func test_04_harvesting_interaction_key_e_and_double_loot_prevention() -> void:
	var PlayerClass = load(PLAYER_SCENE_PATH)
	var gs: Node = root.get_node("GameState")
	var bus: Node = root.get_node("EventBus")
	var sm: Node = root.get_node("SoundManager")
	
	gs.reset_state()
	gs.fuel = 50.0
	gs.scrap = 5
	gs.supplies = 2
	
	# Create ResourceNode
	var node = ResourceNode.new()
	root.add_child(node)
	node.setup_node({
		"node_id": 1,
		"node_type": ResourceNode.NodeType.CRATE,
		"distance_m": 200.0,
		"fuel": 30.0,
		"scrap": 4.0,
		"supplies": 2.0,
		"description": "Тестовый ящик"
	})
	node.position = Vector2(4000.0, 560.0)
	node._ready()
	
	# Instantiate Player outside
	var player = PlayerClass.instantiate()
	root.add_child(player)
	player.set_player_active(true)
	player.global_position = Vector2(4000.0, 560.0) # Right at node
	
	# Simulate entering interaction area
	node._on_body_entered(player)
	chk(node.is_player_nearby, "Node detects player is nearby")
	chk(node.prompt_pivot != null and node.prompt_pivot.visible, "Context prompt is visible when player is near")
	
	# Verify prompt text
	var prompt_str: String = node.get_interaction_prompt()
	chk(prompt_str.contains("+30 Топливо"), "Prompt contains '+30 Топливо'")
	chk(prompt_str.contains("+4 Металлолом"), "Prompt contains '+4 Металлолом'")
	chk(prompt_str.contains("+2 Припасы"), "Prompt contains '+2 Припасы'")
	
	# Simulate Key [E] Action
	var key_event := InputEventAction.new()
	key_event.action = "interact"
	key_event.pressed = true
	
	# First harvest via input
	node._unhandled_input(key_event)
	
	# Verify State changes
	chk(node.is_harvested, "Node is marked harvested after Key [E]")
	chk(node.prompt_pivot != null and not node.prompt_pivot.visible, "Prompt is hidden after harvest")
	chk_almost_eq(gs.fuel, 80.0, 0.001, "GameState fuel increased from 50 to 80")
	chk_almost_eq(float(gs.scrap), 9.0, 0.001, "GameState scrap increased from 5 to 9")
	chk_almost_eq(float(gs.supplies), 4.0, 0.001, "GameState supplies increased from 2 to 4")
	
	# ADVERSARIAL ATTACK: DOUBLE-LOOTING SPAM
	# Spam Key [E] 20 times in rapid succession
	for i in range(20):
		node._unhandled_input(key_event)
		var second_yield: Dictionary = node.harvest()
		chk(second_yield["fuel"] == 0.0, "Spam harvest yield fuel must strictly be 0.0")
		chk(second_yield["scrap"] == 0.0, "Spam harvest yield scrap must strictly be 0.0")
		chk(second_yield["supplies"] == 0.0, "Spam harvest yield supplies must strictly be 0.0")
		
	# GameState must remain completely unchanged!
	chk_almost_eq(gs.fuel, 80.0, 0.001, "GameState fuel must NOT increase on double-harvest")
	chk_almost_eq(float(gs.scrap), 9.0, 0.001, "GameState scrap must NOT increase on double-harvest")
	chk_almost_eq(float(gs.supplies), 4.0, 0.001, "GameState supplies must NOT increase on double-harvest")
	
	# Test leaving and re-entering harvested area
	node._on_body_exited(player)
	chk(not node.is_player_nearby, "Player exited area")
	node._on_body_entered(player)
	chk(node.prompt_pivot != null and not node.prompt_pivot.visible, "Prompt remains hidden when re-entering harvested node")
	
	# Cleanup
	player.free()
	node.free()

# ------------------------------------------------------------------------------
# TEST 5: Deadlock Reachable Resources Query Accuracy & BVA Boundaries
# ------------------------------------------------------------------------------
func test_05_deadlock_reachable_resources_query_accuracy() -> void:
	# Create a clean node container
	var test_container := Node2D.new()
	test_container.name = "TestNodesContainer"
	root.add_child(test_container)
	
	# Setup test nodes at controlled distances around house at X = 20,000 px (1000m)
	# Safe radius is 45.0m (900 px)
	var house_x_px: float = 20000.0 # 1000.0m
	
	var node_specs: Array[Dictionary] = [
		{"id": 1, "offset_m": 0.0, "fuel": 40.0, "scrap": 3.0, "harvested": false},    # In radius (0m)
		{"id": 2, "offset_m": 44.9, "fuel": 30.0, "scrap": 2.0, "harvested": false},   # In radius (44.9m)
		{"id": 3, "offset_m": 45.0, "fuel": 50.0, "scrap": 1.0, "harvested": false},   # Exact boundary (45.0m)
		{"id": 4, "offset_m": 45.1, "fuel": 60.0, "scrap": 5.0, "harvested": false},   # Out of radius (45.1m) - FALSE POSITIVE TEST
		{"id": 5, "offset_m": -44.9, "fuel": 25.0, "scrap": 1.0, "harvested": false},  # In radius behind (-44.9m)
		{"id": 6, "offset_m": -45.1, "fuel": 70.0, "scrap": 4.0, "harvested": false},  # Out of radius behind (-45.1m) - FALSE POSITIVE TEST
		{"id": 7, "offset_m": 10.0, "fuel": 100.0, "scrap": 10.0, "harvested": true}   # In radius, but HARVESTED - FALSE POSITIVE TEST
	]
	
	var created_nodes: Array = []
	for spec in node_specs:
		var n = ResourceNode.new()
		n.setup_node({
			"node_id": spec["id"],
			"fuel": spec["fuel"],
			"scrap": spec["scrap"],
			"supplies": 0.0
		})
		n.is_harvested = spec["harvested"]
		n.global_position = Vector2(house_x_px + spec["offset_m"] * 20.0, 560.0)
		test_container.add_child(n)
		n._ready()
		created_nodes.append(n)
		
	# Execute query
	var totals: Dictionary = ResourceNode.query_reachable_resources(house_x_px, 45.0, self)
	
	# Expected included nodes: 1 (40F, 3S), 2 (30F, 2S), 3 (50F, 1S), 5 (25F, 1S)
	# Expected total fuel: 40 + 30 + 50 + 25 = 145.0
	# Expected total scrap: 3 + 2 + 1 + 1 = 7.0
	# Expected count: 4
	chk_almost_eq(totals["reachable_fuel"], 145.0, 0.001, 
		"query_reachable_resources accurately includes fuel from within 45m safe radius (got: %f)" % totals["reachable_fuel"])
	chk_almost_eq(totals["reachable_scrap"], 7.0, 0.001, 
		"query_reachable_resources accurately includes scrap from within 45m safe radius (got: %f)" % totals["reachable_scrap"])
	chk(totals["reachable_node_count"] == 4, 
		"query_reachable_resources accurately counts exactly 4 reachable nodes (got: %d)" % totals["reachable_node_count"])
		
	# Now dynamically harvest Node 2 (30F, 2S)
	created_nodes[1].is_harvested = true
	var updated_totals: Dictionary = ResourceNode.query_reachable_resources(house_x_px, 45.0, self)
	chk_almost_eq(updated_totals["reachable_fuel"], 115.0, 0.001, 
		"After harvesting node 2, reachable fuel drops from 145 to 115")
	chk_almost_eq(updated_totals["reachable_scrap"], 5.0, 0.001, 
		"After harvesting node 2, reachable scrap drops from 7 to 5")
	chk(updated_totals["reachable_node_count"] == 3, 
		"Reachable count drops to 3")
		
	test_container.free()

# ------------------------------------------------------------------------------
# TEST 6: Deadlock Detection Integration with Zero False Positives
# ------------------------------------------------------------------------------
func test_06_deadlock_detection_integration_with_zero_false_positives() -> void:
	# Case A: Mobile house (Fuel > 0, Durability > 0) -> NO DEADLOCK
	var dl_mobile: bool = SimulationLogic.check_deadlock_condition(
		10.0, 100.0, 0.0, 1.0, 0.0, 0.0, false
	)
	chk(not dl_mobile, "Mobile house must never be in deadlock")
	
	# Case B: Fuel = 0, but fuel is reachable within 45m -> NO DEADLOCK (ZERO FALSE POSITIVES)
	var dl_reachable_fuel: bool = SimulationLogic.check_deadlock_condition(
		0.0, 100.0, 0.0, 1.0, 30.0, 0.0, false
	)
	chk(not dl_reachable_fuel, "Zero fuel with reachable fuel cache must NOT trigger deadlock")
	
	# Case C: Legs broken (0%), Scrap = 0, but scrap is reachable -> NO DEADLOCK
	var dl_reachable_scrap: bool = SimulationLogic.check_deadlock_condition(
		50.0, 0.0, 0.0, 1.0, 0.0, 3.0, false
	)
	chk(not dl_reachable_scrap, "Broken legs with reachable scrap must NOT trigger deadlock")
	
	# Case D: Player is outside investigating -> NO DEADLOCK
	var dl_player_outside: bool = SimulationLogic.check_deadlock_condition(
		0.0, 0.0, 0.0, 1.0, 0.0, 0.0, true
	)
	chk(not dl_player_outside, "When player is outside, deadlock must be suspended")
	
	# Case E: TRUE DEADLOCK — Fuel = 0 and NO reachable fuel
	var dl_true_fuel: bool = SimulationLogic.check_deadlock_condition(
		0.0, 100.0, 0.0, 1.0, 0.0, 0.0, false
	)
	chk(dl_true_fuel, "Zero fuel and zero reachable fuel MUST trigger deadlock")
	
	# Case F: TRUE DEADLOCK — Legs = 0, Scrap = 0, and NO reachable scrap
	var dl_true_legs: bool = SimulationLogic.check_deadlock_condition(
		50.0, 0.0, 0.0, 1.0, 0.0, 0.0, false
	)
	chk(dl_true_legs, "Broken legs with zero scrap and zero reachable scrap MUST trigger deadlock")

# ------------------------------------------------------------------------------
# TEST 7: Ground Plane Alignment, Kinematic and Camera Invariants
# ------------------------------------------------------------------------------
func test_07_ground_alignment_and_camera_boundary_invariants() -> void:
	var world_scene: PackedScene = load(WORLD_SCENE_PATH)
	var world = world_scene.instantiate()
	root.add_child(world)
	
	# Ground surface: center Y=660, height 200 -> surface plane Y = 560 px
	var ground_col: CollisionShape2D = world.get_node("Ground/GroundCollision")
	var g_rect: RectangleShape2D = ground_col.shape as RectangleShape2D
	var surface_y: float = ground_col.position.y - (g_rect.size.y * 0.5)
	chk_almost_eq(surface_y, 560.0, 0.01, "Ground top collision plane is exactly Y = 560.0 px")
	
	# WalkingHouse ground contact
	var house = world.get_node("WalkingHouse")
	chk_almost_eq(house.position.y, 432.0, 0.01, "WalkingHouse body Y is 432.0 px")
	# Stance ground contact = 432.0 + 128.0 (leg length) = 560.0 px
	chk_almost_eq(house.position.y + 128.0, 560.0, 0.01, "WalkingHouse feet contact snow surface at exactly Y = 560.0 px")
	
	# Player entity ground contact
	var player = world.get_node("Player")
	chk_almost_eq(player.position.y, 560.0, 0.01, "Player feet align with ground surface at Y = 560.0 px")
	
	# Camera horizontal constraints
	var cam = world.get_node("WorldCamera")
	chk(cam.limit_left == 0, "Camera left limit is 0")
	chk(cam.limit_right >= 100000, "Camera right limit covers full 5000m route (100,000 px)")
	chk(cam.limit_bottom == 720, "Camera bottom limit is 720 px")
	
	world.free()
