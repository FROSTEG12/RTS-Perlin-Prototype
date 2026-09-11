extends SceneTree
func _initialize() -> void:
	for id in ["wall","gate","square_tower","round_tower","round_tower_alt"]:
		var model = load("res://assets/buildings/fortress/"+id+".tscn").instantiate()
		for level in [.2,2.0,3.4,4.0,4.5]:
			var low := Vector3.INF
			var high := -Vector3.INF
			for surface in model.mesh.get_surface_count():
				var arrays: Array = model.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty(): indices = PackedInt32Array(range(vertices.size()))
				for i in range(0,indices.size(),3):
					for edge in 3:
						var a := vertices[indices[i+edge]]
						var b := vertices[indices[i+(edge+1)%3]]
						if (a.y-level)*(b.y-level)>0 or is_equal_approx(a.y,b.y): continue
						var v := a.lerp(b,(level-a.y)/(b.y-a.y))
						low = low.min(v)
						high = high.max(v)
			print(id," y",level," ",low," .. ",high)
		model.free()
	var gate = load("res://assets/buildings/fortress/gate.tscn").instantiate()
	for surface in gate.mesh.get_surface_count():
		var material = gate.mesh.surface_get_material(surface)
		var low := Vector3.INF
		var high := -Vector3.INF
		for v in gate.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			low=low.min(v)
			high=high.max(v)
		print("GATE_MATERIAL ",material.resource_name," ",material.albedo_color," ",low," .. ",high)
	gate.free()
	quit()
