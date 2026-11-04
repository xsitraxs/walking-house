# scripts/ui/MainMenu.gd
class_name MainMenu
extends Control

## Main Menu Coordinator for «Шагающий дом» (Walking House).
## Features procedural vector art backdrop, ambient snow, warm cabin glow, and audio controls.

@onready var start_btn: Button = get_node_or_null("MenuLayer/Center/Panel/VBox/MenuButtons/StartButton")
@onready var tutorial_btn: Button = get_node_or_null("MenuLayer/Center/Panel/VBox/MenuButtons/TutorialButton")
@onready var settings_btn: Button = get_node_or_null("MenuLayer/Center/Panel/VBox/MenuButtons/SettingsButton")
@onready var quit_btn: Button = get_node_or_null("MenuLayer/Center/Panel/VBox/MenuButtons/QuitButton")

@onready var tutorial_dialog = get_node_or_null("TutorialDialog")
@onready var settings_dialog = get_node_or_null("SettingsDialog")

func _ready() -> void:
	if start_btn != null:
		start_btn.pressed.connect(_on_start_pressed)
	if tutorial_btn != null:
		tutorial_btn.pressed.connect(_on_tutorial_pressed)
	if settings_btn != null:
		settings_btn.pressed.connect(_on_settings_pressed)
	if quit_btn != null:
		quit_btn.pressed.connect(_on_quit_pressed)
		
	var sm = _get_sound_manager()
	if sm != null:
		sm.stop_all()
		sm.set_wind_intensity(0.2) # Gentle ambient winter breeze

func _on_start_pressed() -> void:
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")
		
	var gs = _get_game_state()
	if gs != null:
		gs.reset_state()
		
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

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

func _on_quit_pressed() -> void:
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")
	get_tree().quit()

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
