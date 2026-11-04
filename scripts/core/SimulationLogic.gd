# scripts/core/SimulationLogic.gd
class_name SimulationLogic
extends RefCounted

## Pure static mathematical and thermodynamic functions for «Шагающий дом» (Walking House).
## Zero node dependencies, 100% headlessly testable.

# ==============================================================================
# 1. LOCOMOTION & SPEED
# ==============================================================================

## Calculates the walking house horizontal speed based on leg durability.
## Features: F11, F12.
## Inflection at 50% durability: 100% speed.
## Linear degradation from 50% to 10% durability down to 50% speed.
## Emergency creep speed (30% speed) below 10% durability.
## Immobilized (0.0 m/s) at <= 0% durability.
static func calculate_speed(base_speed: float, durability: float, max_durability: float = 100.0) -> float:
	if durability <= 0.0 or max_durability <= 0.0 or base_speed <= 0.0:
		return 0.0
	var pct: float = clampf((durability / max_durability) * 100.0, 0.0, 100.0)
	if pct >= 50.0:
		return base_speed
	elif pct >= 10.0:
		var factor: float = 0.5 + 0.5 * ((pct - 10.0) / 40.0)
		return base_speed * factor
	else:
		return base_speed * 0.3

## Calculates locomotive fuel consumption over delta time.
## Features: F09, F34.
static func calculate_fuel_consumption(
	is_moving: bool, 
	has_engine_upgrade: bool, 
	delta: float, 
	base_rate: float = 0.50, 
	upgrade_discount: float = 0.30
) -> float:
	if not is_moving or delta <= 0.0:
		return 0.0
	var rate: float = base_rate * (1.0 - upgrade_discount) if has_engine_upgrade else base_rate
	return maxf(0.0, rate * delta)

## Calculates mechanical leg wear over delta time.
## Features: F10, F35.
static func calculate_leg_wear(
	is_moving: bool, 
	has_legs_upgrade: bool, 
	delta: float, 
	base_wear_rate: float = 0.20, 
	upgrade_discount: float = 0.40, 
	biome_multiplier: float = 1.0
) -> float:
	if not is_moving or delta <= 0.0:
		return 0.0
	var rate: float = base_wear_rate * (1.0 - upgrade_discount) if has_legs_upgrade else base_wear_rate
	return maxf(0.0, rate * biome_multiplier * delta)

# ==============================================================================
# 2. REPAIRS & UPGRADES
# ==============================================================================

## Calculates durability gain for a given amount of scrap.
## Feature: F32.
static func calculate_repair_gain(scrap_amount: float, k_repair: float = 20.0) -> float:
	return maxf(0.0, scrap_amount) * k_repair

## Applies scrap to repair legs, consuming only what is necessary to reach max_durability.
## Returns Dictionary: {"new_durability": float, "scrap_spent": float}
## Feature: F32.
static func apply_repair(
	current_durability: float, 
	scrap_available: float, 
	max_durability: float = 100.0, 
	k_repair: float = 20.0
) -> Dictionary:
	var clamped_durability: float = clampf(current_durability, 0.0, max_durability)
	var needed: float = max_durability - clamped_durability
	if needed <= 0.0 or scrap_available <= 0.0:
		return {"new_durability": clamped_durability, "scrap_spent": 0.0}
	
	var scrap_needed: float = ceil(needed / k_repair)
	var scrap_spent: float = minf(scrap_needed, floor(scrap_available))
	if scrap_spent <= 0.0 and scrap_available > 0.0:
		scrap_spent = minf(scrap_needed, scrap_available)
		
	var gain: float = scrap_spent * k_repair
	var new_durability: float = minf(max_durability, clamped_durability + gain)
	return {
		"new_durability": new_durability,
		"scrap_spent": scrap_spent
	}

## Checks if player can afford an upgrade. Supports canonical and short alias IDs.
## Features: F33, F34, F35, F36.
static func can_afford_upgrade(
	upgrade_type: String, 
	scrap: float, 
	supplies: float = 0.0,
	fuel: float = 0.0
) -> bool:
	match upgrade_type.to_lower():
		"insulation":
			return scrap >= 12.0 and supplies >= 6.0
		"engine", "efficient_engine":
			return scrap >= 15.0 and fuel >= 20.0
		"legs", "reinforced_legs":
			return scrap >= 18.0 and supplies >= 8.0
		_:
			return false

# ==============================================================================
# 3. THERMODYNAMICS & WEATHER
# ==============================================================================

