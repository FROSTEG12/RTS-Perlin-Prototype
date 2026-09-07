extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D
var rts: Control

func _initialize() -> void:
	call_deferred("run")

func mouse(point: Vector2, button: int, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	root.push_input(event, true)

func click(point: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	mouse(point, button, true, shift)
	mouse(point, button, false, shift)
	await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame

func run() -> void:
	create_timer(100).timeout.connect(func(): push_error("RTS TEST TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.weather.climate.set_rain(false)
	world.weather.climate.rain = 0
	world.weather.climate.cloud = 0
	world.weather.climate.fog = 0
	world._set_time_of_day(12)
	rts = world.rts
	assert(world.player_units.size() == 5)
	assert(rts.units().size() == 5)
	assert(rts.selected.is_empty())
	var unit: TestUnit3D = world.test_unit
	var origin := unit.grid_cell
	world.game_camera.focus_on(unit.global_position)
	world.game_camera.size = 13
	for frame in 8: await process_frame
	var center: Vector2 = rts.unit_screen_rect(unit).get_center()
	await click(center)
	assert(rts.selected == [unit], "LMB selects, never moves")
	assert(unit.target_cells.is_empty() and unit.get_node("SelectionRing").visible)
	await click(center, MOUSE_BUTTON_LEFT, true)
	assert(rts.selected.is_empty(), "Shift-click toggles")
	# Reverse-direction drag through all five units.
	var box: Rect2 = rts.unit_screen_rect(unit)
	for other in world.player_units: box = box.merge(rts.unit_screen_rect(other))
	mouse(box.end + Vector2(8, 8), MOUSE_BUTTON_LEFT, true)
	mouse(box.position - Vector2(8, 8), MOUSE_BUTTON_LEFT, false)
	await process_frame
	assert(rts.selected.size() == 5, "Box selection")
	var goal := origin
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5)]:
		if not world.pathfinder.find_path(origin, origin + offset).is_empty():
			goal = origin + offset
			break
	assert(goal != origin)
	# Stop automatic movement while checking queue behavior deterministically.
	for other in world.player_units: other.set_process(false)
	var destination: Vector3 = world.map_renderer.cell_to_world(goal.x, goal.y)
	await click(world.game_camera.unproject_position(destination), MOUSE_BUTTON_RIGHT)
	for frame in 3: await process_frame
	assert(rts.orders.pending.is_empty())
	assert(not unit.target_cells.is_empty(), "RMB orders movement")
	var endpoints := {}
	for other in world.player_units:
		assert(not other.target_cells.is_empty())
		endpoints[other.target_cells.back()] = true
	assert(endpoints.size() == 5, "Distinct group endpoints")
	var preview_id := unit.path_preview.multimesh.get_instance_id()
	rts.set_selection([unit])
	await click(world.game_camera.unproject_position(world.map_renderer.cell_to_world(origin.x, origin.y)), MOUSE_BUTTON_RIGHT, true)
	for frame in 2: await process_frame
	assert(unit.move_orders.size() == 2 and unit.target_cells.back() == origin, "Shift RMB queues")
	# Invalid targets leave the accepted route intact.
	var route_before := unit.target_cells.duplicate()
	rts.orders.move([unit], Vector2i(-1, -1), false)
	await process_frame
	assert(unit.target_cells == route_before)
	# Release over GUI cancels drag rather than selecting through it.
	mouse(center, MOUSE_BUTTON_LEFT, true)
	mouse(Vector2(30, 30), MOUSE_BUTTON_LEFT, false)
	await process_frame
	assert(not rts.selecting and rts.selected == [unit])
	# LMB empty clears selection but not the route.
	await click(Vector2(850, 80))
	assert(rts.selected.is_empty() and unit.target_cells == route_before)
	# Advance partially; new order must preserve the forward segment anchor.
	unit._process(0.1)
	var anchor: Vector2i = unit.target_cells.front()
	rts.set_selection([unit])
	rts.orders.move([unit], goal, false)
	await process_frame
	assert(unit.target_cells.front() == anchor)
	assert(unit.move_orders.size() == 1)
	assert(unit.path_preview.multimesh.get_instance_id() == preview_id)
	for step in 100: unit._process(0.01)
	assert(unit.visual.player.current_animation == "jog")
	# Stop invalidates even orders not yet processed; S must not move the camera.
	var camera_before: Vector3 = world.game_camera.global_position
	rts.orders.move([unit], origin, true)
	await key(KEY_S)
	for frame in 2: await process_frame
	assert(unit.target_cells.is_empty() and unit.move_orders.is_empty() and rts.orders.pending.is_empty())
	assert(world.game_camera.global_position == camera_before)
	assert(unit.visual.player.current_animation == "idle")
	world.game_camera.position.x += 2
	await key(KEY_SPACE)
	var focus: Vector3 = world.game_camera.screen_to_ground(root.get_visible_rect().size * 0.5)
	assert(Vector2(focus.x, focus.z).distance_to(Vector2(unit.global_position.x, unit.global_position.z)) < 0.01)
	# Build mode owns its clicks; Escape cancels it, preserving selection.
	world.building_button.button_pressed = true
	await key(KEY_ESCAPE)
	assert(not world.is_placing_building and rts.selected == [unit])
	# Selected five for a visual preview with routes.
	rts.set_selection(world.player_units)
	rts.orders.move(world.player_units, goal, false)
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "rts-five-selected.png")
	await key(KEY_G)
	assert(rts.grid_overlay.visible)
	var mask: Image = rts.grid_overlay.mask.get_image()
	for y in world.DEFAULT_MAP_SIZE:
		for x in world.DEFAULT_MAP_SIZE:
			assert((mask.get_pixel(x, y).r > 0.5) == world.pathfinder.astar_grid.is_point_solid(Vector2i(x, y)))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "rts-walkability-grid.png")
	await key(KEY_G)
	assert(not rts.grid_overlay.visible)
	world.generate_world()
	assert(rts.selected.is_empty() and rts.orders.pending.is_empty())
	assert(rts.units().size() == 5)
	for other in world.player_units:
		assert(other.target_cells.is_empty() and other.move_orders.is_empty())
		assert(other.trail_wear == world.map_renderer.trail_wear)
	print("RTS_CONTROLS_PASS five_units click shift box group_move queue invalid_target GUI deselect retarget stop focus building reset shared_preview grid")
	quit()
