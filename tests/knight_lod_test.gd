extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize(): call_deferred("run")
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(2.6, 2.2, 4.5)
	camera.look_at(Vector3(0, 0.65, 0))
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-40, -30, 0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.2, 0.2)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var instances: Array[Node3D] = []
	for color in ["blue", "red"]:
		var model: Node3D = load("res://assets/units/low_poly_knight/" + color + ".scn").instantiate()
		model.scale = Vector3.ONE * 0.55
		model.position.x = -0.75 if color == "blue" else 0.75
		scene.add_child(model)
		var player: AnimationPlayer = model.get_node("AnimationPlayer")
		player.play("Idle")
		player.advance(0.4)
		player.pause()
		instances.append(model)
	var near_count := 0
	var far_count := 0
	for zoom in [3.0, 9.0, 22.0, 42.0]:
		camera.size = zoom
		for frame in 6: await process_frame
		await RenderingServer.frame_post_draw
		var count := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		print("LOD_DRAW zoom=", zoom, " triangles=", count)
		if zoom == 3.0: near_count = count
		if zoom == 42.0: far_count = count
		root.get_texture().get_image().save_png(OUT + "knight-lod-%d.png" % int(zoom))
	assert(far_count < near_count, "Zooming out must actually reduce rendered geometry")
	# Inspect the reduced mesh enlarged, including the deformed cape in every clip.
	camera.size = 3.8
	for mesh in instances[0].find_children("*", "MeshInstance3D", true, false): mesh.lod_bias = 1000.0
	for mesh in instances[1].find_children("*", "MeshInstance3D", true, false): mesh.lod_bias = 0.001
	for clip in ["Idle", "Walk", "Run", "Attack_Combo", "Attack_Splash", "Death_1", "Death_2", "Death_3"]:
		for model in instances:
			var player: AnimationPlayer = model.get_node("AnimationPlayer")
			player.play(clip, 0)
			player.seek(player.get_animation(clip).length * (0.98 if clip.begins_with("Death") else 0.55), true)
			player.pause()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "knight-compare-" + clip + ".png")
	print("KNIGHT_LOD_PASS ", near_count, " -> ", far_count)
	quit()
