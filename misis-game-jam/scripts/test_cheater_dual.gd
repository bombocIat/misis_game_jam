extends Node
## Exhaustive + behavioral tests for Шулер dual-throw algorithm.


const NAMES: Dictionary = {
	RuleEngine.Item.ROCK: "ROCK",
	RuleEngine.Item.SCISSORS: "SCISSORS",
	RuleEngine.Item.PAPER: "PAPER",
	RuleEngine.Item.LIZARD: "LIZARD",
	RuleEngine.Item.SPOCK: "SPOCK",
}


func _ready() -> void:
	var log_lines: PackedStringArray = PackedStringArray()
	_log(log_lines, "=== CheaterDualResolve / AiOpponent.CHEATER tests ===")

	var failures: int = 0
	failures += _test_all_dual_outcomes(log_lines)
	failures += _test_named_cases(log_lines)
	failures += _test_choose_items_count(log_lines)
	failures += _test_ban_ignore(log_lines)

	var summary: String
	if failures == 0:
		summary = "PASS: all Шулер algorithm checks ok"
	else:
		summary = "FAIL: %d check group(s) had errors" % failures
	_log(log_lines, summary)
	_log(log_lines, "=== Cheater tests finished ===")
	_write_log_file(log_lines)
	_show_on_screen(summary, failures == 0)
	push_warning(summary)


func _test_all_dual_outcomes(log_lines: PackedStringArray) -> int:
	_log(log_lines, "--- exhaustive p1 × ai_a × ai_b (125) ---")
	var engine := RuleEngine.new()
	var items: Array[RuleEngine.Item] = [
		RuleEngine.Item.ROCK,
		RuleEngine.Item.SCISSORS,
		RuleEngine.Item.PAPER,
		RuleEngine.Item.LIZARD,
		RuleEngine.Item.SPOCK,
	]
	var checked: int = 0
	var fails: int = 0
	for p1: RuleEngine.Item in items:
		for a: RuleEngine.Item in items:
			for b: RuleEngine.Item in items:
				var p2: Array[RuleEngine.Item] = [a, b]
				var got: Dictionary = CheaterDualResolve.evaluate(engine, p1, p2)
				var want: int = _expected_result(engine, p1, a, b)
				checked += 1
				if int(got["result"]) != want:
					fails += 1
					_log(
						log_lines,
						"FAIL %s vs [%s,%s]: got %d want %d (tie=%s w=%d/%d)"
						% [
							NAMES[p1], NAMES[a], NAMES[b],
							int(got["result"]), want,
							str(got["any_tie"]), int(got["wins_p1"]), int(got["wins_p2"]),
						]
					)
	if fails == 0:
		_log(log_lines, "OK   exhaustive: %d triples" % checked)
		return 0
	_log(log_lines, "FAIL exhaustive: %d / %d" % [fails, checked])
	return 1


func _expected_result(
	engine: RuleEngine, p1: RuleEngine.Item, a: RuleEngine.Item, b: RuleEngine.Item
) -> int:
	var r_a: int = engine.resolve(p1, a)
	var r_b: int = engine.resolve(p1, b)
	if r_a == 0 or r_b == 0:
		return 0
	var w1: int = 0
	var w2: int = 0
	if r_a == 1:
		w1 += 1
	elif r_a == -1:
		w2 += 1
	if r_b == 1:
		w1 += 1
	elif r_b == -1:
		w2 += 1
	if w1 > w2:
		return 1
	if w2 > w1:
		return -1
	return 0


func _test_named_cases(log_lines: PackedStringArray) -> int:
	_log(log_lines, "--- named scenarios ---")
	var engine := RuleEngine.new()
	var fails: int = 0
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.ROCK,
		[RuleEngine.Item.SCISSORS, RuleEngine.Item.LIZARD], 1, "ROCK beats SCISSORS+LIZARD"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.ROCK,
		[RuleEngine.Item.PAPER, RuleEngine.Item.SPOCK], -1, "ROCK loses to PAPER+SPOCK"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.ROCK,
		[RuleEngine.Item.SCISSORS, RuleEngine.Item.PAPER], 0, "ROCK win+lose → tie by score"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.ROCK,
		[RuleEngine.Item.ROCK, RuleEngine.Item.SCISSORS], 0, "ROCK vs ROCK+SCISSORS → tie dominates"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.PAPER,
		[RuleEngine.Item.PAPER, RuleEngine.Item.PAPER], 0, "PAPER vs PAPER+PAPER → tie"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.LIZARD,
		[RuleEngine.Item.ROCK, RuleEngine.Item.SCISSORS], -1, "LIZARD loses to ROCK+SCISSORS"
	)
	fails += _check_case(
		log_lines, engine, RuleEngine.Item.SPOCK,
		[RuleEngine.Item.ROCK, RuleEngine.Item.SCISSORS], 1, "SPOCK beats ROCK+SCISSORS"
	)
	return 0 if fails == 0 else 1


