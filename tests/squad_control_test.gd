extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	root.size = Vector2i(1280,720)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	for frame in 5: await process_frame
	var rts = world.rts
	var unit = world.player_units[7]
	rts.set_selection([unit])
	assert(rts.selected.size() == 15)
	rts.select_unit(unit, true)
	assert(rts.selected.is_empty())
	rts.select_unit(unit)
	rts._set_hover(unit)
	for member in world.player_units:
		assert(member.selected and member.hovered)
		assert(not member.get_node("SelectionRing").visible)
	var center := Vector3.ZERO
	for member in world.player_units: center += member.global_position
	assert(rts.squad_center(world.lead_unit).is_equal_approx(center / 15))
	var old_center: Vector3 = rts.squad_center(unit)
	world.lead_unit.position.x += 3.0
	assert(rts.squad_center(unit).is_equal_approx(old_center + Vector3(0.2,0,0)))
	world.lead_unit.position.x -= 3.0
	world.game_camera.size = 12
	world.game_camera.focus_on(center / 15)
	rts.set_selection([])
	var badge: Vector2 = rts.badge_rect(world.lead_unit).get_center()
	assert(rts.hit_unit(badge) == world.lead_unit)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = badge
		root.push_input(click, true)
		await process_frame
	assert(rts.selected.size() == 15)
	rts.orders.move([unit], unit.grid_cell, false)
	assert(rts.orders.pending.size() == 15)
	rts.orders.stop([unit])
	assert(rts.orders.pending.is_empty())
	# Individual control is explicitly opt-in, not removed from the engine.
	unit.individual_control = true
	rts.set_selection([unit])
	assert(rts.selected == [unit])
	rts.orders.move([unit], unit.grid_cell, false)
	assert(rts.orders.pending.size() == 1)
	rts.orders.stop([unit])
	unit.individual_control = false
	rts.set_selection([unit])
	assert(rts.selected.size() == 15)
	var skills = world.hud.skill_slots
	for i in 6:
		for down in [true, false]:
			var key := InputEventKey.new()
			key.physical_keycode = skills.KEYS[i]
			key.pressed = down
			root.push_input(key, true)
			await process_frame
		assert(skills.last_requested == i)
		assert(skills.slots[i].button_pressed, "Release must retain active state")
		for other in 6: assert(skills.slots[other].button_pressed == (other == i))
		var repeated := InputEventKey.new()
		repeated.physical_keycode = skills.KEYS[i]
		repeated.pressed = true
		repeated.echo = true
		root.push_input(repeated, true)
		await process_frame
		assert(skills.slots[i].button_pressed, "Key repeat must not toggle")
	# Another key transfers activation; there can never be two active slots.
	assert(skills.slots[5].button_pressed)
	for down in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Q
		key.pressed = down
		root.push_input(key, true)
		await process_frame
	assert(skills.slots[0].button_pressed and not skills.slots[5].button_pressed)
	# Mouse clicks share the exact same persistent toggle state.
	var slot_point: Vector2 = skills.slots[1].get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = slot_point
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = slot_point
		root.push_input(click, true)
		await process_frame
	assert(skills.slots[1].button_pressed and not skills.slots[0].button_pressed)
	world.pause_menu.set_open(true)
	var paused_key := InputEventKey.new()
	paused_key.physical_keycode = KEY_W
	paused_key.pressed = true
	root.push_input(paused_key, true)
	await process_frame
	assert(skills.slots[1].button_pressed, "Pause preserves toggles and blocks hotkeys")
	world.pause_menu.set_open(false)
	for member in world.player_units:
		rts._feedback(true, member.global_position, "Движение")
		assert(rts.feedback_timer == 0, "No per-soldier confirmation circles")
	assert(rts.orders.pending.is_empty())
	assert(not "bottom" in world.hud and not "cards" in world.hud)
	if DisplayServer.get_name() != "headless":
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/squad-controls.png")
	print("SQUAD_CONTROL_PASS group_selection marker_center_click no_rings special_unit commands six_hotkeys no_old_hud")
	quit()
