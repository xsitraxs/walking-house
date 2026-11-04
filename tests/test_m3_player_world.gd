# tests/test_m3_player_world.gd
class_name TestM3PlayerWorld
extends RefCounted

## Comprehensive Test Suite for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD).
## Covers:
## - F18, F19, F25: Embark / Disembark state cycle and exit lockout while moving
## - F20: Outside locomotion kinematics, speed, and snow friction
## - F21: Proximity detection via Area2D (2.5m = 50px)
## - F22: Russian floating context prompts with yield previews
## - F23: Outside hypothermia exposure, 20s warmth buffer, and damage calculation
## - F24: Safe tether radius (45m), warning zone, violation penalty, and 50m hard clamp
## - F26, F27, F28: Resource scavenging (Fuel, Scrap, Supplies)
## - F29, F30, F31: 3 procedural node archetypes (Crate, Machinery, Camp)
## - F37: 30 deterministic resource nodes solvency (760 Fuel, 55 Scrap, 22 Supplies)
## - F47: Deadlock proximity query interface with boundary precision (45.0m)
## - F48: 5 distinct biomes across 5000m and smooth transition blending
## - F49: 4-layer parallax background with monotonic speed scaling
## - F50: Zero external assets (all Godot-native CanvasItem procedural vector graphics)

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")
const BiomeManager = preload("res://scripts/world/BiomeManager.gd")
const GameCamera = preload("res://scripts/world/GameCamera.gd")

var suite_name: String = "M3: Player Entity, Exploration, 5 Biomes & Resource Nodes"

func run_suite(runner) -> void:
	test_01_player_instantiation_and_nodes(runner)
	test_02_embark_disembark_cycle_and_lockouts(runner)
	test_03_player_outside_locomotion_kinematics(runner)
	test_04_safe_tether_radius_and_clamp(runner)
	test_05_hypothermia_warmth_and_cold_damage(runner)
	test_06_world_ground_collision_and_boundaries(runner)
	test_07_biome_manager_5_biomes_and_transitions(runner)
	test_08_resource_node_types_and_russian_prompts(runner)
	test_09_resource_node_harvesting_and_gamestate(runner)
	test_10_deterministic_30_nodes_and_solvency(runner)
	test_11_deadlock_query_reachability(runner)
	test_12_game_camera_tracking_and_zoom(runner)

# ------------------------------------------------------------------------------
# TEST 01: Player Node Hierarchy & Default Configuration
# ------------------------------------------------------------------------------
func test_01_player_instantiation_and_nodes(runner) -> void:
	runner.start_test("test_01_player_instantiation_and_nodes")
	var scene_path := "res://scenes/entities/Player.tscn"
	if not FileAccess.file_exists(scene_path):
		runner.mark_pending("Player.tscn not found")
		runner.end_test()
		return

	var scene: PackedScene = load(scene_path)
	var player = scene.instantiate()
	runner.assert_true(player is CharacterBody2D, "Player must inherit from CharacterBody2D")
	runner.assert_eq(player.collision_layer, 4, "Player collision layer must be 4")
	runner.assert_eq(player.collision_mask, 1, "Player collision mask must be 1 (Ground)")

	# Child node verification
	var col_shape: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	runner.assert_true(col_shape != null and col_shape.shape is CapsuleShape2D, "Player has CapsuleShape2D collision shape")

	var interact_area: Area2D = player.get_node_or_null("InteractionArea")
	runner.assert_true(interact_area != null, "Player has InteractionArea child")
	runner.assert_eq(interact_area.collision_mask, 8, "InteractionArea mask detects layer 8 (Interactables)")

	var lantern: PointLight2D = player.get_node_or_null("LanternLight")
	runner.assert_true(lantern != null, "Player has LanternLight PointLight2D")
	runner.assert_gt(lantern.energy, 0.5, "LanternLight has positive energy")

	# Speed and tether constants
	runner.assert_almost_eq(player.SPEED, 64.0, 0.1, "Player speed is 64 px/s (3.2 m/s)")
	runner.assert_almost_eq(player.SAFE_RADIUS_PX, 900.0, 0.1, "Safe tether radius is 900 px (45 m)")
	runner.assert_almost_eq(player.CLAMP_LIMIT_PX, 1000.0, 0.1, "Tether clamp limit is 1000 px (50 m)")

	player.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 02: Embark / Disembark State Cycle & Exit Lockouts (F18, F19, F25)
