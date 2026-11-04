# scripts/core/BalanceConfig.gd
class_name BalanceConfig
extends RefCounted

## Spatial and metric constants
const ROUTE_LENGTH_METERS: float = 5000.0
const METERS_TO_PIXELS: float = 20.0
const WORLD_WIDTH_PIXELS: float = ROUTE_LENGTH_METERS * METERS_TO_PIXELS # 100,000 px
const VIEWPORT_WIDTH: float = 1280.0
const VIEWPORT_HEIGHT: float = 720.0

## Biomes configuration (5 biomes of 1000m each)
const BIOME_LENGTH_METERS: float = 1000.0
const BIOMES: Array[Dictionary] = [
	{
		"index": 0,
		"id": "snowy_plains",
		"name": "Заснеженная равнина",
		"start_m": 0.0,
		"end_m": 1000.0,
		"day_temp": -10.0,
		"night_temp": -22.0,
		"wear_mult": 1.0
	},
	{
		"index": 1,
		"id": "abandoned_camp",
		"name": "Заброшенный лагерь геологов",
		"start_m": 1000.0,
		"end_m": 2000.0,
		"day_temp": -12.0,
		"night_temp": -25.0,
		"wear_mult": 1.0
	},
	{
		"index": 2,
		"id": "machinery_graveyard",
		"name": "Кладбище техники",
		"start_m": 2000.0,
		"end_m": 3000.0,
		"day_temp": -14.0,
		"night_temp": -27.0,
		"wear_mult": 1.5
	},
	{
		"index": 3,
		"id": "frozen_forest",
		"name": "Замёрзший лес",
		"start_m": 3000.0,
		"end_m": 4000.0,
		"day_temp": -18.0,
		"night_temp": -32.0,
		"wear_mult": 1.25
	},
	{
		"index": 4,
		"id": "station_outskirts",
		"name": "Окрестности станции «Полюс»",
		"start_m": 4000.0,
		"end_m": 5000.0,
		"day_temp": -12.0,
		"night_temp": -24.0,
		"wear_mult": 1.0
	}
]

## Speeds and kinematics
const BASE_FORWARD_SPEED: float = 5.0 # m/s (100 px/s)
const BASE_REVERSE_SPEED: float = 2.5 # m/s (50 px/s)
const HOUSE_ACCELERATION: float = 2.5 # m/s^2
const PLAYER_SPEED: float = 3.2 # m/s (64 px/s)
const PLAYER_SAFE_RADIUS: float = 45.0 # meters (900 px)
const PLAYER_INTERACT_RADIUS: float = 2.5 # meters (50 px)

## Initial state resources and capacities
const INITIAL_FUEL: float = 100.0
const MAX_FUEL: float = 100.0
const INITIAL_LEG_DURABILITY: float = 100.0
const MAX_LEG_DURABILITY: float = 100.0
const INITIAL_SCRAP: int = 0
const INITIAL_SUPPLIES: int = 5
const INITIAL_CABIN_TEMP: float = 18.0 # °C
const INITIAL_PLAYER_HEALTH: float = 100.0
const MAX_PLAYER_HEALTH: float = 100.0

## Starting baseline exploration reserves (for 15-25 min balanced run)
const STARTING_RESERVE_FUEL: float = 60.0
const STARTING_RESERVE_SCRAP: int = 5
const STARTING_RESERVE_SUPPLIES: int = 3

## Fuel consumption rates
const WALK_FUEL_RATE: float = 0.50 # fuel/sec at 5 m/s forward -> 0.10 fuel/meter
const REVERSE_FUEL_RATE: float = 0.35 # fuel/sec at 2.5 m/s reverse -> 0.14 fuel/meter
const IDLE_FUEL_RATE: float = 0.0 # fuel/sec when standing
const STOVE_FUEL_RATE: float = 0.25 # fuel/sec -> 15.0 fuel/minute

