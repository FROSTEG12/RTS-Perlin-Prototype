extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func render_frame(material: ShaderMaterial, seconds: float) -> Image:
	material.set_shader_parameter("edge_time",seconds)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("EDGE_ANIMATION_SKIP requires rendered pixels")
		quit()
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55,0.65,0.4)
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	scene.add_child(camera)
	camera.position = Vector3(0,30,30)
	camera.look_at(Vector3.ZERO)
	var state = preload("res://scripts/world/visibility_mask.gd").new()
	state.configure(52)
	state.update([{"position":Vector3.ZERO}],true)
	var history: PackedByteArray = state.explored.duplicate()
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	mesh.mesh = quad
	mesh.extra_cull_margin = 16384
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/map_visibility.gdshader")
	material.set_shader_parameter("sight_mask",state.texture)
	material.set_shader_parameter("previous_mask",state.previous)
	material.set_shader_parameter("world_size",104.0)
	mesh.material_override = material
	camera.add_child(mesh)
	mesh.position.z = -1
	var first := await render_frame(material,0)
	var second := await render_frame(material,2)
	var near := await render_frame(material,2.016)
	first.save_png(OUT+"shroud-edge-0.png")
	second.save_png(OUT+"shroud-edge-2.png")
	var moving := 0
	var stable := 0
	var strong_motion := 0
	var largest_step := 0.0
	for y in range(0,540,3):
		for x in range(0,960,3):
			var screen := Vector2(x+0.5,y+0.5)
			var origin := camera.project_ray_origin(screen)
			var direction := camera.project_ray_normal(screen)
			var ground := origin-direction*(origin.y/direction.y)
			var value: float = state.sample(ground,true)
			var a := first.get_pixel(x,y)
			var b := second.get_pixel(x,y)
			var difference := absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			if value < 0.001 or value > 0.999:
				# Ignore one mask texel at the classification boundary (GPU is bilinear).
				if ground.length() < 11.0 or ground.length() > 16.0:
					assert(difference < 0.001,"Opaque/clear cores must not animate")
					stable += 1
			elif difference > 0.008: moving += 1
			if difference > 0.15: strong_motion += 1
			var c := near.get_pixel(x,y)
			largest_step = maxf(largest_step,absf(b.r-c.r)+absf(b.g-c.g)+absf(b.b-c.b))
	assert(moving > 30 and stable > 1000)
	assert(strong_motion > 200,"Edge motion must be obvious within two seconds")
	assert(largest_step < 0.06,"No single-frame flicker")
	assert(state.explored == history)
	# Close view of one edge, for inspecting mask reconstruction and large curls.
	camera.size = 12
	camera.position += Vector3(11,0,0)
	(await render_frame(material,0)).save_png(OUT+"shroud-close-0.png")
	(await render_frame(material,2)).save_png(OUT+"shroud-close-2.png")
	print("EDGE_ANIMATION_PASS moving_pixels=",moving," strong_motion=",strong_motion," stable_core=",stable," max_frame_delta=",largest_step)
	quit()