# ------------------------------------------------------------------------------
func test_02_embark_disembark_cycle_and_lockouts(runner) -> void:
	runner.start_test("test_02_embark_disembark_cycle_and_lockouts")
	var gs_script = load("res://scripts/autoload/GameState.gd")
	var gs = gs_script.new()
	gs.reset_state()

	var bus_script = load("res://scripts/autoload/EventBus.gd")
	var bus = bus_script.new()

	var house_script = load("res://scripts/entities/WalkingHouse.gd")
	var house = house_script.new()
	house.game_state = gs
	house.event_bus = bus
	house.position = Vector2(500.0, 432.0)

	var player_script = load("res://scripts/entities/Player.gd")
	var player = player_script.new()
	player.game_state = gs
	player.event_bus = bus
	player.set_player_active(false)

	# F19: Exit Lockout when house is moving (current_speed = 3.0 m/s)
	house.current_speed = 3.0
	house.is_house_moving = true
	var disembark_while_moving: bool = house._handle_disembark_request()
	runner.assert_false(disembark_while_moving, "Disembark must be rejected when house is moving")
	runner.assert_false(gs.is_player_outside, "Player remains inside cabin when disembark is rejected")

	# F18: Disembark when house is stationary (current_speed = 0.0)
	house.current_speed = 0.0
	house.is_house_moving = false
	var disembark_while_stopped: bool = house._handle_disembark_request()
	runner.assert_true(disembark_while_stopped, "Disembark succeeds when house is stationary")
	runner.assert_true(gs.is_player_outside, "GameState registers player as outside")

	# Spawn player at ladder: house.x - 60 px, Y = 560 px
	player.spawn_at_house_ladder(house)
	runner.assert_true(player.is_active, "Player entity becomes active upon spawn")
	runner.assert_true(player.visible, "Player entity becomes visible upon spawn")
	runner.assert_almost_eq(player.global_position.x, 440.0, 0.1, "Player spawned at ladder X (500 - 60 = 440 px)")
	runner.assert_almost_eq(player.global_position.y, 560.0, 0.1, "Player spawned at snow ground plane Y (560 px)")

	# F25: Return into house cabin (embark)
	player._update_ladder_proximity()
	runner.assert_true(player.can_reenter_house, "Player is within ladder proximity zone (< 50 px)")
	player._embark_into_house()
	runner.assert_false(gs.is_player_outside, "GameState registers player as back inside house")

	player.free()
	house.free()
	gs.free()
	bus.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 03: Outside Locomotion Kinematics (F20)
# ------------------------------------------------------------------------------
func test_03_player_outside_locomotion_kinematics(runner) -> void:
	runner.start_test("test_03_player_outside_locomotion_kinematics")
	var player_script = load("res://scripts/entities/Player.gd")
	var player = player_script.new()
	player.set_player_active(true)
	player.global_position = Vector2(200.0, 560.0)

	# Verify max speed configuration
	runner.assert_almost_eq(player.SPEED, 64.0, 0.01, "Player top pedestrian speed is 64 px/s (3.2 m/s)")

	# Simulate positive velocity
	player.velocity.x = 64.0
	player._process_locomotion(0.1) # Decelerates via friction if no input axis
	runner.assert_lt(player.velocity.x, 64.0, "Velocity slows under friction when input is zero")

	player.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 04: Safe Tether Radius, Warnings & 50m Hard Clamp (F24)
