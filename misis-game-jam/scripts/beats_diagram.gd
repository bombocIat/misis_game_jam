class_name BeatsDiagram
extends Control
## Regular pentagon of RPSLS items; arrows follow RuleEngine.beats and redraw on change.

const ITEMS: Array[RuleEngine.Item] = [
	RuleEngine.Item.ROCK,
	RuleEngine.Item.SCISSORS,
	RuleEngine.Item.PAPER,
	RuleEngine.Item.LIZARD,
	RuleEngine.Item.SPOCK,
]

const ITEM_LABELS: Dictionary = {
	RuleEngine.Item.ROCK: "R",
	RuleEngine.Item.SCISSORS: "Sc",
	RuleEngine.Item.PAPER: "P",
	RuleEngine.Item.LIZARD: "L",
	RuleEngine.Item.SPOCK: "Sp",
}

const ITEM_ICONS: Dictionary = {
	RuleEngine.Item.ROCK: "res://assets/textures/rpsls/rock.svg",
	RuleEngine.Item.SCISSORS: "res://assets/textures/rpsls/scissors.svg",
	RuleEngine.Item.PAPER: "res://assets/textures/rpsls/paper.svg",
	RuleEngine.Item.LIZARD: "res://assets/textures/rpsls/lizard.svg",
	RuleEngine.Item.SPOCK: "res://assets/textures/rpsls/spock.svg",
}

const ITEM_COLORS: Dictionary = {
	RuleEngine.Item.ROCK: Color(0.75, 0.55, 0.35),
	RuleEngine.Item.SCISSORS: Color(0.65, 0.75, 0.85),
	RuleEngine.Item.PAPER: Color(0.57, 0.57, 0.57),
	RuleEngine.Item.LIZARD: Color(0.4, 0.8, 0.4),
	RuleEngine.Item.SPOCK: Color(0.59, 0, 0.18), #215 0 64
}

@export var radius: float = 120.0
@export var node_radius: float = 28.0

var _engine: RuleEngine
var _textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: RuleEngine.Item in ITEMS:
		_textures[item] = load(str(ITEM_ICONS[item])) as Texture2D
	if _engine != null:
		bind_engine(_engine)


func bind_engine(engine: RuleEngine) -> void:
	if _engine != null and _engine.beats_changed.is_connected(_on_beats_changed):
		_engine.beats_changed.disconnect(_on_beats_changed)
	_engine = engine
	if not _engine.beats_changed.is_connected(_on_beats_changed):
		_engine.beats_changed.connect(_on_beats_changed)
	queue_redraw()


func _on_beats_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _engine == null:
		return
	var center: Vector2 = size * 0.5
	var positions: Dictionary = _vertex_positions(center)

	# Soft pentagon outline.
	var outline: PackedVector2Array = PackedVector2Array()
	for item: RuleEngine.Item in ITEMS:
		outline.append(positions[item] as Vector2)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		draw_line(a, b, Color(1, 1, 1, 0.12), 2.0)

	# Arrows from undirected pairs: mutual beats → one white double arrow.
	for i: int in range(ITEMS.size()):
		for j: int in range(i + 1, ITEMS.size()):
			var a: RuleEngine.Item = ITEMS[i]
			var b: RuleEngine.Item = ITEMS[j]
			var a_beats_b: bool = _item_beats(a, b)
			var b_beats_a: bool = _item_beats(b, a)
			if a_beats_b and b_beats_a:
				_draw_double_arrow(
					positions[a] as Vector2,
					positions[b] as Vector2,
					Color(1, 1, 1, 0.95)
				)
			elif a_beats_b:
				_draw_arrow(
					positions[a] as Vector2,
					positions[b] as Vector2,
					ITEM_COLORS[a] as Color
				)
			elif b_beats_a:
				_draw_arrow(
					positions[b] as Vector2,
					positions[a] as Vector2,
					ITEM_COLORS[b] as Color
				)

	# Nodes on top.
	for item: RuleEngine.Item in ITEMS:
		var pos: Vector2 = positions[item] as Vector2
		draw_circle(pos, node_radius, Color(0.12, 0.14, 0.18, 0.95))
		draw_arc(pos, node_radius, 0.0, TAU, 32, ITEM_COLORS[item] as Color, 2.5, true)
		var tex: Texture2D = _textures.get(item) as Texture2D
		if tex != null:
			var icon_size := Vector2(36, 36)
			draw_texture_rect(tex, Rect2(pos - icon_size * 0.5, icon_size), false)
		else:
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(-10, 5),
				str(ITEM_LABELS[item]),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				Color.WHITE
			)


func _vertex_positions(center: Vector2) -> Dictionary:
	var positions: Dictionary = {}
	for i: int in range(ITEMS.size()):
		var angle: float = -PI * 0.5 + float(i) * TAU / float(ITEMS.size())
		positions[ITEMS[i]] = center + Vector2(cos(angle), sin(angle)) * radius
	return positions


func _item_beats(a: RuleEngine.Item, b: RuleEngine.Item) -> bool:
	return b in _engine.get_beats(a)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var ends: PackedVector2Array = _arrow_ends(from, to)
	if ends.is_empty():
		return
	var start: Vector2 = ends[0]
	var end: Vector2 = ends[1]
	var dir: Vector2 = (end - start).normalized()
	draw_line(start, end, color, 2.5)
	_draw_arrow_head(end, dir, color)


func _draw_double_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var ends: PackedVector2Array = _arrow_ends(from, to)
	if ends.is_empty():
		return
	var start: Vector2 = ends[0]
	var end: Vector2 = ends[1]
	var dir: Vector2 = (end - start).normalized()
	draw_line(start, end, color, 3.0)
	_draw_arrow_head(end, dir, color)
	_draw_arrow_head(start, -dir, color)


func _arrow_ends(from: Vector2, to: Vector2) -> PackedVector2Array:
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length < 1.0:
		return PackedVector2Array()
	var dir: Vector2 = delta / length
	var start: Vector2 = from + dir * (node_radius + 4.0)
	var end: Vector2 = to - dir * (node_radius + 6.0)
	if start.distance_to(end) < 8.0:
		return PackedVector2Array()
	return PackedVector2Array([start, end])


func _draw_arrow_head(tip: Vector2, dir: Vector2, color: Color) -> void:
	var head: float = 10.0
	var left: Vector2 = tip - dir.rotated(0.4) * head
	var right: Vector2 = tip - dir.rotated(-0.4) * head
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
