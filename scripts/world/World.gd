# scripts/world/World.gd
class_name World
extends Node2D

## Master Environment, Boundary & Camera Tracking Coordinator.
## Coordinates WalkingHouse, Player entity, POI containers, and BiomeManager.

const BalanceConfig = preload("res://scripts/core/BalanceConfig.gd")
const SimulationLogic = preload("res://scripts/core/SimulationLogic.gd")
const ResourceNode = preload("res://scripts/world/ResourceNode.gd")

@onready var house: CharacterBody2D = get_node_or_null("WalkingHouse")
@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var camera = get_node_or_null("WorldCamera")
@onready var biome_mgr = get_node_or_null("BiomeManager")
@onready var resource_nodes: Node2D = get_node_or_null("ResourceNodes")
@onready var snow_tracks = get_node_or_null("SnowTracks")
@onready var world_modulate: CanvasModulate = get_node_or_null("WorldCanvasModulate")
@onready var weather_mgr = get_node_or_null("WeatherManager")
@onready var upgrade_panel = get_node_or_null("UI/UpgradePanel")
@onready var pause_menu = get_node_or_null("UI/PauseMenu")
@onready var end_screen = get_node_or_null("UI/EndScreen")

var deadlock_timer: float = 0.0
var game_state: Node = null

func _ready() -> void:
	_ensure_components()
	_populate_resource_nodes()
	_setup_camera()
	_connect_event_bus()
	_start_outside_at_ladder()

func _ensure_components() -> void:
	if house == null:
		house = get_node_or_null("WalkingHouse")
	if player == null:
		player = get_node_or_null("Player")
	if camera == null:
		camera = get_node_or_null("WorldCamera")
	if biome_mgr == null:
		biome_mgr = get_node_or_null("BiomeManager")
	if resource_nodes == null:
		resource_nodes = get_node_or_null("ResourceNodes")
	if snow_tracks == null:
		snow_tracks = get_node_or_null("SnowTracks")
	if world_modulate == null:
		world_modulate = get_node_or_null("WorldCanvasModulate")
	if weather_mgr == null:
		weather_mgr = get_node_or_null("WeatherManager")
		if weather_mgr == null:
			var weather_script = load("res://scripts/world/WeatherManager.gd")
			if weather_script != null:
				weather_mgr = Node2D.new()
				weather_mgr.name = "WeatherManager"
				weather_mgr.set_script(weather_script)
				add_child(weather_mgr)
	if upgrade_panel == null:
		var ui = get_node_or_null("UI")
		if ui != null:
			upgrade_panel = ui.get_node_or_null("UpgradePanel")
			if upgrade_panel == null and ResourceLoader.exists("res://scenes/ui/UpgradePanel.tscn"):
				var up_scene = load("res://scenes/ui/UpgradePanel.tscn")
				upgrade_panel = up_scene.instantiate()
				ui.add_child(upgrade_panel)
	if pause_menu == null:
		var ui = get_node_or_null("UI")
		if ui != null:
			pause_menu = ui.get_node_or_null("PauseMenu")
			if pause_menu == null and ResourceLoader.exists("res://scenes/ui/PauseMenu.tscn"):
				var pm_scene = load("res://scenes/ui/PauseMenu.tscn")
				pause_menu = pm_scene.instantiate()
				ui.add_child(pause_menu)
	if end_screen == null:
		var ui = get_node_or_null("UI")
		if ui != null:
			end_screen = ui.get_node_or_null("EndScreen")
			if end_screen == null and ResourceLoader.exists("res://scenes/ui/EndScreen.tscn"):
				var es_scene = load("res://scenes/ui/EndScreen.tscn")
				end_screen = es_scene.instantiate()
				ui.add_child(end_screen)

func _populate_resource_nodes() -> void:
	if resource_nodes == null:
		resource_nodes = Node2D.new()
		resource_nodes.name = "ResourceNodes"
		add_child(resource_nodes)
		
	if resource_nodes.get_child_count() > 0:
		return
		
	var node_scene_path := "res://scenes/world/ResourceNode.tscn"
	var node_scene: PackedScene = null
	if ResourceLoader.exists(node_scene_path):
		node_scene = load(node_scene_path)
		
	for data in ResourceNode.DEFAULT_NODES:
		var node_inst: ResourceNode = null
		if node_scene != null:
			node_inst = node_scene.instantiate() as ResourceNode
		else:
			node_inst = ResourceNode.new()
			
		node_inst.name = "ResourceNode_%02d" % data.node_id
		node_inst.setup_node(data)
		var px: float = data.get("world_x", data.distance_m * BalanceConfig.METERS_TO_PIXELS)
		var py: float = 560.0 + data.get("offset_y", 0.0)
		node_inst.position = Vector2(px, py)
		resource_nodes.add_child(node_inst)

