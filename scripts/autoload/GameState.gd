# scripts/autoload/GameState.gd
# Global State Store & Reactive Manager for «Шагающий дом»
extends Node

const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")

# ==============================================================================
# CONSTANTS & BALANCING CONFIGURATION
# ==============================================================================
const MAX_FUEL: float = 100.0
const MAX_LEG_DURABILITY: float = 100.0
const MAX_PLAYER_HEALTH: float = 100.0
const MAX_PLAYER_WARMTH: float = 100.0
const TARGET_DISTANCE: float = 5000.0

const CABIN_START_TEMP: float = 18.0
const CABIN_MIN_TEMP: float = -35.0
const CABIN_MAX_TEMP: float = 30.0
const FREEZING_THRESHOLD: float = 0.0

const UPGRADE_INSULATION: String = "insulation"
const UPGRADE_ENGINE: String = "engine"
const UPGRADE_LEGS: String = "reinforced_legs"

enum WeatherState {
	CLEAR = 0,
	OVERCAST = 1,
	BLIZZARD = 2
}

signal stove_extinguished(reason: String)
signal deadlock_detected()

# ==============================================================================
# RUNTIME STATE VARIABLES
# ==============================================================================
# 1. House & Locomotion
var fuel: float = 100.0
var max_fuel: float = MAX_FUEL
var leg_durability: float = 100.0
var max_leg_durability: float = MAX_LEG_DURABILITY
var distance_traveled: float = 0.0
var target_distance: float = TARGET_DISTANCE
var house_speed: float = 0.0
var is_house_moving: bool = false
var is_player_outside: bool = false

# 2. Cabin & Player Survival
var cabin_temperature: float = CABIN_START_TEMP
var outside_temperature: float = -15.0
var is_stove_on: bool = false
var player_health: float = 100.0
var max_player_health: float = MAX_PLAYER_HEALTH
var player_warmth: float = 100.0
var max_player_warmth: float = MAX_PLAYER_WARMTH

# 3. Economy & Scavenged Supplies
var scrap: float = 0.0
var supplies: float = 5.0

# 4. Upgrades (Level 0 = not installed, Level 1..3 = installed)
var upgrades: Dictionary = {
	UPGRADE_INSULATION: 0,
	UPGRADE_ENGINE: 0,
	UPGRADE_LEGS: 0
}

# 5. Weather & Time
var weather_state: int = WeatherState.CLEAR
var is_blizzard: bool = false
var blizzard_warning_active: bool = false
var time_of_day: float = 8.0 # 08:00 AM
var day_count: int = 1

# 6. Game Lifecycle Flags
var is_game_active: bool = true
var is_game_paused: bool = false
var is_game_over: bool = false
var is_victory: bool = false
var elapsed_time: float = 0.0
var game_over_reason: String = ""

# 7. Summary Run Statistics
var stats: Dictionary = {
	"time_elapsed": 0.0,
	"distance_traveled": 0.0,
	"fuel_consumed": 0.0,
	"fuel_collected": 0.0,
	"scrap_collected": 0.0,
	"scrap_spent_repairs": 0.0,
	"scrap_spent_upgrades": 0.0,
	"supplies_collected": 0.0,
	"repairs_count": 0,
	"upgrades_count": 0,
	"blizzards_survived": 0
}

# ==============================================================================
# ENGINE LIFECYCLE
# ==============================================================================
func _ready() -> void:
	reset_state()

func _process(delta: float) -> void:
	if is_game_active and not is_game_paused and not is_game_over and not is_victory:
		elapsed_time += delta
		stats["time_elapsed"] = elapsed_time
		_process_thermodynamics_and_survival(delta)

