extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.weather.climate.automatic = false
	world.weather.climate.fog = 0
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	var camera = world.game_camera
	camera.size = 42 if "--continuous" in OS.get_cmdline_user_args() else 25
	camera.global_position = world.test_unit.global_position + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
	world._place_temporary_building(world.test_unit.global_position + Vector3(-3, 0, -3))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.time_scale = 0
	var previous: Image
	var largest_delta := 0.0
	var largest_minute := 0
	var continuous := "--continuous" in OS.get_cmdline_user_args()
	var samples := 600 if continuous else 60
	for minute in range(0, samples + 1):
		world._set_time_of_day(7.0 + float(minute) / samples)
		for frame in (1 if continuous else 3): await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		if minute % 10 == 0:
			shot.save_png(OUT + "dawn_shadow_%02d.png" % minute)
		if previous != null:
			var delta := 0.0
			var changed := 0
			for y in range(0, shot.get_height(), 4):
				for x in range(260, shot.get_width(), 4):
					var d := shot.get_pixel(x,y) - previous.get_pixel(x,y)
					var amount := maxf(absf(d.r), maxf(absf(d.g), absf(d.b)))
					delta += amount
					if amount > 0.12: changed += 1
			if delta > largest_delta:
				largest_delta = delta
				largest_minute = minute
				if continuous:
					previous.save_png(OUT + "dawn_jump_before.png")
					shot.save_png(OUT + "dawn_jump_after.png")
			print("DAWN minute=", minute, " delta=", delta, " strong_pixels=", changed)
		previous = shot
	print("DAWN largest delta=", largest_delta, " at 07:", largest_minute, "; fog/rain/cloud/wind animation frozen")
	Engine.time_scale = 1
	quit()
