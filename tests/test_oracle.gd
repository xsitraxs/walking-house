# test_oracle.gd — Authoritative reference calculations and balance specifications
# Derived directly from PROJECT.md and explorer_balance_test_survey/handoff.md
class_name TestOracle
extends RefCounted

# Spatial & Kinematic Constants
const BASE_SPEED: float = 5.0
const REVERSE_SPEED: float = 2.5
const UPGRADED_SPEED: float = 5.75
const PLAYER_SPEED: float = 3.2
const ROUTE_DISTANCE: float = 5000.0
const METERS_TO_PIXELS: float = 20.0

# Fuel & Wear Constants
const BASE_FUEL_RATE: float = 0.50 # per second forward (0.10 / meter)
const REVERSE_FUEL_RATE: float = 0.35 # per second reverse (0.14 / meter)
const STOVE_FUEL_RATE: float = 0.25 # per second
const BASE_LEG_WEAR_RATE: float = 0.20 # per second forward (0.040% / meter)

# Repair & Upgrade Constants
const REPAIR_DURABILITY_GAIN: float = 20.0 # +20% per scrap
const REPAIR_SCRAP_COST: int = 1
const UPGRADE_INSULATION_SCRAP: float = 12.0
const UPGRADE_INSULATION_SUPPLIES: float = 6.0
const UPGRADE_ENGINE_SCRAP: float = 15.0
const UPGRADE_ENGINE_FUEL: float = 20.0
const UPGRADE_LEGS_SCRAP: float = 18.0
const UPGRADE_LEGS_SUPPLIES: float = 8.0

# Thermal & Environmental Constants
const CABIN_COOLING_COEFF: float = 0.025 # k_loss calm
const CABIN_COOLING_BLIZZARD_MULT: float = 1.8
const INSULATION_REDUCTION: float = 0.45 # -45% heat loss
const ENGINE_FUEL_REDUCTION: float = 0.30 # -30% locomotive fuel
const LEGS_WEAR_REDUCTION: float = 0.40 # -40% mechanical wear
const STOVE_HEATING_RATE: float = 1.1 # °C per second
const CABIN_MAX_TEMP: float = 24.0 # °C
const CABIN_FREEZE_THRESHOLD: float = 0.0 # °C
const CABIN_WARMTH_THRESHOLD: float = 10.0 # °C

# Survival & Exploration Constants
const SAFE_RADIUS_METERS: float = 45.0
const SAFE_WARM_TIME: float = 20.0 # seconds before hypothermia outside
const OUTSIDE_COLD_DAMAGE_CALM: float = 2.5 # HP/sec
const OUTSIDE_COLD_DAMAGE_BLIZZARD: float = 6.0 # HP/sec
const TETHER_VIOLATION_DAMAGE_MULT: float = 2.0
const DEADLOCK_GRACE_PERIOD: float = 3.0 # seconds

# 20 Deterministic Route POIs from explorer_balance_test_survey/handoff.md
static func get_route_pois() -> Array:
	return [
		{"id": 1, "biome": 1, "x": 200.0, "y": 6.0, "name": "Брошенный снегоход", "fuel": 30.0, "scrap": 3, "supplies": 1},
		{"id": 2, "biome": 1, "x": 450.0, "y": -8.0, "name": "Склад бочек у вехи", "fuel": 40.0, "scrap": 2, "supplies": 1},
		{"id": 3, "biome": 1, "x": 700.0, "y": 10.0, "name": "Обломки грузового прицепа", "fuel": 35.0, "scrap": 4, "supplies": 2},
		{"id": 4, "biome": 1, "x": 950.0, "y": -5.0, "name": "Заброшенный метеопост", "fuel": 35.0, "scrap": 3, "supplies": 1},
		{"id": 5, "biome": 2, "x": 1200.0, "y": 12.0, "name": "Жилой модуль геологов", "fuel": 40.0, "scrap": 3, "supplies": 2},
		{"id": 6, "biome": 2, "x": 1450.0, "y": -10.0, "name": "Старый генератор", "fuel": 50.0, "scrap": 4, "supplies": 1},
		{"id": 7, "biome": 2, "x": 1700.0, "y": 8.0, "name": "Занесённые цистерны ГСМ", "fuel": 50.0, "scrap": 3, "supplies": 2},
		{"id": 8, "biome": 2, "x": 1950.0, "y": -12.0, "name": "Руины полевой столовой", "fuel": 30.0, "scrap": 2, "supplies": 3},
		{"id": 9, "biome": 3, "x": 2200.0, "y": 14.0, "name": "Остов шагохода «Буран-1»", "fuel": 35.0, "scrap": 6, "supplies": 0},
		{"id": 10, "biome": 3, "x": 2450.0, "y": -15.0, "name": "Мастерская тягачей", "fuel": 40.0, "scrap": 5, "supplies": 1},
		{"id": 11, "biome": 3, "x": 2700.0, "y": 10.0, "name": "Шахтный экскаватор", "fuel": 35.0, "scrap": 6, "supplies": 1},
		{"id": 12, "biome": 3, "x": 2950.0, "y": -8.0, "name": "Эвакуационный конвой", "fuel": 45.0, "scrap": 5, "supplies": 1},
		{"id": 13, "biome": 4, "x": 3200.0, "y": 15.0, "name": "Занесённая сторожка", "fuel": 35.0, "scrap": 2, "supplies": 2},
		{"id": 14, "biome": 4, "x": 3450.0, "y": -12.0, "name": "Трактор-трелёвочник", "fuel": 40.0, "scrap": 3, "supplies": 1},
		{"id": 15, "biome": 4, "x": 3700.0, "y": 10.0, "name": "Железный контейнер со знаком", "fuel": 45.0, "scrap": 2, "supplies": 1},
		{"id": 16, "biome": 4, "x": 3950.0, "y": -6.0, "name": "Рухнувшая радиомачта", "fuel": 35.0, "scrap": 2, "supplies": 0},
		{"id": 17, "biome": 5, "x": 4200.0, "y": 10.0, "name": "Блокпост внешнего периметра", "fuel": 30.0, "scrap": 0, "supplies": 1},
		{"id": 18, "biome": 5, "x": 4450.0, "y": -8.0, "name": "Резервная насосная станция", "fuel": 40.0, "scrap": 0, "supplies": 0},
		{"id": 19, "biome": 5, "x": 4700.0, "y": 12.0, "name": "Железнодорожный семафор", "fuel": 30.0, "scrap": 0, "supplies": 1},
		{"id": 20, "biome": 5, "x": 4950.0, "y": 0.0, "name": "Врата Станции «Полюс»", "fuel": 40.0, "scrap": 0, "supplies": 0}
	]

