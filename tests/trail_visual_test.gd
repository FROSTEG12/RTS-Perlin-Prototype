extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	world._sync_weather_controls()
	world.map_renderer.trail_wear.process_pending(8192)
	world.map_renderer.trail_wear.flush_texture()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "trail_" + label + ".png")

func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.test_unit.set_process(false)
	world.game_camera.set_process(false)
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world.weather.climate.fog = 0
	world._set_time_of_day(12)
	DisplayServer.window_set_size(Vector2i(1280,720))
	var renderer = world.map_renderer
	var best := INF
	var target := Vector3.ZERO
	for y in range(6, renderer.map_size - 6):
		for x in range(6, renderer.map_size - 6):
			var p: Vector3 = renderer.cell_to_world(x,y)
			if p.length_squared() >= best: continue
			var clear := true
			for dy in range(-4,5):
				for dx in range(-4,5):
					if not renderer.is_land(Vector2i(x+dx,y+dy)): clear = false
			if clear:
				target = p
				best = p.length_squared()
	assert(best < INF)
	world.game_camera.position = target + Vector3(10.5,18,10.5)
	world.game_camera.size = 9
	# Isolate terrain material for legible before/after inspection.
	renderer.resource_root.visible = false
	var wear = renderer.trail_wear
	assert(world.test_unit.trail_wear == wear)
	var start := target - Vector3(3,0,0)
	var finish := target + Vector3(3,0,0)
	await shot("00_untouched")
	for pass_index in 24:
		wear.forget_unit(10001)
		var a := start if pass_index % 2 == 0 else finish
		var b := finish if pass_index % 2 == 0 else start
		for segment in 120:
			wear.record_movement(10001, a.lerp(b, float(segment)/120), a.lerp(b, float(segment+1)/120))
		wear.process_pending(8192)
		if pass_index + 1 in [1,4,10,24]: await shot("%02d_passes" % (pass_index+1))
	# Actual unit movement reports into the same shared field; standing/spawn
	# don't draw anything and route cancellation still follows the real motion.
	var cell: Vector2i = renderer.world_to_cell(target + Vector3(-2,0,2))
	world.test_unit.place_on_cell(cell, renderer.cell_to_world(cell.x,cell.y))
	var path: Array[Vector2i] = [cell, cell + Vector2i(1,0), cell + Vector2i(2,0)]
	world.test_unit.follow_path(path, renderer)
	var before: int = wear.applied_samples
	for frame in 100:
		world.test_unit._process(1.0 / 60.0)
		wear.process_pending(256)
	assert(wear.applied_samples > before)
	assert(world.test_unit.target_positions.is_empty())
	var stopped: int = wear.applied_samples
	for frame in 60: world.test_unit._process(1.0 / 60.0)
	wear.process_pending(8192)
	assert(wear.applied_samples == stopped)
	await shot("unit_actual_route")
	world._set_time_of_day(0)
	await shot("night")
	world._set_time_of_day(12)
	world.weather.climate.cloud = 1
	world.weather.climate.rain = 0.8
	world._set_time_of_day(12)
	await create_timer(1.8).timeout
	await shot("rain")
	renderer.resource_root.visible = true
	world.game_camera.size = 22
	await shot("forest_overview")
	print("TRAIL_VISUAL PASS: 0/1/4/10/24 passes, actual unit integration, standing still, night/rain, zoom")
	quit()
