class_name MapRenderer3D
extends Node3D

const CELL_SIZE := 1.0
const LAND_Y := 0.0
const WATER_Y := -0.16
const MAX_SEABED_DEPTH := 2.2
const COAST_SUBDIVISIONS := 4
const SEABED_SUBDIVISIONS := 6
const GROUND_SUBDIVISIONS := 10
const COAST_THRESHOLD := 0.5
const WATER_SHADER := preload("res://shaders/water.gdshader")
const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const TERRAIN_SHADOW_RECEIVER_SHADER := preload("res://shaders/terrain_shadow_receiver.gdshader")
const GRASS_TEXTURE := preload("res://assets/tiles/grass_surface.png")
const TRAIL_SOIL_TEXTURE := preload("res://assets/world_edge/soil_albedo.png")
const TREE_RESOURCES := preload("res://scripts/world/tree_resources.gd")
const WORLD_EDGE := preload("res://scripts/world/world_edge.gd")
const CAUSTICS_TEXTURE := preload("res://assets/water/caustics_pack/caustics/caust00.png")

const RESOURCE_COLORS := {
	"tree": Color("205b38"),
	"stone": Color("d2d5cc"),
	"iron": Color("d96b45"),
	"food": Color("ff78b4"),
	"coal": Color("343b46"),
}

var cells := PackedByteArray()
var map_size := 0
var resources: Array[Dictionary] = []
var visual_water_depths := PackedFloat32Array()
var visual_land_depths := PackedFloat32Array()
var generated_seabed_depths := PackedFloat32Array()
var depth_field_resolution := 1
var water_depth_texture: ImageTexture
var terrain_material: ShaderMaterial
var terrain_shadow_receiver_material: ShaderMaterial
var water_material: ShaderMaterial
var trail_wear := preload("res://scripts/effects/trail_wear.gd").new()

@onready var terrain: MeshInstance3D = $Terrain
@onready var terrain_shadow_receiver: MeshInstance3D = $TerrainShadowReceiver
@onready var seabed: MeshInstance3D = $Seabed
@onready var water: MeshInstance3D = $Water
@onready var resource_root: Node3D = $Resources


func _process(_delta: float) -> void:
	if water_material == null:
		return
	var active_camera := get_viewport().get_camera_3d()
	if active_camera != null and active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		water_material.set_shader_parameter("camera_ortho_size", active_camera.size)


func set_world(new_cells: PackedByteArray, new_size: int, new_resources: Array[Dictionary], bathymetry: Dictionary) -> void:
	cells = new_cells
	map_size = new_size
	resources = new_resources
	depth_field_resolution = int(bathymetry["resolution"])
	visual_water_depths = bathymetry["water_distance"]
	visual_land_depths = bathymetry["land_distance"]
	generated_seabed_depths = bathymetry["depth"]
	water_depth_texture = _create_water_depth_texture()
	if trail_wear.get_parent() == null:
		trail_wear.name = "TrailWear"
		add_child(trail_wear)
	trail_wear.configure(map_size * CELL_SIZE, cells, map_size)
	_build_terrain()
	# Terrain now includes the underwater shelf and basin as one continuous
	# surface. Keeping the legacy seabed would create a visible coastal seam.
	seabed.mesh = null
	_build_water()
	_build_resources()
	WORLD_EDGE.build(self)


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


func set_cloud_shadow_offset(offset: Vector2) -> void:
	if terrain_material != null:
		terrain_material.set_shader_parameter("cloud_shadow_offset", offset)
	if water_material != null:
		water_material.set_shader_parameter("cloud_shadow_offset", offset)
	var falling := get_node_or_null("WorldEdge/FallingWater") as MeshInstance3D
	if falling != null:
		falling.material_override.set_shader_parameter("cloud_shadow_offset", offset)


