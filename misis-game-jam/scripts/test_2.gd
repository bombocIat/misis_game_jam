extends Node2D
## P1 vs AI + rule cards that rewrite beats via drag-and-drop.


const CARD_SCENE: PackedScene = preload("res://scenes/rule_card.tscn")
const HAND_Y := 780.0
const HAND_XS: Array[float] = [560.0, 720.0, 880.0, 1040.0]

@onready var player_1: Player = %Player1
@onready var player_2: Player = %Player2
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel
@onready var stats_window: StatsWindow = %StatsWindow
@onready var beats_diagram: BeatsDiagram = %BeatsDiagram
@onready var card_play_zone: Area2D = %CardPlayZone
@onready var card_hand: Node2D = %CardHand

var _engine: RuleEngine = RuleEngine.new()
var _stats: MatchStats = MatchStats.new()
var _ai: AiOpponent = AiOpponent.new()
var _p1_ready: bool = false
var _p2_ready: bool = false
var _p1_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _p2_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _resolving: bool = false
var _ai_thinking: bool = false
var _drop_zone: DropZone


func _ready() -> void:
	_ensure_drag_input()
	player_1.thrown.connect(_on_player_1_thrown)
	player_2.thrown.connect(_on_player_2_thrown)
	player_2.input_enabled = false
	player_2.player_name = "AI"
	player_2.name_label.text = "AI"
	stats_window.bind_stats(_stats)
	beats_diagram.bind_engine(_engine)
	_setup_play_zone()
	_spawn_hand()
	hint_label.text = (
		"Ты: 1–5 предмет, Space = бросок  |  Перетащи карту в центр, чтобы изменить стрелки"
	)
	_set_status("Выбери предмет или сыграй карту!")


func _ensure_drag_input() -> void:
	if InputMap.has_action(&"draggable_click"):
		return
	InputMap.add_action(&"draggable_click")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"draggable_click", mouse)


func _setup_play_zone() -> void:
	_drop_zone = card_play_zone.get_node("DropZone") as DropZone
	var accepted := DraggableType.new()
	accepted.id = RuleCard.CARD_TYPE_ID
	var accepted_list: Array[DraggableType] = []
	accepted_list.append(accepted)
	_drop_zone.accepted_draggable_types = accepted_list
	_drop_zone.snap_style = DropZone.SNAP_STYLE.SNAP_CENTER
	_drop_zone.drop_accepted.connect(_on_card_drop_accepted)


func _spawn_hand() -> void:
	var kinds: Array[RuleCard.Kind] = [
		RuleCard.Kind.WIND,
		RuleCard.Kind.DRAGON,
		RuleCard.Kind.HOMEWORK,
		RuleCard.Kind.COOL_ROCK,
	]
	for i: int in range(kinds.size()):
		var card: RuleCard = CARD_SCENE.instantiate() as RuleCard
		card.kind = kinds[i]
		card_hand.add_child(card)
		card.position = Vector2(HAND_XS[i], HAND_Y)
		card.get_node("Draggable").drag_layer_parent = self


func _on_card_drop_accepted(_zone: DropZone, area: Area2D, _plan: DropPlan) -> void:
	var card: RuleCard = area as RuleCard
	if card == null:
		return
	var message: String = card.apply_to(_engine)
	_set_status(message)
	print(message)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(card):
		card.queue_free()


func _on_player_1_thrown(item: RuleEngine.Item) -> void:
	_p1_item = item
	_p1_ready = true
	_set_status("Ты: %s — AI думает..." % player_1.item_name(item))
	_try_resolve()
	_request_ai_throw()


func _on_player_2_thrown(item: RuleEngine.Item) -> void:
	_p2_item = item
	_p2_ready = true
	_set_status("AI: %s" % player_2.item_name(item))
	_try_resolve()


func _request_ai_throw() -> void:
	if _p2_ready or _ai_thinking or player_2.has_thrown:
		return
	_ai_thinking = true
	player_2.choice_label.text = "AI думает..."
	await get_tree().create_timer(0.45).timeout
	if _resolving or player_2.has_thrown:
		_ai_thinking = false
		return
	var item: RuleEngine.Item = _ai.choose_item(_engine)
	player_2.pick(item)
	player_2.throw_item()
	_ai_thinking = false


func _try_resolve() -> void:
	if _resolving or not _p1_ready or not _p2_ready:
		return
	_resolving = true
	var result: int = _engine.resolve(_p1_item, _p2_item)
	_stats.record_round(_p1_item, _p2_item, result)
	var left: String = player_1.item_name(_p1_item)
	var right: String = player_2.item_name(_p2_item)
	match result:
		1:
			player_2.take_damage(1)
			_set_status("%s бьёт %s — ты победил! AI: %d HP" % [left, right, player_2.hp])
		-1:
			player_1.take_damage(1)
			_set_status("%s бьёт %s — AI победил! Ты: %d HP" % [right, left, player_1.hp])
		_:
			player_1.take_damage(1)
			player_2.take_damage(1)
			if (
				_p1_item != _p2_item
				and _engine.has_beat(_p1_item, _p2_item)
				and _engine.has_beat(_p2_item, _p1_item)
			):
				_set_status("%s и %s бьют друг друга — оба −1 HP" % [left, right])
			else:
				_set_status("%s vs %s — ничья, оба −1 HP" % [left, right])
	print("Round: %s vs %s -> %d | HP %d vs %d" % [left, right, result, player_1.hp, player_2.hp])
	await get_tree().create_timer(2.0).timeout
	if not player_1.is_alive() or not player_2.is_alive():
		_end_match()
		return
	_reset_round()


func _end_match() -> void:
	player_1.input_enabled = false
	if not player_1.is_alive() and not player_2.is_alive():
		_set_status("Оба без HP — ничья в матче!")
	elif not player_1.is_alive():
		_set_status("Ты проиграл — у AI осталось %d HP" % player_2.hp)
	else:
		_set_status("Ты победил! У AI 0 HP")
	_resolving = false
	_ai_thinking = false


func _reset_round() -> void:
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	player_1.reset_round()
	player_2.reset_round()
	_set_status("Следующий раунд — бросай или сыграй карту!")


func _set_status(text: String) -> void:
	status_label.text = text
