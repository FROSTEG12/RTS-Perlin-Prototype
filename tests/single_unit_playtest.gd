extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	assert(world.player_units.size()==1)
	assert(world.lead_unit.individual_control)
	assert(not world.vision.enabled and not world.vision.overlay.visible)
	assert(not world.hud.skill_slots.visible)
	assert(not world.hud.navigation_buttons[2].visible)
	assert(world.hud.navigation_buttons[0].visible and world.hud.navigation_buttons[1].visible)
	world.hud._open_section(2)
	world.hud.open_inventory()
	world.hud.formation_panel.open()
	assert(not world.hud.formation_panel.visible and not world.hud.formation_inventory.visible)
	for code in [KEY_Q,KEY_W,KEY_E,KEY_D,KEY_F,KEY_R]:
		var event := InputEventKey.new()
		event.physical_keycode=code
		event.pressed=true
		root.push_input(event,true)
		await process_frame
	assert(not world.hud.formation_panel.visible and not world.hud.formation_inventory.visible)
	var unit = world.lead_unit
	unit.set_process(false)
	var destination: Vector2i = unit.grid_cell
	for offset in [Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3)]:
		if not world.pathfinder.find_path(unit.grid_cell,unit.grid_cell+offset).is_empty(): destination=unit.grid_cell+offset; break
	assert(destination!=unit.grid_cell)
	var route: Array[Vector2i] = world.pathfinder.find_path(unit.grid_cell,destination)
	assert(unit.accept_move(route,world.map_renderer,false))
	for frame in 600: unit._process(1.0/60)
	assert(unit.target_cells.is_empty() and unit.grid_cell==destination)
	world.vision.set_enabled(true)
	assert(world.vision.overlay.visible)
	world.vision.set_enabled(false)
	assert(not world.vision.overlay.visible)
	# Flags restore the existing interfaces without rebuilding or losing templates.
	world.formation_features_enabled=true
	world.hud.formation_panel.open()
	assert(world.hud.formation_panel.visible)
	print("SINGLE_UNIT_PLAYTEST_PASS one_individual movement hidden_ui inactive_hotkeys fog_default_off reversible")
	world.queue_free()
	await process_frame
	quit()
