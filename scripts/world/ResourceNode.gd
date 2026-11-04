# scripts/world/ResourceNode.gd
class_name ResourceNode
extends Area2D

## Interactive Resource Node entity for Milestone 3 (M3_PLAYER_EXPLORATION_WORLD).
## Features:
## - F21: Proximity Detection (Area2D with radius 50px = 2.5m)
## - F22: Russian Floating Context Prompts with dark frosted style & bobbing hover
## - F26, F27, F28: Collection of Fuel, Scrap, and Supplies via Key [E]
## - F29: Procedural vector graphics for Crates
## - F30: Procedural vector graphics for Abandoned Machinery
## - F31: Procedural vector graphics for Camp Remnants
## - F47: Deadlock proximity query interface with zero false positives

signal harvested(node: ResourceNode, yields: Dictionary)

enum NodeType {
	CRATE = 0,     # F29 Crates -> Fuel / Supplies
	MACHINERY = 1, # F30 Machinery -> Scrap / Supplies
	CAMP = 2       # F31 Camp Remnants -> Supplies / Fuel
}

# ------------------------------------------------------------------------------
# 30 DETERMINISTIC RESOURCE NODES CONFIGURATION
# ------------------------------------------------------------------------------
const DEFAULT_NODES: Array[Dictionary] = [
	{"node_id": 1, "biome_index": 0, "poi_ref": 1, "distance_m": 195.0, "world_x": 3900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 30.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+30 Топливо)", "description": "Арктический ящик с канистрами керосина"},
	{"node_id": 2, "biome_index": 0, "poi_ref": 1, "distance_m": 205.0, "world_x": 4100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 3.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+3 Металлолом, +1 Припасы)", "description": "Брошенный снегоход геологов"},
	{"node_id": 3, "biome_index": 0, "poi_ref": 2, "distance_m": 445.0, "world_x": 8900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 40.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+40 Топливо)", "description": "Склад топливных бочек у вехи"},
	{"node_id": 4, "biome_index": 0, "poi_ref": 2, "distance_m": 455.0, "world_x": 9100.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 0.0, "scrap": 2.0, "supplies": 1.0, "prompt": "[E] Обыскать лагерь (+2 Металлолом, +1 Припасы)", "description": "Временная стоянка разметчиков трассы"},
	{"node_id": 5, "biome_index": 0, "poi_ref": 3, "distance_m": 695.0, "world_x": 13900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 35.0, "scrap": 0.0, "supplies": 2.0, "prompt": "[E] Обыскать ящик (+35 Топливо, +2 Припасы)", "description": "Контейнер снабжения из грузового прицепа"},
	{"node_id": 6, "biome_index": 0, "poi_ref": 3, "distance_m": 705.0, "world_x": 14100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 4.0, "supplies": 0.0, "prompt": "[E] Разобрать механизм (+4 Металлолом)", "description": "Рама опрокинутого грузового прицепа"},
	{"node_id": 7, "biome_index": 0, "poi_ref": 4, "distance_m": 950.0, "world_x": 19000.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 35.0, "scrap": 3.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+35 Топливо, +3 Металлолом, +1 Припасы)", "description": "Заброшенный автоматический метеопост"},
	{"node_id": 8, "biome_index": 1, "poi_ref": 5, "distance_m": 1195.0, "world_x": 23900.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 40.0, "scrap": 0.0, "supplies": 2.0, "prompt": "[E] Обыскать лагерь (+40 Топливо, +2 Припасы)", "description": "Обледенелый жилой вагончик геологов"},
	{"node_id": 9, "biome_index": 1, "poi_ref": 5, "distance_m": 1205.0, "world_x": 24100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 3.0, "supplies": 0.0, "prompt": "[E] Разобрать механизм (+3 Металлолом)", "description": "Каркас бытовки и печная труба"},
	{"node_id": 10, "biome_index": 1, "poi_ref": 6, "distance_m": 1445.0, "world_x": 28900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 50.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+50 Топливо)", "description": "Бак аварийного дизель-генератора"},
	{"node_id": 11, "biome_index": 1, "poi_ref": 6, "distance_m": 1455.0, "world_x": 29100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 4.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+4 Металлолом, +1 Припасы)", "description": "Старый дизельный генератор в кожухе"},
	{"node_id": 12, "biome_index": 1, "poi_ref": 7, "distance_m": 1695.0, "world_x": 33900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 50.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+50 Топливо)", "description": "Занесённая цистерна полярного склада ГСМ"},
	{"node_id": 13, "biome_index": 1, "poi_ref": 7, "distance_m": 1705.0, "world_x": 34100.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 0.0, "scrap": 3.0, "supplies": 2.0, "prompt": "[E] Обыскать лагерь (+3 Металлолом, +2 Припасы)", "description": "Схрон ремонтной бригады цистерн"},
	{"node_id": 14, "biome_index": 1, "poi_ref": 8, "distance_m": 1950.0, "world_x": 39000.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 30.0, "scrap": 2.0, "supplies": 3.0, "prompt": "[E] Обыскать лагерь (+30 Топливо, +2 Металлолом, +3 Припасы)", "description": "Руины полевой столовой экспедиции"},
	{"node_id": 15, "biome_index": 2, "poi_ref": 9, "distance_m": 2195.0, "world_x": 43900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 35.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+35 Топливо)", "description": "Топливный кессон шагохода «Буран-1»"},
	{"node_id": 16, "biome_index": 2, "poi_ref": 9, "distance_m": 2205.0, "world_x": 44100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 6.0, "supplies": 0.0, "prompt": "[E] Разобрать механизм (+6 Металлолом)", "description": "Остов экспериментального шагохода «Буран-1»"},
	{"node_id": 17, "biome_index": 2, "poi_ref": 10, "distance_m": 2450.0, "world_x": 49000.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 40.0, "scrap": 5.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+40 Топливо, +5 Металлолом, +1 Припасы)", "description": "Мастерская тяжелых тягачей"},
	{"node_id": 18, "biome_index": 2, "poi_ref": 11, "distance_m": 2695.0, "world_x": 53900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 35.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+35 Топливо)", "description": "Топливный резервуар экскаватора"},
	{"node_id": 19, "biome_index": 2, "poi_ref": 11, "distance_m": 2705.0, "world_x": 54100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 6.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+6 Металлолом, +1 Припасы)", "description": "Гидравлические опоры шахтного экскаватора"},
	{"node_id": 20, "biome_index": 2, "poi_ref": 12, "distance_m": 2945.0, "world_x": 58900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 45.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+45 Топливо)", "description": "Топливный прицеп эвакуационного конвоя"},
	{"node_id": 21, "biome_index": 2, "poi_ref": 12, "distance_m": 2955.0, "world_x": 59100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 5.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+5 Металлолом, +1 Припасы)", "description": "Колонна брошенных арктических вездеходов"},
	{"node_id": 22, "biome_index": 3, "poi_ref": 13, "distance_m": 3200.0, "world_x": 64000.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 35.0, "scrap": 2.0, "supplies": 2.0, "prompt": "[E] Обыскать лагерь (+35 Топливо, +2 Металлолом, +2 Припасы)", "description": "Занесённая сторожка лесника среди елей"},
	{"node_id": 23, "biome_index": 3, "poi_ref": 14, "distance_m": 3445.0, "world_x": 68900.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 40.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+40 Топливо)", "description": "Канистры из кузова трелевочника"},
	{"node_id": 24, "biome_index": 3, "poi_ref": 14, "distance_m": 3455.0, "world_x": 69100.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 0.0, "scrap": 3.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+3 Металлолом, +1 Припасы)", "description": "Гусеничный трактор-трелёвочник"},
	{"node_id": 25, "biome_index": 3, "poi_ref": 15, "distance_m": 3700.0, "world_x": 74000.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 45.0, "scrap": 2.0, "supplies": 1.0, "prompt": "[E] Обыскать ящик (+45 Топливо, +2 Металлолом, +1 Припасы)", "description": "Железный герметичный контейнер МЧС"},
	{"node_id": 26, "biome_index": 3, "poi_ref": 16, "distance_m": 3950.0, "world_x": 79000.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 35.0, "scrap": 2.0, "supplies": 0.0, "prompt": "[E] Разобрать механизм (+35 Топливо, +2 Металлолом)", "description": "Рухнувшая аварийная радиомачта"},
	{"node_id": 27, "biome_index": 4, "poi_ref": 17, "distance_m": 4200.0, "world_x": 84000.0, "offset_y": 0.0, "node_type": NodeType.CAMP, "fuel": 30.0, "scrap": 0.0, "supplies": 1.0, "prompt": "[E] Обыскать лагерь (+30 Топливо, +1 Припасы)", "description": "Блокпост внешнего периметра станции"},
	{"node_id": 28, "biome_index": 4, "poi_ref": 18, "distance_m": 4450.0, "world_x": 89000.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 40.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+40 Топливо)", "description": "Узел резервной насосной станции"},
	{"node_id": 29, "biome_index": 4, "poi_ref": 19, "distance_m": 4700.0, "world_x": 94000.0, "offset_y": 0.0, "node_type": NodeType.MACHINERY, "fuel": 30.0, "scrap": 0.0, "supplies": 1.0, "prompt": "[E] Разобрать механизм (+30 Топливо, +1 Припасы)", "description": "Обледеневший железнодорожный семафор"},
	{"node_id": 30, "biome_index": 4, "poi_ref": 20, "distance_m": 4950.0, "world_x": 99000.0, "offset_y": 0.0, "node_type": NodeType.CRATE, "fuel": 40.0, "scrap": 0.0, "supplies": 0.0, "prompt": "[E] Обыскать ящик (+40 Топливо)", "description": "Аварийный схрон у Врат Станции «Полюс»"}
]

