class_name RuleEngine
extends RefCounted
## Pure RPSLS schema + resolve. RefCounted: no scene tree, cheap to spawn in tests / systems.

signal beats_changed

enum Item { ROCK, SCISSORS, PAPER, LIZARD, SPOCK }

const ALL_ITEMS: Array[Item] = [
	Item.ROCK,
	Item.SCISSORS,
	Item.PAPER,
	Item.LIZARD,
	Item.SPOCK,
]

## Item -> Array[Item]: who this item beats (mutable via set_beats / cards).
var beats: Dictionary = {
	Item.ROCK: [Item.SCISSORS, Item.LIZARD],
	Item.SCISSORS: [Item.PAPER, Item.LIZARD],
	Item.PAPER: [Item.ROCK, Item.SPOCK],
	Item.LIZARD: [Item.PAPER, Item.SPOCK],
	Item.SPOCK: [Item.ROCK, Item.SCISSORS],
}

## Directed edge power A→B. Same card twice stacks damage (default 1).
var beat_power: Dictionary = {}


func _init() -> void:
	_init_default_powers()


func _init_default_powers() -> void:
	beat_power.clear()
	for a: Item in ALL_ITEMS:
		for b: Variant in get_beats(a):
			beat_power[_edge_key(a, b as Item)] = 1


func _edge_key(a: Item, b: Item) -> String:
	return "%d>%d" % [a as int, b as int]


func resolve(a: Item, b: Item) -> int:
	if a == b:
		return 0
	var a_beats_b: bool = has_beat(a, b)
	var b_beats_a: bool = has_beat(b, a)
	# Mutual arrows (white double) = both die / tie, not a one-sided win.
	if a_beats_b and b_beats_a:
		return 0
	if a_beats_b:
		return 1
	if b_beats_a:
		return -1
	return 0


## Damage dealt when attacker beats defender via that arrow.
func get_damage(attacker: Item, defender: Item) -> int:
	if not has_beat(attacker, defender):
		return 0
	return int(beat_power.get(_edge_key(attacker, defender), 1))


func set_beats(a: Item, targets: Array) -> void:
	var typed: Array[Item] = []
	for target: Variant in targets:
		typed.append(target as Item)
	# Drop powers for removed edges from a.
	var old: Array = get_beats(a)
	for old_b: Variant in old:
		if typed.find(old_b as Item) < 0:
			beat_power.erase(_edge_key(a, old_b as Item))
	beats[a] = typed
	for b: Item in typed:
		var key: String = _edge_key(a, b)
		if not beat_power.has(key):
			beat_power[key] = 1
	beats_changed.emit()


func get_beats(a: Item) -> Array:
	var raw: Array = beats.get(a, []) as Array
	return raw.duplicate()


func has_beat(a: Item, b: Item) -> bool:
	return b in get_beats(a)


## Add edge or stack its power if it already exists. Returns new power.
func add_beat(a: Item, b: Item) -> int:
	if a == b:
		return 0
	var targets: Array = get_beats(a)
	var key: String = _edge_key(a, b)
	if b in targets:
		beat_power[key] = get_damage(a, b) + 1
		beats_changed.emit()
		return int(beat_power[key])
	targets.append(b)
	beats[a] = targets
	beat_power[key] = 1
	beats_changed.emit()
	return 1


## Flip one random existing arrow A→B into B→A (power moves with it).
func flip_random_arrow() -> bool:
	var edges: Array[Vector2i] = []
	for a: Item in ALL_ITEMS:
		for b: Variant in get_beats(a):
			edges.append(Vector2i(a as int, b as int))
	if edges.is_empty():
		return false
	var edge: Vector2i = edges[randi() % edges.size()]
	var a: Item = edge.x as Item
	var b: Item = edge.y as Item
	var power: int = get_damage(a, b)
	var from_list: Array = get_beats(a)
	from_list.erase(b)
	beats[a] = from_list
	beat_power.erase(_edge_key(a, b))
	var to_list: Array = get_beats(b)
	if a not in to_list:
		to_list.append(a)
	beats[b] = to_list
	var reverse_key: String = _edge_key(b, a)
	beat_power[reverse_key] = int(beat_power.get(reverse_key, 0)) + maxi(power, 1)
	beats_changed.emit()
	return true


## Remove one random outgoing arrow from `item`. Returns removed target or -1.
func remove_random_beat_from(item: Item) -> int:
	var targets: Array = get_beats(item)
	if targets.is_empty():
		return -1
	var victim: Item = targets[randi() % targets.size()] as Item
	targets.erase(victim)
	beats[item] = targets
	beat_power.erase(_edge_key(item, victim))
	beats_changed.emit()
	return victim as int


func item_name(item: Item) -> String:
	match item:
		Item.ROCK:
			return "Камень"
		Item.SCISSORS:
			return "Ножницы"
		Item.PAPER:
			return "Бумага"
		Item.LIZARD:
			return "Ящерица"
		Item.SPOCK:
			return "Спок"
		_:
			return "?"
