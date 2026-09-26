class_name Player
extends Node2D
## RPSLS thrower. Visuals (portrait / HP bar) are bound from the duel scene.


signal choice_changed(item: RuleEngine.Item)
signal thrown(item: RuleEngine.Item)
signal hp_changed(current: int, maximum: int)
signal died

const ITEM_NAMES: Dictionary = {
	RuleEngine.Item.ROCK: "ROCK",
	RuleEngine.Item.SCISSORS: "SCISSORS",
	RuleEngine.Item.PAPER: "PAPER",
	RuleEngine.Item.LIZARD: "LIZARD",
	RuleEngine.Item.SPOCK: "SPOCK",
}

const MAX_HP: int = 10
const MOOD_FLASH_SEC := 1.0

@export var player_name: String = "Player"
@export var player_color: Color = Color(0.3, 0.7, 1.0)
## false = P1 keys 1-5 + Space; true = P2 keys 6-0 + Enter
@export var is_player_two: bool = false
@export var input_enabled: bool = true
## Hide the old ColorRect body (squares removed from the duel UI).
@export var show_body: bool = false
## Show built-in HP/name labels (false when an external bar / enemy HUD is used).
@export var show_local_hud: bool = true

var selected_item: RuleEngine.Item = RuleEngine.Item.ROCK
var has_thrown: bool = false
var hp: int = MAX_HP
var banned_items: Array[RuleEngine.Item] = []
var _face: Sprite2D
var _tex_neutral: Texture2D
var _tex_smirk: Texture2D
var _tex_angry: Texture2D
var _mood_token: int = 0

@onready var name_label: Label = %NameLabel
@onready var choice_label: Label = %ChoiceLabel
@onready var hp_label: Label = %HpLabel
@onready var body: ColorRect = %Body


func _ready() -> void:
	name_label.text = player_name
	body.color = player_color
	body.visible = show_body
	name_label.visible = show_local_hud
	hp_label.visible = show_local_hud
	_refresh_choice_ui()
	_refresh_hp_ui()


## Bind a face sprite (e.g. MinerFace) for mood flashes. Does not move/scale it.
func bind_face(face: Sprite2D, neutral: Texture2D, smirk: Texture2D, angry: Texture2D) -> void:
	_face = face
	_tex_neutral = neutral
	_tex_smirk = smirk
	_tex_angry = angry
	_mood_token += 1
	if _face != null and _tex_neutral != null:
		_face.texture = _tex_neutral


func clear_face() -> void:
	_mood_token += 1
	_face = null
	_tex_neutral = null
	_tex_smirk = null
	_tex_angry = null


func flash_hurt() -> void:
	if _face == null or _tex_angry == null:
		return
	_flash_mood(_tex_angry)


func flash_smirk() -> void:
	if _face == null or _tex_smirk == null:
		return
	_flash_mood(_tex_smirk)


func _flash_mood(tex: Texture2D) -> void:
	_mood_token += 1
	var token: int = _mood_token
	_face.texture = tex
	await get_tree().create_timer(MOOD_FLASH_SEC).timeout
	if token != _mood_token or not is_instance_valid(_face) or _tex_neutral == null:
		return
	_face.texture = _tex_neutral


func set_banned_items(items: Array[RuleEngine.Item]) -> void:
	banned_items = items.duplicate()
	if selected_item in banned_items:
		_select_first_allowed()
	_refresh_choice_ui()


func clear_banned_items() -> void:
	banned_items.clear()
	_refresh_choice_ui()


func is_item_allowed(item: RuleEngine.Item) -> bool:
	return item not in banned_items


func _select_first_allowed() -> void:
	for item: RuleEngine.Item in [
		RuleEngine.Item.ROCK,
		RuleEngine.Item.SCISSORS,
		RuleEngine.Item.PAPER,
		RuleEngine.Item.LIZARD,
		RuleEngine.Item.SPOCK,
	]:
		if is_item_allowed(item):
			selected_item = item
			return


func _unhandled_input(event: InputEvent) -> void:
	if (
		not input_enabled
		or not is_alive()
		or has_thrown
		or not (event is InputEventKey and event.pressed and not event.echo)
	):
		return
	var key: Key = (event as InputEventKey).keycode
	if is_player_two:
		_handle_p2_keys(key)
	else:
		_handle_p1_keys(key)


func pick(item: RuleEngine.Item) -> bool:
	if has_thrown or not is_alive():
		return false
	if not is_item_allowed(item):
		choice_label.text = "BAN: %s" % item_name(item)
		return false
	selected_item = item
	choice_changed.emit(item)
	_refresh_choice_ui()
	return true


func throw_item() -> void:
	if has_thrown or not is_alive():
		return
	if not is_item_allowed(selected_item):
		_select_first_allowed()
		if not is_item_allowed(selected_item):
			choice_label.text = "Нет доступных предметов"
			return
	has_thrown = true
	_refresh_choice_ui()
	thrown.emit(selected_item)


func reset_round() -> void:
	has_thrown = false
	_refresh_choice_ui()


func reset_match(enable_input: bool = true) -> void:
	hp = MAX_HP
	has_thrown = false
	selected_item = RuleEngine.Item.ROCK
	banned_items.clear()
	input_enabled = enable_input
	_mood_token += 1
	if _face != null and _tex_neutral != null:
		_face.texture = _tex_neutral
	_refresh_choice_ui()
	_refresh_hp_ui()


func is_alive() -> bool:
	return hp > 0


func heal(amount: int = 1) -> void:
	if amount <= 0 or not is_alive():
		return
	hp = mini(MAX_HP, hp + amount)
	_refresh_hp_ui()
	hp_changed.emit(hp, MAX_HP)


func take_damage(amount: int = 1) -> void:
	if amount <= 0 or not is_alive():
		return
	hp = maxi(0, hp - amount)
	_refresh_hp_ui()
	hp_changed.emit(hp, MAX_HP)
	flash_hurt()
	if hp <= 0:
		died.emit()


func item_name(item: RuleEngine.Item = selected_item) -> String:
	return str(ITEM_NAMES.get(item, "?"))


func _handle_p1_keys(key: Key) -> void:
	match key:
		KEY_1:
			pick(RuleEngine.Item.ROCK)
		KEY_2:
			pick(RuleEngine.Item.SCISSORS)
		KEY_3:
			pick(RuleEngine.Item.PAPER)
		KEY_4:
			pick(RuleEngine.Item.LIZARD)
		KEY_5:
			pick(RuleEngine.Item.SPOCK)
		KEY_SPACE:
			throw_item()


func _handle_p2_keys(key: Key) -> void:
	match key:
		KEY_6:
			pick(RuleEngine.Item.ROCK)
		KEY_7:
			pick(RuleEngine.Item.SCISSORS)
		KEY_8:
			pick(RuleEngine.Item.PAPER)
		KEY_9:
			pick(RuleEngine.Item.LIZARD)
		KEY_0:
			pick(RuleEngine.Item.SPOCK)
		KEY_ENTER, KEY_KP_ENTER:
			throw_item()


func _refresh_choice_ui() -> void:
	if has_thrown:
		choice_label.text = "THROWN: %s" % item_name()
	else:
		choice_label.text = "READY: %s" % item_name()


func _refresh_hp_ui() -> void:
	if not show_local_hud:
		return
	hp_label.text = "HP %d/%d" % [hp, MAX_HP]
	if hp <= 3:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
