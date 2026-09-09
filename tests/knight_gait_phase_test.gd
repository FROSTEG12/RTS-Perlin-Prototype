extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	var units: Array[Unit3D] = []
	var scene := load("res://scenes/units/knight.tscn") as PackedScene
	for index in 5:
		var unit := scene.instantiate() as Unit3D
		root.add_child(unit)
		unit.set_process(false)
		unit.visual.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		units.append(unit)
	for clip in ["idle", "walk", "jog"]:
		var times: Array[float] = []
		for unit in units:
			unit.visual.reset_pose()
			if clip != "idle": unit.visual.set_motion(Vector3.BACK * (1.1 if clip == "walk" else 2.25), 0.016)
			var player: AnimationPlayer = unit.visual.player
			assert(player.current_animation == clip)
			times.append(player.current_animation_position / player.get_animation(clip).length)
			assert(unit.position == Vector3.ZERO and unit.move_speed == unit.MOVE_SPEED)
		for a in times.size():
			for b in range(a + 1, times.size()):
				assert(absf(times[a] - times[b]) > 0.05)
		print("PHASES ", clip, " ", times)
		assert(units[0].visual.player.get_animation(clip) == units[1].visual.player.get_animation(clip))
	print("KNIGHT_GAIT_PHASE_PASS independent_phases shared_resources unchanged_movement")
	quit()
