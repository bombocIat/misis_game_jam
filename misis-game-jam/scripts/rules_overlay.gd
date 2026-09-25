class_name RulesOverlay
extends Control
## Tab-toggled overlay: enlarged beats diagram + match stats.


@onready var _panel: PanelContainer = %Panel
@onready var _beats: BeatsDiagram = %BeatsDiagram
@onready var _stats: StatsWindow = %StatsWindow
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.text = "Tab — закрыть"


func toggle() -> void:
	visible = not visible
	if visible:
		_beats.queue_redraw()


func bind(engine: RuleEngine, stats: MatchStats) -> void:
	_beats.bind_engine(engine)
	_stats.bind_stats(stats)


func _gui_input(event: InputEvent) -> void:
	# Click dimmed backdrop to close.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(event.global_position):
			visible = false
			accept_event()
