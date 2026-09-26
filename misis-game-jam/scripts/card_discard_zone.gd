extends Area2D
## Trash bin: opens when a card overlaps the discard collision.


const TEX_CLOSED: Texture2D = preload("res://assets/textures/trash_can.png")
const TEX_OPENED: Texture2D = preload("res://assets/textures/trash_can_opened.png")

@onready var _sprite: Sprite2D = $Sprite2D

var _hover_count: int = 0


func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_set_open(false)


func reset_visual() -> void:
	_hover_count = 0
	_set_open(false)


func _on_area_entered(area: Area2D) -> void:
	if not _is_draggable_card(area):
		return
	_hover_count += 1
	_set_open(true)


func _on_area_exited(area: Area2D) -> void:
	if not _is_draggable_card(area):
		return
	_hover_count = maxi(0, _hover_count - 1)
	if _hover_count == 0:
		_set_open(false)


func _is_draggable_card(area: Area2D) -> bool:
	if area is RuleCard:
		return not (area as RuleCard).resolved
	return area.has_meta("draggable")


func _set_open(open: bool) -> void:
	if _sprite == null:
		return
	_sprite.texture = TEX_OPENED if open else TEX_CLOSED
