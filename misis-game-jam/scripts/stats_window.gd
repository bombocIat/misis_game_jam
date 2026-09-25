class_name StatsWindow
extends Control
## Compact always-on HUD: per-item win % (wins / throws).

const ITEM_ORDER: Array[RuleEngine.Item] = [
	RuleEngine.Item.ROCK,
	RuleEngine.Item.SCISSORS,
	RuleEngine.Item.PAPER,
	RuleEngine.Item.LIZARD,
	RuleEngine.Item.SPOCK,
]

const ITEM_ICONS: Dictionary = {
	RuleEngine.Item.ROCK: "res://assets/textures/rpsls/rock.png",
	RuleEngine.Item.SCISSORS: "res://assets/textures/rpsls/scissors.png",
	RuleEngine.Item.PAPER: "res://assets/textures/rpsls/paper.png",
	RuleEngine.Item.LIZARD: "res://assets/textures/rpsls/lizard.png",
	RuleEngine.Item.SPOCK: "res://assets/textures/rpsls/spock.png",
}

const ITEM_LABELS: Dictionary = {
	RuleEngine.Item.ROCK: "Камень",
	RuleEngine.Item.SCISSORS: "Ножницы",
	RuleEngine.Item.PAPER: "Бумага",
	RuleEngine.Item.LIZARD: "Ящерица",
	RuleEngine.Item.SPOCK: "Спок",
}

var _stats: MatchStats
var _percent_labels: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_rows_if_needed()
	if _stats != null:
		bind_stats(_stats)


func bind_stats(stats: MatchStats) -> void:
	if _stats != null and _stats.changed.is_connected(_on_stats_changed):
		_stats.changed.disconnect(_on_stats_changed)
	_stats = stats
	if not _stats.changed.is_connected(_on_stats_changed):
		_stats.changed.connect(_on_stats_changed)
	_refresh()


func _build_rows_if_needed() -> void:
	var list: VBoxContainer = %ItemList
	if list.get_child_count() > 0:
		return
	for item: RuleEngine.Item in ITEM_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(str(ITEM_ICONS[item])) as Texture2D
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(120, 0)
		name_label.text = str(ITEM_LABELS[item])
		name_label.add_theme_font_size_override("font_size", 23)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var percent := Label.new()
		percent.custom_minimum_size = Vector2(130, 0)
		percent.add_theme_font_size_override("font_size", 23)
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		percent.text = "0% (0/0)"
		percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(percent)
		_percent_labels[item] = percent

		list.add_child(row)


func _on_stats_changed() -> void:
	_refresh()


func _refresh() -> void:
	_build_rows_if_needed()
	if _stats == null:
		return
	for item: RuleEngine.Item in ITEM_ORDER:
		var label: Label = _percent_labels[item] as Label
		var wins: int = _stats.get_wins(item)
		var throws: int = _stats.get_throws(item)
		var pct: int = _stats.win_rate_percent(item)
		label.text = "%d%% (%d/%d)" % [pct, wins, throws]
