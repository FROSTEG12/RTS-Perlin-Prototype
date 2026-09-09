extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D
var training: Node3D
var hero: TestUnit3D
var npc: TestUnit3D
var origin: Vector3

func _initialize(): call_deferred("run")
func simulate(seconds: float) -> void:
	for frame in ceili(seconds * 60):
		training._process(1.0 / 60)
		for actor in [hero, npc]:
			actor._process(1.0 / 60)
			actor.visual.player.advance(1.0 / 60)
		assert(hero.global_position.distance_to(npc.global_position) >= training.MIN_BODY_DISTANCE - 0.001)
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "combo-fixed-" + name + ".png")
func reset_pair(direction: Vector3, distance: float) -> void:
	training.reset_arena()
	hero.position = origin
	npc.position = origin + direction * distance
	hero.visual.rotation.y = atan2(direction.x, direction.z)
	npc.visual.rotation.y = hero.visual.rotation.y + PI
	hero.visual.player.play("idle", 0)
	hero.visual.player.advance(0)
	npc.visual.player.play("idle", 0)
	npc.visual.player.advance(0)
	training.bags["attack"] = ["Attack_Combo"]
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("COMBO_TEST_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	training = world.training
	training.set_process(false)
	hero = training.hero
	npc = training.npc
	for actor in [hero, npc]:
		actor.set_process(false)
		actor.visual.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for actor in world.player_units:
		actor.set_process(false)
	# Locate a real dry patch; preserve map rendering for inspection.
	var found := false
	for y in range(8, 96):
		if found: break
		for x in range(8, 96):
			var clear := true
			for oy in range(-4, 5):
				for ox in range(-4, 5):
					if not world.map_renderer.is_land(Vector2i(x + ox, y + oy)): clear = false
			if clear:
				origin = world.map_renderer.cell_to_world(x, y)
				found = true
				break
	assert(found)
	for i in range(1, 5): world.player_units[i].position = origin + Vector3(8 + i, 0, 8)
	var animation: Animation = hero.visual.player.get_animation("Attack_Combo")
	var curve: Animation = animation.get_meta("root_motion_curve")
	assert(curve != null)
	var expected := curve.position_track_interpolate(0, curve.length)
	for time in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 3.633333]: print("CURVE ", time, " ", curve.position_track_interpolate(0, time))
	assert(expected.z > 0.9 and expected.z < 1.0)
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":pelvis"):
			var first: Vector3 = animation.track_get_key_value(track, 0)
			for key in animation.track_get_key_count(track):
				var point: Vector3 = animation.track_get_key_value(track, key)
				assert(Vector2(first.x, first.z).distance_to(Vector2(point.x, point.z)) < 0.00001)
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		reset_pair(direction, 3.0)
		training._start_attack(hero, npc)
		simulate(animation.length + 0.02)
		var finish := hero.global_position
		assert(absf((finish - origin).length() - expected.length()) < 0.005)
		assert((finish - origin).normalized().dot(direction) > 0.999)
		simulate(0.5)
		assert(hero.global_position.distance_to(finish) < 0.00001, "No recovery slide")
		assert(hero.grid_cell == world.map_renderer.world_to_cell(finish))
	# Interrupt midway: keep the attained location, don't complete or undo the lunge.
	reset_pair(Vector3.BACK, 3.0)
	training._start_attack(hero, npc)
	simulate(2.0)
	var interrupted := hero.position
	training._cancel_action(hero)
	simulate(1)
	assert(hero.position.distance_to(interrupted) < 0.00001)
	reset_pair(Vector3.BACK, 3.0)
	training._start_attack(hero, npc)
	simulate(2.0)
	interrupted = hero.position
	training._die()
	simulate(1)
	assert(hero.position.distance_to(interrupted) < 0.00001)
	# Close-range combo consumes blocked motion without entering the defender.
	reset_pair(Vector3.BACK, 1.6)
	# Test-only visibility: foliage must not conceal contact in the review frames.
	world.map_renderer.resource_root.visible = false
	world.weather.climate.fog_override = 0
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world._set_time_of_day(12)
	training.focus_arena()
	world.game_camera.size = 5.0
	world.rts.grid_button.button_pressed = true
	await snap("before")
	training._start_attack(hero, npc)
	simulate(1.0)
	await snap("first-hit")
	simulate(1.6)
	await snap("second-hit")
	simulate(1.6)
	var finish := hero.position
	await snap("idle-after")
	print("CLOSE MOVE ", finish - origin, " distance=", finish.distance_to(npc.position))
	assert(hero.position.distance_to(origin) > 0.4)
	assert(hero.position.distance_to(npc.position) >= training.MIN_BODY_DISTANCE)
	simulate(1)
	assert(hero.position.distance_to(finish) < 0.00001)
	# A blocked border must not let the extracted displacement cross into water.
	reset_pair(Vector3.BACK, 3.0)
	var blocked_cell: Vector2i = world.map_renderer.world_to_cell(origin + Vector3.BACK)
	var offset: int = blocked_cell.y * world.DEFAULT_MAP_SIZE + blocked_cell.x
	var original: int = world.map_renderer.cells[offset]
	world.map_renderer.cells[offset] = 1
	training._start_attack(hero, npc)
	simulate(5)
	assert(hero.position.z < origin.z + 0.5)
	world.map_renderer.cells[offset] = original
	print("KNIGHT_COMBO_MOTION_PASS displacement=", expected, " directions cancel death clearance shore no_recovery_slide")
	quit()
