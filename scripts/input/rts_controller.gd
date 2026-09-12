extends Control
## Screen-space selection, with a world-space command interface beneath it.
const DRAG_THRESHOLD := 7.0
const CONTROL_GROUPS := preload("res://scripts/units/unit_control_groups.gd")
const SQUAD_BADGE := preload("res://assets/ui/army_emblems/infantry.png")
var world: Node3D
var orders: Node
var selected: Array[Unit3D] = []
var hovered: Unit3D
var hovered_members: Array[Unit3D] = []
var selecting := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var additive := false
var resource_area := false
var hover_timer := 0.0
var feedback_timer := 0.0
var feedback_point := Vector3.ZERO
var feedback_ok := true
var status: Label
var stop_button: Button
var focus_button: Button
var grid_button: CheckButton
var grid_overlay: MeshInstance3D
var command_panel: PanelContainer


func _ready() -> void:
	# UI artwork must not inherit the world's nearest/pixel-art sampling.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orders = preload("res://scripts/input/rts_orders.gd").new()
	orders.world = world
	add_child(orders)
	orders.result_received.connect(_feedback)
	grid_overlay = preload("res://scripts/ui/walkability_grid.gd").new()
	grid_overlay.world = world
	world.map_renderer.add_child(grid_overlay)
	var panel := PanelContainer.new()
	command_panel = panel
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
	return get_tree().get_nodes_in_group("rts_units").filter(func(unit): return world.vision == null or world.vision.can_observe(unit))


func set_selection(next: Array) -> void:
	if world.vision != null: next = next.filter(func(unit): return is_instance_valid(unit) and world.vision.can_observe(unit))
	var expanded := CONTROL_GROUPS.expand(next, units())
	for unit in selected:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected.clear()
	for unit in expanded:
		if is_instance_valid(unit) and unit not in selected:
			selected.append(unit)
			unit.set_selected(true)
	_update_status()

func select_unit(unit: Unit3D, additive: bool = false) -> void:
	var next: Array = selected.duplicate() if additive else []
	if additive and unit in next:
		for member in CONTROL_GROUPS.members(unit, units()): next.erase(member)
	else:
		next.append(unit)
	set_selection(next)


func reset() -> void:
	cancel_drag()
	set_selection([])
	_set_hover(null)
	orders.reset()
	feedback_timer = 0.0


