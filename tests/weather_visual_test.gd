extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> Image:
	world._sync_weather_controls()
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(OUT + "weather_" + label + ".png")
	print("WEATHER_CAPTURE ", label)
	return picture
func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.world_seed = 4242
	world.generate_world()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var camera = world.game_camera
	camera.size = 19.0
	camera.global_position = world.test_unit.global_position + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
	world._place_temporary_building(world.test_unit.global_position + Vector3(-3, 0, -3))
	var state = world.weather.climate
	state.automatic = false
	state.rain = 0
	state.cloud = 0
	state.fog = 0
	world._set_time_of_day(12)
	await capture("clear")
	var clear_energy: float = world.key_light.light_energy
	state.cloud = 1
	state.rain = 0.8
	state.fog = 0.08
	world._set_time_of_day(12)
	assert(world.key_light.light_energy < clear_energy * 0.5)
	await create_timer(2.0).timeout
	await capture("rain_noon")
	world._set_time_of_day(0)
	await capture("rain_night")
	state.cloud = 0.1
	state.rain = 0
	state.fog = 0.95
	world._set_time_of_day(8)
	await create_timer(2.0).timeout
	await capture("fog_morning")
	var origin: Vector3 = world.test_unit.global_position
	world.test_unit.global_position += Vector3(5, 0, -1)
	world._set_time_of_day(8)
	assert(world.weather.fog_material.get_shader_parameter("unit_position").is_equal_approx(world.test_unit.global_position))
	await capture("fog_unit_moved")
	world.test_unit.global_position = origin
	camera.global_position += Vector3(2, 0, 2)
	camera.size = 30
	world._set_time_of_day(8)
	await capture("fog_pan_zoom")
	world._set_time_of_day(0)
	await capture("fog_night")
	# Map rim and extreme zoom must not uncover a rectangular weather emitter.
	camera.size = 42
	camera.global_position = Vector3(51.0, 0, 51.0) + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
	state.rain = 0.8
	state.cloud = 1.0
	world._set_time_of_day(12)
	await create_timer(2.0).timeout
	await capture("edge_rain_fog")
	assert(world.weather.rain_particles.local_coords == false)
	assert(world.weather.collision.heightfield_mask == 1)
	assert(world.weather.fog_quad.layers == 2)
	assert(world.weather.fog_material.get_shader_parameter("map_half_extent") == world.map_renderer.get_half_extent())
	state.rain = 0
	state.fog = 0
	state.cloud = 0
	world._set_time_of_day(12)
	assert(is_equal_approx(world.key_light.light_energy, clear_energy))
	var rows = world.get_node("UI/MapControls/Margin/Rows")
	rows.get_node("RainToggle").button_pressed = true
	assert(state.manual_rain and not state.automatic)
	rows.get_node("RainToggle").button_pressed = false
	assert(not state.manual_rain)
	rows.get_node("FogPreview").button_pressed = true
	assert(state.fog_override == 0.95)
	rows.get_node("FogPreview").button_pressed = false
	assert(state.fog_override == -1)
	print("WEATHER_VISUAL PASS: lighting restoration, moving unit reveal, toggles, day/night captures")
	if "--preview" in OS.get_cmdline_user_args():
		camera.size = 19
		camera.global_position = origin + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
		rows.get_node("RainToggle").button_pressed = true
		state.cloud = 1
		state.rain = 0.8
		world._set_time_of_day(12)
		world.set_process(true)
		await capture("preview")
		print("WEATHER_PREVIEW ready; rain switch, fog test and unit controls active")
		return
	quit()
