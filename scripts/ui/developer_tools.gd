extends Control
## Hidden utility UI; independent of the future gameplay HUD.
var world: Node3D
var panel: PanelContainer
var fog_of_war_toggle: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -265
	panel.offset_bottom = 265
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	title.text = "Служебное меню · F1"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Закрыть · Esc"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): set_open(false))
	header.add_child(close)
	fog_of_war_toggle = CheckButton.new()
	fog_of_war_toggle.text = "Туман войны"
	fog_of_war_toggle.tooltip_text = "Выключить: показать всю карту и объекты. Разведка не стирается. Погодный туман не меняется."
	fog_of_war_toggle.focus_mode = Control.FOCUS_NONE
	fog_of_war_toggle.button_pressed = world.vision.enabled
	fog_of_war_toggle.toggled.connect(world.vision.set_enabled)
	world.vision.enabled_changed.connect(fog_of_war_toggle.set_pressed_no_signal)
	rows.add_child(fog_of_war_toggle)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	for source: Control in [world.world_controls, world.rts.command_panel]:
		source.reparent(tabs)
		source.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.set_tab_title(0, "Мир и разработка")
	tabs.set_tab_title(1, "Управление и подсказки")
	set_open(false)

func set_open(value: bool) -> void:
	visible = value
	world.game_camera.controls_blocked = value
	world.game_camera.dragging = false
	world.rts.cancel_drag()
	if not value:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and is_ancestor_of(focused): focused.release_focus()

func contains(point: Vector2) -> bool:
	return is_visible_in_tree() and panel.get_global_rect().has_point(point)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F1 or event.physical_keycode == KEY_F1:
		set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()
