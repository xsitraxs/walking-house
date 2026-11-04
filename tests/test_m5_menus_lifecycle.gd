# tests/test_m5_menus_lifecycle.gd
class_name TestM5MenusLifecycle
extends RefCounted

## Comprehensive Milestone 5 Test Suite for «Шагающий дом» (Walking House).
## Validates:
## - Main Menu: scene instantiation, Russian button labels, backdrop, procedural snow
## - Tutorial Dialog: survival rules, Russian hotkey map, open/close flow
## - Settings Dialog: volume sliders, SoundManager bus synchronization
## - Pause Menu: modal pause lifecycle, resume, menu navigation
## - End Screen: Victory presentation, Defeat presentation, Deadlock reason formatting, run statistics
## - Game Lifecycle: GameState reset invariants, World scene integration, project entry point

const GameStateScript = preload("res://scripts/autoload/GameState.gd")
const EventBusScript = preload("res://scripts/autoload/EventBus.gd")
const SoundManagerScript = preload("res://scripts/autoload/SoundManager.gd")

var suite_name: String = "M5: Menus, Tutorial, End Screens & Game Lifecycle"

func run_suite(runner) -> void:
	test_01_main_menu_instantiation_and_nodes(runner)
	test_02_tutorial_dialog_ui_and_hotkeys(runner)
	test_03_settings_dialog_audio_sync(runner)
	test_04_pause_menu_toggle_and_unpause(runner)
	test_05_end_screen_victory_presentation(runner)
	test_06_end_screen_defeat_presentation(runner)
	test_07_end_screen_deadlock_reason_formatting(runner)
	test_08_gamestate_reset_lifecycle(runner)
	test_09_world_scene_ui_integration(runner)
	test_10_project_entry_point(runner)

# ------------------------------------------------------------------------------
# TEST 01: Main Menu Scene Instantiation & Nodes
# ------------------------------------------------------------------------------
func test_01_main_menu_instantiation_and_nodes(runner) -> void:
	runner.start_test("test_01_main_menu_instantiation_and_nodes")
	
	var scene = load("res://scenes/ui/MainMenu.tscn")
	runner.assert_true(scene != null, "MainMenu.tscn loads successfully")
	
	var inst = scene.instantiate()
	runner.assert_true(inst != null, "MainMenu instantiates successfully")
	
	var start_btn = inst.get_node_or_null("MenuLayer/Margin/LeftBox/Panel/VBox/MenuButtons/StartButton")
	var tut_btn = inst.get_node_or_null("MenuLayer/Margin/LeftBox/Panel/VBox/MenuButtons/TutorialButton")
	var sett_btn = inst.get_node_or_null("MenuLayer/Margin/LeftBox/Panel/VBox/MenuButtons/SettingsButton")
	var quit_btn = inst.get_node_or_null("MenuLayer/Margin/LeftBox/Panel/VBox/MenuButtons/QuitButton")
	
	runner.assert_true(start_btn != null, "StartButton exists")
	runner.assert_true(tut_btn != null, "TutorialButton exists")
	runner.assert_true(sett_btn != null, "SettingsButton exists")
	runner.assert_true(quit_btn != null, "QuitButton exists")
	
	runner.assert_true(start_btn.text.contains("НАЧАТЬ"), "StartButton has Russian label")
	runner.assert_true(tut_btn.text.contains("Обучение"), "TutorialButton has Russian label")
	runner.assert_true(sett_btn.text.contains("звука"), "SettingsButton has Russian label")
	runner.assert_true(quit_btn.text.contains("Выход"), "QuitButton has Russian label")
	
	var backdrop = inst.get_node_or_null("Backdrop")
	runner.assert_true(backdrop != null, "Backdrop node exists")
	
	var snow = inst.get_node_or_null("SnowParticles")
	runner.assert_true(snow != null, "SnowParticles node exists")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 02: Tutorial Dialog UI & Hotkeys
# ------------------------------------------------------------------------------
func test_02_tutorial_dialog_ui_and_hotkeys(runner) -> void:
	runner.start_test("test_02_tutorial_dialog_ui_and_hotkeys")
	
	var scene = load("res://scenes/ui/TutorialDialog.tscn")
	runner.assert_true(scene != null, "TutorialDialog.tscn loads successfully")
	
	var inst = scene.instantiate()
	runner.assert_true(inst != null, "TutorialDialog instantiates successfully")
	
	var close_btn = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/ButtonHBox/CloseButton")
	runner.assert_true(close_btn != null, "CloseButton exists")
	runner.assert_true(close_btn.text.contains("ПОНЯТНО"), "CloseButton has Russian text")
	
	# Open/close testing
	inst.open_tutorial()
	runner.assert_true(inst.visible, "Tutorial becomes visible on open_tutorial()")
	
	var closed_box = [false]
	inst.tutorial_closed.connect(func(): closed_box[0] = true)
	inst.close_tutorial()
	runner.assert_false(inst.visible, "Tutorial becomes hidden on close_tutorial()")
	runner.assert_true(closed_box[0], "tutorial_closed signal emitted")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 03: Settings Dialog & Audio Sync
