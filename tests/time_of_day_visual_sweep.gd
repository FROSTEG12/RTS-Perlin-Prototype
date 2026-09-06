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
	var renderer = world.get_node("MapRenderer")
	var target := Vector3.ZERO
	var found := false
	for y in range(35, 70):
		for x in range(35, 70):
			if renderer.is_land(Vector2i(x, y)) and not renderer.is_land(Vector2i(x + 4, y)):
				target = renderer.cell_to_world(x, y)
				world._place_temporary_building(target)
				found = true
				break
		if found:
			break
	var camera = world.get_node("GameCamera")
	camera.position = target + Vector3(12.5, 18.0, 10.5)
	camera.size = 9.0
	if "--inspect-shore" in OS.get_cmdline_user_args():
		world._set_time_of_day(6.667)
		world.process_mode = Node.PROCESS_MODE_INHERIT
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		return
	var index := 0
	var atlas := Image.create(1920, 1440, false, Image.FORMAT_RGB8)
	for hour in [0.0, 4.0, 6.0, 6.667, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0]:
		world._set_time_of_day(hour)
		for frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame_image = root.get_texture().get_image()
		frame_image.save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/time_%02d.png" % index)
		frame_image.convert(Image.FORMAT_RGB8)
		frame_image.resize(640, 360)
		atlas.blit_rect(frame_image, Rect2i(0, 0, 640, 360), Vector2i((index % 3) * 640, (index / 3) * 360))
		print("TIME_SWEEP ", index, " hour=", hour)
		index += 1
	atlas.save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/time_atlas.png")
	quit()
