extends SceneTree

func _initialize() -> void:
	var timeline = preload("res://scripts/snapshot_timeline.gd").new()
	timeline.receive(50.0, 900.0)
	var previous: float = timeline.render_time(900.0)
	for frame in range(1, 6):
		var current: float = timeline.render_time(900.0 + frame / 120.0)
		assert(current > previous, "Presentation must advance between network ticks")
		previous = current
	timeline.receive(50.05, 900.05)
	assert(timeline.render_time(900.06) >= previous, "No backwards movement")
	assert(timeline.render_time(901.0) <= 50.05, "No extrapolation beyond confirmed state")
	timeline.receive(55.0, 905.0)
	assert(timeline.render_time(905.0) >= 54.9, "No stale backlog after client suspension")
	timeline.receive(54.0, 905.1)
	assert(timeline.latest == 55.0, "Ignore reordered snapshots")
	print("SNAPSHOT_TIMELINE_PASS")
	quit()
