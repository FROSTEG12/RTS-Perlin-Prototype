extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var renderer = world.get_node("MapRenderer")
	var original: Array = renderer.resources.duplicate(true)
	var tree_count := 0
	var target := Vector3.ZERO
	var best_distance := INF
	for resource in original:
		if resource.kind == "tree":
			tree_count += 1
			var position: Vector3 = renderer.cell_to_world(resource.x, resource.y)
			if position.length_squared() < best_distance:
				best_distance = position.length_squared()
				target = position
	var rendered_count := 0
	var batch_count := 0
	var shadow_count := 0
	var shadow_batches := 0
	for batch in renderer.resource_root.get_children():
		if str(batch.name).begins_with("Trees_"):
			batch_count += 1
			rendered_count += batch.multimesh.instance_count
			assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if str(batch.name).begins_with("TreeShadows_"):
			shadow_batches += 1
			shadow_count += batch.multimesh.instance_count
			assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
			assert(batch.multimesh.mesh is QuadMesh)
			assert(batch.multimesh.use_custom_data)
			assert(batch.extra_cull_margin > 2.0)
			assert(batch.multimesh.mesh.material.shader == preload("res://shaders/tree_shadow_silhouette.gdshader"))
			var visible_batch = renderer.resource_root.get_node("Trees_%s" % preload("res://scripts/tree_resources.gd").TREE_SHEETS[int(str(batch.name).trim_prefix("TreeShadows_"))].resource_path.get_file().trim_suffix("_Body_000.png"))
			for index in batch.multimesh.instance_count:
				assert(batch.multimesh.get_instance_custom_data(index) == visible_batch.multimesh.get_instance_custom_data(index))
				assert(batch.multimesh.get_instance_transform(index).origin == visible_batch.multimesh.get_instance_transform(index).origin)
	assert(tree_count > 0 and tree_count == rendered_count)
	assert(batch_count <= 6)
	assert(shadow_count == tree_count and shadow_batches == batch_count)
	renderer._build_resources()
	assert(original == renderer.resources, "Rendering must not change resource data")
	var rebuilt_count := 0
	for batch in renderer.resource_root.get_children():
		if str(batch.name).begins_with("Trees_"):
			rebuilt_count += batch.multimesh.instance_count
	assert(rebuilt_count == tree_count, "Rebuilding must not duplicate trees")
	var rebuilt_shadows := 0
	for batch in renderer.resource_root.get_children():
		if str(batch.name).begins_with("TreeShadows_"):
			rebuilt_shadows += batch.multimesh.instance_count
	assert(rebuilt_shadows == tree_count)
	print("TREE_TEST PASS: ", tree_count, " trees, ", batch_count, " batches, unchanged resource data")
	var camera = world.get_node("GameCamera")
	camera.position = target + Vector3(10.5, 18.0, 10.5)
	for hour in [7.45, 7.666667, 7.733333, 7.833333, 8.0, 12.0, 0.0, 6.5, 18.5]:
		world._set_time_of_day(hour)
		for material in renderer.get_meta("tree_shadow_materials"):
			assert(material.get_shader_parameter("sun_direction").is_equal_approx(-world.key_light.global_basis.z))
		camera.size = 12.0
		for frame in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/trees_%s.png" % str(hour))
	world._set_time_of_day(12.0)
	camera.size = 22.0
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/trees_overview.png")
	if "--inspect-trees" in OS.get_cmdline_user_args():
		camera.size = 14.0
		world._set_time_of_day(7.4)
		world.process_mode = Node.PROCESS_MODE_INHERIT
		return
	quit()
