# scripts/autoload/EventBus.gd
# Global Decoupled Signal Dispatch for «Шагающий дом»
extends Node

# ==============================================================================
# 1. LOCOMOTION & HOUSE MECHANICS
# ==============================================================================
## Emitted when the house advances. distance_delta is meters moved this tick, total_distance is total meters traveled.
signal house_moved(distance_delta: float, total_distance: float)

## Emitted when house speed changes (e.g. acceleration, deceleration, leg degradation).
signal house_speed_changed(new_speed: float)

## Emitted when distance to target changes.
signal distance_changed(current: float, target: float)

## Emitted when the house is forcibly stopped due to zero fuel or destroyed legs.
signal critical_stop_triggered(reason: String)

# ==============================================================================
# 2. RESOURCES & INTEGRITY
# ==============================================================================
## Emitted whenever fuel level changes. current: current fuel, max_val: tank capacity.
signal fuel_changed(current: float, max_val: float)

## Emitted whenever leg durability changes. current: 0..100, max_val: 100.
signal leg_durability_changed(current: float, max_val: float)

## Companion alias for leg durability to guarantee compatibility with test suites.
signal leg_health_changed(current: float, max_val: float)

## Emitted when scrap metal amount changes.
signal scrap_changed(current: float)

## Emitted when mechanical supplies/rations amount changes.
signal supplies_changed(current: float)

## Bulk resource update signal for HUD status refresh.
signal resources_changed(scrap: float, fuel: float, supplies: float)

## Emitted when player repairs house legs.
signal repair_performed(scrap_spent: float, durability_restored: float)

## Emitted when an environmental resource container is scavenged.
signal resource_looted(type: String, amount: float, world_pos: Vector2)

# ==============================================================================
# 3. THERMODYNAMICS & HEATING
# ==============================================================================
## Emitted when cabin temperature changes.
signal cabin_temperature_changed(temp: float)

## Companion alias for cabin temperature.
signal cabin_temp_changed(temp: float)

## Emitted when heating stove is toggled on or off.
signal stove_toggled(is_on: bool)

## Emitted when stove turns off automatically (e.g. running out of fuel).
signal stove_extinguished(reason: String)

# ==============================================================================
# 4. PLAYER & EXPLORATION
# ==============================================================================
## Emitted when player re-enters the house cabin.
signal player_embarked()

## Emitted when player disembarks into the snow.
signal player_disembarked()

## Emitted when player mode switches (true: outside on foot, false: inside cabin).
signal player_mode_changed(is_outside: bool)

## Emitted when player HP changes. hp: 0..100, max_hp: 100.
signal player_health_changed(hp: float, max_hp: float)

## Emitted when player outdoor warmth/cold exposure buffer changes.
signal player_warmth_changed(current: float, max_warmth: float)

## Request UI HUD to show contextual interaction prompt (e.g. "[E] Обыскать ящик").
signal prompt_requested(text: String)

## Request UI HUD to hide contextual prompt.
signal prompt_cleared()

# ==============================================================================
# 5. UPGRADES
# ==============================================================================
## Emitted when an upgrade is unlocked/purchased.
signal upgrade_unlocked(upgrade_id: String)

## Emitted with upgrade level information.
signal upgrade_purchased(upgrade_id: String, new_level: int)

# ==============================================================================
# 6. WEATHER, ENVIRONMENT & TIME
# ==============================================================================
## Emitted when weather state or outdoor ambient temperature changes.
signal weather_changed(weather_state: int, ambient_temp: float)

## Advance 20-second warning before a blizzard squall strikes.
signal blizzard_warning_triggered(seconds_left: float)

## Blizzard squall begins.
signal blizzard_started()

## Blizzard squall ends.
signal blizzard_ended()

## Companion storm signals.
signal storm_warning(seconds_remaining: float)
signal storm_started()
signal storm_ended()

## Time of day progression clock.
signal time_updated(time_of_day: float, hour_str: String)

# ==============================================================================
# 7. LIFECYCLE & VICTORY / DEFEAT
# ==============================================================================
## Emitted when deadlock detection engine identifies unwinnable softlock.
signal deadlock_detected()

## Emitted when house reaches destination station (5000 m).
signal victory_triggered(stats: Dictionary)

## Companion victory signal.
signal victory_reached()

## Emitted when player dies of hypothermia or reaches terminal defeat.
signal game_over_triggered(reason: String, stats: Dictionary)

## Emitted when new game is started or restart button is clicked.
signal game_restarted()