# ------------------------------------------------------------------------------
# EXPORT CONFIGURATION
# ------------------------------------------------------------------------------
@export var node_id: int = 1
@export var node_type: NodeType = NodeType.CRATE
@export var distance_m: float = 200.0
@export var display_name: String = "Ящик снабжения"

@export_group("Resource Yields")
@export var fuel_yield: float = 30.0
@export var scrap_yield: float = 0.0
@export var supplies_yield: float = 0.0

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var prompt_pivot: Node2D = get_node_or_null("PromptPivot")
@onready var prompt_panel: PanelContainer = get_node_or_null("PromptPivot/PromptPanel")
@onready var prompt_label: Label = get_node_or_null("PromptPivot/PromptPanel/PromptLabel")
@onready var particles: CPUParticles2D = get_node_or_null("CollectionParticles")

# ------------------------------------------------------------------------------
# RUNTIME STATE
# ------------------------------------------------------------------------------
var is_player_nearby: bool = false
var is_harvested: bool = false
var prompt_text: String = ""
var anim_timer: float = 0.0
var base_prompt_y: float = -65.0

# ------------------------------------------------------------------------------
# COLOR PALETTE (Pure Procedural Graphics — Zero External Textures)
# ------------------------------------------------------------------------------
const C_WOOD_BASE := Color(0.38, 0.28, 0.20, 1.0)
const C_WOOD_DARK := Color(0.24, 0.17, 0.12, 1.0)
const C_WOOD_LIGHT := Color(0.48, 0.36, 0.26, 1.0)
const C_IRON_STRAP := Color(0.26, 0.29, 0.34, 1.0)
const C_IRON_RIVET := Color(0.70, 0.75, 0.82, 1.0)

