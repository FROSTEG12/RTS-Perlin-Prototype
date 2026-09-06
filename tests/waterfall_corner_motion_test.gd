extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1100, 760))
	var renderer = world.get_node("MapRenderer")
	var cells := PackedByteArray()
	cells.resize(64)
	cells.fill(1)
	var resources: Array[Dictionary] = []
	renderer.set_world(cells, 8, resources, MapGenerator.new()._generate_bathymetry(cells, 8, 177))
	var edge = renderer.get_node("WorldEdge")
	var fall = edge.get_node("FallingWater")
	var arrays = fall.mesh.surface_get_arrays(0)
	var copies := {}
	var pairs := 0
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var boundary: Vector2 = arrays[Mesh.ARRAY_TEX_UV2][index]
		if absf(absf(boundary.x) - 4.0) > 0.001 or absf(absf(boundary.y) - 4.0) > 0.001:
			continue
		var travel: float = arrays[Mesh.ARRAY_TEX_UV][index].y
		var key := Vector3(boundary.x, boundary.y, travel)
		if copies.has(key):
			var other: int = copies[key]
			assert(arrays[Mesh.ARRAY_VERTEX][index].distance_to(arrays[Mesh.ARRAY_VERTEX][other]) < 0.00001)
			assert(arrays[Mesh.ARRAY_NORMAL][index].distance_to(arrays[Mesh.ARRAY_NORMAL][other]) < 0.00001)
			pairs += 1
		else:
			copies[key] = index
	assert(pairs == 220)
	print("CORNER_INPUTS PASS: 220 matched positions, normals and flow coordinates; shared displacement field")
	var camera = world.get_node("GameCamera")
	camera.configure_map(4.0)
	camera.size = 8.0
	world._set_time_of_day(12.0)
	for shot in range(6):
		var target := Vector3(3.9 - (shot % 3) * 0.08, -0.4, 3.9 + (shot % 3) * 0.02)
		if shot >= 3:
			target.z = -3.9 + (shot % 3) * 0.02
		camera.global_position = target + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
		# Real shader animation and camera motion, not only a static screenshot.
		for frame in range(24):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/corner_motion_%d.png" % shot)
	print("CORNER_MOTION captured 6 moving views")
	quit()