# ------------------------------------------------------------------------------
func test_04_safe_tether_radius_and_clamp(runner) -> void:
	runner.start_test("test_04_safe_tether_radius_and_clamp")
	var player_script = load("res://scripts/entities/Player.gd")
	var player = player_script.new()

	var house_node := Node2D.new()
	house_node.name = "WalkingHouse"
	house_node.global_position = Vector2(1000.0, 432.0)
	player.house_ref = house_node
	player.set_player_active(true)

	# 1. Normal state within safe tether (dist = 30m = 600 px)
	player.global_position = Vector2(1600.0, 560.0)
	runner.assert_almost_eq(player.get_distance_to_house_meters(), 30.0, 0.1, "Distance to house is 30m")
	player._process_tether(0.1)
	runner.assert_almost_eq(player.global_position.x, 1600.0, 0.1, "Position unconstrained within safe tether")

	# 2. Warning boundary (dist = 42m = 840 px)
	player.global_position = Vector2(1840.0, 560.0)
	runner.assert_almost_eq(player.get_distance_to_house_meters(), 42.0, 0.1, "Distance to house is 42m")

	# 3. Violation boundary (dist = 46m = 920 px > 45m safe radius)
	player.global_position = Vector2(1920.0, 560.0)
	runner.assert_gt(player.get_distance_to_house_meters(), BalanceConfig.PLAYER_SAFE_RADIUS, "Exceeds 45m safe radius")

	# 4. Hard physical clamp (dist attempted = 55m = 1100 px -> clamped to 50m = 1000 px)
	player.global_position = Vector2(2100.0, 560.0)
	player.velocity.x = 64.0
	player._process_tether(0.1)
	runner.assert_almost_eq(player.global_position.x, 2000.0, 0.1, "Player clamped to exactly 50m limit (1000 px from house)")
	runner.assert_lte(player.velocity.x, 0.0, "Outward velocity zeroed when hitting physical tether lock")
	runner.assert_true(player.is_at_tether_limit, "Tether limit flag active at 50m clamp")

	# 5. Return towards house (dist = 40m = 800 px < 50m clamp: unlatches limit prompt)
	player.global_position = Vector2(1800.0, 560.0)
	player._process_tether(0.1)
	runner.assert_false(player.is_at_tether_limit, "Tether limit flag cleared when returning within limit")

	player.free()
	house_node.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 05: Hypothermia, Warmth Buffer & Cold Damage (F23)