const C_STEEL_BASE := Color(0.22, 0.25, 0.30, 1.0)
const C_STEEL_DARK := Color(0.14, 0.16, 0.20, 1.0)
const C_STEEL_RUST := Color(0.55, 0.28, 0.15, 0.9)
const C_PIPE_METAL := Color(0.35, 0.38, 0.42, 1.0)

const C_TENT_CANVAS := Color(0.28, 0.38, 0.32, 1.0)
const C_TENT_ORANGE := Color(0.68, 0.36, 0.18, 1.0)
const C_TENT_SHADOW := Color(0.16, 0.22, 0.18, 1.0)
const C_DRUM_METAL := Color(0.32, 0.30, 0.28, 1.0)
const C_ASH_BLACK := Color(0.12, 0.12, 0.12, 1.0)

const C_SNOW_TOP := Color(0.95, 0.98, 1.0, 1.0)
const C_SNOW_SHADOW := Color(0.75, 0.82, 0.90, 0.8)

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------
func _init() -> void:
	_setup_collision()

func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("poi")
	_setup_collision()
	_setup_prompt_ui()
	_build_prompt_string()
	
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	if prompt_pivot != null:
		base_prompt_y = prompt_pivot.position.y
		prompt_pivot.visible = false

func _setup_collision() -> void:
	collision_layer = 8 # Layer 4 (Interactables)
	collision_mask = 4  # Detect Layer 3 (Player)
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 50.0 # 2.5m * 20 px/m
		collision_shape.shape = circle
		add_child(collision_shape)

