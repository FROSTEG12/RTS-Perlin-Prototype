extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var camera := IsometricGameCamera.new()
	root.add_child(camera)
	camera.process_mode = Node.PROCESS_MODE_DISABLED
	camera.current = true
	camera.configure_map(52.0)
	for viewport_size in [Vector2i(1280, 720), Vector2i(800, 1200), Vector2i(2400, 1080)]:
		root.size = viewport_size
		for zoom in [9.0, 22.0, 42.0]:
			camera.size = zoom
			for x in [-52.0, 0.0, 52.0]:
				for z in [-52.0, 0.0, 52.0]:
					var target := Vector3(x, 0.0, z)
					camera.global_position = target + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
					camera._clamp_position()
					await process_frame
					var focus := camera.screen_to_ground(root.get_visible_rect().size * 0.5)
					assert(focus.distance_to(target) < 0.01, "Every map edge/corner must reach screen center")
					var stable_position := camera.global_position
					for attempt in range(100):
						camera._clamp_position()
					assert(camera.global_position.distance_to(stable_position) < 0.001, "Clamp must not jitter")
		camera.position = Vector3(999, 18, 999)
		camera._clamp_position()
		await process_frame
		var bounded := camera.screen_to_ground(root.get_visible_rect().size * 0.5)
		assert(absf(bounded.x - 52.0) < 0.01 and absf(bounded.z - 52.0) < 0.01)
	print("CAMERA_TEST PASS: 81 focus/zoom/aspect cases; stable bounds; all corners reachable")
	quit()
