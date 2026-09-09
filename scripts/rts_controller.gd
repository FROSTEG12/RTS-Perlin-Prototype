extends Control
## Screen-space selection, with a world-space command interface beneath it.
const DRAG_THRESHOLD := 7.0
var world: Node3D
var orders: Node
var selected: Array[TestUnit3D] = []
var hovered: TestUnit3D
var selecting := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var additive := false
var hover_timer := 0.0
var feedback_timer := 0.0
var feedback_point := Vector3.ZERO
var feedback_ok := true
var status: Label
var stop_button: Button
var focus_button: Button
var grid_button: CheckButton
var grid_overlay: MeshInstance3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orders = preload("res://scripts/rts_orders.gd").new()
	orders.world = world
	add_child(orders)
	orders.result_received.connect(_feedback)
	grid_overlay = preload("res://scripts/walkability_grid.gd").new()
	grid_overlay.world = world
	world.map_renderer.add_child(grid_overlay)
	var panel := PanelContainer.new()
	panel.name = "UnitCommands"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -342
	panel.offset_top = -198
	panel.offset_right = -18
	panel.offset_bottom = -18
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	margin.add_child(rows)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	rows.add_child(status)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	stop_button = Button.new()
	stop_button.text = "Стоп [S]"
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.pressed.connect(stop_selected)
	buttons.add_child(stop_button)
	focus_button = Button.new()
	focus_button.text = "К выделенным [Пробел]"
	focus_button.focus_mode = Control.FOCUS_NONE
	focus_button.pressed.connect(focus_selected)
	buttons.add_child(focus_button)
	var help := Label.new()
	help.text = "ЛКМ / рамка — выбор · Shift — группа\nПКМ — идти · Shift+ПКМ — очередь\nКамера: средняя кнопка / колесо"
	help.add_theme_font_size_override("font_size", 12)
	rows.add_child(help)
	grid_button = CheckButton.new()
	grid_button.text = "Сетка проходимости [G]"
	grid_button.focus_mode = Control.FOCUS_NONE
	grid_button.toggled.connect(func(enabled: bool): grid_overlay.visible = enabled)
	rows.add_child(grid_button)
	var legend := Label.new()
	legend.text = "Зелёное — суша · красное — вода"
	legend.add_theme_font_size_override("font_size", 12)
	rows.add_child(legend)
	_update_status()


func units() -> Array:
	return get_tree().get_nodes_in_group("rts_units")


func set_selection(next: Array) -> void:
	for unit in selected:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected.clear()
	for unit in next:
		if is_instance_valid(unit) and not unit.battle_dead and unit not in selected:
			selected.append(unit)
			unit.set_selected(true)
	_update_status()


func reset() -> void:
	cancel_drag()
	set_selection([])
	_set_hover(null)
	orders.reset()
	feedback_timer = 0.0


func cancel_drag() -> void:
	selecting = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_drag()
		_set_hover(null)


