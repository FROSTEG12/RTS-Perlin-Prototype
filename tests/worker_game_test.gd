extends SceneTree
const OUT = "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"

func _initialize(): call_deferred("run")

func run():
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world.weather.climate.fog = 0
	world._set_time_of_day(12)
	var unit = world.test_unit
	assert(unit.get_node_or_null("Body") == null)
	assert(unit.get_node("Visual/Model/Skeleton3D") is Skeleton3D)
	world.game_camera.global_position = unit.global_position + world.game_camera.global_basis.z * (18.0 / world.game_camera.global_basis.z.y)
	for zoom in [9.0, 22.0]:
		world.game_camera.size = zoom
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "worker_game_%d.png" % zoom)
	var visual = unit.visual
	for velocity in [Vector3.RIGHT * 2.25, Vector3.FORWARD * 2.25, Vector3.LEFT * 2.25, Vector3.BACK * 2.25]:
		for frame in 60: visual.set_motion(velocity, 1.0 / 60.0)
		assert(visual.player.current_animation == "jog")
		assert((visual.basis.z - velocity.normalized()).length() < 0.001)
	visual.set_motion(Vector3.ZERO, 0.016)
	assert(visual.player.current_animation == "idle")
	assert(unit.rotation == Vector3.ZERO) # Path dots/fog root do not turn with model.
	world.generate_world()
	assert(unit.trail_wear == world.map_renderer.trail_wear)
	assert(visual.player.current_animation == "idle")
	print("WORKER GAME PASS: production scene, 4 directions, stop, zoom 9/22, map reset")
	quit()