func _build_terrain() -> void:
	terrain.mesh = _build_continuous_ground_mesh()
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = GRASS_SHADER
	terrain_material.set_shader_parameter("grass_texture", GRASS_TEXTURE)
	terrain_material.set_shader_parameter("shore_distance_texture", water_depth_texture)
	terrain_material.set_shader_parameter("map_world_size", map_size * CELL_SIZE)
	terrain_material.set_shader_parameter("trail_wear_texture", trail_wear.texture)
	terrain_material.set_shader_parameter("trail_soil_texture", TRAIL_SOIL_TEXTURE)
	terrain.material_override = terrain_material
	terrain_shadow_receiver.mesh = terrain.mesh
	terrain_shadow_receiver_material = ShaderMaterial.new()
	terrain_shadow_receiver_material.shader = TERRAIN_SHADOW_RECEIVER_SHADER
	terrain_shadow_receiver_material.render_priority = 1
	terrain_shadow_receiver.material_override = terrain_shadow_receiver_material


func _build_continuous_ground_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var fine_size := map_size * GROUND_SUBDIVISIONS
	var row_size := fine_size + 1
	var step := CELL_SIZE / GROUND_SUBDIVISIONS
	var map_min := -map_size * CELL_SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(row_size * row_size)

	for grid_y in range(row_size):
		for grid_x in range(row_size):
			var world_x := map_min + grid_x * step
			var world_z := map_min + grid_y * step
			heights[grid_y * row_size + grid_x] = _ground_surface_y(world_x, world_z)

	for grid_y in range(row_size):
		for grid_x in range(row_size):
			var index := grid_y * row_size + grid_x
			var world_x := map_min + grid_x * step
			var world_z := map_min + grid_y * step
			vertices.append(Vector3(world_x, heights[index], world_z))
			uvs.append(Vector2(world_x, world_z) * 0.095)
			var left_x := maxi(0, grid_x - 1)
			var right_x := mini(fine_size, grid_x + 1)
			var down_y := maxi(0, grid_y - 1)
			var up_y := mini(fine_size, grid_y + 1)
			var height_left := heights[grid_y * row_size + left_x]
			var height_right := heights[grid_y * row_size + right_x]
			var height_down := heights[down_y * row_size + grid_x]
			var height_up := heights[up_y * row_size + grid_x]
			normals.append(Vector3(
				height_left - height_right,
				step * 2.0,
				height_down - height_up
			).normalized())

	for grid_y in range(fine_size):
		for grid_x in range(fine_size):
			var first := grid_y * row_size + grid_x
			indices.append_array(PackedInt32Array([
				first, first + row_size + 1, first + 1,
				first, first + row_size, first + row_size + 1,
			]))
	return _arrays_to_mesh(vertices, normals, uvs, indices)


func _ground_surface_y(world_x: float, world_z: float) -> float:
	var land_density := _sample_land_density(world_x, world_z)
	if land_density >= COAST_THRESHOLD:
		var beach_rise := smoothstep(COAST_THRESHOLD, 0.76, land_density)
		return lerpf(WATER_Y - 0.035, LAND_Y, beach_rise)
	# Generator bathymetry starts at exactly the same height at the waterline,
	# then continues downward. There is no second mesh and no vertical break.
	return WATER_Y - _sample_generated_field(generated_seabed_depths, world_x, world_z, 0.035)


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
	# Extend the last real sample; the map border is not an ocean coastline.
	cell_x = clampi(cell_x, 0, map_size - 1)
	cell_y = clampi(cell_y, 0, map_size - 1)
	return 1.0 if cells[cell_y * map_size + cell_x] == 0 else 0.0


