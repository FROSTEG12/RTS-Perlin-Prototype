extends Node
## Identical autoload path and RPC protocol in the server and every client.
signal world_received(state: Dictionary)
signal snapshot_received(state: Dictionary)
signal match_ended(reason: String)
var server: Node
var loaded := false
var timeline = preload("res://scripts/snapshot_timeline.gd").new()

func presentation_time() -> float:
	return timeline.render_time(Time.get_ticks_usec() / 1000000.0)

@rpc("authority", "call_remote", "reliable")
func receive_match_ended(reason: String) -> void:
	loaded = false
	match_ended.emit(reason)

func request_world() -> void:
	_request_world.rpc_id(1)

func move_unit(target: Vector2i) -> void:
	if loaded:
		_move.rpc_id(1, target)

func stop_unit() -> void:
	if loaded:
		_stop.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_world() -> void:
	if server != null:
		server.send_world(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func _move(target: Vector2i) -> void:
	if server != null:
		server.move_unit(multiplayer.get_remote_sender_id(), target)

@rpc("any_peer", "call_remote", "reliable")
func _stop() -> void:
	if server != null:
		server.stop_unit(multiplayer.get_remote_sender_id())

@rpc("authority", "call_remote", "reliable")
func receive_world(state: Dictionary) -> void:
	timeline.reset()
	timeline.receive(state.simulation_time, Time.get_ticks_usec() / 1000000.0)
	world_received.emit(state)
	loaded = true
	_ready_for_snapshots.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _ready_for_snapshots() -> void:
	if server != null and server.players.has(multiplayer.get_remote_sender_id()):
		server.ready_peers[multiplayer.get_remote_sender_id()] = true

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_snapshot(state: Dictionary) -> void:
	if loaded:
		timeline.receive(state.simulation_time, Time.get_ticks_usec() / 1000000.0)
		snapshot_received.emit(state)
