# tests/test_m4_thermo_weather_upgrades.gd
class_name TestM4ThermoWeatherUpgrades
extends RefCounted

## Comprehensive Milestone 4 (M4_THERMODYNAMICS_WEATHER_UPGRADES_SURVIVAL) Test Suite.
## Validates:
## - F38, F39, F40, F41, F45, F46: Cabin thermodynamics, stove burn, Newton cooling, indoor hypothermia & warmth recovery
## - F42, F43, F44, F51: WeatherManager 300s Day/Night cycle, polar contrast CanvasModulate, blizzard distance triggers & warning
## - F32, F33, F34, F35, F36: Leg repairs (+20%/scrap), Upgrades (Insulation, Engine, Legs), UpgradePanel UI & lockout
## - F06, F47: Deadlock detection engine with zero false positives & 3.0s temporal grace period

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const WeatherManager = preload("res://scripts/world/WeatherManager.gd")
const UpgradePanel = preload("res://scripts/ui/UpgradePanel.gd")
const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")
const SoundManagerScript = preload("res://scripts/autoload/SoundManager.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")

var suite_name: String = "M4: Thermodynamics, Weather, Upgrades & Deadlock Engine"

func run_suite(runner) -> void:
	test_01_weather_manager_diurnal_cycle(runner)
	test_02_outside_temperature_curve_and_blizzard_drop(runner)
	test_03_canvas_modulate_polar_contrast(runner)
	test_04_blizzard_distance_triggers_and_warning(runner)
	test_05_snow_particles_system(runner)
	test_06_gamestate_thermodynamics_loop(runner)
	test_07_stove_fuel_burn_and_auto_extinguish(runner)
	test_08_cabin_hypothermia_and_warmth_recovery(runner)
	test_09_leg_repair_and_outdoor_lockout(runner)
	test_10_upgrade_system_costs_and_effects(runner)
	test_11_upgrade_panel_modal_ui(runner)
	test_12_deadlock_detection_zero_false_positives(runner)
	test_13_deadlock_detection_true_positive_and_grace_period(runner)