func _check_case(
	log_lines: PackedStringArray,
	engine: RuleEngine,
	p1: RuleEngine.Item,
	p2: Array,
	want: int,
	label: String
) -> int:
	var items: Array[RuleEngine.Item] = []
	for v: Variant in p2:
		items.append(v as RuleEngine.Item)
	var got: Dictionary = CheaterDualResolve.evaluate(engine, p1, items)
	if int(got["result"]) != want:
		_log(log_lines, "FAIL %s: got %d want %d" % [label, int(got["result"]), want])
		return 1
	_log(log_lines, "OK   %s -> %d" % [label, want])
	return 0


func _test_choose_items_count(log_lines: PackedStringArray) -> int:
	_log(log_lines, "--- choose_items returns 2 ---")
	var engine := RuleEngine.new()
	var ai := AiOpponent.new()
	ai.persona = AiOpponent.Persona.CHEATER
	var empty_bans: Array[RuleEngine.Item] = []
	var fails: int = 0
	for i: int in range(40):
		ai.prepare_round(engine)
		var picks: Array[RuleEngine.Item] = ai.choose_items(engine, empty_bans)
		if picks.size() != 2:
			fails += 1
			_log(log_lines, "FAIL choose_items size=%d (trial %d)" % [picks.size(), i])
		elif picks[0] == picks[1]:
			fails += 1
			_log(log_lines, "FAIL choose_items duplicate %s (trial %d)" % [NAMES[picks[0]], i])
	if fails == 0:
		_log(log_lines, "OK   choose_items: 40 trials, always 2 distinct")
		return 0
	return 1


func _test_ban_ignore(log_lines: PackedStringArray) -> int:
	_log(log_lines, "--- ban ignore ~33% + distraction ---")
	var engine := RuleEngine.new()
	var ai := AiOpponent.new()
	ai.persona = AiOpponent.Persona.CHEATER
	var bans: Array[RuleEngine.Item] = [
		RuleEngine.Item.ROCK,
		RuleEngine.Item.SCISSORS,
		RuleEngine.Item.PAPER,
	]
	var trials: int = 300
	var ignored: int = 0
	var with_line: int = 0
	var illegal_when_obey: int = 0
	for _i: int in range(trials):
		ai.prepare_round(engine)
		var picks: Array[RuleEngine.Item] = ai.choose_items(engine, bans)
		if ai.ignored_ban:
			ignored += 1
			if not ai.last_taunt.is_empty():
				with_line += 1
		else:
			for item: RuleEngine.Item in picks:
				if item in bans:
					illegal_when_obey += 1
	var rate: float = float(ignored) / float(trials)
	_log(log_lines, "OK   ignore rate=%.3f (%d/%d)" % [rate, ignored, trials])
	var fails: int = 0
	# Loose band around 33% for flaky RNG.
	if rate < 0.20 or rate > 0.50:
		fails += 1
		_log(log_lines, "FAIL ignore rate out of [0.20, 0.50]: %.3f" % rate)
	if with_line != ignored:
		fails += 1
		_log(log_lines, "FAIL distraction lines %d != ignores %d" % [with_line, ignored])
	if illegal_when_obey > 0:
		fails += 1
		_log(log_lines, "FAIL played banned item while obeying: %d" % illegal_when_obey)
	if fails == 0:
		_log(log_lines, "OK   ban ignore behavior")
	return fails


func _log(lines: PackedStringArray, message: String) -> void:
	lines.append(message)
	print(message)


func _write_log_file(lines: PackedStringArray) -> void:
	var path: String = "res://assets/debug/last_cheater_test_result.txt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("Log written to %s" % path)


func _show_on_screen(summary: String, ok: bool) -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.text = summary + "\n\nЛог: res://assets/debug/last_cheater_test_result.txt"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3) if ok else Color(1.0, 0.3, 0.3))
	ui.add_child(label)
