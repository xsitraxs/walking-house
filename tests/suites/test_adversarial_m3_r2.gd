# tests/suites/test_adversarial_m3_r2.gd
# Adversarial Reviewer & Critic Stress Suite for M3 Iteration 2
# Author: m3_reviewer_1_r2
# Focus: BiomeManager 4 Boundary Hermite Transitions, Defensive Palette Immutability,
#        Player Tether Limit State, Prompt Unlatching, and Chatter Invariants
extends SceneTree

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const BiomeManagerScript = preload("res://scripts/world/BiomeManager.gd")
const PlayerScript = preload("res://scripts/entities/Player.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")
const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const SoundManagerScript = preload("res://scripts/autoload/SoundManager.gd")

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

func assert_true(condition: bool, msg: String) -> void:
	total_assertions += 1
	if not condition:
		failed_tests += 1
		var err = "[FAIL] %s: %s" % [current_test, msg]
		failure_details.append(err)
		print("  " + err)

func assert_false(condition: bool, msg: String) -> void:
	assert_true(not condition, msg)

func assert_eq(a, b, msg: String) -> void:
	assert_true(a == b, "%s (Expected %s, got %s)" % [msg, str(b), str(a)])

func assert_lte(a: float, b: float, msg: String) -> void:
	assert_true(a <= b, "%s (Expected %f <= %f)" % [msg, a, b])

func assert_gte(a: float, b: float, msg: String) -> void:
	assert_true(a >= b, "%s (Expected %f >= %f)" % [msg, a, b])

func assert_almost_eq(a: float, b: float, tol: float, msg: String) -> void:
	var diff = absf(a - b)
	assert_true(diff <= tol, "%s (Expected ~%f, got %f, diff=%f > tol=%f)" % [msg, b, a, diff, tol])

func _run_tests() -> void:
	await process_frame
	print("\n" + "=".repeat(80))
	print("  M3 ITERATION 2 ADVERSARIAL CRITIC STRESS SUITE (m3_reviewer_1_r2)")
	print("  Stress-testing Biome Blending, Palette Defense, Tether Prompt Unlatching")
	print("=".repeat(80) + "\n")

	# Singletons
	bus = root.get_node_or_null("EventBus")
	if bus == null:
		bus = EventBusScript.new()
		bus.name = "EventBus"
		root.add_child(bus)

	gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = GameStateScript.new()
		gs.name = "GameState"
		root.add_child(gs)

	sound = root.get_node_or_null("SoundManager")
	if sound == null:
		sound = SoundManagerScript.new()
		sound.name = "SoundManager"
		root.add_child(sound)

	var before_failures = failed_tests

	# Run tests
	current_test = "TEST 1: 4-Boundary Hermite Continuity (1000m, 2000m, 3000m, 4000m)"
	_test_all_four_boundaries_hermite()

	current_test = "TEST 2: Fine-Grained 1-Meter Smoothness and Discontinuity Detection"
	_test_fine_grained_smoothness()

	current_test = "TEST 3: Defensive Palette Deep Mutation & Snapshot Independence"
	_test_palette_deep_mutation_defense()

	current_test = "TEST 4: Player Tether Limit State Invariants, Chatter & Symmetrical Clamping"
	_test_player_tether_limit_and_unlatching()

	current_test = "TEST 5: Tether Prompt Unlatching Suppression Near Ladder / Interactables"
	_test_prompt_suppression_near_interactables()

	current_test = "TEST 6: Extreme Coordinates & Boundary Clamping Robustness"
	_test_extreme_coordinates()

	print("\n" + "=".repeat(80))
	print("  M3 ADVERSARIAL CRITIC SUMMARY")
	print("=".repeat(80))
	print("  Total Assertions: %d" % total_assertions)
	print("  Failed Assertions: %d" % failed_tests)
	if failed_tests == 0:
		print("  STATUS: 100% PASSED — ROBUST AND IMMUTABLE")
		print("=".repeat(80) + "\n")
		quit(0)
	else:
		print("  STATUS: %d FAILURES DETECTED" % failed_tests)
		for f in failure_details:
			print("    * " + f)
		print("=".repeat(80) + "\n")
		quit(1)