func _process_thermodynamics_and_survival(delta: float) -> void:
	if delta <= 0.0:
		return
		
	# 1. Stove fuel consumption
	if is_stove_on:
		var fuel_burn: float = SimulationLogic.calculate_stove_fuel(true, delta, BalanceConfig.STOVE_FUEL_RATE)
		consume_fuel(fuel_burn)
		
	# 2. Cabin temperature evolution
	var has_insulation: bool = has_insulation_upgrade()
	var new_temp: float = SimulationLogic.calculate_cabin_temperature(
		cabin_temperature,
		outside_temperature,
		is_stove_on,
		has_insulation,
		is_blizzard,
		delta,
		BalanceConfig.CABIN_BASE_COOLING_RATE,
		BalanceConfig.STOVE_HEATING_RATE,
		BalanceConfig.CABIN_BLIZZARD_COOLING_MULT,
		0.45,
		BalanceConfig.CABIN_MAX_TEMP
	)
	set_cabin_temperature(new_temp)
	
	# 3. Inside cabin survival dynamics
	if not is_player_outside:
		if cabin_temperature < BalanceConfig.CABIN_FREEZE_THRESHOLD:
			var freeze_dmg: float = SimulationLogic.calculate_cabin_cold_damage(
				cabin_temperature, 
				delta, 
				BalanceConfig.INDOOR_FREEZE_DAMAGE_RATE
			)
			if freeze_dmg > 0.0:
				damage_player(freeze_dmg)
			set_player_warmth(maxf(0.0, player_warmth - 15.0 * delta))
		elif cabin_temperature >= BalanceConfig.CABIN_COMFORT_TEMP:
			set_player_warmth(minf(max_player_warmth, player_warmth + 25.0 * delta))
			if player_health < max_player_health:
				var recovery: float = SimulationLogic.calculate_warmth_recovery(
					cabin_temperature, 
					delta, 
					BalanceConfig.INDOOR_FREEZE_DAMAGE_RATE, 
					BalanceConfig.CABIN_COMFORT_TEMP
				)
				if recovery > 0.0:
					heal_player(recovery)

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	elif is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null

func _emit_bus(signal_name: String, args: Array = []) -> void:
	if has_signal(signal_name):
		match args.size():
			0:
				emit_signal(signal_name)
			1:
				emit_signal(signal_name, args[0])
			2:
				emit_signal(signal_name, args[0], args[1])
			3:
				emit_signal(signal_name, args[0], args[1], args[2])
			_:
				callv("emit_signal", [signal_name] + args)
	var bus_node: Node = null
	if Engine.has_singleton("EventBus"):
		bus_node = Engine.get_singleton("EventBus")
	elif is_inside_tree() and get_tree().root.has_node("EventBus"):
		bus_node = get_tree().root.get_node("EventBus")
	
	if bus_node != null and bus_node.has_signal(signal_name):
		match args.size():
			0:
				bus_node.emit_signal(signal_name)
			1:
				bus_node.emit_signal(signal_name, args[0])
			2:
				bus_node.emit_signal(signal_name, args[0], args[1])
			3:
				bus_node.emit_signal(signal_name, args[0], args[1], args[2])
			_:
				bus_node.callv("emit_signal", [signal_name] + args)

