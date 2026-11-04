# scripts/ui/UpgradePanel.gd
class_name UpgradePanel
extends CanvasLayer

## Russian Workbench & Upgrades Modal Dashboard for «Шагающий дом».
## Features: F32 (Leg Repair), F33 (Insulation), F34 (Efficient Engine), F35 (Reinforced Legs), F36 (Upgrade UI).
## Dark frosted glass theme, one-time purchase enforcement, dynamic badges, outside lockout.

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")

# ------------------------------------------------------------------------------
# UI NODE REFERENCES
# ------------------------------------------------------------------------------
@onready var root_control: Control = get_node_or_null("RootControl")
@onready var close_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/HeaderHBox/CloseButton")

# Resource Labels
@onready var scrap_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/ScrapLabel")
@onready var fuel_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/FuelLabel")
@onready var supplies_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/SuppliesLabel")

# Leg Repair Card
@onready var repair_durability_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/DurabilityLabel")
@onready var repair_durability_bar: ProgressBar = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/DurabilityBar")
@onready var repair_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/RepairButton")

# Upgrade 1: Insulation
@onready var ins_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/VBox/ActionHBox/InsulationButton")
@onready var ins_cost_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/VBox/ActionHBox/InsulationCostLabel")

# Upgrade 2: Efficient Engine
@onready var eng_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/VBox/ActionHBox/EngineButton")
@onready var eng_cost_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/VBox/ActionHBox/EngineCostLabel")

# Upgrade 3: Reinforced Legs
@onready var legs_button: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/VBox/ActionHBox/LegsButton")
@onready var legs_cost_label: Label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/VBox/ActionHBox/LegsCostLabel")
var game_state: Node = null

# ------------------------------------------------------------------------------
# LIFECYCLE & INITIALIZATION
# ------------------------------------------------------------------------------
func _ready() -> void:
	layer = 25
	if root_control == null:
		_build_procedural_ui()
	else:
		_resolve_references()
		
	_connect_signals()
	_connect_event_bus()
	visible = false
	update_display()

func _resolve_references() -> void:
	if close_button == null:
		close_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/HeaderHBox/CloseButton")
	if scrap_label == null:
		scrap_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/ScrapLabel")
	if fuel_label == null:
		fuel_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/FuelLabel")
	if supplies_label == null:
		supplies_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ResourceBar/SuppliesLabel")
	if repair_durability_label == null:
		repair_durability_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/DurabilityLabel")
	if repair_durability_bar == null:
		repair_durability_bar = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/DurabilityBar")
	if repair_button == null:
		repair_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/RepairSection/RepairHBox/RepairButton")
	if ins_button == null:
		ins_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/VBox/ActionHBox/InsulationButton")
		if ins_button == null:
			ins_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/ActionHBox/InsulationButton")
	if ins_cost_label == null:
		ins_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/VBox/ActionHBox/InsulationCostLabel")
		if ins_cost_label == null:
			ins_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/InsulationCard/ActionHBox/InsulationCostLabel")
	if eng_button == null:
		eng_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/VBox/ActionHBox/EngineButton")
		if eng_button == null:
			eng_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/ActionHBox/EngineButton")
	if eng_cost_label == null:
		eng_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/VBox/ActionHBox/EngineCostLabel")
		if eng_cost_label == null:
			eng_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/EngineCard/ActionHBox/EngineCostLabel")
	if legs_button == null:
		legs_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/VBox/ActionHBox/LegsButton")
		if legs_button == null:
			legs_button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/ActionHBox/LegsButton")
	if legs_cost_label == null:
		legs_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/VBox/ActionHBox/LegsCostLabel")
		if legs_cost_label == null:
			legs_cost_label = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/UpgradesVBox/LegsCard/ActionHBox/LegsCostLabel")

func _connect_signals() -> void:
	if close_button != null and not close_button.pressed.is_connected(close_panel):
		close_button.pressed.connect(close_panel)
	if repair_button != null and not repair_button.pressed.is_connected(_on_repair_pressed):
		repair_button.pressed.connect(_on_repair_pressed)
	if ins_button != null and not ins_button.pressed.is_connected(_on_insulation_pressed):
		ins_button.pressed.connect(_on_insulation_pressed)
	if eng_button != null and not eng_button.pressed.is_connected(_on_engine_pressed):
		eng_button.pressed.connect(_on_engine_pressed)
	if legs_button != null and not legs_button.pressed.is_connected(_on_legs_pressed):
		legs_button.pressed.connect(_on_legs_pressed)

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	if bus.has_signal("resources_changed"):
		bus.connect("resources_changed", Callable(self, "_on_resources_changed"))
	if bus.has_signal("leg_durability_changed"):
		bus.connect("leg_durability_changed", Callable(self, "_on_leg_durability_changed"))
	if bus.has_signal("upgrade_unlocked"):
		bus.connect("upgrade_unlocked", Callable(self, "_on_upgrade_unlocked"))
	if bus.has_signal("player_disembarked"):
		bus.connect("player_disembarked", Callable(self, "_on_player_disembarked"))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_upgrades"):
		toggle_panel()
		get_viewport().set_input_as_handled()
		return
		
	if visible:
		if event.is_action_pressed("toggle_menu") or event.is_action_pressed("ui_cancel"):
			close_panel()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
			_on_repair_pressed()
			get_viewport().set_input_as_handled()
			return

