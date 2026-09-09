extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D
var training: Node3D
func _initialize(): call_deferred("run")
func simulate(seconds: float) -> void:
	for step in ceili(seconds * 60):
		training._process(1.0 / 60)
		for unit in [training.hero, training.npc]:
			unit._process(1.0 / 60)
			unit.visual.player.advance(1.0 / 60 * unit.visual.player.speed_scale)
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "knight-" + name + ".png")
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("KNIGHT_TEST_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.simulation_speed = 0
	world._set_time_of_day(12)
	world.weather.climate.fog_override = 0
	world.weather.climate.set_rain(false)
	world._apply_day_night_lighting()
	training = world.training
	training.set_process(false)
	assert(world.player_units.size() == 5)
	for unit in world.player_units:
		assert(unit.visual.get_node("Model").scene_file_path.ends_with("/blue.scn"))
	assert(not training.npc.is_in_group("rts_units"))
	for unit in [training.hero, training.npc]:
		unit.set_process(false)
		unit.visual.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		assert(unit.visual.player.get_animation_list().size() == 11)
		var skeleton: Skeleton3D = unit.visual.get_node("Model").find_child("Skeleton3D", true, false)
		assert(skeleton.get_bone_count() == 24)
		var cape: MeshInstance3D = skeleton.get_node("Cape_001")
		assert(cape.mesh.get_blend_shape_count() == 81)
		assert(int(cape.get_meta("lod_levels", 0)) > 0)
		var lod_count := 0
		for mesh in unit.visual.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			lod_count += int(mesh.get_meta("lod_levels", 0))
		assert(lod_count > 0)
		for clip in ["walk", "jog"]:
			var animation: Animation = unit.visual.player.get_animation(clip)
			assert(animation.loop_mode == Animation.LOOP_LINEAR)
			for track in animation.get_track_count():
				if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":pelvis"):
					var first: Vector3 = animation.track_get_key_value(track, 0)
					var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track)-1)
					assert(Vector2(first.x, first.z).distance_to(Vector2(last.x,last.z)) < 0.001)
	# Actual generated-map approach and immortal target contacts.
	training.focus_arena()
	await snap("ready")
	training.attack_button.pressed.emit()
	simulate(12)
	assert(training.npc_hits > 0)
	assert(training.health == 100 and not training.dead)
	assert(not training.hero.movement_locked)
	var deaths: Array[String] = []
	for cycle in 3:
		training.reset_arena()
		training.npc_toggle.button_pressed = true
		simulate(40)
		assert(training.dead and training.health == 0)
		assert(training.hero.movement_locked)
		assert(not training.npc_attacking and training.jobs.is_empty())
		var clip: String = training.hero.visual.player.assigned_animation
		assert(clip in training.DEATHS and clip not in deaths)
		deaths.append(clip)
		world.rts.orders.stop([training.hero])
		assert(training.hero.visual.player.assigned_animation == clip, "Stop must not visually revive a corpse")
		var dead_path: Array[Vector2i] = [training.hero.grid_cell]
		assert(not training.hero.accept_move(dead_path, world.map_renderer, false))
		training.focus_arena()
		await snap(clip)
	training.reset_arena()
	training.npc_toggle.button_pressed = true
	simulate(0.3)
	training.npc_toggle.button_pressed = false
	simulate(10)
	assert(training.health == 100 and not training.npc.movement_locked)
	var last := ""
	for i in 30:
		var chosen: String = training.pick_clip("random_test", training.DEATHS)
		assert(chosen != last)
		last = chosen
	world.generate_world()
	assert(training.health == 100 and not training.dead and not training.hero.movement_locked)
	assert(not training.npc_attacking and training.npc.visible)
	training.focus_arena()
	await snap("final")
	print("KNIGHT_TRAINING_PASS models colors clips root_motion LOD immortal_target death respawn stop_npc regeneration")
	quit()
