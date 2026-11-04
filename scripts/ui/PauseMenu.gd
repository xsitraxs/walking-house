# scripts/ui/PauseMenu.gd
class_name PauseMenu
extends CanvasLayer

## Pause Menu & In-Game Options for «Шагающий дом».
## Supports pause toggling, audio volume adjustments, tutorial access, and return to main menu.

@onready var root_control: Control = get_node_or_null("RootControl")
@onready var resume_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/ResumeButton")
@onready var tutorial_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/TutorialButton")
@onready var settings_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/SettingsButton")
@onready var main_menu_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/MainMenuButton")

@onready var tutorial_dialog = get_node_or_null("TutorialDialog")
@onready var settings_dialog = get_node_or_null("SettingsDialog")

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if resume_btn != null:
		resume_btn.pressed.connect(_on_resume_pressed)
	if tutorial_btn != null:
		tutorial_btn.pressed.connect(_on_tutorial_pressed)
	if settings_btn != null:
		settings_btn.pressed.connect(_on_settings_pressed)
	if main_menu_btn != null:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func close_menu() -> void:
	visible = false
	get_tree().paused = false
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		# Check if game is already over
		var gs = _get_game_state()
		if gs != null and (gs.is_game_over or gs.is_victory):
			return
		open_menu()

func _on_resume_pressed() -> void:
	close_menu()

func _on_tutorial_pressed() -> void:
	if tutorial_dialog != null:
		tutorial_dialog.open_tutorial()
	else:
		var tut_scene = load("res://scenes/ui/TutorialDialog.tscn")
		if tut_scene != null:
			var inst = tut_scene.instantiate()
			add_child(inst)
			tutorial_dialog = inst
			inst.open_tutorial()

func _on_settings_pressed() -> void:
	if settings_dialog != null:
		settings_dialog.open_settings()
	else:
		var sett_scene = load("res://scenes/ui/SettingsDialog.tscn")
		if sett_scene != null:
			var inst = sett_scene.instantiate()
			add_child(inst)
			settings_dialog = inst
			inst.open_settings()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	var gs = _get_game_state()
	if gs != null:
		gs.reset_state()
	var sm = _get_sound_manager()
	if sm != null:
		sm.stop_all()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu"):
		if tutorial_dialog != null and tutorial_dialog.visible:
			return
		if settings_dialog != null and settings_dialog.visible:
			return
		toggle_menu()
		get_viewport().set_input_as_handled()

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