# ------------------------------------------------------------------------------
# PANEL VISIBILITY & LOCKOUT CONTROLS
# ------------------------------------------------------------------------------
func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()

func open_panel() -> bool:
	var gs: Node = _get_game_state()
	if gs != null and gs.is_player_outside:
		var bus: Node = _get_event_bus()
		if bus != null and bus.has_signal("prompt_requested"):
			bus.emit_signal("prompt_requested", "Верстак доступен только внутри кабины дома!")
		return false
		
	visible = true
	update_display()
	var sm: Node = _get_sound_manager()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("click")
	return true

func close_panel() -> void:
	visible = false
	var sm: Node = _get_sound_manager()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("click")

func _on_player_disembarked() -> void:
	if visible:
		close_panel()

# ------------------------------------------------------------------------------
# DISPLAY & DYNAMIC BADGE REFRESH
# ------------------------------------------------------------------------------
func update_display() -> void:
	var gs: Node = _get_game_state()
	if gs == null:
		return
		
	# 1. Resource counters
	if scrap_label != null:
		scrap_label.text = "⚙ Металлолом: %d шт." % int(gs.scrap)
	if fuel_label != null:
		fuel_label.text = "⛽ Топливо: %.1f л" % gs.fuel
	if supplies_label != null:
		supplies_label.text = "📦 Припасы: %d шт." % int(gs.supplies)
		
	# 2. Leg Repair Card
	if repair_durability_bar != null:
		repair_durability_bar.max_value = gs.max_leg_durability
		repair_durability_bar.value = gs.leg_durability
	if repair_durability_label != null:
		repair_durability_label.text = "Прочность опор: %.1f%% / 100.0%%" % gs.leg_durability
		
	if repair_button != null:
		if gs.leg_durability >= gs.max_leg_durability:
			repair_button.text = "[✓ Шасси исправно (100%)]"
			repair_button.disabled = true
			repair_button.modulate = Color(0.7, 0.9, 0.7)
		elif gs.scrap < 1.0:
			repair_button.text = "[Недостаточно металлолома (требуется 1 шт.)]"
			repair_button.disabled = true
			repair_button.modulate = Color(0.8, 0.4, 0.4)
		else:
			repair_button.text = "[R] Починить опоры (+20%) — 1 металлолом"
			repair_button.disabled = false
			repair_button.modulate = Color(0.3, 0.8, 1.0)
			
	# 3. Upgrade 1: Insulation (12 scrap, 6 supplies)
	_update_upgrade_card(
		"insulation",
		12.0, 6.0, 0.0,
		ins_button,
		ins_cost_label,
		"Стоимость: 12 металлолома, 6 припасов"
	)
	
	# 4. Upgrade 2: Efficient Engine (15 scrap, 20 fuel)
	_update_upgrade_card(
		"engine",
		15.0, 0.0, 20.0,
		eng_button,
		eng_cost_label,
		"Стоимость: 15 металлолома, 20.0 л топлива"
	)
	
	# 5. Upgrade 3: Reinforced Legs (18 scrap, 8 supplies)
	_update_upgrade_card(
		"reinforced_legs",
		18.0, 8.0, 0.0,
		legs_button,
		legs_cost_label,
		"Стоимость: 18 металлолома, 8 припасов"
	)

func _update_upgrade_card(
	upgrade_id: String,
	scrap_c: float,
	supplies_c: float,
	fuel_c: float,
	btn: Button,
	cost_lbl: Label,
	cost_text: String
) -> void:
	var gs: Node = _get_game_state()
	if gs == null or btn == null:
		return
		
	if cost_lbl != null:
		cost_lbl.text = cost_text
		
	var is_installed: bool = gs.has_upgrade(upgrade_id) or gs.get_upgrade_level(upgrade_id) >= 1
	if is_installed:
		btn.text = "[✓ Установлено]"
		btn.disabled = true
		btn.modulate = Color(0.35, 0.95, 0.45)
	else:
		var can_buy: bool = gs.can_afford_upgrade(upgrade_id, scrap_c, supplies_c, fuel_c)
		if can_buy:
			btn.text = "[Купить]"
			btn.disabled = false
			btn.modulate = Color(0.30, 0.75, 1.0)
		else:
			btn.text = "[Недостаточно ресурсов]"
			btn.disabled = true
			btn.modulate = Color(0.85, 0.35, 0.35)

