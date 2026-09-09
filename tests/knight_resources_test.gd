extends SceneTree
func _initialize() -> void:
	for color in ["blue", "red"]:
		var model: Node3D = load("res://assets/units/low_poly_knight/" + color + ".scn").instantiate()
		var player: AnimationPlayer = model.get_node("AnimationPlayer")
		for clip in ["Idle", "Walk", "Run", "Attack_Combo", "Attack_Splash", "Death_1", "Death_2", "Death_3"]:
			assert(player.has_animation(clip))
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
		assert(skeleton != null and skeleton.get_bone_count() == 24)
		assert(skeleton.get_node("Cape_001").mesh.get_blend_shape_count() == 81)
		var lod_meshes := 0
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if int(mesh.get_meta("lod_levels", 0)) > 0: lod_meshes += 1
		assert(lod_meshes > 0)
		model.free()
	print("KNIGHT_RESOURCES_PASS blue red clips skeleton cape lod_metadata")
	quit()
