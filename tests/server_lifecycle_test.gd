extends SceneTree
var role := "owner"
var mode := "stop"
var server_pid := 0
var session: Node
var notified := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--server-pid="):
			server_pid = int(arg.trim_prefix("--server-pid="))
	call_deferred("_run")

func _run() -> void:
	session = preload("res://scripts/network_session.gd").new()
	root.add_child(session)
	session.status_changed.connect(func(message: String): print(role, ": ", message))
	create_timer(25).timeout.connect(func(): push_error("LIFECYCLE_TIMEOUT"); quit(1))
	if role == "guest":
		root.get_node("MatchNetwork").match_ended.connect(func(_reason: String): notified = true)
		if session.join_host("127.0.0.1", 17005) != OK:
			quit(1)
			return
		await session.connected_to_host
		await create_timer(4).timeout
		var probe := ENetMultiplayerPeer.new()
		var port_released := probe.create_server(17005, 1) == OK
		probe.close()
		if not notified or not port_released:
			push_error("LIFECYCLE_FAIL " + mode)
			quit(1)
			return
		print("LIFECYCLE_PASS ", mode, " guest_notified server_exited")
		quit()
		return
	if await session.start_host(17005, 12345) != OK:
		quit(1)
		return
	server_pid = session.server_pid
	var guest_pid := OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path("user://lifecycle-" + mode + ".log"),
		"--script", "res://tests/server_lifecycle_test.gd", "--", "--role=guest",
		"--mode=" + mode, "--server-pid=%d" % server_pid]), false)
	var deadline := Time.get_ticks_msec() + 15000
	while root.multiplayer.get_peers().size() < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if root.multiplayer.get_peers().size() < 2:
		push_error("Guest did not connect")
		quit(1)
		return
	await create_timer(0.5).timeout
	OS.delay_msec(1500)
	if not OS.is_process_running(server_pid):
		push_error("Server must survive a frozen owner window")
		quit(1)
		return
	if mode == "crash":
		OS.kill(OS.get_process_id())
		return
	if mode == "close":
		quit()
		return
	session.stop()
	await create_timer(1.5).timeout
	if OS.is_process_running(server_pid):
		push_error("Owner stop did not terminate server")
		quit(1)
		return
	while OS.is_process_running(guest_pid):
		await create_timer(0.1).timeout
	quit()
