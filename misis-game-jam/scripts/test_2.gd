extends Node2D
## Hotseat duel: two Players throw RPSLS items, RuleEngine resolves.


@onready var player_1: Player = %Player1
@onready var player_2: Player = %Player2
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel

var _engine: RuleEngine = RuleEngine.new()
var _p1_ready: bool = false
var _p2_ready: bool = false
var _p1_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _p2_item: RuleEngine.Item = RuleEngine.Item.ROCK
var _resolving: bool = false


func _ready() -> void:
	player_1.thrown.connect(_on_player_1_thrown)
	player_2.thrown.connect(_on_player_2_thrown)
	hint_label.text = (
		"P1: 1 Rock  2 Scissors  3 Paper  4 Lizard  5 Spock  |  Space = throw\n"
		+ "P2: 6 Rock  7 Scissors  8 Paper  9 Lizard  0 Spock  |  Enter = throw"
	)
	_set_status("Pick items, then throw!")


func _on_player_1_thrown(item: RuleEngine.Item) -> void:
	_p1_item = item
	_p1_ready = true
	_set_status("P1 threw %s — waiting for P2..." % player_1.item_name(item))
	_try_resolve()


func _on_player_2_thrown(item: RuleEngine.Item) -> void:
	_p2_item = item
	_p2_ready = true
	_set_status("P2 threw %s — waiting for P1..." % player_2.item_name(item))
	_try_resolve()


func _try_resolve() -> void:
	if _resolving or not _p1_ready or not _p2_ready:
		return
	_resolving = true
	var result: int = _engine.resolve(_p1_item, _p2_item)
	var left: String = player_1.item_name(_p1_item)
	var right: String = player_2.item_name(_p2_item)
	match result:
		1:
			_set_status("%s beats %s — %s wins!" % [left, right, player_1.player_name])
		-1:
			_set_status("%s beats %s — %s wins!" % [right, left, player_2.player_name])
		_:
			_set_status("%s vs %s — TIE!" % [left, right])
	print("Round: %s vs %s -> %d" % [left, right, result])
	await get_tree().create_timer(2.0).timeout
	_reset_round()


func _reset_round() -> void:
	_p1_ready = false
	_p2_ready = false
	_resolving = false
	player_1.reset_round()
	player_2.reset_round()
	_set_status("Next round — pick and throw!")


func _set_status(text: String) -> void:
	status_label.text = text