func _setup_prompt_ui() -> void:
	if prompt_pivot == null:
		prompt_pivot = get_node_or_null("PromptPivot")
	if prompt_pivot == null:
		prompt_pivot = Node2D.new()
		prompt_pivot.name = "PromptPivot"
		prompt_pivot.position = Vector2(0, -65)
		add_child(prompt_pivot)
		
	if prompt_panel == null:
		prompt_panel = prompt_pivot.get_node_or_null("PromptPanel")
	if prompt_panel == null:
		prompt_panel = PanelContainer.new()
		prompt_panel.name = "PromptPanel"
		prompt_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
		prompt_panel.offset_left = -100.0
		prompt_panel.offset_top = -30.0
		prompt_panel.offset_right = 100.0
		prompt_panel.offset_bottom = 0.0
		prompt_pivot.add_child(prompt_panel)
		
	if prompt_label == null:
		prompt_label = prompt_panel.get_node_or_null("PromptLabel")
	if prompt_label == null:
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.add_theme_font_size_override("font_size", 13)
		prompt_panel.add_child(prompt_label)
		
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.35, 0.55, 0.78, 0.90)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 4.0
	prompt_panel.add_theme_stylebox_override("panel", sb)
	prompt_label.modulate = Color(0.95, 0.98, 1.0, 1.0)

func _process(delta: float) -> void:
	if is_player_nearby and not is_harvested and prompt_pivot != null:
		anim_timer += delta
		var bob: float = sin(anim_timer * 4.0) * 3.0
		prompt_pivot.position.y = base_prompt_y + bob

func _build_prompt_string() -> void:
	var yields: Array[String] = []
	if fuel_yield > 0.0:
		yields.append("+%d Топливо" % int(fuel_yield))
	if scrap_yield > 0.0:
		yields.append("+%d Металлолом" % int(scrap_yield))
	if supplies_yield > 0.0:
		yields.append("+%d Припасы" % int(supplies_yield))
	
	var yield_str: String = " (%s)" % ", ".join(yields) if not yields.is_empty() else ""
	
	match node_type:
		NodeType.CRATE:
			prompt_text = "[E] Обыскать ящик%s" % yield_str
		NodeType.MACHINERY:
			prompt_text = "[E] Разобрать механизм%s" % yield_str
		NodeType.CAMP:
			prompt_text = "[E] Обыскать лагерь%s" % yield_str
			
	if prompt_label != null:
		prompt_label.text = prompt_text

func get_interaction_prompt() -> String:
	if prompt_text.is_empty():
		_build_prompt_string()
	return prompt_text

