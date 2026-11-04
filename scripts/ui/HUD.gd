# scripts/ui/HUD.gd
# Russian Localization & Reactive Dashboard for «Шагающий дом»
# StyleBoxFlat dark frosted theme, 10 indicators in 100% Russian, EventBus reactive bindings.
class_name WalkingHouseHUD
extends CanvasLayer

# ==============================================================================
# UI NODE REFERENCES (Populated via @onready or procedural fallback)
# ==============================================================================
@onready var root_control: Control = get_node_or_null("RootControl")

# Indicator 1: Топливо
@onready var fuel_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/FuelContainer/FuelLabel")
@onready var fuel_bar: ProgressBar = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/FuelContainer/FuelBar")

# Indicator 2: Металлолом
@onready var scrap_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/ResHBox/ScrapLabel")

# Indicator 3: Припасы
@onready var supplies_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/ResHBox/SuppliesLabel")

# Indicator 4: Прочность опор
@onready var legs_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/LegsContainer/LegsLabel")
@onready var legs_bar: ProgressBar = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/LegsContainer/LegsBar")

# Indicator 5: Температура в доме
@onready var cabin_temp_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/CabinTempLabel")

# Indicator 6: Здоровье
@onready var health_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/HealthContainer/HealthLabel")
@onready var health_bar: ProgressBar = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/HealthBar")

# Indicator 7: Пройдено (м)
@onready var distance_traveled_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/DistTraveledLabel")

# Indicator 8: До станции (м)
@onready var distance_remaining_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/DistRemainingLabel")

# Indicator 9: Печь (ВКЛ/ВЫКЛ)
@onready var stove_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/StoveContainer/StoveLabel")
@onready var stove_button: Button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/StoveContainer/StoveButton")

# Maintenance buttons
@onready var repair_button: Button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/MaintenanceHBox/RepairButton")
@onready var upgrades_button: Button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/MaintenanceHBox/UpgradesButton")

# Indicator 10: Погода
@onready var weather_label: Label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/WeatherLabel")

# Supplementary UI Elements
@onready var alert_banner: PanelContainer = get_node_or_null("RootControl/AlertBanner")
@onready var alert_label: Label = get_node_or_null("RootControl/AlertBanner/AlertLabel")
@onready var prompt_container: PanelContainer = get_node_or_null("RootControl/PromptContainer")
@onready var prompt_label: Label = get_node_or_null("RootControl/PromptContainer/PromptLabel")
@onready var controls_hint_label: Label = get_node_or_null("RootControl/ControlsHint")

var current_hour_str: String = "08:00"

# Weather names dictionary in Russian
const WEATHER_NAMES: Dictionary = {
	0: "Ясно",
	1: "Пасмурно",
	2: "МЕТЕЛЬ!"
}

# ==============================================================================
# LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	# If running headlessly or dynamically instantiated without .tscn node hierarchy:
	if root_control == null:
		_build_procedural_ui()
	else:
		_resolve_node_references()
		
	_apply_dark_frosted_theme()
	_connect_event_bus()
	
	if stove_button != null:
		stove_button.pressed.connect(_on_stove_button_pressed)
	if repair_button != null:
		repair_button.pressed.connect(_on_repair_button_pressed)
	if upgrades_button != null:
		upgrades_button.pressed.connect(_on_upgrades_button_pressed)
		
	sync_all_indicators()

