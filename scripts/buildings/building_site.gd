extends Node3D
## Instantly completed prototype. Future construction stages belong under ModelAnchor.
var building_id: StringName = &"sawmill"
var footprint := Vector2i(8,6)
var quarter_turn := 0
var origin_cell := Vector2i.ZERO
var stage: StringName = &"completed"
var model_anchor: Node3D
var model_name := "sawmill"
var construction_stage := 5
var construction_work := 0.0
const CONSTRUCTION_SECONDS := 32.0
var yaw := 0.0
var shape := PackedVector2Array()
var connections: Array[Dictionary] = []

# Passage is narrower than the ~1.91 m portcullis: leave clearance at the jambs.
const GATE_PASSAGE_HALF_WIDTH := .65

func blocks_navigation(point: Vector3) -> bool:
	if building_id != &"fortress_gate": return true
	var local_point := (point-position).rotated(Vector3.UP,-yaw)
	return absf(local_point.x)>GATE_PASSAGE_HALF_WIDTH

func _ready() -> void:
	model_anchor = Node3D.new()
	model_anchor.name = "ModelAnchor"
	add_child(model_anchor)
	model_anchor.rotation.y = yaw
	model_anchor.add_child(preload("res://scripts/buildings/building_model.gd").create(model_name))
	set_construction_stage(construction_stage)

func set_construction_stage(index: int) -> void:
	if model_name not in ["sawmill","house","warehouse"]: return
	construction_stage = clampi(index,1,5)
	stage = &"completed" if construction_stage==5 else &"construction"
	if model_anchor != null:
		preload("res://scripts/buildings/building_model.gd").set_stage(model_anchor,construction_stage)
