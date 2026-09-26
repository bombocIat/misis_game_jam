extends Node2D
## P1 vs AI campaign + rule cards that rewrite beats via drag-and-drop.


const CARD_SCENE: PackedScene = preload("res://scenes/rule_card.tscn")
const MAX_HAND: int = 3
const HAND_Y := 912.0
const HAND_SPACING := 250.0
const HAND_CENTER_X := 960.0
const STACK_STEP := Vector2(14.0, -12.0)

@onready var player_1: Player = %Player1
@onready var player_2: Player = %Player2
@onready var status_label: Label = %StatusLabel
@onready var rules_overlay: RulesOverlay = %RulesOverlay
@onready var tutorial_overlay: TutorialOverlay = %TutorialOverlay
@onready var card_play_zone: Area2D = %CardPlayZone
@onready var card_discard_zone: Area2D = %CardDiscardZone
@onready var card_hand: Node2D = %CardHand

var _engine: RuleEngine = RuleEngine.new()
var _stats: MatchStats = MatchStats.new()
var _ai: AiOpponent = AiOpponent.new()
var _campaign: AiCampaign = AiCampaign.new()
var _p1_ready: bool = false
var _p2_ready: bool = false
var _p1_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _p2_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _resolving: bool = false
var _ai_thinking: bool = false
var _drop_zone: DropZone
var _discard_drop_zone: DropZone
var _match_over: bool = false
var _play_stack_count: int = 0
var _p1_win_streak: int = 0
var _p2_win_streak: int = 0
var _tie_streak: int = 0
var _round_bans: Array[RuleEngine.Item] = []


func _ready() -> void:
	_ensure_drag_input()
	player_1.thrown.connect(_on_player_1_thrown)
	player_2.thrown.connect(_on_player_2_thrown)
	player_2.input_enabled = false
	player_1.input_enabled = false
	rules_overlay.bind(_engine, _stats)
	_setup_play_zone()
	_setup_discard_zone()
	tutorial_overlay.closed.connect(_on_tutorial_closed)
	_set_status("Прочитай туториал, затем Space или клик")


func _on_tutorial_closed() -> void:
	_start_match(_campaign.current_tier, false)


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_overlay.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_TAB:
		rules_overlay.toggle()
		get_viewport().set_input_as_handled()
	elif key == KEY_R and _match_over:
		_start_match(_campaign.current_tier, true)
		get_viewport().set_input_as_handled()


func _ensure_drag_input() -> void:
	if InputMap.has_action(&"draggable_click"):
		return
	InputMap.add_action(&"draggable_click")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"draggable_click", mouse)


func _make_card_type_list() -> Array[DraggableType]:
	var accepted := DraggableType.new()
	accepted.id = RuleCard.CARD_TYPE_ID
	var accepted_list: Array[DraggableType] = []
	accepted_list.append(accepted)
	return accepted_list


func _setup_play_zone() -> void:
	_drop_zone = card_play_zone.get_node("DropZone") as DropZone
	_drop_zone.accepted_draggable_types = _make_card_type_list()
	_drop_zone.snap_style = DropZone.SNAP_STYLE.SNAP_CENTER
	_drop_zone.drop_behavior = DropBehaviorStack.new()
	_drop_zone.drop_applied.connect(_on_play_drop_applied)


func _setup_discard_zone() -> void:
	_discard_drop_zone = card_discard_zone.get_node("DropZone") as DropZone
	_discard_drop_zone.accepted_draggable_types = _make_card_type_list()
	_discard_drop_zone.snap_style = DropZone.SNAP_STYLE.SNAP_CENTER
	_discard_drop_zone.drop_behavior = DropBehaviorStack.new()
	_discard_drop_zone.drop_accepted.connect(_on_discard_drop_accepted)


