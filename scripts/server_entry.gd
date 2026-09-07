extends SceneTree
var owner_port := 0
var lifetime_connection: StreamPeerTCP
var server: Node
var next_owner_check := 0
var stopping := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	Engine.max_fps = 60
	OS.low_processor_usage_mode = false
	var port := 7000
	var seed_value := 12345
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--owner-port="):
			owner_port = int(arg.trim_prefix("--owner-port="))
	if owner_port > 0:
		lifetime_connection = StreamPeerTCP.new()
		lifetime_connection.connect_to_host("127.0.0.1", owner_port)
	server = preload("res://scripts/dedicated_server.gd").new()
	root.add_child(server)
	var result: Error = server.start(port, seed_value)
	if result != OK:
		push_error("Server start failed: " + error_string(result))
		quit(1)
	else:
		var marker := FileAccess.open("user://dedicated-%d.ready" % OS.get_process_id(), FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()

func _process(_delta: float) -> bool:
	if stopping or server == null or lifetime_connection == null:
		return false
	if Time.get_ticks_msec() < next_owner_check:
		return false
	next_owner_check = Time.get_ticks_msec() + 250
	lifetime_connection.poll()
	if lifetime_connection.get_status() in [StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR]:
		stopping = true
		server.set_process(false)
		_finish.call_deferred()
	return false

func _finish() -> void:
	root.get_node("MatchNetwork").receive_match_ended.rpc("Организатор завершил матч")
	# Give reliable notification time to leave before closing the transport.
	await create_timer(0.5).timeout
	quit()

func _finalize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dedicated-%d.ready" % OS.get_process_id()))
