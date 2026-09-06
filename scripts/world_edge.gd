extends RefCounted

const CLIFF_SHADER := preload("res://shaders/world_edge.gdshader")
const WATER_SHADER := preload("res://shaders/world_edge_water.gdshader")
const MIST_SHADER := preload("res://shaders/world_edge_mist.gdshader")
const ROCK_TEXTURE := preload("res://assets/world_edge/rock_albedo_stylized.png")
const SOIL_TEXTURE := preload("res://assets/world_edge/rock_albedo_stylized.png")
const FLOW_NOISE := preload("res://assets/waterfall/worley_noise.png")
const DEPTHS := [0.0, 0.4, 1.4, 3.0, 5.5, 8.5, 12.0]
const LIP_RADIUS := 0.18


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
	var shadow_mask := PackedFloat32Array()
	shadow_mask.resize(perimeter.size())
	for index in perimeter.size():
		var occlusion := 0.0
		for neighbor in range(-9, 10):
			var other := posmod(index + neighbor, perimeter.size())
			if perimeter[other].y < renderer.WATER_Y:
				occlusion = maxf(occlusion, 1.0 - smoothstep(0.0, 0.9, absf(neighbor) / renderer.GROUND_SUBDIVISIONS))
		shadow_mask[index] = occlusion
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for ring in DEPTHS.size():
		for index in perimeter.size():
			var top := perimeter[index]
			var jagged := sin(top.x * 1.13 + top.z * 0.71) * 0.17 + sin(top.x * 0.37 - top.z * 0.53) * 0.23
			var depth: float = DEPTHS[ring]
			# Vertical boundary planes and shared corners; no taper into the map.
			var point := top
			point.y -= depth + jagged * minf(depth * 0.3, 1.0)
			vertices.append(point)
			normals.append(outward[index])
			colors.append(Color(depth / 12.0, 1.0 if top.y < -0.23 else 0.0, shadow_mask[index], 1))
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
	cliff_material.set_shader_parameter("rock_texture", ROCK_TEXTURE)
	cliff_material.set_shader_parameter("soil_texture", SOIL_TEXTURE)
	_add_mesh(container, "RockStrata", vertices, normals, colors, indices, cliff_material)
	_build_water_edges(renderer, container, perimeter, outward)
	_build_mist(container)


static func set_mist_color(renderer: Node3D, color: Color) -> void:
	var container := renderer.get_node_or_null("WorldEdge")
	if container == null:
		return
	for child in container.get_children():
		if child is MeshInstance3D:
			var linear := color.srgb_to_linear()
			child.material_override.set_shader_parameter("mist_color", Vector3(linear.r, linear.g, linear.b))


static func _add_mesh(parent: Node3D, mesh_name: String, vertices: PackedVector3Array,
		normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, material: Material, uvs := PackedVector2Array(), boundary_uvs := PackedVector2Array()) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not boundary_uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = boundary_uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	# Cosmetic underside must not cast giant directional shadows on gameplay.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


# Intersect exactly the same linear boundary segments as the terrain mesh.
# The density threshold is not the visible shore: sloping beach meets WATER_Y later.
static func _water_interval(renderer: Node3D, a: Vector3, b: Vector3) -> PackedVector3Array:
	a.y = renderer._ground_surface_y(a.x, a.z)
	b.y = renderer._ground_surface_y(b.x, b.z)
	var wet_a: bool = a.y < renderer.WATER_Y
	var wet_b: bool = b.y < renderer.WATER_Y
	if not wet_a and not wet_b:
		return PackedVector3Array()
	if wet_a != wet_b:
		var hit := a.lerp(b, (renderer.WATER_Y - a.y) / (b.y - a.y))
		if wet_a:
			b = hit
		else:
			a = hit
	a.y = renderer.WATER_Y
	b.y = renderer.WATER_Y
	return PackedVector3Array([a, b])


static func _is_water_segment(renderer: Node3D, a: Vector3, b: Vector3, _outward: Vector3) -> bool:
	return not _water_interval(renderer, a, b).is_empty()


static func _fall_outward(boundary: Vector3, half_extent: float) -> Vector3:
	# Same smooth corner field as waterfall_outward() in the shader.
	return Vector3(
		signf(boundary.x) * (1.0 - smoothstep(0.0, 0.65, half_extent - absf(boundary.x))),
		0.0,
		signf(boundary.z) * (1.0 - smoothstep(0.0, 0.65, half_extent - absf(boundary.z)))
	)


static func _build_water_edges(renderer: Node3D, parent: Node3D, perimeter: PackedVector3Array, outward: PackedVector3Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var boundary_uvs := PackedVector2Array()
	var wet_count := 0
	var half_extent: float = renderer.get_half_extent()
	for index in perimeter.size():
		var interval := _water_interval(renderer, perimeter[index], perimeter[(index + 1) % perimeter.size()])
		if interval.is_empty():
			continue
		wet_count += 1
		var normal := outward[index]
		var first := vertices.size()
		# Six segments around the lip, then a vertical curtain at a fixed offset.
		for row in range(55):
			var angle := minf(row / 6.0, 1.0) * PI * 0.5
			var depth := LIP_RADIUS * (1.0 - cos(angle)) + maxf(0, row - 6) * 0.25
			var offset := LIP_RADIUS * sin(angle)
			var travel := LIP_RADIUS * angle + maxf(0, row - 6) * 0.25
			for endpoint in interval:
				var p: Vector3 = endpoint
				var along := p.x + p.z
				var corner := absf(absf(p.x) - half_extent) < 0.001 and absf(absf(p.z) - half_extent) < 0.001
				boundary_uvs.append(Vector2(endpoint.x, endpoint.z))
				var extrusion := _fall_outward(endpoint, half_extent)
				p += extrusion * offset
				p.y -= depth
				vertices.append(p)
				normals.append((extrusion.normalized() * sin(angle) + Vector3.UP * cos(angle)).normalized())
				colors.append(Color(0, depth / 12.0, 1.0 if corner else 0.0, 1))
				uvs.append(Vector2(along, travel))
			if row > 0:
				var a := first + (row - 1) * 2
				indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	parent.set_meta("wet_edge_segments", wet_count)
	if vertices.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("edge_flow_noise", FLOW_NOISE)
	material.set_shader_parameter("map_depth_texture", renderer.water_depth_texture)
	material.set_shader_parameter("map_world_size", renderer.map_size * renderer.CELL_SIZE)
	_add_mesh(parent, "FallingWater", vertices, normals, colors, indices, material, uvs, boundary_uvs)


static func _build_mist(parent: Node3D) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2048, 2048)
	var material := ShaderMaterial.new()
	material.shader = MIST_SHADER
	var mist := MeshInstance3D.new()
	mist.name = "MistBelowWorld"
	mist.mesh = mesh
	mist.material_override = material
	mist.position.y = -24.0
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mist)
