extends SceneTree
const BASE := "res://assets/units/kaykit/"
const NAMES := ["Knight", "Ranger", "Barbarian", "Rogue", "Rogue_Hooded"]
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"

func _initialize(): call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.8
	camera.position = Vector3(0, 3.3, 6)
	camera.look_at(Vector3(0, 0.6, 0))
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.shadow_enabled = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.18, 0.23, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	environment.environment.ambient_light_energy = 0.5
	stage.add_child(environment)
	var plane := MeshInstance3D.new()
	plane.mesh = PlaneMesh.new()
	plane.mesh.size = Vector2(30, 30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.37, 0.3)
	plane.material_override = material
	stage.add_child(plane)
	var players: Array[AnimationPlayer] = []
	var skeletons: Array[Skeleton3D] = []
	var shared: AnimationLibrary
	for index in NAMES.size():
		var model: Node3D = load(BASE + NAMES[index] + ".scn").instantiate()
		model.scale = Vector3.ONE * 0.55
		model.position.x = (index - 2) * 1.35
		stage.add_child(model)
		var player: AnimationPlayer = model.get_node("AnimationPlayer")
		var skeleton: Skeleton3D = model.get_node("Skeleton3D")
		assert(skeleton.get_bone_count() == 23)
		var library := player.get_animation_library("")
		if shared == null: shared = library
		assert(library == shared)
		assert(library.get_animation_list().size() == 27)
		for name in library.get_animation_list():
			var clip := library.get_animation(name)
			for track in clip.get_track_count():
				var path := clip.track_get_path(track)
				assert(path.get_concatenated_names() == "Skeleton3D")
				assert(skeleton.find_bone(path.get_subname(0)) >= 0)
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			assert(mesh.get_node(mesh.skeleton) == skeleton)
			assert(mesh.skin != null and mesh.material_override.albedo_texture != null)
			for bind in mesh.skin.get_bind_count():
				var name := mesh.skin.get_bind_name(bind)
				assert(skeleton.find_bone(name) >= 0 if not name.is_empty() else mesh.skin.get_bind_bone(bind) < 23)
		players.append(player)
		skeletons.append(skeleton)
	for clip in ["idle", "walk", "jog"]:
		for player in players:
			player.play(clip)
		for frame in 15: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "kaykit-" + clip + ".png")
		for skeleton in skeletons:
			for bone in skeleton.get_bone_count():
				assert(skeleton.get_bone_global_pose(bone).origin.is_finite())
	# Per-instance animation control must not change another unit's clip.
	players[0].play("idle")
	assert(players[1].current_animation == "jog")
	print("KAYKIT_MODELS_PASS five_unique_models native_23_bones valid_tracks valid_skins shared_27_clips independent_players")
	quit()
