extends Node2D
## P1 vs AI campaign + rule cards that rewrite beats via drag-and-drop.


const CARD_SCENE: PackedScene = preload("res://scenes/rule_card.tscn")
const THROW_TOKEN_SCENE: PackedScene = preload("res://scenes/throw_token.tscn")
const TEX_MASON_NEUTRAL: Texture2D = preload("res://assets/textures/miner_face.png")
const TEX_MASON_SMIRK: Texture2D = preload("res://assets/textures/miner_face_smirk.png")
const TEX_MASON_ANGRY: Texture2D = preload("res://assets/textures/miner_face_angry.png")
const TEX_NERD_FACE: Texture2D = preload("res://assets/textures/nerd_face.png")
const TEX_NERD_SMIRK: Texture2D = preload("res://assets/textures/nerd_smirk.png")
const TEX_NERD_ANGRY: Texture2D = preload("res://assets/textures/nerd_angry.png")
const TEX_JOKER_FACE: Texture2D = preload("res://assets/textures/joker_face.png")
const TEX_JOKER_SMIRK: Texture2D = preload("res://assets/textures/joker_smirk.png")
const TEX_JOKER_RAGE: Texture2D = preload("res://assets/textures/joker_rage.png")
const TEX_THROW: Dictionary = {
	RuleEngine.Item.ROCK: preload("res://assets/textures/rpsls/rock.png"),
	RuleEngine.Item.SCISSORS: preload("res://assets/textures/rpsls/scissors.png"),
	RuleEngine.Item.PAPER: preload("res://assets/textures/rpsls/paper.png"),
	RuleEngine.Item.LIZARD: preload("res://assets/textures/rpsls/lizard.png"),
	RuleEngine.Item.SPOCK: preload("res://assets/textures/rpsls/spock.png"),
}
const MAX_HAND: int = 3
## Rule cards: vertical column on the right wall above the pentagram.
const HAND_X := 1760.0
const HAND_TOP_Y := 190.0
const HAND_V_SPACING := 180.0
const HAND_CARD_SCALE := Vector2(0.676, 0.676)
## Throw tokens along the bottom (old hand area), clear of left HP UI.
const THROW_Y := 992.0
const THROW_START_X := 480.0
const THROW_SPACING := 190.0
const STACK_STEP := Vector2(14.0, -12.0)
## Player's played pile sits left of the zone center, the AI's — right.
const PLAYER_STACK_OFFSET := Vector2(-130.0, 0.0)
const AI_STACK_OFFSET := Vector2(130.0, 0.0)
const CARD_IDLE_DISCARD_ROUNDS := 2
## Enemy throw reveal icons (near opponent).
const ENEMY_THROW_ICON_POS := Vector2(1038.0, 584.0)
const ENEMY_THROW_ICON_SPACING := 110.0
const ENEMY_THROW_ICON_SCALE := Vector2(2.025, 2.025)
const THROW_TOKEN_SCALE := Vector2(1.5, 1.5)

@onready var player_1: Player = %Player1
@onready var player_2: Player = %Player2
@onready var status_label: Label = %StatusLabel
@onready var rules_overlay: RulesOverlay = %RulesOverlay
@onready var tutorial_overlay: TutorialOverlay = %TutorialOverlay
@onready var card_play_zone: Area2D = %CardPlayZone
@onready var card_hand: Node2D = %CardHand
@onready var side_beats: BeatsDiagram = %SideBeatsDiagram
@onready var enemy_hit_zone: Area2D = %EnemyHitZone
@onready var throw_tray: Node2D = %ThrowTray
@onready var miner_body: Sprite2D = %MinerBody
@onready var miner_face: Sprite2D = %MinerFace
@onready var nerd_body: Sprite2D = %NerdBody
@onready var nerd_face: Sprite2D = %NerdFace
@onready var joker_body: Sprite2D = %JokerBody
@onready var joker_face: Sprite2D = %JokerFace
@onready var enemy_hud: Node2D = %EnemyHud
@onready var enemy_hp_label: Label = %EnemyHpLabel
@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var player_hp_bar: ProgressBar = %PlayerHpBar
@onready var player_hp_value: Label = %PlayerHpValue

var cheater_bubble: PanelContainer
var cheater_bubble_label: Label
var _throw_tokens: Array[ThrowToken] = []
var _enemy_drop_zone: DropZone
var _enemy_throw_icons: Node2D
var _parked_throw_token: ThrowToken

