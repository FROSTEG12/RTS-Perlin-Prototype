extends SceneTree
const G = preload("res://scripts/buildings/building_geometry.gd")
const T = preload("res://scripts/world/tree_resources.gd")
class Shore extends Node3D:
	const WATER_Y := -.16
	func _ground_surface_y(x: float,y: float) -> float:
		return -.3 if Vector2(x,y).length()>1.55 else -.08
class Resources extends Node3D:
	var resources: Array[Dictionary] = []
	var resource_root := Node3D.new()
	func cell_to_world(x: int,y: int) -> Vector3: return Vector3(x,0,y)
	func _init() -> void: add_child(resource_root)
func _initialize() -> void:
	var shore := Shore.new()
	var round_shape := G.polygon(Vector2.ZERO,Vector2(3,3),0,true)
	assert(G.supported_by_land(round_shape,shore),"Dry round foundation must ignore wet bounding-box corners")
	assert(not G.supported_by_land(G.polygon(Vector2.ZERO,Vector2(3,3),0),shore))
	assert(not G.supported_by_land(G.polygon(Vector2(.2,0),Vector2(3,3),0,true),shore))
	shore.free()
	var renderer := Resources.new()
	for kind in ["tree","stone","iron","coal","meat","berries"]:
		renderer.resources.append({"kind":kind,"x":0,"y":0})
	renderer.resources.append({"kind":"tree","x":2,"y":0})
	renderer.resources.append({"kind":"stone","x":2,"y":0})
	renderer.resources.append({"kind":"tree","x":6,"y":0})
	var batch := MultiMeshInstance3D.new()
	batch.multimesh=MultiMesh.new()
	batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh=BoxMesh.new()
	batch.multimesh.instance_count=3
	for i in 3: batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(i*3,0,0)))
	renderer.resource_root.add_child(batch)
	assert(T.clear_area(renderer,Rect2(-1,-1,2,2))==7)
	assert(renderer.resources.size()==2)
	if DisplayServer.get_name() != "headless":
		assert(batch.multimesh.get_instance_transform(0).basis.x.length()==0)
		assert(batch.multimesh.get_instance_transform(2).basis.x.length()==1)
	renderer.free()
	print("BUILDING_CLEARANCE_PASS actual_coast_contour crown_overlap all_resources nearby_resources_preserved")
	quit()
