extends SceneTree
## Offline assembly. Runtime only loads the baked, shared PackedScene.
const INPUTS = preload("res://tools/inspect_worker.gd")
const OUTPUT = "res://assets/units/worker/worker.scn"
const TEXTURES = "res://assets/units/worker/textures/"

func _initialize():
	call_deferred("build")

func load_source(index: int) -> Node3D:
	var folder = INPUTS.SOURCE
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): folder = arg.trim_suffix("/") + "/"
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	assert(doc.append_from_file(folder + INPUTS.FILES[index], state) == OK)
	var node = doc.generate_scene(state)
	root.add_child(node)
	return node

func skeleton(node: Node) -> Skeleton3D:
	return node.find_children("*", "Skeleton3D", true, false)[0]

func own(node: Node, scene: Node):
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func prepare_materials(nodes: Array, textures_only: bool):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURES))
	var processed = {}
	for node in nodes:
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material = mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material == null or processed.has(material.get_instance_id()): continue
				processed[material.get_instance_id()] = true
				var metallic = material.get_texture(BaseMaterial3D.TEXTURE_METALLIC)
				var metallic_data = metallic.get_image().get_data() if metallic != null else PackedByteArray()
				for slot in BaseMaterial3D.TEXTURE_MAX:
					var texture = material.get_texture(slot)
					if texture == null: continue
					# glTF can assign the same ORM/roughness image to two slots.
					# Keep a single unchanged texture, preserving each channel selector.
					var file_slot = slot
					if slot == BaseMaterial3D.TEXTURE_ROUGHNESS:
						if not metallic_data.is_empty() and metallic_data == texture.get_image().get_data(): file_slot = BaseMaterial3D.TEXTURE_METALLIC
					var path = TEXTURES + material.resource_name.validate_filename() + "_%d.png" % file_slot
					if textures_only:
						assert(texture.get_image().save_png(path) == OK)
					else:
						material.set_texture(slot, load(path))
				if material.resource_name == "MI_Hair_1": material.albedo_color = Color(0.24, 0.13, 0.065)

func head_only(mesh: ArrayMesh) -> ArrayMesh:
	var result = ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept = PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var keep = true
			for corner in 3:
				var p = positions[indices[t + corner]]
				if p.y < 1.50 or absf(p.x) > 0.15: keep = false
			if keep:
				for corner in 3: kept.append(indices[t + corner])
		if kept.is_empty(): continue
		# Compact all vertex channels, retaining original UVs, normals and weights.
		var old_vertices = PackedInt32Array()
		var remap = {}
		for i in kept.size():
			var old = kept[i]
			if not remap.has(old):
				remap[old] = old_vertices.size()
				old_vertices.append(old)
			kept[i] = remap[old]
		for channel in Mesh.ARRAY_INDEX:
			if arrays[channel] == null or arrays[channel].is_empty(): continue
			var original = arrays[channel]
			var stride: int = original.size() / positions.size()
			var compact = original.duplicate()
			compact.resize(0)
			for old in old_vertices:
				for c in stride: compact.append(original[old * stride + c])
			arrays[channel] = compact
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, mesh.surface_get_material(surface))
	print("HEAD compact bounds ", result.get_aabb())
	return result

func attach_mesh(mesh: MeshInstance3D, source: Skeleton3D, target: Skeleton3D):
	var skin = mesh.skin.duplicate() as Skin
	for bind in skin.get_bind_count():
		var bone_name = skin.get_bind_name(bind)
		if bone_name.is_empty(): bone_name = source.get_bone_name(skin.get_bind_bone(bind))
		var target_bone = target.find_bone(bone_name)
		assert(target_bone >= 0)
		skin.set_bind_name(bind, bone_name)
		skin.set_bind_bone(bind, target_bone)
	mesh.reparent(target)
	mesh.transform = Transform3D.IDENTITY
	mesh.skeleton = NodePath("..")
	mesh.skin = skin

