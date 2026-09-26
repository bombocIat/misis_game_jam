class_name TutorialOverlay
extends Control
## First-run controls tutorial. Emits closed when dismissed.


signal closed

@onready var _panel: PanelContainer = %Panel


func _ready() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	%BodyLabel.text = (
		"УПРАВЛЕНИЕ\n\n"
		+ "1 камень · 2 ножницы · 3 бумага · 4 ящерица · 5 Спок\n"
		+ "Space — сыграть\n"
		+ "6–0 — ставка: что кинет враг (угадал ×2 урон, нет −1 HP)\n"
		+ "B — купить карту за 1 HP\n"
		+ "R — реванш (после матча)\n\n"
		+ "КАРТЫ\n\n"
		+ "Перетащи в область справа от противника — сыграть карту\n"
		+ "Перетащи в мусорку справа внизу — сбросить без эффекта\n"
		+ "Враг тоже играет карты раз в 2 раунда\n\n"
		+ "ПРЕДМЕТЫ\n\n"
		+ "Камень — при поражении блокирует 1 урон (если урон > 1)\n"
		+ "Ножницы — при победе срезают стрелку врага\n"
		+ "Бумага — при победе +1 карта\n"
		+ "Ящерица — при победе лечит 1\n"
		+ "Спок — при ничьей −1 себе, +1 врагу\n\n"
		+ "Tab — статистика и пентаграмма правил\n"
		+ "H — открыть эту справку снова\n\n"
		+ "Space или клик — начать"
	)


func open_help() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_dismiss()
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss()
		accept_event()


func _dismiss() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()
