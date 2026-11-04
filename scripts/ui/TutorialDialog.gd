# scripts/ui/TutorialDialog.gd
class_name TutorialDialog
extends CanvasLayer

## Interactive Russian Guide & Tutorial Overlay for «Шагающий дом».
## Outlines the core survival loop, locomotive mechanics, and hotkey controls.

signal tutorial_closed()

@onready var root_control: Control = get_node_or_null("RootControl")
@onready var close_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/CloseButton")

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)

func open_tutorial() -> void:
	visible = true
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func close_tutorial() -> void:
	visible = false
	tutorial_closed.emit()
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func _on_close_pressed() -> void:
	close_tutorial()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_menu"):
		close_tutorial()
		get_viewport().set_input_as_handled()

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null