func bake(source: Skeleton3D, target: Skeleton3D, original: Animation) -> Animation:
	var result = Animation.new()
	result.length = original.length
	result.loop_mode = Animation.LOOP_LINEAR
	var tracks = []
	for b in target.get_bone_count():
		var track = result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track, NodePath("Skeleton3D:" + target.get_bone_name(b)))
		tracks.append(track)
	var hip = target.find_bone("pelvis")
	var source_hip = source.find_bone("pelvis")
	var hip_track = result.add_track(Animation.TYPE_POSITION_3D)
	result.track_set_path(hip_track, NodePath("Skeleton3D:pelvis"))
	var frames = ceili(original.length * 30)
	for frame in range(frames + 1):
		var time = minf(frame / 30.0, original.length)
		source.reset_bone_poses()
		for t in original.get_track_count():
			var path = original.track_get_path(t)
			if path.get_subname_count() != 1: continue
			var b = source.find_bone(path.get_subname(0))
			if b < 0: continue
			match original.track_get_type(t):
				Animation.TYPE_ROTATION_3D: source.set_bone_pose_rotation(b, original.rotation_track_interpolate(t, time))
				Animation.TYPE_POSITION_3D: source.set_bone_pose_position(b, original.position_track_interpolate(t, time))
		# Transfer global rotation deltas from the source rest, then reconstruct
		# target local poses. Bone lengths remain those of the peasant outfit.
		var rotations: Array[Basis] = []
		for b in target.get_bone_count():
			var sb = source.find_bone(target.get_bone_name(b))
			assert(sb >= 0)
			rotations.append(source.get_bone_global_pose(sb).basis.orthonormalized() * source.get_bone_global_rest(sb).basis.orthonormalized().inverse() * target.get_bone_global_rest(b).basis.orthonormalized())
		for b in target.get_bone_count():
			var parent = target.get_bone_parent(b)
			var local = rotations[b] if parent < 0 else rotations[parent].inverse() * rotations[b]
			result.rotation_track_insert_key(tracks[b], time, local.get_rotation_quaternion().normalized())
		var ratio = target.get_bone_global_rest(hip).origin.y / source.get_bone_global_rest(source_hip).origin.y
		var hip_pos = target.get_bone_rest(hip).origin + (source.get_bone_pose_position(source_hip) - source.get_bone_rest(source_hip).origin) * ratio
		result.position_track_insert_key(hip_track, time, hip_pos)
	return result

func build():
	var outfit = load_source(0)
	var body = load_source(1)
	var hair = load_source(2)
	var textures_only = "--textures-only" in OS.get_cmdline_user_args()
	prepare_materials([outfit, body, hair], textures_only)
	if textures_only:
		print("EXTRACTED original texture pixels; run editor import, then build again")
		quit()
		return
	var movement = load_source(3)
	var target = skeleton(outfit)
	var worker = Node3D.new()
	worker.name = "Worker"
	root.add_child(worker)
	target.reparent(worker)
	target.name = "Skeleton3D"
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "SuperHero_Male":
			mesh.mesh = head_only(mesh.mesh)
			mesh.name = "HeadAndNeck"
		attach_mesh(mesh, skeleton(body), target)
	for mesh in hair.find_children("*", "MeshInstance3D", true, false): attach_mesh(mesh, skeleton(hair), target)
	var library = AnimationLibrary.new()
	var source_player = movement.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for pair in [["idle", "Idle_Loop"], ["walk", "Walk_Loop"], ["jog", "Jog_Fwd_Loop"]]:
		library.add_animation(pair[0], bake(skeleton(movement), target, source_player.get_animation(pair[1])))
	var player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", library)
	player.autoplay = "idle"
	player.playback_default_blend_time = 0.16
	worker.add_child(player)
	target.reset_bone_poses()
	var triangles = 0
	for mesh in worker.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count(): triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
	print("WORKER bones=", target.get_bone_count(), " triangles=", triangles, " meshes=", worker.find_children("*", "MeshInstance3D", true, false).size())
	own(worker, worker)
	var packed = PackedScene.new()
	assert(packed.pack(worker) == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	assert(ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	print("BUILT ", OUTPUT)
	quit()