func _test_all_four_boundaries_hermite() -> void:
	var bm = BiomeManagerScript.new()
	bm._ready()

	var boundaries = [
		{"m": 1000.0, "from_idx": 0, "to_idx": 1},
		{"m": 2000.0, "from_idx": 1, "to_idx": 2},
		{"m": 3000.0, "from_idx": 2, "to_idx": 3},
		{"m": 4000.0, "from_idx": 3, "to_idx": 4}
	]

	for b in boundaries:
		var bm_dist: float = b["m"]
		var from_idx: int = b["from_idx"]
		var to_idx: int = b["to_idx"]
		var pal_from: Dictionary = BiomeManagerScript.BIOME_PALETTES[from_idx]
		var pal_to: Dictionary = BiomeManagerScript.BIOME_PALETTES[to_idx]

		# 1. At start of window: bm_dist - 50m
		bm.update_distance(bm_dist - 50.0)
		var pal_start = bm.get_active_palette()
		assert_almost_eq(pal_start.sky_zenith.r, pal_from.sky_zenith.r, 0.001, "Boundary %.0fm: start window matches from-biome sky_zenith" % bm_dist)
		assert_almost_eq(pal_start.mountain_tint.r, pal_from.mountain_tint.r, 0.001, "Boundary %.0fm: start window matches from-biome mountain_tint" % bm_dist)

		# 2. At s=0.25 (bm_dist - 25m), blend_factor = 0.15625
		bm.update_distance(bm_dist - 25.0)
		var pal_25 = bm.get_active_palette()
		var exp_zenith_25: Color = pal_from.sky_zenith.lerp(pal_to.sky_zenith, 0.15625)
		var exp_wind_25: float = lerpf(pal_from.wind_intensity, pal_to.wind_intensity, 0.15625)
		assert_almost_eq(pal_25.sky_zenith.r, exp_zenith_25.r, 0.005, "Boundary %.0fm: s=0.25 sky_zenith blends correctly" % bm_dist)
		assert_almost_eq(pal_25.wind_intensity, exp_wind_25, 0.005, "Boundary %.0fm: s=0.25 wind_intensity blends correctly" % bm_dist)

		# 3. At midpoint (bm_dist), blend_factor = 0.50
		bm.update_distance(bm_dist)
		var pal_mid = bm.get_active_palette()
		var exp_zenith_mid: Color = pal_from.sky_zenith.lerp(pal_to.sky_zenith, 0.50)
		var exp_mtn_mid: Color = pal_from.mountain_tint.lerp(pal_to.mountain_tint, 0.50)
		var exp_wind_mid: float = lerpf(pal_from.wind_intensity, pal_to.wind_intensity, 0.50)
		assert_almost_eq(pal_mid.sky_zenith.r, exp_zenith_mid.r, 0.005, "Boundary %.0fm: midpoint sky_zenith blends at 50%%" % bm_dist)
		assert_almost_eq(pal_mid.mountain_tint.r, exp_mtn_mid.r, 0.005, "Boundary %.0fm: midpoint mountain_tint blends at 50%%" % bm_dist)
		assert_almost_eq(pal_mid.wind_intensity, exp_wind_mid, 0.005, "Boundary %.0fm: midpoint wind_intensity blends at 50%%" % bm_dist)

		# 4. At s=0.75 (bm_dist + 25m), blend_factor = 0.84375
		bm.update_distance(bm_dist + 25.0)
		var pal_75 = bm.get_active_palette()
		var exp_zenith_75: Color = pal_from.sky_zenith.lerp(pal_to.sky_zenith, 0.84375)
		var exp_wind_75: float = lerpf(pal_from.wind_intensity, pal_to.wind_intensity, 0.84375)
		assert_almost_eq(pal_75.sky_zenith.r, exp_zenith_75.r, 0.005, "Boundary %.0fm: s=0.75 sky_zenith blends correctly" % bm_dist)
		assert_almost_eq(pal_75.wind_intensity, exp_wind_75, 0.005, "Boundary %.0fm: s=0.75 wind_intensity blends correctly" % bm_dist)

		# 5. At end of window: bm_dist + 50m
		bm.update_distance(bm_dist + 50.0)
		var pal_end = bm.get_active_palette()
		assert_almost_eq(pal_end.sky_zenith.r, pal_to.sky_zenith.r, 0.001, "Boundary %.0fm: end window matches to-biome sky_zenith" % bm_dist)
		assert_almost_eq(pal_end.mountain_tint.r, pal_to.mountain_tint.r, 0.001, "Boundary %.0fm: end window matches to-biome mountain_tint" % bm_dist)

	bm.free()