func _start_match(tier: int, is_retry: bool) -> void:
	_campaign.current_tier = clampi(tier, 0, _campaign.unlocked_tier)
	_campaign.save_progress()
	_ai.persona = _campaign.persona_for_tier(_campaign.current_tier)
	_engine = RuleEngine.new()
	_stats = MatchStats.new()
	rules_overlay.bind(_engine, _stats)
	_clear_hand()
	_clear_played_cards()
	_play_stack_count = 0
	_p1_win_streak = 0
	_p2_win_streak = 0
	_tie_streak = 0
	_clear_round_bans()
	player_1.reset_match(true)
	player_2.reset_match(false)
	player_2.player_name = _ai.get_display_name()
	player_2.name_label.text = _ai.get_display_name()
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	_match_over = false
	_spawn_starting_hand()
	_ai.prepare_round(_engine)
	var unlocked_hint := _campaign.name_for_tier(_campaign.unlocked_tier)
	if is_retry:
		_set_status("Реванш: %s. Выбери предмет или сыграй карту!" % _ai.get_display_name())
	else:
		_set_status(
			"Бой против %s (открыто до: %s). Выбери предмет или сыграй карту!"
			% [_ai.get_display_name(), unlocked_hint]
		)


func _clear_hand() -> void:
	for child: Node in card_hand.get_children():
		child.queue_free()


func _clear_played_cards() -> void:
	for child: Node in card_play_zone.get_children():
		if child is RuleCard:
			child.queue_free()


func _spawn_starting_hand() -> void:
	# Always one toilet-paper (1-round ban) card, rest permanent.
	_draw_card(RuleCard.BAN_KINDS[randi() % RuleCard.BAN_KINDS.size()], false)
	for _i: int in range(MAX_HAND - 1):
		_draw_permanent_card(false)
	_layout_hand()


func _hand_cards() -> Array[RuleCard]:
	var cards: Array[RuleCard] = []
	for child: Node in card_hand.get_children():
		if child is RuleCard and is_instance_valid(child):
			cards.append(child as RuleCard)
	return cards


func _hand_count() -> int:
	return _hand_cards().size()


func _draw_card(kind: RuleCard.Kind, relayout: bool = true) -> bool:
	if _hand_count() >= MAX_HAND:
		return false
	var card: RuleCard = CARD_SCENE.instantiate() as RuleCard
	card.kind = kind
	card_hand.add_child(card)
	var draggable: Draggable = card.get_node("Draggable") as Draggable
	draggable.drag_layer_parent = self
	if relayout:
		_layout_hand()
	return true


func _draw_permanent_card(relayout: bool = true) -> bool:
	var kinds: Array[RuleCard.Kind] = RuleCard.PERMANENT_KINDS
	return _draw_card(kinds[randi() % kinds.size()], relayout)


func _draw_ban_card(relayout: bool = true) -> bool:
	var kinds: Array[RuleCard.Kind] = RuleCard.BAN_KINDS
	return _draw_card(kinds[randi() % kinds.size()], relayout)


func _grant_end_of_turn_cards(player_won: bool) -> void:
	_draw_permanent_card(false)
	if player_won:
		_draw_ban_card(false)
	_layout_hand()


func _clear_round_bans() -> void:
	_round_bans.clear()
	player_1.clear_banned_items()
	player_2.clear_banned_items()


func _add_round_ban(item: RuleEngine.Item) -> void:
	if item not in _round_bans:
		_round_bans.append(item)
	player_1.set_banned_items(_round_bans)
	player_2.set_banned_items(_round_bans)


func _layout_hand() -> void:
	var cards: Array[RuleCard] = _hand_cards()
	var n: int = cards.size()
	if n <= 0:
		return
	var start_x: float = HAND_CENTER_X - float(n - 1) * HAND_SPACING * 0.5
	for i: int in range(n):
		cards[i].position = Vector2(start_x + float(i) * HAND_SPACING, HAND_Y)


func _on_play_drop_applied(_zone: DropZone, area: Area2D, _plan: DropPlan) -> void:
	if _match_over:
		return
	var card: RuleCard = area as RuleCard
	if card == null or card.resolved:
		return
	var message: String
	if card.is_round_ban():
		_add_round_ban(card.get_ban_item())
		message = "Список: %s" % card.get_ability_body()
	else:
		message = card.apply_to(_engine)
	_set_status(message)
	print(message)
	_play_stack_count += 1
	card.z_index = _play_stack_count
	card.mark_resolved()
	_layout_hand()
	_settle_stacked_card(card, _play_stack_count - 1)


