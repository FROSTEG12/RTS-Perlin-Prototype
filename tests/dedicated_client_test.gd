extends SceneTree
var bridge: Node
var latest := {}
var role := "a"
var starts := {}
var moving_ids := {}
var started := false
var destination := Vector2i.ZERO

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	bridge = root.get_node("MatchNetwork")
	bridge.world_received.connect(func(state: Dictionary): latest = state)
	bridge.snapshot_received.connect(_snapshot)
	var peer := ENetMultiplayerPeer.new()
	assert(peer.create_client("127.0.0.1", 17002) == OK)
	root.multiplayer.multiplayer_peer = peer
	await root.multiplayer.connected_to_server
	peer.get_peer(1).set_timeout(32, 60000, 120000)
	bridge.request_world()
	await create_timer(30).timeout
	push_error("TIMEOUT " + role)
	quit(1)

func _snapshot(state: Dictionary) -> void:
	latest = state
	if state.players.size() != 2:
		return
	if not started:
		started = true
		for p in state.players:
			starts[p.peer_id] = p.position
		call_deferred("_exercise")
	for p in state.players:
		if p.position.distance_to(starts[p.peer_id]) > 1.0:
			moving_ids[p.peer_id] = true

func _exercise() -> void:
	var id := root.multiplayer.get_unique_id()
	var generator := MapGenerator.new()
	var data := generator.generate_map(latest.seed, 34.0, 40, 104)
	var finder := GridPathfinder.new()
	finder.setup(data.cells, 104)
	var spawn := Vector2i.ZERO
	for p in latest.players:
		if p.peer_id == id:
			spawn = p.spawn_cell
	for offset in [Vector2i(10, 0), Vector2i(-10, 0), Vector2i(0, 10), Vector2i(0, -10)]:
		if not finder.find_path(spawn, spawn + offset).is_empty():
			destination = spawn + offset
			break
	bridge.move_unit(destination)
	await create_timer(1).timeout
	if role == "a":
		# Stronger than losing focus: block this client's complete main thread.
		var before: int = latest.tick
		OS.delay_msec(2500)
		await create_timer(0.5).timeout
		assert(latest.tick - before >= 45, "Server stopped when client froze")
	await create_timer(4).timeout
	assert(moving_ids.size() == 2, "Both players' movement must reach both clients")
	bridge.stop_unit()
	await create_timer(0.3).timeout
	var stopped := Vector3.ZERO
	for p in latest.players:
		if p.peer_id == id:
			stopped = p.position
	await create_timer(0.5).timeout
	for p in latest.players:
		if p.peer_id == id:
			assert(stopped.distance_to(p.position) < 0.001, "Stop command failed")
	print("DEDICATED_CLIENT_PASS role=", role, " both_units=", moving_ids.size(), " tick=", latest.tick)
	quit()