## Updates cabin temperature via Newton's Law of Cooling with active heating.
## Features: F38, F39, F43.
static func calculate_cabin_temperature(
	current_temp: float, 
	outside_temp: float, 
	stove_on: bool, 
	has_insulation: bool, 
	is_blizzard: bool, 
	delta: float,
	k_base: float = 0.025,
	q_stove: float = 1.1,
	blizzard_multiplier: float = 1.8,
	insulation_discount: float = 0.45,
	max_temp: float = 24.0
) -> float:
	if delta <= 0.0:
		return current_temp
	var k: float = k_base
	if is_blizzard:
		k *= blizzard_multiplier
	if has_insulation:
		k *= (1.0 - insulation_discount)
	var heat_in: float = q_stove if stove_on else 0.0
	var dt_temp: float = (-k * (current_temp - outside_temp) + heat_in) * delta
	return clampf(current_temp + dt_temp, -50.0, max_temp)

## Calculates fuel consumed by the heating stove over delta time.
## Feature: F40.
static func calculate_stove_fuel(
	stove_on: bool, 
	delta: float, 
	consumption_rate: float = 0.25
) -> float:
	if not stove_on or delta <= 0.0:
		return 0.0
	return maxf(0.0, consumption_rate * delta)

# ==============================================================================
# 4. PLAYER EXPOSURE & HEALTH
# ==============================================================================

## Calculates outside cold exposure damage rate, doubling when tether radius is exceeded.
## Features: F23, F24.
static func calculate_player_outside_exposure(
	delta: float, 
	dist_from_house: float, 
	safe_radius: float = 45.0,
	base_rate: float = 2.5,
	penalty_mult: float = 2.0
) -> float:
	if delta <= 0.0:
		return 0.0
	if dist_from_house <= safe_radius:
		return base_rate * delta
	else:
		return base_rate * penalty_mult * delta

## Calculates outside cold damage applied to health after warm clothing buffer expires.
## Feature: F23.
static func calculate_outside_cold_damage(
	exposure_time: float, 
	warm_buffer: float = 20.0, 
	is_blizzard: bool = false, 
	delta: float = 0.0,
	base_damage: float = 2.5,
	blizzard_damage: float = 6.0
) -> float:
	if exposure_time <= warm_buffer or delta <= 0.0:
		return 0.0
	var rate: float = blizzard_damage if is_blizzard else base_damage
	return rate * delta

## Calculates damage when inside cabin if temperature drops below 0°C.
## Feature: F45.
static func calculate_cabin_cold_damage(
	cabin_temp: float, 
	delta: float, 
	damage_factor: float = 0.5
) -> float:
	if cabin_temp >= 0.0 or delta <= 0.0:
		return 0.0
	return absf(cabin_temp) * damage_factor * delta

## Calculates passive health recovery in a warm cabin (temp >= 10°C).
## Feature: F46.
static func calculate_warmth_recovery(
	cabin_temp: float, 
	delta: float, 
	recovery_rate: float = 0.5, 
	min_warm_temp: float = 10.0
) -> float:
	if cabin_temp < min_warm_temp or delta <= 0.0:
		return 0.0
	return recovery_rate * delta

# ==============================================================================
# 5. DEADLOCK DETECTION (ZERO FALSE POSITIVES)
# ==============================================================================

## Evaluates whether the game is in an instantaneous resource deadlock.
## Guaranteed ZERO FALSE POSITIVES:
## - If player is outside, returns false (player can collect resources).
## - If fuel remains or reachable fuel is within safe perimeter, returns false.
## - If legs have durability or scrap is available for repair, returns false.
## Features: F06, F47.
static func check_deadlock_condition(
	fuel: float, 
	leg_durability: float, 
	scrap: float, 
	min_repair_cost: float, 
	reachable_fuel: float, 
	reachable_scrap: float, 
	is_player_outside: bool
) -> bool:
	if is_player_outside:
		return false
	
	var fuel_stalled: bool = (fuel <= 0.0) and (reachable_fuel <= 0.0)
	var legs_stalled: bool = (leg_durability <= 0.0) and ((scrap + reachable_scrap) < min_repair_cost)
	
	return fuel_stalled or legs_stalled

## Updates the temporal grace period timer for deadlock confirmation.
## Returns Dictionary: {"timer": float, "is_confirmed": bool}
## Feature: F47.
static func update_deadlock_timer(
	current_timer: float, 
	is_condition_met: bool, 
	delta: float, 
	grace_period: float = 3.0
) -> Dictionary:
	if not is_condition_met:
		return {"timer": 0.0, "is_confirmed": false}
	var new_timer: float = current_timer + maxf(0.0, delta)
	var is_confirmed: bool = (new_timer >= grace_period)
	return {
		"timer": new_timer,
		"is_confirmed": is_confirmed
	}
