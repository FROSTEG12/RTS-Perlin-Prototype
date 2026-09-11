extends Control
## Display changes are provisional until confirmed; timeout restores the old mode.
const CONFIG_PATH := "user://display.cfg"
var world: Node3D
var panel: VBoxContainer
var settings: VBoxContainer
var modes: OptionButton
var resolutions: OptionButton
var confirmation: HBoxContainer
var countdown: Label
var remaining := 0.0
var previous_mode := 0
var previous_size := Vector2i.ZERO
var previous_position := Vector2i.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = preload("res://scripts/ui/game_hud.gd").make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.06, 0.78)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	center.add_child(frame)
	frame.custom_minimum_size.x = 460
	var rows := VBoxContainer.new()
	frame.add_child(rows)
	panel = VBoxContainer.new()
	rows.add_child(panel)
	_button("Настройки", panel, func(): panel.hide(); settings.show())
	_button("Выйти", panel, func(): get_tree().quit())
	settings = VBoxContainer.new()
	rows.add_child(settings)
	var title := Label.new()
	title.text = "ЭКРАН"
	settings.add_child(title)
	modes = OptionButton.new()
	modes.add_item("Оконный")
	modes.add_item("Полный экран — разрешение монитора")
	settings.add_child(modes)
	resolutions = OptionButton.new()
	for value in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(2560,1080), Vector2i(3440,1440), Vector2i(3840,2160)]:
		_add_resolution(value)
	settings.add_child(resolutions)
	modes.item_selected.connect(func(index: int): resolutions.disabled = index == 1)
	_button("Применить", settings, apply_preview)
	confirmation = HBoxContainer.new()
	settings.add_child(confirmation)
	countdown = Label.new()
	confirmation.add_child(countdown)
	_button("Сохранить", confirmation, confirm)
	_button("Вернуть", confirmation, revert)
	_button("Назад · Esc", settings, _back)
	confirmation.hide()
	settings.hide()
	hide()
	if DisplayServer.get_name() != "headless":
		var config := ConfigFile.new()
		if config.load(CONFIG_PATH) == OK:
			_set_display(int(config.get_value("display", "mode", 0)), config.get_value("display", "size", Vector2i(1280,720)))

func _button(text: String, parent: Node, action: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.pressed.connect(action)
	parent.add_child(item)

func _add_resolution(value: Vector2i) -> int:
	for index in resolutions.item_count:
		if resolutions.get_item_metadata(index) == value: return index
	resolutions.add_item("%d × %d" % [value.x, value.y])
	resolutions.set_item_metadata(resolutions.item_count - 1, value)
	return resolutions.item_count - 1

func set_open(value: bool) -> void:
	if not value and remaining > 0: revert()
	if value:
		world.developer_tools.set_open(false)
		modes.select(0 if get_window().mode == Window.MODE_WINDOWED else 1)
		resolutions.select(_add_resolution(get_window().size))
		resolutions.disabled = modes.selected == 1
	visible = value
	panel.show()
	settings.hide()
	world.rts.cancel_drag()
	world.game_camera.dragging = false
	world.game_camera.controls_blocked = value
	get_tree().paused = value

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if world.developer_tools.visible:
			world.developer_tools.set_open(false)
		elif visible and settings.visible: _back()
		else: set_open(not visible)
		get_viewport().set_input_as_handled()

func _back() -> void:
	if remaining > 0: revert()
	settings.hide()
	panel.show()

func apply_preview() -> void:
	if remaining > 0: revert()
	previous_mode = get_window().mode
	previous_size = get_window().size
	previous_position = get_window().position
	_set_display(Window.MODE_WINDOWED if modes.selected == 0 else Window.MODE_FULLSCREEN, resolutions.get_item_metadata(resolutions.selected))
	remaining = 15.0
	confirmation.show()

func _set_display(mode: int, dimensions: Vector2i) -> void:
	if DisplayServer.get_name() == "headless": return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED if mode == Window.MODE_WINDOWED else Window.MODE_FULLSCREEN
	if window.mode == Window.MODE_WINDOWED:
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var available := Vector2(usable.size - Vector2i(32, 64))
		var requested := Vector2(dimensions).max(Vector2(960, 540))
		var factor := minf(1.0, minf(available.x / requested.x, available.y / requested.y))
		window.size = Vector2i(requested * factor)
		window.position = usable.position + (usable.size - window.size) / 2

func confirm() -> void:
	if remaining <= 0: return
	remaining = 0
	confirmation.hide()
	if DisplayServer.get_name() == "headless": return
	var config := ConfigFile.new()
	config.set_value("display", "mode", get_window().mode)
	config.set_value("display", "size", get_window().size)
	config.save(CONFIG_PATH)

func revert() -> void:
	if remaining <= 0: return
	remaining = 0
	confirmation.hide()
	if DisplayServer.get_name() != "headless":
		get_window().mode = previous_mode
		get_window().size = previous_size
		get_window().position = previous_position
	modes.select(0 if previous_mode == Window.MODE_WINDOWED else 1)
	resolutions.select(_add_resolution(previous_size))
	resolutions.disabled = modes.selected == 1

func _process(delta: float) -> void:
	if remaining > 0:
		remaining -= delta
		countdown.text = "Оставить? %d с" % ceili(remaining)
		if remaining <= 0:
			remaining = 0.001
			revert()
