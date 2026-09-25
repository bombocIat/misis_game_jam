extends Node
## Fixed 16:9 design (1600×900). Opens the largest 16:9 window that fits the screen.

const DESIGN := Vector2i(1600, 900)
const ASPECT := 16.0 / 9.0

var size: Vector2i = DESIGN
var aspect_name: String = "16:9"


func _enter_tree() -> void:
	apply_max_16_9_window()


func apply_max_16_9_window() -> void:
	size = DESIGN
	aspect_name = "16:9"

	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		screen = Vector2i(1920, 1080)

	# Largest 16:9 rectangle that fits inside the screen.
	var by_width := Vector2i(screen.x, int(round(float(screen.x) * 9.0 / 16.0)))
	var by_height := Vector2i(int(round(float(screen.y) * 16.0 / 9.0)), screen.y)
	var window_size: Vector2i = by_width if by_width.y <= screen.y else by_height
	window_size.x = maxi(window_size.x, 640)
	window_size.y = maxi(window_size.y, 360)

	var win: Window = get_window()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_size = DESIGN
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.size = window_size
	var origin: Vector2i = (screen - window_size) / 2
	win.position = Vector2i(maxi(origin.x, 0), maxi(origin.y, 0))

	print(
		"DisplayFit: screen %dx%d → window %dx%d (design %dx%d 16:9)"
		% [screen.x, screen.y, window_size.x, window_size.y, DESIGN.x, DESIGN.y]
	)
