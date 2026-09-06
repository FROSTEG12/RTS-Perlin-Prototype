extends RefCounted

const CLIFF_SHADER := preload("res://shaders/world_edge.gdshader")
const WATER_SHADER := preload("res://shaders/world_edge_water.gdshader")
const DEPTHS := [0.0, 0.4, 1.4, 3.0, 5.5, 8.5, 12.0]
const INSETS := [0.0, 0.015, -0.14, 0.3, 0.85, 1.8, 3.5]


static func build(renderer: Node3D) -> void:
	var previous := renderer.get_node_or_null("WorldEdge")
	if previous != null:
		previous.free()
	var container := Node3D.new()
	container.name = "WorldEdge"
	renderer.add_child(container)
	var half_extent: float = renderer.get_half_extent()
	# Match the terrain's boundary vertices exactly, including underwater bed.
	var segments: int = renderer.map_size * renderer.GROUND_SUBDIVISIONS
	var perimeter := PackedVector3Array()
	var outward := PackedVector3Array()
	for side in range(4):
		for index in range(segments):
			var along := lerpf(-half_extent, half_extent, float(index) / segments)
			var point := Vector3.ZERO
			var normal := Vector3.ZERO
			match side:
				0:
					point = Vector3(along, 0, -half_extent)
					normal = Vector3(0, 0, -1)
				1:
					point = Vector3(half_extent, 0, along)
					normal = Vector3(1, 0, 0)
				2:
					point = Vector3(-along, 0, half_extent)
					normal = Vector3(0, 0, 1)
				3:
					point = Vector3(-half_extent, 0, -along)
					normal = Vector3(-1, 0, 0)
			point.y = renderer._ground_surface_y(point.x, point.z)
			perimeter.append(point)
			outward.append(normal)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for ring in DEPTHS.size():
		for index in perimeter.size():
			var top := perimeter[index]
			var radial := Vector3(top.x, 0, top.z).normalized()
			var jagged := sin(top.x * 1.13 + top.z * 0.71) * 0.17 + sin(top.x * 0.37 - top.z * 0.53) * 0.23
			var depth: float = DEPTHS[ring]
			var point: Vector3 = top - radial * (INSETS[ring] + jagged * minf(depth, 1.0))
			point.y -= depth + jagged * minf(depth * 0.3, 1.0)
			vertices.append(point)
			normals.append((outward[index] + Vector3(0, -0.15, 0)).normalized())
			colors.append(Color(depth / 12.0, 1.0 if top.y < -0.23 else 0.0, 0, 1))
			if ring == 0:
				continue
			var next := (index + 1) % perimeter.size()
			var a := (ring - 1) * perimeter.size() + index
			var b := (ring - 1) * perimeter.size() + next
			var c := ring * perimeter.size() + index
			var d := ring * perimeter.size() + next
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var cliff_material := ShaderMaterial.new()
	cliff_material.shader = CLIFF_SHADER
	_add_mesh(container, "RockStrata", vertices, normals, colors, indices, cliff_material)
	_build_water_edges(renderer, container, perimeter, outward)


static func _add_mesh(parent: Node3D, mesh_name: String, vertices: PackedVector3Array,
		normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, material: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	# Cosmetic underside must not cast giant directional shadows on gameplay.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


static func _build_water_edges(renderer: Node3D, parent: Node3D, perimeter: PackedVector3Array, outward: PackedVector3Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for index in perimeter.size():
		var next := (index + 1) % perimeter.size()
		var cell: Vector2i = renderer.world_to_cell(perimeter[index])
		cell.x = clampi(cell.x, 0, renderer.map_size - 1)
		cell.y = clampi(cell.y, 0, renderer.map_size - 1)
		# Boundary smoothing lowers even dry map corners; those are not rivers.
		if renderer.cells[cell.y * renderer.map_size + cell.x] != 1:
			continue
		if perimeter[index].y >= renderer.WATER_Y - 0.08 or perimeter[next].y >= renderer.WATER_Y - 0.08:
			continue
		var a := perimeter[index] + outward[index] * 0.025
		var b := perimeter[next] + outward[index] * 0.025
		a.y = renderer.WATER_Y
		b.y = renderer.WATER_Y
		var first := vertices.size()
		vertices.append_array(PackedVector3Array([a, b, a - Vector3(0, 7, 0), b - Vector3(0, 7, 0)]))
		for vertex in range(4):
			normals.append(outward[index])
			colors.append(Color(float(index) * 0.1, 0 if vertex < 2 else 1, 0, 1))
		indices.append_array(PackedInt32Array([first, first + 2, first + 1, first + 1, first + 2, first + 3]))
	if vertices.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	_add_mesh(parent, "FallingWater", vertices, normals, colors, indices, material)
