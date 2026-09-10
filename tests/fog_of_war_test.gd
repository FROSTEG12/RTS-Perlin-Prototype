extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/" + file)
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var fog = world.fog_of_war
	assert(fog.sources().size() == 1)
	var start: Vector3 = fog.sources()[0].position
	assert(fog.state.is_visible(start))
	assert(world.hud.minimap.terrain_material.get_shader_parameter("sight_mask") == fog.state.texture)
	var idle_revision: int = fog.state.revision
	fog.update_sight(false)
	assert(fog.state.revision == idle_revision)
	# Dummy/headless rendering does not retain MultiMesh transform buffers.
	if DisplayServer.get_name() != "headless":
		var hidden := 0
		var shown := 0
		for batch in fog.batches:
			for i in batch.transforms.size():
				var instance: Transform3D = batch.node.multimesh.get_instance_transform(i)
				if instance.basis.determinant() == 0: hidden += 1
				else: shown += 1
		assert(hidden > 0 and shown > 0)
		print("FOG_MULTIMESH_PASS hidden_and_revealed_instances")
	var away := Vector3(-36,0,36)
	if away.distance_to(start) < 35: away = Vector3(36,0,-36)
	var tall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2,20,2)
	tall.mesh = box
	world.add_child(tall)
	tall.position = away
	tall.add_to_group("fog_static")
	var enemy := Node3D.new()
	world.add_child(enemy)
	enemy.position = away
	enemy.add_to_group("fog_dynamic")
	fog.update_sight()
	assert(not tall.visible and not enemy.visible)
	assert(not world.hud.minimap.is_contact_visible(1,[0],away))
	enemy.position = start
	fog.update_sight(false)
	assert(enemy.visible)
	enemy.position = away
	fog.update_sight(false)
	assert(not enemy.visible)
	world.game_camera.size = 30
	world.game_camera.focus_on(start)
	await capture("fog-start.png")
	var original: Array[Vector3] = []
	for unit in world.player_units:
		original.append(unit.global_position)
		unit.global_position += away - start
	fog.update_sight()
	assert(fog.state.is_explored(start) and not fog.state.is_visible(start))
	assert(tall.visible and enemy.visible)
	assert(world.hud.minimap.is_contact_visible(1,[0],away))
	world.game_camera.focus_on((start + away) * 0.5)
	world.game_camera.size = 42
	await capture("fog-explored.png")
	for i in world.player_units.size(): world.player_units[i].global_position = original[i]
	fog.update_sight()
	assert(tall.visible and not enemy.visible)
	assert(not world.hud.minimap.is_contact_visible(1,[0],away))
	world.pause_menu.set_open(true)
	var revision: int = fog.state.revision
	for frame in 5: await process_frame
	assert(fog.state.revision == revision)
	world.pause_menu.set_open(false)
	tall.free()
	enemy.free()
	world.generate_world()
	assert(not fog.state.is_explored(away))
	assert(fog.state.is_visible(fog.sources()[0].position))
	print("FOG_WORLD_PASS squad exploration hidden_trees tall_objects enemies minimap memory pause regeneration")
	quit()