var _engine: RuleEngine = RuleEngine.new()
var _stats: MatchStats = MatchStats.new()
var _ai: AiOpponent = AiOpponent.new()
var _campaign: AiCampaign = AiCampaign.new()
var _p1_ready: bool = false
var _p2_ready: bool = false
var _p1_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _p2_item: RuleEngine.Item = RuleEngine.Item.ROCK
## AI may throw several items (Шулер = 2). Primary is _p2_item = first.
var _p2_items: Array[RuleEngine.Item] = []
var _resolving: bool = false
var _ai_thinking: bool = false
var _drop_zone: DropZone
var _match_over: bool = false
var _play_stack_count: int = 0
var _ai_stack_count: int = 0
var _p1_win_streak: int = 0
var _p2_win_streak: int = 0
var _tie_streak: int = 0
var _round_bans: Array[RuleEngine.Item] = []
var _round_index: int = 0
## Player's bet on the AI's item this round; -1 = none.
var _prediction: int = -1
## Set when the player wins with paper: one extra draw next hand refill.
var _paper_bonus_draw: bool = false
## First tutorial close starts the match; later H opens are help-only.
var _match_started_from_tutorial: bool = false

const BUY_CARD_COST := 1
const PREDICTION_KEYS: Dictionary = {
	KEY_6: RuleEngine.Item.ROCK,
	KEY_7: RuleEngine.Item.SCISSORS,
	KEY_8: RuleEngine.Item.PAPER,
	KEY_9: RuleEngine.Item.LIZARD,
	KEY_0: RuleEngine.Item.SPOCK,
}


func _ready() -> void:
	_ensure_drag_input()
	_ensure_cheater_bubble()
	player_1.thrown.connect(_on_player_1_thrown)
	player_2.thrown.connect(_on_player_2_thrown)
	player_1.hp_changed.connect(_on_player_1_hp_changed)
	player_2.hp_changed.connect(_on_player_2_hp_changed)
	player_2.input_enabled = false
	player_1.input_enabled = false
	player_hp_bar.max_value = float(Player.MAX_HP)
	status_label.visible = false
	rules_overlay.bind(_engine, _stats)
	side_beats.bind_engine(_engine)
	_setup_play_zone()
	_setup_enemy_hit_zone()
	_ensure_enemy_throw_icons()
	_spawn_throw_tokens()
	tutorial_overlay.closed.connect(_on_tutorial_closed)
	_hide_cheater_bubble()
	_set_status("Прочитай туториал, затем Space или клик")


## Bubble can vanish if the scene is resaved without it — recreate at runtime.
func _ensure_cheater_bubble() -> void:
	cheater_bubble = get_node_or_null("%CheaterBubble") as PanelContainer
	cheater_bubble_label = get_node_or_null("%CheaterBubbleLabel") as Label
	if cheater_bubble != null and cheater_bubble_label != null:
		return
	cheater_bubble = PanelContainer.new()
	cheater_bubble.name = "CheaterBubble"
	cheater_bubble.unique_name_in_owner = true
	cheater_bubble.visible = false
	cheater_bubble.z_index = 30
	cheater_bubble.offset_left = 820.0
	cheater_bubble.offset_top = 360.0
	cheater_bubble.offset_right = 1180.0
	cheater_bubble.offset_bottom = 480.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	cheater_bubble.add_theme_stylebox_override("panel", style)
	add_child(cheater_bubble)
	cheater_bubble_label = Label.new()
	cheater_bubble_label.name = "CheaterBubbleLabel"
	cheater_bubble_label.unique_name_in_owner = true
	cheater_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cheater_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cheater_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cheater_bubble_label.add_theme_font_size_override("font_size", 28)
	cheater_bubble_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	cheater_bubble_label.text = "…"
	cheater_bubble.add_child(cheater_bubble_label)


func _on_tutorial_closed() -> void:
	if _match_started_from_tutorial:
		return
	_match_started_from_tutorial = true
	_start_match(_campaign.current_tier, false)