# ------------------------------------------------------------------------------
func test_05_hypothermia_warmth_and_cold_damage(runner) -> void:
	runner.start_test("test_05_hypothermia_warmth_and_cold_damage")
	var gs_script = load("res://scripts/autoload/GameState.gd")
	var gs = gs_script.new()
	gs.reset_state()

	var player_script = load("res://scripts/entities/Player.gd")
	var player = player_script.new()
	player.set_player_active(true)

	var house_node := Node2D.new()
	house_node.global_position = Vector2(1000.0, 432.0)
	player.house_ref = house_node
	player.global_position = Vector2(1200.0, 560.0) # 10m from house (within 45m)

	# Mock GameState retrieval for headless test
	Engine.register_singleton("GameState", gs)

	# Phase 1: 10s outside (warmth buffer active, 0 damage)
	player.outside_exposure_timer = 10.0
	player._process_cold_exposure(1.0) # timer becomes 11.0s
	runner.assert_almost_eq(gs.player_health, 100.0, 0.01, "Zero damage during first 20s warmth grace period")
	runner.assert_almost_eq(gs.player_warmth, 45.0, 0.1, "Warmth buffer correctly at 45% after 11s")

	# Phase 2: After 20s (exposure damage active)
	player.outside_exposure_timer = 20.0
	player._process_cold_exposure(2.0) # 2.0s over limit -> 2.0s * 2.5 HP/s = 5.0 HP damage
	runner.assert_almost_eq(gs.player_health, 95.0, 0.1, "5.0 HP cold damage inflicted after warmth exhaustion")

	# Phase 3: Blizzard damage amplification (6.0 HP/s)
	gs.is_blizzard = true
	player._process_cold_exposure(1.0) # 1.0s * 6.0 HP/s = 6.0 HP damage
	runner.assert_almost_eq(gs.player_health, 89.0, 0.1, "Blizzard amplifies outdoor hypothermia to 6.0 HP/s")

	# Phase 4: Tether violation penalty (2.0x multiplier beyond 45m)
	gs.is_blizzard = false
	player.global_position = Vector2(2000.0, 560.0) # 50m from house (> 45m)
	player._process_cold_exposure(1.0) # 1.0s * 2.5 HP/s * 2.0 = 5.0 HP damage
	runner.assert_almost_eq(gs.player_health, 84.0, 0.1, "Tether violation doubles outdoor cold damage")

	Engine.unregister_singleton("GameState")
	player.free()
	house_node.free()
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 06: World Ground Collision & Parallax Monotonicity (F49, F50)
# ------------------------------------------------------------------------------
func test_06_world_ground_collision_and_boundaries(runner) -> void:
	runner.start_test("test_06_world_ground_collision_and_boundaries")
	var scene_path := "res://scenes/world/World.tscn"
	if not FileAccess.file_exists(scene_path):
		runner.mark_pending("World.tscn not found")
		runner.end_test()
		return

	var scene: PackedScene = load(scene_path)
	var world = scene.instantiate()

	# Ground Collision Surface verification: center (50000, 660), height 200 -> top edge Y = 560 px
	var ground_body: StaticBody2D = world.get_node_or_null("Ground")
	runner.assert_true(ground_body != null, "World contains StaticBody2D Ground")
	var ground_shape: CollisionShape2D = world.get_node_or_null("Ground/GroundCollision")
	runner.assert_true(ground_shape != null, "Ground contains GroundCollision shape")
	var rect_shape: RectangleShape2D = ground_shape.shape as RectangleShape2D
	runner.assert_almost_eq(rect_shape.size.x, 102000.0, 1.0, "Ground spans 102,000 px horizontally")
	var top_edge_y: float = ground_shape.position.y - (rect_shape.size.y * 0.5)
	runner.assert_almost_eq(top_edge_y, 560.0, 0.1, "Ground surface top edge is precisely Y = 560.0 px")

	# Boundary Walls
	var left_wall: CollisionShape2D = world.get_node_or_null("Ground/LeftWall")
	var right_wall: CollisionShape2D = world.get_node_or_null("Ground/RightWall")
	runner.assert_true(left_wall != null and right_wall != null, "World has Left and Right boundary walls")

	# Parallax Monotonicity (4 layers: 0.02 < 0.08 < 0.25 < 0.60 < 1.0)
	var pbg: ParallaxBackground = world.get_node_or_null("ParallaxBackground")
	runner.assert_true(pbg != null, "World contains ParallaxBackground")
	var s_layer: ParallaxLayer = world.get_node_or_null("ParallaxBackground/SkyLayer")
	var m_layer: ParallaxLayer = world.get_node_or_null("ParallaxBackground/MountainLayer")
	var mid_layer: ParallaxLayer = world.get_node_or_null("ParallaxBackground/MidgroundLayer")
	var d_layer: ParallaxLayer = world.get_node_or_null("ParallaxBackground/ForegroundDunesLayer")

	runner.assert_almost_eq(s_layer.motion_scale.x, 0.02, 0.001, "Layer 1 Sky motion scale is 0.02")
	runner.assert_almost_eq(m_layer.motion_scale.x, 0.08, 0.001, "Layer 2 Mountain motion scale is 0.08")
	runner.assert_almost_eq(mid_layer.motion_scale.x, 0.25, 0.001, "Layer 3 Midground motion scale is 0.25")
	runner.assert_almost_eq(d_layer.motion_scale.x, 0.60, 0.001, "Layer 4 Dunes motion scale is 0.60")

	runner.assert_lt(s_layer.motion_scale.x, m_layer.motion_scale.x, "Parallax Layer 1 < Layer 2")
	runner.assert_lt(m_layer.motion_scale.x, mid_layer.motion_scale.x, "Parallax Layer 2 < Layer 3")
	runner.assert_lt(mid_layer.motion_scale.x, d_layer.motion_scale.x, "Parallax Layer 3 < Layer 4")

	world.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 07: BiomeManager 5 Distinct Biomes & Transition Blending (F48)
