extends SceneTree
## Run with real Forward+ GPU, not --headless. No production settings are saved.
const PROFILED := preload("res://tests/stress_unit.gd")
var OUT := OS.get_user_data_dir().path_join("stress-20260909")
const UNIT := preload("res://scenes/worker_unit.tscn")
var world: Node3D
var units: Array[TestUnit3D] = []
var cells: Array[Vector2i] = []
var routes: Array = []
var center := Vector3.ZERO
var results: Array[Dictionary] = []
var phase := "setup"
var moving := false
var attacking := false
var blood_rate := 0.0
var blood_carry := 0.0
var hit_index := 0
var manual_blood_us := 0
var contact_us := 0
var reorders_us := 0
var hits := 0

func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): OUT = argument.trim_prefix("--out=")
	if "--extra" in OS.get_cmdline_user_args(): OUT += "-extra"
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	call_deferred("run")

func status(label: String) -> void:
	phase = label
	var file := FileAccess.open(OUT + "-status.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": phase, "units": units.size(), "pid": OS.get_process_id(), "unix": Time.get_unix_time_from_system()}))
	print("STRESS_PHASE ", units.size(), " ", phase)

func step(delta: float) -> void:
	if moving:
		var start := Time.get_ticks_usec()
		for i in units.size():
			if units[i].target_positions.is_empty():
				var route: Array[Vector2i] = routes[i].duplicate()
				if units[i].grid_cell == route.back(): route.reverse()
				units[i].accept_move(route, world.map_renderer, false)
		reorders_us += Time.get_ticks_usec() - start
	if attacking:
		for unit in units:
			if not unit.visual.player.is_playing(): unit.visual.player.play("Attack_Combo", 0.18)
	if blood_rate > 0:
		blood_carry += delta * blood_rate
		var start := Time.get_ticks_usec()
		while blood_carry >= 1:
			blood_carry -= 1
			var unit := units[hit_index % units.size()]
			world.training.blood.spawn_hit(unit.global_position, Vector3.RIGHT)
			hit_index += 1
			hits += 1
		contact_us += Time.get_ticks_usec() - start
	var start := Time.get_ticks_usec()
	world.training.blood._process(delta)
	manual_blood_us += Time.get_ticks_usec() - start

func reset_counters() -> void:
	PROFILED.process_us = 0
	PROFILED.preview_us = 0
	manual_blood_us = 0
	contact_us = 0
	reorders_us = 0

