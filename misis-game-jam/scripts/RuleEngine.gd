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


func resolve(a: Item, b: Item) -> int:
	if a == b:
		return 0
	var a_beats_b: bool = b in (beats.get(a, []) as Array)
	var b_beats_a: bool = a in (beats.get(b, []) as Array)
	# Mutual arrows (white double) = both die / tie, not a one-sided win.
	if a_beats_b and b_beats_a:
		return 0
	if a_beats_b:
		return 1
	if b_beats_a:
		return -1
	return 0


func set_beats(a: Item, targets: Array) -> void:
	var typed: Array[Item] = []
	for target: Variant in targets:
		typed.append(target as Item)
	beats[a] = typed
	beats_changed.emit()


func get_beats(a: Item) -> Array:
	var raw: Array = beats.get(a, []) as Array
	return raw.duplicate()


func has_beat(a: Item, b: Item) -> bool:
	return b in get_beats(a)


func add_beat(a: Item, b: Item) -> void:
	if a == b:
		return
	var targets: Array = get_beats(a)
	if b in targets:
		return
	targets.append(b)
	set_beats(a, targets)


## Flip one random existing arrow A→B into B→A. Returns true if flipped.
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
	var from_list: Array = get_beats(a)
	from_list.erase(b)
	beats[a] = from_list
	var to_list: Array = get_beats(b)
	if a not in to_list:
		to_list.append(a)
	beats[b] = to_list
	beats_changed.emit()
	return true


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