# ------------------------------------------------------------------------------
# ACTIONS & HANDLERS
# ------------------------------------------------------------------------------
func _on_repair_pressed() -> void:
	var gs: Node = _get_game_state()
	var sm: Node = _get_sound_manager()
	if gs == null:
		return
		
	if gs.is_player_outside:
		var bus: Node = _get_event_bus()
		if bus != null:
			bus.emit_signal("prompt_requested", "Ремонт доступен только внутри кабины дома!")
		return
		
	var success: bool = gs.repair_legs(20.0, 1.0)
	if success:
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("metal_clank")
	else:
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("error")
	update_display()

func _on_insulation_pressed() -> void:
	_buy_upgrade("insulation", 12.0, 6.0, 0.0)

func _on_engine_pressed() -> void:
	_buy_upgrade("engine", 15.0, 0.0, 20.0)

func _on_legs_pressed() -> void:
	_buy_upgrade("reinforced_legs", 18.0, 8.0, 0.0)

func _buy_upgrade(upgrade_id: String, scrap_c: float, supplies_c: float, fuel_c: float) -> void:
	var gs: Node = _get_game_state()
	var sm: Node = _get_sound_manager()
	if gs == null:
		return
		
	if gs.is_player_outside:
		return
		
	var ok: bool = gs.purchase_upgrade(upgrade_id, scrap_c, supplies_c, fuel_c)
	if ok:
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("click")
	else:
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("error")
	update_display()

func _on_resources_changed(_s: float, _f: float, _p: float) -> void:
	if visible:
		update_display()

func _on_leg_durability_changed(_dur: float, _max_dur: float) -> void:
	if visible:
		update_display()

func _on_upgrade_unlocked(_id: String) -> void:
	update_display()

