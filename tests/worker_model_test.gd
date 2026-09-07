extends SceneTree

func _initialize(): call_deferred("run")

func lowest_foot(worker: Node3D) -> float:
	var skeleton: Skeleton3D = worker.get_node("Skeleton3D")
	var feet: MeshInstance3D = skeleton.get_node("Male_Peasant_Feet")
	var matrices: Array[Transform3D] = []
	for bind in feet.skin.get_bind_count():
		var bone = skeleton.find_bone(feet.skin.get_bind_name(bind))
		if bone < 0: bone = feet.skin.get_bind_bone(bind)
		matrices.append(skeleton.get_bone_global_pose(bone) * feet.skin.get_bind_pose(bind))
	var minimum = INF
	for surface in feet.mesh.get_surface_count():
		var a = feet.mesh.surface_get_arrays(surface)
		var stride: int = a[Mesh.ARRAY_BONES].size() / a[Mesh.ARRAY_VERTEX].size()
		for v in a[Mesh.ARRAY_VERTEX].size():
			var p = Vector3.ZERO
			for weight in stride:
				var index = v * stride + weight
				p += (matrices[a[Mesh.ARRAY_BONES][index]] * a[Mesh.ARRAY_VERTEX][v]) * a[Mesh.ARRAY_WEIGHTS][index]
			minimum = minf(minimum, p.y)
	return minimum

func run():
	var scene = load("res://assets/units/worker/worker.scn") as PackedScene
	var worker = scene.instantiate()
	var other = scene.instantiate()
	root.add_child(worker)
	root.add_child(other)
	assert(worker.find_children("*", "Skeleton3D", true, false).size() == 1)
	var skeleton: Skeleton3D = worker.get_node("Skeleton3D")
	assert(skeleton.get_bone_count() == 65)
	assert(skeleton.get_node("HeadAndNeck").mesh.get_aabb().position.y >= 1.5)
	for mesh in worker.find_children("*", "MeshInstance3D", true, false):
		assert(mesh.get_node(mesh.skeleton) == skeleton)
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.mesh.surface_get_material(surface)
			if material.resource_name in ["MI_Peasant", "MI_Regular_Male", "MI_Superhero_Male"]:
				assert(material.get_texture(BaseMaterial3D.TEXTURE_METALLIC) == material.get_texture(BaseMaterial3D.TEXTURE_ROUGHNESS))
		for bind in mesh.skin.get_bind_count():
			var name = mesh.skin.get_bind_name(bind)
			assert(skeleton.find_bone(name) >= 0 or mesh.skin.get_bind_bone(bind) >= 0)
	var player: AnimationPlayer = worker.get_node("AnimationPlayer")
	other.get_node("AnimationPlayer").pause()
	for clip in ["idle", "walk", "jog"]:
		var animation = player.get_animation(clip)
		assert(animation.loop_mode == Animation.LOOP_LINEAR)
		assert(animation == other.get_node("AnimationPlayer").get_animation(clip))
		player.play(clip, 0)
		var bottom_min = INF
		var bottom_max = -INF
		for frame in 30:
			player.seek(animation.length * frame / 30.0, true)
			bottom_min = minf(bottom_min, lowest_foot(worker))
			bottom_max = maxf(bottom_max, lowest_foot(worker))
		print("FEET ", clip, " lowest range: ", bottom_min, "..", bottom_max)
		assert(worker.position == Vector3.ZERO) # No root motion drives navigation.
	assert(skeleton != other.get_node("Skeleton3D"))
	print("WORKER MODEL PASS: one skeleton, cropped head, skins, 3 looping shared clips, independent instances")
	quit()