func _input(event: InputEvent) -> void:
	# A release swallowed by GUI must cancel, never leave a stuck drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		cancel_drag.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if world.is_generating or world.is_placing_building:
		return
	if event is InputEventMouseButton and over_ui(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			cancel_drag()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_S or event.keycode == KEY_S:
			stop_selected()
		elif event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE:
			focus_selected()
		elif event.physical_keycode == KEY_G or event.keycode == KEY_G:
			grid_button.button_pressed = not grid_button.button_pressed
		elif event.keycode == KEY_ESCAPE:
			if selecting:
				cancel_drag()
			else:
				set_selection([])
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not world.game_camera.dragging:
				selecting = true
				drag_start = event.position
				drag_end = drag_start
				additive = event.shift_pressed
			elif not event.pressed and selecting:
				drag_end = event.position
				_finish_selection()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()
			if not selected.is_empty():
				var point: Vector3 = world.game_camera.screen_to_ground(event.position, MapRenderer3D.LAND_Y)
				if point.is_finite():
					orders.move(selected, world.map_renderer.world_to_cell(point), event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			cancel_drag()
	elif event is InputEventMouseMotion and selecting:
		drag_end = event.position
		queue_redraw()


func unit_screen_rect(unit: TestUnit3D) -> Rect2:
	var feet: Vector2 = world.game_camera.unproject_position(unit.global_position)
	var head: Vector2 = world.game_camera.unproject_position(unit.global_position + Vector3.UP * 1.2)
	var width := maxf(12.0, feet.distance_to(head) * 0.34)
	return Rect2(Vector2(head.x - width, head.y - 5.0), Vector2(width * 2.0, maxf(18.0, feet.y - head.y + 10.0)))


func over_ui(point: Vector2) -> bool:
	var training_panel := world.get_node_or_null("UI/TrainingPanel")
	if training_panel != null and training_panel.is_visible_in_tree() and training_panel.get_global_rect().has_point(point):
		return true
	for panel in [world.get_node("UI/MapControls"), get_node("UnitCommands")]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(point):
			return true
	return false


func hit_unit(point: Vector2) -> TestUnit3D:
	var result: TestUnit3D
	var nearest := INF
	for unit: TestUnit3D in units():
		if not unit.is_visible_in_tree() or world.game_camera.is_position_behind(unit.global_position):
			continue
		var rect := unit_screen_rect(unit)
		if rect.has_point(point):
			var distance := point.distance_squared_to(rect.get_center())
			if distance < nearest:
				result = unit
				nearest = distance
	return result


func _finish_selection() -> void:
	var next: Array = selected.duplicate() if additive else []
	if drag_start.distance_to(drag_end) < DRAG_THRESHOLD:
		var unit := hit_unit(drag_end)
		if unit != null:
			if additive and unit in next:
				next.erase(unit)
			else:
				next.append(unit)
	else:
		var rect := Rect2(drag_start, drag_end - drag_start).abs()
		for unit: TestUnit3D in units():
			if unit.is_visible_in_tree() and not world.game_camera.is_position_behind(unit.global_position) and rect.intersects(unit_screen_rect(unit)):
				next.append(unit)
	cancel_drag()
	set_selection(next)


func stop_selected() -> void:
	_manual_override()
	orders.stop(selected)
	_update_status()


func _manual_override() -> void:
	if world.training != null and world.training.has_method("manual_override"):
		world.training.manual_override(selected)


func focus_selected() -> void:
	if selected.is_empty():
		return
	var center := Vector3.ZERO
	for unit in selected:
		center += unit.global_position
	world.game_camera.focus_on(center / selected.size())


func _set_hover(unit: TestUnit3D) -> void:
	if is_instance_valid(hovered):
		hovered.set_hovered(false)
	hovered = unit
	if hovered != null:
		hovered.set_hovered(true)


func _process(delta: float) -> void:
	var surviving: Array[TestUnit3D] = []
	for unit in selected:
		if is_instance_valid(unit) and not unit.battle_dead:
			surviving.append(unit)
	if surviving.size() != selected.size():
		selected = surviving
		_update_status()
	hover_timer -= delta
	if hover_timer <= 0.0:
		hover_timer = 0.08
		var over_ui := get_viewport().gui_get_hovered_control() != null
		_set_hover(null if over_ui or selecting or world.is_placing_building else hit_unit(get_viewport().get_mouse_position()))
	if feedback_timer > 0.0:
		feedback_timer = maxf(0.0, feedback_timer - delta)
		queue_redraw()
		if feedback_timer == 0.0:
			_update_status()


func _feedback(ok: bool, point: Vector3, message: String) -> void:
	feedback_point = point
	feedback_ok = ok
	feedback_timer = 1.0
	status.text = message
	queue_redraw()


func _update_status() -> void:
	if status == null:
		return
	status.text = "Выделено: %d" % selected.size() if not selected.is_empty() else "Выбери юнита левой кнопкой"
	if selected.size() == 1:
		status.text = selected[0].display_name
	stop_button.disabled = selected.is_empty()
	focus_button.disabled = selected.is_empty()


func _draw() -> void:
	if selecting and drag_start.distance_to(drag_end) >= DRAG_THRESHOLD:
		var rect := Rect2(drag_start, drag_end - drag_start).abs()
		draw_rect(rect, Color(0.65, 0.85, 0.55, 0.13), true)
		draw_rect(rect, Color(0.75, 0.95, 0.60, 0.9), false, 1.5)
	if feedback_timer > 0.0 and world != null:
		var point: Vector2 = world.game_camera.unproject_position(feedback_point)
		var color := Color(0.85, 0.95, 0.4, feedback_timer) if feedback_ok else Color(1.0, 0.3, 0.2, feedback_timer)
		draw_arc(point, 9.0 + feedback_timer * 6.0, 0.0, TAU, 24, color, 2.0, true)
		if not feedback_ok:
			draw_line(point - Vector2(5, 5), point + Vector2(5, 5), color, 2)
			draw_line(point - Vector2(5, -5), point + Vector2(5, -5), color, 2)