func _resolve_node_references() -> void:
	if fuel_label == null:
		fuel_label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/FuelContainer/FuelLabel")
	if fuel_bar == null:
		fuel_bar = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/FuelContainer/FuelBar")
	if scrap_label == null:
		scrap_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/ResHBox/ScrapLabel")
		if scrap_label == null:
			scrap_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/ScrapLabel")
	if supplies_label == null:
		supplies_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/ResHBox/SuppliesLabel")
		if supplies_label == null:
			supplies_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/SuppliesLabel")
	if legs_label == null:
		legs_label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/LegsContainer/LegsLabel")
	if legs_bar == null:
		legs_bar = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/LegsContainer/LegsBar")
	if cabin_temp_label == null:
		cabin_temp_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/CabinTempLabel")
	if health_label == null:
		health_label = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/HealthContainer/HealthLabel")
	if health_bar == null:
		health_bar = get_node_or_null("RootControl/TopMargin/MainHBox/CrewPanel/VBox/HealthBar")
	if distance_traveled_label == null:
		distance_traveled_label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/DistTraveledLabel")
	if distance_remaining_label == null:
		distance_remaining_label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/DistRemainingLabel")
	if stove_label == null:
		stove_label = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/StoveContainer/StoveLabel")
	if stove_button == null:
		stove_button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/StoveContainer/StoveButton")
	if weather_label == null:
		weather_label = get_node_or_null("RootControl/TopMargin/MainHBox/NavPanel/VBox/WeatherLabel")
	if alert_banner == null:
		alert_banner = get_node_or_null("RootControl/AlertBanner")
	if alert_label == null:
		alert_label = get_node_or_null("RootControl/AlertBanner/AlertLabel")
	if prompt_container == null:
		prompt_container = get_node_or_null("RootControl/PromptContainer")
	if prompt_label == null:
		prompt_label = get_node_or_null("RootControl/PromptContainer/PromptLabel")
	if controls_hint_label == null:
		controls_hint_label = get_node_or_null("RootControl/ControlsHint")
	if repair_button == null:
		repair_button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/MaintenanceHBox/RepairButton")
	if upgrades_button == null:
		upgrades_button = get_node_or_null("RootControl/TopMargin/MainHBox/HousePanel/VBox/MaintenanceHBox/UpgradesButton")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stove"):
		_on_stove_button_pressed()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		_on_repair_button_pressed()

# ==============================================================================
# THEME: DARK FROSTED GLASS (StyleBoxFlat)
# ==============================================================================
func _create_dark_frosted_stylebox(bg_alpha: float = 0.88) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, bg_alpha)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.24, 0.38, 0.52, 0.75)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 8.0
	return sb

