extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world._set_time_of_day(9.0)
	var renderer = world.get_node("MapRenderer")
	var count := 0
	for y in range(44, 61, 6):
		for x in range(44, 61, 6):
			if renderer.is_land(Vector2i(x, y)):
				world._place_temporary_building(renderer.cell_to_world(x, y))
				count += 1
	var key = world.get_node("KeyLight")
	var camera = world.get_node("GameCamera")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for zoom in [9.0, 42.0]:
		camera.size = zoom
		for variant in ["before", "after"]:
			key.directional_shadow_mode = 2 if variant == "before" else 1
			key.directional_shadow_split_1 = 0.1 if variant == "before" else 0.5
			key.directional_shadow_max_distance = 180.0 if variant == "before" else 80.0
			key.shadow_blur = 0.6 if variant == "before" else 1.2
			key.shadow_normal_bias = 0.35 if variant == "before" else 0.2
			for frame in range(45):
				await process_frame
			var start := Time.get_ticks_usec()
			for frame in range(120):
				await process_frame
			var ms := (Time.get_ticks_usec() - start) / 120000.0
			print("SHADOW_BENCH ", variant, " zoom=", zoom, " houses=", count, " frame_ms=", ms,
				" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/shadow_%s_%d.png" % [variant, int(zoom)])
	quit()
