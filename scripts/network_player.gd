class_name NetworkPlayer3D
extends Node3D

const INTERPOLATION_DELAY := 0.12

@onready var visual: Node3D = $Visual
@onready var player_label: Label3D = $PlayerLabel

var peer_id := 0
var network_position := Vector3.ZERO
var local_source: Node3D
var _has_snapshot := false
var _from_position := Vector3.ZERO
var _to_position := Vector3.ZERO
var _from_time := 0.0
var _to_time := 0.0


func setup(id: int, spawn_position: Vector3, source: Node3D = null) -> void:
	peer_id = id
	local_source = source
	position = spawn_position
	network_position = spawn_position
	_from_position = spawn_position
	_to_position = spawn_position
	player_label.text = "Игрок %d" % id
	visual.reset_pose()
	set_multiplayer_authority(id)
	visible = local_source == null


func apply_snapshot(world_position: Vector3, sample_time: float) -> void:
	network_position = world_position
	if not _has_snapshot:
		position = world_position
		_from_position = world_position
		_from_time = sample_time
		_has_snapshot = true
	else:
		_from_position = _to_position
		_from_time = _to_time
	_to_position = world_position
	_to_time = sample_time


func _process(delta: float) -> void:
	if local_source != null:
		network_position = local_source.global_position
		position = network_position
		return
	if network_position != _to_position:
		var clock := get_node_or_null("/root/NetworkTime")
		var sample_time: float = clock.time if clock != null else Time.get_ticks_msec() / 1000.0
		apply_snapshot(network_position, sample_time)
	if not _has_snapshot:
		visual.set_motion(Vector3.ZERO, delta)
		return
	var before := position
	var clock := get_node_or_null("/root/NetworkTime")
	if _to_time <= _from_time or clock == null or not clock.is_initial_sync_done():
		position = _to_position
	else:
		var render_time: float = clock.time - INTERPOLATION_DELAY
		var weight := clampf((render_time - _from_time) / (_to_time - _from_time), 0.0, 1.0)
		position = _from_position.lerp(_to_position, weight)
	visual.set_motion((position - before) / maxf(delta, 0.00001), delta)
