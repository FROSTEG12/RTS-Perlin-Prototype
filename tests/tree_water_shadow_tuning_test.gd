extends SceneTree

const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> Image:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if not label.is_empty(): picture.save_png(OUT + "shadow_tuning_" + label + ".png")
	return picture

func set_shortening(value: float) -> void:
	for material in world.map_renderer.get_meta("tree_shadow_materials"):
		material.set_shader_parameter("low_sun_shortening", value)

func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Engine.time_scale = 0.0
	world._set_time_of_day(17.5)
	var renderer = world.map_renderer
	var direction: Vector3 = -world.key_light.global_basis.z
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	var target := Vector3.ZERO
	var score := INF
	for resource in renderer.resources:
		if resource.kind != "tree": continue
		var position: Vector3 = renderer.cell_to_world(resource.x, resource.y)
		var downstream := position + horizontal * 3.0
		if renderer._ground_surface_y(downstream.x, downstream.z) < -0.3 and position.length_squared() < score:
			target = position + horizontal * 1.5
			score = position.length_squared()
	assert(score < INF, "Need a tree casting toward water")
	world.game_camera.position = target + Vector3(10.5, 18, 10.5)
	world.game_camera.size = 12.0
	var water: ShaderMaterial = renderer.water_material
	var new_shader := water.shader
	var old_shader := Shader.new()
	old_shader.code = new_shader.code.split("// Custom direct lighting")[0]
	set_shortening(0.0)
	water.shader = old_shader
	await shot("before_1730")
	set_shortening(0.28)
	await shot("short_only_1730")
	water.shader = new_shader
	water.set_shader_parameter("water_shadow_strength", 0.52)
	var adjusted := await shot("after_1730")
	water.set_shader_parameter("water_shadow_strength", 1.0)
	var full_shadow := await shot("full_water_shadow_1730")
	var lifted := 0
	for y in range(0, adjusted.get_height(), 2):
		for x in range(250, adjusted.get_width(), 2):
			if adjusted.get_pixel(x,y).g - full_shadow.get_pixel(x,y).g > 0.02: lifted += 1
	assert(lifted > 50, "Water shadows did not become lighter")
	# Verify that the new direct-light path preserves the sunlit appearance.
	world.key_light.shadow_enabled = false
	water.shader = old_shader
	var old_lit := await shot("")
	water.shader = new_shader
	var new_lit := await shot("")
	var error := 0.0
	var samples := 0
	for y in range(0, old_lit.get_height(), 3):
		for x in range(250, old_lit.get_width(), 3):
			var a := old_lit.get_pixel(x,y)
			var b := new_lit.get_pixel(x,y)
			error += maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))
			samples += 1
	error /= samples
	assert(error < 0.015, "Sunlit water appearance changed too much")
	world.key_light.shadow_enabled = true
	water.set_shader_parameter("water_shadow_strength", 0.52)
	for hour in [7.45, 7.733333, 8.0, 12.0, 0.0]:
		world._set_time_of_day(hour)
		await shot(str(hour))
	world._set_time_of_day(17.5)
	world.game_camera.size = 25
	await shot("overview")
	print("SHADOW_TUNING PASS: water pixels lightened=", lifted, "; unshadowed mean RGB error=", error)
	Engine.time_scale = 1.0
	quit()
