extends SceneTree
const OUT = "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"

func _initialize(): call_deferred("run")

func run():
	var stage = Node3D.new()
	root.add_child(stage)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.22, 0.28, 0.30)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.shadow_enabled = true
	stage.add_child(light)
	var ground = MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(20,20)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32,0.38,0.25)
	ground.mesh.material = mat
	stage.add_child(ground)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.position = Vector3(0,1.7,5)
	stage.add_child(camera)
	camera.look_at(Vector3(0,0.9,0))
	var worker = load("res://assets/units/worker/worker.scn").instantiate()
	stage.add_child(worker)
	var player = worker.get_node("AnimationPlayer")
	DisplayServer.window_set_size(Vector2i(900,800))
	for item in [["idle_front", "idle", 0.5, 0.0], ["jog_front", "jog", 0.2, 0.0], ["jog_side", "jog", 0.4, PI/2], ["idle_back", "idle", 0.5, PI]]:
		player.play(item[1], 0.0)
		player.seek(item[2], true)
		player.pause()
		worker.rotation.y = item[3]
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "worker_" + item[0] + ".png")
	print("WORKER VISUAL DONE")
	quit()