func _unhandled_input(event: InputEvent) -> void:
	if tutorial_overlay.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_H:
		tutorial_overlay.open_help()
		get_viewport().set_input_as_handled()
	elif key == KEY_TAB:
		rules_overlay.toggle()
		get_viewport().set_input_as_handled()
	elif key == KEY_R and _match_over:
		_start_match(_campaign.current_tier, true)
		get_viewport().set_input_as_handled()
	elif key == KEY_B and not _match_over:
		_try_buy_card()
		get_viewport().set_input_as_handled()
	elif PREDICTION_KEYS.has(key) and not _match_over and not player_1.has_thrown:
		_toggle_prediction(PREDICTION_KEYS[key] as RuleEngine.Item)
		get_viewport().set_input_as_handled()


func _toggle_prediction(item: RuleEngine.Item) -> void:
	if _prediction == (item as int):
		_prediction = -1
		_set_status("Ставка снята")
	else:
		_prediction = item as int
		_set_status(
			"Ставка: %s кинет %s (угадал — ×2 урон, нет — −1 HP)"
			% [_ai.get_display_name(), player_1.item_name(item)]
		)


func _try_buy_card() -> void:
	if _resolving or player_1.has_thrown:
		return
	if _hand_count() >= MAX_HAND:
		_set_status("Рука полна (%d/%d)" % [_hand_count(), MAX_HAND])
		return
	if player_1.hp <= BUY_CARD_COST:
		_set_status("Слишком мало HP, чтобы купить карту")
		return
	player_1.take_damage(BUY_CARD_COST)
	_draw_permanent_card(true)
	_set_status("Куплена карта за %d HP (осталось %d)" % [BUY_CARD_COST, player_1.hp])


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


func _setup_enemy_hit_zone() -> void:
	_enemy_drop_zone = enemy_hit_zone.get_node("DropZone") as DropZone
	var throw_type := DraggableType.new()
	throw_type.id = ThrowToken.THROW_TYPE_ID
	var accepted: Array[DraggableType] = []
	accepted.append(throw_type)
	_enemy_drop_zone.accepted_draggable_types = accepted
	_enemy_drop_zone.snap_style = DropZone.SNAP_STYLE.SNAP_CENTER
	_enemy_drop_zone.drop_behavior = DropBehaviorStack.new()
	_enemy_drop_zone.drop_applied.connect(_on_enemy_throw_drop_applied)
	enemy_hit_zone.z_index = 5
	enemy_hit_zone.monitoring = true
	enemy_hit_zone.monitorable = true


func _spawn_throw_tokens() -> void:
	_parked_throw_token = null
	for child: Node in throw_tray.get_children():
		child.queue_free()
	_throw_tokens.clear()
	var order: Array[RuleEngine.Item] = [
		RuleEngine.Item.ROCK,
		RuleEngine.Item.SCISSORS,
		RuleEngine.Item.PAPER,
		RuleEngine.Item.LIZARD,
		RuleEngine.Item.SPOCK,
	]
	for i: int in range(order.size()):
		var item: RuleEngine.Item = order[i]
		var token: ThrowToken = THROW_TOKEN_SCENE.instantiate() as ThrowToken
		var home := Vector2(THROW_START_X + float(i) * THROW_SPACING, THROW_Y)
		throw_tray.add_child(token)
		token.scale = THROW_TOKEN_SCALE
		token.setup(item, TEX_THROW[item] as Texture2D, home)
		var drag: Draggable = token.get_node("Draggable") as Draggable
		drag.drag_layer_parent = self
		_throw_tokens.append(token)
	_refresh_throw_tokens()


func _return_throw_token(token: ThrowToken) -> void:
	if not is_instance_valid(token):
		return
	if _enemy_drop_zone != null:
		DropUtils.clear_occupant_reference(_enemy_drop_zone, token)
	if token.get_parent() != throw_tray:
		token.reparent(throw_tray)
	token.return_home()


func _park_throw_token_at_drop(token: ThrowToken) -> void:
	if not is_instance_valid(token):
		return
	var drop_global: Vector2 = token.global_position
	if _enemy_drop_zone != null:
		DropUtils.clear_occupant_reference(_enemy_drop_zone, token)
	if token.get_parent() != throw_tray:
		token.reparent(throw_tray)
	token.global_position = drop_global
	var drag: Draggable = token.get_node_or_null("Draggable") as Draggable
	if drag != null:
		drag.next_position = drop_global
		drag.previous_position = drop_global
		drag.state = Draggable.DRAGGABLE_STATE.IDLE
	token.set_throw_enabled(false)
	_parked_throw_token = token


