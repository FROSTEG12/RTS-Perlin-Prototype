extends SceneTree
var world: Node3D
func check_formation() -> void:
	var origin: Vector2i = world.player_units[0].grid_cell
	for i in 15:
		assert(world.player_units[i].grid_cell == origin + Vector2i(i % 5, i / 5), "One soldier per adjacent cell in a 5x3 block")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	assert(world.player_units.size() == 15)
	check_formation()
	assert(world.get_node_or_null("KnightTraining") == null)
	assert(world.get_node_or_null("UI/TrainingPanel") == null)
	assert(world.get_node_or_null("TemporaryBuildings") == null)
	var occupied := {}
	for unit in world.player_units:
		assert(world.map_renderer.is_land(unit.grid_cell) and not occupied.has(unit.grid_cell))
		occupied[unit.grid_cell] = true
		assert(unit.visual.get_node("Model").scene_file_path.ends_with("/blue.scn"))
		unit.set_process(false)
	world.rts.set_selection(world.player_units)
	assert(world.rts.selected.size() == 15)
	assert(not world.developer_tools.visible)
	assert(not world.world_controls.is_visible_in_tree())
	assert(not world.rts.command_panel.is_visible_in_tree())
	for frame in 3: await process_frame
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F1
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await process_frame
	assert(world.developer_tools.visible and world.world_controls.is_visible_in_tree())
	var center: Vector2 = world.developer_tools.panel.get_global_rect().get_center()
	assert(world.rts.over_ui(center))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	assert(not world.developer_tools.visible and not world.rts.over_ui(center))
	assert(world.rts.selected.size() == 15, "Closing tools must not clear selection")
	world.rts.orders.move(world.player_units, world.lead_unit.grid_cell, false)
	assert(world.rts.orders.pending.size() == 15)
	var target_origin: Vector2i = world.rts.orders.pending[0].target
	for i in 15: assert(world.rts.orders.pending[i].target == target_origin + Vector2i(i % 5, i / 5))
	for tick in 400:
		world.rts.orders._process(0.1)
		for unit in world.player_units: unit._process(0.1)
	for unit in world.player_units: assert(unit.target_positions.is_empty())
	check_formation()
	world.rts.stop_selected()
	# Regeneration preserves the agreed full squad and compact footprint.
	world.generate_world()
	assert(world.player_units.size() == 15 and world.rts.units().size() == 15)
	check_formation()
	print("WORLD_SMOKE_PASS fifteen_blue_units 5x3 adjacent_cells movement selection reset no_combat")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		world.game_camera.set_process(false)
		world.game_camera.size = 9.0
		world.game_camera.focus_on(world.player_units[7].global_position)
		world.rts.grid_overlay.visible = true
		world.rts.set_selection([])
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/squad15-formation.png")
	quit()
