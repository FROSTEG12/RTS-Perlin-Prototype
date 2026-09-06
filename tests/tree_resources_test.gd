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
	for batch in renderer.resource_root.get_children():
		if str(batch.name).begins_with("Trees_"):
			batch_count += 1
			rendered_count += batch.multimesh.instance_count
	assert(tree_count > 0 and tree_count == rendered_count)
	assert(batch_count <= 6)
	renderer._build_resources()
	assert(original == renderer.resources, "Rendering must not change resource data")
	var rebuilt_count := 0
	for batch in renderer.resource_root.get_children():
		if str(batch.name).begins_with("Trees_"):
			rebuilt_count += batch.multimesh.instance_count
	assert(rebuilt_count == tree_count, "Rebuilding must not duplicate trees")
	print("TREE_TEST PASS: ", tree_count, " trees, ", batch_count, " batches, unchanged resource data")
	var camera = world.get_node("GameCamera")
	camera.position = target + Vector3(10.5, 18.0, 10.5)
	for hour in [12.0, 0.0, 6.5, 18.5]:
		world._set_time_of_day(hour)
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
		world.process_mode = Node.PROCESS_MODE_INHERIT
		return
	quit()
