# tests/suites/test_adversarial_m3_biome_interpolation.gd
# Empirical Challenger Adversarial Stress Suite for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD)
# Iteration 2 Challenger: m3_challenger_1_r2
# Focus: BiomeManager boundary calculation and palette interpolation across all 4 transition zones
extends SceneTree

const BiomeManagerClass = preload("res://scripts/world/BiomeManager.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")

const COLOR_KEYS: Array[String] = [
	"sky_zenith",
	"sky_horizon",
	"ambient_modulate",
	"mountain_tint",
	"mountain_snow",
	"midground_tint",
	"dunes_tint",
	"ground_snow_base",
	"ground_snow_top",
	"ground_soil_dark"
]

const FLOAT_KEYS: Array[String] = [
	"wind_intensity",
	"aurora_alpha",
	"star_alpha"
]

const BOUNDARIES: Array[float] = [1000.0, 2000.0, 3000.0, 4000.0]

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
	print("  M3 EMPIRICAL CHALLENGER ADVERSARIAL STRESS SUITE (ITERATION 2)")
	print("  Stress-Testing BiomeManager Boundaries & Hermite Smoothstep Interpolation")
	print("=".repeat(80) + "\n")
	
	var tests: Array[Callable] = [
		Callable(self, "test_01_transition_zones_dense_sampling_and_continuity"),
		Callable(self, "test_02_strict_monotonicity_across_all_4_zones"),
		Callable(self, "test_03_hermite_smoothstep_derivative_and_s_curve_properties"),
		Callable(self, "test_04_floating_point_edge_cases_and_clamping"),
		Callable(self, "test_05_returned_palette_defensive_immutability"),
		Callable(self, "test_06_signal_dispatch_across_boundaries")
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
	
	if failure_log.size() > 0:
		print("FAILURES SUMMARY:")
		for f in failure_log:
			printerr("  - " + f)
		print("=".repeat(80) + "\n")
	
	await process_frame
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

# ==============================================================================
# ASSERTION HELPERS
# ==============================================================================
func assert_true(condition: bool, message: String) -> void:
	total_assertions += 1
	if not condition:
		failed_assertions += 1
		var err = "[FAIL] [%s] %s" % [current_test, message]
		failure_log.append(err)
		printerr("    " + err)

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_eq(actual, expected, message: String) -> void:
	assert_true(actual == expected, "%s (Expected: %s, Actual: %s)" % [message, str(expected), str(actual)])

func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	var diff = absf(actual - expected)
	assert_true(diff <= tolerance, "%s (Expected: %f, Actual: %f, Diff: %f, Tol: %f)" % [message, expected, actual, diff, tolerance])

func assert_gte(actual: float, expected: float, message: String) -> void:
	assert_true(actual >= expected - 1e-6, "%s (Expected >= %f, Actual: %f)" % [message, expected, actual])

func assert_lte(actual: float, expected: float, message: String) -> void:
	assert_true(actual <= expected + 1e-6, "%s (Expected <= %f, Actual: %f)" % [message, expected, actual])

func assert_gt(actual: float, expected: float, message: String) -> void:
	assert_true(actual > expected + 1e-6, "%s (Expected > %f, Actual: %f)" % [message, expected, actual])

func assert_lt(actual: float, expected: float, message: String) -> void:
	assert_true(actual < expected - 1e-6, "%s (Expected < %f, Actual: %f)" % [message, expected, actual])

# ==============================================================================
# TEST 1: Dense Sampling & Strict Continuity Across All 4 Transition Zones
# Ranges: [940m..1060m], [1940m..2060m], [2940m..3060m], [3940m..4060m]
# ==============================================================================
func test_01_transition_zones_dense_sampling_and_continuity() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	for b_idx in range(BOUNDARIES.size()):
		var boundary_m: float = BOUNDARIES[b_idx]
		var from_idx: int = b_idx
		var to_idx: int = b_idx + 1
		var pal_from: Dictionary = BiomeManagerClass.BIOME_PALETTES[from_idx]
		var pal_to: Dictionary = BiomeManagerClass.BIOME_PALETTES[to_idx]
		
		var start_sample: float = boundary_m - 60.0
		var end_sample: float = boundary_m + 60.0
		var step_m: float = 0.5 # Dense 0.5m sampling (241 steps per zone)
		
		var steps: int = int(round((end_sample - start_sample) / step_m))
		var prev_pal: Dictionary = {}
		var prev_dist: float = start_sample
		
		# Sample point 0
		bm.update_distance(start_sample)
		prev_pal = bm.get_active_palette()
		
		var max_color_delta: float = 0.0
		var max_float_delta: float = 0.0
		
		for i in range(1, steps + 1):
			var dist: float = start_sample + float(i) * step_m
			bm.update_distance(dist)
			var cur_pal = bm.get_active_palette()
			
			# Check continuity across all color channels
			for ck in COLOR_KEYS:
				var c_prev: Color = prev_pal[ck]
				var c_cur: Color = cur_pal[ck]
				var d_r: float = absf(c_cur.r - c_prev.r)
				var d_g: float = absf(c_cur.g - c_prev.g)
				var d_b: float = absf(c_cur.b - c_prev.b)
				var d_a: float = absf(c_cur.a - c_prev.a)
				
				var max_c: float = maxf(maxf(d_r, d_g), maxf(d_b, d_a))
				if max_c > max_color_delta:
					max_color_delta = max_c
				
				# Maximum theoretical delta per 0.5m step in 100m window:
				# max slope = 1.5 * delta_val / 100m = 0.015 * delta_val per meter
				# for 0.5m, max delta <= 0.0075 * delta_val <= 0.0075 * 1.0 = 0.0075
				# If there were a snap/jump discontinuity, delta would jump by > 0.02
				assert_lte(max_c, 0.015, "Boundary %.0fm: Color key %s continuous at %.1fm (step delta: %f)" % [boundary_m, ck, dist, max_c])
				
			# Check continuity across all float channels
			for fk in FLOAT_KEYS:
				var f_prev: float = prev_pal[fk]
				var f_cur: float = cur_pal[fk]
				var d_f: float = absf(f_cur - f_prev)
				if d_f > max_float_delta:
					max_float_delta = d_f
				assert_lte(d_f, 0.015, "Boundary %.0fm: Float key %s continuous at %.1fm (step delta: %f)" % [boundary_m, fk, dist, d_f])
				
			prev_pal = cur_pal
			prev_dist = dist
			
		print("    Boundary %.0fm [Zone %d->%d]: 241 samples tested. Max color step delta: %.5f, max float step delta: %.5f" % [
			boundary_m, from_idx, to_idx, max_color_delta, max_float_delta
		])
		
		# Specific endpoint & midpoint boundary continuity check with micro-steps
		# 1. Entrance boundary: B - 50.0m
		bm.update_distance(boundary_m - 50.001)
		var pal_before_entry = bm.get_active_palette()
		bm.update_distance(boundary_m - 50.0)
		var pal_at_entry = bm.get_active_palette()
		bm.update_distance(boundary_m - 49.999)
		var pal_after_entry = bm.get_active_palette()
		
		for ck in COLOR_KEYS:
			var c_before: Color = pal_before_entry[ck]
			var c_at: Color = pal_at_entry[ck]
			var c_after: Color = pal_after_entry[ck]
			assert_almost_eq(c_at.r, c_before.r, 1e-5, "Entrance continuity before->at for %s at %.0fm" % [ck, boundary_m])
			assert_almost_eq(c_after.r, c_at.r, 1e-4, "Entrance continuity at->after for %s at %.0fm" % [ck, boundary_m])
			
		# 2. Midpoint boundary: B
		bm.update_distance(boundary_m - 0.001)
		var pal_before_mid = bm.get_active_palette()
		bm.update_distance(boundary_m)
		var pal_at_mid = bm.get_active_palette()
		bm.update_distance(boundary_m + 0.001)
		var pal_after_mid = bm.get_active_palette()
		
		for ck in COLOR_KEYS:
			var c_mid_before: Color = pal_before_mid[ck]
			var c_mid: Color = pal_at_mid[ck]
			var c_mid_after: Color = pal_after_mid[ck]
			assert_almost_eq(c_mid.r, c_mid_before.r, 1e-4, "Midpoint continuity before->mid for %s at %.0fm" % [ck, boundary_m])
			assert_almost_eq(c_mid_after.r, c_mid.r, 1e-4, "Midpoint continuity mid->after for %s at %.0fm" % [ck, boundary_m])
			
		# 3. Exit boundary: B + 50.0m
		bm.update_distance(boundary_m + 49.999)
		var pal_before_exit = bm.get_active_palette()
		bm.update_distance(boundary_m + 50.0)
		var pal_at_exit = bm.get_active_palette()
		bm.update_distance(boundary_m + 50.001)
		var pal_after_exit = bm.get_active_palette()
		
		for ck in COLOR_KEYS:
			var c_exit_before: Color = pal_before_exit[ck]
			var c_exit: Color = pal_at_exit[ck]
			var c_exit_after: Color = pal_after_exit[ck]
			assert_almost_eq(c_exit.r, c_exit_before.r, 1e-4, "Exit continuity before->at for %s at %.0fm" % [ck, boundary_m])
			assert_almost_eq(c_exit_after.r, c_exit.r, 1e-5, "Exit continuity at->after for %s at %.0fm" % [ck, boundary_m])
			
	bm.free()

# ==============================================================================
# TEST 2: Strict Monotonicity Across All 4 Transition Zones
# Every channel must vary monotonically (increasing, decreasing, or constant)
# ==============================================================================
func test_02_strict_monotonicity_across_all_4_zones() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	var total_channels_tested: int = 0
	
	for b_idx in range(BOUNDARIES.size()):
		var boundary_m: float = BOUNDARIES[b_idx]
		var idx_a: int = b_idx
		var idx_b: int = b_idx + 1
		var pal_a: Dictionary = BiomeManagerClass.BIOME_PALETTES[idx_a]
		var pal_b: Dictionary = BiomeManagerClass.BIOME_PALETTES[idx_b]
		
		# Collect 101 sample points across [B - 50.0 .. B + 50.0] with 1m increments
		var samples: Array[Dictionary] = []
		for m in range(0, 101):
			var d: float = (boundary_m - 50.0) + float(m)
			bm.update_distance(d)
			samples.append(bm.get_active_palette())
			
		# Check all 10 Color keys x 4 channels (R, G, B, A) = 40 channels per boundary
		for ck in COLOR_KEYS:
			var ca: Color = pal_a[ck]
			var cb: Color = pal_b[ck]
			
			var channel_names = ["r", "g", "b", "a"]
			for ch in channel_names:
				total_channels_tested += 1
				var val_start: float = ca[ch]
				var val_end: float = cb[ch]
				var delta: float = val_end - val_start
				
				if delta > 1e-4:
					# Strictly non-decreasing
					for s_idx in range(samples.size() - 1):
						var v1: float = samples[s_idx][ck][ch]
						var v2: float = samples[s_idx + 1][ck][ch]
						assert_gte(v2, v1, "Boundary %.0fm: %s.%s must increase monotonically (v1=%f, v2=%f at step %d)" % [
							boundary_m, ck, ch, v1, v2, s_idx
						])
				elif delta < -1e-4:
					# Strictly non-increasing
					for s_idx in range(samples.size() - 1):
						var v1: float = samples[s_idx][ck][ch]
						var v2: float = samples[s_idx + 1][ck][ch]
						assert_lte(v2, v1, "Boundary %.0fm: %s.%s must decrease monotonically (v1=%f, v2=%f at step %d)" % [
							boundary_m, ck, ch, v1, v2, s_idx
						])
				else:
					# Constant channel
					for s_idx in range(samples.size()):
						var v: float = samples[s_idx][ck][ch]
						assert_almost_eq(v, val_start, 1e-4, "Boundary %.0fm: %s.%s must remain constant (v=%f)" % [
							boundary_m, ck, ch, v
						])
						
		# Check all 3 float keys
		for fk in FLOAT_KEYS:
			total_channels_tested += 1
			var fa: float = pal_a[fk]
			var fb: float = pal_b[fk]
			var delta: float = fb - fa
			
			if delta > 1e-4:
				for s_idx in range(samples.size() - 1):
					var v1: float = samples[s_idx][fk]
					var v2: float = samples[s_idx + 1][fk]
					assert_gte(v2, v1, "Boundary %.0fm: %s must increase monotonically (v1=%f, v2=%f)" % [
						boundary_m, fk, v1, v2
					])
			elif delta < -1e-4:
				for s_idx in range(samples.size() - 1):
					var v1: float = samples[s_idx][fk]
					var v2: float = samples[s_idx + 1][fk]
					assert_lte(v2, v1, "Boundary %.0fm: %s must decrease monotonically (v1=%f, v2=%f)" % [
						boundary_m, fk, v1, v2
					])
			else:
				for s_idx in range(samples.size()):
					var v: float = samples[s_idx][fk]
					assert_almost_eq(v, fa, 1e-4, "Boundary %.0fm: %s must remain constant (v=%f)" % [
						boundary_m, fk, v
					])
					
		print("    Boundary %.0fm: verified monotonicity across 43 individual channels over 101 sample distances" % boundary_m)
		
	print("    Total monotonic channel tracks verified across all 4 zones: %d" % total_channels_tested)
	bm.free()

# ==============================================================================
# TEST 3: Hermite Smoothstep S-Curve Properties & Derivative Invariants
# S(s) = 3s^2 - 2s^3, dS/ds = 6s(1-s)
# At edges (s=0, s=1): derivative = 0
# At midpoint (s=0.5): derivative = 1.5 (maximum slope)
# ==============================================================================
func test_03_hermite_smoothstep_derivative_and_s_curve_properties() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	# Verify mathematical properties for all 4 boundaries
	for boundary_m in BOUNDARIES:
		# Midpoint test: exact s = 0.5 => blend_factor = 0.500000
		bm.update_distance(boundary_m)
		var pal_mid = bm.get_active_palette()
		var b_idx: int = int(round(boundary_m / 1000.0))
		var pal_from = BiomeManagerClass.BIOME_PALETTES[b_idx - 1]
		var pal_to = BiomeManagerClass.BIOME_PALETTES[b_idx]
		
		for ck in COLOR_KEYS:
			var exp_mid: Color = pal_from[ck].lerp(pal_to[ck], 0.5)
			assert_almost_eq(pal_mid[ck].r, exp_mid.r, 1e-4, "Midpoint %.0fm: %s.r exactly 50%% blend" % [boundary_m, ck])
			assert_almost_eq(pal_mid[ck].g, exp_mid.g, 1e-4, "Midpoint %.0fm: %s.g exactly 50%% blend" % [boundary_m, ck])
			assert_almost_eq(pal_mid[ck].b, exp_mid.b, 1e-4, "Midpoint %.0fm: %s.b exactly 50%% blend" % [boundary_m, ck])
			
		for fk in FLOAT_KEYS:
			var exp_f: float = lerpf(pal_from[fk], pal_to[fk], 0.5)
			assert_almost_eq(pal_mid[fk], exp_f, 1e-4, "Midpoint %.0fm: %s exactly 50%% blend" % [boundary_m, fk])
			
		# S-curve symmetry test: blend(B - d) + blend(B + d) == 1.0
		for delta_test in [5.0, 15.0, 25.0, 35.0, 45.0]:
			bm.update_distance(boundary_m - delta_test)
			var pal_left = bm.get_active_palette()
			bm.update_distance(boundary_m + delta_test)
			var pal_right = bm.get_active_palette()
			
			for ck in COLOR_KEYS:
				var c_left: Color = pal_left[ck]
				var c_right: Color = pal_right[ck]
				var c_from: Color = pal_from[ck]
				var c_to: Color = pal_to[ck]
				
				# (c_left - c_from) + (c_right - c_from) should equal (c_to - c_from)
				var sum_r = (c_left.r - c_from.r) + (c_right.r - c_from.r)
				var target_r = c_to.r - c_from.r
				assert_almost_eq(sum_r, target_r, 1e-4, "S-curve symmetry for %s.r at delta %.1fm (boundary %.0fm)" % [ck, delta_test, boundary_m])
				
		# Numerical derivative test:
		# At s = 0.01 (x = boundary_m - 49.0): ds/dx = 0.01, dS/ds = 6*(0.01)*(0.99) = 0.0594
		# dS/dx = 0.000594 per meter.
		# At s = 0.50 (x = boundary_m): dS/ds = 6*(0.5)*(0.5) = 1.5
		# dS/dx = 0.0150 per meter.
		# Ratio (edge slope / midpoint slope) = 0.000594 / 0.0150 = 0.0396 (approaches zero!).
		var h: float = 1.0 # 1m step
		
		# Edge 1 (Left edge, s near 0): B - 50m to B - 49m
		bm.update_distance(boundary_m - 50.0)
		var p_edge_0 = bm.get_active_palette()
		bm.update_distance(boundary_m - 49.0)
		var p_edge_1 = bm.get_active_palette()
		
		# Midpoint: B - 0.5m to B + 0.5m
		bm.update_distance(boundary_m - 0.5)
		var p_mid_0 = bm.get_active_palette()
		bm.update_distance(boundary_m + 0.5)
		var p_mid_1 = bm.get_active_palette()
		
		# Edge 2 (Right edge, s near 1): B + 49m to B + 50m
		bm.update_distance(boundary_m + 49.0)
		var p_edge2_0 = bm.get_active_palette()
		bm.update_distance(boundary_m + 50.0)
		var p_edge2_1 = bm.get_active_palette()
		
		# Find a color key and channel with significant difference (> 0.05)
		var test_key = "mountain_tint"
		var test_channel = "r"
		var max_diff: float = 0.0
		for ck in COLOR_KEYS:
			for ch in ["r", "g", "b"]:
				var diff: float = absf(pal_to[ck][ch] - pal_from[ck][ch])
				if diff > max_diff:
					max_diff = diff
					test_key = ck
					test_channel = ch
		
		var slope_left: float = absf(p_edge_1[test_key][test_channel] - p_edge_0[test_key][test_channel]) / h
		var slope_mid: float = absf(p_mid_1[test_key][test_channel] - p_mid_0[test_key][test_channel]) / h
		var slope_right: float = absf(p_edge2_1[test_key][test_channel] - p_edge2_0[test_key][test_channel]) / h
		
		var ratio_left: float = slope_left / slope_mid
		var ratio_right: float = slope_right / slope_mid
		
		print("    Boundary %.0fm (%s.%s total delta: %.3f):" % [boundary_m, test_key, test_channel, max_diff])
		print("      Left edge slope (s=0..0.01): %.6f/m (ratio to mid: %.4f)" % [slope_left, ratio_left])
		print("      Midpoint slope (s=0.50):     %.6f/m" % slope_mid)
		print("      Right edge slope (s=0.99..1): %.6f/m (ratio to mid: %.4f)" % [slope_right, ratio_right])
		
		assert_lte(ratio_left, 0.06, "Left edge slope approaches zero relative to midpoint (< 6%%)")
		assert_lte(ratio_right, 0.06, "Right edge slope approaches zero relative to midpoint (< 6%%)")
		assert_gt(slope_mid, slope_left * 10.0, "Midpoint slope is an order of magnitude steeper than edge")
			
	bm.free()

# ==============================================================================
# TEST 4: Floating-Point Edge Cases & Clamping
# Negative coordinates, exact boundary floats, clamping at 5000m, epsilon nudges
# ==============================================================================
func test_04_floating_point_edge_cases_and_clamping() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	var pal_0 = BiomeManagerClass.BIOME_PALETTES[0]
	var pal_4 = BiomeManagerClass.BIOME_PALETTES[4]
	
	# 1. Negative distances: must clamp strictly to 0.0 (Biome 0)
	var negative_coords: Array[float] = [-10000.0, -100.0, -1.0, -0.0001, -0.0]
	for neg in negative_coords:
		bm.update_distance(neg)
		assert_eq(bm.current_distance_m, 0.0, "Negative distance %.4f clamped to 0.0" % neg)
		var p = bm.get_active_palette()
		assert_eq(p["id"], "snowy_plains", "Negative distance yields Biome 0 id")
		assert_almost_eq(p.sky_zenith.r, pal_0.sky_zenith.r, 1e-5, "Negative distance yields exact Biome 0 zenith")
		assert_almost_eq(p.wind_intensity, pal_0.wind_intensity, 1e-5, "Negative distance yields exact Biome 0 wind")
		
	# 2. Exceeding route length: must clamp strictly to 5000.0 (Biome 4)
	var overflow_coords: Array[float] = [5000.0, 5000.0001, 5001.0, 5500.0, 100000.0]
	for oflow in overflow_coords:
		bm.update_distance(oflow)
		assert_eq(bm.current_distance_m, 5000.0, "Overflow distance %.4f clamped to 5000.0" % oflow)
		var p = bm.get_active_palette()
		assert_eq(p["id"], "station_outskirts", "Overflow distance yields Biome 4 id")
		assert_almost_eq(p.sky_zenith.r, pal_4.sky_zenith.r, 1e-5, "Overflow distance yields exact Biome 4 zenith")
		assert_almost_eq(p.wind_intensity, pal_4.wind_intensity, 1e-5, "Overflow distance yields exact Biome 4 wind")
		
	# 3. Mid-biome points far outside transition: must not trigger transition blend
	var interior_points: Array[float] = [500.0, 1500.0, 2500.0, 3500.0, 4500.0]
	for i in range(interior_points.size()):
		var mid_dist = interior_points[i]
		bm.update_distance(mid_dist)
		var p = bm.get_active_palette()
		var exp_pal = BiomeManagerClass.BIOME_PALETTES[i]
		assert_eq(p["id"], exp_pal["id"], "Interior point %.0fm matches Biome %d" % [mid_dist, i])
		assert_almost_eq(p.sky_zenith.r, exp_pal.sky_zenith.r, 1e-5, "Interior point %.0fm has unblended zenith" % mid_dist)
		assert_almost_eq(p.mountain_tint.r, exp_pal.mountain_tint.r, 1e-5, "Interior point %.0fm has unblended mountain tint" % mid_dist)
		
	# 4. Exact float boundary transitions
	for b_m in BOUNDARIES:
		var exact_points = [
			b_m - 50.0, # entry
			b_m,        # midpoint
			b_m + 50.0  # exit
		]
		for pt in exact_points:
			bm.update_distance(pt)
			var p = bm.get_active_palette()
			# Verify no NaN or Inf
			for ck in COLOR_KEYS:
				var c: Color = p[ck]
				assert_false(is_nan(c.r) or is_inf(c.r), "No NaN/Inf in %s.r at exact float %.1f" % [ck, pt])
				assert_false(is_nan(c.g) or is_inf(c.g), "No NaN/Inf in %s.g at exact float %.1f" % [ck, pt])
				assert_false(is_nan(c.b) or is_inf(c.b), "No NaN/Inf in %s.b at exact float %.1f" % [ck, pt])
				assert_false(is_nan(c.a) or is_inf(c.a), "No NaN/Inf in %s.a at exact float %.1f" % [ck, pt])
			for fk in FLOAT_KEYS:
				var f: float = p[fk]
				assert_false(is_nan(f) or is_inf(f), "No NaN/Inf in %s at exact float %.1f" % [fk, pt])
				
	# 5. Micro-epsilon boundary crossings: B - 50.0 +/- 1e-5, B +/- 1e-5, B + 50.0 +/- 1e-5
	for b_m in BOUNDARIES:
		var epsilons = [-1e-4, 0.0, 1e-4]
		for e in epsilons:
			bm.update_distance(b_m - 50.0 + e)
			var p_ent = bm.get_active_palette()
			assert_false(p_ent.is_empty(), "Palette valid at entry micro-step")
			
			bm.update_distance(b_m + e)
			var p_mid = bm.get_active_palette()
			assert_false(p_mid.is_empty(), "Palette valid at mid micro-step")
			
			bm.update_distance(b_m + 50.0 + e)
			var p_ext = bm.get_active_palette()
			assert_false(p_ext.is_empty(), "Palette valid at exit micro-step")
			
	print("    Floating-point edge cases (negative, overflow 5000m, exact floats, epsilon steps) passed cleanly")
	bm.free()

# ==============================================================================
# TEST 5: Defensive Immutability of Returned Palette
# Calling get_active_palette() must return an isolated duplicate
# ==============================================================================
func test_05_returned_palette_defensive_immutability() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	bm.update_distance(975.0)
	var snapshot1 = bm.get_active_palette()
	var original_r = snapshot1.sky_zenith.r
	
	# Adversarial caller mutates returned dictionary
	snapshot1["sky_zenith"] = Color(0.999, 0.999, 0.999, 1.0)
	snapshot1["wind_intensity"] = 999.0
	snapshot1["new_malicious_key"] = "hacked"
	
	# Internal state must remain untouched
	var snapshot2 = bm.get_active_palette()
	assert_almost_eq(snapshot2.sky_zenith.r, original_r, 1e-5, "Internal sky_zenith.r protected from external mutation")
	assert_lte(snapshot2.wind_intensity, 1.0, "Internal wind_intensity protected from external mutation")
	assert_false(snapshot2.has("new_malicious_key"), "Internal palette free of external key injection")
	
	# Further distance updates must not reference old mutated snapshots
	bm.update_distance(1000.0)
	var snapshot3 = bm.get_active_palette()
	assert_false(snapshot3.has("new_malicious_key"), "Subsequent distance update maintains clean state")
	
	print("    Defensive immutability verified: get_active_palette() isolates internal state")
	bm.free()

# ==============================================================================
# TEST 6: Signal Dispatch Across Boundaries
# biome_transition_updated, biome_changed, ambient_palette_updated
# ==============================================================================
func test_06_signal_dispatch_across_boundaries() -> void:
	var bm = BiomeManagerClass.new()
	bm._ready()
	
	var transition_signals: Array[Dictionary] = []
	var biome_changed_signals: Array[Dictionary] = []
	var ambient_signals: Array[Dictionary] = []
	
	bm.connect("biome_transition_updated", func(from_idx: int, to_idx: int, blend: float):
		transition_signals.append({"from": from_idx, "to": to_idx, "blend": blend})
	)
	bm.connect("biome_changed", func(b_idx: int, info: Dictionary):
		biome_changed_signals.append({"index": b_idx, "id": info.get("id", "")})
	)
	bm.connect("ambient_palette_updated", func(pal: Dictionary):
		ambient_signals.append(pal.duplicate(true))
	)
	
	# Move into Zone 1: 940m -> 975m -> 1000m -> 1025m -> 1060m
	bm.update_distance(940.0)  # Pure Biome 0
	bm.update_distance(975.0)  # In transition (s=0.25, blend=0.15625)
	bm.update_distance(1000.0) # Midpoint (s=0.50, blend=0.50000)
	bm.update_distance(1025.0) # In transition (s=0.75, blend=0.84375)
	bm.update_distance(1060.0) # Exited transition => Pure Biome 1
	
	# Verify biome_transition_updated was fired 3 times during transition
	assert_eq(transition_signals.size(), 3, "Transition signal emitted 3 times during transition zone")
	if transition_signals.size() == 3:
		assert_eq(transition_signals[0]["from"], 0, "Signal 1 from_idx is 0")
		assert_eq(transition_signals[0]["to"], 1, "Signal 1 to_idx is 1")
		assert_almost_eq(transition_signals[0]["blend"], 0.15625, 1e-4, "Signal 1 blend is 0.15625 at 975m")
		
		assert_eq(transition_signals[1]["from"], 0, "Signal 2 from_idx is 0")
		assert_eq(transition_signals[1]["to"], 1, "Signal 2 to_idx is 1")
		assert_almost_eq(transition_signals[1]["blend"], 0.50000, 1e-4, "Signal 2 blend is 0.50000 at 1000m")
		
		assert_eq(transition_signals[2]["from"], 0, "Signal 3 from_idx is 0")
		assert_eq(transition_signals[2]["to"], 1, "Signal 3 to_idx is 1")
		assert_almost_eq(transition_signals[2]["blend"], 0.84375, 1e-4, "Signal 3 blend is 0.84375 at 1025m")
		
	# Verify biome_changed was fired when entering Biome 1 at 1060m
	assert_gte(float(biome_changed_signals.size()), 1.0, "biome_changed emitted upon transition exit into Biome 1")
	var found_biome_1 = false
	for sig in biome_changed_signals:
		if sig["index"] == 1:
			found_biome_1 = true
			assert_eq(sig["id"], "abandoned_camp", "biome_changed emitted with id 'abandoned_camp'")
	assert_true(found_biome_1, "biome_changed received for Biome 1")
	
	# Verify ambient_palette_updated was fired on all 5 distance updates
	assert_eq(ambient_signals.size(), 5, "ambient_palette_updated fired on all 5 distance updates")
	
	print("    Signal dispatch verified: transition blend updates, biome change, and ambient updates emitted correctly")
	bm.free()
