class_name AiOpponent
extends RefCounted
## Weighted RPSLS AI with campaign personas.


enum Persona { CHAOTIC, MASON, BOTANIST }

const ITEMS: Array[RuleEngine.Item] = [
	RuleEngine.Item.ROCK,
	RuleEngine.Item.SCISSORS,
	RuleEngine.Item.PAPER,
	RuleEngine.Item.LIZARD,
	RuleEngine.Item.SPOCK,
]

const PERSONA_NAMES: Dictionary = {
	Persona.CHAOTIC: "Хаотик",
	Persona.MASON: "Каменщик",
	Persona.BOTANIST: "Ботаник",
}

## Rock weight multiplier for Каменщик (+15% chance mass via weight).
const MASON_ROCK_MULT := 1.15

var persona: Persona = Persona.CHAOTIC


func get_display_name() -> String:
	return str(PERSONA_NAMES.get(persona, "AI"))


func choose_item(engine: RuleEngine) -> RuleEngine.Item:
	match persona:
		Persona.CHAOTIC:
			return ITEMS[randi() % ITEMS.size()]
		Persona.MASON:
			return _choose_weighted(engine, true, [])
		Persona.BOTANIST:
			return _choose_weighted(engine, false, _lowest_win_items(engine, 2))
		_:
			return _choose_weighted(engine, false, [])


func _choose_weighted(
	engine: RuleEngine,
	boost_rock: bool,
	banned: Array[RuleEngine.Item]
) -> RuleEngine.Item:
	var win_counts: Dictionary = _count_wins(engine)
	var total: float = 0.0
	var weights: Array[float] = []
	var choices: Array[RuleEngine.Item] = []
	for item: RuleEngine.Item in ITEMS:
		if item in banned:
			continue
		var w: float = float(win_counts[item])
		if boost_rock and item == RuleEngine.Item.ROCK:
			w *= MASON_ROCK_MULT
		# Keep a tiny floor so zero-win items can still appear unless banned.
		w = maxf(w, 0.05)
		choices.append(item)
		weights.append(w)
		total += w

	if choices.is_empty():
		return ITEMS[randi() % ITEMS.size()]
	if total <= 0.0:
		return choices[randi() % choices.size()]

	var roll: float = randf() * total
	var cursor: float = 0.0
	for i: int in range(choices.size()):
		cursor += weights[i]
		if roll <= cursor:
			return choices[i]
	return choices[choices.size() - 1]


## Items with the lowest theoretical win-counts (from current beat graph).
func _lowest_win_items(engine: RuleEngine, count: int) -> Array[RuleEngine.Item]:
	var win_counts: Dictionary = _count_wins(engine)
	var ranked: Array[RuleEngine.Item] = ITEMS.duplicate()
	ranked.sort_custom(
		func(a: RuleEngine.Item, b: RuleEngine.Item) -> bool:
			return int(win_counts[a]) < int(win_counts[b])
	)
	var banned: Array[RuleEngine.Item] = []
	var n: int = mini(count, ranked.size())
	for i: int in range(n):
		banned.append(ranked[i])
	return banned


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