func _clear_parked_throw_token() -> void:
	if _parked_throw_token != null and is_instance_valid(_parked_throw_token):
		_return_throw_token(_parked_throw_token)
	_parked_throw_token = null


func _refresh_throw_tokens() -> void:
	for token: ThrowToken in _throw_tokens:
		if not is_instance_valid(token):
			continue
		if token == _parked_throw_token:
			token.set_throw_enabled(false)
			continue
		_return_throw_token(token)
		var banned: bool = token.item in _round_bans
		var can_throw: bool = (
			_match_started_from_tutorial
			and not _match_over
			and not _resolving
			and not _ai_thinking
			and not player_1.has_thrown
			and player_1.is_alive()
			and not banned
		)
		token.set_throw_enabled(can_throw)


func _on_enemy_throw_drop_applied(_zone: DropZone, area: Area2D, _plan: DropPlan) -> void:
	var token: ThrowToken = area as ThrowToken
	if token == null:
		return
	if _match_over or _resolving or _ai_thinking or player_1.has_thrown or not player_1.is_alive():
		call_deferred("_return_throw_token", token)
		return
	if not player_1.is_item_allowed(token.item):
		_set_status("BAN: %s" % player_1.item_name(token.item))
		call_deferred("_return_throw_token", token)
		return
	if _parked_throw_token != null and _parked_throw_token != token:
		_return_throw_token(_parked_throw_token)
	# Mark before force_throw so refresh won't snap this token home.
	_parked_throw_token = token
	token.set_throw_enabled(false)
	player_1.force_throw(token.item)
	call_deferred("_finish_throw_token_drop", token)


func _finish_throw_token_drop(token: ThrowToken) -> void:
	_park_throw_token_at_drop(token)
	_refresh_throw_tokens()

func _start_match(tier: int, is_retry: bool) -> void:
	_campaign.current_tier = clampi(tier, 0, _campaign.unlocked_tier)
	_campaign.save_progress()
	_ai.persona = _campaign.persona_for_tier(_campaign.current_tier)
	_engine = RuleEngine.new()
	_stats = MatchStats.new()
	rules_overlay.bind(_engine, _stats)
	side_beats.bind_engine(_engine)
	_clear_hand()
	_clear_played_cards()
	_clear_enemy_throw_icons()
	_clear_parked_throw_token()
	_play_stack_count = 0
	_ai_stack_count = 0
	_p1_win_streak = 0
	_p2_win_streak = 0
	_tie_streak = 0
	_round_index = 0
	_prediction = -1
	_paper_bonus_draw = false
	_clear_round_bans()
	player_1.reset_match(true)
	player_2.reset_match(false)
	player_2.player_name = _ai.get_display_name()
	_apply_ai_portrait()
	_refresh_player_hp_hud(player_1.hp, Player.MAX_HP)
	_refresh_enemy_hp_hud(player_2.hp, Player.MAX_HP)
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	_match_over = false
	_spawn_starting_hand()
	_ai.prepare_round(_engine)
	_refresh_throw_tokens()
	var unlocked_hint := _campaign.name_for_tier(_campaign.unlocked_tier)
	if is_retry:
		_set_status("Реванш: %s. Кинь предмет во врага или сыграй карту!" % _ai.get_display_name())
	else:
		_set_status(
			"Бой против %s (открыто до: %s). Кинь предмет во врага или сыграй карту!"
			% [_ai.get_display_name(), unlocked_hint]
		)

func _apply_ai_portrait() -> void:
	var is_mason: bool = _ai.persona == AiOpponent.Persona.MASON
	var is_botanist: bool = _ai.persona == AiOpponent.Persona.BOTANIST
	var is_cheater: bool = _ai.persona == AiOpponent.Persona.CHEATER
	miner_body.visible = is_mason
	nerd_body.visible = is_botanist
	joker_body.visible = is_cheater
	enemy_hud.visible = is_mason or is_botanist or is_cheater
	enemy_name_label.text = _ai.get_display_name()
	if is_mason:
		player_2.bind_face(miner_face, TEX_MASON_NEUTRAL, TEX_MASON_SMIRK, TEX_MASON_ANGRY)
	elif is_botanist:
		player_2.bind_face(nerd_face, TEX_NERD_FACE, TEX_NERD_SMIRK, TEX_NERD_ANGRY)
	elif is_cheater:
		player_2.bind_face(
			joker_face, TEX_JOKER_FACE, TEX_JOKER_SMIRK, TEX_JOKER_RAGE, Vector2(0.0, 20.0)
		)
	else:
		player_2.clear_face()


