class_name AiOpponent
extends RefCounted
## Before each throw: scan all 25 RPSLS pairs via RuleEngine.
## Weight = how many times that item wins; higher wins → higher chance.


const ITEMS: Array[RuleEngine.Item] = [
	RuleEngine.Item.ROCK,
	RuleEngine.Item.SCISSORS,
	RuleEngine.Item.PAPER,
	RuleEngine.Item.LIZARD,
	RuleEngine.Item.SPOCK,
]


func choose_item(engine: RuleEngine) -> RuleEngine.Item:
	var win_counts: Dictionary = _count_wins(engine)
	var total: float = 0.0
	var weights: Array[float] = []
	for item: RuleEngine.Item in ITEMS:
		var w: float = float(win_counts[item])
		weights.append(w)
		total += w

	if total <= 0.0:
		return ITEMS[randi() % ITEMS.size()]

	var roll: float = randf() * total
	var cursor: float = 0.0
	for i: int in range(ITEMS.size()):
		cursor += weights[i]
		if roll <= cursor:
			return ITEMS[i]
	return ITEMS[ITEMS.size() - 1]


## For each item A: wins among all 25 pairs where A is the thrown side (resolve(A, B) == 1).
func _count_wins(engine: RuleEngine) -> Dictionary:
	var win_counts: Dictionary = {}
	for item: RuleEngine.Item in ITEMS:
		win_counts[item] = 0
	for a: RuleEngine.Item in ITEMS:
		for b: RuleEngine.Item in ITEMS:
			if engine.resolve(a, b) == 1:
				win_counts[a] = int(win_counts[a]) + 1
	return win_counts