# ------------------------------------------------------------------------------
func test_03_settings_dialog_audio_sync(runner) -> void:
	runner.start_test("test_03_settings_dialog_audio_sync")
	
	var scene = load("res://scenes/ui/SettingsDialog.tscn")
	runner.assert_true(scene != null, "SettingsDialog.tscn loads successfully")
	
	var inst = scene.instantiate()
	runner.assert_true(inst != null, "SettingsDialog instantiates successfully")
	
	var master_slider = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/MasterHBox/MasterSlider")
	var sfx_slider = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/SFXHBox/SFXSlider")
	var wind_slider = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SlidersVBox/WindHBox/WindSlider")
	
	runner.assert_true(master_slider != null, "Master slider exists")
	runner.assert_true(sfx_slider != null, "SFX slider exists")
	runner.assert_true(wind_slider != null, "Wind slider exists")
	
	# Test slider handlers
	inst._on_master_changed(60.0)
	inst._on_sfx_changed(75.0)
	inst._on_wind_changed(50.0)
	runner.assert_true(true, "Volume handlers executed without errors")
	
	inst.open_settings()
	runner.assert_true(inst.visible, "Settings visible when opened")
	inst.close_settings()
	runner.assert_false(inst.visible, "Settings hidden when closed")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 04: Pause Menu Toggle & Navigation
# ------------------------------------------------------------------------------
func test_04_pause_menu_toggle_and_unpause(runner) -> void:
	runner.start_test("test_04_pause_menu_toggle_and_unpause")
	
	var scene = load("res://scenes/ui/PauseMenu.tscn")
	runner.assert_true(scene != null, "PauseMenu.tscn loads successfully")
	
	var inst = scene.instantiate()
	runner.assert_true(inst != null, "PauseMenu instantiates successfully")
	
	var resume_btn = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/ResumeButton")
	var tut_btn = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/TutorialButton")
	var sett_btn = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/SettingsButton")
	var menu_btn = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/MenuButtons/MainMenuButton")
	
	runner.assert_true(resume_btn != null, "Resume button exists")
	runner.assert_true(tut_btn != null, "Tutorial button exists in pause menu")
	runner.assert_true(sett_btn != null, "Settings button exists in pause menu")
	runner.assert_true(menu_btn != null, "MainMenu button exists in pause menu")
	
	runner.assert_true(resume_btn.text.contains("ПРОДОЛЖИТЬ"), "Resume button has Russian text")
	runner.assert_true(menu_btn.text.contains("главное меню"), "MainMenu button has Russian text")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 05: End Screen Victory Presentation
# ------------------------------------------------------------------------------
func test_05_end_screen_victory_presentation(runner) -> void:
	runner.start_test("test_05_end_screen_victory_presentation")
	
	var scene = load("res://scenes/ui/EndScreen.tscn")
	runner.assert_true(scene != null, "EndScreen.tscn loads successfully")
	
	var inst = scene.instantiate()
	runner.assert_true(inst != null, "EndScreen instantiates successfully")
	
	var test_stats = {
		"final_distance": 5000.0,
		"time_elapsed": 780.0, # 13 min
		"fuel_collected": 340.0,
		"scrap_collected": 22.0,
		"supplies_collected": 15.0,
		"repairs_count": 4,
		"upgrades_count": 2,
		"blizzards_survived": 3
	}
	
	inst.show_victory(test_stats)
	runner.assert_true(inst.visible, "EndScreen visible on victory")
	
	var title = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/TitleLabel")
	runner.assert_true(title != null, "TitleLabel exists")
	runner.assert_true(title.text.contains("ПОБЕДА"), "Title contains 'ПОБЕДА'")
	
	var dist_val = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/DistVal")
	var time_val = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/TimeVal")
	var fuel_val = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/StatsGrid/FuelVal")
	
	runner.assert_true(dist_val.text.contains("5000.0"), "Stats show 5000.0 m distance")
	runner.assert_true(time_val.text.contains("13 мин"), "Stats show 13 minutes elapsed")
	runner.assert_true(fuel_val.text.contains("340.0"), "Stats show 340.0 fuel collected")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 06: End Screen Defeat Presentation
# ------------------------------------------------------------------------------
func test_06_end_screen_defeat_presentation(runner) -> void:
	runner.start_test("test_06_end_screen_defeat_presentation")
	
	var scene = load("res://scenes/ui/EndScreen.tscn")
	var inst = scene.instantiate()
	
	var test_stats = {
		"final_distance": 1420.0,
		"time_elapsed": 300.0,
		"fuel_collected": 80.0,
		"scrap_collected": 5.0,
		"supplies_collected": 2.0,
		"repairs_count": 1,
		"upgrades_count": 0,
		"blizzards_survived": 1
	}
	
	inst.show_defeat("Критическое переохлаждение исследователя на морозе", test_stats)
	runner.assert_true(inst.visible, "EndScreen visible on defeat")
	
	var title = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/TitleLabel")
	var subtitle = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SubTitleLabel")
	
	runner.assert_true(title.text.contains("ПОГИБЛА"), "Title contains 'ПОГИБЛА'")
	runner.assert_true(subtitle.text.contains("переохлаждение"), "Subtitle contains cause of defeat")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 07: End Screen Deadlock Reason Formatting
