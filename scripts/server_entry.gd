extends SceneTree

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
	var server := preload("res://scripts/dedicated_server.gd").new()
	root.add_child(server)
	var result: Error = server.start(port, seed_value)
	if result != OK:
		push_error("Server start failed: " + error_string(result))
		quit(1)
	else:
		var marker := FileAccess.open("user://dedicated-%d.ready" % OS.get_process_id(), FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()

func _finalize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dedicated-%d.ready" % OS.get_process_id()))
