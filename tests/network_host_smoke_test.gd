extends SceneTree
const MAIN_SCENE := preload("res://scenes/main.tscn")
var world: Node
var role := "host"
var initial_positions := {}
var moved := {}
var exercised := false
var moving_frames := 0
var jogging_frames := 0
var route_seen := false
var last_position := Vector3.ZERO
var first_snapshot_usec := 0
var first_render_usec := 0

func _initialize() -> void:
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	call_deferred("_start")

func _start() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	root.get_node("MatchNetwork").snapshot_received.connect(_observe)
	if role == "host":
		assert(await world.network_session.start_host(17003) == OK)
	else:
		assert(world.network_session.join_host("127.0.0.1", 17003) == OK)
	await create_timer(100).timeout
	push_error("GAME_NETWORK_TIMEOUT " + role)
	quit(1)

func _observe(state: Dictionary) -> void:
	if state.players.size() != 2 or state.get("ready_count", 0) != 2:
		return
	if not exercised:
		exercised = true
		for p in state.players:
			initial_positions[p.peer_id] = p.position
		call_deferred("_move")
	for p in state.players:
		if p.position.distance_to(initial_positions[p.peer_id]) > 0.5:
			moved[p.peer_id] = true
		if p.peer_id == root.multiplayer.get_unique_id() and first_snapshot_usec == 0 and p.position.distance_to(initial_positions[p.peer_id]) > 0.001:
			first_snapshot_usec = Time.get_ticks_usec()

func _process(_delta: float) -> bool:
	if not exercised or world.local_network_player == null:
		return false
	var position: Vector3 = world.test_unit.global_position
	if position.distance_to(last_position) > 0.001 and last_position != Vector3.ZERO:
		moving_frames += 1
		if world.test_unit.visual.player.current_animation == "jog":
			jogging_frames += 1
		if first_render_usec == 0 and first_snapshot_usec > 0:
			first_render_usec = Time.get_ticks_usec()
	last_position = position
	if world.local_network_player.route_view.dots.multimesh.instance_count > 0:
		route_seen = true
	return false

func _move() -> void:
	var own_id := root.multiplayer.get_unique_id()
	var spawn: Vector2i = world.player_spawn_cells[own_id]
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5)]:
		if not world.pathfinder.find_path(spawn, spawn + offset).is_empty():
			root.get_node("MatchNetwork").move_unit(spawn + offset)
			break
	await create_timer(7).timeout
	assert(moving_frames > 10 and jogging_frames >= moving_frames * 0.9, "Own movement animation must remain running")
	assert(route_seen, "Server-confirmed route must be visible")
	assert(first_render_usec > 0 and first_render_usec - first_snapshot_usec < 300000, "Unexpected extra presentation delay")
	print("PRESENTATION_PASS ", role, " jog=", jogging_frames, "/", moving_frames, " received_to_display_ms=", (first_render_usec - first_snapshot_usec) / 1000.0)
	assert(moved.size() == 2, "Game windows must see both players move")
	assert(world.test_unit.global_position.distance_to(initial_positions[own_id]) > 0.5, "Own visible unit must move")
	assert(world.remote_players.size() == 1)
	for remote in world.remote_players.values():
		assert(remote.visible and remote.global_position.distance_to(initial_positions[remote.peer_id]) > 0.5)
	print("GAME_NETWORK_PASS ", role, " own_and_remote_visible_movement")
	await create_timer(3).timeout
	world.network_session.stop()
	quit()
