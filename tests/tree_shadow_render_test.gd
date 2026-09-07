extends SceneTree
const TREES = preload("res://scripts/tree_resources.gd")
const CYCLE = preload("res://scripts/day_night_lighting.gd")
func _initialize() -> void:
	call_deferred("run")
func shot() -> Image:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func dark_pixels(base: Image, shadow: Image) -> int:
	var count := 0
	for y in range(0, base.get_height(), 2):
		for x in range(0, base.get_width(), 2):
			if base.get_pixel(x,y).r - shadow.get_pixel(x,y).r > 0.025: count += 1
	return count
func run() -> void:
	DisplayServer.window_set_size(Vector2i(640, 480))
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.position = Vector3(10.5,18,10.5)
	camera.look_at(Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24,24)
	plane.subdivide_width = 15
	plane.subdivide_depth = 15
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ground)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.shadow_bias = 0.025
	light.shadow_normal_bias = 0.2
	scene.add_child(light)
	var environment := Environment.new()
	var env := WorldEnvironment.new()
	env.environment = environment
	scene.add_child(env)
	var proxy := MeshInstance3D.new()
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	scene.add_child(proxy)
	var minimum := 1000000
	for variant in 6:
		proxy.mesh = TREES.shadow_mesh(variant, 3.5)
		for hour in [7.45, 7.666667, 7.733333, 7.833333, 8.0, 12.0, 18.5, 0.0]:
			CYCLE.apply(hour, light, environment)
			proxy.visible = false
			var baseline := await shot()
			proxy.visible = true
			var with_shadow := await shot()
			var pixels := dark_pixels(baseline, with_shadow)
			minimum = mini(minimum, pixels)
			assert(pixels > 30, "Missing raster shadow: variant %d hour %s pixels %d" % [variant, hour, pixels])
	# Proxies may not contribute any visible geometry when shadows are off.
	light.shadow_enabled = false
	proxy.visible = false
	var hidden := await shot()
	proxy.visible = true
	var visible := await shot()
	assert(hidden.get_data() == visible.get_data(), "Shadow proxy leaked into the visible scene")
	print("TREE_RASTER PASS: 48 variant/time pairs; min shadow pixels=", minimum, "; invisible when shadows disabled")
	quit()