## Mechanical leg wear and degradation
const BASE_LEG_WEAR_PER_METER: float = 0.040 # % per meter (0.20% per sec at 5 m/s)
const LEG_DEGRADATION_THRESHOLD: float = 50.0 # % below which speed starts degrading
const LEG_CRITICAL_THRESHOLD: float = 10.0 # % emergency alert threshold
const LEG_CRITICAL_SPEED_FLOOR: float = 0.30 # speed multiplier below critical threshold

## Repair mechanics
const REPAIR_SCRAP_COST: int = 1 # 1 scrap unit
const REPAIR_DURABILITY_GAIN: float = 20.0 # +20.0% durability restored

## Thermodynamics and temperatures
const CABIN_BASE_COOLING_RATE: float = 0.025 # 1/s Newton cooling coefficient
const CABIN_BLIZZARD_COOLING_MULT: float = 1.8 # heat loss multiplier during blizzard
const STOVE_HEATING_RATE: float = 1.1 # °C/sec heat influx when stove is active
const CABIN_MAX_TEMP: float = 24.0 # °C upper thermal limit
const CABIN_COMFORT_TEMP: float = 10.0 # °C safe comfort threshold
const CABIN_FREEZE_THRESHOLD: float = 0.0 # °C threshold below which player takes hypothermia damage
const INDOOR_FREEZE_DAMAGE_RATE: float = 0.5 # HP/sec per °C below freezing threshold

## Outdoor exposure
const OUTDOOR_WARMTH_DURATION: float = 20.0 # seconds of warm clothes buffer
const OUTDOOR_FREEZE_DAMAGE_RATE: float = 2.5 # HP/sec hypothermia damage outside
const OUTDOOR_BLIZZARD_DAMAGE_RATE: float = 6.0 # HP/sec blizzard hypothermia damage outside
const SUPPLY_HEAL_AMOUNT: float = 25.0 # HP restored per supply unit consumed
const SUPPLY_HEAL_DURATION: float = 5.0 # seconds duration of healing

## Weather, Day/Night cycle and Blizzards
const DAY_NIGHT_CYCLE_DURATION: float = 300.0 # 5 minutes total period
const DAY_DURATION: float = 150.0
const DUSK_DURATION: float = 30.0
const NIGHT_DURATION: float = 90.0
const DAWN_DURATION: float = 30.0
const BLIZZARD_WARNING_LEAD_TIME: float = 20.0 # seconds warning prior to blizzard
const BLIZZARD_EVENTS: Array[Dictionary] = [
	{
		"id": "blizzard_1",
		"trigger_distance_m": 1400.0,
		"duration_sec": 40.0,
		"temp_drop": -15.0
	},
	{
		"id": "blizzard_2",
		"trigger_distance_m": 3300.0,
		"duration_sec": 50.0,
		"temp_drop": -15.0
	}
]

## Deadlock evaluation
const DEADLOCK_GRACE_PERIOD: float = 3.0 # seconds hysteresis before triggering defeat

## Upgrades specification
const UPGRADES: Dictionary = {
	"insulation": {
		"id": "insulation",
		"name": "Утепление корпуса",
		"description": "Снижает теплопотери кабины на 45%",
		"cost": {"scrap": 12, "supplies": 6, "fuel": 0.0},
		"cooling_reduction": 0.45,
		"cooling_multiplier": 0.55
	},
	"engine": {
		"id": "engine",
		"name": "Экономичный двигатель",
		"description": "Снижает расход топлива двигателем при ходьбе на 30%",
		"cost": {"scrap": 15, "supplies": 0, "fuel": 20.0},
		"fuel_reduction": 0.30,
		"fuel_multiplier": 0.70
	},
	"reinforced_legs": {
		"id": "reinforced_legs",
		"name": "Усиленные ноги",
		"description": "Замедляет износ опор на 40% и повышает скорость на 15%",
		"cost": {"scrap": 18, "supplies": 8, "fuel": 0.0},
		"wear_reduction": 0.40,
		"wear_multiplier": 0.60,
		"speed_bonus": 0.15,
		"speed_multiplier": 1.15
	}
}

