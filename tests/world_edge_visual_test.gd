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
	quit()
