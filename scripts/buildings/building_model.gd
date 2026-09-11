extends RefCounted
## Preview and finished object use the same scene, origin and scale.
static func create(model: String) -> Node3D:
	var path := "res://assets/buildings/settlement/LumberMill_BLU.glb" if model == "sawmill" else "res://assets/buildings/fortress/"+model+".tscn"
	var result: Node3D = load(path).instantiate()
	if model == "sawmill":
		var box := bounds(result)
		result.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
		result.position *= .6
		result.scale *= .6
		var anchor := Node3D.new()
		anchor.add_child(result)
		return anchor
	if model in ["square_tower","round_tower","round_tower_alt"]:
		# Logical front is +Z: sawmill door and gate portcullis (source z .329..426).
		# Tower doors were authored on -Z; correct locally, not the socket frame.
		if model == "square_tower":
			# Flags skew the overall AABB. Align the stone shaft, not the flag.
			result.position = Vector3(-.1763255,0,-.0232875)
		var facing := Node3D.new()
		facing.rotation.y = PI
		facing.add_child(result)
		var anchor := Node3D.new()
		anchor.add_child(facing)
		return anchor
	return result

static func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result

static func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in meshes(node):
		var relative := mesh.transform
		var parent := mesh.get_parent()
		while mesh != node and parent != null and parent != node:
			if parent is Node3D: relative = parent.transform*relative
			parent = parent.get_parent()
		if mesh == node: relative = Transform3D.IDENTITY
		var box: AABB = relative*mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