# Reference Implementation Formulas for Assertion Oracles
static func ref_calculate_speed(base_speed: float, durability: float, max_durability: float) -> float:
	if durability <= 0.0:
		return 0.0
	var pct: float = clamp((durability / max_durability) * 100.0, 0.0, 100.0)
	if pct >= 50.0:
		return base_speed
	elif pct >= 10.0:
		var factor: float = 0.5 + 0.5 * ((pct - 10.0) / 40.0)
		return base_speed * factor
	else:
		return base_speed * 0.3

static func ref_calculate_fuel_consumption(is_moving: bool, has_engine_upgrade: bool, delta: float) -> float:
	if not is_moving:
		return 0.0
	var rate: float = BASE_FUEL_RATE
	if has_engine_upgrade:
		rate *= (1.0 - ENGINE_FUEL_REDUCTION)
	return rate * delta

static func ref_calculate_leg_wear(is_moving: bool, has_legs_upgrade: bool, delta: float) -> float:
	if not is_moving:
		return 0.0
	var rate: float = BASE_LEG_WEAR_RATE
	if has_legs_upgrade:
		rate *= (1.0 - LEGS_WEAR_REDUCTION)
	return rate * delta

static func ref_calculate_cabin_temperature(current_temp: float, outside_temp: float, stove_on: bool, has_insulation: bool, is_blizzard: bool, delta: float) -> float:
	var k: float = CABIN_COOLING_COEFF
	if is_blizzard:
		k *= CABIN_COOLING_BLIZZARD_MULT
	if has_insulation:
		k *= (1.0 - INSULATION_REDUCTION)
	
	var cooling: float = k * (current_temp - outside_temp) * delta
	var heating: float = (STOVE_HEATING_RATE * delta) if stove_on else 0.0
	var new_temp: float = current_temp - cooling + heating
	return clamp(new_temp, outside_temp, CABIN_MAX_TEMP)

static func ref_calculate_stove_fuel(stove_on: bool, delta: float) -> float:
	return (STOVE_FUEL_RATE * delta) if stove_on else 0.0

static func ref_calculate_player_outside_exposure(delta: float, dist_from_house: float, safe_radius: float) -> float:
	var mult: float = TETHER_VIOLATION_DAMAGE_MULT if (dist_from_house > safe_radius) else 1.0
	return OUTSIDE_COLD_DAMAGE_CALM * mult * delta

static func ref_check_deadlock_condition(fuel: float, leg_durability: float, scrap: float, min_repair_cost: float, reachable_fuel: float, reachable_scrap: float, is_player_outside: bool) -> bool:
	if is_player_outside:
		return false
	var fuel_stalled: bool = (fuel <= 0.0) and (reachable_fuel <= 0.0)
	var legs_stalled: bool = (leg_durability <= 0.0) and (scrap < min_repair_cost) and (reachable_scrap < min_repair_cost)
	return fuel_stalled or legs_stalled

static func ref_apply_repair(current_durability: float, scrap_available: float) -> Dictionary:
	if current_durability >= 100.0 or scrap_available < REPAIR_SCRAP_COST:
		return {"new_durability": current_durability, "scrap_spent": 0.0}
	var needed: float = 100.0 - current_durability
	var max_units_needed: int = int(ceil(needed / REPAIR_DURABILITY_GAIN))
	var units_to_spend: int = mini(max_units_needed, int(scrap_available))
	var gain: float = float(units_to_spend) * REPAIR_DURABILITY_GAIN
	var final_dur: float = minf(100.0, current_durability + gain)
	return {"new_durability": final_dur, "scrap_spent": float(units_to_spend)}

static func ref_can_afford_upgrade(upgrade_type: String, scrap: float, supplies: float) -> bool:
	match upgrade_type:
		"insulation":
			return scrap >= UPGRADE_INSULATION_SCRAP and supplies >= UPGRADE_INSULATION_SUPPLIES
		"engine":
			return scrap >= UPGRADE_ENGINE_SCRAP
		"legs":
			return scrap >= UPGRADE_LEGS_SCRAP and supplies >= UPGRADE_LEGS_SUPPLIES
		_:
			return false