func _on_player_1_hp_changed(current: int, maximum: int) -> void:
	_refresh_player_hp_hud(current, maximum)


func _on_player_2_hp_changed(current: int, maximum: int) -> void:
	_refresh_enemy_hp_hud(current, maximum)


func _refresh_player_hp_hud(current: int, maximum: int) -> void:
	player_hp_bar.max_value = float(maximum)
	player_hp_bar.value = float(current)
	player_hp_value.text = "%d / %d" % [current, maximum]
	if current <= 3:
		player_hp_value.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	else:
		player_hp_value.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))


func _refresh_enemy_hp_hud(current: int, maximum: int) -> void:
	enemy_hp_label.text = "HP %d/%d" % [current, maximum]
	if current <= 3:
		enemy_hp_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	else:
		enemy_hp_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))


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
	card.idle_rounds = 0
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
	if _paper_bonus_draw:
		_paper_bonus_draw = false
		_draw_permanent_card(false)
	_layout_hand()


func _age_and_auto_discard_hand() -> void:
	var doomed: Array[RuleCard] = []
	for card: RuleCard in _hand_cards():
		card.idle_rounds += 1
		if card.idle_rounds >= CARD_IDLE_DISCARD_ROUNDS:
			doomed.append(card)
	for card: RuleCard in doomed:
		if is_instance_valid(card):
			card_hand.remove_child(card)
			card.free()
	if not doomed.is_empty():
		_layout_hand()


func _clear_round_bans() -> void:
	_round_bans.clear()
	player_1.clear_banned_items()
	player_2.clear_banned_items()
	_refresh_throw_tokens()


func _add_round_ban(item: RuleEngine.Item) -> void:
	if item not in _round_bans:
		_round_bans.append(item)
	player_1.set_banned_items(_round_bans)
	player_2.set_banned_items(_round_bans)
	_refresh_throw_tokens()


func _layout_hand() -> void:
	var cards: Array[RuleCard] = _hand_cards()
	var n: int = cards.size()
	if n <= 0:
		return
	for i: int in range(n):
		var card: RuleCard = cards[i]
		card.scale = HAND_CARD_SCALE
		card.position = Vector2(HAND_X, HAND_TOP_Y + float(i) * HAND_V_SPACING)
		card.z_index = i + 1
		var drag: Draggable = card.get_node_or_null("Draggable") as Draggable
		if drag != null:
			drag.next_position = card.global_position
			drag.previous_position = card.global_position
			drag.state = Draggable.DRAGGABLE_STATE.IDLE


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
	card.scale = Vector2.ONE
	card.mark_resolved()
	_layout_hand()
	_settle_stacked_card(card, _play_stack_count - 1)


## AI plays a card: spawns it straight onto the play pile and applies it.
func _ai_play_card(kind: RuleCard.Kind) -> void:
	var card: RuleCard = CARD_SCENE.instantiate() as RuleCard
	card.kind = kind
	card_play_zone.add_child(card)
	card.mark_resolved()
	var message: String = card.apply_to(_engine)
	_ai_stack_count += 1
	card.z_index = _ai_stack_count
	card.position = AI_STACK_OFFSET + STACK_STEP * float(_ai_stack_count - 1)
	card.modulate = Color(1.0, 0.8, 0.8, 1.0)
	_set_status("%s играет карту — %s" % [_ai.get_display_name(), message])
	print("AI card: %s" % message)


func _settle_stacked_card(card: RuleCard, stack_index: int) -> void:
	if not is_instance_valid(card):
		return
	card.position = PLAYER_STACK_OFFSET + STACK_STEP * float(stack_index)
	var drag: Draggable = card.get_node_or_null("Draggable") as Draggable
	if drag != null:
		drag.next_position = card.global_position
		drag.previous_position = card.global_position
		drag.state = Draggable.DRAGGABLE_STATE.IDLE


func _ensure_enemy_throw_icons() -> void:
	_enemy_throw_icons = get_node_or_null("EnemyThrowIcons") as Node2D
	if _enemy_throw_icons != null:
		return
	_enemy_throw_icons = Node2D.new()
	_enemy_throw_icons.name = "EnemyThrowIcons"
	_enemy_throw_icons.z_index = 25
	add_child(_enemy_throw_icons)


