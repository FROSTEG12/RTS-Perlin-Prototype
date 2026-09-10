extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> Image:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT+file)
	return image
func brightness(image: Image, rect: Rect2i) -> float:
	var total := 0.0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var pixel := image.get_pixel(x,y)
			total += pixel.r*0.2126+pixel.g*0.7152+pixel.b*0.0722
	return total/rect.get_area()
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	world.vision.set_process(false)
	world.weather.climate.fog = 0
	world.weather.climate.rain = 0
	world._apply_day_night_lighting()
	for unit in world.player_units: unit.set_process(false)
	var vision = world.vision
	assert(not vision.material.shader.code.contains("hint_depth_texture"))
	assert(vision.material.get_shader_parameter("memory_darkness") == vision.MEMORY_DARKNESS)
	assert(world.hud.minimap.terrain_material.get_shader_parameter("memory_darkness") == vision.MEMORY_DARKNESS)
	if DisplayServer.get_name() == "headless":
		print("VISIBILITY_EDGES_LOGIC_PASS continuous_projection shared_darkness")
		quit()
		return
	var center: Vector3 = vision.sources()[0].position
	var original: Array[Vector3] = []
	for unit in world.player_units: original.append(unit.global_position)
	world.game_camera.focus_on(center)
	world.game_camera.size = 28
	var lit := await capture("visibility-contrast-lit.png")
	var screen: Vector2 = world.game_camera.unproject_position(center)
	screen *= root.get_stretch_transform().get_scale()
	var region := Rect2i(Vector2i(screen)-Vector2i(35,35),Vector2i(70,70))
	vision.state.update([],true)
	vision._sync_visuals()
	var memory := await capture("visibility-contrast-memory.png")
	var ratio := brightness(memory,region)/maxf(brightness(lit,region),0.001)
	assert(ratio < 0.80 and ratio > 0.15,"Remembered terrain must be visibly darker, not black")
	print("VISIBILITY_MEMORY_LUMINANCE_RATIO ",ratio)
	# Reproduce the user's explored boundaries, not an entirely unexplored black screen.
	var points := [Vector3(48,0,0),Vector3(0,0,48),Vector3(48,0,48)]
	for i in points.size():
		for index in world.player_units.size(): world.player_units[index].global_position = original[index]+points[i]-center
		vision.reset_world()
		world.game_camera.focus_on(points[i])
		world.game_camera.size = 30
		await capture("visibility-boundary-%d.png" % i)
		world.game_camera.size = 52
		await capture("visibility-boundary-%d-wide.png" % i)
	print("VISIBILITY_EDGES_VISUAL_PASS contrast east south corner zoom")
	quit()
