extends Node3D
## Opt-in visibility for future enemies/buildings. Memories contain render meshes only.
var vision: Node3D
var records: Dictionary = {}

func reset() -> void:
	for record in records.values():
		if is_instance_valid(record.snapshot): record.snapshot.free()
	records.clear()

func refresh() -> void:
	for node in get_tree().get_nodes_in_group("vision_dynamic"):
		if node is Node3D: node.visible = not vision.enabled or vision.state.is_visible(node.global_position)
	for node in get_tree().get_nodes_in_group("vision_static"):
		if not node is Node3D: continue
		var id := node.get_instance_id()
		if not records.has(id):
			records[id] = {"source":weakref(node),"snapshot":null,"position":node.global_position,"captured":-1000}
		var record: Dictionary = records[id]
		var seen: bool = vision.state.is_visible(node.global_position)
		node.visible = seen or not vision.enabled
		if seen and Time.get_ticks_msec()-record.captured >= 100:
			if is_instance_valid(record.snapshot): record.snapshot.free()
			record.snapshot = Node3D.new()
			record.snapshot.name = "RememberedStructure"
			add_child(record.snapshot)
			_capture_meshes(node,record.snapshot)
			record.position = node.global_position
			record.captured = Time.get_ticks_msec()
		if is_instance_valid(record.snapshot): record.snapshot.visible = vision.enabled and not seen
	# Destruction is learned only when the last known position becomes visible again.
	for id in records.keys():
		var record: Dictionary = records[id]
		if record.source.get_ref() != null: continue
		if not is_instance_valid(record.snapshot) or vision.state.is_visible(record.position):
			if is_instance_valid(record.snapshot): record.snapshot.free()
			records.erase(id)
		else: record.snapshot.visible = vision.enabled
	if vision.world.hud != null: vision.world.hud.minimap.refresh_landmarks()

func _capture_meshes(source: Node, target: Node3D) -> void:
	if source is MeshInstance3D and source.mesh != null and source.is_visible_in_tree():
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh.duplicate(true)
		if source.material_override != null: copy.material_override = source.material_override.duplicate(true)
		for surface in source.get_surface_override_material_count():
			var material: Material = source.get_surface_override_material(surface)
			if material != null: copy.set_surface_override_material(surface,material.duplicate(true))
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.layers = 2
		target.add_child(copy)
		copy.global_transform = source.global_transform
	for child in source.get_children(): _capture_meshes(child,target)
