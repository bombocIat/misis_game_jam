extends Node
## F5/F6: results on-screen + file assets/debug/last_test_result.txt (open in Cursor).


func _ready() -> void:
	var log_lines: PackedStringArray = []
	_log(log_lines, "=== RuleEngine test started ===")

	var engine := RuleEngine.new()
	var items: Array[RuleEngine.Item] = [
		RuleEngine.Item.ROCK,
		RuleEngine.Item.SCISSORS,
		RuleEngine.Item.PAPER,
		RuleEngine.Item.LIZARD,
		RuleEngine.Item.SPOCK,
	]
	var names: Dictionary = {
		RuleEngine.Item.ROCK: "ROCK",
		RuleEngine.Item.SCISSORS: "SCISSORS",
		RuleEngine.Item.PAPER: "PAPER",
		RuleEngine.Item.LIZARD: "LIZARD",
		RuleEngine.Item.SPOCK: "SPOCK",
	}
	var expected: Dictionary = {
		RuleEngine.Item.ROCK: {
			RuleEngine.Item.ROCK: 0,
			RuleEngine.Item.SCISSORS: 1,
			RuleEngine.Item.PAPER: -1,
			RuleEngine.Item.LIZARD: 1,
			RuleEngine.Item.SPOCK: -1,
		},
		RuleEngine.Item.SCISSORS: {
			RuleEngine.Item.ROCK: -1,
			RuleEngine.Item.SCISSORS: 0,
			RuleEngine.Item.PAPER: 1,
			RuleEngine.Item.LIZARD: 1,
			RuleEngine.Item.SPOCK: -1,
		},
		RuleEngine.Item.PAPER: {
			RuleEngine.Item.ROCK: 1,
			RuleEngine.Item.SCISSORS: -1,
			RuleEngine.Item.PAPER: 0,
			RuleEngine.Item.LIZARD: -1,
			RuleEngine.Item.SPOCK: 1,
		},
		RuleEngine.Item.LIZARD: {
			RuleEngine.Item.ROCK: -1,
			RuleEngine.Item.SCISSORS: -1,
			RuleEngine.Item.PAPER: 1,
			RuleEngine.Item.LIZARD: 0,
			RuleEngine.Item.SPOCK: 1,
		},
		RuleEngine.Item.SPOCK: {
			RuleEngine.Item.ROCK: 1,
			RuleEngine.Item.SCISSORS: 1,
			RuleEngine.Item.PAPER: -1,
			RuleEngine.Item.LIZARD: -1,
			RuleEngine.Item.SPOCK: 0,
		},
	}

	var failures: int = 0
	var checked: int = 0
	for a: RuleEngine.Item in items:
		for b: RuleEngine.Item in items:
			var got: int = engine.resolve(a, b)
			var want: int = expected[a][b]
			checked += 1
			var pair: String = "%s vs %s" % [names[a], names[b]]
			if got != want:
				failures += 1
				_log(log_lines, "FAIL %s: got %d, expected %d" % [pair, got, want])
			else:
				_log(log_lines, "OK   %s -> %d" % [pair, got])

	var summary: String
	if failures == 0:
		summary = "PASS: all %d pairs match classic RPSLS" % checked
	else:
		summary = "FAIL: %d / %d pairs wrong" % [failures, checked]
	_log(log_lines, summary)
	_log(log_lines, "=== RuleEngine test finished ===")

	_write_log_file(log_lines)
	_show_on_screen(summary, failures == 0)
	# Warnings always show in Godot Debugger even when Output filters hide print().
	push_warning(summary)


func _log(lines: PackedStringArray, message: String) -> void:
	lines.append(message)
	print(message)


func _write_log_file(lines: PackedStringArray) -> void:
	var path: String = "res://assets/debug/last_test_result.txt"
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
	label.text = summary + "\n\nЛог: res://assets/debug/last_test_result.txt\n(открой файл в Cursor)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3) if ok else Color(1.0, 0.3, 0.3))
	ui.add_child(label)