func _clear_enemy_throw_icons() -> void:
	if _enemy_throw_icons == null:
		return
	for child: Node in _enemy_throw_icons.get_children():
		child.queue_free()


func _show_enemy_throw_icons(items: Array[RuleEngine.Item]) -> void:
	_ensure_enemy_throw_icons()
	_clear_enemy_throw_icons()
	var n: int = items.size()
	var start_x: float = ENEMY_THROW_ICON_POS.x - float(n - 1) * ENEMY_THROW_ICON_SPACING * 0.5
	for i: int in range(n):
		var icon := Sprite2D.new()
		icon.texture = TEX_THROW[items[i]] as Texture2D
		icon.scale = ENEMY_THROW_ICON_SCALE
		icon.position = Vector2(
			start_x + float(i) * ENEMY_THROW_ICON_SPACING,
			ENEMY_THROW_ICON_POS.y
		)
		_enemy_throw_icons.add_child(icon)


func _on_player_1_thrown(item: RuleEngine.Item) -> void:
	if _match_over:
		return
	_clear_enemy_throw_icons()
	_p1_item = item
	_p1_ready = true
	_refresh_throw_tokens()
	_set_status("Ты: %s — %s думает..." % [player_1.item_name(item), _ai.get_display_name()])
	_try_resolve()
	_request_ai_throw()


func _on_player_2_thrown(item: RuleEngine.Item) -> void:
	_p2_item = item
	if _p2_items.is_empty():
		_p2_items = [item]
	_p2_ready = true
	_show_enemy_throw_icons(_p2_items)
	_set_status("%s: %s" % [_ai.get_display_name(), _format_ai_items()])
	_try_resolve()


func _format_ai_items() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: RuleEngine.Item in _p2_items:
		parts.append(player_2.item_name(item))
	return " + ".join(parts)


func _show_cheater_distraction(line: String) -> void:
	_ensure_cheater_bubble()
	cheater_bubble_label.text = line
	cheater_bubble.visible = true
	player_2.flash_smirk()


func _hide_cheater_bubble() -> void:
	if cheater_bubble != null:
		cheater_bubble.visible = false


func _request_ai_throw() -> void:
	if _p2_ready or _ai_thinking or player_2.has_thrown or _match_over:
		return
	_ai_thinking = true
	player_2.choice_label.text = "%s думает..." % _ai.get_display_name()
	if _resolving or player_2.has_thrown or _match_over:
		_ai_thinking = false
		return
	var ai_card: int = _ai.pick_card_for_round(_round_index)
	if ai_card >= 0:
		_ai_play_card(ai_card as RuleCard.Kind)
		if _resolving or player_2.has_thrown or _match_over:
			_ai_thinking = false
			return
	var items: Array[RuleEngine.Item] = _ai.choose_items(_engine, _round_bans)
	_p2_items = items
	_p2_item = items[0]
	if _ai.ignored_ban and not _ai.last_taunt.is_empty():
		player_2.take_damage(1)
		_show_cheater_distraction(_ai.last_taunt)
		_set_status(
			"%s: «%s» (−1 HP за игнор бана, осталось %d)"
			% [_ai.get_display_name(), _ai.last_taunt, player_2.hp]
		)
		if _match_over:
			_ai_thinking = false
			return
		if not player_2.is_alive():
			_ai_thinking = false
			_end_match()
			return
		if _resolving or player_2.has_thrown:
			_ai_thinking = false
			return
	player_2.choice_label.text = "THROWN: %s" % _format_ai_items()
	_show_enemy_throw_icons(_p2_items)
	# Bypass Player.pick bans when Шулер ignores the prohibition.
	player_2.force_throw(_p2_item)
	_ai_thinking = false