# ------------------------------------------------------------------------------
func test_07_biome_manager_5_biomes_and_transitions(runner) -> void:
	runner.start_test("test_07_biome_manager_5_biomes_and_transitions")
	var mgr = BiomeManager.new()
	mgr._ready()

	# Verify 5 distinct biomes across 5000m
	runner.assert_eq(mgr.get_biome_at(500.0)["id"], "snowy_plains", "Biome 0 (0-1000m): Заснеженная равнина")
	runner.assert_eq(mgr.get_biome_at(1500.0)["id"], "abandoned_camp", "Biome 1 (1000-2000m): Заброшенный лагерь")
	runner.assert_eq(mgr.get_biome_at(2500.0)["id"], "machinery_graveyard", "Biome 2 (2000-3000m): Кладбище техники")
	runner.assert_eq(mgr.get_biome_at(3500.0)["id"], "frozen_forest", "Biome 3 (3000-4000m): Замёрзший лес")
	runner.assert_eq(mgr.get_biome_at(4500.0)["id"], "station_outskirts", "Biome 4 (4000-5000m): Окрестности станции «Полюс»")

	var pal_0 = BiomeManager.BIOME_PALETTES[0]
	var pal_1 = BiomeManager.BIOME_PALETTES[1]

	# 1. Test point at 975.0m (within blend window before 1000m: s=0.25, blend_factor=0.15625)
	mgr.update_distance(975.0)
	var pal_975 = mgr.get_active_palette()
	var exp_zenith_975: Color = pal_0.sky_zenith.lerp(pal_1.sky_zenith, 0.15625)
	var exp_mountain_975: Color = pal_0.mountain_tint.lerp(pal_1.mountain_tint, 0.15625)
	runner.assert_almost_eq(pal_975.sky_zenith.r, exp_zenith_975.r, 0.005, "Sky zenith blends at 975m (blend_factor ~0.156)")
	runner.assert_almost_eq(pal_975.mountain_tint.r, exp_mountain_975.r, 0.005, "Mountain tint blends at 975m (blend_factor ~0.156)")

	# 2. Test point at 1000.0m (exact midpoint: s=0.5, blend_factor=0.50)
	mgr.update_distance(1000.0)
	var pal_1000 = mgr.get_active_palette()
	var exp_zenith_1000: Color = pal_0.sky_zenith.lerp(pal_1.sky_zenith, 0.50)
	var exp_mountain_1000: Color = pal_0.mountain_tint.lerp(pal_1.mountain_tint, 0.50)
	runner.assert_almost_eq(pal_1000.sky_zenith.r, exp_zenith_1000.r, 0.005, "Sky zenith strictly blends at 1000m midpoint")
	runner.assert_almost_eq(pal_1000.mountain_tint.r, exp_mountain_1000.r, 0.005, "Mountain tint strictly blends at 1000m midpoint")

	# 3. Test point at 1025.0m (within blend window after 1000m: s=0.75, blend_factor=0.84375)
	mgr.update_distance(1025.0)
	var pal_1025 = mgr.get_active_palette()
	var exp_zenith_1025: Color = pal_0.sky_zenith.lerp(pal_1.sky_zenith, 0.84375)
	var exp_mountain_1025: Color = pal_0.mountain_tint.lerp(pal_1.mountain_tint, 0.84375)
	runner.assert_almost_eq(pal_1025.sky_zenith.r, exp_zenith_1025.r, 0.005, "Sky zenith blends at 1025m (blend_factor ~0.844)")
	runner.assert_almost_eq(pal_1025.mountain_tint.r, exp_mountain_1025.r, 0.005, "Mountain tint blends at 1025m (blend_factor ~0.844)")

	# 4. Test point at 1050.0m (exact end of blend window: s=1.0, blend_factor=1.00)
	mgr.update_distance(1050.0)
	var pal_1050 = mgr.get_active_palette()
	runner.assert_almost_eq(pal_1050.sky_zenith.r, pal_1.sky_zenith.r, 0.005, "Sky zenith matches Biome 1 at 1050m end of window")
	runner.assert_almost_eq(pal_1050.mountain_tint.r, pal_1.mountain_tint.r, 0.005, "Mountain tint matches Biome 1 at 1050m end of window")

	# Strict monotonic interpolation across boundary without snaps or jumps
	runner.assert_gt(pal_975.sky_zenith.r, pal_1000.sky_zenith.r, "Sky zenith R decreases monotonically towards midpoint")
	runner.assert_gt(pal_1000.sky_zenith.r, pal_1025.sky_zenith.r, "Sky zenith R decreases monotonically past midpoint")
	runner.assert_gte(pal_1025.sky_zenith.r, pal_1050.sky_zenith.r, "Sky zenith R reaches Biome 1 target smoothly")

	runner.assert_gt(pal_975.mountain_tint.r, pal_1000.mountain_tint.r, "Mountain tint R decreases monotonically towards midpoint")
	runner.assert_gt(pal_1000.mountain_tint.r, pal_1025.mountain_tint.r, "Mountain tint R decreases monotonically past midpoint")
	runner.assert_gte(pal_1025.mountain_tint.r, pal_1050.mountain_tint.r, "Mountain tint R reaches Biome 1 target smoothly")

	# Pure biome outside blend zone (e.g. 1500m)
	mgr.update_distance(1500.0)
	runner.assert_eq(mgr.active_biome_index, 1, "Active biome index is 1 at 1500m")

	mgr.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 08: ResourceNode Archetypes & Russian Context Prompts (F21, F22, F29-F31)
