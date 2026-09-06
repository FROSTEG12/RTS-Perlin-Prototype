extends SceneTree

const CYCLE = preload("res://scripts/day_night_lighting.gd")

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	var lights = scene.find_children("*", "DirectionalLight3D", true, false)
	assert(lights.size() == 1, "Only one directional shadow source is allowed")
	var key = lights[0]
	var environment = scene.get_node("WorldEnvironment").environment
	CYCLE.apply(0.0, key, environment)
	var midnight_basis: Basis = key.transform.basis
	var previous_direction: Vector3 = -key.transform.basis.z
	var previous = CYCLE.sample(0.0)
	for minute in range(1, 1441):
		var hour = float(minute) / 60.0
		CYCLE.apply(hour, key, environment)
		var current = CYCLE.sample(hour)
		var direction: Vector3 = -key.transform.basis.z
		assert(direction.angle_to(previous_direction) < deg_to_rad(0.5), "Shadow direction jumped")
		assert(direction.y < -0.45, "Unbounded horizon shadow")
		previous_direction = direction
		assert(key.shadow_enabled and key.visible, "Shadow source was switched")
		for property in ["key_energy", "ambient_energy", "shadow_opacity"]:
			assert(absf(current[property] - previous[property]) < 0.025, "Discontinuous lighting")
		for property in ["key_color", "ambient_color"]:
			var delta: Color = current[property] - previous[property]
			assert(maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) < 0.025)
		previous = current
	assert(CYCLE.sample(0.0) == CYCLE.sample(24.0), "Midnight seam")
	assert(key.transform.basis.is_equal_approx(midnight_basis), "Orbit seam")
	CYCLE.apply(6.0, key, environment)
	var morning: Vector3 = -key.transform.basis.z
	CYCLE.apply(18.0, key, environment)
	var evening: Vector3 = -key.transform.basis.z
	assert(Vector2(morning.x, morning.z).dot(Vector2(evening.x, evening.z)) < 0.0,
		"Morning and evening must cast shadows in opposite directions")
	CYCLE.apply(12.0, key, environment)
	assert((-key.transform.basis.z).y < morning.y, "Noon shadows must be shorter")
	print("PASS: 1440 time steps, continuous orbit and midnight wrap, moving shadows, single source")
	scene.free()
	quit()
