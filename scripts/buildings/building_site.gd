extends Node3D
## A reserved site, not a completed building. Future stages belong under ModelAnchor.
var building_id: StringName = &"sawmill"
var footprint := Vector2i(4,6)
var quarter_turn := 0
var origin_cell := Vector2i.ZERO
var stage: StringName = &"planned"
var model_anchor: Node3D
var model_name := ""

func _ready() -> void:
	model_anchor = Node3D.new()
	model_anchor.name = "ModelAnchor"
	add_child(model_anchor)
	model_anchor.rotation.y = quarter_turn*PI/2.0
	if not model_name.is_empty():
		stage = &"test_module"
		model_anchor.add_child(load("res://assets/buildings/fortress/"+model_name+".tscn").instantiate())
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#80715a")
	wood.roughness = 1.0
	for x in [-1,1]:
		for z in [-1,1]:
			_box(Vector3(.12,.45,.12),Vector3(x*(footprint.x*.5-.12),.225,z*(footprint.y*.5-.12)),wood)
	for x in [-1,1]: _box(Vector3(.10,.10,footprint.y),Vector3(x*(footprint.x*.5-.05),.08,0),wood)
	for z in [-1,1]: _box(Vector3(footprint.x,.10,.10),Vector3(0,.08,z*(footprint.y*.5-.05)),wood)
	var label := Label3D.new()
	label.text = "Лесопилка\nПлощадка"
	label.font_size = 32
	label.pixel_size = .012
	label.position.y = .8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#c5e7f4")
	add_child(label)

func _box(dimensions: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	node.mesh = box
	node.material_override = material
	node.position = at
	model_anchor.add_child(node)