func setup_node(data: Dictionary) -> void:
	_setup_collision()
	node_id = data.get("node_id", 1)
	node_type = data.get("node_type", NodeType.CRATE)
	distance_m = data.get("distance_m", 0.0)
	display_name = data.get("description", "Ресурсная точка")
	fuel_yield = data.get("fuel", 0.0)
	scrap_yield = data.get("scrap", 0.0)
	supplies_yield = data.get("supplies", 0.0)
	_build_prompt_string()
	queue_redraw()

# ------------------------------------------------------------------------------
# INTERACTION & INPUT
# ------------------------------------------------------------------------------
func interact(_caller: Node = null) -> Dictionary:
	return harvest()

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_harvested:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		harvest()

func _on_body_entered(body: Node2D) -> void:
	if is_harvested:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("player") or body is CharacterBody2D:
		_set_player_present(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player") or body is CharacterBody2D:
		_set_player_present(false)

func _on_area_entered(area: Area2D) -> void:
	if is_harvested:
		return
	if area.is_in_group("player") or area.name == "InteractionArea" or area.get_parent().name.to_lower().contains("player"):
		_set_player_present(true)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player") or area.name == "InteractionArea" or area.get_parent().name.to_lower().contains("player"):
		_set_player_present(false)

func _set_player_present(present: bool) -> void:
	is_player_nearby = present
	if prompt_pivot != null:
		prompt_pivot.visible = present and not is_harvested
	if present and not is_harvested:
		_emit_event_bus("prompt_requested", [prompt_text])
	else:
		_emit_event_bus("prompt_cleared", [])

# ------------------------------------------------------------------------------
# HARVESTING
# ------------------------------------------------------------------------------
func harvest() -> Dictionary:
	if is_harvested:
		return {"fuel": 0.0, "scrap": 0.0, "supplies": 0.0}
		
	is_harvested = true
	is_player_nearby = false
	
	if prompt_pivot != null:
		prompt_pivot.visible = false
	_emit_event_bus("prompt_cleared", [])
	
	# Update GameState & emit signals
	var gs: Node = _get_game_state()
	if gs != null:
		if fuel_yield > 0.0:
			gs.collect_resource("fuel", fuel_yield, global_position)
		if scrap_yield > 0.0:
			gs.collect_resource("scrap", scrap_yield, global_position)
		if supplies_yield > 0.0:
			gs.collect_resource("supplies", supplies_yield, global_position)
			
	var sm: Node = _get_sound_manager()
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("loot")
		
	if particles != null:
		particles.restart()
		particles.emitting = true
		
	queue_redraw()
	
	var result := {
		"fuel": fuel_yield,
		"scrap": scrap_yield,
		"supplies": supplies_yield
	}
	harvested.emit(self, result)
	return result

# ------------------------------------------------------------------------------
# PROXIMITY QUERY FOR DEADLOCK DETECTION (F47)
# ------------------------------------------------------------------------------
func is_reachable_from(house_pos_x: float, safe_radius_m: float = 45.0) -> bool:
	if is_harvested:
		return false
	var dist_m: float = absf(global_position.x - house_pos_x) / 20.0 # BalanceConfig.METERS_TO_PIXELS
	return dist_m <= safe_radius_m

func get_unharvested_resources() -> Dictionary:
	if is_harvested:
		return {"fuel": 0.0, "scrap": 0.0, "supplies": 0.0}
	return {
		"fuel": fuel_yield,
		"scrap": scrap_yield,
		"supplies": supplies_yield
	}

static func query_reachable_resources(house_world_x: float, safe_radius_m: float = 45.0, tree: SceneTree = null) -> Dictionary:
	var totals := {
		"reachable_fuel": 0.0,
		"reachable_scrap": 0.0,
		"reachable_supplies": 0.0,
		"reachable_node_count": 0
	}
	if tree == null:
		var loop = Engine.get_main_loop()
		if loop is SceneTree:
			tree = loop
	if tree == null:
		return totals
		
	var nodes: Array = tree.get_nodes_in_group("resource_nodes")
	for node in nodes:
		if node is ResourceNode and not node.is_harvested:
			if node.is_reachable_from(house_world_x, safe_radius_m):
				totals["reachable_fuel"] += node.fuel_yield
				totals["reachable_scrap"] += node.scrap_yield
				totals["reachable_supplies"] += node.supplies_yield
				totals["reachable_node_count"] += 1
				
	return totals

# ------------------------------------------------------------------------------
# PROCEDURAL VECTOR GRAPHICS (_draw)
# ------------------------------------------------------------------------------
func _draw() -> void:
	match node_type:
		NodeType.CRATE:
			_draw_crate()
		NodeType.MACHINERY:
			_draw_machinery()
		NodeType.CAMP:
			_draw_camp()

# F29: Procedural Wood & Metal Cargo Crate
func _draw_crate() -> void:
	var w: float = 38.0
	var h: float = 28.0
	var box_rect := Rect2(-w * 0.5, -h, w, h)
	
	if not is_harvested:
		# Intact Crate
		draw_rect(box_rect, C_WOOD_BASE)
		draw_rect(box_rect, C_WOOD_DARK, false, 2.0)
		
		# Wooden Planks
		var plank_h: float = h / 3.0
		draw_line(Vector2(-w * 0.5, -h + plank_h), Vector2(w * 0.5, -h + plank_h), C_WOOD_DARK, 1.5)
		draw_line(Vector2(-w * 0.5, -h + plank_h * 2.0), Vector2(w * 0.5, -h + plank_h * 2.0), C_WOOD_DARK, 1.5)
		
		# Iron Strapping
		draw_rect(Rect2(-w * 0.5, -h, 6, h), C_IRON_STRAP)
		draw_rect(Rect2(w * 0.5 - 6, -h, 6, h), C_IRON_STRAP)
		draw_line(Vector2(-w * 0.5 + 4, -h + 3), Vector2(w * 0.5 - 4, -3), C_IRON_STRAP, 2.5)
		
		# Iron Rivets
		draw_circle(Vector2(-w * 0.5 + 3, -h + 4), 2.0, C_IRON_RIVET)
		draw_circle(Vector2(w * 0.5 - 3, -h + 4), 2.0, C_IRON_RIVET)
		draw_circle(Vector2(-w * 0.5 + 3, -4), 2.0, C_IRON_RIVET)
		draw_circle(Vector2(w * 0.5 - 3, -4), 2.0, C_IRON_RIVET)
		
		# Stencil Marking
		if fuel_yield > 0.0:
			draw_rect(Rect2(-4, -h * 0.5 - 4, 8, 8), Color(0.85, 0.35, 0.2, 0.8))
			draw_circle(Vector2(0, -h * 0.5), 2.0, C_IRON_RIVET)
		else:
			draw_rect(Rect2(-2, -h * 0.5 - 5, 4, 10), Color(0.9, 0.9, 0.9, 0.8))
			draw_rect(Rect2(-5, -h * 0.5 - 2, 10, 4), Color(0.9, 0.9, 0.9, 0.8))
			
		# Arched Snow Layer on Lid
		var snow_pts := PackedVector2Array([
			Vector2(-w * 0.5 - 2, -h),
			Vector2(-w * 0.2, -h - 5),
			Vector2(w * 0.2, -h - 6),
			Vector2(w * 0.5 + 2, -h),
			Vector2(w * 0.5, -h + 3),
			Vector2(-w * 0.5, -h + 3)
		])
		draw_polygon(snow_pts, PackedColorArray([C_SNOW_TOP, C_SNOW_TOP, C_SNOW_TOP, C_SNOW_TOP, C_SNOW_SHADOW, C_SNOW_SHADOW]))
	else:
		# Harvested/Opened Crate
		draw_rect(box_rect, C_WOOD_DARK)
		draw_rect(Rect2(-w * 0.5 + 3, -h + 5, w - 6, h - 7), Color(0.10, 0.08, 0.06)) # Hollow dark interior
		# Lid ajar at angle
		var lid_pts := PackedVector2Array([
			Vector2(-w * 0.5 - 4, -h - 10),
			Vector2(w * 0.5 - 2, -h + 2),
			Vector2(w * 0.5 - 6, -h + 6),
			Vector2(-w * 0.5 - 8, -h - 6)
		])
		draw_polygon(lid_pts, PackedColorArray([C_WOOD_LIGHT, C_WOOD_BASE, C_WOOD_DARK, C_WOOD_DARK]))
		# Scattered snow dusting inside
		draw_rect(Rect2(-10, -5, 20, 3), C_SNOW_SHADOW)

# F30: Procedural Heavy Industrial Machinery & Cogwheels
func _draw_machinery() -> void:
	var w: float = 52.0
	var h: float = 36.0
	
	if not is_harvested:
		# Base Chassis Block
		draw_rect(Rect2(-w * 0.5, -h + 8, w, h - 8), C_STEEL_BASE)
		draw_rect(Rect2(-w * 0.5, -h + 8, w, h - 8), C_STEEL_DARK, false, 2.0)
		
		# Rust Stains
		draw_line(Vector2(-12, -h + 10), Vector2(-12, -4), C_STEEL_RUST, 3.0)
		draw_line(Vector2(10, -h + 14), Vector2(10, -2), C_STEEL_RUST, 2.0)
		
		# Cylindrical Tank / Exhaust Pipe
		draw_rect(Rect2(w * 0.5 - 14, -h - 10, 10, 24), C_PIPE_METAL)
		draw_circle(Vector2(w * 0.5 - 9, -h - 10), 5.0, C_STEEL_DARK)
		
		# Central Exposed Cogwheel
		var cog_center := Vector2(-8, -h * 0.5)
		draw_circle(cog_center, 10.0, C_STEEL_DARK)
		draw_circle(cog_center, 8.0, C_PIPE_METAL)
		draw_circle(cog_center, 3.5, C_STEEL_DARK)
		for i in range(6):
			var angle: float = i * (PI / 3.0)
			var tooth_pos := cog_center + Vector2(cos(angle), sin(angle)) * 9.0
			draw_circle(tooth_pos, 2.5, C_STEEL_BASE)
			
		# Radiator Grille
		for i in range(4):
			var gy: float = -h + 14.0 + (i * 4.0)
			draw_line(Vector2(6, gy), Vector2(w * 0.5 - 8, gy), C_STEEL_DARK, 1.5)
			
		# Snow Banking along bottom
		var snow_drift := PackedVector2Array([
			Vector2(-w * 0.5 - 6, 0),
			Vector2(-w * 0.2, -6),
			Vector2(w * 0.2, -4),
			Vector2(w * 0.5 + 6, 0)
		])
		draw_polygon(snow_drift, PackedColorArray([C_SNOW_TOP, C_SNOW_TOP, C_SNOW_SHADOW, C_SNOW_SHADOW]))
	else:
		# Stripped Machinery Framework
		draw_rect(Rect2(-w * 0.5, -h + 16, w, h - 16), C_STEEL_DARK)
		draw_line(Vector2(-w * 0.5, -h + 8), Vector2(w * 0.5 - 10, -h + 8), C_PIPE_METAL, 2.0)
		draw_line(Vector2(-15, -h + 8), Vector2(-15, 0), C_PIPE_METAL, 2.0)
		# Broken cog on ground
		draw_circle(Vector2(w * 0.5 + 4, -4), 6.0, C_STEEL_RUST)
		draw_circle(Vector2(w * 0.5 + 4, -4), 2.0, Color.BLACK)
		# Black grease stain in snow
		draw_circle(Vector2(-4, -2), 8.0, Color(0.12, 0.12, 0.14, 0.7))

# F31: Procedural Expedition Tent & Camp Remnants
func _draw_camp() -> void:
	var tw: float = 46.0
	var th: float = 38.0
	
	if not is_harvested:
		# Triangular Canvas Tent
		var tent_poly := PackedVector2Array([
			Vector2(-tw * 0.5, 0),
			Vector2(-8, -th),
			Vector2(tw * 0.5 - 10, 0)
		])
		draw_polygon(tent_poly, PackedColorArray([C_TENT_CANVAS, C_TENT_ORANGE, C_TENT_CANVAS]))
		draw_polyline(tent_poly, C_TENT_SHADOW, 2.0)
		
		# Ridgepole & Guy Lines
		draw_line(Vector2(-8, -th), Vector2(-tw * 0.5 - 8, 0), Color(0.8, 0.8, 0.8, 0.6), 1.0)
		draw_line(Vector2(-8, -th), Vector2(tw * 0.5, 0), Color(0.8, 0.8, 0.8, 0.6), 1.0)
		
		# Metal Fuel/Supply Barrel Beside Tent
		var barrel_rect := Rect2(tw * 0.5 - 8, -22, 14, 22)
		draw_rect(barrel_rect, C_DRUM_METAL)
		draw_rect(barrel_rect, C_STEEL_DARK, false, 1.5)
		draw_line(Vector2(tw * 0.5 - 8, -15), Vector2(tw * 0.5 + 6, -15), C_STEEL_DARK, 1.0)
		draw_line(Vector2(tw * 0.5 - 8, -7), Vector2(tw * 0.5 + 6, -7), C_STEEL_DARK, 1.0)
		
		# Stone Fire Pit with Embers
		var pit_pos := Vector2(-tw * 0.5 - 12, -4)
		draw_circle(pit_pos, 7.0, C_ASH_BLACK)
		draw_circle(pit_pos + Vector2(2, -1), 2.0, Color(0.9, 0.45, 0.1, 0.85)) # Glowing ember
		for i in range(5):
			var a: float = i * (TAU / 5.0)
			draw_circle(pit_pos + Vector2(cos(a), sin(a)) * 6.5, 2.2, Color(0.45, 0.48, 0.52))
			
		# Snow Cap on Tent Peak
		draw_line(Vector2(-14, -th + 6), Vector2(-8, -th), C_SNOW_TOP, 3.0)
		draw_line(Vector2(-8, -th), Vector2(2, -th + 8), C_SNOW_TOP, 3.0)
	else:
		# Torn Canvas Tent
		var torn_poly := PackedVector2Array([
			Vector2(-tw * 0.5, 0),
			Vector2(-12, -th * 0.6),
			Vector2(4, -th * 0.3),
			Vector2(tw * 0.5 - 10, 0)
		])
		draw_polygon(torn_poly, PackedColorArray([C_TENT_SHADOW, C_TENT_CANVAS, C_TENT_SHADOW, C_TENT_SHADOW]))
		# Knocked Over Barrel
		draw_rect(Rect2(tw * 0.5 - 6, -8, 22, 10), C_DRUM_METAL)
		# Snowed-over fire pit
		draw_circle(Vector2(-tw * 0.5 - 12, -3), 7.0, C_SNOW_SHADOW)

# ------------------------------------------------------------------------------
# HELPER SINGLETON ACCESSORS & WIRING
# ------------------------------------------------------------------------------
var game_state: Node = null
var event_bus: Node = null
var sound_manager: Node = null

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

func _get_sound_manager() -> Node:
	if sound_manager != null:
		return sound_manager
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and get_tree().root.has_node("SoundManager"):
		return get_tree().root.get_node("SoundManager")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null and loop.root.has_node("SoundManager"):
		return loop.root.get_node("SoundManager")
	return null

func _emit_event_bus(signal_name: String, args: Array = []) -> void:
	var bus: Node = event_bus
	if bus == null and Engine.has_singleton("EventBus"):
		bus = Engine.get_singleton("EventBus")
	elif bus == null and is_inside_tree() and get_tree().root.has_node("EventBus"):
		bus = get_tree().root.get_node("EventBus")
	elif bus == null:
		var loop = Engine.get_main_loop()
		if loop is SceneTree and loop.root != null and loop.root.has_node("EventBus"):
			bus = loop.root.get_node("EventBus")
	if bus != null and bus.has_signal(signal_name):
		bus.callv("emit_signal", [signal_name] + args)
