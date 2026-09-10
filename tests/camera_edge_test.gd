extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var camera := IsometricGameCamera.new()
	root.add_child(camera)
	camera.set_process(false)
	for dimensions in [Vector2(1280, 720), Vector2(2560, 1080), Vector2(3440, 1440)]:
		var rect := Rect2(Vector2.ZERO, dimensions)
		assert(camera.edge_direction(dimensions * 0.5, rect) == Vector2.ZERO)
		assert(camera.edge_direction(Vector2(1, dimensions.y / 2), rect) == Vector2.LEFT)
		assert(camera.edge_direction(Vector2(dimensions.x - 1, dimensions.y / 2), rect) == Vector2.RIGHT)
		assert(camera.edge_direction(Vector2(dimensions.x / 2, 1), rect) == Vector2(0, 1))
		assert(camera.edge_direction(Vector2(dimensions.x / 2, dimensions.y - 1), rect) == Vector2(0, -1))
		assert(is_equal_approx(camera.edge_direction(Vector2.ONE, rect).length(), 1.0))
		assert(camera.edge_direction(Vector2(-1, 50), rect) == Vector2.ZERO)
		assert(camera.edge_direction(dimensions + Vector2.ONE, rect) == Vector2.ZERO)
	camera.dragging = true
	camera.controls_blocked = true
	camera._process(0.1)
	assert(not camera.dragging)
	print("CAMERA_EDGE PASS: directions, corners, outside, 16:9/21:9, menu block")
	quit()