# ------------------------------------------------------------------------------
# TEST 01: Diurnal Cycle Progression & Russian Time Formatting
# ------------------------------------------------------------------------------
func test_01_weather_manager_diurnal_cycle(runner) -> void:
	runner.start_test("test_01_weather_manager_diurnal_cycle")
	
	# Period is 300s real time = 24.0 in-game hours (0.08 hours/second)
	# Advance 75s (which is 1/4 of 300s = 6.0 in-game hours) from 0.0h
	var t0: float = WeatherManager.advance_time_of_day(0.0, 75.0, 300.0)
	runner.assert_almost_eq(t0, 6.0, 0.01, "Advance 75s (6h) from 0.0h")
	
	# Rollover: 23.0h + 25.0s (2.0 hours) = 25.0h -> 1.0h
	var t_rollover: float = WeatherManager.advance_time_of_day(23.0, 25.0, 300.0)
	runner.assert_almost_eq(t_rollover, 1.0, 0.01, "Rollover across 24h period")
	
	# Format "HH:MM" (takes time_of_day in hours)
	runner.assert_eq(WeatherManager.format_time_string(0.0), "00:00", "0h -> 00:00")
	runner.assert_eq(WeatherManager.format_time_string(6.0), "06:00", "6h -> 06:00")
	runner.assert_eq(WeatherManager.format_time_string(12.0), "12:00", "12h -> 12:00")
	runner.assert_eq(WeatherManager.format_time_string(18.0), "18:00", "18h -> 18:00")
	
	# Sun factor: 0.0 at midnight (0.0h), 1.0 at noon (12.0h), 0.5 at dawn (6.8h)
	runner.assert_almost_eq(WeatherManager.calculate_sun_factor(0.0), 0.0, 0.02, "Sun factor midnight")
	runner.assert_almost_eq(WeatherManager.calculate_sun_factor(12.0), 1.0, 0.02, "Sun factor noon")
	runner.assert_almost_eq(WeatherManager.calculate_sun_factor(6.8), 0.5, 0.05, "Sun factor dawn")
	
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 02: Outside Temperature Diurnal Curve & Blizzard Penalty
# ------------------------------------------------------------------------------
func test_02_outside_temperature_curve_and_blizzard_drop(runner) -> void:
	runner.start_test("test_02_outside_temperature_curve_and_blizzard_drop")
	
	# Calm weather: day_temp = -10.0, night_temp = -20.0
	# Midnight (sun = 0.0) -> -20.0°C
	var temp_midnight: float = WeatherManager.calculate_outside_temperature(-10.0, -20.0, 0.0, 0.0)
	runner.assert_almost_eq(temp_midnight, -20.0, 0.01, "Calm midnight outdoor temp is -20°C")
	
	# Noon (sun = 1.0) -> -10.0°C (+10°C peak swing)
	var temp_noon: float = WeatherManager.calculate_outside_temperature(-10.0, -20.0, 1.0, 0.0)
	runner.assert_almost_eq(temp_noon, -10.0, 0.01, "Calm noon outdoor temp is -10°C")
	
	# Full Blizzard (intensity = 1.0): drops by -15°C
	# Midnight blizzard -> -35.0°C
	var temp_blizz_midnight: float = WeatherManager.calculate_outside_temperature(-10.0, -20.0, 0.0, 1.0, -15.0)
	runner.assert_almost_eq(temp_blizz_midnight, -35.0, 0.01, "Blizzard midnight outdoor temp is -35°C")
	
	# Noon blizzard -> -25.0°C
	var temp_blizz_noon: float = WeatherManager.calculate_outside_temperature(-10.0, -20.0, 1.0, 1.0, -15.0)
	runner.assert_almost_eq(temp_blizz_noon, -25.0, 0.01, "Blizzard noon outdoor temp is -25°C")
	
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 03: CanvasModulate High-Contrast Polar Night Tint
# ------------------------------------------------------------------------------
func test_03_canvas_modulate_polar_contrast(runner) -> void:
	runner.start_test("test_03_canvas_modulate_polar_contrast")
	
	# Night tint (midnight = 0.0h)
	var tint_night: Color = WeatherManager.calculate_day_night_tint(0.0)
	# Day tint (noon = 12.0h)
	var tint_day: Color = WeatherManager.calculate_day_night_tint(12.0)
	
	# Midnight color is polar navy blue
	runner.assert_lt(tint_night.r, 0.25, "Polar night red component is deep dark")
	runner.assert_gt(tint_night.b, tint_night.r, "Polar night maintains blue tint")
	
	# Noon color is bright daylight
	runner.assert_gt(tint_day.r, 0.85, "Noon daylight red is bright")
	runner.assert_gt(tint_day.v, 0.90, "Noon daylight value is near 1.0")
	
	# Polar night contrast ratio > 2.5
	var contrast_ratio: float = tint_day.v / maxf(0.05, tint_night.v)
	runner.assert_gt(contrast_ratio, 2.5, "High contrast polar night ratio > 2.5")
	
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 04: Blizzard Distance Triggers (1400m, 3300m) & 20s Warning
# ------------------------------------------------------------------------------
func test_04_blizzard_distance_triggers_and_warning(runner) -> void:
	runner.start_test("test_04_blizzard_distance_triggers_and_warning")
	
	var wm = WeatherManager.new()
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.is_game_active = true
	wm.game_state = gs
	
	# Event definitions verify: 1400m / 40s duration, 3300m / 50s duration
	runner.assert_eq(wm.BLIZZARD_EVENTS.size(), 2, "2 deterministic blizzard events")
	runner.assert_almost_eq(wm.BLIZZARD_EVENTS[0].trigger_distance_m, 1400.0, 0.1, "First blizzard at 1400m")
	runner.assert_almost_eq(wm.BLIZZARD_EVENTS[0].duration_sec, 40.0, 0.1, "First blizzard duration 40s")
	runner.assert_almost_eq(wm.BLIZZARD_EVENTS[1].trigger_distance_m, 3300.0, 0.1, "Second blizzard at 3300m")
	runner.assert_almost_eq(wm.BLIZZARD_EVENTS[1].duration_sec, 50.0, 0.1, "Second blizzard duration 50s")
	
	# Distance before 1400m: IDLE
	gs.distance_traveled = 1350.0
	wm._process_blizzard_lifecycle(gs, 1.0)
	runner.assert_eq(wm.blizzard_phase, wm.BlizzardPhase.IDLE, "Idle before 1400m")
	
	# Distance reaches 1400m: Warning Phase triggered!
	gs.distance_traveled = 1400.0
	wm._process_blizzard_lifecycle(gs, 1.0)
	runner.assert_eq(wm.blizzard_phase, wm.BlizzardPhase.WARNING, "Warning phase triggered at 1400m")
	runner.assert_true(gs.blizzard_warning_active, "GameState blizzard warning active")
	runner.assert_almost_eq(wm.warning_timer, 20.0, 0.1, "Warning countdown initialized to 20s")
	
	# Advance remaining 20.5s: Warning expires, Active Blizzard strikes!
	wm._process_blizzard_lifecycle(gs, 20.5)
	runner.assert_eq(wm.blizzard_phase, wm.BlizzardPhase.ACTIVE, "Active blizzard phase entered")
	runner.assert_false(gs.blizzard_warning_active, "Warning deactivated")
	runner.assert_eq(gs.weather_state, GameState.WeatherState.BLIZZARD, "GameState weather is BLIZZARD")
	
	# Run 40.5s of blizzard duration: Active -> Dissipating
	wm._process_blizzard_lifecycle(gs, 40.5)
	runner.assert_eq(wm.blizzard_phase, wm.BlizzardPhase.DISSIPATING, "Dissipating phase after 40s")
	
	wm._process_blizzard_lifecycle(gs, 3.5)
	runner.assert_eq(wm.blizzard_phase, wm.BlizzardPhase.IDLE, "Returns to idle after dissipation")
	runner.assert_eq(gs.weather_state, GameState.WeatherState.CLEAR, "Weather returns to CLEAR")
	
	gs.free()
	wm.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 05: Global Falling Snow Particles (Calm 60 vs Blizzard 400)
