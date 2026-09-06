extends RefCounted

const TREE_SHADER := preload("res://shaders/tree_sprite.gdshader")
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


static func build(renderer: Node3D, positions: Array[Vector3]) -> void:
	# No per-tree nodes or CPU animation. Six instanced batches on this map.
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
		material.shader = TREE_SHADER
		material.set_shader_parameter("tree_atlas", texture)
		quad.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = quad
		multimesh.instance_count = groups[variant].size()
		for index in groups[variant].size():
			var item: Array = groups[variant][index]
			var position: Vector3 = item[0]
			position.y = renderer._ground_surface_y(position.x, position.z) + 0.015
			multimesh.set_instance_transform(index, Transform3D(camera_basis.scaled(Vector3.ONE * item[1]), position))
			multimesh.set_instance_custom_data(index, Color(item[2], item[3], 0.0, 0.0))
		var batch := MultiMeshInstance3D.new()
		batch.name = "Trees_%s" % texture.resource_path.get_file().trim_suffix("_Body_000.png")
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		renderer.resource_root.add_child(batch)
