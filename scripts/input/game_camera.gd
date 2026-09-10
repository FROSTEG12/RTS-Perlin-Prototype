class_name IsometricGameCamera
extends Camera3D

const MIN_SIZE := 9.0
const MAX_SIZE := 42.0
const ZOOM_STEP := 1.10
const CAMERA_HEIGHT := 18.0
const EDGE_MARGIN := 20.0
const EDGE_SPEED := 0.65 # Visible camera heights per second, independent of zoom/FPS.

var dragging := false
var map_half_extent := 52.0
var controls_blocked := false
var window_focused := true


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 22.0
	position = Vector3(10.5, CAMERA_HEIGHT, 10.5)
	look_at(Vector3.ZERO, Vector3.UP)


func _process(delta: float) -> void:
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		dragging = false
	if controls_blocked or not window_focused:
		dragging = false
	elif not dragging and get_window().has_focus() and not get_tree().paused:
		# Never scroll behind interactive UI, or after the pointer leaves the window.
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			var direction := edge_direction(get_viewport().get_mouse_position(), get_viewport().get_visible_rect())
			_move_on_ground(direction * size * EDGE_SPEED * delta)
	_clamp_position()


func edge_direction(point: Vector2, rect: Rect2) -> Vector2:
	if not rect.has_point(point):
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if point.x < rect.position.x + EDGE_MARGIN: direction.x = -1.0
	elif point.x >= rect.end.x - EDGE_MARGIN: direction.x = 1.0
	if point.y < rect.position.y + EDGE_MARGIN: direction.y = 1.0
	elif point.y >= rect.end.y - EDGE_MARGIN: direction.y = -1.0
	return direction.normalized()


func focus_on(point: Vector3) -> void:
	global_position = Vector3(point.x, 0.0, point.z) + global_basis.z * (CAMERA_HEIGHT / global_basis.z.y)
	_clamp_position()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true


func _unhandled_input(event: InputEvent) -> void:
	if controls_blocked or not window_focused or get_tree().paused:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_size(size / ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_size(size * ZOOM_STEP)
	elif event is InputEventMouseMotion and dragging:
		var drag_scale: float = size / get_viewport().get_visible_rect().size.y
		_move_on_ground(Vector2(-event.relative.x, event.relative.y) * drag_scale * 1.45)
		get_viewport().set_input_as_handled()


func configure_map(half_extent: float) -> void:
	map_half_extent = half_extent
	_clamp_position()


func screen_to_ground(screen_position: Vector2, ground_y: float = 0.0) -> Vector3:
	var ray_origin := project_ray_origin(screen_position)
	var ray_direction := project_ray_normal(screen_position)
	var denominator := ray_direction.y
	if absf(denominator) < 0.0001:
		return Vector3.INF
	var distance := (ground_y - ray_origin.y) / denominator
	return ray_origin + ray_direction * distance


func _set_size(new_size: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var before := screen_to_ground(mouse_position)
	size = clampf(new_size, MIN_SIZE, MAX_SIZE)
	var after := screen_to_ground(mouse_position)
	if before.is_finite() and after.is_finite():
		position += before - after
	_clamp_position()
	get_viewport().set_input_as_handled()


func _move_on_ground(input: Vector2) -> void:
	var screen_right := global_transform.basis.x
	var screen_up := global_transform.basis.y
	var right_ground := Vector3(screen_right.x, 0.0, screen_right.z).normalized()
	var up_ground := Vector3(screen_up.x, 0.0, screen_up.z).normalized()
	position += right_ground * input.x + up_ground * input.y


func _clamp_position() -> void:
	global_position.y = CAMERA_HEIGHT
	# Limit the ground point at screen center, not the elevated camera body.
	# The isometric camera sits ~10.5 units away from its ground focus on X/Z.
	# Shrinking the body bounds with zoom made the near corner unreachable.
	var back := global_basis.z
	if absf(back.y) < 0.0001:
		return
	var focus := global_position - back * (global_position.y / back.y)
	global_position.x += clampf(focus.x, -map_half_extent, map_half_extent) - focus.x
	global_position.z += clampf(focus.z, -map_half_extent, map_half_extent) - focus.z