# ------------------------------------------------------------------------------
func test_05_snow_particles_system(runner) -> void:
	runner.start_test("test_05_snow_particles_system")
	
	var wm = WeatherManager.new()
	wm._setup_snow_particles()
	
	runner.assert_true(wm.snow_particles != null, "WeatherSnowParticles node instantiated")
	runner.assert_eq(wm.snow_particles.amount, 60, "Calm snow particle amount is 60")
	runner.assert_true(wm.snow_particles.emitting, "Snow particles emitting by default")
	
	# Trigger blizzard intensity ramp to 1.0
	wm.blizzard_intensity = 1.0
	wm._update_snow_particles(0.1)
	runner.assert_eq(wm.snow_particles.amount, 400, "Blizzard snow particle amount ramps to 400")
	
	# Return to calm
	wm.blizzard_intensity = 0.0
	wm._update_snow_particles(0.1)
	runner.assert_eq(wm.snow_particles.amount, 60, "Calm snow particle returns to 60")
	
	wm.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 06: Cabin Thermodynamics in GameState Loop
# ------------------------------------------------------------------------------
func test_06_gamestate_thermodynamics_loop(runner) -> void:
	runner.start_test("test_06_gamestate_thermodynamics_loop")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.cabin_temperature = 15.0
	gs.outside_temperature = -15.0
	gs.is_stove_on = false
	gs.is_game_active = true
	
	# 1 second of Newton natural cooling with stove OFF:
	# delta_T = 30°C, loss = 0.025 * 30 * 1.0 = 0.75°C -> 14.25°C
	gs._process_thermodynamics_and_survival(1.0)
	runner.assert_almost_eq(gs.cabin_temperature, 14.25, 0.02, "Cabin cools 0.75°C naturally in 1s")
	
	# Turn stove ON: +1.1°C/s gain, -loss
	# Next second: temp ~14.25 - (0.025 * 29.25) + 1.1 = 14.25 - 0.731 + 1.1 = 14.619°C
	gs.is_stove_on = true
	gs._process_thermodynamics_and_survival(1.0)
	runner.assert_gt(gs.cabin_temperature, 14.25, "Stove heating overcomes natural heat loss")
	
	# Cabin temperature ceiling: cannot exceed 24.0°C
	gs.cabin_temperature = 23.9
	gs.outside_temperature = 10.0
	gs.is_stove_on = true
	gs._process_thermodynamics_and_survival(2.0)
	runner.assert_almost_eq(gs.cabin_temperature, 24.0, 0.01, "Cabin temperature capped at 24°C ceiling")
	
	# Insulation upgrade effect: reduces heat loss by 45%
	gs.cabin_temperature = 15.0
	gs.outside_temperature = -15.0
	gs.is_stove_on = false
	gs.upgrades["insulation"] = true
	gs._process_thermodynamics_and_survival(1.0)
	# Without insulation: loss = 0.75 -> 14.25
	# With insulation: loss = 0.75 * 0.55 = 0.4125 -> temp = 14.5875
	runner.assert_almost_eq(gs.cabin_temperature, 14.5875, 0.02, "Insulation upgrade reduces heat loss by 45%")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 07: Stove Fuel Consumption, Auto-Extinguish & Audio