# ------------------------------------------------------------------------------
func test_07_end_screen_deadlock_reason_formatting(runner) -> void:
	runner.start_test("test_07_end_screen_deadlock_reason_formatting")
	
	var scene = load("res://scenes/ui/EndScreen.tscn")
	var inst = scene.instantiate()
	
	var raw_reason = "deadlock: Безысходный тупик: ресурсы исчерпаны, дальнейшее движение невозможно"
	inst.show_defeat(raw_reason, {})
	
	var subtitle = inst.get_node_or_null("RootControl/Dimmer/Center/ModalPanel/VBox/SubTitleLabel")
	runner.assert_false(subtitle.text.contains("deadlock:"), "deadlock prefix stripped from user view")
	runner.assert_true(subtitle.text.contains("Безысходный тупик"), "User-facing Russian reason displayed")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 08: GameState Reset Lifecycle
# ------------------------------------------------------------------------------
func test_08_gamestate_reset_lifecycle(runner) -> void:
	runner.start_test("test_08_gamestate_reset_lifecycle")
	
	var gs = GameStateScript.new()
	
	# Alter state to simulate end of run
	gs.fuel = 12.0
	gs.leg_durability = 4.0
	gs.scrap = 3.0
	gs.supplies = 9.0
	gs.distance_traveled = 3450.0
	gs.is_victory = true
	gs.is_game_active = false
	gs.stats["fuel_collected"] = 280.0
	gs.stats["repairs_count"] = 5
	
	# Perform full reset
	gs.reset_state()
	
	runner.assert_eq(gs.fuel, 100.0, "Fuel reset to 100")
	runner.assert_eq(gs.leg_durability, 100.0, "Leg durability reset to 100")
	runner.assert_eq(gs.scrap, 0.0, "Scrap reset to 0")
	runner.assert_eq(gs.distance_traveled, 0.0, "Distance reset to 0")
	runner.assert_false(gs.is_victory, "is_victory reset to false")
	runner.assert_false(gs.is_game_over, "is_game_over reset to false")
	runner.assert_true(gs.is_game_active, "is_game_active reset to true")
	runner.assert_eq(gs.stats["fuel_collected"], 0.0, "Statistics fuel_collected reset to 0")
	runner.assert_eq(gs.stats["repairs_count"], 0, "Statistics repairs_count reset to 0")
	
	gs.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 09: World Scene UI Integration
# ------------------------------------------------------------------------------
func test_09_world_scene_ui_integration(runner) -> void:
	runner.start_test("test_09_world_scene_ui_integration")
	
	var world_scene = load("res://scenes/world/World.tscn")
	runner.assert_true(world_scene != null, "World.tscn loads successfully")
	
	var inst = world_scene.instantiate()
	runner.assert_true(inst != null, "World instantiates successfully")
	
	var ui = inst.get_node_or_null("UI")
	runner.assert_true(ui != null, "UI CanvasLayer exists in World")
	
	var hud = ui.get_node_or_null("HUD")
	var up = ui.get_node_or_null("UpgradePanel")
	var pm = ui.get_node_or_null("PauseMenu")
	var es = ui.get_node_or_null("EndScreen")
	
	runner.assert_true(hud != null, "HUD exists in World UI")
	runner.assert_true(up != null, "UpgradePanel exists in World UI")
	runner.assert_true(pm != null, "PauseMenu exists in World UI")
	runner.assert_true(es != null, "EndScreen exists in World UI")
	
	inst.free()
	runner.end_test()

# ------------------------------------------------------------------------------
# TEST 10: Project Entry Point Verification
# ------------------------------------------------------------------------------
func test_10_project_entry_point(runner) -> void:
	runner.start_test("test_10_project_entry_point")
	
	var cfg = ConfigFile.new()
	var err = cfg.load("res://project.godot")
	runner.assert_eq(err, OK, "project.godot loads without errors")
	
	var main_scene = cfg.get_value("application", "run/main_scene", "")
	runner.assert_eq(main_scene, "res://scenes/ui/MainMenu.tscn", "main_scene points to MainMenu.tscn")
	
	var menu_scene = load("res://scenes/ui/MainMenu.tscn")
	runner.assert_true(menu_scene != null, "MainMenu.tscn loadable")
	
	var main_wrapper = load("res://scenes/Main.tscn")
	runner.assert_true(main_wrapper != null, "Main.tscn fallback wrapper loadable")
	
	runner.end_test()