func _test_fine_grained_smoothness() -> void:
	var bm = BiomeManagerScript.new()
	bm._ready()

	# Sample across 1000m boundary from 940m to 1060m at 1m step
	var prev_zenith_r: float = -1.0
	var max_step_delta: float = 0.0

	for m in range(940, 1061):
		bm.update_distance(float(m))
		var pal = bm.get_active_palette()
		var curr_zenith_r = pal.sky_zenith.r
		if prev_zenith_r >= 0.0:
			var step_delta = absf(curr_zenith_r - prev_zenith_r)
			if step_delta > max_step_delta:
				max_step_delta = step_delta
		prev_zenith_r = curr_zenith_r

	# The total difference is (0.20 - 0.18) = 0.02 across 100m.
	# Max derivative for smoothstep 3s^2 - 2s^3 is at s=0.5: S'(0.5) = 1.5.
	# Over 100m, max rate is 1.5 * 0.02 / 100 = 0.0003 per meter!
	# If there were any snapping, step_delta would jump to ~0.01 or 0.02!
	assert_true(max_step_delta < 0.001, "Max 1m step delta is smooth (max delta = %f < 0.001)" % max_step_delta)

	bm.free()

func _test_palette_deep_mutation_defense() -> void:
	var bm = BiomeManagerScript.new()
	bm._ready()

	bm.update_distance(1000.0)
	var pal1 = bm.get_active_palette()
	var original_zenith = pal1.sky_zenith

	# Attempt adversarial mutation of returned dictionary
	pal1["sky_zenith"] = Color(1.0, 0.0, 1.0, 1.0) # Purple
	pal1["malicious_key"] = "hacked"
	pal1["wind_intensity"] = 9999.0

	# Get another snapshot
	var pal2 = bm.get_active_palette()
	assert_eq(pal2.sky_zenith, original_zenith, "Internal palette sky_zenith was protected from caller mutation")
	assert_false(pal2.has("malicious_key"), "Internal palette has no injected malicious_key")
	assert_almost_eq(pal2.wind_intensity, 0.40, 0.01, "Internal wind_intensity was protected from caller mutation")

	bm.free()

func _test_player_tether_limit_and_unlatching() -> void:
	var house = Node2D.new()
	house.global_position = Vector2(1000.0, 560.0)
	root.add_child(house)

	var player = PlayerScript.new()
	player.house_ref = house
	root.add_child(player)
	player.spawn_at_house_ladder(house)

	var requested_prompts: Array[String] = []
	var clear_prompt_events: Array[int] = [0]

	var on_prompt_requested = func(text: String):
		requested_prompts.append(text)
	var on_prompt_cleared = func():
		clear_prompt_events[0] += 1

	bus.connect("prompt_requested", Callable(on_prompt_requested))
	bus.connect("prompt_cleared", Callable(on_prompt_cleared))

	# 1. Start inside safe zone: 30m away (1600 px)
	player.global_position = Vector2(1600.0, 560.0)
	player._process_tether(0.1)
	assert_false(player.is_at_tether_limit, "At 30m, player is not at tether limit")
	assert_eq(requested_prompts.size(), 0, "No tether limit prompt requested in safe zone")

	# 2. Exceed 50m limit: attempted 55m (2100 px). Clamp is at 1000 + 1000 = 2000 px.
	player.global_position = Vector2(2100.0, 560.0)
	player.velocity.x = 80.0
	player._process_tether(0.1)
	assert_almost_eq(player.global_position.x, 2000.0, 0.1, "Player position clamped to 2000 px (50m)")
	assert_lte(player.velocity.x, 0.0, "Outward velocity zeroed")
	assert_true(player.is_at_tether_limit, "is_at_tether_limit is true at clamp limit")
	assert_eq(requested_prompts.size(), 1, "Exactly 1 prompt requested on reaching limit")
	assert_eq(requested_prompts[0], "Трос натянут до предела (50 м)!", "Prompt text matches Russian localization")

	# 3. Repeated frames holding right at limit: should NOT spam prompt_requested
	player._process_tether(0.1)
	player._process_tether(0.1)
	assert_eq(requested_prompts.size(), 1, "No prompt spamming while remaining at limit")

	# 4. Step inward towards house: 49.5m (1990 px)
	player.global_position = Vector2(1990.0, 560.0)
	player._process_tether(0.1)
	assert_false(player.is_at_tether_limit, "is_at_tether_limit resets to false when stepping inward")
	assert_eq(clear_prompt_events[0], 1, "prompt_cleared emitted on stepping inward from limit")

	# 5. Continuous inward movement: should NOT repeatedly fire prompt_cleared
	player.global_position = Vector2(1980.0, 560.0)
	player._process_tether(0.1)
	assert_eq(clear_prompt_events[0], 1, "prompt_cleared not spammed on further inward movement")

	# 6. Symmetrical negative direction (left clamp): 50m to the left (1000 - 1000 = 0 px)
	player.global_position = Vector2(-100.0, 560.0)
	player.velocity.x = -80.0
	player._process_tether(0.1)
	assert_almost_eq(player.global_position.x, 0.0, 0.1, "Negative direction clamped to exactly 0 px (-50m)")
	assert_gte(player.velocity.x, 0.0, "Leftward velocity zeroed when hitting left clamp")
	assert_true(player.is_at_tether_limit, "is_at_tether_limit is true at negative clamp")
	assert_eq(requested_prompts.size(), 2, "Prompt requested for negative limit hit")

	# 7. Step back right from left clamp:
	player.global_position = Vector2(10.0, 560.0)
	player._process_tether(0.1)
	assert_false(player.is_at_tether_limit, "is_at_tether_limit resets when stepping inward from left limit")
	assert_eq(clear_prompt_events[0], 2, "prompt_cleared emitted when stepping inward from left limit")

	bus.disconnect("prompt_requested", Callable(on_prompt_requested))
	bus.disconnect("prompt_cleared", Callable(on_prompt_cleared))

	player.free()
	house.free()