# ------------------------------------------------------------------------------
func test_07_stove_fuel_burn_and_auto_extinguish(runner) -> void:
	runner.start_test("test_07_stove_fuel_burn_and_auto_extinguish")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.fuel = 1.0
	gs.is_stove_on = true
	gs.is_game_active = true
	
	var extinguished_reasons: Array = []
	gs.stove_extinguished.connect(func(reason): extinguished_reasons.append(reason))
	
	# Burn 2.0s at 0.25 fuel/s -> burns 0.5 fuel
	gs._process_thermodynamics_and_survival(2.0)
	runner.assert_almost_eq(gs.fuel, 0.5, 0.01, "Stove burns exactly 0.25 fuel/s (spent 0.5 in 2s)")
	runner.assert_true(gs.is_stove_on, "Stove remains ON while fuel remains")
	
	# Burn remaining 0.5 fuel: reaches 0.0 -> auto-extinguish
	gs._process_thermodynamics_and_survival(3.0)
	runner.assert_almost_eq(gs.fuel, 0.0, 0.01, "Fuel depleted to 0.0")
	runner.assert_false(gs.is_stove_on, "Stove automatically extinguished when fuel reaches 0")
	runner.assert_gte(extinguished_reasons.size(), 1, "stove_extinguished signal emitted")
	runner.assert_true("топливо" in extinguished_reasons[0].to_lower() or "fuel" in extinguished_reasons[0].to_lower(), "Extinguish reason mentions fuel")
	
	# Outdoor guard: cannot toggle stove while outside
	gs.fuel = 10.0
	gs.is_player_outside = true
	var toggled = gs.toggle_stove()
	runner.assert_false(toggled, "toggle_stove rejected when player is outside")
	runner.assert_false(gs.is_stove_on, "Stove remains OFF when outdoor player attempts toggle")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 08: Indoor Hypothermia & Warmth Recovery
