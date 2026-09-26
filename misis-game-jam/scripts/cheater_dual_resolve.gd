class_name CheaterDualResolve
extends RefCounted
## Pure outcome for Шулер dual throw: any tie → round tie; else compare pair wins.


## result: 1 player wins, -1 AI wins, 0 tie
## Also returns per-side won-pair damage (before streaks / prediction).
static func evaluate(
	engine: RuleEngine,
	p1_item: RuleEngine.Item,
	p2_items: Array[RuleEngine.Item]
) -> Dictionary:
	var wins_p1: int = 0
	var wins_p2: int = 0
	var any_tie: bool = false
	var dmg_to_p1: int = 0
	var dmg_to_p2: int = 0
	var winning_p1_vs: Array[RuleEngine.Item] = []
	var winning_p2_items: Array[RuleEngine.Item] = []

	for ai_item: RuleEngine.Item in p2_items:
		var pair: int = engine.resolve(p1_item, ai_item)
		match pair:
			1:
				wins_p1 += 1
				dmg_to_p2 += engine.get_damage(p1_item, ai_item)
				winning_p1_vs.append(ai_item)
			-1:
				wins_p2 += 1
				dmg_to_p1 += engine.get_damage(ai_item, p1_item)
				winning_p2_items.append(ai_item)
			_:
				any_tie = true

	var result: int = 0
	if any_tie:
		result = 0
		dmg_to_p1 = 0
		dmg_to_p2 = 0
		winning_p1_vs.clear()
		winning_p2_items.clear()
	elif wins_p1 > wins_p2:
		result = 1
	elif wins_p2 > wins_p1:
		result = -1
	else:
		result = 0
		dmg_to_p1 = 0
		dmg_to_p2 = 0

	return {
		"result": result,
		"any_tie": any_tie,
		"wins_p1": wins_p1,
		"wins_p2": wins_p2,
		"dmg_to_p1": dmg_to_p1,
		"dmg_to_p2": dmg_to_p2,
		"winning_p1_vs": winning_p1_vs,
		"winning_p2_items": winning_p2_items,
	}
