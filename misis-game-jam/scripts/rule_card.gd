class_name RuleCard
extends Area2D
## Ability card with notebook / toilet-paper textures.

enum Kind {
	WIND,
	DRAGON,
	HOMEWORK,
	COOL_ROCK,
	CHAOS,
	VULCAN,
	PAPER_PLANE,
	MIND_MELD,
	SANDSTORM,
	EQUALIZER,
	BAN_ROCK,
	BAN_SCISSORS,
	BAN_PAPER,
	BAN_LIZARD,
	BAN_SPOCK,
}

const CARD_TYPE_ID := "rule_card"
## Base 150×200 scaled +25%.
const SIZE := Vector2(188, 250)
const FONT_SIZE := 30
const SPECIAL_TOP_PAD := 75.0
const NORMAL_TOP_PAD := 15.0
const LABEL_SIDE_PAD := 13.0

const TOILET_ART := "res://assets/textures/toilet_paper_list.png"

const PERMANENT_KINDS: Array[Kind] = [
	Kind.WIND,
	Kind.DRAGON,
	Kind.HOMEWORK,
	Kind.COOL_ROCK,
	Kind.CHAOS,
	Kind.VULCAN,
	Kind.PAPER_PLANE,
	Kind.MIND_MELD,
	Kind.SANDSTORM,
	Kind.EQUALIZER,
]

const BAN_KINDS: Array[Kind] = [
	Kind.BAN_ROCK,
	Kind.BAN_SCISSORS,
	Kind.BAN_PAPER,
	Kind.BAN_LIZARD,
	Kind.BAN_SPOCK,
]

const ART: Dictionary = {
	Kind.WIND: {"path": "res://assets/textures/card_1(special).png", "special": true},
	Kind.DRAGON: {"path": "res://assets/textures/card_2.png", "special": false},
	Kind.HOMEWORK: {"path": "res://assets/textures/card_3(special).png", "special": true},
	Kind.COOL_ROCK: {"path": "res://assets/textures/card_4.png", "special": true},
	Kind.CHAOS: {"path": "res://assets/textures/card_1(special).png", "special": true},
	Kind.VULCAN: {"path": "res://assets/textures/card_2.png", "special": false},
	Kind.PAPER_PLANE: {"path": "res://assets/textures/card_3(special).png", "special": true},
	Kind.MIND_MELD: {"path": "res://assets/textures/card_4.png", "special": true},
	Kind.SANDSTORM: {"path": "res://assets/textures/card_2.png", "special": false},
	Kind.EQUALIZER: {"path": "res://assets/textures/card_1(special).png", "special": true},
	Kind.BAN_ROCK: {"path": TOILET_ART, "special": true},
	Kind.BAN_SCISSORS: {"path": TOILET_ART, "special": true},
	Kind.BAN_PAPER: {"path": TOILET_ART, "special": true},
	Kind.BAN_LIZARD: {"path": TOILET_ART, "special": true},
	Kind.BAN_SPOCK: {"path": TOILET_ART, "special": true},
}

@export var kind: Kind = Kind.WIND

var resolved: bool = false

@onready var _label: Label = %AbilityLabel
@onready var _art: TextureRect = %CardArt
@onready var _draggable: Draggable = %Draggable
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_setup_draggable_type()
	_apply_visuals()
	monitoring = true
	monitorable = true


func mark_resolved() -> void:
	resolved = true
	input_pickable = false
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	if _draggable != null:
		_draggable.set_process(false)


func is_special() -> bool:
	return bool(ART[kind]["special"])


func is_round_ban() -> bool:
	return kind in BAN_KINDS


func get_ban_item() -> RuleEngine.Item:
	match kind:
		Kind.BAN_ROCK:
			return RuleEngine.Item.ROCK
		Kind.BAN_SCISSORS:
			return RuleEngine.Item.SCISSORS
		Kind.BAN_PAPER:
			return RuleEngine.Item.PAPER
		Kind.BAN_LIZARD:
			return RuleEngine.Item.LIZARD
		Kind.BAN_SPOCK:
			return RuleEngine.Item.SPOCK
		_:
			return RuleEngine.Item.ROCK


func get_title() -> String:
	match kind:
		Kind.DRAGON:
			return "Дракон, а не ящерица"
		Kind.VULCAN:
			return "Вулканский разум"
		Kind.SANDSTORM:
			return "Песчаная буря"
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
		Kind.CHAOS:
			return "2 случайные стрелки меняются"
		Kind.VULCAN:
			return "Спок побеждает ящерицу"
		Kind.PAPER_PLANE:
			return "Бумага побеждает ножницы"
		Kind.MIND_MELD:
			return "Спок побеждает бумагу"
		Kind.SANDSTORM:
			return "Камень бьёт Спока (+стек)"
		Kind.EQUALIZER:
			return "Камень и ножницы бьют друг друга"
		Kind.BAN_ROCK:
			return "1 раунд: нельзя камень"
		Kind.BAN_SCISSORS:
			return "1 раунд: нельзя ножницы"
		Kind.BAN_PAPER:
			return "1 раунд: нельзя бумагу"
		Kind.BAN_LIZARD:
			return "1 раунд: нельзя ящерицу"
		Kind.BAN_SPOCK:
			return "1 раунд: нельзя Спока"
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
		Kind.CHAOS:
			var flips: int = 0
			if engine.flip_random_arrow():
				flips += 1
			if engine.flip_random_arrow():
				flips += 1
			return "Хаос: развернуто стрелок — %d" % flips
		Kind.VULCAN:
			var power: int = engine.add_beat(RuleEngine.Item.SPOCK, RuleEngine.Item.LIZARD)
			return "Вулкан: Спок бьёт ящерицу (урон %d)" % power
		Kind.PAPER_PLANE:
			var power: int = engine.add_beat(RuleEngine.Item.PAPER, RuleEngine.Item.SCISSORS)
			return "Бумажный самолётик: бумага бьёт ножницы (урон %d)" % power
		Kind.MIND_MELD:
			var power: int = engine.add_beat(RuleEngine.Item.SPOCK, RuleEngine.Item.PAPER)
			return "Слияние разумов: Спок бьёт бумагу (урон %d)" % power
		Kind.SANDSTORM:
			var power: int = engine.add_beat(RuleEngine.Item.ROCK, RuleEngine.Item.SPOCK)
			return "Песчаная буря: камень бьёт Спока (урон %d)" % power
		Kind.EQUALIZER:
			var p1: int = engine.add_beat(RuleEngine.Item.ROCK, RuleEngine.Item.SCISSORS)
			var p2: int = engine.add_beat(RuleEngine.Item.SCISSORS, RuleEngine.Item.ROCK)
			return "Уравнитель: камень↔ножницы (урон %d / %d)" % [p1, p2]
		Kind.BAN_ROCK, Kind.BAN_SCISSORS, Kind.BAN_PAPER, Kind.BAN_LIZARD, Kind.BAN_SPOCK:
			return get_ability_body()
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
