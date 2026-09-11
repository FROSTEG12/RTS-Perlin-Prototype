extends RefCounted

const TREE_SHADER := preload("res://shaders/tree_sprite.gdshader")
const SILHOUETTE_SHADER := preload("res://shaders/tree_shadow_silhouette.gdshader")
const TREE_SHEETS := [
	preload("res://assets/vegetation/engvee/Carpinus_01_Body_000.png"),
	preload("res://assets/vegetation/engvee/Carpinus_02_Body_000.png"),
	preload("res://assets/vegetation/engvee/Carpinus_03_Body_000.png"),
	preload("res://assets/vegetation/engvee/Spruce_01_Body_000.png"),
	preload("res://assets/vegetation/engvee/Spruce_02_Body_000.png"),
	preload("res://assets/vegetation/engvee/Pine_01_Body_000.png"),
]
# Stem foot in the first 256px frame, not the transparent image bottom.
const ROOT_PIXELS := [Vector2(95.5, 217), Vector2(95.5, 214),
	Vector2(95.5, 212), Vector2(95.5, 234),
	Vector2(95.5, 235), Vector2(95.5, 216)]
const HEIGHTS := [2.8, 2.6, 2.5, 3.2, 2.9, 3.1]

# Normalized height/radius profiles: broadleaf crowns, tiered spruces,
# and a pine with a longer bare trunk. Closed 3D meshes never turn edge-on.
const SHADOW_PROFILES := [
	[Vector2(0, .045), Vector2(.26, .035), Vector2(.31, .20), Vector2(.48, .32), Vector2(.69, .31), Vector2(.88, .20), Vector2(1, 0)],
	[Vector2(0, .045), Vector2(.24, .035), Vector2(.33, .24), Vector2(.55, .34), Vector2(.76, .27), Vector2(.91, .15), Vector2(1, 0)],
	[Vector2(0, .04), Vector2(.30, .03), Vector2(.36, .20), Vector2(.58, .29), Vector2(.79, .22), Vector2(.93, .12), Vector2(1, 0)],
	[Vector2(0, .035), Vector2(.15, .03), Vector2(.20, .27), Vector2(.37, .18), Vector2(.40, .23), Vector2(.59, .13), Vector2(.62, .17), Vector2(.81, .08), Vector2(.83, .105), Vector2(1, 0)],
	[Vector2(0, .035), Vector2(.17, .03), Vector2(.23, .25), Vector2(.41, .17), Vector2(.44, .21), Vector2(.64, .12), Vector2(.67, .15), Vector2(1, 0)],
	[Vector2(0, .04), Vector2(.34, .03), Vector2(.39, .19), Vector2(.56, .27), Vector2(.75, .24), Vector2(.9, .14), Vector2(1, 0)],
]

