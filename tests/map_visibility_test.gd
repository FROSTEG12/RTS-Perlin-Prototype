extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+file)
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	root.size = Vector2i(1280,720)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var vision = world.vision
	vision.set_process(false)
	assert(vision.sources().size() == 1)
	assert(vision.overlay.mesh is QuadMesh and vision.material.render_priority == 127)
	assert(not world.weather.fog_material.shader.code.contains("unit_position"))
	assert(world.hud.minimap.terrain_material.get_shader_parameter("sight_mask") == vision.state.texture)
	var start: Vector3 = vision.sources()[0].position
	var original: Array[Vector3] = []
	for unit in world.player_units: original.append(unit.global_position)
	world.game_camera.size = 37
	world.game_camera.focus_on(start)
	await capture("visibility-start.png")
	# Move continuously across actual frames, not just teleport screenshots.
	var peak_update_usec := 0
	for frame in 72:
		for unit in world.player_units: unit.global_position.x += 0.06
		var tick := Time.get_ticks_usec()
		vision._process(1.0/60.0)
		peak_update_usec = maxi(peak_update_usec,Time.get_ticks_usec()-tick)
		assert(vision.state.blend >= 0 and vision.state.blend <= 1)
		if frame in [24,48,71]: await capture("visibility-move-%d.png" % frame)
		await process_frame
	print("VISIBILITY_UPDATE_PEAK_USEC ",peak_update_usec)
	var away := Vector3(-33,0,33)
	if away.distance_to(start) < 32: away = Vector3(33,0,-33)
	for i in world.player_units.size(): world.player_units[i].global_position = original[i]+away-start
	vision.refresh_sight(true)
	assert(vision.state.is_explored(start) and not vision.state.is_visible(start))
	# The ground is known, but buildings added after departure are not.
	var building := MeshInstance3D.new()
	building.mesh = BoxMesh.new()
	world.add_child(building)
	building.global_position = start
	building.add_to_group("vision_static")
	var enemy := MeshInstance3D.new()
	enemy.mesh = BoxMesh.new()
	world.add_child(enemy)
	enemy.global_position = start + Vector3(1,0,0)
	enemy.add_to_group("vision_dynamic")
	vision.objects.refresh()
	assert(not building.visible and not enemy.visible and not vision.can_observe(enemy))
	world.hud.minimap.set_landmark(777,start,"building",1,[0])
	assert(world.hud.minimap.visible_landmarks().is_empty())
	assert(not world.hud.minimap.is_contact_visible(1,[0],start))
	for i in world.player_units.size(): world.player_units[i].global_position = original[i]
	vision.refresh_sight(true)
	assert(building.visible and enemy.visible and vision.can_observe(enemy))
	assert(world.hud.minimap.visible_landmarks().size() == 1)
	var id := building.get_instance_id()
	assert(vision.objects.records[id].snapshot.get_child_count() == 1)
	for i in world.player_units.size(): world.player_units[i].global_position = original[i]+away-start
	vision.refresh_sight(true)
	assert(not building.visible and not enemy.visible)
	var memory: Node3D = vision.objects.records[id].snapshot
	assert(memory.visible)
	building.scale *= 3
	world.hud.minimap.set_landmark(777,start,"watchtower",1,[0])
	assert(world.hud.minimap.visible_landmarks()[0].kind == "building")
	assert(memory.get_child(0).scale == Vector3.ONE)
	building.free()
	world.hud.minimap.remove_landmark(777)
	vision.objects.refresh()
	assert(memory.visible and world.hud.minimap.visible_landmarks().size() == 1)
	world.game_camera.focus_on((start+away)*0.5)
	world.game_camera.size = 50
	await capture("visibility-explored.png")
	world.game_camera.focus_on(Vector3(48,0,48))
	await capture("visibility-edge.png")
	for i in world.player_units.size(): world.player_units[i].global_position = original[i]
	vision.refresh_sight(true)
	assert(not vision.objects.records.has(id))
	assert(world.hud.minimap.visible_landmarks().is_empty())
	enemy.free()
	# A tracked actor also cannot remain selected or expose its path after leaving sight.
	var hidden_unit: Unit3D = world.player_units.pop_back()
	hidden_unit.individual_control = true
	hidden_unit.add_to_group("vision_dynamic")
	hidden_unit.global_position = away
	vision.refresh_sight(true)
	world.rts.set_selection([hidden_unit])
	assert(world.rts.selected.is_empty() and hidden_unit not in world.rts.units())
	hidden_unit.global_position = start
	vision.objects.refresh()
	world.rts.set_selection([hidden_unit])
	assert(world.rts.selected == [hidden_unit])
	hidden_unit.global_position = away
	vision.objects.refresh()
	world.rts._process(0.016)
	assert(world.rts.selected.is_empty() and not hidden_unit.selected)
	hidden_unit.remove_from_group("vision_dynamic")
	hidden_unit.individual_control = false
	hidden_unit.global_position = original.back()
	hidden_unit.visible = true
	world.player_units.append(hidden_unit)
	vision.refresh_sight(true)
	# Stationary squads also lose sight at night, without losing explored ground.
	var saved_hour: float = world.current_time
	world._set_time_of_day(12.0)
	vision.refresh_sight(true)
	var probe: Vector3 = vision.sources()[0].position+Vector3(9,0,0)
	assert(vision.sources()[0].radius == 10.0 and vision.state.is_visible(probe))
	world.game_camera.focus_on(start)
	world.game_camera.size = 37
	await capture("visibility-day-range.png")
	world._set_time_of_day(0.0)
	vision._process(0.11)
	assert(vision.last_sources[0].radius == 7.0)
	assert(not vision.state.is_visible(probe) and vision.state.is_explored(probe))
	vision._process(0.11)
	assert(vision.state.blend == 1.0)
	await capture("visibility-night-range.png")
	world._set_time_of_day(saved_hour)
	vision.refresh_sight(true)
	world.pause_menu.set_open(true)
	vision.set_process(true)
	var revision: int = vision.state.revision
	var blend: float = vision.state.blend
	var edge_clock: float = vision.edge_clock
	for frame in 4: await process_frame
	assert(vision.state.revision == revision and vision.state.blend == blend)
	assert(vision.edge_clock == edge_clock,"Edge animation pauses with the game")
	world.pause_menu.set_open(false)
	world.generate_world()
	assert(vision.objects.records.is_empty() and not vision.state.is_explored(away))
	assert(world.hud.minimap.terrain_material.get_shader_parameter("sight_mask") == vision.state.texture)
	print("MAP_VISIBILITY_PASS smooth_motion unseen_new_building enemy_hide snapshots destruction minimap day_night pause reset")
	quit()
