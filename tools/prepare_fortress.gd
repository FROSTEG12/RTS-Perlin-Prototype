extends SceneTree
## Extract isolated modules only; exclude the assembled lower demo and loose props.
const MODULES := [
	["wall",Vector2(-130,-88),6.0],
	["round_tower",Vector2(-82,-63),3.0],
	["round_tower_alt",Vector2(-56,-37),3.0],
	["square_tower",Vector2(-28,-8),3.0],
	["gate",Vector2(3,45),6.0],
]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source = load("res://assets/buildings/fortress/Original.glb").instantiate()
	root.add_child(source)
	for specification in MODULES:
		var parts: Array = []
		var bounds := AABB()
		var initialized := false
		for node in source.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var kept := PackedVector3Array()
				var kept_normals := PackedVector3Array()
				for i in range(0,indices.size(),3):
					var triangle: Array[Vector3] = []
					for j in 3: triangle.append(node.global_transform*positions[indices[i+j]])
					if triangle.any(func(p: Vector3): return p.y<=60 or p.x<specification[1].x or p.x>specification[1].y): continue
					for j in 3:
						kept.append(triangle[j])
						kept_normals.append((node.global_basis*normals[indices[i+j]]).normalized())
						if not initialized: bounds=AABB(triangle[j],Vector3.ZERO); initialized=true
						else: bounds=bounds.expand(triangle[j])
				if kept.is_empty(): continue
				var material: StandardMaterial3D = node.mesh.surface_get_material(surface).duplicate()
				var tint := material.albedo_color
				if tint.r>tint.g*1.4 and tint.r>tint.b*1.4: material.albedo_color = Color("#36629a")
				parts.append([kept,kept_normals,material])
		assert(initialized)
		var scale_factor: float = specification[2]/bounds.size.x
		var pivot := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var mesh := ArrayMesh.new()
		for part in parts:
			var vertices: PackedVector3Array = part[0]
			for i in vertices.size(): vertices[i]=(vertices[i]-pivot)*scale_factor
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=part[1]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(mesh.get_surface_count()-1,part[2])
		assert(ResourceSaver.save(mesh,"res://assets/buildings/fortress/"+specification[0]+".res")==OK)
		mesh.take_over_path("res://assets/buildings/fortress/"+specification[0]+".res")
		var module := MeshInstance3D.new()
		module.name = specification[0]
		module.mesh = mesh
		var packed := PackedScene.new()
		assert(packed.pack(module)==OK)
		assert(ResourceSaver.save(packed,"res://assets/buildings/fortress/"+specification[0]+".tscn")==OK)
		module.free()
		print("EXPORTED ",specification[0]," size=",mesh.get_aabb().size," scale=",scale_factor)
	source.free()
	quit()
