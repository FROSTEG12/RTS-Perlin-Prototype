extends SceneTree
## Preserve source clips, skin, weapon sockets and cape morph animation.
func _initialize(): call_deferred("run")
func run() -> void:
	build("Knight_RTS.glb", "red.scn")
	build("Knight_RTS_Blue.glb", "blue.scn")
	quit()

func build(source: String, output: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://assets/units/low_poly_knight/" + source, state) == OK)
	var model := document.generate_scene(state)
	root.add_child(model)
	model.set_meta("knight_gait", true)
	var player: AnimationPlayer = model.get_node("AnimationPlayer")
	# Existing visual adapter scales models by .55. Source is 1.76 m tall;
	# .75 final scale matches the other prototype units (~1.32 world units).
	model.get_node("Knight_Root").scale = Vector3.ONE * (0.75 / 0.55)
	# Export's root rest basis is already rotated. Skinned visor faces +Z;
	# retain it instead of adding a second 180-degree turn.
	for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var original: ArrayMesh = instance.mesh
		# Automatic body LOD loses thin skinned legs in Run/Death when enlarged.
		# Keep its original silhouette; cape, helmet, visor and weapons still use LOD.
		if instance.name == "Armor_001": continue
		# Copy skin, materials and ALL morph targets before generating index LODs.
		# Cape animation is retained at every level; only triangle indices change.
		var importer := ImporterMesh.from_mesh(original)
		importer.generate_lods(60.0, 60.0, [])
		var levels := 0
		for surface in importer.get_surface_count():
			levels += importer.get_surface_lod_count(surface)
			for level in importer.get_surface_lod_count(surface):
				print("LOD ", instance.name, " ", level, " triangles=", importer.get_surface_lod_indices(surface, level).size() / 3)
		instance.mesh = importer.get_mesh()
		instance.set_meta("lod_levels", levels)
		instance.lod_bias = 1.0
	for clip in ["Idle", "Walk", "Run"]:
		var animation := player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR
		if clip == "Idle": continue
		# Remove net horizontal pelvis travel, not vertical bounce or gait sway.
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D: continue
			if not str(animation.track_get_path(track)).ends_with(":pelvis"): continue
			var count := animation.track_get_key_count(track)
			var start: Vector3 = animation.track_get_key_value(track, 0)
			var drift: Vector3 = animation.track_get_key_value(track, count - 1) - start
			drift.y = 0
			for key in count:
				var value: Vector3 = animation.track_get_key_value(track, key)
				animation.track_set_key_value(track, key, value - drift * animation.track_get_key_time(track, key) / animation.length)
	var library := player.get_animation_library("")
	for pair in [["idle", "Idle"], ["walk", "Walk"], ["jog", "Run"]]:
		library.add_animation(pair[0], player.get_animation(pair[1]))
	player.play("idle")
	player.advance(0)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, "res://assets/units/low_poly_knight/" + output) == OK)
	print("KNIGHT_BUILD_PASS ", player.get_animation_list())
	model.free()
