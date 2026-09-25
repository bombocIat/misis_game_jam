extends Node2D
## P1 vs AI + rule cards that rewrite beats via drag-and-drop.


const CARD_SCENE: PackedScene = preload("res://scenes/rule_card.tscn")
const MAX_HAND: int = 3
const HAND_Y := 760.0
const HAND_SPACING := 210.0
const HAND_CENTER_X := 800.0

const ALL_KINDS: Array[RuleCard.Kind] = [
	RuleCard.Kind.WIND,
	RuleCard.Kind.DRAGON,
	RuleCard.Kind.HOMEWORK,
	RuleCard.Kind.COOL_ROCK,
]

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
	_spawn_starting_hand()
	hint_label.text = (
		"Ты: 1–5 предмет, Space = бросок  |  Карты: макс 3  |  В конце хода +1, за победу ещё +1"
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


func _spawn_starting_hand() -> void:
	for _i: int in range(MAX_HAND):
		_draw_random_card(false)
	_layout_hand()


func _hand_cards() -> Array[RuleCard]:
	var cards: Array[RuleCard] = []
	for child: Node in card_hand.get_children():
		if child is RuleCard and is_instance_valid(child):
			cards.append(child as RuleCard)
	return cards


func _hand_count() -> int:
	return _hand_cards().size()


func _draw_random_card(relayout: bool = true) -> bool:
	if _hand_count() >= MAX_HAND:
		return false
	var card: RuleCard = CARD_SCENE.instantiate() as RuleCard
	card.kind = ALL_KINDS[randi() % ALL_KINDS.size()]
	card_hand.add_child(card)
	var draggable: Draggable = card.get_node("Draggable") as Draggable
	draggable.drag_layer_parent = self
	if relayout:
		_layout_hand()
	return true


func _grant_end_of_turn_cards(player_won: bool) -> void:
	# Always +1, and +1 more for a win. Cap at MAX_HAND.
	_draw_random_card(false)
	if player_won:
		_draw_random_card(false)
	_layout_hand()


func _layout_hand() -> void:
	var cards: Array[RuleCard] = _hand_cards()
	var n: int = cards.size()
	if n <= 0:
		return
	var start_x: float = HAND_CENTER_X - float(n - 1) * HAND_SPACING * 0.5
	for i: int in range(n):
		cards[i].position = Vector2(start_x + float(i) * HAND_SPACING, HAND_Y)


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
	await get_tree().process_frame
	_layout_hand()


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
			var dmg: int = _engine.get_damage(_p1_item, _p2_item)
			player_2.take_damage(dmg)
			_set_status("%s бьёт %s (−%d) — ты победил! AI: %d HP" % [left, right, dmg, player_2.hp])
		-1:
			var dmg: int = _engine.get_damage(_p2_item, _p1_item)
			player_1.take_damage(dmg)
			_set_status("%s бьёт %s (−%d) — AI победил! Ты: %d HP" % [right, left, dmg, player_1.hp])
		_:
			var dmg_to_p1: int = 1
			var dmg_to_p2: int = 1
			if (
				_p1_item != _p2_item
				and _engine.has_beat(_p1_item, _p2_item)
				and _engine.has_beat(_p2_item, _p1_item)
			):
				dmg_to_p2 = _engine.get_damage(_p1_item, _p2_item)
				dmg_to_p1 = _engine.get_damage(_p2_item, _p1_item)
				player_1.take_damage(dmg_to_p1)
				player_2.take_damage(dmg_to_p2)
				_set_status(
					"%s (−%d) и %s (−%d) бьют друг друга" % [left, dmg_to_p2, right, dmg_to_p1]
				)
			else:
				player_1.take_damage(dmg_to_p1)
				player_2.take_damage(dmg_to_p2)
				_set_status("%s vs %s — ничья, оба −1 HP" % [left, right])
	print("Round: %s vs %s -> %d | HP %d vs %d" % [left, right, result, player_1.hp, player_2.hp])
	await get_tree().create_timer(2.0).timeout
	if not player_1.is_alive() or not player_2.is_alive():
		_end_match()
		return
	_reset_round(result == 1)


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


func _reset_round(player_won: bool = false) -> void:
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	player_1.reset_round()
	player_2.reset_round()
	_grant_end_of_turn_cards(player_won)
	_set_status("Следующий раунд — бросай или сыграй карту! (карт: %d/%d)" % [_hand_count(), MAX_HAND])


func _set_status(text: String) -> void:
	status_label.text = text
