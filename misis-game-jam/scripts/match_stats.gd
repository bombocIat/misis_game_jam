class_name MatchStats
extends RefCounted
## Per-item throw/win counters for RPSLS. Win rate = wins / throws.

signal changed

var throws: Dictionary = {}
var wins: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	throws.clear()
	wins.clear()
	for item: int in RuleEngine.Item.values():
		throws[item] = 0
		wins[item] = 0
	changed.emit()


func record_round(a: RuleEngine.Item, b: RuleEngine.Item, result: int) -> void:
	throws[a] = int(throws[a]) + 1
	throws[b] = int(throws[b]) + 1
	if result == 1:
		wins[a] = int(wins[a]) + 1
	elif result == -1:
		wins[b] = int(wins[b]) + 1
	changed.emit()


func get_throws(item: RuleEngine.Item) -> int:
	return int(throws.get(item, 0))


func get_wins(item: RuleEngine.Item) -> int:
	return int(wins.get(item, 0))


## Wins / throws. Returns 0.0 when never thrown.
func win_rate(item: RuleEngine.Item) -> float:
	var t: int = get_throws(item)
	if t <= 0:
		return 0.0
	return float(get_wins(item)) / float(t)


func win_rate_percent(item: RuleEngine.Item) -> int:
	return int(round(win_rate(item) * 100.0))
