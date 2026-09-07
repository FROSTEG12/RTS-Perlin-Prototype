extends SceneTree
const MAIN_SCENE := preload("res://scenes/main.tscn")
var world: Node
var role := "host"
var initial_positions := {}
var moved := {}
var exercised := false

func _initialize() -> void:
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

func _move() -> void:
	var own_id := root.multiplayer.get_unique_id()
	var spawn: Vector2i = world.player_spawn_cells[own_id]
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5)]:
		if not world.pathfinder.find_path(spawn, spawn + offset).is_empty():
			root.get_node("MatchNetwork").move_unit(spawn + offset)
			break
	await create_timer(7).timeout
	assert(moved.size() == 2, "Game windows must see both players move")
	assert(world.test_unit.global_position.distance_to(initial_positions[own_id]) > 0.5, "Own visible unit must move")
	assert(world.remote_players.size() == 1)
	for remote in world.remote_players.values():
		assert(remote.visible and remote.global_position.distance_to(initial_positions[remote.peer_id]) > 0.5)
	print("GAME_NETWORK_PASS ", role, " own_and_remote_visible_movement")
	await create_timer(3).timeout
	world.network_session.stop()
	quit()