func _try_resolve() -> void:
	if _resolving or not _p1_ready or not _p2_ready or _match_over:
		return
	_resolving = true
	if _p2_items.is_empty():
		_p2_items = [_p2_item]

	var left: String = player_1.item_name(_p1_item)
	var right: String = _format_ai_items()
	var notes: PackedStringArray = PackedStringArray()

	# Prediction: correct if any AI item matches the bet.
	var predicted_right: bool = false
	if _prediction >= 0:
		for ai_item: RuleEngine.Item in _p2_items:
			if _prediction == (ai_item as int):
				predicted_right = true
				break
	var predicted_wrong: bool = _prediction >= 0 and not predicted_right
	_prediction = -1

	for ai_item: RuleEngine.Item in _p2_items:
		_stats.record_round(_p1_item, ai_item, _engine.resolve(_p1_item, ai_item))

	var dual: Dictionary = CheaterDualResolve.evaluate(_engine, _p1_item, _p2_items)
	var result: int = int(dual["result"])
	var dmg_to_p1: int = int(dual["dmg_to_p1"])
	var dmg_to_p2: int = int(dual["dmg_to_p2"])
	var winning_p1_vs: Array[RuleEngine.Item] = []
	var winning_p2_items: Array[RuleEngine.Item] = []
	for v: Variant in dual["winning_p1_vs"] as Array:
		winning_p1_vs.append(v as RuleEngine.Item)
	for v: Variant in dual["winning_p2_items"] as Array:
		winning_p2_items.append(v as RuleEngine.Item)

	# Apply rock block on each winning hit (evaluate stores raw edge damage).
	if result == 1:
		dmg_to_p2 = 0
		for beaten: RuleEngine.Item in winning_p1_vs:
			var hit: int = _engine.get_damage(_p1_item, beaten)
			hit = _apply_rock_block(beaten, hit, notes, player_2.item_name(beaten))
			dmg_to_p2 += hit
	elif result == -1:
		dmg_to_p1 = 0
		for winner_item: RuleEngine.Item in winning_p2_items:
			var hit: int = _engine.get_damage(winner_item, _p1_item)
			hit = _apply_rock_block(_p1_item, hit, notes, left)
			dmg_to_p1 += hit

	match result:
		1:
			var bonus: int = _p1_win_streak
			dmg_to_p2 += bonus
			if predicted_right:
				dmg_to_p2 *= 2
				notes.append("ставка ×2")
			if _p2_items.size() > 1:
				notes.append("против 2 предметов")
			player_2.take_damage(dmg_to_p2)
			for beaten: RuleEngine.Item in winning_p1_vs:
				_apply_win_perks(player_1, player_2, _p1_item, beaten, notes, true)
			_p1_win_streak += 1
			_p2_win_streak = 0
			_tie_streak = 0
			_set_status(
				"%s бьёт %s (−%d%s) — ты победил! %s: %d HP%s"
				% [
					left, right, dmg_to_p2,
					(" +%d стрик" % bonus) if bonus > 0 else "",
					_ai.get_display_name(), player_2.hp, _join_notes(notes),
				]
			)
		-1:
			var bonus: int = _p2_win_streak
			dmg_to_p1 += bonus
			if _p2_items.size() > 1:
				notes.append("двойной ход")
			player_1.take_damage(dmg_to_p1)
			player_2.flash_smirk()
			for winner_item: RuleEngine.Item in winning_p2_items:
				_apply_win_perks(player_2, player_1, winner_item, _p1_item, notes, false)
			_p2_win_streak += 1
			_p1_win_streak = 0
			_tie_streak = 0
			_set_status(
				"%s бьёт %s (−%d%s) — %s победил! Ты: %d HP%s"
				% [
					right, left, dmg_to_p1,
					(" +%d стрик" % bonus) if bonus > 0 else "",
					_ai.get_display_name(), player_1.hp, _join_notes(notes),
				]
			)
		_:
			# Overall tie (equal pair wins, or all ties): only tie damage, once.
			_p1_win_streak = 0
			_p2_win_streak = 0
			_tie_streak += 1
			var sudden: bool = _tie_streak >= 2
			dmg_to_p1 = 1
			dmg_to_p2 = 1
			# Mutual arrows vs a single AI item → use that edge damage once.
			if _p2_items.size() == 1:
				var only: RuleEngine.Item = _p2_items[0]
				if (
					_p1_item != only
					and _engine.has_beat(_p1_item, only)
					and _engine.has_beat(only, _p1_item)
				):
					dmg_to_p2 = _engine.get_damage(_p1_item, only)
					dmg_to_p1 = _engine.get_damage(only, _p1_item)
			if _p1_item == RuleEngine.Item.SPOCK:
				dmg_to_p1 = maxi(0, dmg_to_p1 - 1)
				dmg_to_p2 += 1
				notes.append("твой Спок: −1 себе, +1 врагу")
			for ai_item: RuleEngine.Item in _p2_items:
				if ai_item == RuleEngine.Item.SPOCK:
					dmg_to_p2 = maxi(0, dmg_to_p2 - 1)
					dmg_to_p1 += 1
					notes.append("Спок врага: −1 ему, +1 тебе")
					break
			if sudden:
				dmg_to_p1 += 1
				dmg_to_p2 += 1
				notes.append("внезапная смерть +1")
			if predicted_right:
				dmg_to_p2 *= 2
				notes.append("ставка ×2")
			player_1.take_damage(dmg_to_p1)
			player_2.take_damage(dmg_to_p2)
			if sudden:
				_set_status(
					"ВНЕЗАПНАЯ СМЕРТЬ! Ничья ×%d — оба −%d/−%d%s"
					% [_tie_streak, dmg_to_p2, dmg_to_p1, _join_notes(notes)]
				)
			else:
				_set_status(
					"%s vs %s — ничья, −%d тебе / −%d врагу%s"
					% [left, right, dmg_to_p1, dmg_to_p2, _join_notes(notes)]
				)

	if predicted_wrong:
		player_1.take_damage(1)
		status_label.text += "  | ставка не сыграла: −1 HP"

	print(
		"Round: %s vs %s -> %d | HP %d vs %d | streaks W%d/%d T%d"
		% [left, right, result, player_1.hp, player_2.hp, _p1_win_streak, _p2_win_streak, _tie_streak]
	)
	_hide_cheater_bubble()
	if not player_1.is_alive() or not player_2.is_alive():
		_end_match()
		return
	_reset_round(result == 1)