# ------------------------------------------------------------------------------
func test_08_cabin_hypothermia_and_warmth_recovery(runner) -> void:
	runner.start_test("test_08_cabin_hypothermia_and_warmth_recovery")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.is_game_active = true
	gs.is_player_outside = false
	gs.player_health = 100.0
	
	# Sub-zero cabin temperature: -10°C
	# Cold damage: abs(-10) * 0.5 * 1.0 = 5.0 damage/s
	gs.cabin_temperature = -10.0
	gs.is_stove_on = false
	gs._process_thermodynamics_and_survival(1.0)
	runner.assert_almost_eq(gs.player_health, 95.0, 0.1, "Sub-zero cabin inflicts cold damage (5 HP at -10°C)")
	
	# Warm cabin temperature: +15°C (>= 10°C)
	# Warmth recovery: +0.5 HP/s
	gs.cabin_temperature = 15.0
	gs._process_thermodynamics_and_survival(2.0)
	runner.assert_almost_eq(gs.player_health, 96.0, 0.1, "Warm cabin recovers health (+1.0 HP in 2s)")
	
	# Fatal freeze trigger: health drops to 0 from sub-zero temperatures
	gs.player_health = 2.0
	gs.cabin_temperature = -10.0
	gs._process_thermodynamics_and_survival(1.0)
	runner.assert_lte(gs.player_health, 0.0, "Player health dropped to zero")
	runner.assert_true(gs.is_game_over, "Game over triggered by fatal freeze")
	runner.assert_true("freeze" in gs.game_over_reason.to_lower(), "Game over reason contains 'freeze'")
	runner.assert_true("переохлаждение" in gs.game_over_reason.to_lower(), "Game over reason contains 'Переохлаждение'")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 09: Leg Repair Mechanics & Outdoor Lockout
# ------------------------------------------------------------------------------
func test_09_leg_repair_and_outdoor_lockout(runner) -> void:
	runner.start_test("test_09_leg_repair_and_outdoor_lockout")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.scrap = 2.0
	gs.leg_durability = 60.0
	
	# Normal repair: 1 scrap for +20% durability
	var ok1: bool = gs.repair_legs(20.0, 1.0)
	runner.assert_true(ok1, "Repair legs succeeds with 1 scrap")
	runner.assert_almost_eq(gs.leg_durability, 80.0, 0.01, "Durability restored from 60% to 80%")
	runner.assert_almost_eq(gs.scrap, 1.0, 0.01, "1 scrap deducted")
	
	# Repair capped at 100%: 1 scrap for 80% -> 100% (not 105%)
	gs.leg_durability = 95.0
	var ok2: bool = gs.repair_legs(20.0, 1.0)
	runner.assert_true(ok2, "Repair near cap succeeds")
	runner.assert_almost_eq(gs.leg_durability, 100.0, 0.01, "Durability capped at 100%")
	runner.assert_almost_eq(gs.scrap, 0.0, 0.01, "1 scrap deducted")
	
	# Rejected when 0 scrap
	var ok3: bool = gs.repair_legs(20.0, 1.0)
	runner.assert_false(ok3, "Repair rejected when 0 scrap available")
	
	# Rejected when already at 100%
	gs.scrap = 5.0
	gs.leg_durability = 100.0
	var ok4: bool = gs.repair_legs(20.0, 1.0)
	runner.assert_false(ok4, "Repair rejected when durability already at 100%")
	runner.assert_almost_eq(gs.scrap, 5.0, 0.01, "Scrap preserved when repair rejected")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 10: Upgrade System Costs, One-Time Purchase & Multipliers
