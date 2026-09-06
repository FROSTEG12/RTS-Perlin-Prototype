class_name MapRenderer3D
extends Node3D

const CELL_SIZE := 1.0
const LAND_Y := 0.0
const WATER_Y := -0.16
const MAX_SEABED_DEPTH := 2.2
const WATER_SHADER := preload("res://shaders/water.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const GRASS_TEXTURE := preload("res://assets/tiles/grass_surface.png")
const CAUSTICS_TEXTURE := preload("res://assets/water/caustics_pack/caustics/caust00.png")

const RESOURCE_COLORS := {
	"tree": Color("205b38"),
	"stone": Color("d2d5cc"),
	"iron": Color("d96b45"),
	"food": Color("ff78b4"),
}

var cells := PackedByteArray()
var map_size := 0
var resources: Array[Dictionary] = []
var water_depths := PackedFloat32Array()
var water_depth_texture: ImageTexture
var water_material: ShaderMaterial

@onready var terrain: MeshInstance3D = $Terrain
@onready var seabed: MeshInstance3D = $Seabed
@onready var water: MeshInstance3D = $Water
@onready var resource_root: Node3D = $Resources


func _process(_delta: float) -> void:
	if water_material == null:
		return
	var active_camera := get_viewport().get_camera_3d()
	if active_camera != null and active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		water_material.set_shader_parameter("camera_ortho_size", active_camera.size)


func set_world(new_cells: PackedByteArray, new_size: int, new_resources: Array[Dictionary]) -> void:
	cells = new_cells
	map_size = new_size
	resources = new_resources
	water_depths = _build_water_depths()
	water_depth_texture = _create_water_depth_texture()
	_build_terrain()
	_build_seabed()
	_build_water()
	_build_resources()


func cell_to_world(cell_x: int, cell_y: int) -> Vector3:
	var center := (map_size - 1) * 0.5
	return Vector3((cell_x - center) * CELL_SIZE, LAND_Y + 0.10, (cell_y - center) * CELL_SIZE)


func world_to_cell(world_position: Vector3) -> Vector2i:
	var center := (map_size - 1) * 0.5
	return Vector2i(
		roundi(world_position.x / CELL_SIZE + center),
		roundi(world_position.z / CELL_SIZE + center)
	)


func is_land(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size or cell.y >= map_size:
		return false
	return cells[cell.y * map_size + cell.x] == 0


func get_half_extent() -> float:
	return map_size * CELL_SIZE * 0.5


func _build_terrain() -> void:
	terrain.mesh = _build_cell_mesh(false, LAND_Y)
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	material.set_shader_parameter("grass_texture", GRASS_TEXTURE)
	terrain.material_override = material


func _build_seabed() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := (map_size - 1) * 0.5
	for y in range(map_size):
		for x in range(map_size):
			if cells[y * map_size + x] == 0:
				continue
			var depth := 0.20 + water_depths[y * map_size + x] * MAX_SEABED_DEPTH
			_append_quad(
				vertices, normals, uvs, indices,
				Vector3((x - center) * CELL_SIZE, WATER_Y - depth, (y - center) * CELL_SIZE),
				CELL_SIZE, depth / MAX_SEABED_DEPTH
			)
	seabed.mesh = _arrays_to_mesh(vertices, normals, uvs, indices)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("82917a")
	material.roughness = 1.0
	seabed.material_override = material


func _build_water() -> void:
	# Dense enough to keep vertex-displaced waves smooth at the closest camera zoom.
	var subdivisions := 8
	var step := CELL_SIZE / subdivisions
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := (map_size - 1) * 0.5
	for cell_y in range(map_size):
		for cell_x in range(map_size):
			if cells[cell_y * map_size + cell_x] == 0 and not _touches_water(cell_x, cell_y):
				continue
			for sub_y in range(subdivisions):
				for sub_x in range(subdivisions):
					var world_x := (cell_x - center) * CELL_SIZE + (sub_x + 0.5) * step - CELL_SIZE * 0.5
					var world_z := (cell_y - center) * CELL_SIZE + (sub_y + 0.5) * step - CELL_SIZE * 0.5
					_append_quad(
						vertices, normals, uvs, indices,
						Vector3(world_x, WATER_Y, world_z), step, 0.0
					)
	water.mesh = _arrays_to_mesh(vertices, normals, uvs, indices)
	water_material = ShaderMaterial.new()
	water_material.shader = WATER_SHADER
	water_material.set_shader_parameter("caustics_texture", CAUSTICS_TEXTURE)
	water_material.set_shader_parameter("map_depth_texture", water_depth_texture)
	water_material.set_shader_parameter("map_world_size", map_size * CELL_SIZE)
	water_material.set_shader_parameter("water_level", WATER_Y)
	water.material_override = water_material


func _touches_water(cell_x: int, cell_y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = Vector2i(cell_x, cell_y) + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size or neighbor.y >= map_size:
			continue
		if cells[neighbor.y * map_size + neighbor.x] == 1:
			return true
	return false


func _build_resources() -> void:
	for child in resource_root.get_children():
		child.free()
	for kind in RESOURCE_COLORS:
		var positions: Array[Vector3] = []
		for resource in resources:
			if resource["kind"] == kind:
				positions.append(cell_to_world(int(resource["x"]), int(resource["y"])))
		if positions.is_empty():
			continue
		var marker_mesh := CylinderMesh.new()
		marker_mesh.top_radius = 0.10 if kind != "tree" else 0.13
		marker_mesh.bottom_radius = marker_mesh.top_radius
		marker_mesh.height = 0.13 if kind != "tree" else 0.20
		marker_mesh.radial_segments = 8
		var marker_material := StandardMaterial3D.new()
		marker_material.albedo_color = RESOURCE_COLORS[kind]
		marker_material.roughness = 0.72
		marker_mesh.material = marker_material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = marker_mesh
		multimesh.instance_count = positions.size()
		for index in range(positions.size()):
			var marker_position := positions[index]
			marker_position.y += marker_mesh.height * 0.5
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, marker_position))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		resource_root.add_child(instance)


func _build_cell_mesh(water_cells: bool, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := (map_size - 1) * 0.5
	for y in range(map_size):
		for x in range(map_size):
			var is_water := cells[y * map_size + x] == 1
			if is_water != water_cells:
				continue
			_append_quad(
				vertices, normals, uvs, indices,
				Vector3((x - center) * CELL_SIZE, height, (y - center) * CELL_SIZE),
				CELL_SIZE, 0.0
			)
	return _arrays_to_mesh(vertices, normals, uvs, indices)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	size: float,
	uv_value: float
) -> void:
	var half := size * 0.5
	var first := vertices.size()
	vertices.append_array(PackedVector3Array([
		center + Vector3(-half, 0.0, -half),
		center + Vector3(half, 0.0, -half),
		center + Vector3(half, 0.0, half),
		center + Vector3(-half, 0.0, half),
	]))
	for _index in range(4):
		normals.append(Vector3.UP)
	uvs.append_array(PackedVector2Array([
		Vector2(0.0, uv_value), Vector2(1.0, uv_value),
		Vector2(1.0, uv_value), Vector2(0.0, uv_value),
	]))
	indices.append_array(PackedInt32Array([
		first, first + 2, first + 1,
		first, first + 3, first + 2,
	]))


func _arrays_to_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_water_depths() -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	distances.resize(map_size * map_size)
	var far := float(map_size * 2)
	for y in range(map_size):
		for x in range(map_size):
			var index := y * map_size + x
			distances[index] = 0.0 if cells[index] == 0 else far
	for y in range(map_size):
		for x in range(map_size):
			var index := y * map_size + x
			if cells[index] == 0:
				continue
			if x > 0: distances[index] = minf(distances[index], distances[index - 1] + 1.0)
			if y > 0: distances[index] = minf(distances[index], distances[index - map_size] + 1.0)
	for y in range(map_size - 1, -1, -1):
		for x in range(map_size - 1, -1, -1):
			var index := y * map_size + x
			if cells[index] == 0:
				continue
			if x < map_size - 1: distances[index] = minf(distances[index], distances[index + 1] + 1.0)
			if y < map_size - 1: distances[index] = minf(distances[index], distances[index + map_size] + 1.0)
	for index in range(distances.size()):
		distances[index] = clampf((distances[index] - 1.0) / 7.0, 0.0, 1.0)
	return distances


func _create_water_depth_texture() -> ImageTexture:
	const RESOLUTION := 4
	var texture_size := map_size * RESOLUTION
	var distances := PackedFloat32Array()
	distances.resize(texture_size * texture_size)
	var far := float(texture_size * 2)
	for y in range(texture_size):
		for x in range(texture_size):
			var cell_x: int = x / RESOLUTION
			var cell_y: int = y / RESOLUTION
			distances[y * texture_size + x] = 0.0 if cells[cell_y * map_size + cell_x] == 0 else far
	var diagonal := 1.41421356
	for y in range(texture_size):
		for x in range(texture_size):
			var index := y * texture_size + x
			if distances[index] == 0.0:
				continue
			if x > 0: distances[index] = minf(distances[index], distances[index - 1] + 1.0)
			if y > 0:
				distances[index] = minf(distances[index], distances[index - texture_size] + 1.0)
				if x > 0: distances[index] = minf(distances[index], distances[index - texture_size - 1] + diagonal)
				if x < texture_size - 1: distances[index] = minf(distances[index], distances[index - texture_size + 1] + diagonal)
	for y in range(texture_size - 1, -1, -1):
		for x in range(texture_size - 1, -1, -1):
			var index := y * texture_size + x
			if distances[index] == 0.0:
				continue
			if x < texture_size - 1: distances[index] = minf(distances[index], distances[index + 1] + 1.0)
			if y < texture_size - 1:
				distances[index] = minf(distances[index], distances[index + texture_size] + 1.0)
				if x > 0: distances[index] = minf(distances[index], distances[index + texture_size - 1] + diagonal)
				if x < texture_size - 1: distances[index] = minf(distances[index], distances[index + texture_size + 1] + diagonal)
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	for y in range(texture_size):
		for x in range(texture_size):
			var distance := distances[y * texture_size + x]
			var value := clampf((distance - 0.5) / (7.0 * RESOLUTION), 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)
