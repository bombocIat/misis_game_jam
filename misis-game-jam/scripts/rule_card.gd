class_name RuleCard
extends Area2D
## Ability card with notebook textures. Special arts: no title, top pad.

enum Kind { WIND, DRAGON, HOMEWORK, COOL_ROCK }

const CARD_TYPE_ID := "rule_card"
## Base 150×200 scaled +25%.
const SIZE := Vector2(188, 250)
const FONT_SIZE := 30
const SPECIAL_TOP_PAD := 75.0
const NORMAL_TOP_PAD := 15.0
const LABEL_SIDE_PAD := 13.0

const ART: Dictionary = {
	Kind.WIND: {
		"path": "res://assets/textures/card_1(special).png",
		"special": true,
	},
	Kind.DRAGON: {
		"path": "res://assets/textures/card_2.png",
		"special": false,
	},
	Kind.HOMEWORK: {
		"path": "res://assets/textures/card_3(special).png",
		"special": true,
	},
	Kind.COOL_ROCK: {
		"path": "res://assets/textures/card_4.png",
		"special": true,
	},
}

@export var kind: Kind = Kind.WIND

@onready var _label: Label = %AbilityLabel
@onready var _art: TextureRect = %CardArt
@onready var _draggable: Draggable = %Draggable
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_setup_draggable_type()
	_apply_visuals()
	monitoring = true
	monitorable = true


func is_special() -> bool:
	return bool(ART[kind]["special"])


func get_title() -> String:
	match kind:
		Kind.WIND:
			return ""
		Kind.DRAGON:
			return "Дракон, а не ящерица"
		Kind.HOMEWORK:
			return ""
		Kind.COOL_ROCK:
			return ""
		_:
			return ""


func get_ability_body() -> String:
	match kind:
		Kind.WIND:
			return "1 случайная стрелка меняется"
		Kind.DRAGON:
			return "Ящерица побеждает камень"
		Kind.HOMEWORK:
			return "Ножницы побеждают камень"
		Kind.COOL_ROCK:
			return "Камень побеждает бумагу"
		_:
			return ""


func get_ability_text() -> String:
	var title: String = get_title()
	var body: String = get_ability_body()
	if title.is_empty() or is_special():
		return body
	return "%s\n\n%s" % [title, body]


func apply_to(engine: RuleEngine) -> String:
	match kind:
		Kind.WIND:
			if engine.flip_random_arrow():
				return "Ветер: случайная стрелка развернулась"
			return "Ветер: нечего менять"
		Kind.DRAGON:
			var power: int = engine.add_beat(RuleEngine.Item.LIZARD, RuleEngine.Item.ROCK)
			return "Дракон: ящерица бьёт камень (урон %d)" % power
		Kind.HOMEWORK:
			var power: int = engine.add_beat(RuleEngine.Item.SCISSORS, RuleEngine.Item.ROCK)
			return "Классная работа: ножницы бьют камень (урон %d)" % power
		Kind.COOL_ROCK:
			var power: int = engine.add_beat(RuleEngine.Item.ROCK, RuleEngine.Item.PAPER)
			return "Крутой камень: камень бьёт бумагу (урон %d)" % power
		_:
			return ""


func _apply_visuals() -> void:
	var def: Dictionary = ART[kind] as Dictionary
	_art.texture = load(str(def["path"])) as Texture2D
	_art.offset_left = -SIZE.x * 0.5
	_art.offset_right = SIZE.x * 0.5
	_art.offset_top = -SIZE.y * 0.5
	_art.offset_bottom = SIZE.y * 0.5
	if _collision.shape is RectangleShape2D:
		(_collision.shape as RectangleShape2D).size = SIZE
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.text = get_ability_text()
	var top: float = SPECIAL_TOP_PAD if is_special() else NORMAL_TOP_PAD
	_label.offset_left = -SIZE.x * 0.5 + LABEL_SIDE_PAD
	_label.offset_right = SIZE.x * 0.5 - LABEL_SIDE_PAD
	_label.offset_top = -SIZE.y * 0.5 + top
	_label.offset_bottom = SIZE.y * 0.5 - LABEL_SIDE_PAD
	if is_special():
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _setup_draggable_type() -> void:
	var card_type := DraggableType.new()
	card_type.id = CARD_TYPE_ID
	_draggable.type = card_type
