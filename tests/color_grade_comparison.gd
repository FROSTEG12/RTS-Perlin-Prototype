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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var effect = world.get_node("WorldEnvironment").compositor.compositor_effects[0]
	for hour in [12.0, 0.0]:
		world._set_time_of_day(hour)
		for active in [false, true]:
			effect.enabled = active
			for frame in range(50):
				await process_frame
			var start := Time.get_ticks_usec()
			for frame in range(120):
				await process_frame
			print("GRADE_BENCH hour=", hour, " enabled=", active,
				" frame_ms=", (Time.get_ticks_usec() - start) / 120000.0)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/grade_%d_%s.png" % [int(hour), str(active)])
	quit()