## Deterministic POI route table (Exactly 20 sites across 5 biomes)
## Placed resources: 760.0 Fuel, 55 Scrap, 22 Supplies
## Grand total available with starting reserve: 820.0 Fuel, 60 Scrap, 25 Supplies
const POI_SITES: Array[Dictionary] = [
	# Biome 1: Заснеженная равнина (0 - 1000m)
	{
		"id": 1,
		"biome_index": 0,
		"biome": 1,
		"distance_m": 200.0,
		"x": 200.0,
		"offset_y_m": 6.0,
		"y": 6.0,
		"type": "snowmobile",
		"name": "Брошенный снегоход",
		"display_name": "Брошенный снегоход",
		"fuel": 30.0,
		"scrap": 3,
		"supplies": 1,
		"description": "Занесённый снегоход геологов с канистрой топлива."
	},
	{
		"id": 2,
		"biome_index": 0,
		"biome": 1,
		"distance_m": 450.0,
		"x": 450.0,
		"offset_y_m": -8.0,
		"y": -8.0,
		"type": "barrels",
		"name": "Склад бочек у вехи",
		"display_name": "Склад бочек у вехи",
		"fuel": 40.0,
		"scrap": 2,
		"supplies": 1,
		"description": "Оставленный схрон топливных бочек у навигационного знака."
	},
	{
		"id": 3,
		"biome_index": 0,
		"biome": 1,
		"distance_m": 700.0,
		"x": 700.0,
		"offset_y_m": 10.0,
		"y": 10.0,
		"type": "trailer",
		"name": "Обломки грузового прицепа",
		"display_name": "Обломки грузового прицепа",
		"fuel": 35.0,
		"scrap": 4,
		"supplies": 2,
		"description": "Перевернутый грузовой прицеп с металлоломом и сухпайком."
	},
	{
		"id": 4,
		"biome_index": 0,
		"biome": 1,
		"distance_m": 950.0,
		"x": 950.0,
		"offset_y_m": -5.0,
		"y": -5.0,
		"type": "weather_station",
		"name": "Заброшенный метеопост",
		"display_name": "Заброшенный метеопост",
		"fuel": 35.0,
		"scrap": 3,
		"supplies": 1,
		"description": "Автоматическая метеорологическая станция с аккумулятором и топливом."
	},
	# Biome 2: Заброшенный лагерь геологов (1000 - 2000m)
	{
		"id": 5,
		"biome_index": 1,
		"biome": 2,
		"distance_m": 1200.0,
		"x": 1200.0,
		"offset_y_m": 12.0,
		"y": 12.0,
		"type": "cabin",
		"name": "Жилой модуль геологов",
		"display_name": "Жилой модуль геологов",
		"fuel": 40.0,
		"scrap": 3,
		"supplies": 2,
		"description": "Обледенелый вагончик-бытовка с консервами и бензином."
	},
	{
		"id": 6,
		"biome_index": 1,
		"biome": 2,
		"distance_m": 1450.0,
		"x": 1450.0,
		"offset_y_m": -10.0,
		"y": -10.0,
		"type": "diesel",
		"name": "Старый генератор",
		"display_name": "Старый дизель-генератор",
		"fuel": 50.0,
		"scrap": 4,
		"supplies": 1,
		"description": "Тяжелый дизельный генератор в защитном кожухе."
	},
	{
		"id": 7,
		"biome_index": 1,
		"biome": 2,
		"distance_m": 1700.0,
		"x": 1700.0,
		"offset_y_m": 8.0,
		"y": 8.0,
		"type": "tanker",
		"name": "Занесённые цистерны ГСМ",
		"display_name": "Занесённые цистерны ГСМ",
		"fuel": 50.0,
		"scrap": 3,
		"supplies": 2,
		"description": "Резервуары полярного склада горючего."
	},
	{
		"id": 8,
		"biome_index": 1,
		"biome": 2,
		"distance_m": 1950.0,
		"x": 1950.0,
		"offset_y_m": -12.0,
		"y": -12.0,
		"type": "canteen",
		"name": "Руины полевой столовой",
		"display_name": "Руины полевой столовой",
		"fuel": 30.0,
		"scrap": 2,
		"supplies": 3,
		"description": "Засыпанная снегом кухня экспедиции с провизией."
	},
	# Biome 3: Кладбище техники (2000 - 3000m)
	{
		"id": 9,
		"biome_index": 2,
		"biome": 3,
		"distance_m": 2200.0,
		"x": 2200.0,
		"offset_y_m": 14.0,
		"y": 14.0,
		"type": "walker_wreck",
		"name": "Остов шагохода «Буран-1»",
		"display_name": "Остов шагохода «Буран-1»",
		"fuel": 35.0,
		"scrap": 6,
		"supplies": 0,
		"description": "Разрушенный экспериментальный шагоход, богатый редким металлом."
	},
	{
		"id": 10,
		"biome_index": 2,
		"biome": 3,
		"distance_m": 2450.0,
		"x": 2450.0,
		"offset_y_m": -15.0,
		"y": -15.0,
		"type": "hangar",
		"name": "Мастерская тягачей",
		"display_name": "Мастерская тяжелых тягачей",
		"fuel": 40.0,
		"scrap": 5,
		"supplies": 1,
		"description": "Разрушенный каркасный ангар с запасными частями."
	},
	{
		"id": 11,
		"biome_index": 2,
		"biome": 3,
		"distance_m": 2700.0,
		"x": 2700.0,
		"offset_y_m": 10.0,
		"y": 10.0,
		"type": "excavator",
		"name": "Шахтный экскаватор",
		"display_name": "Шахтный карьерный экскаватор",
		"fuel": 35.0,
		"scrap": 6,
		"supplies": 1,
		"description": "Исполинский карьерный механизм с гидравлическими опорами."
	},
	{
		"id": 12,
		"biome_index": 2,
		"biome": 3,
		"distance_m": 2950.0,
		"x": 2950.0,
		"offset_y_m": -8.0,
		"y": -8.0,
		"type": "convoy",
		"name": "Эвакуационный конвой",
		"display_name": "Эвакуационный конвой",
		"fuel": 45.0,
		"scrap": 5,
		"supplies": 1,
		"description": "Колонна брошенных арктических вездеходов."
	},
	# Biome 4: Замёрзший лес (3000 - 4000m)
	{
		"id": 13,
		"biome_index": 3,
		"biome": 4,
		"distance_m": 3200.0,
		"x": 3200.0,
		"offset_y_m": 15.0,
		"y": 15.0,
		"type": "cabin",
		"name": "Занесённая сторожка",
		"display_name": "Занесённая сторожка лесника",
		"fuel": 35.0,
		"scrap": 2,
		"supplies": 2,
		"description": "Деревянная сторожка среди обледенелых елей."
	},
	{
		"id": 14,
		"biome_index": 3,
		"biome": 4,
		"distance_m": 3450.0,
		"x": 3450.0,
		"offset_y_m": -12.0,
		"y": -12.0,
		"type": "timber_truck",
		"name": "Трактор-трелёвочник",
		"display_name": "Трактор-трелёвочник",
		"fuel": 40.0,
		"scrap": 3,
		"supplies": 1,
		"description": "Гусеничный трелевочник с полным топливным баком."
	},
	{
		"id": 15,
		"biome_index": 3,
		"biome": 4,
		"distance_m": 3700.0,
		"x": 3700.0,
		"offset_y_m": 10.0,
		"y": 10.0,
		"type": "cache",
		"name": "Железный контейнер со знаком",
		"display_name": "Железный контейнер со знаком",
		"fuel": 45.0,
		"scrap": 2,
		"supplies": 1,
		"description": "Герметичный контейнер МЧС на холме."
	},
	{
		"id": 16,
		"biome_index": 3,
		"biome": 4,
		"distance_m": 3950.0,
		"x": 3950.0,
		"offset_y_m": -6.0,
		"y": -6.0,
		"type": "radio_tower",
		"name": "Рухнувшая радиомачта",
		"display_name": "Рухнувшая радиомачта",
		"fuel": 35.0,
		"scrap": 2,
		"supplies": 0,
		"description": "Остатки аварийного передатчика на опушке леса."
	},
	# Biome 5: Окрестности станции «Полюс» (4000 - 5000m)
	{
		"id": 17,
		"biome_index": 4,
		"biome": 5,
		"distance_m": 4200.0,
		"x": 4200.0,
		"offset_y_m": 10.0,
		"y": 10.0,
		"type": "checkpoint",
		"name": "Блокпост внешнего периметра",
		"display_name": "Блокпост внешнего периметра",
		"fuel": 30.0,
		"scrap": 0,
		"supplies": 1,
		"description": "Заградительный пост у границы безопасной зоны станции."
	},
	{
		"id": 18,
		"biome_index": 4,
		"biome": 5,
		"distance_m": 4450.0,
		"x": 4450.0,
		"offset_y_m": -8.0,
		"y": -8.0,
		"type": "pump_station",
		"name": "Резервная насосная станция",
		"display_name": "Резервная насосная станция",
		"fuel": 40.0,
		"scrap": 0,
		"supplies": 0,
		"description": "Автономный узел перекачки топлива станции."
	},
	{
		"id": 19,
		"biome_index": 4,
		"biome": 5,
		"distance_m": 4700.0,
		"x": 4700.0,
		"offset_y_m": 12.0,
		"y": 12.0,
		"type": "semaphore",
		"name": "Железнодорожный семафор",
		"display_name": "Железнодорожный семафор",
		"fuel": 30.0,
		"scrap": 0,
		"supplies": 1,
		"description": "Обледеневший семафор подъездных путей станции."
	},
	{
		"id": 20,
		"biome_index": 4,
		"biome": 5,
		"distance_m": 4950.0,
		"x": 4950.0,
		"offset_y_m": 0.0,
		"y": 0.0,
		"type": "station_gate",
		"name": "Врата Станции «Полюс»",
		"display_name": "Врата Станции «Полюс»",
		"fuel": 40.0,
		"scrap": 0,
		"supplies": 0,
		"description": "Массивные противоштормовые ворота спасительной полярной станции."
	}
]

static func get_total_poi_resources() -> Dictionary:
	var total_fuel: float = 0.0
	var total_scrap: int = 0
	var total_supplies: int = 0
	for poi in POI_SITES:
		total_fuel += poi.fuel
		total_scrap += poi.scrap
		total_supplies += poi.supplies
	return {
		"fuel": total_fuel,
		"scrap": total_scrap,
		"supplies": total_supplies
	}

static func get_grand_total_resources() -> Dictionary:
	var poi_totals: Dictionary = get_total_poi_resources()
	return {
		"fuel": poi_totals.fuel + STARTING_RESERVE_FUEL,
		"scrap": poi_totals.scrap + STARTING_RESERVE_SCRAP,
		"supplies": poi_totals.supplies + STARTING_RESERVE_SUPPLIES
	}

static func get_biome_at_distance(distance_m: float) -> Dictionary:
	var clamped_dist: float = clampf(distance_m, 0.0, ROUTE_LENGTH_METERS)
	var idx: int = int(clamped_dist / BIOME_LENGTH_METERS)
	if idx >= BIOMES.size():
		idx = BIOMES.size() - 1
	return BIOMES[idx]