func _build_seabed() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var fine_size := map_size * SEABED_SUBDIVISIONS
	var step := CELL_SIZE / SEABED_SUBDIVISIONS
	var map_min := -map_size * CELL_SIZE * 0.5
	var height_grid := PackedFloat32Array()
	height_grid.resize((fine_size + 1) * (fine_size + 1))
	for grid_y in range(fine_size + 1):
		for grid_x in range(fine_size + 1):
			var world_x := map_min + grid_x * step
			var world_z := map_min + grid_y * step
			height_grid[grid_y * (fine_size + 1) + grid_x] = _seabed_surface_y(world_x, world_z)
	# One shared grid gives the guide's subdivided-plane topology. It is both
	# smoother and cheaper than storing four disconnected vertices per quad.
	var row_size := fine_size + 1
	for grid_y in range(row_size):
		for grid_x in range(row_size):
			var grid_index := grid_y * row_size + grid_x
			var world_x := map_min + grid_x * step
			var world_z := map_min + grid_y * step
			vertices.append(Vector3(world_x, height_grid[grid_index], world_z))
			uvs.append(Vector2(world_x, world_z))
			var left_x := maxi(0, grid_x - 1)
			var right_x := mini(fine_size, grid_x + 1)
			var down_y := maxi(0, grid_y - 1)
			var up_y := mini(fine_size, grid_y + 1)
			var height_left := height_grid[grid_y * row_size + left_x]
			var height_right := height_grid[grid_y * row_size + right_x]
			var height_down := height_grid[down_y * row_size + grid_x]
			var height_up := height_grid[up_y * row_size + grid_x]
			normals.append(Vector3(height_left - height_right, step * 2.0, height_down - height_up).normalized())
	for fine_y in range(fine_size):
		for fine_x in range(fine_size):
			var first := fine_y * row_size + fine_x
			indices.append_array(PackedInt32Array([
				first, first + row_size + 1, first + 1,
				first, first + row_size, first + row_size + 1,
			]))
	seabed.mesh = _arrays_to_mesh(vertices, normals, uvs, indices)
	var material := StandardMaterial3D.new()
	# Continue the wet beach underneath the water instead of revealing an
	# unrelated grey material exactly where the coastal terrain mesh ends.
	material.albedo_color = Color("7a6138")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	seabed.material_override = material


func _seabed_surface_y(world_x: float, world_z: float) -> float:
	return WATER_Y - _sample_generated_field(generated_seabed_depths, world_x, world_z, 0.04)


func _sample_visual_water_depth(world_x: float, world_z: float) -> float:
	return _sample_generated_field(visual_water_depths, world_x, world_z, 0.0)


func _sample_generated_field(field: PackedFloat32Array, world_x: float, world_z: float, fallback: float) -> float:
	var texture_size := map_size * depth_field_resolution
	if field.size() != texture_size * texture_size:
		return fallback
	var sample_x := clampf(
		(world_x / CELL_SIZE + map_size * 0.5) * depth_field_resolution - 0.5,
		0.0, texture_size - 1.0
	)
	var sample_y := clampf(
		(world_z / CELL_SIZE + map_size * 0.5) * depth_field_resolution - 0.5,
		0.0, texture_size - 1.0
	)
	var x0 := floori(sample_x)
	var y0 := floori(sample_y)
	var x1 := mini(x0 + 1, texture_size - 1)
	var y1 := mini(y0 + 1, texture_size - 1)
	var blend_x := sample_x - x0
	var blend_y := sample_y - y0
	var top := lerpf(field[y0 * texture_size + x0], field[y0 * texture_size + x1], blend_x)
	var bottom := lerpf(field[y1 * texture_size + x0], field[y1 * texture_size + x1], blend_x)
	return lerpf(top, bottom, blend_y)


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
	water_material.set_shader_parameter("edge_flow_noise", WORLD_EDGE.FLOW_NOISE)
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
				var position := cell_to_world(int(resource["x"]), int(resource["y"]))
				if kind == "tree":
					position += Vector3(float(resource.get("offset_x", 0.0)), 0.0, float(resource.get("offset_y", 0.0)))
				positions.append(position)
		if positions.is_empty():
			continue
		if kind == "tree":
			TREE_RESOURCES.build(self, positions)
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


func _create_water_depth_texture() -> ImageTexture:
	var texture_size := map_size * depth_field_resolution
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBAF)
	for y in range(texture_size):
		for x in range(texture_size):
			var index := y * texture_size + x
			image.set_pixel(x, y, Color(
				visual_water_depths[index],
				visual_land_depths[index],
				generated_seabed_depths[index] / MAX_SEABED_DEPTH,
				1.0
			))
	return ImageTexture.create_from_image(image)