func settle(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_usec() < until:
		await process_frame
		var now := Time.get_ticks_usec()
		step((now - last) / 1000000.0)
		last = now
	reset_counters()

func summary(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values: total += value
	return {"mean": total / maxi(values.size(), 1), "p50": sorted[int((sorted.size()-1)*0.5)], "p95": sorted[int((sorted.size()-1)*0.95)], "p99": sorted[int((sorted.size()-1)*0.99)], "max": sorted.back()}

func measure(label: String, seconds: float = 8.0) -> void:
	status(label + "_warmup")
	await settle(2.0)
	status(label)
	var data := {"frame_ms": [], "render_cpu_ms": [], "gpu_ms": [], "render_setup_ms": [], "unit_ms": [], "preview_ms": [], "blood_ms": [], "contact_ms": [], "reorders_ms": [], "process_monitor_ms": [], "moving_units": []}
	var start := Time.get_ticks_usec()
	var last := start
	var start_hits := hits
	var upload_start: int = world.training.blood.upload_count
	var pose_start := 0
	for unit in units: pose_start += unit.visual.pose_updates
	var rid := root.get_viewport_rid()
	reset_counters()
	while Time.get_ticks_usec() - start < int(seconds * 1000000):
		await process_frame
		var now := Time.get_ticks_usec()
		data.frame_ms.append((now-last) / 1000.0)
		data.unit_ms.append(PROFILED.process_us / 1000.0)
		data.preview_ms.append(PROFILED.preview_us / 1000.0)
		data.blood_ms.append(manual_blood_us / 1000.0)
		data.contact_ms.append(contact_us / 1000.0)
		data.reorders_ms.append(reorders_us / 1000.0)
		data.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		data.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		data.render_setup_ms.append(RenderingServer.get_frame_setup_time_cpu())
		data.process_monitor_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		var moving_count := 0
		for unit in units:
			if not unit.target_positions.is_empty(): moving_count += 1
		data.moving_units.append(moving_count)
		reset_counters()
		step((now-last) / 1000000.0)
		last = now
	var result := {"count": units.size(), "phase": label, "samples": data.frame_ms.size(), "seconds": (Time.get_ticks_usec()-start)/1000000.0,
		"resolution": str(root.size), "render_scale": root.scaling_3d_scale,
		"rain": world.weather.climate.rain, "fog": world.weather.climate.fog,
		"hits": hits-start_hits, "uploads": world.training.blood.upload_count-upload_start,
		"records": world.training.blood.active_count(), "unix": Time.get_unix_time_from_system()}
	for key in data: result[key] = summary(data[key])
	result.fps = 1000.0 / result.frame_ms.mean
	result.p99_equivalent_fps = 1000.0 / result.frame_ms.p99
	result.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	result.primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	result.static_memory_mib = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	result.render_memory_mib = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	result.nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	result.visible_centers = visible_count()
	var poses := 0
	for unit in units: poses += unit.visual.pose_updates
	result.pose_hz_per_unit = float(poses-pose_start) / units.size() / result.seconds
	result.blood_pending = world.training.blood.pending.size()
	result.blood_coalesced = world.training.blood.coalesced
	result.blood_rejected = world.training.blood.rejected
	results.append(result)
	var file := FileAccess.open(OUT + "-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"metadata": metadata(), "results": results}, "\t"))
	print("STRESS_RESULT ", JSON.stringify(result))

func visible_count() -> int:
	var count := 0
	var rect := root.get_visible_rect()
	for unit in units:
		if not world.game_camera.is_position_behind(unit.global_position) and rect.has_point(world.game_camera.unproject_position(unit.global_position)): count += 1
	return count

func metadata() -> Dictionary:
	return {"seed": world.world_seed, "resolution": str(root.size), "viewport": str(root.get_visible_rect()),
		"gpu": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info(), "vsync": DisplayServer.window_get_vsync_mode(),
		"camera_size": world.game_camera.size, "cpu_threads": OS.get_processor_count(), "debug_build": OS.is_debug_build(),
		"notes": "Actual world/assets, clear noon, 1280x720, uncapped, 2s warmup + 8s per stage. Movement loops precomputed real AStar routes; dispatcher tested separately. Combat is animation + one synthetic contact/unit/2s, not full battle AI."}

func find_fixture() -> void:
	# Pick a dry rectangle with maximal land coverage, keeping all counts in one view.
	var best := -1
	var origin := Vector2i.ZERO
	for y in range(18, 86, 3):
		for x in range(18, 86, 3):
			var count := 0
			for oy in range(-10, 11):
				for ox in range(-10, 11):
					if world.map_renderer.is_land(Vector2i(x+ox, y+oy)): count += 1
			if count > best:
				best = count
				origin = Vector2i(x, y)
	for oy in range(-10, 11):
		for ox in range(-10, 11):
			var cell := origin + Vector2i(ox, oy)
			if not world.map_renderer.is_land(cell): continue
			for direction in [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]:
				var route: Array[Vector2i] = world.pathfinder.find_path(cell, cell+direction*4)
				if route.size() >= 5 and route.size() <= 7:
					cells.append(cell)
					routes.append(route)
					break
	assert(cells.size() >= 300, "Need >=300 reachable land cells")
	center = world.map_renderer.cell_to_world(origin.x, origin.y)
	world.game_camera.size = 42
	world.game_camera.focus_on(center)

func grow(count: int) -> void:
	status("spawn_%d" % count)
	while units.size() < count:
		var unit: TestUnit3D = UNIT.instantiate()
		unit.set_script(PROFILED)
		world.map_renderer.add_child(unit)
		unit.set_trail_wear(world.map_renderer.trail_wear)
		units.append(unit)
		if units.size() % 10 == 0: await process_frame
	world.player_units.assign(units)
	world.weather.unit = units[0]
	reset_units()

func reset_units() -> void:
	moving = false
	attacking = false
	blood_rate = 0
	blood_carry = 0
	hit_index = 0
	world.rts.orders.reset()
	world.rts.set_selection([])
	world.training.blood.clear()
	for i in units.size():
		units[i].movement_locked = false
		units[i].place_on_cell(cells[i], world.map_renderer.cell_to_world(cells[i].x, cells[i].y))

func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "-" + label + ".png")

func dispatcher_test() -> void:
	reset_units()
	status("dispatcher_300")
	var rejected := [0]
	var callback := func(ok: bool, _point: Vector3, _text: String):
		if not ok: rejected[0] += 1
	world.rts.orders.result_received.connect(callback)
	var started := Time.get_ticks_usec()
	world.rts.orders.move(units, world.map_renderer.world_to_cell(center), false)
	var enqueue_ms := (Time.get_ticks_usec()-started)/1000.0
	var submitted: int = world.rts.orders.pending.size()
	var frames := 0
	while not world.rts.orders.pending.is_empty():
		await process_frame
		frames += 1
	var elapsed_ms := (Time.get_ticks_usec()-started)/1000.0
	world.rts.orders.result_received.disconnect(callback)
	print("DISPATCHER ", JSON.stringify({"requested": units.size(), "submitted": submitted, "rejected": rejected[0], "enqueue_ms": enqueue_ms, "until_drained_ms": elapsed_ms, "frames": frames}))
	var file := FileAccess.open(OUT + "-dispatcher.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"requested": units.size(), "submitted": submitted, "rejected": rejected[0], "enqueue_ms": enqueue_ms, "until_drained_ms": elapsed_ms, "frames": frames}, "\t"))

func run() -> void:
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	create_timer(1200).timeout.connect(func(): push_error("STRESS_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	world.set_script(preload("res://tests/stress_world.gd"))
	world.battle_test = false
	root.add_child(world)
	world.simulation_speed = 0
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world.weather.climate.fog = 0
	world.weather.climate.fog_override = 0
	world._set_time_of_day(12)
	world.training.set_process(false)
	world.training.blood.set_process(false)
	for unit in world.player_units + [world.training.npc]:
		unit.visible = false
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.remove_from_group("rts_units")
	world.get_node("UI").visible = false
	find_fixture()
	if "--extra" in OS.get_cmdline_user_args():
		await extra_diagnostics()
		status("complete")
		print("UNIT_STRESS_EXTRA_PASS")
		quit()
		return
	for count in [5, 50, 100, 150, 200, 250, 300]:
		await grow(count)
		await measure("idle")
		moving = true
		await measure("move")
		reset_units()
		attacking = true
		for unit in units:
			unit.movement_locked = true
			unit.visual.player.play("Attack_Combo", 0)
			unit.visual.player.seek(unit.visual.animation_phase * 3.6)
		blood_rate = count / 2.0
		await measure("attack_blood")
		if count in [50, 300]: await screenshot("%d-blood" % count)
	# Single-variable diagnostic toggles: deliberately not production fixes.
	reset_units()
	attacking = true
	for unit in units:
		unit.movement_locked = true
		unit.visual.player.play("Attack_Combo", 0)
		unit.visual.player.seek(unit.visual.animation_phase * 3.6)
	await measure("diag_attack_no_blood")
	for i in 96: world.training.blood.spawn_hit(units[i].global_position, Vector3.RIGHT)
	world.training.blood._drain()
	for record in world.training.blood.records: record.born = world.training.blood.clock - 60
	world.training.blood.flush()
	await measure("diag_attack_static_blood")
	blood_rate = 150
	await measure("diag_attack_dynamic_blood")
	reset_units()
	moving = true
	await measure("diag_move_base")
	world.rts.set_selection(units)
	await measure("diag_move_selected")
	world.rts.set_selection([])
	for unit in units: unit.set_trail_wear(null)
	await measure("diag_move_no_trails")
	for unit in units: unit.set_trail_wear(world.map_renderer.trail_wear)
	reset_units()
	for unit in units:
		unit.movement_locked = true
		unit.visual.player.pause()
	await measure("diag_idle_frozen_animation")
	reset_units()
	for unit in units:
		var cape: MeshInstance3D = unit.visual.get_node("Model").find_child("Cape_001", true, false)
		cape.visible = false
	await measure("diag_idle_no_cape")
	for unit in units: unit.visual.get_node("Model").find_child("Cape_001", true, false).visible = true
	world.key_light.shadow_enabled = false
	await measure("diag_idle_no_shadows")
	world.key_light.shadow_enabled = true
	world.map_renderer.resource_root.visible = false
	await measure("diag_idle_no_forest")
	world.map_renderer.resource_root.visible = true
	root.scaling_3d_scale = 0.5
	await measure("diag_idle_half_resolution")
	root.scaling_3d_scale = 1.0
	await dispatcher_test()
	status("complete")
	print("UNIT_STRESS_PASS")
	quit()

func extra_diagnostics() -> void:
	await grow(300)
	var geometry := []
	for name in ["Terrain", "TerrainShadowReceiver", "Water"]:
		var node: MeshInstance3D = world.map_renderer.get_node(name)
		var indices := 0
		var vertices := 0
		for surface in node.mesh.get_surface_count():
			indices += node.mesh.surface_get_array_index_len(surface)
			vertices += node.mesh.surface_get_array_len(surface)
		geometry.append({"node": name, "triangles": indices/3, "vertices": vertices})
	print("GEOMETRY ", JSON.stringify(geometry))
	await measure("extra_idle_baseline")
	world.map_renderer.terrain_shadow_receiver.visible = false
	await measure("extra_idle_no_terrain_shadow_receiver")
	world.map_renderer.terrain_shadow_receiver.visible = true
	world.map_renderer.terrain.visible = false
	await measure("extra_idle_no_terrain")
	world.map_renderer.terrain.visible = true
	world.map_renderer.water.visible = false
	await measure("extra_idle_no_water")
	world.map_renderer.water.visible = true
	world.set_process(false)
	await measure("extra_idle_no_world_tick")
	world.set_process(true)
	# Pause only animation evaluation; keep normal idle unit _process active.
	for unit in units: unit.visual.player.active = false
	await measure("extra_idle_animation_inactive")
	for unit in units: unit.visual.player.active = true
	world.weather.climate.set_rain(true)
	world.weather.climate.rain = 0.8
	world.weather.climate.cloud = 1.0
	world.weather.climate.fog_override = 0.65
	world.weather.climate.fog = 0.65
	await measure("extra_idle_rain_fog")
	await screenshot("300-rain-fog")
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world.weather.climate.fog_override = 0
	world.weather.climate.fog = 0
	root.size = Vector2i(1920, 1080)
	await measure("extra_idle_1080p")
	root.size = Vector2i(1280, 720)
	await measure("extra_idle_repeat")