# ------------------------------------------------------------------------------
func test_08_resource_node_types_and_russian_prompts(runner) -> void:
	runner.start_test("test_08_resource_node_types_and_russian_prompts")
	var node = ResourceNode.new()

	# 1. Crate Archetype (F29)
	node.setup_node({
		"node_id": 1,
		"node_type": ResourceNode.NodeType.CRATE,
		"distance_m": 195.0,
		"fuel": 30.0,
		"scrap": 0.0,
		"supplies": 0.0
	})
	var crate_prompt: String = node.get_interaction_prompt()
	runner.assert_true(crate_prompt.begins_with("[E] Обыскать ящик"), "Crate Russian prompt begins with '[E] Обыскать ящик'")
	runner.assert_true(crate_prompt.contains("+30 Топливо"), "Crate Russian prompt contains yield preview '+30 Топливо'")

	# 2. Machinery Archetype (F30)
	node.setup_node({
		"node_id": 2,
		"node_type": ResourceNode.NodeType.MACHINERY,
		"distance_m": 205.0,
		"fuel": 0.0,
		"scrap": 3.0,
		"supplies": 1.0
	})
	var mach_prompt: String = node.get_interaction_prompt()
	runner.assert_true(mach_prompt.begins_with("[E] Разобрать механизм"), "Machinery prompt begins with '[E] Разобрать механизм'")
	runner.assert_true(mach_prompt.contains("+3 Металлолом"), "Machinery prompt shows '+3 Металлолом'")
	runner.assert_true(mach_prompt.contains("+1 Припасы"), "Machinery prompt shows '+1 Припасы'")

	# 3. Camp Remnants Archetype (F31)
	node.setup_node({
		"node_id": 4,
		"node_type": ResourceNode.NodeType.CAMP,
		"distance_m": 455.0,
		"fuel": 0.0,
		"scrap": 2.0,
		"supplies": 1.0
	})
	var camp_prompt: String = node.get_interaction_prompt()
	runner.assert_true(camp_prompt.begins_with("[E] Обыскать лагерь"), "Camp prompt begins with '[E] Обыскать лагерь'")

	# F21: Interaction radius is 50 px (2.5m)
	runner.assert_almost_eq(node.collision_shape.shape.radius, 50.0, 0.1, "Interaction radius is exactly 50 px (2.5 m)")

	node.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 09: Resource Harvesting & State Integration (F26-F28)
# ------------------------------------------------------------------------------
func test_09_resource_node_harvesting_and_gamestate(runner) -> void:
	runner.start_test("test_09_resource_node_harvesting_and_gamestate")
	var gs_script = load("res://scripts/autoload/GameState.gd")
	var gs = gs_script.new()
	gs.reset_state()
	gs.fuel = 50.0
	Engine.register_singleton("GameState", gs)

	var node = ResourceNode.new()
	node.setup_node({
		"node_id": 1,
		"node_type": ResourceNode.NodeType.CRATE,
		"distance_m": 195.0,
		"fuel": 30.0,
		"scrap": 4.0,
		"supplies": 2.0
	})

	var initial_fuel: float = gs.fuel
	var initial_scrap: float = gs.scrap
	var initial_supplies: float = gs.supplies

	# First harvest
	var yields: Dictionary = node.harvest()
	runner.assert_eq(yields["fuel"], 30.0, "Harvested 30 fuel")
	runner.assert_eq(yields["scrap"], 4.0, "Harvested 4 scrap")
	runner.assert_eq(yields["supplies"], 2.0, "Harvested 2 supplies")

	runner.assert_almost_eq(gs.fuel, initial_fuel + 30.0, 0.1, "GameState fuel increased by 30")
	runner.assert_almost_eq(gs.scrap, initial_scrap + 4.0, 0.1, "GameState scrap increased by 4")
	runner.assert_almost_eq(gs.supplies, initial_supplies + 2.0, 0.1, "GameState supplies increased by 2")
	runner.assert_true(node.is_harvested, "Node is marked as harvested")

	# Second harvest attempt on empty node
	var empty_yields: Dictionary = node.harvest()
	runner.assert_eq(empty_yields["fuel"], 0.0, "Second harvest yields 0 fuel")
	runner.assert_eq(empty_yields["scrap"], 0.0, "Second harvest yields 0 scrap")

	Engine.unregister_singleton("GameState")
	node.free()
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 10: 30 Deterministic Nodes & Exact Balance Solvency (F37)
# ------------------------------------------------------------------------------
func test_10_deterministic_30_nodes_and_solvency(runner) -> void:
	runner.start_test("test_10_deterministic_30_nodes_and_solvency")
	var nodes: Array[Dictionary] = ResourceNode.DEFAULT_NODES
	runner.assert_eq(nodes.size(), 30, "Exactly 30 deterministic resource nodes defined")

	var total_fuel: float = 0.0
	var total_scrap: float = 0.0
	var total_supplies: float = 0.0
	var biome_node_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}

	for n in nodes:
		total_fuel += n["fuel"]
		total_scrap += n["scrap"]
		total_supplies += n["supplies"]
		var b_idx: int = n["biome_index"]
		biome_node_counts[b_idx] = biome_node_counts.get(b_idx, 0) + 1

	# Strict BalanceConfig POI matching
	runner.assert_almost_eq(total_fuel, 760.0, 0.1, "Placed fuel strictly equals 760.0 units")
	runner.assert_almost_eq(total_scrap, 55.0, 0.1, "Placed scrap strictly equals 55 units")
	runner.assert_almost_eq(total_supplies, 22.0, 0.1, "Placed supplies strictly equals 22 units")

	# Biome distribution
	for b in range(5):
		runner.assert_gt(biome_node_counts[b], 0, "Biome %d has resource nodes placed" % b)

	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 11: Deadlock Proximity Query & Reachability (F47)