static func shadow_mesh(variant: int, height: float) -> ArrayMesh:
	const SIDES := 10
	var profile: Array = SHADOW_PROFILES[variant]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring in profile.size():
		var p: Vector2 = profile[ring]
		for side in SIDES:
			var angle := side * TAU / SIDES
			# Small fixed lobes keep crowns from looking like perfect cylinders.
			var lobe := 1.0 + sin(angle * 3.0 + variant * 1.7) * 0.09
			# Atlas cards contain transparent margins: don't use the full card
			# width as solid foliage. Height compensation must not inflate crowns.
			vertices.append(Vector3(cos(angle) * p.y * lobe * 0.72, p.x, sin(angle) * p.y * lobe * 0.72) * height)
	for ring in range(profile.size() - 1):
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			indices.append_array(PackedInt32Array([a, b, a + SIDES, b, b + SIDES, a + SIDES]))
	# Close the trunk base. The final ring converges to a closed crown tip.
	for side in range(1, SIDES - 1):
		indices.append_array(PackedInt32Array([0, side + 1, side]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


static func build(renderer: Node3D, positions: Array[Vector3]) -> void:
	# Six visible batches + six shadows-only batches, no per-tree nodes.
	var shadow_materials: Array[ShaderMaterial] = []
	renderer.set_meta("tree_shadow_materials", shadow_materials)
	# Flat visible cards must not receive the intersecting hidden card's shadow.
	# This also disables reception of other objects' shadows by the tree sprite.
	var visible_shader := Shader.new()
	visible_shader.code = TREE_SHADER.code.replace("render_mode cull_disabled", "render_mode shadows_disabled, cull_disabled")
	var groups: Array = []
	for variant in TREE_SHEETS.size():
		groups.append([])
	for position in positions:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2(position.x, position.z))
		var variant := rng.randi_range(0, TREE_SHEETS.size() - 1)
		groups[variant].append([position, rng.randf_range(0.85, 1.15), rng.randf(), rng.randf_range(0.92, 1.06)])
	var camera_basis: Basis = renderer.get_viewport().get_camera_3d().global_basis.orthonormalized()
	for variant in TREE_SHEETS.size():
		if groups[variant].is_empty():
			continue
		var texture: Texture2D = TREE_SHEETS[variant]
		var frame_size := Vector2(texture.get_size()) / 4.0
		var height: float = HEIGHTS[variant]
		var width := height * frame_size.x / frame_size.y
		var pivot: Vector2 = ROOT_PIXELS[variant] / frame_size
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		quad.center_offset = Vector3((0.5 - pivot.x) * width, (pivot.y - 0.5) * height, 0.0)
		var material := ShaderMaterial.new()
		material.shader = visible_shader
		material.set_shader_parameter("tree_atlas", texture)
		quad.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = groups[variant].size()
		var shadows := MultiMesh.new()
		shadows.transform_format = MultiMesh.TRANSFORM_3D
		shadows.use_custom_data = true
		var shadow_quad := QuadMesh.new()
		shadow_quad.size = Vector2(width, height / camera_basis.y.y)
		shadow_quad.center_offset = Vector3((0.5 - pivot.x) * width, (pivot.y - 0.5) * shadow_quad.size.y, 0)
		var shadow_material := ShaderMaterial.new()
		shadow_material.shader = SILHOUETTE_SHADER
		shadow_material.set_shader_parameter("tree_atlas", texture)
		shadow_material.set_shader_parameter("sun_direction", renderer.get_meta("tree_shadow_direction", Vector3(0.7, -0.6, 0.3)))
		shadow_materials.append(shadow_material)
		shadow_quad.material = shadow_material
		shadows.mesh = shadow_quad
		shadows.instance_count = groups[variant].size()
		for index in groups[variant].size():
			var item: Array = groups[variant][index]
			var position: Vector3 = item[0]
			position.y = renderer._ground_surface_y(position.x, position.z) + 0.015
			multimesh.set_instance_transform(index, Transform3D(camera_basis.scaled(Vector3.ONE * item[1]), position))
			multimesh.set_instance_custom_data(index, Color(item[2], item[3], 0.0, 0.0))
			# Rotation is performed by the shader toward the light, never randomly.
			var shadow_basis := Basis.IDENTITY.scaled(Vector3.ONE * item[1])
			shadows.set_instance_transform(index, Transform3D(shadow_basis, position))
			shadows.set_instance_custom_data(index, Color(item[2], item[3], 0.0, 0.0))
		var batch := MultiMeshInstance3D.new()
		batch.name = "Trees_%s" % texture.resource_path.get_file().trim_suffix("_Body_000.png")
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		renderer.resource_root.add_child(batch)
		var shadow_batch := MultiMeshInstance3D.new()
		shadow_batch.name = "TreeShadows_%d" % variant
		shadow_batch.multimesh = shadows
		shadow_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow_batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# CPU bounds don't know the shader rotates the card around Y.
		shadow_batch.extra_cull_margin = width * 1.15
		renderer.resource_root.add_child(shadow_batch)


static func update_shadow_direction(renderer: Node3D, direction: Vector3) -> void:
	renderer.set_meta("tree_shadow_direction", direction)
	# Only six uniforms; no CPU transforms or per-tree updates every frame.
	for material in renderer.get_meta("tree_shadow_materials", []):
		material.set_shader_parameter("sun_direction", direction)

static func clear_area(renderer: Node3D, area: Rect2, polygon: PackedVector2Array = PackedVector2Array()) -> int:
	var remaining: Array[Dictionary] = []
	var removed := 0
	for resource in renderer.resources:
		var point: Vector3 = renderer.cell_to_world(resource.x,resource.y)
		point += Vector3(resource.get("offset_x",0.0),0,resource.get("offset_y",0.0))
		if resource.kind == "tree" and area.has_point(Vector2(point.x,point.z)) and (polygon.is_empty() or Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon)):
			removed += 1
		else: remaining.append(resource)
	if removed == 0: return 0
	renderer.resources = remaining
	# Hide matching trunks in both instanced batches, including their shadows.
	# Keep all other transforms/variants intact; no full forest rebuild on click.
	for batch in renderer.resource_root.get_children():
		if not batch is MultiMeshInstance3D or not (str(batch.name).begins_with("Trees_") or str(batch.name).begins_with("TreeShadows_")): continue
		for index in batch.multimesh.instance_count:
			var transform: Transform3D = batch.multimesh.get_instance_transform(index)
			if area.has_point(Vector2(transform.origin.x,transform.origin.z)) and (polygon.is_empty() or Geometry2D.is_point_in_polygon(Vector2(transform.origin.x,transform.origin.z),polygon)):
				transform.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
				batch.multimesh.set_instance_transform(index,transform)
	return removed