# ------------------------------------------------------------------------------
# PROCEDURAL UI FALLBACK BUILDER (For Headless & Code-Only Instantiation)
# ------------------------------------------------------------------------------
func _build_procedural_ui() -> void:
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.04, 0.06, 0.08, 0.70)
	root_control.add_child(dimmer)
	
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.add_child(center)
	
	var modal := PanelContainer.new()
	modal.name = "ModalPanel"
	modal.custom_minimum_size = Vector2(760, 540)
	
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.24, 0.38, 0.52, 0.85)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_right = 8
	box.corner_radius_bottom_left = 8
	box.content_margin_left = 20.0
	box.content_margin_top = 16.0
	box.content_margin_right = 20.0
	box.content_margin_bottom = 16.0
	modal.add_theme_stylebox_override("panel", box)
	center.add_child(modal)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	modal.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	header.name = "HeaderHBox"
	vbox.add_child(header)
	
	var title := Label.new()
	title.text = "⚙ ВЕРСТАК И МОДЕРНИЗАЦИЯ ДОМА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.modulate = Color(0.85, 0.92, 1.0)
	header.add_child(title)
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "[ X ]"
	header.add_child(close_button)
	
	var sub := Label.new()
	sub.text = "Техническое обслуживание шасси и установка долговечных улучшений"
	sub.modulate = Color(0.65, 0.75, 0.85, 0.8)
	vbox.add_child(sub)
	
	vbox.add_child(HSeparator.new())
	
	# Resource status bar
	var res_bar := HBoxContainer.new()
	res_bar.name = "ResourceBar"
	res_bar.add_theme_constant_override("separation", 24)
	vbox.add_child(res_bar)
	
	scrap_label = Label.new()
	scrap_label.name = "ScrapLabel"
	scrap_label.text = "⚙ Металлолом: 0 шт."
	res_bar.add_child(scrap_label)
	
	fuel_label = Label.new()
	fuel_label.name = "FuelLabel"
	fuel_label.text = "⛽ Топливо: 100.0 л"
	res_bar.add_child(fuel_label)
	
	supplies_label = Label.new()
	supplies_label.name = "SuppliesLabel"
	supplies_label.text = "📦 Припасы: 5 шт."
	res_bar.add_child(supplies_label)
	
	vbox.add_child(HSeparator.new())
	
	# Leg Repair Section
	var rep_sec := VBoxContainer.new()
	rep_sec.name = "RepairSection"
	vbox.add_child(rep_sec)
	
	var rep_title := Label.new()
	rep_title.text = "🛠 ТЕХНИЧЕСКОЕ ОБСЛУЖИВАНИЕ ШАССИ"
	rep_title.modulate = Color(0.95, 0.85, 0.4)
	rep_sec.add_child(rep_title)
	
	var rep_hbox := HBoxContainer.new()
	rep_hbox.name = "RepairHBox"
	rep_hbox.add_theme_constant_override("separation", 16)
	rep_sec.add_child(rep_hbox)
	
	repair_durability_label = Label.new()
	repair_durability_label.name = "DurabilityLabel"
	repair_durability_label.text = "Прочность опор: 100.0% / 100.0%"
	rep_hbox.add_child(repair_durability_label)
	
	repair_durability_bar = ProgressBar.new()
	repair_durability_bar.name = "DurabilityBar"
	repair_durability_bar.custom_minimum_size = Vector2(160, 16)
	repair_durability_bar.show_percentage = false
	repair_durability_bar.value = 100.0
	rep_hbox.add_child(repair_durability_bar)
	
	repair_button = Button.new()
	repair_button.name = "RepairButton"
	repair_button.text = "[R] Починить опоры (+20%) — 1 металлолом"
	repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_hbox.add_child(repair_button)
	
	vbox.add_child(HSeparator.new())
	
	# Upgrades List
	var upg_vbox := VBoxContainer.new()
	upg_vbox.name = "UpgradesVBox"
	upg_vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(upg_vbox)
	
	# Card 1: Insulation
	var ins_card := _create_procedural_card(
		"InsulationCard",
		"❄ Утепление корпуса",
		"Снижает естественные теплопотери кабины на 45%. Защищает экипаж от переохлаждения в буран.",
		"Стоимость: 12 металлолома, 6 припасов",
		"InsulationButton",
		"InsulationCostLabel"
	)
	upg_vbox.add_child(ins_card["card"])
	ins_button = ins_card["button"]
	ins_cost_label = ins_card["cost_label"]
	
	# Card 2: Engine
	var eng_card := _create_procedural_card(
		"EngineCard",
		"⚡ Экономичный двигатель",
		"Снижает расход топлива гидравлическим двигателем при ходьбе на 30%.",
		"Стоимость: 15 металлолома, 20.0 л топлива",
		"EngineButton",
		"EngineCostLabel"
	)
	upg_vbox.add_child(eng_card["card"])
	eng_button = eng_card["button"]
	eng_cost_label = eng_card["cost_label"]
	
	# Card 3: Legs
	var legs_card := _create_procedural_card(
		"LegsCard",
		"🦵 Усиленные опоры",
		"Замедляет механический износ опор на 40% и повышает скорость ходьбы на 15%.",
		"Стоимость: 18 металлолома, 8 припасов",
		"LegsButton",
		"LegsCostLabel"
	)
	upg_vbox.add_child(legs_card["card"])
	legs_button = legs_card["button"]
	legs_cost_label = legs_card["cost_label"]
	
	vbox.add_child(HSeparator.new())
	
	# Footer
	var footer := Label.new()
	footer.text = "[U / Tab / Esc] Закрыть верстак | [R] Быстрый ремонт шасси"
	footer.modulate = Color(0.65, 0.65, 0.65, 0.75)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)

func _create_procedural_card(
	card_name: String,
	title_str: String,
	desc_str: String,
	cost_str: String,
	btn_name: String,
	cost_name: String
) -> Dictionary:
	var card := PanelContainer.new()
	card.name = card_name
	
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.13, 0.18, 0.75)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.20, 0.30, 0.42, 0.6)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_right = 6
	box.corner_radius_bottom_left = 6
	box.content_margin_left = 12.0
	box.content_margin_top = 8.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", box)
	
	var card_vbox := VBoxContainer.new()
	card.add_child(card_vbox)
	
	var t_lbl := Label.new()
	t_lbl.text = title_str
	t_lbl.modulate = Color(0.9, 0.95, 1.0)
	card_vbox.add_child(t_lbl)
	
	var d_lbl := Label.new()
	d_lbl.text = desc_str
	d_lbl.modulate = Color(0.75, 0.8, 0.85, 0.85)
	card_vbox.add_child(d_lbl)
	
	var act_hbox := HBoxContainer.new()
	act_hbox.name = "ActionHBox"
	card_vbox.add_child(act_hbox)
	
	var c_lbl := Label.new()
	c_lbl.name = cost_name
	c_lbl.text = cost_str
	c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_lbl.modulate = Color(0.95, 0.85, 0.45)
	act_hbox.add_child(c_lbl)
	
	var btn := Button.new()
	btn.name = btn_name
	btn.text = "[Купить]"
	btn.custom_minimum_size = Vector2(220, 0)
	act_hbox.add_child(btn)
	
	return {"card": card, "button": btn, "cost_label": c_lbl}

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------
func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null

func _get_game_state() -> Node:
	if game_state != null:
		return game_state
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
