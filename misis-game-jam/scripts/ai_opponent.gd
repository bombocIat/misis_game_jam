class_name AiOpponent
extends RefCounted
## Campaign personas: Каменщик, Ботаник, Шулер.


enum Persona { MASON, BOTANIST, CHEATER }

const ITEMS: Array[RuleEngine.Item] = [
	RuleEngine.Item.ROCK,
	RuleEngine.Item.SCISSORS,
	RuleEngine.Item.PAPER,
	RuleEngine.Item.LIZARD,
	RuleEngine.Item.SPOCK,
]

const PERSONA_NAMES: Dictionary = {
	Persona.MASON: "Каменщик",
	Persona.BOTANIST: "Ботаник",
	Persona.CHEATER: "Шулер",
}

## Каменщик: rock chance never below this.
const MASON_ROCK_FLOOR := 0.5

## Шулер: phrase → actual throw (legacy single-item bluffs; dual uses distractions).
const CHEATER_BLUFFS: Array[Dictionary] = [
	{"line": "Я боюсь рептилий...", "play": RuleEngine.Item.ROCK},
	{"line": "Сегодня будет камнепад!", "play": RuleEngine.Item.SPOCK},
	{"line": "Бумага всё стерпит...", "play": RuleEngine.Item.SCISSORS},
	{"line": "Ножницы совсем затупились.", "play": RuleEngine.Item.PAPER},
	{"line": "Спок сегодня не в духе.", "play": RuleEngine.Item.LIZARD},
	{"line": "Камень — мой талисман!", "play": RuleEngine.Item.PAPER},
	{"line": "Ящериц точно не будет.", "play": RuleEngine.Item.LIZARD},
	{"line": "Только не бумага, прошу...", "play": RuleEngine.Item.PAPER},
	{"line": "Режу всё подряд!", "play": RuleEngine.Item.ROCK},
	{"line": "Вулканский разум подсказывает...", "play": RuleEngine.Item.SCISSORS},
]

## Шулер: отвлекает, когда игнорирует бан хода.
const CHEATER_DISTRACTIONS: PackedStringArray = [
	"Смотри, птичка",
	"Эй, сзади",
	"у тебя шнурок развязался",
]
const CHEATER_BAN_IGNORE_CHANCE := 0.33

## Cards each persona may play (every AI_CARD_EVERY rounds).
const PERSONA_CARDS: Dictionary = {
	Persona.MASON: [
		RuleCard.Kind.COOL_ROCK,
		RuleCard.Kind.SANDSTORM,
		RuleCard.Kind.EQUALIZER,
	],
	Persona.BOTANIST: [
		RuleCard.Kind.DRAGON,
		RuleCard.Kind.VULCAN,
		RuleCard.Kind.MIND_MELD,
		RuleCard.Kind.PAPER_PLANE,
	],
	Persona.CHEATER: [
		RuleCard.Kind.WIND,
		RuleCard.Kind.CHAOS,
		RuleCard.Kind.HOMEWORK,
	],
}
const AI_CARD_EVERY := 2

var persona: Persona = Persona.MASON
## Last taunt / distraction line (empty when unused).
var last_taunt: String = ""
## Шулер ignored a round ban this throw.
var ignored_ban: bool = false
## Botanist: items avoided this round (frozen at round start, before cards).
var _round_avoid: Array[RuleEngine.Item] = []
## Win-counts snapshot at round start (used by botanist weights).
var _round_win_counts: Dictionary = {}


func get_display_name() -> String:
	return str(PERSONA_NAMES.get(persona, "AI"))


## Call at the start of each round, before the player plays cards.
func prepare_round(engine: RuleEngine) -> void:
	_round_win_counts = _count_wins(engine)
	_round_avoid.clear()
	if persona == Persona.BOTANIST:
		_round_avoid = _lowest_from_counts(_round_win_counts, 2)


## Returns a card kind to play this round, or -1 if the AI passes.
func pick_card_for_round(round_index: int) -> int:
	if round_index <= 0 or round_index % AI_CARD_EVERY != 0:
		return -1
	var pool: Array = PERSONA_CARDS.get(persona, []) as Array
	if pool.is_empty():
		return -1
	return int(pool[randi() % pool.size()])


## One or more items for this throw. Шулер always returns two when possible.
func choose_items(
	engine: RuleEngine, round_bans: Array[RuleEngine.Item] = []
) -> Array[RuleEngine.Item]:
	last_taunt = ""
	ignored_ban = false
	if persona == Persona.CHEATER:
		return _choose_cheater_dual(engine, round_bans)
	var single: Array[RuleEngine.Item] = [choose_item(engine, round_bans)]
	return single


func choose_item(
	engine: RuleEngine, round_bans: Array[RuleEngine.Item] = []
) -> RuleEngine.Item:
	last_taunt = ""
	ignored_ban = false
	match persona:
		Persona.MASON:
			return _choose_mason(engine, round_bans)
		Persona.BOTANIST:
			var banned: Array[RuleEngine.Item] = _round_avoid.duplicate()
			for item: RuleEngine.Item in round_bans:
				if item not in banned:
					banned.append(item)
			return _choose_weighted_from_counts(_round_win_counts, banned)
		Persona.CHEATER:
			var dual: Array[RuleEngine.Item] = _choose_cheater_dual(engine, round_bans)
			return dual[0]
		_:
			return _choose_weighted(engine, round_bans)


