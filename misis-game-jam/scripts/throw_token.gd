class_name ThrowToken
extends Area2D
## Draggable RPSLS item — drop on the enemy to throw.


const THROW_TYPE_ID := "throw_token"

@export var item: RuleEngine.Item = RuleEngine.Item.ROCK

var home_position: Vector2 = Vector2.ZERO
var _enabled: bool = true

@onready var _sprite: Sprite2D = %Sprite
@onready var _draggable: Draggable = $Draggable


func _ready() -> void:
	_setup_type()
	monitoring = true
	monitorable = true


func setup(item_id: RuleEngine.Item, tex: Texture2D, home: Vector2) -> void:
	item = item_id
	home_position = home
	position = home
	if _sprite == null:
		await ready
	_sprite.texture = tex
	_setup_type()


func set_throw_enabled(enabled: bool) -> void:
	_enabled = enabled
	input_pickable = enabled
	modulate = Color.WHITE if enabled else Color(0.45, 0.45, 0.5, 0.7)


func return_home() -> void:
	position = home_position
	if _draggable != null:
		_draggable.next_position = global_position
		_draggable.previous_position = global_position
		_draggable.state = Draggable.DRAGGABLE_STATE.IDLE


func _setup_type() -> void:
	if _draggable == null:
		return
	var t := DraggableType.new()
	t.id = THROW_TYPE_ID
	_draggable.type = t