func cancel_drag() -> void:
	selecting = false
	resource_area = false
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
	if world.placement != null and world.placement.active: return
	if event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit: return
	if world.is_generating or world.developer_tools.visible:
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
				resource_area = event.alt_pressed and not selected.is_empty()
			elif not event.pressed and selecting:
				drag_end = event.position
				_finish_selection()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()
			if not selected.is_empty():
				var point: Vector3 = world.game_camera.screen_to_ground(event.position, MapRenderer3D.LAND_Y)
				if point.is_finite():
					if orders.gathering.deposit_at(selected,point):
						get_viewport().set_input_as_handled()
						return
					var resource: Dictionary = orders.gathering.pick(event.position,point)
					if not resource.is_empty() and selected.any(func(unit): return unit.individual_control): orders.gathering.start(selected,resource)
					else: orders.move(selected, world.map_renderer.world_to_cell(point), event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			cancel_drag()
	elif event is InputEventMouseMotion and selecting:
		drag_end = event.position
		queue_redraw()


func unit_screen_rect(unit: Unit3D) -> Rect2:
	var feet: Vector2 = world.game_camera.unproject_position(unit.global_position)
	var head: Vector2 = world.game_camera.unproject_position(unit.global_position + Vector3.UP * 1.2)
	var width := maxf(12.0, feet.distance_to(head) * 0.34)
	return Rect2(Vector2(head.x - width, head.y - 5.0), Vector2(width * 2.0, maxf(18.0, feet.y - head.y + 10.0)))


func over_ui(point: Vector2) -> bool:
	return (world.developer_tools != null and world.developer_tools.contains(point)) or (world.hud != null and world.hud.contains(point)) or (world.pause_menu != null and world.pause_menu.visible)


func badge_rect(unit: Unit3D) -> Rect2:
	var anchor: Vector2 = world.game_camera.unproject_position(squad_center(unit) + Vector3.UP * 1.7)
	return Rect2(anchor - Vector2(22, 42), Vector2(44, 48))

func squad_center(unit: Unit3D) -> Vector3:
	var group := CONTROL_GROUPS.members(unit, units())
	var center := Vector3.ZERO
	for member in group: center += member.global_position
	return center / group.size() if not group.is_empty() else unit.global_position

func squad_leaders() -> Array[Unit3D]:
	var leaders: Array[Unit3D] = []
	var seen := {}
	for unit: Unit3D in units():
		if unit.individual_control or unit.squad_id <= 0 or seen.has(unit.squad_id): continue
		seen[unit.squad_id] = true
		leaders.append(unit)
	return leaders

func hit_unit(point: Vector2) -> Unit3D:
	for leader in squad_leaders():
		if leader.is_visible_in_tree() and not world.game_camera.is_position_behind(leader.global_position) and badge_rect(leader).has_point(point):
			return leader
	var result: Unit3D
	var nearest := INF
	for unit: Unit3D in units():
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
	if resource_area:
		orders.gathering.select_area(selected,Rect2(drag_start,drag_end-drag_start).abs())
		cancel_drag()
		return
	var next: Array = selected.duplicate() if additive else []
	if drag_start.distance_to(drag_end) < DRAG_THRESHOLD:
		var unit := hit_unit(drag_end)
		if unit != null:
			if additive and unit in next:
				for member in CONTROL_GROUPS.members(unit, units()): next.erase(member)
			else:
				next.append(unit)
	else:
		var rect := Rect2(drag_start, drag_end - drag_start).abs()
		for unit: Unit3D in units():
			if unit.is_visible_in_tree() and not world.game_camera.is_position_behind(unit.global_position) and rect.intersects(unit_screen_rect(unit)):
				next.append(unit)
	cancel_drag()
	set_selection(next)


func stop_selected() -> void:
	orders.stop(selected)
	_update_status()



func focus_selected() -> void:
	if selected.is_empty():
		return
	var center := Vector3.ZERO
	for unit in selected:
		center += unit.global_position
	world.game_camera.focus_on(center / selected.size())


func _set_hover(unit: Unit3D) -> void:
	for member in hovered_members:
		if is_instance_valid(member): member.set_hovered(false)
	hovered = unit
	hovered_members = CONTROL_GROUPS.members(unit, units())
	for member in hovered_members: member.set_hovered(true)


func _process(delta: float) -> void:
	queue_redraw()
	var surviving: Array[Unit3D] = []
	for unit in selected:
		if not is_instance_valid(unit): continue
		if world.vision != null and not world.vision.can_observe(unit): unit.set_selected(false)
		else: surviving.append(unit)
	if surviving.size() != selected.size():
		selected = surviving
		_update_status()
	hover_timer -= delta
	if hover_timer <= 0.0:
		hover_timer = 0.08
		var over_ui := get_viewport().gui_get_hovered_control() != null
		_set_hover(null if over_ui or selecting else hit_unit(get_viewport().get_mouse_position()))
	if feedback_timer > 0.0:
		feedback_timer = maxf(0.0, feedback_timer - delta)
		queue_redraw()
		if feedback_timer == 0.0:
			_update_status()


func _feedback(ok: bool, point: Vector3, message: String) -> void:
	feedback_point = point
	feedback_ok = ok
	# Each soldier reports path acceptance: don't flash a destination ring per job.
	feedback_timer = 0.0 if ok else 1.0
	status.text = message
	queue_redraw()


func _update_status() -> void:
	if world.hud != null: world.hud.skill_slots.sync_active()
	if status == null:
		return
	status.text = "Выделено бойцов: %d" % selected.size() if not selected.is_empty() else "Выбери отряд левой кнопкой"
	if selected.size() == 1:
		status.text = selected[0].display_name
	stop_button.disabled = selected.is_empty()
	focus_button.disabled = selected.is_empty()


func _draw() -> void:
	if world == null: return
	# One representative actual path, not a misleading line across water.
	for unit in selected:
		if not is_instance_valid(unit) or unit.target_positions.is_empty(): continue
		if world.vision != null and not world.vision.can_observe(unit): continue
		var points := PackedVector2Array([world.game_camera.unproject_position(unit.global_position)])
		for target in unit.target_positions:
			points.append(world.game_camera.unproject_position(unit.get_parent().to_global(target)))
		if points.size() > 1:
			draw_polyline(points, Color(0.55, 0.8, 0.95, 0.65), 1.5, true)
			draw_arc(points[points.size() - 1], 7, 0, TAU, 24, Color(0.8, 0.9, 1), 2, true)
		break
	# Shared screen-space geometry for drawing and clicking each squad standard.
	for leader in squad_leaders():
		if not leader.is_visible_in_tree() or world.game_camera.is_position_behind(leader.global_position): continue
		var rect := badge_rect(leader)
		var active := leader in selected
		var lit := active or leader in hovered_members
		var p := rect.position
		var polygon := PackedVector2Array([p + Vector2(22, 0), p + Vector2(43, 10), p + Vector2(43, 36), p + Vector2(22, 48), p + Vector2(1, 36), p + Vector2(1, 10)])
		draw_colored_polygon(polygon, Color("#285ca0") if lit else Color("#204a83"))
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color.WHITE, 2.5 if active else 1.5, true)
		draw_texture_rect(SQUAD_BADGE, Rect2(p + Vector2(4, 3), Vector2(36, 42)), false)
	if selecting and drag_start.distance_to(drag_end) >= DRAG_THRESHOLD:
		var rect := Rect2(drag_start, drag_end - drag_start).abs()
		draw_rect(rect, Color(0.65, 0.85, 0.55, 0.13), true)
		draw_rect(rect, Color(0.75, 0.95, 0.60, 0.9), false, 1.5)
	if feedback_timer > 0.0 and not feedback_ok and world != null:
		var point: Vector2 = world.game_camera.unproject_position(feedback_point)
		var color := Color(1.0, 0.3, 0.2, feedback_timer)
		if not feedback_ok:
			draw_line(point - Vector2(5, 5), point + Vector2(5, 5), color, 2)
			draw_line(point - Vector2(5, -5), point + Vector2(5, -5), color, 2)