func _settle_stacked_card(card: RuleCard, stack_index: int) -> void:
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(card):
		return
	card.position = STACK_STEP * float(stack_index)
	var drag: Draggable = card.get_node_or_null("Draggable") as Draggable
	if drag != null:
		drag.next_position = card.global_position
		drag.previous_position = card.global_position
		drag.state = Draggable.DRAGGABLE_STATE.IDLE


func _on_discard_drop_accepted(_zone: DropZone, area: Area2D, _plan: DropPlan) -> void:
	if _match_over:
		return
	var card: RuleCard = area as RuleCard
	if card == null or card.resolved:
		return
	card.mark_resolved()
	_set_status("Карта сброшена (без эффекта)")
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(card):
		card.queue_free()
	await get_tree().process_frame
	_layout_hand()
	if card_discard_zone.has_method("reset_visual"):
		card_discard_zone.reset_visual()


func _on_player_1_thrown(item: RuleEngine.Item) -> void:
	if _match_over:
		return
	_p1_item = item
	_p1_ready = true
	_set_status("Ты: %s — %s думает..." % [player_1.item_name(item), _ai.get_display_name()])
	_try_resolve()
	_request_ai_throw()


func _on_player_2_thrown(item: RuleEngine.Item) -> void:
	_p2_item = item
	_p2_ready = true
	_set_status("%s: %s" % [_ai.get_display_name(), player_2.item_name(item)])
	_try_resolve()


func _request_ai_throw() -> void:
	if _p2_ready or _ai_thinking or player_2.has_thrown or _match_over:
		return
	_ai_thinking = true
	player_2.choice_label.text = "%s думает..." % _ai.get_display_name()
	await get_tree().create_timer(0.45).timeout
	if _resolving or player_2.has_thrown or _match_over:
		_ai_thinking = false
		return
	var item: RuleEngine.Item = _ai.choose_item(_engine, _round_bans)
	if not _ai.last_taunt.is_empty():
		player_2.choice_label.text = _ai.last_taunt
		_set_status("%s: «%s»" % [_ai.get_display_name(), _ai.last_taunt])
		await get_tree().create_timer(1.1).timeout
		if _resolving or player_2.has_thrown or _match_over:
			_ai_thinking = false
			return
	player_2.pick(item)
	player_2.throw_item()
	_ai_thinking = false