func _test_prompt_suppression_near_interactables() -> void:
	var house = Node2D.new()
	house.global_position = Vector2(1000.0, 560.0)
	root.add_child(house)

	var player = PlayerScript.new()
	player.house_ref = house
	root.add_child(player)
	player.spawn_at_house_ladder(house)

	var clear_events: Array[int] = [0]
	var on_prompt_cleared = func():
		clear_events[0] += 1
	bus.connect("prompt_cleared", Callable(on_prompt_cleared))

	# Player hit clamp
	player.global_position = Vector2(2000.0, 560.0)
	player._process_tether(0.1)
	assert_true(player.is_at_tether_limit, "Player at limit")

	# Simulate being near an interactable or ladder when stepping inward
	player.can_reenter_house = true
	player.global_position = Vector2(1990.0, 560.0)
	player._process_tether(0.1)
	assert_false(player.is_at_tether_limit, "Limit flag cleared")
	assert_eq(clear_events[0], 0, "prompt_cleared suppressed because can_reenter_house is active")

	# Now hit limit again and step inward with current_interactable active
	player.can_reenter_house = false
	player.global_position = Vector2(2000.0, 560.0)
	player._process_tether(0.1)
	assert_true(player.is_at_tether_limit, "Player at limit again")

	var dummy_interactable = Node.new()
	player.current_interactable = dummy_interactable
	player.global_position = Vector2(1990.0, 560.0)
	player._process_tether(0.1)
	assert_false(player.is_at_tether_limit, "Limit flag cleared")
	assert_eq(clear_events[0], 0, "prompt_cleared suppressed because current_interactable is active")

	dummy_interactable.free()
	bus.disconnect("prompt_cleared", Callable(on_prompt_cleared))
	player.free()
	house.free()

func _test_extreme_coordinates() -> void:
	var bm = BiomeManagerScript.new()
	bm._ready()

	# Negative distance
	bm.update_distance(-500.0)
	assert_eq(bm.current_distance_m, 0.0, "Negative distance clamped to 0.0m")
	assert_eq(bm.active_biome_index, 0, "Negative distance active_biome_index is 0")
	var pal_neg = bm.get_active_palette()
	assert_eq(pal_neg.sky_zenith, BiomeManagerScript.BIOME_PALETTES[0].sky_zenith, "Negative distance uses Biome 0")

	# Distance > 5000m
	bm.update_distance(6000.0)
	assert_eq(bm.current_distance_m, 5000.0, "Excess distance clamped to 5000.0m")
	assert_eq(bm.active_biome_index, 4, "Excess distance active_biome_index is 4")
	var pal_pos = bm.get_active_palette()
	assert_eq(pal_pos.sky_zenith, BiomeManagerScript.BIOME_PALETTES[4].sky_zenith, "Excess distance uses Biome 4")

	# Zigzagging across 2000m boundary 50 times
	for i in range(50):
		var d = 1940.0 if (i % 2 == 0) else 2060.0
		bm.update_distance(d)
		var p = bm.get_active_palette()
		assert_true(p.has("sky_zenith"), "Palette intact during rapid boundary oscillation")

	bm.free()
