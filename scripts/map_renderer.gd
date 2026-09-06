class_name MapRenderer3D
extends Node3D

const CELL_SIZE := 1.0
const LAND_Y := 0.0
const WATER_Y := -0.16
const MAX_SEABED_DEPTH := 2.2
const COAST_SUBDIVISIONS := 4
const COAST_THRESHOLD := 0.5
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
	terrain.mesh = _build_smooth_land_mesh()
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	material.set_shader_parameter("grass_texture", GRASS_TEXTURE)
	material.set_shader_parameter("shore_distance_texture", water_depth_texture)
	material.set_shader_parameter("map_world_size", map_size * CELL_SIZE)
	terrain.material_override = material


func _build_smooth_land_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var fine_size := map_size * COAST_SUBDIVISIONS
	var step := CELL_SIZE / COAST_SUBDIVISIONS
	var map_min := -map_size * CELL_SIZE * 0.5
	var density_grid := PackedFloat32Array()
	density_grid.resize((fine_size + 1) * (fine_size + 1))
	for grid_y in range(fine_size + 1):
		for grid_x in range(fine_size + 1):
			var sample_x := map_min + grid_x * step
			var sample_z := map_min + grid_y * step
			density_grid[grid_y * (fine_size + 1) + grid_x] = _sample_land_density(sample_x, sample_z)
	for fine_y in range(fine_size):
		for fine_x in range(fine_size):
			var x0 := map_min + fine_x * step
			var z0 := map_min + fine_y * step
			var x1 := x0 + step
			var z1 := z0 + step
			var polygon: Array[Vector3] = [
				Vector3(x0, LAND_Y, z0),
				Vector3(x1, LAND_Y, z0),
				Vector3(x1, LAND_Y, z1),
				Vector3(x0, LAND_Y, z1),
			]
			var values: Array[float] = [
				density_grid[fine_y * (fine_size + 1) + fine_x],
				density_grid[fine_y * (fine_size + 1) + fine_x + 1],
				density_grid[(fine_y + 1) * (fine_size + 1) + fine_x + 1],
				density_grid[(fine_y + 1) * (fine_size + 1) + fine_x],
			]
			var clipped := _clip_density_polygon(polygon, values)
			if clipped.size() < 3:
				continue
			var first := vertices.size()
			for point in clipped:
				var terrain_point := point
				var coast_density := _sample_land_density(point.x, point.z)
				var beach_rise := smoothstep(COAST_THRESHOLD, 0.76, coast_density)
				terrain_point.y = lerpf(WATER_Y - 0.035, LAND_Y, beach_rise)
				vertices.append(terrain_point)
				normals.append(Vector3.UP)
				uvs.append(Vector2(point.x, point.z) * 0.095)
			for triangle_index in range(1, clipped.size() - 1):
				indices.append_array(PackedInt32Array([
					first, first + triangle_index + 1, first + triangle_index,
				]))
	return _arrays_to_mesh(vertices, normals, uvs, indices)


func _clip_density_polygon(points: Array[Vector3], values: Array[float]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index in range(points.size()):
		var previous_index := (index - 1 + points.size()) % points.size()
		var previous_point := points[previous_index]
		var current_point := points[index]
		var previous_value := values[previous_index]
		var current_value := values[index]
		var previous_inside := previous_value >= COAST_THRESHOLD
		var current_inside := current_value >= COAST_THRESHOLD
		if previous_inside != current_inside:
			var amount := (COAST_THRESHOLD - previous_value) / (current_value - previous_value)
			result.append(previous_point.lerp(current_point, amount))
		if current_inside:
			result.append(current_point)
	return result


func _sample_land_density(world_x: float, world_z: float) -> float:
	var center := (map_size - 1) * 0.5
	var warp_x := sin(world_z * 0.37 + world_x * 0.11) * 0.13 + sin(world_z * 0.83 - world_x * 0.19) * 0.045
	var warp_z := sin(world_x * 0.41 - world_z * 0.09) * 0.13 + sin(world_x * 0.91 + world_z * 0.17) * 0.045
	var grid_x := (world_x + warp_x) / CELL_SIZE + center
	var grid_y := (world_z + warp_z) / CELL_SIZE + center
	var base_x := floori(grid_x)
	var base_y := floori(grid_y)
	var weights_x := _cubic_weights(grid_x - base_x)
	var weights_y := _cubic_weights(grid_y - base_y)
	var density := 0.0
	for offset_y in range(4):
		for offset_x in range(4):
			density += _land_value(base_x + offset_x - 1, base_y + offset_y - 1) * weights_x[offset_x] * weights_y[offset_y]
	return density


func _cubic_weights(amount: float) -> PackedFloat32Array:
	var amount_squared := amount * amount
	var amount_cubed := amount_squared * amount
	return PackedFloat32Array([
		pow(1.0 - amount, 3.0) / 6.0,
		(3.0 * amount_cubed - 6.0 * amount_squared + 4.0) / 6.0,
		(-3.0 * amount_cubed + 3.0 * amount_squared + 3.0 * amount + 1.0) / 6.0,
		amount_cubed / 6.0,
	])


func _land_value(cell_x: int, cell_y: int) -> float:
	if cell_x < 0 or cell_y < 0 or cell_x >= map_size or cell_y >= map_size:
		return 0.0
	return 1.0 if cells[cell_y * map_size + cell_x] == 0 else 0.0


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
	for offset in [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]:
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
	var water_distances := PackedFloat32Array()
	var land_distances := PackedFloat32Array()
	water_distances.resize(texture_size * texture_size)
	land_distances.resize(texture_size * texture_size)
	var far := float(texture_size * 2)
	for y in range(texture_size):
		for x in range(texture_size):
			var world_x := (float(x) + 0.5) / RESOLUTION - map_size * 0.5
			var world_z := (float(y) + 0.5) / RESOLUTION - map_size * 0.5
			var is_visual_land := _sample_land_density(world_x, world_z) >= COAST_THRESHOLD
			water_distances[y * texture_size + x] = 0.0 if is_visual_land else far
			land_distances[y * texture_size + x] = far if is_visual_land else 0.0
	water_distances = _distance_transform(water_distances, texture_size)
	land_distances = _distance_transform(land_distances, texture_size)
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	for y in range(texture_size):
		for x in range(texture_size):
			var water_distance := water_distances[y * texture_size + x]
			var land_distance := land_distances[y * texture_size + x]
			var water_value := clampf((water_distance - 0.5) / (7.0 * RESOLUTION), 0.0, 1.0)
			var land_value := clampf((land_distance - 0.5) / (7.0 * RESOLUTION), 0.0, 1.0)
			image.set_pixel(x, y, Color(water_value, land_value, 0.0, 1.0))
	return ImageTexture.create_from_image(image)


func _distance_transform(source: PackedFloat32Array, texture_size: int) -> PackedFloat32Array:
	var distances := source
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
	return distances