func _try_resolve() -> void:
	if _resolving or not _p1_ready or not _p2_ready or _match_over:
		return
	_resolving = true
	var result: int = _engine.resolve(_p1_item, _p2_item)
	_stats.record_round(_p1_item, _p2_item, result)
	var left: String = player_1.item_name(_p1_item)
	var right: String = player_2.item_name(_p2_item)
	match result:
		1:
			var base: int = _engine.get_damage(_p1_item, _p2_item)
			var bonus: int = _p1_win_streak
			var dmg: int = base + bonus
			player_2.take_damage(dmg)
			_p1_win_streak += 1
			_p2_win_streak = 0
			_tie_streak = 0
			if bonus > 0:
				_set_status(
					"%s бьёт %s (−%d = %d+%d стрик)! Победа ×%d. %s: %d HP"
					% [left, right, dmg, base, bonus, _p1_win_streak, _ai.get_display_name(), player_2.hp]
				)
			else:
				_set_status(
					"%s бьёт %s (−%d) — ты победил! %s: %d HP"
					% [left, right, dmg, _ai.get_display_name(), player_2.hp]
				)
		-1:
			var base: int = _engine.get_damage(_p2_item, _p1_item)
			var bonus: int = _p2_win_streak
			var dmg: int = base + bonus
			player_1.take_damage(dmg)
			_p2_win_streak += 1
			_p1_win_streak = 0
			_tie_streak = 0
			if bonus > 0:
				_set_status(
					"%s бьёт %s (−%d = %d+%d стрик)! %s ×%d. Ты: %d HP"
					% [right, left, dmg, base, bonus, _ai.get_display_name(), _p2_win_streak, player_1.hp]
				)
			else:
				_set_status(
					"%s бьёт %s (−%d) — %s победил! Ты: %d HP"
					% [right, left, dmg, _ai.get_display_name(), player_1.hp]
				)
		_:
			_p1_win_streak = 0
			_p2_win_streak = 0
			_tie_streak += 1
			var sudden: bool = _tie_streak >= 2
			var top_bonus: int = 1 if sudden else 0
			var dmg_to_p1: int = 1
			var dmg_to_p2: int = 1
			if (
				_p1_item != _p2_item
				and _engine.has_beat(_p1_item, _p2_item)
				and _engine.has_beat(_p2_item, _p1_item)
			):
				dmg_to_p2 = _engine.get_damage(_p1_item, _p2_item)
				dmg_to_p1 = _engine.get_damage(_p2_item, _p1_item)
			dmg_to_p1 += top_bonus
			dmg_to_p2 += top_bonus
			player_1.take_damage(dmg_to_p1)
			player_2.take_damage(dmg_to_p2)
			if sudden:
				_set_status(
					"ВНЕЗАПНАЯ СМЕРТЬ! Ничья ×%d — оба −%d/−%d (+1 сверху)"
					% [_tie_streak, dmg_to_p2, dmg_to_p1]
				)
			elif (
				_p1_item != _p2_item
				and _engine.has_beat(_p1_item, _p2_item)
				and _engine.has_beat(_p2_item, _p1_item)
			):
				_set_status(
					"%s (−%d) и %s (−%d) бьют друг друга" % [left, dmg_to_p2, right, dmg_to_p1]
				)
			else:
				_set_status("%s vs %s — ничья, оба −%d HP" % [left, right, dmg_to_p1])
	print(
		"Round: %s vs %s -> %d | HP %d vs %d | streaks W%d/%d T%d"
		% [left, right, result, player_1.hp, player_2.hp, _p1_win_streak, _p2_win_streak, _tie_streak]
	)
	await get_tree().create_timer(2.0).timeout
	if not player_1.is_alive() or not player_2.is_alive():
		_end_match()
		return
	_reset_round(result == 1)


func _end_match() -> void:
	_match_over = true
	player_1.input_enabled = false
	_resolving = false
	_ai_thinking = false
	if not player_1.is_alive() and not player_2.is_alive():
		_campaign.retry_current()
		_set_status("Оба без HP — ничья. R = реванш с %s" % _ai.get_display_name())
		return
	if not player_1.is_alive():
		_campaign.retry_current()
		_set_status(
			"Поражение от %s (HP %d). R = реванш"
			% [_ai.get_display_name(), player_2.hp]
		)
		return
	# Player won.
	var previous_name: String = _ai.get_display_name()
	var unlocked_new: bool = _campaign.on_player_won()
	if unlocked_new:
		_set_status(
			"Победа над %s! Открыт: %s. Стартуем через миг..."
			% [previous_name, _campaign.name_for_tier(_campaign.current_tier)]
		)
		await get_tree().create_timer(2.2).timeout
		_start_match(_campaign.current_tier, false)
	elif _campaign.current_tier >= AiCampaign.MAX_TIER:
		_set_status("Победа над %s! Кампания пройдена. R = реванш" % previous_name)
	else:
		_set_status(
			"Победа над %s! Дальше: %s. Стартуем..."
			% [previous_name, _campaign.name_for_tier(_campaign.current_tier)]
		)
		await get_tree().create_timer(1.8).timeout
		_start_match(_campaign.current_tier, false)


func _reset_round(player_won: bool = false) -> void:
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	_clear_round_bans()
	player_1.reset_round()
	player_2.reset_round()
	_grant_end_of_turn_cards(player_won)
	_ai.prepare_round(_engine)
	_set_status(
		"Следующий раунд vs %s — бросай или сыграй карту! (карт: %d/%d | стрик W %d/%d · ничьи %d)"
		% [
			_ai.get_display_name(),
			_hand_count(),
			MAX_HAND,
			_p1_win_streak,
			_p2_win_streak,
			_tie_streak,
		]
	)


func _set_status(text: String) -> void:
	status_label.text = text
