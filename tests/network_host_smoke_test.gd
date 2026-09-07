extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var world: Node3D
var role := ""
var connected_peer_id := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
	if role not in ["host", "client"]:
		push_error("Use --role=host or --role=client")
		quit(2)
		return
	call_deferred("_start")


func _start() -> void:
	world = MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	if role == "host":
		world.network_session.peer_joined.connect(_on_peer_joined)
		world.network_session.peer_left.connect(_on_peer_left)
		var result: Error = world.network_session.start_host()
		if result != OK:
			push_error("Host failed: %s" % error_string(result))
			quit(3)
			return
		print("NETWORK_SMOKE HOST_READY seed=", world.world_seed)
	else:
		world.network_world_synchronized.connect(_on_world_synchronized)
		var result: Error = world.network_session.join_host("127.0.0.1")
		if result != OK:
			push_error("Client start failed: %s" % error_string(result))
			quit(5)
			return
	await create_timer(60.0).timeout
	push_error("%s timed out" % role.capitalize())
	quit(4 if role == "host" else 6)


func _on_peer_joined(peer_id: int) -> void:
	connected_peer_id = peer_id


func _on_peer_left(peer_id: int) -> void:
	if peer_id != connected_peer_id:
		return
	print("NETWORK_SMOKE HOST_PASS peer=", peer_id, " seed=", world.world_seed)
	quit()


func _on_world_synchronized(seed_value: int) -> void:
	if seed_value != world.world_seed:
		push_error("Client applied the wrong world seed")
		quit(8)
		return
	print(
		"NETWORK_SMOKE CLIENT_PASS id=",
		world.multiplayer.get_unique_id(),
		" seed=",
		seed_value
	)
	await create_timer(1.0).timeout
	quit()
