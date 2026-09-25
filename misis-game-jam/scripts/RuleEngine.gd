class_name RuleEngine
extends RefCounted
## Pure RPSLS schema + resolve. RefCounted: no scene tree, cheap to spawn in tests / systems.

enum Item { ROCK, SCISSORS, PAPER, LIZARD, SPOCK }

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
	var a_targets: Array = beats.get(a, []) as Array
	if b in a_targets:
		return 1
	var b_targets: Array = beats.get(b, []) as Array
	if a in b_targets:
		return -1
	return 0


func set_beats(a: Item, targets: Array) -> void:
	var typed: Array[Item] = []
	for target: Variant in targets:
		typed.append(target as Item)
	beats[a] = typed


func get_beats(a: Item) -> Array:
	var raw: Array = beats.get(a, []) as Array
	return raw.duplicate()
