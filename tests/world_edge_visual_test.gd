extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	world._set_time_of_day(12.0)
	var renderer = world.get_node("MapRenderer")
	var edge = renderer.get_node_or_null("WorldEdge")
	if edge != null:
		assert(edge.get_child_count() <= 2)
		var rock = edge.get_node("RockStrata")
		var arrays = rock.mesh.surface_get_arrays(0)
		var perimeter_count: int = renderer.map_size * renderer.GROUND_SUBDIVISIONS * 4
		assert(arrays[Mesh.ARRAY_VERTEX].size() == perimeter_count * 7)
		for point in arrays[Mesh.ARRAY_VERTEX]:
			assert(point.is_finite())
		for index in perimeter_count:
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			assert(absf(point.y - renderer._ground_surface_y(point.x, point.z)) < 0.001)
		print("EDGE_GEOMETRY PASS: exact terrain seam; finite vertices; at most two meshes")
	var camera = world.get_node("GameCamera")
	camera.size = 22.0
	var targets := [Vector3(51.5, 0, 51.5), Vector3(-51.5, 0, 51.5), Vector3(51.5, 0, -51.5)]
	for index in targets.size():
		camera.global_position = targets[index] + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
		camera._clamp_position()
		for frame in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/world_edge_%d.png" % index)
		print("EDGE_VIEW ", index)
	world._set_time_of_day(0.0)
	for frame in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/world_edge_night.png")
	quit()
