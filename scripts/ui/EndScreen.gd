# scripts/ui/EndScreen.gd
class_name EndScreen
extends CanvasLayer

## Victory & Defeat Modal Dashboard for «Шагающий дом».
## Displays run statistics, root cause of failure or victory celebration, and replay/menu buttons.

@onready var root_control: Control = get_node_or_null("RootControl")
@onready var title_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SubTitleLabel")

# Stats labels
@onready var stat_distance_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/DistVal")
@onready var stat_time_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/TimeVal")
@onready var stat_fuel_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/FuelVal")
@onready var stat_scrap_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/ScrapVal")
@onready var stat_supplies_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/SuppliesVal")
@onready var stat_repairs_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/RepairsVal")
@onready var stat_upgrades_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/UpgradesVal")
@onready var stat_blizzards_val: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/BlizzardsVal")

# Buttons
@onready var retry_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/RetryButton")
@onready var menu_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/MenuButton")

var is_shown: bool = false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resolve_references()
	
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)
		
	_connect_event_bus()

func _resolve_references() -> void:
	if root_control == null:
		root_control = get_node_or_null("RootControl")
	if title_label == null:
		title_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/TitleLabel")
	if subtitle_label == null:
		subtitle_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SubTitleLabel")
	if stat_distance_val == null:
		stat_distance_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/DistVal")
	if stat_time_val == null:
		stat_time_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/TimeVal")
	if stat_fuel_val == null:
		stat_fuel_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/FuelVal")
	if stat_scrap_val == null:
		stat_scrap_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/ScrapVal")
	if stat_supplies_val == null:
		stat_supplies_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/SuppliesVal")
	if stat_repairs_val == null:
		stat_repairs_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/RepairsVal")
	if stat_upgrades_val == null:
		stat_upgrades_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/UpgradesVal")
	if stat_blizzards_val == null:
		stat_blizzards_val = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/BlizzardsVal")
	if retry_button == null:
		retry_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/RetryButton")
	if menu_button == null:
		menu_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/MenuButton")

func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if bus == null:
		return
	if bus.has_signal("victory_triggered"):
		bus.connect("victory_triggered", Callable(self, "_on_victory_triggered"))
	if bus.has_signal("game_over_triggered"):
		bus.connect("game_over_triggered", Callable(self, "_on_game_over_triggered"))

func show_victory(stats: Dictionary) -> void:
	_resolve_references()
	if is_shown:
		return
	is_shown = true
	visible = true
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = true
	
	if title_label != null:
		title_label.text = "🏆 СТАНЦИЯ ДОСТИГНУТА! ПОБЕДА!"
		title_label.modulate = Color(0.4, 0.95, 0.5, 1.0) # Warm green
	if subtitle_label != null:
		subtitle_label.text = "Шагающий дом преодолел 5000 метров ледяной пустоши и добрался до тепла заброшенной геотермальной станции!"
		subtitle_label.modulate = Color(0.85, 0.95, 0.85, 0.9)
		
	_populate_stats(stats)
	
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("loot")

func show_defeat(reason: String, stats: Dictionary) -> void:
	_resolve_references()
	if is_shown:
		return
	is_shown = true
	visible = true
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = true
	
	if title_label != null:
		title_label.text = "☠ ЭКСПЕДИЦИЯ ПОГИБЛА"
		title_label.modulate = Color(1.0, 0.3, 0.3, 1.0) # Frost red
	if subtitle_label != null:
		var clean_reason = reason
		if reason.begins_with("deadlock:"):
			clean_reason = reason.substr(9).strip_edges()
		elif reason.is_empty():
			clean_reason = "Критическое обморожение исследователя."
		subtitle_label.text = "Причина: %s" % clean_reason
		subtitle_label.modulate = Color(1.0, 0.75, 0.75, 0.9)
		
	_populate_stats(stats)
	
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("error")

func _populate_stats(stats: Dictionary) -> void:
	var dist: float = stats.get("final_distance", stats.get("distance_traveled", 0.0))
	var time_sec: float = stats.get("time_elapsed", 0.0)
	var mins: int = int(floor(time_sec / 60.0))
	var secs: int = int(floor(fmod(time_sec, 60.0)))
	
	if stat_distance_val != null:
		stat_distance_val.text = "%.1f м / 5000.0 м" % dist
	if stat_time_val != null:
		stat_time_val.text = "%d мин %02d сек" % [mins, secs]
	if stat_fuel_val != null:
		stat_fuel_val.text = "%.1f л" % stats.get("fuel_collected", 0.0)
	if stat_scrap_val != null:
		stat_scrap_val.text = "%d шт." % int(stats.get("scrap_collected", 0.0))
	if stat_supplies_val != null:
		stat_supplies_val.text = "%d шт." % int(stats.get("supplies_collected", 0.0))
	if stat_repairs_val != null:
		stat_repairs_val.text = "%d раз" % stats.get("repairs_count", 0)
	if stat_upgrades_val != null:
		stat_upgrades_val.text = "%d из 3" % stats.get("upgrades_count", 0)
	if stat_blizzards_val != null:
		stat_blizzards_val.text = "%d" % stats.get("blizzards_survived", 0)

func _on_victory_triggered(stats: Dictionary) -> void:
	show_victory(stats)

func _on_game_over_triggered(reason: String, stats: Dictionary) -> void:
	show_defeat(reason, stats)

func _on_retry_pressed() -> void:
	is_shown = false
	visible = false
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	
	var gs = _get_game_state()
	if gs != null:
		gs.reset_state()
		
	var sm = _get_sound_manager()
	if sm != null:
		sm.stop_all()
		sm.play_sfx("click")
		
	if is_inside_tree() and get_tree() != null:
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	is_shown = false
	visible = false
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	
	var gs = _get_game_state()
	if gs != null:
		gs.reset_state()
		
	var sm = _get_sound_manager()
	if sm != null:
		sm.stop_all()
		sm.play_sfx("click")
		
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState")
	return null

func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null
