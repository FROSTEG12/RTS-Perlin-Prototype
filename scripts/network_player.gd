class_name NetworkPlayer3D
extends Node3D

const INTERPOLATION_DELAY := 0.10
@onready var visual: Node3D = $Visual
@onready var player_label: Label3D = $PlayerLabel
var peer_id := 0
var network_position := Vector3.ZERO
var local_source: Node3D
var snapshots: Array[Dictionary] = []

func setup(id: int, spawn_position: Vector3, source: Node3D = null) -> void:
	peer_id = id
	local_source = source
	position = spawn_position
	network_position = spawn_position
	player_label.text = "Игрок %d" % id
	visual.reset_pose()
	visible = local_source == null

func apply_snapshot(world_position: Vector3, sample_time: float) -> void:
	if not snapshots.is_empty() and sample_time <= float(snapshots.back().time):
		return
	network_position = world_position
	if snapshots.is_empty():
		position = world_position
	snapshots.append({"position": world_position, "time": sample_time})
	while snapshots.size() > 32:
		snapshots.pop_front()

func _process(delta: float) -> void:
	if snapshots.is_empty():
		return
	var before := global_position
	var clock := get_node("/root/NetworkTime")
	var render_time: float = clock.time - INTERPOLATION_DELAY
	while snapshots.size() > 2 and float(snapshots[1].time) <= render_time:
		snapshots.pop_front()
	if snapshots.size() < 2 or not clock.is_initial_sync_done():
		position = network_position
	else:
		var first: Dictionary = snapshots[0]
		var second: Dictionary = snapshots[1]
		var weight := clampf((render_time - first.time) / maxf(second.time - first.time, 0.0001), 0.0, 1.0)
		position = first.position.lerp(second.position, weight)
	var velocity := (global_position - before) / maxf(delta, 0.00001)
	if local_source != null:
		local_source.set_process(false)
		local_source.global_position = global_position
		local_source.visual.set_motion(velocity, delta)
		if is_instance_valid(local_source.trail_wear):
			local_source.trail_wear.record_movement(local_source.get_instance_id(), before, global_position)
	else:
		visual.set_motion(velocity, delta)