func _choose_cheater_dual(
	engine: RuleEngine, round_bans: Array[RuleEngine.Item]
) -> Array[RuleEngine.Item]:
	var effective_bans: Array[RuleEngine.Item] = round_bans.duplicate()
	if not round_bans.is_empty() and randf() < CHEATER_BAN_IGNORE_CHANCE:
		ignored_ban = true
		effective_bans.clear()
		last_taunt = CHEATER_DISTRACTIONS[randi() % CHEATER_DISTRACTIONS.size()]

	var first: RuleEngine.Item = _choose_weighted(engine, effective_bans)
	var second_bans: Array[RuleEngine.Item] = effective_bans.duplicate()
	if first not in second_bans:
		second_bans.append(first)
	var second: RuleEngine.Item = _choose_weighted(engine, second_bans)
	var result: Array[RuleEngine.Item] = [first]
	if second != first:
		result.append(second)
	else:
		# Fallback: any other allowed item so Шулер still plays two when possible.
		for item: RuleEngine.Item in ITEMS:
			if item == first or item in effective_bans:
				continue
			result.append(item)
			break
	return result


func _choose_mason(
	engine: RuleEngine, banned: Array[RuleEngine.Item]
) -> RuleEngine.Item:
	if RuleEngine.Item.ROCK in banned:
		return _choose_weighted(engine, banned)

	var win_counts: Dictionary = _count_wins(engine)
	var rock_w: float = maxf(float(win_counts[RuleEngine.Item.ROCK]), 0.05)
	var other_choices: Array[RuleEngine.Item] = []
	var other_weights: Array[float] = []
	var other_total: float = 0.0
	for item: RuleEngine.Item in ITEMS:
		if item == RuleEngine.Item.ROCK or item in banned:
			continue
		var w: float = maxf(float(win_counts[item]), 0.05)
		other_choices.append(item)
		other_weights.append(w)
		other_total += w

	var total: float = rock_w + other_total
	var rock_p: float = rock_w / total if total > 0.0 else MASON_ROCK_FLOOR
	rock_p = maxf(rock_p, MASON_ROCK_FLOOR)

	if other_choices.is_empty() or randf() < rock_p:
		return RuleEngine.Item.ROCK
	return _roll_weighted(other_choices, other_weights)


func _choose_cheater(banned: Array[RuleEngine.Item]) -> RuleEngine.Item:
	var pool: Array[Dictionary] = []
	for bluff: Dictionary in CHEATER_BLUFFS:
		var play: RuleEngine.Item = bluff["play"] as RuleEngine.Item
		if play not in banned:
			pool.append(bluff)
	if pool.is_empty():
		return _choose_uniform(banned)
	var pick: Dictionary = pool[randi() % pool.size()]
	last_taunt = str(pick["line"])
	return pick["play"] as RuleEngine.Item


func _choose_uniform(banned: Array[RuleEngine.Item]) -> RuleEngine.Item:
	var allowed: Array[RuleEngine.Item] = []
	for item: RuleEngine.Item in ITEMS:
		if item not in banned:
			allowed.append(item)
	if allowed.is_empty():
		return ITEMS[randi() % ITEMS.size()]
	return allowed[randi() % allowed.size()]


func _choose_weighted(
	engine: RuleEngine, banned: Array[RuleEngine.Item]
) -> RuleEngine.Item:
	return _choose_weighted_from_counts(_count_wins(engine), banned)


func _choose_weighted_from_counts(
	win_counts: Dictionary, banned: Array[RuleEngine.Item]
) -> RuleEngine.Item:
	var choices: Array[RuleEngine.Item] = []
	var weights: Array[float] = []
	for item: RuleEngine.Item in ITEMS:
		if item in banned:
			continue
		choices.append(item)
		weights.append(maxf(float(win_counts.get(item, 0)), 0.05))
	if choices.is_empty():
		return ITEMS[randi() % ITEMS.size()]
	return _roll_weighted(choices, weights)


func _roll_weighted(choices: Array[RuleEngine.Item], weights: Array[float]) -> RuleEngine.Item:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return choices[randi() % choices.size()]
	var roll: float = randf() * total
	var cursor: float = 0.0
	for i: int in range(choices.size()):
		cursor += weights[i]
		if roll <= cursor:
			return choices[i]
	return choices[choices.size() - 1]


func _lowest_from_counts(win_counts: Dictionary, count: int) -> Array[RuleEngine.Item]:
	var ranked: Array[RuleEngine.Item] = ITEMS.duplicate()
	ranked.sort_custom(
		func(a: RuleEngine.Item, b: RuleEngine.Item) -> bool:
			return int(win_counts.get(a, 0)) < int(win_counts.get(b, 0))
	)
	var banned: Array[RuleEngine.Item] = []
	var n: int = mini(count, ranked.size())
	for i: int in range(n):
		banned.append(ranked[i])
	return banned


func _count_wins(engine: RuleEngine) -> Dictionary:
	var win_counts: Dictionary = {}
	for item: RuleEngine.Item in ITEMS:
		win_counts[item] = 0
	for a: RuleEngine.Item in ITEMS:
		for b: RuleEngine.Item in ITEMS:
			if engine.resolve(a, b) == 1:
				win_counts[a] = int(win_counts[a]) + 1
	return win_counts
