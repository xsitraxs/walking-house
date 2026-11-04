# scripts/ui/SettingsDialog.gd
class_name SettingsDialog
extends CanvasLayer

## Volume and Audio Settings Modal for «Шагающий дом».

signal settings_closed()

@onready var master_slider: HSlider = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/MasterHBox/MasterSlider")
@onready var sfx_slider: HSlider = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/SFXHBox/SFXSlider")
@onready var wind_slider: HSlider = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/WindHBox/WindSlider")
@onready var close_btn: Button = get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/CloseButton")

func _ready() -> void:
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)
	if master_slider != null:
		master_slider.value_changed.connect(_on_master_changed)
	if sfx_slider != null:
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if wind_slider != null:
		wind_slider.value_changed.connect(_on_wind_changed)
	sync_sliders()

func open_settings() -> void:
	sync_sliders()
	visible = true
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func close_settings() -> void:
	visible = false
	settings_closed.emit()
	var sm = _get_sound_manager()
	if sm != null:
		sm.play_sfx("click")

func sync_sliders() -> void:
	var sm = _get_sound_manager()
	if sm == null:
		return
	if master_slider != null:
		master_slider.value = sm.get_volume("Master") * 100.0
	if sfx_slider != null:
		sfx_slider.value = sm.get_volume("SFX") * 100.0
	if wind_slider != null:
		wind_slider.value = sm.get_volume("Wind") * 100.0

func _on_master_changed(val: float) -> void:
	var sm = _get_sound_manager()
	if sm != null:
		sm.set_volume("Master", val / 100.0)

func _on_sfx_changed(val: float) -> void:
	var sm = _get_sound_manager()
	if sm != null:
		sm.set_volume("SFX", val / 100.0)
		sm.set_volume("UI", val / 100.0)

func _on_wind_changed(val: float) -> void:
	var sm = _get_sound_manager()
	if sm != null:
		sm.set_volume("Wind", val / 100.0)
		sm.set_volume("Engine", val / 100.0)

func _on_close_pressed() -> void:
	close_settings()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_menu"):
		close_settings()
		get_viewport().set_input_as_handled()

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	return null