# ------------------------------------------------------------------------------
func test_10_upgrade_system_costs_and_effects(runner) -> void:
	runner.start_test("test_10_upgrade_system_costs_and_effects")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.scrap = 50.0
	gs.supplies = 20.0
	gs.fuel = 50.0
	
	# 1. Insulation: 12 scrap, 6 supplies
	runner.assert_true(gs.can_afford_upgrade("insulation"), "Can afford insulation")
	var p1: bool = gs.purchase_upgrade("insulation")
	runner.assert_true(p1, "Purchase insulation succeeded")
	runner.assert_true(gs.has_upgrade("insulation"), "Insulation upgrade registered")
	runner.assert_almost_eq(gs.scrap, 38.0, 0.01, "12 scrap deducted (50 -> 38)")
	runner.assert_almost_eq(gs.supplies, 14.0, 0.01, "6 supplies deducted (20 -> 14)")
	
	# One-time purchase enforcement
	runner.assert_false(gs.can_afford_upgrade("insulation"), "Cannot afford already purchased insulation")
	var p1_again: bool = gs.purchase_upgrade("insulation")
	runner.assert_false(p1_again, "Re-purchase of insulation rejected")
	
	# 2. Engine: 15 scrap, 20 fuel
	runner.assert_true(gs.can_afford_upgrade("engine"), "Can afford engine")
	var p2: bool = gs.purchase_upgrade("engine")
	runner.assert_true(p2, "Purchase engine succeeded")
	runner.assert_true(gs.has_upgrade("engine"), "Engine upgrade registered")
	runner.assert_almost_eq(gs.scrap, 23.0, 0.01, "15 scrap deducted (38 -> 23)")
	runner.assert_almost_eq(gs.fuel, 30.0, 0.01, "20 fuel deducted (50 -> 30)")
	
	# 3. Reinforced Legs: 18 scrap, 8 supplies
	runner.assert_true(gs.can_afford_upgrade("reinforced_legs"), "Can afford reinforced legs")
	var p3: bool = gs.purchase_upgrade("reinforced_legs")
	runner.assert_true(p3, "Purchase reinforced legs succeeded")
	runner.assert_true(gs.has_upgrade("reinforced_legs"), "Reinforced legs registered")
	runner.assert_almost_eq(gs.scrap, 5.0, 0.01, "18 scrap deducted (23 -> 5)")
	runner.assert_almost_eq(gs.supplies, 6.0, 0.01, "8 supplies deducted (14 -> 6)")
	
	# Rejection when resources insufficient
	gs.reset_state()
	gs.scrap = 0.0
	gs.supplies = 0.0
	runner.assert_false(gs.can_afford_upgrade("insulation"), "Cannot afford with 0 resources")
	runner.assert_false(gs.purchase_upgrade("insulation"), "Purchase rejected with 0 resources")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 11: UpgradePanel Modal UI & Dynamic Badge States
# ------------------------------------------------------------------------------
func test_11_upgrade_panel_modal_ui(runner) -> void:
	runner.start_test("test_11_upgrade_panel_modal_ui")
	
	var panel = UpgradePanel.new()
	panel._build_procedural_ui()
	
	runner.assert_true(panel.ins_button != null, "Insulation buy button exists")
	runner.assert_true(panel.eng_button != null, "Engine buy button exists")
	runner.assert_true(panel.legs_button != null, "Legs buy button exists")
	runner.assert_true(panel.repair_button != null, "Repair button exists")
	
	var gs = GameStateScript.new()
	gs.reset_state()
	panel.game_state = gs
	
	# Dynamic badge states:
	# 1. Unaffordable upgrade (0 resources) -> "[Недостаточно ресурсов]"
	gs.scrap = 0.0
	gs.supplies = 0.0
	panel.update_display()
	runner.assert_eq(panel.ins_button.text, "[Недостаточно ресурсов]", "Badge for unaffordable upgrade")
	runner.assert_true(panel.ins_button.disabled, "Unaffordable upgrade button disabled")
	
	# 2. Affordable upgrade -> "[Купить]"
	gs.scrap = 20.0
	gs.supplies = 10.0
	panel.update_display()
	runner.assert_eq(panel.ins_button.text, "[Купить]", "Badge for affordable upgrade")
	runner.assert_false(panel.ins_button.disabled, "Affordable upgrade button enabled")
	
	# 3. Owned upgrade -> "[✓ Установлено]"
	gs.upgrades["insulation"] = 1
	panel.update_display()
	runner.assert_eq(panel.ins_button.text, "[✓ Установлено]", "Badge for owned upgrade")
	runner.assert_true(panel.ins_button.disabled, "Owned upgrade button disabled")
	
	gs.free()
	panel.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 12: Deadlock Detection Engine (Zero False Positives)
