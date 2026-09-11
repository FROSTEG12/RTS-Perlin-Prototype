extends PanelContainer
## Non-modal window: header drag, persistent position, local input barrier.
var world: Node3D
var header: HBoxContainer
var close_button: Button
var window_dragging := false
var drag_offset := Vector2.ZERO
var positioned := false

func setup_header(title: Label, rows: VBoxContainer, close_action: Callable) -> void:
	mouse_force_pass_scroll_events = false
	header = HBoxContainer.new()
	header.mouse_filter = MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = CURSOR_MOVE
	rows.add_child(header)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = Button.new()
	close_button.text = "×"
	close_button.add_theme_font_size_override("font_size",24)
	close_button.custom_minimum_size = Vector2(34,34)
	close_button.focus_mode = FOCUS_NONE
	close_button.tooltip_text = "Закрыть"
	close_button.pressed.connect(func(): window_dragging = false; close_action.call())
	header.add_child(close_button)
	header.gui_input.connect(_header_input)

func bring_forward() -> void:
	# Reorder only the two floating windows, never above pause/developer menus.
	get_parent().move_child(self,get_parent().get_child_count()-1)

func clamp_to_screen() -> void:
	var bounds: Vector2 = world.hud.size
	position = position.clamp(Vector2(10,10),(bounds-size-Vector2(10,10)).max(Vector2(10,10)))

func _header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		window_dragging = event.pressed
		drag_offset = header.global_position+event.position-global_position
		world.rts.cancel_drag()
		world.game_camera.dragging = false
		header.accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if window_dragging:
		if event is InputEventMouseMotion:
			global_position = event.position-drag_offset
			positioned = true
			clamp_to_screen()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			window_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and is_ancestor_of(focus) and not focus.get_global_rect().has_point(event.position):
			focus.release_focus()
		# Only the topmost floating window under the pointer receives focus.
		if get_global_rect().has_point(event.position):
			for sibling in get_parent().get_children():
				if sibling is PanelContainer and sibling.has_method("bring_forward") and sibling.get_index()>get_index() and sibling.visible and sibling.get_global_rect().has_point(event.position): return
			bring_forward()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: window_dragging = false
