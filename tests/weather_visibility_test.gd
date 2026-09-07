extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void:
	call_deferred("run")
func picture() -> Image:
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var camera = world.game_camera
	camera.size = 19
	camera.global_position = world.test_unit.global_position + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
	var state = world.weather.climate
	state.automatic = false
	state.rain = 0
	state.cloud = 0
	state.fog = 0
	Engine.time_scale = 0.0
	world._set_time_of_day(8)
	var clear := await picture()
	state.fog = 0.95
	world._set_time_of_day(8)
	var fog := await picture()
	var inside_error := 0.0
	var outside_error := 0.0
	var inside_count := 0
	var outside_count := 0
	for y in range(0, fog.get_height(), 3):
		for x in range(260, fog.get_width(), 3):
			var ground: Vector3 = camera.screen_to_ground(Vector2(x, y))
			var distance: float = Vector2(ground.x, ground.z).distance_to(Vector2(world.test_unit.position.x, world.test_unit.position.z))
			var difference: Color = fog.get_pixel(x, y) - clear.get_pixel(x, y)
			var error := maxf(absf(difference.r), maxf(absf(difference.g), absf(difference.b)))
			if distance < 3.7:
				inside_error += error
				inside_count += 1
			elif distance > 8.0:
				outside_error += error
				outside_count += 1
	assert(inside_count > 100 and outside_count > 100)
	inside_error /= inside_count
	outside_error /= outside_count
	assert(inside_error < 0.005, "Inner reveal must match the fog-free image")
	assert(outside_error > 0.01, "Fog must remain outside the reveal")
	fog.save_png(OUT + "weather_visibility_wide.png")
	print("VISIBILITY PASS: inner RGB error=", inside_error, "; outside difference=", outside_error)
	Engine.time_scale = 1.0
	if "--preview" in OS.get_cmdline_user_args():
		world.get_node("UI/MapControls/Margin/Rows/FogPreview").button_pressed = true
		world.set_process(true)
		print("VISIBILITY_PREVIEW ready; wider clear center, fog test enabled")
		return
	quit()