# ==============================================================================
# FUEL & ENGINE REACTIVE METHODS
# ==============================================================================
func consume_fuel(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var actual: float = min(amount, fuel)
	fuel = max(0.0, fuel - actual)
	stats["fuel_consumed"] += actual
	
	_emit_bus("fuel_changed", [fuel, max_fuel])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	
	# Reactive Hook: Auto-cutoff stove and halt movement when fuel hits zero
	if fuel <= 0.0:
		if is_stove_on:
			is_stove_on = false
			_emit_bus("stove_toggled", [false])
			_emit_bus("stove_extinguished", ["out_of_fuel"])
			var sm: Node = _get_sound_manager()
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("stove_extinguish")
		if is_house_moving:
			is_house_moving = false
			house_speed = 0.0
			_emit_bus("house_speed_changed", [0.0])
			_emit_bus("critical_stop_triggered", ["Топливо исчерпано"])
			
	return actual

func add_fuel(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var prev: float = fuel
	fuel = min(max_fuel, fuel + amount)
	var added: float = fuel - prev
	stats["fuel_collected"] += amount
	
	_emit_bus("fuel_changed", [fuel, max_fuel])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	return added

func set_fuel(val: float) -> void:
	fuel = clamp(val, 0.0, max_fuel)
	_emit_bus("fuel_changed", [fuel, max_fuel])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	if fuel <= 0.0:
		if is_stove_on:
			is_stove_on = false
			_emit_bus("stove_toggled", [false])
			_emit_bus("stove_extinguished", ["out_of_fuel"])
		if is_house_moving:
			is_house_moving = false
			house_speed = 0.0
			_emit_bus("house_speed_changed", [0.0])
			_emit_bus("critical_stop_triggered", ["Топливо исчерпано"])

# ==============================================================================
# LEG DURABILITY & REPAIR REACTIVE METHODS
# ==============================================================================
func wear_legs(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var actual: float = min(amount, leg_durability)
	leg_durability = max(0.0, leg_durability - actual)
	
	_emit_bus("leg_durability_changed", [leg_durability, max_leg_durability])
	_emit_bus("leg_health_changed", [leg_durability, max_leg_durability])
	
	# Reactive Hook: Critical halt when legs collapse
	if leg_durability <= 0.0 and is_house_moving:
		is_house_moving = false
		house_speed = 0.0
		_emit_bus("house_speed_changed", [0.0])
		_emit_bus("critical_stop_triggered", ["Шасси разрушено"])
		
	return actual

func set_leg_durability(val: float) -> void:
	leg_durability = clamp(val, 0.0, max_leg_durability)
	_emit_bus("leg_durability_changed", [leg_durability, max_leg_durability])
	_emit_bus("leg_health_changed", [leg_durability, max_leg_durability])
	if leg_durability <= 0.0 and is_house_moving:
		is_house_moving = false
		house_speed = 0.0
		_emit_bus("house_speed_changed", [0.0])
		_emit_bus("critical_stop_triggered", ["Шасси разрушено"])

func repair_legs(durability_gain: float = 20.0, scrap_cost: float = 1.0) -> bool:
	if is_player_outside:
		return false
	if scrap < scrap_cost:
		return false
	if leg_durability >= max_leg_durability:
		return false
		
	var repair_res: Dictionary = SimulationLogic.apply_repair(
		leg_durability, 
		minf(scrap_cost, scrap), 
		max_leg_durability, 
		durability_gain
	)
	var spent: float = repair_res.get("scrap_spent", scrap_cost)
	var new_dur: float = repair_res.get("new_durability", minf(max_leg_durability, leg_durability + durability_gain))
	
	if spent <= 0.0:
		return false
		
	var actual_gain: float = new_dur - leg_durability
	spend_scrap(spent)
	leg_durability = new_dur
	stats["repairs_count"] += 1
	stats["scrap_spent_repairs"] += spent
	
	_emit_bus("repair_performed", [spent, actual_gain])
	_emit_bus("leg_durability_changed", [leg_durability, max_leg_durability])
	_emit_bus("leg_health_changed", [leg_durability, max_leg_durability])
	return true

# ==============================================================================
# INVENTORY & SCAVENGING
# ==============================================================================
func add_scrap(amount: float) -> float:
	scrap += amount
	stats["scrap_collected"] += amount
	_emit_bus("scrap_changed", [scrap])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	return scrap

func spend_scrap(amount: float) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	_emit_bus("scrap_changed", [scrap])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	return true

func set_scrap(val: float) -> void:
	scrap = max(0.0, val)
	_emit_bus("scrap_changed", [scrap])
	_emit_bus("resources_changed", [scrap, fuel, supplies])

func add_supplies(amount: float) -> float:
	supplies += amount
	stats["supplies_collected"] += amount
	_emit_bus("supplies_changed", [supplies])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	return supplies

func spend_supplies(amount: float) -> bool:
	if supplies < amount:
		return false
	supplies -= amount
	_emit_bus("supplies_changed", [supplies])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	return true

func set_supplies(val: float) -> void:
	supplies = max(0.0, val)
	_emit_bus("supplies_changed", [supplies])
	_emit_bus("resources_changed", [scrap, fuel, supplies])

func collect_resource(type: String, amount: float, world_pos: Vector2 = Vector2.ZERO) -> void:
	match type.to_lower():
		"fuel":
			add_fuel(amount)
		"scrap":
			add_scrap(amount)
		"supplies", "rations":
			add_supplies(amount)
	_emit_bus("resource_looted", [type, amount, world_pos])

# ==============================================================================
# THERMODYNAMICS & STOVE
# ==============================================================================
func set_cabin_temperature(val: float) -> void:
	var clamped: float = clamp(val, CABIN_MIN_TEMP, CABIN_MAX_TEMP)
	if abs(clamped - cabin_temperature) > 0.001:
		cabin_temperature = clamped
		_emit_bus("cabin_temperature_changed", [cabin_temperature])
		_emit_bus("cabin_temp_changed", [cabin_temperature])

func toggle_stove() -> bool:
	if is_player_outside:
		_emit_bus("prompt_requested", ["Нельзя управлять печью снаружи дома!"])
		return false
	if is_stove_on:
		is_stove_on = false
		_emit_bus("stove_toggled", [false])
		return false
	else:
		if fuel <= 0.0:
			var sm: Node = _get_sound_manager()
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("error")
			_emit_bus("prompt_requested", ["Нет топлива для розжига печи!"])
			return false
		is_stove_on = true
		_emit_bus("stove_toggled", [true])
		return true

func set_stove(on: bool) -> bool:
	if on and (fuel <= 0.0 or is_player_outside):
		return false
	if is_stove_on != on:
		is_stove_on = on
		_emit_bus("stove_toggled", [is_stove_on])
	return is_stove_on

# ==============================================================================
# PLAYER HEALTH & WARMTH
# ==============================================================================
func set_player_health(val: float) -> void:
	var clamped: float = clamp(val, 0.0, max_player_health)
	if abs(clamped - player_health) > 0.001:
		player_health = clamped
		_emit_bus("player_health_changed", [player_health, max_player_health])
		if player_health <= 0.0 and not is_game_over and not is_victory:
			trigger_game_over("freeze: Переохлаждение: жизненные показатели упали до нуля")

func damage_player(amount: float) -> void:
	set_player_health(player_health - amount)

func heal_player(amount: float) -> void:
	set_player_health(player_health + amount)

func consume_supply_for_heal() -> bool:
	if supplies < 1.0 or player_health >= max_player_health:
		return false
	spend_supplies(1.0)
	heal_player(BalanceConfig.SUPPLY_HEAL_AMOUNT)
	var sm = _get_sound_manager()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("repair")
	return true

func set_player_warmth(val: float) -> void:
	var clamped: float = clamp(val, 0.0, max_player_warmth)
	if abs(clamped - player_warmth) > 0.001:
		player_warmth = clamped
		_emit_bus("player_warmth_changed", [player_warmth, max_player_warmth])

# ==============================================================================
# LOCOMOTION & DISTANCE PROGRESSION
# ==============================================================================
func add_distance(delta_m: float) -> void:
	if is_game_over or is_victory:
		return
	distance_traveled = clamp(distance_traveled + delta_m, 0.0, target_distance)
	stats["distance_traveled"] = distance_traveled
	
	_emit_bus("house_moved", [delta_m, distance_traveled])
	_emit_bus("distance_changed", [distance_traveled, target_distance])
	
	if distance_traveled >= target_distance and not is_victory:
		trigger_victory()

func set_distance_traveled(val: float) -> void:
	add_distance(val - distance_traveled)

func set_house_moving(moving: bool) -> bool:
	if moving:
		if fuel <= 0.0 or leg_durability <= 0.0 or is_player_outside or is_game_over or is_victory:
			is_house_moving = false
			return false
	is_house_moving = moving
	return is_house_moving

func set_house_speed(speed: float) -> void:
	house_speed = max(0.0, speed)
	_emit_bus("house_speed_changed", [house_speed])

# ==============================================================================
# EMBARK / DISEMBARK
# ==============================================================================
func disembark_player() -> bool:
	# Lockout: Cannot exit while house is moving
	if is_house_moving or is_player_outside or is_game_over or is_victory:
		return false
	is_player_outside = true
	_emit_bus("player_disembarked", [])
	_emit_bus("player_mode_changed", [true])
	return true

func embark_player() -> bool:
	if not is_player_outside or is_game_over or is_victory:
		return false
	is_player_outside = false
	_emit_bus("player_embarked", [])
	_emit_bus("player_mode_changed", [false])
	return true

# ==============================================================================
# UPGRADES SYSTEM
# ==============================================================================
func _get_canonical_upgrade_id(upgrade_id: String) -> String:
	match upgrade_id.to_lower():
		"insulation":
			return UPGRADE_INSULATION
		"engine", "efficient_engine":
			return UPGRADE_ENGINE
		"legs", "reinforced_legs":
			return UPGRADE_LEGS
		_:
			return upgrade_id

func can_afford_upgrade(upgrade_id: String, scrap_cost: float = 0.0, supplies_cost: float = 0.0, fuel_cost: float = 0.0) -> bool:
	var canon: String = _get_canonical_upgrade_id(upgrade_id)
	if has_upgrade(canon):
		return false
		
	if scrap_cost <= 0.0 and supplies_cost <= 0.0 and fuel_cost <= 0.0:
		match canon:
			UPGRADE_INSULATION:
				scrap_cost = 12.0
				supplies_cost = 6.0
			UPGRADE_ENGINE:
				scrap_cost = 15.0
				fuel_cost = 20.0
			UPGRADE_LEGS:
				scrap_cost = 18.0
				supplies_cost = 8.0
	return scrap >= scrap_cost and supplies >= supplies_cost and fuel >= fuel_cost

func purchase_upgrade(upgrade_id: String, scrap_cost: float = 0.0, supplies_cost: float = 0.0, fuel_cost: float = 0.0) -> bool:
	var canon: String = _get_canonical_upgrade_id(upgrade_id)
	# One-time purchase enforcement
	if has_upgrade(canon):
		return false
		
	if scrap_cost <= 0.0 and supplies_cost <= 0.0 and fuel_cost <= 0.0:
		match canon:
			UPGRADE_INSULATION:
				scrap_cost = 12.0
				supplies_cost = 6.0
			UPGRADE_ENGINE:
				scrap_cost = 15.0
				fuel_cost = 20.0
			UPGRADE_LEGS:
				scrap_cost = 18.0
				supplies_cost = 8.0
		
	if not can_afford_upgrade(canon, scrap_cost, supplies_cost, fuel_cost):
		return false
		
	spend_scrap(scrap_cost)
	if supplies_cost > 0.0:
		spend_supplies(supplies_cost)
	if fuel_cost > 0.0:
		consume_fuel(fuel_cost)
		
	var new_lvl: int = 1
	upgrades[canon] = new_lvl
	if canon != upgrade_id:
		upgrades[upgrade_id] = new_lvl
	stats["upgrades_count"] += 1
	stats["scrap_spent_upgrades"] += scrap_cost
	
	_emit_bus("upgrade_unlocked", [canon])
	_emit_bus("upgrade_purchased", [canon, new_lvl])
	return true

func has_insulation_upgrade() -> bool:
	var val = upgrades.get(UPGRADE_INSULATION, 0)
	if val is bool:
		return val
	return int(val) > 0

func has_engine_upgrade() -> bool:
	var val = upgrades.get(UPGRADE_ENGINE, 0)
	if val is bool:
		return val
	return int(val) > 0

func has_legs_upgrade() -> bool:
	var val = upgrades.get(UPGRADE_LEGS, 0)
	if val is bool:
		return val
	return int(val) > 0

func has_upgrade(upgrade_id: String) -> bool:
	var canon: String = _get_canonical_upgrade_id(upgrade_id)
	var v1 = upgrades.get(canon, 0)
	var v2 = upgrades.get(upgrade_id, 0)
	var b1: bool = v1 if v1 is bool else int(v1) > 0
	var b2: bool = v2 if v2 is bool else int(v2) > 0
	return b1 or b2

func get_upgrade_level(upgrade_id: String) -> int:
	var canon: String = _get_canonical_upgrade_id(upgrade_id)
	var v1 = upgrades.get(canon, 0)
	var v2 = upgrades.get(upgrade_id, 0)
	var lvl1: int = 1 if (v1 is bool and v1) else (0 if v1 is bool else int(v1))
	var lvl2: int = 1 if (v2 is bool and v2) else (0 if v2 is bool else int(v2))
	return max(lvl1, lvl2)

# ==============================================================================
# WEATHER & TIME
# ==============================================================================
func set_weather(state: int, ambient_temp: float) -> void:
	weather_state = state
	outside_temperature = ambient_temp
	
	if state == WeatherState.BLIZZARD:
		if not is_blizzard:
			is_blizzard = true
			_emit_bus("blizzard_started", [])
			_emit_bus("storm_started", [])
	else:
		if is_blizzard:
			is_blizzard = false
			stats["blizzards_survived"] += 1
			_emit_bus("blizzard_ended", [])
			_emit_bus("storm_ended", [])
			
	_emit_bus("weather_changed", [weather_state, outside_temperature])

func trigger_blizzard_warning(seconds: float = 20.0) -> void:
	blizzard_warning_active = true
	_emit_bus("blizzard_warning_triggered", [seconds])
	_emit_bus("storm_warning", [seconds])

func set_time_of_day(time_val: float) -> void:
	time_of_day = fmod(time_val, 24.0)
	var hrs: int = int(floor(time_of_day))
	var mins: int = int(floor((time_of_day - hrs) * 60.0))
	var hour_str: String = "%02d:%02d" % [hrs, mins]
	_emit_bus("time_updated", [time_of_day, hour_str])

# ==============================================================================
# END CONDITIONS & RESET
# ==============================================================================
func trigger_victory() -> void:
	if is_victory or is_game_over:
		return
	is_victory = true
	is_game_active = false
	is_house_moving = false
	house_speed = 0.0
	
	var final_stats = get_summary_stats()
	_emit_bus("victory_triggered", [final_stats])
	_emit_bus("victory_reached", [])

func trigger_game_over(reason: String) -> void:
	if is_victory or is_game_over:
		return
	is_game_over = true
	is_game_active = false
	is_house_moving = false
	house_speed = 0.0
	game_over_reason = reason
	
	var final_stats = get_summary_stats()
	_emit_bus("game_over_triggered", [reason, final_stats])

func trigger_deadlock(reason: String = "deadlock: Безысходный тупик: ресурсы исчерпаны, дальнейшее движение невозможно") -> void:
	if is_game_over or is_victory:
		return
	deadlock_detected.emit()
	_emit_bus("deadlock_detected", [])
	trigger_game_over(reason)

func get_summary_stats() -> Dictionary:
	var copy = stats.duplicate(true)
	copy["final_fuel"] = fuel
	copy["final_leg_durability"] = leg_durability
	copy["final_scrap"] = scrap
	copy["final_supplies"] = supplies
	copy["final_distance"] = distance_traveled
	copy["is_victory"] = is_victory
	copy["reason"] = game_over_reason
	return copy

func reset_state() -> void:
	fuel = MAX_FUEL
	max_fuel = MAX_FUEL
	leg_durability = MAX_LEG_DURABILITY
	max_leg_durability = MAX_LEG_DURABILITY
	distance_traveled = 0.0
	target_distance = TARGET_DISTANCE
	house_speed = 0.0
	is_house_moving = false
	is_player_outside = false
	
	cabin_temperature = CABIN_START_TEMP
	outside_temperature = -15.0
	is_stove_on = false
	player_health = MAX_PLAYER_HEALTH
	max_player_health = MAX_PLAYER_HEALTH
	player_warmth = MAX_PLAYER_WARMTH
	max_player_warmth = MAX_PLAYER_WARMTH
	
	scrap = 0.0
	supplies = 5.0
	
	upgrades = {
		UPGRADE_INSULATION: 0,
		UPGRADE_ENGINE: 0,
		UPGRADE_LEGS: 0
	}
	
	weather_state = WeatherState.CLEAR
	is_blizzard = false
	blizzard_warning_active = false
	time_of_day = 8.0
	day_count = 1
	
	is_game_active = true
	is_game_paused = false
	is_game_over = false
	is_victory = false
	elapsed_time = 0.0
	game_over_reason = ""
	
	stats = {
		"time_elapsed": 0.0,
		"distance_traveled": 0.0,
		"fuel_consumed": 0.0,
		"fuel_collected": 0.0,
		"scrap_collected": 0.0,
		"scrap_spent_repairs": 0.0,
		"scrap_spent_upgrades": 0.0,
		"supplies_collected": 0.0,
		"repairs_count": 0,
		"upgrades_count": 0,
		"blizzards_survived": 0
	}
	
	_emit_bus("game_restarted", [])
	_emit_bus("fuel_changed", [fuel, max_fuel])
	_emit_bus("leg_durability_changed", [leg_durability, max_leg_durability])
	_emit_bus("leg_health_changed", [leg_durability, max_leg_durability])
	_emit_bus("scrap_changed", [scrap])
	_emit_bus("supplies_changed", [supplies])
	_emit_bus("resources_changed", [scrap, fuel, supplies])
	_emit_bus("cabin_temperature_changed", [cabin_temperature])
	_emit_bus("cabin_temp_changed", [cabin_temperature])
	_emit_bus("player_health_changed", [player_health, max_player_health])
	_emit_bus("player_warmth_changed", [player_warmth, max_player_warmth])
	_emit_bus("house_moved", [0.0, 0.0])
	_emit_bus("distance_changed", [0.0, target_distance])
	_emit_bus("stove_toggled", [false])
	_emit_bus("player_mode_changed", [false])
	_emit_bus("weather_changed", [weather_state, outside_temperature])