## Rock: on loss blocks 1 damage, but never below 1.
func _apply_rock_block(
	loser_item: RuleEngine.Item, dmg: int, notes: PackedStringArray, loser_name: String
) -> int:
	if loser_item == RuleEngine.Item.ROCK and dmg > 1:
		notes.append("%s блокирует 1" % loser_name)
		return dmg - 1
	return dmg


## Winner perks: Lizard heals, Scissors cut an enemy arrow, Paper draws (player only).
func _apply_win_perks(
	winner: Player,
	_loser: Player,
	winner_item: RuleEngine.Item,
	loser_item: RuleEngine.Item,
	notes: PackedStringArray,
	winner_is_player: bool
) -> void:
	match winner_item:
		RuleEngine.Item.LIZARD:
			winner.heal(1)
			notes.append("ящерица лечит +1")
		RuleEngine.Item.SCISSORS:
			var cut: int = _engine.remove_random_beat_from(loser_item)
			if cut >= 0:
				notes.append(
					"ножницы срезали стрелку %s→%s"
					% [_engine.item_name(loser_item), _engine.item_name(cut as RuleEngine.Item)]
				)
		RuleEngine.Item.PAPER:
			if winner_is_player:
				_paper_bonus_draw = true
				notes.append("бумага: +1 карта")
		_:
			pass


func _join_notes(notes: PackedStringArray) -> String:
	if notes.is_empty():
		return ""
	return "  [" + " · ".join(notes) + "]"


func _end_match() -> void:
	_match_over = true
	player_1.input_enabled = false
	_resolving = false
	_ai_thinking = false
	_refresh_throw_tokens()
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
			"Победа над %s! Открыт: %s. Стартуем..."
			% [previous_name, _campaign.name_for_tier(_campaign.current_tier)]
		)
		_start_match(_campaign.current_tier, false)
	elif _campaign.current_tier >= AiCampaign.MAX_TIER:
		_set_status("Победа над %s! Кампания пройдена. R = реванш" % previous_name)
	else:
		_set_status(
			"Победа над %s! Дальше: %s. Стартуем..."
			% [previous_name, _campaign.name_for_tier(_campaign.current_tier)]
		)
		_start_match(_campaign.current_tier, false)


func _reset_round(player_won: bool = false) -> void:
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	_ai_thinking = false
	_p2_items.clear()
	_hide_cheater_bubble()
	_clear_round_bans()
	_round_index += 1
	_prediction = -1
	player_1.reset_round()
	player_2.reset_round()
	_age_and_auto_discard_hand()
	_grant_end_of_turn_cards(player_won)
	_ai.prepare_round(_engine)
	_refresh_throw_tokens()
	_set_status(
		"Раунд %d vs %s — кинь предмет во врага или сыграй карту! (карт: %d/%d | стрик W %d/%d · ничьи %d)"
		% [
			_round_index + 1,
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
