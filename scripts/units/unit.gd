class_name Unit3D
extends Node3D

const MOVE_SPEED := 2.25
const PATH_COLOR := Color(1.0, 0.73, 0.08, 0.92)

var grid_cell := Vector2i.ZERO
var move_speed := MOVE_SPEED
var display_name := "Рыцарь"
var target_cells: Array[Vector2i] = []
var target_positions: Array[Vector3] = []
var trail_wear: Node
var selected := false
var hovered := false
var order_revision := 0
var move_orders: Array[Vector2i] = []
var preview_dirty := true
var preview_capacity := 0
static var shared_dot_mesh: SphereMesh

func set_trail_wear(provider: Node) -> void:
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())
	trail_wear = provider

func _exit_tree() -> void:
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())

@onready var visual: Node3D = $Visual
@onready var path_preview: MultiMeshInstance3D = $PathPreview


func _ready() -> void:
	add_to_group("rts_units")
	path_preview.top_level = true
	path_preview.global_transform = Transform3D.IDENTITY
	if shared_dot_mesh == null:
		shared_dot_mesh = SphereMesh.new()
		shared_dot_mesh.radius = 0.035
		shared_dot_mesh.height = 0.07
		shared_dot_mesh.radial_segments = 6
		shared_dot_mesh.rings = 3
		var material := StandardMaterial3D.new()
		material.albedo_color = PATH_COLOR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_dot_mesh.material = material
	path_preview.multimesh = MultiMesh.new()
	path_preview.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	path_preview.multimesh.mesh = shared_dot_mesh
	set_selected(false)


func set_selected(value: bool) -> void:
	selected = value
	_update_ring()
	path_preview.visible = value
	if value:
		_rebuild_path_preview()


func set_hovered(value: bool) -> void:
	hovered = value
	_update_ring()


func _update_ring() -> void:
	$SelectionRing.visible = selected or hovered
	$SelectionRing.scale = Vector3.ONE * (1.0 if selected else 1.15)


func order_anchor(renderer: MapRenderer3D, queued: bool) -> Vector2i:
	if not target_cells.is_empty():
		return target_cells.back() if queued else target_cells.front()
	return renderer.world_to_cell(global_position)


func accept_move(path: Array[Vector2i], renderer: MapRenderer3D, queued: bool) -> bool:
	if path.is_empty() or (queued and move_orders.size() >= 32):
		return false
	if queued and not move_orders.is_empty() and move_orders.back() == path.back():
		return true
	if queued and not target_cells.is_empty():
		for index in range(1, path.size()):
			target_cells.append(path[index])
			target_positions.append(renderer.cell_to_world(path[index].x, path[index].y))
	else:
		follow_path(path, renderer)
	if not target_cells.is_empty():
		move_orders.append(path.back())
	preview_dirty = true
	_rebuild_path_preview()
	return true


func stop_orders(renderer: MapRenderer3D) -> void:
	order_revision += 1
	target_cells.clear()
	target_positions.clear()
	move_orders.clear()
	grid_cell = renderer.world_to_cell(global_position)
	visual.set_motion(Vector3.ZERO, 0.016)
	preview_dirty = true
	_rebuild_path_preview()


func place_on_cell(cell: Vector2i, world_position: Vector3) -> void:
	order_revision += 1
	move_orders.clear()
	preview_dirty = true
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())
	grid_cell = cell
	position = world_position
	target_cells.clear()
	target_positions.clear()
	visual.reset_pose()
	_rebuild_path_preview()


func follow_path(path: Array[Vector2i], renderer: MapRenderer3D) -> void:
	move_orders.clear()
	preview_dirty = true
	target_cells.clear()
	target_positions.clear()
	if path.is_empty():
		_rebuild_path_preview()
		return
	var first_position := renderer.cell_to_world(path[0].x, path[0].y)
	var first_index := 0
	if position.distance_squared_to(first_position) <= 0.0001:
		grid_cell = path[0]
		first_index = 1
	for index in range(first_index, path.size()):
		target_cells.append(path[index])
		target_positions.append(renderer.cell_to_world(path[index].x, path[index].y))
	_rebuild_path_preview()


func nearest_route_cell(renderer: MapRenderer3D) -> Vector2i:
	if target_cells.is_empty():
		return grid_cell
	var current_center := renderer.cell_to_world(grid_cell.x, grid_cell.y)
	if position.distance_squared_to(target_positions[0]) < position.distance_squared_to(current_center):
		return target_cells[0]
	return grid_cell


func cancel_movement(renderer: MapRenderer3D) -> void:
	order_revision += 1
	move_orders.clear()
	preview_dirty = true
	var stop_cell := nearest_route_cell(renderer)
	var stop_position := renderer.cell_to_world(stop_cell.x, stop_cell.y)
	target_cells.clear()
	target_positions.clear()
	if position.distance_squared_to(stop_position) <= 0.0001:
		position = stop_position
		grid_cell = stop_cell
	else:
		target_cells.append(stop_cell)
		target_positions.append(stop_position)
	_rebuild_path_preview()


func _process(delta: float) -> void:
	if target_positions.is_empty():
		visual.set_motion(Vector3.ZERO, delta)
		return
	var before := global_position
	var local_before := position
	var remaining := move_speed * delta
	while remaining > 0.0 and not target_positions.is_empty():
		var distance := position.distance_to(target_positions[0])
		var next := position.move_toward(target_positions[0], remaining)
		position = next
		remaining -= distance
		if position.distance_squared_to(target_positions[0]) > 0.0001:
			break
		position = target_positions.pop_front()
		grid_cell = target_cells.pop_front()
		if not move_orders.is_empty() and grid_cell == move_orders.front():
			move_orders.pop_front()
		preview_dirty = true
	visual.set_motion((position - local_before) / maxf(delta, 0.00001), delta)
	if is_instance_valid(trail_wear):
		trail_wear.record_movement(get_instance_id(), before, global_position)
	_rebuild_path_preview()



func _rebuild_path_preview() -> void:
	if not is_node_ready() or not selected or not preview_dirty:
		return
	preview_dirty = false
	var points: Array[Vector3] = []
	var start := position
	for target_world in target_positions:
		var finish := target_world
		var length := start.distance_to(finish)
		var direction := start.direction_to(finish) if length > 0.001 else Vector3.ZERO
		var cursor := 0.20
		while cursor < length and points.size() < 4096:
			var point := start + direction * cursor
			point.y += 0.035
			points.append(get_parent().to_global(point))
			cursor += 0.28
		start = finish
	var multimesh := path_preview.multimesh
	if points.size() > preview_capacity:
		preview_capacity = maxi(64, preview_capacity)
		while preview_capacity < points.size():
			preview_capacity *= 2
		multimesh.instance_count = preview_capacity
	multimesh.visible_instance_count = points.size()
	for index in range(points.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
