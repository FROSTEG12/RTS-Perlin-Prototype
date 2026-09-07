extends SceneTree
## Offline import of the five CC0 characters and their native Rig_Medium clips.
const BASE := "res://assets/units/kaykit/"
const CHARACTERS := ["Knight", "Ranger", "Barbarian", "Rogue", "Rogue_Hooded"]

func _initialize(): call_deferred("build")

func source(file: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(BASE + "source/" + file + ".glb", state) == OK)
	var scene := doc.generate_scene(state)
	root.add_child(scene)
	return scene

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func build() -> void:
	var general := source("Rig_Medium_General")
	var movement := source("Rig_Medium_MovementBasic")
	var sample := source("Knight")
	var target: Skeleton3D = sample.find_children("*", "Skeleton3D", true, false)[0]
	print("KAYKIT skeleton=", sample.get_path_to(target), " bones=", target.get_bone_count())
	var library := AnimationLibrary.new()
	for scene in [general, movement]:
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		for bone in target.get_bone_count():
			var source_bone := skeleton.find_bone(target.get_bone_name(bone))
			assert(source_bone >= 0)
			assert(target.get_bone_rest(bone).is_equal_approx(skeleton.get_bone_rest(source_bone)), "Native rigs must match")
		for clip_name in player.get_animation_list():
			if clip_name in ["RESET", "T-Pose"]: continue
			var clip: Animation = player.get_animation(clip_name).duplicate()
			for track in clip.get_track_count():
				var path := clip.track_get_path(track)
				assert(path.get_subname_count() == 1)
				assert(target.find_bone(path.get_subname(0)) >= 0)
				clip.track_set_path(track, NodePath("Skeleton3D:" + path.get_subname(0)))
			clip.loop_mode = Animation.LOOP_LINEAR if clip_name.begins_with("Idle") or clip_name.begins_with("Walking") or clip_name.begins_with("Running") else Animation.LOOP_NONE
			library.add_animation(clip_name, clip)
	library.add_animation("idle", library.get_animation("Idle_A"))
	library.add_animation("walk", library.get_animation("Walking_A"))
	library.add_animation("jog", library.get_animation("Running_A"))
	assert(ResourceSaver.save(library, BASE + "locomotion.res", ResourceSaver.FLAG_COMPRESS) == OK)
	# Reload by path so every character references the SAME library on disk/runtime.
	library = load(BASE + "locomotion.res")
	for character in CHARACTERS:
		var scene := source(character)
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var model := Node3D.new()
		model.name = character
		root.add_child(model)
		skeleton.reparent(model)
		skeleton.name = "Skeleton3D"
		var material := StandardMaterial3D.new()
		var texture_name: String = "rogue" if character.begins_with("Rogue") else character.to_lower()
		material.albedo_texture = load(BASE + "textures/" + texture_name + "_texture.png")
		material.roughness = 0.85
		var triangles := 0
		var bounds := AABB()
		var initialized := false
		for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = material
			var box: AABB = mesh.transform * mesh.mesh.get_aabb()
			bounds = bounds.merge(box) if initialized else box
			initialized = true
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		model.add_child(player)
		player.add_animation_library("", library)
		player.autoplay = "idle"
		player.playback_default_blend_time = 0.16
		own(model, model)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, BASE + character + ".scn", ResourceSaver.FLAG_COMPRESS) == OK)
		print("KAYKIT_BUILT ", character, " bones=", skeleton.get_bone_count(), " triangles=", triangles, " bounds=", bounds, " clips=", library.get_animation_list().size())
		model.free()
		scene.free()
	quit()
