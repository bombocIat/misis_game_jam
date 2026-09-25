class_name RuleCard
extends Area2D
## White ability card. Drag onto CardPlayZone to rewrite RuleEngine.beats.

enum Kind { WIND, DRAGON, COOL_ROCK }

const CARD_TYPE_ID := "rule_card"
const SIZE := Vector2(150, 200)

@export var kind: Kind = Kind.WIND

@onready var _label: Label = %AbilityLabel
@onready var _draggable: Draggable = %Draggable


func _ready() -> void:
	_setup_draggable_type()
	_label.text = get_ability_text()
	monitoring = true
	monitorable = true


func get_title() -> String:
	match kind:
		Kind.WIND:
			return "Ветер"
		Kind.DRAGON:
			return "Дракон, а не ящерица"
		Kind.COOL_ROCK:
			return "У меня крутой камень"
		_:
			return "Карта"


func get_ability_text() -> String:
	match kind:
		Kind.WIND:
			return "Ветер\n\n1 случайная стрелка меняется"
		Kind.DRAGON:
			return "Дракон, а не ящерица\n\nЯщерица побеждает камень"
		Kind.COOL_ROCK:
			return "У меня крутой камень\n\nКамень побеждает бумагу"
		_:
			return ""


func apply_to(engine: RuleEngine) -> String:
	match kind:
		Kind.WIND:
			if engine.flip_random_arrow():
				return "Ветер: случайная стрелка развернулась"
			return "Ветер: нечего менять"
		Kind.DRAGON:
			engine.add_beat(RuleEngine.Item.LIZARD, RuleEngine.Item.ROCK)
			return "Дракон: ящерица теперь бьёт камень"
		Kind.COOL_ROCK:
			engine.add_beat(RuleEngine.Item.ROCK, RuleEngine.Item.PAPER)
			return "Крутой камень: камень теперь бьёт бумагу"
		_:
			return ""


func _setup_draggable_type() -> void:
	var card_type := DraggableType.new()
	card_type.id = CARD_TYPE_ID
	_draggable.type = card_type
