extends Node3D
## Instantly completed prototype. Future construction stages belong under ModelAnchor.
var building_id: StringName = &"sawmill"
var footprint := Vector2i(13,9)
var quarter_turn := 0
var origin_cell := Vector2i.ZERO
var stage: StringName = &"completed"
var model_anchor: Node3D
var model_name := "sawmill"

func _ready() -> void:
	model_anchor = Node3D.new()
	model_anchor.name = "ModelAnchor"
	add_child(model_anchor)
	model_anchor.rotation.y = quarter_turn*PI/2.0
	model_anchor.add_child(preload("res://scripts/buildings/building_model.gd").create(model_name))