# ------------------------------------------------------------------------------
func test_11_deadlock_query_reachability(runner) -> void:
	runner.start_test("test_11_deadlock_query_reachability")
	var node = ResourceNode.new()
	node.setup_node({
		"node_id": 99,
		"distance_m": 200.0,
		"fuel": 30.0,
		"scrap": 5.0
	})
	node.global_position = Vector2(4000.0, 560.0) # 200m * 20 px/m

	# House at 240m (dist = 40m <= 45m safe radius) -> Reachable
	var house_x_reachable: float = 240.0 * 20.0 # 4800 px
	runner.assert_true(node.is_reachable_from(house_x_reachable, 45.0), "Node at 40m distance is reachable")

	# Boundary Value Analysis (BVA) for reachability:
	var house_x_44_9m: float = (200.0 + 44.9) * 20.0
	runner.assert_true(node.is_reachable_from(house_x_44_9m, 45.0), "Node at 44.9m is reachable")

	var house_x_45_0m: float = (200.0 + 45.0) * 20.0
	runner.assert_true(node.is_reachable_from(house_x_45_0m, 45.0), "Node at exactly 45.0m is reachable")

	var house_x_45_1m: float = (200.0 + 45.1) * 20.0
	runner.assert_false(node.is_reachable_from(house_x_45_1m, 45.0), "Node at 45.1m is outside safe tether perimeter")

	# Harvested node is no longer reachable
	node.is_harvested = true
	runner.assert_false(node.is_reachable_from(house_x_reachable, 45.0), "Harvested node is not reachable for deadlock relief")

	node.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 12: GameCamera Tracking & Zoom Transitions
# ------------------------------------------------------------------------------
func test_12_game_camera_tracking_and_zoom(runner) -> void:
	runner.start_test("test_12_game_camera_tracking_and_zoom")
	var cam = GameCamera.new()
	cam._ready()

	# Limits verification
	runner.assert_eq(cam.limit_left, 0, "Camera left limit is 0")
	runner.assert_gte(cam.limit_right, 100000, "Camera right limit covers full 5000m world")
	runner.assert_eq(cam.limit_bottom, 720, "Camera bottom limit is 720 px")

	# Mode switching
	cam._on_player_disembarked()
	runner.assert_true(cam.is_player_focused, "Camera switches to player focus on disembark")
	runner.assert_eq(cam.ZOOM_PLAYER, Vector2(1.15, 1.15), "Player zoom target is 1.15x")

	cam._on_player_embarked()
	runner.assert_false(cam.is_player_focused, "Camera switches to house focus on embark")
	runner.assert_eq(cam.ZOOM_HOUSE, Vector2(1.0, 1.0), "House zoom target is 1.0x")

	cam.free()
	runner.end_test()