# ------------------------------------------------------------------------------
func test_12_deadlock_detection_zero_false_positives(runner) -> void:
	runner.start_test("test_12_deadlock_detection_zero_false_positives")
	
	# Scenario A: Player outside scavenging -> Never deadlocked
	var dl_a: bool = SimulationLogic.check_deadlock_condition(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, true)
	runner.assert_false(dl_a, "Player outside scavenging is NEVER deadlocked")
	
	# Scenario B: Zero fuel, but fuel cache reachable within 50m safe perimeter -> NOT deadlocked
	var dl_b: bool = SimulationLogic.check_deadlock_condition(0.0, 100.0, 5.0, 1.0, 30.0, 0.0, false)
	runner.assert_false(dl_b, "Zero fuel with reachable fuel cache is NOT deadlocked")
	
	# Scenario C: Broken legs (durability 0), 0 scrap in inventory, but scrap cache reachable -> NOT deadlocked
	var dl_c: bool = SimulationLogic.check_deadlock_condition(40.0, 0.0, 0.0, 1.0, 0.0, 3.0, false)
	runner.assert_false(dl_c, "Broken legs with reachable scrap is NOT deadlocked")
	
	# Scenario D: Broken legs, scrap in inventory (>= 1.0) -> NOT deadlocked
	var dl_d: bool = SimulationLogic.check_deadlock_condition(40.0, 0.0, 2.0, 1.0, 0.0, 0.0, false)
	runner.assert_false(dl_d, "Broken legs with scrap in inventory is NOT deadlocked")
	
	# Scenario E: Mobile house (fuel > 0 and durability > 0) -> NOT deadlocked
	var dl_e: bool = SimulationLogic.check_deadlock_condition(50.0, 80.0, 0.0, 1.0, 0.0, 0.0, false)
	runner.assert_false(dl_e, "Mobile house is NOT deadlocked")
	
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 13: Deadlock True-Positive Detection & 3.0s Hysteresis Grace Period
# ------------------------------------------------------------------------------
func test_13_deadlock_detection_true_positive_and_grace_period(runner) -> void:
	runner.start_test("test_13_deadlock_detection_true_positive_and_grace_period")
	
	# True positive condition: 0 fuel + 0 reachable fuel, player inside
	var is_dl: bool = SimulationLogic.check_deadlock_condition(0.0, 100.0, 5.0, 1.0, 0.0, 0.0, false)
	runner.assert_true(is_dl, "Zero fuel and zero reachable fuel meets deadlock condition")
	
	# Hysteresis timer: 0.0s to 2.9s does NOT confirm deadlock
	var step1 = SimulationLogic.update_deadlock_timer(0.0, true, 1.5, 3.0)
	runner.assert_almost_eq(step1.timer, 1.5, 0.01, "Timer advances to 1.5s")
	runner.assert_false(step1.is_confirmed, "Not confirmed at 1.5s")
	
	var step2 = SimulationLogic.update_deadlock_timer(1.5, true, 1.4, 3.0)
	runner.assert_almost_eq(step2.timer, 2.9, 0.01, "Timer advances to 2.9s")
	runner.assert_false(step2.is_confirmed, "Not confirmed at 2.9s")
	
	# Transient recovery resets timer
	var step_reset = SimulationLogic.update_deadlock_timer(2.9, false, 0.5, 3.0)
	runner.assert_almost_eq(step_reset.timer, 0.0, 0.01, "Timer resets on condition recovery")
	runner.assert_false(step_reset.is_confirmed, "Not confirmed on reset")
	
	# Full 3.0s duration confirms deadlock
	var step_confirm = SimulationLogic.update_deadlock_timer(2.0, true, 1.0, 3.0)
	runner.assert_gte(step_confirm.timer, 3.0, "Timer reaches 3.0s")
	runner.assert_true(step_confirm.is_confirmed, "Deadlock confirmed after 3.0s continuous stall")
	
	# GameState trigger_deadlock integration
	var gs = GameStateScript.new()
	gs.reset_state()
	gs.is_game_active = true
	var flags := {"deadlock": false}
	gs.deadlock_detected.connect(func(): flags["deadlock"] = true)
	
	gs.trigger_deadlock("deadlock: Безысходный тупик: ресурсы исчерпаны")
	runner.assert_true(flags["deadlock"], "deadlock_detected signal emitted")
	runner.assert_true(gs.is_game_over, "is_game_over set to true")
	runner.assert_true("deadlock" in gs.game_over_reason.to_lower(), "Game over reason contains 'deadlock'")
	runner.assert_true("тупик" in gs.game_over_reason.to_lower(), "Game over reason contains 'тупик'")
	
	gs.free()
	runner.end_test()