func _create_bar_fill_stylebox(fill_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	return sb

func _apply_dark_frosted_theme() -> void:
	var frosted_box = _create_dark_frosted_stylebox()
	for panel_name in ["HousePanel", "NavPanel", "CrewPanel"]:
		var p: PanelContainer = get_node_or_null("RootControl/TopMargin/MainHBox/" + panel_name)
		if p != null:
			p.add_theme_stylebox_override("panel", frosted_box)
			
	if alert_banner != null:
		var alert_box: StyleBoxFlat = _create_dark_frosted_stylebox(0.92)
		alert_box.bg_color = Color(0.25, 0.05, 0.05, 0.92)
		alert_box.border_color = Color(0.95, 0.25, 0.25, 0.9)
		alert_banner.add_theme_stylebox_override("panel", alert_box)
		
	if prompt_container != null:
		var prompt_box: StyleBoxFlat = _create_dark_frosted_stylebox(0.85)
		prompt_box.border_color = Color(0.40, 0.60, 0.80, 0.8)
		prompt_container.add_theme_stylebox_override("panel", prompt_box)

# ==============================================================================
# PROCEDURAL UI FALLBACK BUILDER (For Headless & Code-Only Instantiation)
# ==============================================================================
func _build_procedural_ui() -> void:
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	
	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.name = "TopMargin"
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_right", 16)
	root_control.add_child(top_margin)
	
	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.add_theme_constant_override("separation", 16)
	top_margin.add_child(main_hbox)
	
	# 1. House Panel (Шасси и двигатель)
	var house_panel: PanelContainer = PanelContainer.new()
	house_panel.name = "HousePanel"
	house_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(house_panel)
	
	var house_vbox: VBoxContainer = VBoxContainer.new()
	house_vbox.name = "VBox"
	house_panel.add_child(house_vbox)
	
	var house_title: Label = Label.new()
	house_title.text = "⚙ ШАССИ И ДВИГАТЕЛЬ"
	house_title.modulate = Color(0.75, 0.85, 0.95)
	house_vbox.add_child(house_title)
	
	var fuel_container: VBoxContainer = VBoxContainer.new()
	fuel_container.name = "FuelContainer"
	house_vbox.add_child(fuel_container)
	fuel_label = Label.new()
	fuel_label.name = "FuelLabel"
	fuel_label.text = "Топливо: 100.0 / 100.0 л"
	fuel_container.add_child(fuel_label)
	fuel_bar = ProgressBar.new()
	fuel_bar.name = "FuelBar"
	fuel_bar.min_value = 0.0
	fuel_bar.max_value = 100.0
	fuel_bar.value = 100.0
	fuel_bar.custom_minimum_size = Vector2(0, 14)
	fuel_bar.show_percentage = false
	fuel_bar.add_theme_stylebox_override("fill", _create_bar_fill_stylebox(Color(0.95, 0.60, 0.10, 0.9)))
	fuel_container.add_child(fuel_bar)
	
	var legs_container: VBoxContainer = VBoxContainer.new()
	legs_container.name = "LegsContainer"
	house_vbox.add_child(legs_container)
	legs_label = Label.new()
	legs_label.name = "LegsLabel"
	legs_label.text = "Прочность опор: 100.0%"
	legs_container.add_child(legs_label)
	legs_bar = ProgressBar.new()
	legs_bar.name = "LegsBar"
	legs_bar.min_value = 0.0
	legs_bar.max_value = 100.0
	legs_bar.value = 100.0
	legs_bar.custom_minimum_size = Vector2(0, 14)
	legs_bar.show_percentage = false
	legs_bar.add_theme_stylebox_override("fill", _create_bar_fill_stylebox(Color(0.20, 0.70, 0.85, 0.9)))
	legs_container.add_child(legs_bar)
	
	var maint_hbox: HBoxContainer = HBoxContainer.new()
	maint_hbox.name = "MaintenanceHBox"
	house_vbox.add_child(maint_hbox)
	repair_button = Button.new()
	repair_button.name = "RepairButton"
	repair_button.text = "[R] Ремонт"
	repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maint_hbox.add_child(repair_button)
	upgrades_button = Button.new()
	upgrades_button.name = "UpgradesButton"
	upgrades_button.text = "[U] Верстак"
	upgrades_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maint_hbox.add_child(upgrades_button)
	
	var stove_container: HBoxContainer = HBoxContainer.new()
	stove_container.name = "StoveContainer"
	house_vbox.add_child(stove_container)
	stove_label = Label.new()
	stove_label.name = "StoveLabel"
	stove_label.text = "Печь: ВЫКЛ"
	stove_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stove_container.add_child(stove_label)
	stove_button = Button.new()
	stove_button.name = "StoveButton"
	stove_button.text = "[F] Печь"
	stove_container.add_child(stove_button)
	
	# 2. Nav Panel (Навигация и погода)
	var nav_panel: PanelContainer = PanelContainer.new()
	nav_panel.name = "NavPanel"
	nav_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(nav_panel)
	
	var nav_vbox: VBoxContainer = VBoxContainer.new()
	nav_vbox.name = "VBox"
	nav_panel.add_child(nav_vbox)
	
	var nav_title: Label = Label.new()
	nav_title.text = "🧭 НАВИГАЦИЯ И ПОГОДА"
	nav_title.modulate = Color(0.75, 0.85, 0.95)
	nav_vbox.add_child(nav_title)
	
	distance_traveled_label = Label.new()
	distance_traveled_label.name = "DistTraveledLabel"
	distance_traveled_label.text = "Пройдено: 0.0 м"
	nav_vbox.add_child(distance_traveled_label)
	
	distance_remaining_label = Label.new()
	distance_remaining_label.name = "DistRemainingLabel"
	distance_remaining_label.text = "До станции: 5000.0 м"
	nav_vbox.add_child(distance_remaining_label)
	
	weather_label = Label.new()
	weather_label.name = "WeatherLabel"
	weather_label.text = "Погода: Ясно (-15.0°C)"
	nav_vbox.add_child(weather_label)
	
	# 3. Crew Panel (Экипаж и ресурсы)
	var crew_panel: PanelContainer = PanelContainer.new()
	crew_panel.name = "CrewPanel"
	crew_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(crew_panel)
	
	var crew_vbox: VBoxContainer = VBoxContainer.new()
	crew_vbox.name = "VBox"
	crew_panel.add_child(crew_vbox)
	
	var crew_title: Label = Label.new()
	crew_title.text = "👤 ЭКИПАЖ И РЕСУРСЫ"
	crew_title.modulate = Color(0.75, 0.85, 0.95)
	crew_vbox.add_child(crew_title)
	
	var health_container: VBoxContainer = VBoxContainer.new()
	health_container.name = "HealthContainer"
	crew_vbox.add_child(health_container)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "Здоровье: 100 / 100 HP"
	health_container.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.custom_minimum_size = Vector2(0, 14)
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("fill", _create_bar_fill_stylebox(Color(0.85, 0.20, 0.25, 0.9)))
	crew_vbox.add_child(health_bar)
	
	cabin_temp_label = Label.new()
	cabin_temp_label.name = "CabinTempLabel"
	cabin_temp_label.text = "Температура в доме: +18.0°C"
	crew_vbox.add_child(cabin_temp_label)
	
	var res_hbox: HBoxContainer = HBoxContainer.new()
	res_hbox.name = "ResHBox"
	crew_vbox.add_child(res_hbox)
	
	scrap_label = Label.new()
	scrap_label.name = "ScrapLabel"
	scrap_label.text = "Металлолом: 0 шт."
	scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_hbox.add_child(scrap_label)
	
	supplies_label = Label.new()
	supplies_label.name = "SuppliesLabel"
	supplies_label.text = "Припасы: 5 шт."
	supplies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_hbox.add_child(supplies_label)
	
	# Alert Banner
	alert_banner = PanelContainer.new()
	alert_banner.name = "AlertBanner"
	alert_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_banner.position = Vector2(400, 150)
	alert_banner.visible = false
	root_control.add_child(alert_banner)
	
	alert_label = Label.new()
	alert_label.name = "AlertLabel"
	alert_label.text = "ВНИМАНИЕ"
	alert_banner.add_child(alert_label)
	
	# Context Prompt Container
	prompt_container = PanelContainer.new()
	prompt_container.name = "PromptContainer"
	prompt_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_container.position = Vector2(480, 620)
	prompt_container.visible = false
	root_control.add_child(prompt_container)
	
	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = ""
	prompt_container.add_child(prompt_label)
	
	# Controls Hint
	controls_hint_label = Label.new()
	controls_hint_label.name = "ControlsHint"
	controls_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls_hint_label.text = "[A/D] Движение | [E] Выход/Вход | [F] Печь | [U] Улучшения | [Esc] Меню"
	controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint_label.position = Vector2(0, 690)
	controls_hint_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	root_control.add_child(controls_hint_label)

# ==============================================================================
# EVENTBUS SIGNAL BINDINGS
# ==============================================================================
func _connect_event_bus() -> void:
	var bus: Node = null
	if Engine.has_singleton("EventBus"):
		bus = Engine.get_singleton("EventBus")
	elif is_inside_tree() and get_tree().root.has_node("EventBus"):
		bus = get_tree().root.get_node("EventBus")
	else:
		var loop = Engine.get_main_loop()
		if loop is SceneTree and loop.root != null and loop.root.has_node("EventBus"):
			bus = loop.root.get_node("EventBus")
		
	if bus == null:
		return
		
	if bus.has_signal("fuel_changed"):
		bus.connect("fuel_changed", Callable(self, "_on_fuel_changed"))
	if bus.has_signal("leg_durability_changed"):
		bus.connect("leg_durability_changed", Callable(self, "_on_leg_durability_changed"))
	if bus.has_signal("scrap_changed"):
		bus.connect("scrap_changed", Callable(self, "_on_scrap_changed"))
	if bus.has_signal("supplies_changed"):
		bus.connect("supplies_changed", Callable(self, "_on_supplies_changed"))
	if bus.has_signal("cabin_temperature_changed"):
		bus.connect("cabin_temperature_changed", Callable(self, "_on_cabin_temperature_changed"))
	if bus.has_signal("player_health_changed"):
		bus.connect("player_health_changed", Callable(self, "_on_player_health_changed"))
	if bus.has_signal("distance_changed"):
		bus.connect("distance_changed", Callable(self, "_on_distance_changed"))
	if bus.has_signal("house_moved"):
		bus.connect("house_moved", Callable(self, "_on_house_moved"))
	if bus.has_signal("stove_toggled"):
		bus.connect("stove_toggled", Callable(self, "_on_stove_toggled"))
	if bus.has_signal("stove_extinguished"):
		bus.connect("stove_extinguished", Callable(self, "_on_stove_extinguished"))
	if bus.has_signal("time_updated"):
		bus.connect("time_updated", Callable(self, "_on_time_updated"))
	if bus.has_signal("weather_changed"):
		bus.connect("weather_changed", Callable(self, "_on_weather_changed"))
	if bus.has_signal("blizzard_warning_triggered"):
		bus.connect("blizzard_warning_triggered", Callable(self, "_on_blizzard_warning"))
	if bus.has_signal("blizzard_started"):
		bus.connect("blizzard_started", Callable(self, "_on_blizzard_started"))
	if bus.has_signal("blizzard_ended"):
		bus.connect("blizzard_ended", Callable(self, "_on_blizzard_ended"))
	if bus.has_signal("critical_stop_triggered"):
		bus.connect("critical_stop_triggered", Callable(self, "_on_critical_stop"))
	if bus.has_signal("prompt_requested"):
		bus.connect("prompt_requested", Callable(self, "_on_prompt_requested"))
	if bus.has_signal("prompt_cleared"):
		bus.connect("prompt_cleared", Callable(self, "_on_prompt_cleared"))
	if bus.has_signal("game_restarted"):
		bus.connect("game_restarted", Callable(self, "sync_all_indicators"))

# ==============================================================================
# STATE SYNCHRONIZATION
# ==============================================================================
func sync_all_indicators() -> void:
	var gs: Node = null
	if Engine.has_singleton("GameState"):
		gs = Engine.get_singleton("GameState")
	elif is_inside_tree() and get_tree().root.has_node("GameState"):
		gs = get_tree().root.get_node("GameState")
	else:
		var loop = Engine.get_main_loop()
		if loop is SceneTree and loop.root != null and loop.root.has_node("GameState"):
			gs = loop.root.get_node("GameState")
		
	if gs == null:
		return
		
	_on_fuel_changed(gs.fuel, gs.max_fuel)
	_on_leg_durability_changed(gs.leg_durability, gs.max_leg_durability)
	_on_scrap_changed(gs.scrap)
	_on_supplies_changed(gs.supplies)
	_on_cabin_temperature_changed(gs.cabin_temperature)
	_on_player_health_changed(gs.player_health, gs.max_player_health)
	_on_distance_changed(gs.distance_traveled, gs.target_distance)
	_on_stove_toggled(gs.is_stove_on)
	_on_weather_changed(gs.weather_state, gs.outside_temperature)

# ==============================================================================
# REACTIVE SIGNAL HANDLERS (100% Russian Formatting)
# ==============================================================================

# Indicator 1: Топливо
func _on_fuel_changed(current: float, max_val: float) -> void:
	if fuel_bar != null:
		fuel_bar.max_value = max_val
		fuel_bar.value = current
	if fuel_label != null:
		fuel_label.text = "Топливо: %.1f / %.1f л" % [current, max_val]
		if current < 15.0:
			fuel_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			fuel_label.modulate = Color(1.0, 1.0, 1.0)

# Indicator 2: Металлолом
func _on_scrap_changed(current: float) -> void:
	if scrap_label != null:
		scrap_label.text = "Металлолом: %d шт." % int(current)

# Indicator 3: Припасы
func _on_supplies_changed(current: float) -> void:
	if supplies_label != null:
		supplies_label.text = "Припасы: %d шт." % int(current)

# Indicator 4: Прочность опор
func _on_leg_durability_changed(current: float, max_val: float) -> void:
	if legs_bar != null:
		legs_bar.max_value = max_val
		legs_bar.value = current
	if legs_label != null:
		legs_label.text = "Прочность опор: %.1f%%" % current
		if current <= 10.0:
			legs_label.text = "Прочность опор: %.1f%% [КРИТИЧНО!]" % current
			legs_label.modulate = Color(1.0, 0.25, 0.25)
		elif current < 50.0:
			legs_label.modulate = Color(1.0, 0.85, 0.3)
		else:
			legs_label.modulate = Color(1.0, 1.0, 1.0)

# Indicator 5: Температура в доме
func _on_cabin_temperature_changed(temp: float) -> void:
	if cabin_temp_label != null:
		var sign_char: String = "+" if temp > 0.0 else ""
		cabin_temp_label.text = "Температура в доме: %s%.1f°C" % [sign_char, temp]
		if temp < 0.0:
			cabin_temp_label.modulate = Color(0.4, 0.85, 1.0)
		elif temp < 10.0:
			cabin_temp_label.modulate = Color(1.0, 0.85, 0.3)
		else:
			cabin_temp_label.modulate = Color(0.5, 1.0, 0.5)

# Indicator 6: Здоровье
func _on_player_health_changed(hp: float, max_hp: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = hp
	if health_label != null:
		health_label.text = "Здоровье: %d / %d HP" % [int(hp), int(max_hp)]
		if hp < 25.0:
			health_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			health_label.modulate = Color(1.0, 1.0, 1.0)

# Indicator 7: Пройдено (м) & Indicator 8: До станции (м)
func _on_distance_changed(current: float, target: float) -> void:
	if distance_traveled_label != null:
		distance_traveled_label.text = "Пройдено: %.1f м" % current
	if distance_remaining_label != null:
		var remaining: float = maxf(0.0, target - current)
		distance_remaining_label.text = "До станции: %.1f м" % remaining

func _on_house_moved(_delta_m: float, total_m: float) -> void:
	if distance_traveled_label != null:
		distance_traveled_label.text = "Пройдено: %.1f м" % total_m
	if distance_remaining_label != null:
		var gs: Node = null
		if Engine.has_singleton("GameState"):
			gs = Engine.get_singleton("GameState")
		elif is_inside_tree() and get_tree().root.has_node("GameState"):
			gs = get_tree().root.get_node("GameState")
		var target: float = gs.target_distance if gs != null else 5000.0
		var remaining: float = maxf(0.0, target - total_m)
		distance_remaining_label.text = "До станции: %.1f м" % remaining

# Indicator 9: Печь (ВКЛ/ВЫКЛ)
func _on_stove_toggled(is_on: bool) -> void:
	if stove_label != null:
		if is_on:
			stove_label.text = "Печь: ВКЛ"
			stove_label.modulate = Color(1.0, 0.65, 0.2)
		else:
			stove_label.text = "Печь: ВЫКЛ"
			stove_label.modulate = Color(0.7, 0.7, 0.7)
			
	if stove_button != null:
		stove_button.text = "[F] Печь (ВЫКЛ)" if is_on else "[F] Печь (ВКЛ)"

func _on_stove_button_pressed() -> void:
	var gs: Node = _get_game_state()
	if gs != null:
		if gs.is_player_outside:
			show_alert("НЕЛЬЗЯ УПРАВЛЯТЬ ПЕЧЬЮ СНАРУЖИ ДОМА!", 3.0)
			return
		gs.toggle_stove()

func _on_repair_button_pressed() -> void:
	var gs: Node = _get_game_state()
	var sm: Node = _get_sound_manager()
	if gs != null:
		if gs.is_player_outside:
			show_alert("РЕМОНТ ДОСТУПЕН ТОЛЬКО ВНУТРИ ДОМА!", 3.0)
			return
		var ok: bool = gs.repair_legs(20.0, 1.0)
		if ok:
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("metal_clank")
			show_alert("ШАССИ ОТРЕМОНТИРОВАНО (+20%)", 2.0)
		else:
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("error")
			if gs.leg_durability >= gs.max_leg_durability:
				show_alert("Шасси уже полностью исправно!", 2.0)
			else:
				show_alert("Недостаточно металлолома для ремонта (нужен 1 лом)!", 2.0)

func _on_upgrades_button_pressed() -> void:
	var gs: Node = _get_game_state()
	if gs != null and gs.is_player_outside:
		show_alert("ВЕРСТАК ДОСТУПЕН ТОЛЬКО ВНУТРИ ДОМА!", 3.0)
		return
	var upg: Node = null
	if is_inside_tree():
		upg = get_tree().root.find_child("UpgradePanel", true, false)
	if upg != null and upg.has_method("toggle_panel"):
		upg.toggle_panel()

# Indicator 10: Погода
func _on_weather_changed(state: int, ambient_temp: float) -> void:
	if weather_label != null:
		var name_str: String = WEATHER_NAMES.get(state, "Неизвестно")
		weather_label.text = "Погода: %s (%.1f°C) | Время: %s" % [name_str, ambient_temp, current_hour_str]
		if state == 2: # BLIZZARD
			weather_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			weather_label.modulate = Color(1.0, 1.0, 1.0)

func _on_time_updated(_tod: float, hour_str: String) -> void:
	current_hour_str = hour_str
	var gs: Node = _get_game_state()
	if gs != null:
		_on_weather_changed(gs.weather_state, gs.outside_temperature)

func _on_stove_extinguished(reason: String) -> void:
	if reason == "out_of_fuel":
		show_alert("ПЕЧЬ ПОГАСЛА: ТОПЛИВО ИСЧЕРПАНО!", 4.0)

# Blizzard Alert Handlers
func _on_blizzard_warning(seconds_left: float) -> void:
	show_alert("ВНИМАНИЕ: МЕТЕЛЬ ПРИБЛИЖАЕТСЯ! %d СЕК." % int(ceil(seconds_left)), 3.0)

func _on_blizzard_started() -> void:
	show_alert("ШТОРМОВАЯ МЕТЕЛЬ НАЧАЛАСЬ! ТЕМПЕРАТУРА ПАДАЕТ!", 5.0)

func _on_blizzard_ended() -> void:
	show_alert("Метель утихла.", 3.0)

func _on_critical_stop(reason: String) -> void:
	show_alert("АВАРИЙНАЯ ОСТАНОВКА: %s" % reason.to_upper(), 4.0)

# Alert & Prompt Display Utilities
func show_alert(text: String, duration_sec: float = 3.0) -> void:
	if alert_banner != null and alert_label != null:
		alert_label.text = text
		alert_banner.visible = true
		if is_inside_tree():
			var t = get_tree().create_timer(duration_sec)
			t.timeout.connect(func(): if alert_banner != null: alert_banner.visible = false)

func _on_prompt_requested(text: String) -> void:
	if prompt_container != null and prompt_label != null:
		prompt_label.text = text
		prompt_container.visible = true

func _on_prompt_cleared() -> void:
	if prompt_container != null:
		prompt_container.visible = false

func _get_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState")
	return null

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null