func _setup_camera() -> void:
	if camera == null:
		return
	camera.target_house = house
	camera.target_player = player
	if house != null:
		camera.global_position = Vector2(house.global_position.x + 80.0, 360.0)

## Игра начинается снаружи: исследователь стоит у трапа и должен подняться
## в дом по [E]. Раньше Player спавнился скрытым снаружи, а GameState считал
## его «внутри» — из-за этого у трапа висела подсказка «Войти в дом», хотя
## игрок и так уже был в доме. Теперь оба состояния согласованы.
func _start_outside_at_ladder() -> void:
	if player == null or house == null:
		return
	var gs: Node = _get_game_state()
	if gs != null and not gs.is_player_outside:
		# Игра начинается снаружи: игрок стоит у трапа и должен подняться
		# в дом по [E]. Синхронизируем GameState, иначе он считает игрока
		# внутри и разрешает «выйти» из дома, в который ещё не входили.
		gs.is_player_outside = true
		if gs.has_signal("player_mode_changed"):
			gs.emit_signal("player_mode_changed", [true])
	player.spawn_at_house_ladder(house)
	# GameCamera переключится сама по сигналу player_mode_changed выше.

func _connect_event_bus() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	if bus.has_signal("player_disembarked"):
		bus.connect("player_disembarked", Callable(self, "_on_player_disembarked"))
	if bus.has_signal("player_embarked"):
		bus.connect("player_embarked", Callable(self, "_on_player_embarked"))

func _on_player_disembarked() -> void:
	if player != null and house != null:
		player.spawn_at_house_ladder(house)
		if camera != null:
			camera.is_player_focused = true

func _on_player_embarked() -> void:
	if player != null:
		player.set_player_active(false)
	if camera != null:
		camera.is_player_focused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu"):
		if upgrade_panel != null and upgrade_panel.visible:
			upgrade_panel.close_panel()
			get_viewport().set_input_as_handled()
			return
		if pause_menu != null and not (end_screen != null and end_screen.visible):
			pause_menu.toggle_menu()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_process_deadlock_detection(delta)

func _process_deadlock_detection(delta: float) -> void:
	var gs = _get_game_state()
	if gs == null or not gs.is_game_active or gs.is_game_over or gs.is_victory:
		deadlock_timer = 0.0
		return
		
	# Zero false positives: if player is outside, deadlock check is false
	if gs.is_player_outside:
		deadlock_timer = 0.0
		return
		
	var house_x_px: float = house.global_position.x if house != null else 0.0
	var reachable: Dictionary = ResourceNode.query_reachable_resources(house_x_px, BalanceConfig.PLAYER_MAX_TETHER_RADIUS, get_tree())
	var reachable_fuel: float = reachable.get("reachable_fuel", 0.0)
	var reachable_scrap: float = reachable.get("reachable_scrap", 0.0)
	
	var is_condition_met: bool = SimulationLogic.check_deadlock_condition(
		gs.fuel,
		gs.leg_durability,
		gs.scrap,
		1.0,
		reachable_fuel,
		reachable_scrap,
		gs.is_player_outside
	)
	
	var timer_res: Dictionary = SimulationLogic.update_deadlock_timer(
		deadlock_timer,
		is_condition_met,
		delta,
		BalanceConfig.DEADLOCK_GRACE_PERIOD
	)
	deadlock_timer = timer_res.get("timer", 0.0)
	
	if timer_res.get("is_confirmed", false):
		gs.trigger_deadlock("deadlock: Безысходный тупик: ресурсы исчерпаны, дальнейшее движение невозможно")

func _get_game_state() -> Node:
	if game_state != null:
		return game_state
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if is_inside_tree() and get_tree().root.has_node("GameState"):
		return get_tree().root.get_node("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("GameState"):
		return loop.root.get_node("GameState")
	return null

func _get_event_bus() -> Node:
	if Engine.has_singleton("EventBus"):
		return Engine.get_singleton("EventBus")
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null
