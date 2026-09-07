class_name TestUnit3D
extends Node3D

const MOVE_SPEED := 2.25
const PATH_COLOR := Color(1.0, 0.73, 0.08, 0.92)

var grid_cell := Vector2i.ZERO
var target_cells: Array[Vector2i] = []
var target_positions: Array[Vector3] = []
var trail_wear: Node

func set_trail_wear(provider: Node) -> void:
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())
	trail_wear = provider

func _exit_tree() -> void:
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())

@onready var visual: Node3D = $Visual
@onready var path_preview: MultiMeshInstance3D = $PathPreview


func _ready() -> void:
	_rebuild_path_preview()


func place_on_cell(cell: Vector2i, world_position: Vector3) -> void:
	if is_instance_valid(trail_wear): trail_wear.forget_unit(get_instance_id())
	grid_cell = cell
	position = world_position
	target_cells.clear()
	target_positions.clear()
	visual.reset_pose()
	_rebuild_path_preview()


func follow_path(path: Array[Vector2i], renderer: MapRenderer3D) -> void:
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
	position = position.move_toward(target_positions[0], MOVE_SPEED * delta)
	visual.set_motion((position - local_before) / maxf(delta, 0.00001), delta)
	if position.distance_squared_to(target_positions[0]) <= 0.0001:
		position = target_positions[0]
		grid_cell = target_cells[0]
		target_positions.remove_at(0)
		target_cells.remove_at(0)
	if is_instance_valid(trail_wear):
		trail_wear.record_movement(get_instance_id(), before, global_position)
	_rebuild_path_preview()


func _rebuild_path_preview() -> void:
	if not is_node_ready():
		return
	var points: Array[Vector3] = []
	var start := Vector3.ZERO
	for target_world in target_positions:
		var finish := target_world - position
		var length := start.distance_to(finish)
		var direction := start.direction_to(finish) if length > 0.001 else Vector3.ZERO
		var cursor := 0.20
		while cursor < length:
			var point := start + direction * cursor
			point.y = 0.035
			points.append(point)
			cursor += 0.28
		start = finish
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.035
	dot_mesh.height = 0.07
	dot_mesh.radial_segments = 6
	dot_mesh.rings = 3
	var dot_material := StandardMaterial3D.new()
	dot_material.albedo_color = PATH_COLOR
	dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mesh.material = dot_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot_mesh
	multimesh.instance_count = points.size()
	for index in range(points.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
	path_preview.multimesh = multimesh
