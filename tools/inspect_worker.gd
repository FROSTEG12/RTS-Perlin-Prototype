extends SceneTree

const SOURCE = "C:/Users/FROSTEG/Desktop/Ресурсы для игры/Персонажи/Люди_Средневековье_3D/"
const FILES = [
	"01_Модели/01_Одежда_Quaternius/Exports/glTF (Godot-Unreal)/Outfits/Male_Peasant.gltf",
	"01_Модели/02_Тела_и_прически_Quaternius/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf",
	"01_Модели/02_Тела_и_прически_Quaternius/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf",
	"02_Анимации/01_Движение/Quaternius_UAL1.glb"]

func _initialize():
	call_deferred("run")

func run():
	var skeletons: Array[Skeleton3D] = []
	for file in FILES:
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		assert(doc.append_from_file(SOURCE + file, state) == OK)
		var scene = doc.generate_scene(state)
		root.add_child(scene)
		print("FILE ", file)
		var skeleton = scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		skeletons.append(skeleton)
		print("SKELETON ", skeleton.get_path(), " transform ", skeleton.global_transform)
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			print("MESH ", mesh.name, " aabb ", mesh.get_aabb(), " transform ", mesh.global_transform, " surfaces ", mesh.mesh.get_surface_count())
		for name in ["root", "pelvis", "Head", "head", "neck_01", "upperarm_l", "foot_l"]:
			var bone = skeleton.find_bone(name)
			if bone >= 0: print("BONE ", name, " rest ", skeleton.get_bone_rest(bone), " global ", skeleton.get_bone_global_rest(bone))
		for player in scene.find_children("*", "AnimationPlayer", true, false):
			print("ANIMATIONS ", player.get_animation_list())
			var anim = player.get_animation(player.get_animation_list()[0])
			for t in mini(6, anim.get_track_count()): print("TRACK ", anim.track_get_path(t), " ", anim.track_get_type(t), " ", anim.track_get_key_value(t, 0))
	for i in range(1, skeletons.size()):
		var errors = []
		for b in skeletons[0].get_bone_count():
			var other = skeletons[i].find_bone(skeletons[0].get_bone_name(b))
			if other < 0: errors.append(str("missing ", skeletons[0].get_bone_name(b)))
			elif not skeletons[0].get_bone_rest(b).is_equal_approx(skeletons[i].get_bone_rest(other)): errors.append(skeletons[0].get_bone_name(b))
		print("REST DIFFERENCES ", i, " ", errors)
	quit()
