extends SceneTree
func _initialize() -> void: call_deferred("run")

func check_draft_row(army: Control) -> void:
	if army.squad_cards.is_empty():
		assert(is_equal_approx(army.add_button.position.x + 36, army.size.x * 0.5))
		return
	var first: Button = army.squad_cards[0]
	var last: Button = army.squad_cards[-1]
	var center: float = (first.position.x + last.position.x + last.size.x) * 0.5
	assert(is_equal_approx(center, army.size.x * 0.5), "Center warriors independently of the +")
	assert(army.add_button.position.x > last.position.x + last.size.x)
	for i in army.squad_cards.size():
		var card: Button = army.squad_cards[i]
		assert(is_equal_approx(card.position.y, first.position.y))
		assert(army.squads[i].state == "planned" and card.pending)
		assert(not card.disabled, "Unformed drafts must remain selectable/removable")
		assert(card.art.material.get_shader_parameter("desaturated") == true)
		assert(card.warning_button.visible and card.warning_button.size == Vector2(34,34))
		assert(card.tooltip_text.is_empty() and card.warning_button.tooltip_text.is_empty())
		assert(not "count_label" in card, "No population counter on cards")

func click(control: Control, mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	var point := control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = mouse_button
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.game_camera.set_process(false)
	for frame in 8: await process_frame
	if DisplayServer.get_name() == "headless": root.notify_mouse_entered()
	var army: Control = world.hud.armies
	var stock: Dictionary = world.stockpile.duplicate()
	assert(army.entries.size() == 5)
	for entry in army.entries:
		assert(entry.capacity == 15)
		assert(entry.emblem.resource_path.begins_with("res://assets/ui/army_emblems/"))
		assert(entry.emblem.get_image().detect_alpha() != Image.ALPHA_NONE)
		assert(entry.portrait.resource_path.ends_with("_cutout.png"))
		var image := Image.load_from_file(ProjectSettings.globalize_path(entry.portrait.resource_path))
		assert(image.detect_alpha() != Image.ALPHA_NONE)
		assert(image.get_pixel(0,0).a == 0)
	assert(army.squads.is_empty())
	await click(world.hud.dock.buttons[1])
	assert(army.visible and not army.chooser.visible)
	assert(not "bottom" in world.hud)
	await click(army.add_button)
	assert(army.chooser.visible and army.heading.text == "Сформировать армию")
	check_draft_row(army)
	for choice in army.choices:
		assert(not choice.pending and not choice.warning_button.visible)
		assert(choice.art.material.get_shader_parameter("desaturated") == false)
	for frame in 8: await process_frame
	for i in 6:
		await click(army.choices[i % 5])
		await create_timer(0.3).timeout
		assert(army.squads.size() == i+1, "Expected %d squads; got %d" % [i+1,army.squads.size()])
		assert(army.selected == i)
		assert(army.squad_cards[i].modulate.a == 1.0)
		assert(army.squad_cards[i].entry.id == army.entries[i%5].id)
		check_draft_row(army)
	assert(army.add_button.disabled)
	for choice in army.choices: assert(choice.disabled)
	army._add_squad(0)
	assert(army.squads.size() == 6)
	assert(world.player_units.size() == 15 and world.stockpile == stock)
	assert(not "requirements" in army and not "close_button" in army)
	assert(not "count_label" in army and not "remove_button" in army)
	assert(army.add_button.size == Vector2(72,72))
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert(army.add_button.get_theme_stylebox(state) is StyleBoxEmpty)
	# Test data only: verify live available/required readout and totals.
	army.entries[0].capacity = 20
	army.entries[0].requirements = {"Дерево": 40, "Металл": 20}
	await click(army.squad_cards[0])
	assert(army.selected == 0)
	assert(army.total_requirements() == {"Дерево":80, "Металл":40})
	world.stockpile["Дерево"] = 15
	army.refresh()
	assert(not army.details_panel.visible, "Ordinary selection must not open requirements")
	await click(army.squad_cards[0].warning_button)
	assert(army.details_panel.visible and army.details_card == army.squad_cards[0])
	assert(army.details_panel.rows[1].value == "15 / 40")
	assert(army.details_panel.rows[1].color == army.details_panel.SHORTAGE)
	world.stockpile["Дерево"] = 40
	army._update_requirements()
	assert(army.details_panel.rows[1].value == "40 / 40")
	assert(army.details_panel.rows[1].color == army.details_panel.LIGHT)
	assert(army.squads[0].state == "planned")
	await click(army.squad_cards[0].warning_button)
	assert(not army.details_panel.visible, "Repeat click closes requirements")
	assert(army.squad_cards[0].count_text == "0 / 20")
	world.stockpile.assign(stock)
	army.entries[0].capacity = 15
	army.entries[0].requirements = {}
	army.refresh()
	var sizes := [Vector2i(960,540),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(2752,1152),Vector2i(2560,1440),Vector2i(3440,1440),Vector2i(3840,2160)]
	if OS.get_cmdline_user_args().has("--hud-single-size"): sizes = [Vector2i(1280,720)]
	for dimensions in sizes:
		root.size = dimensions
		for frame in 8: await process_frame
		assert(root.get_visible_rect().encloses(army.get_global_rect()))
		assert(not army.get_global_rect().intersects(world.hud.minimap.get_global_rect()))
		assert(not army.get_global_rect().intersects(world.hud.dock.get_global_rect()))
		for control in army.choices + army.squad_cards + [army.add_button]:
			assert(root.get_visible_rect().encloses(control.get_global_rect()))
			assert(not control.get_global_rect().intersects(world.hud.minimap.get_global_rect()))
			assert(army.contains(control.get_global_rect().get_center()))
			assert(world.rts.over_ui(control.get_global_rect().get_center()))
		assert(not army.squad_cards[5].get_global_rect().intersects(army.add_button.get_global_rect()))
		assert(not army.chooser.get_global_rect().intersects(army.squad_cards[0].get_global_rect()))
		assert(not army.contains(army.chooser.global_position + Vector2(4,4)), "No invisible full-panel mouse blocker")
		for card in army.choices + army.squad_cards:
			assert(card.art.material.shader.resource_path.ends_with("army_readiness.gdshader"), "Only color changes, no clipping mask")
			assert(card.art.position.y < card.background_top() - 20)
			var crown_y: float = card.art.position.y + card.art.size.y * card.entry.head_y
			assert(is_equal_approx(crown_y, 2.0), "Normalize warrior height independently of weapon length")
			assert(is_equal_approx(card.art.position.y + card.art.size.y, card.footer_top()))
			assert(card.frame_front.get_index() > card.art.get_index(), "Plaque must sit over the waist")
			assert(root.get_visible_rect().encloses(card.art.get_global_rect()))
		assert(army.choices[1].art.position.y < -10, "Pike protrudes above aligned warriors")
		await click(army.squad_cards[4])
		assert(army.selected == 4)
		assert(not army.details_panel.visible)
		await click(army.squad_cards[0].warning_button)
		assert(army.details_panel.visible and army.selected == 4, "Details do not select or activate the squad")
		assert(root.get_visible_rect().encloses(army.details_panel.get_global_rect()))
		assert(army.details_panel.unknown_cost and army.details_panel.rows[0].value == "0 / 15")
		assert(world.rts.over_ui(army.details_panel.get_global_rect().get_center()))
		await click(army.details_panel)
		assert(army.details_panel.visible, "Inside click keeps popup open")
		check_draft_row(army)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			if dimensions == Vector2i(1280,720):
				var mark_center: Vector2 = army.squad_cards[0].warning_button.get_global_rect().get_center()
				var white_pixels := 0
				for px in range(-5,6):
					for py in range(-9,10):
						var color := capture.get_pixel(int(mark_center.x)+px, int(mark_center.y)+py)
						if color.r > 0.8 and color.g > 0.8 and color.b > 0.8: white_pixels += 1
				assert(white_pixels > 15, "The white ! must render OVER the navy disc")
				var disc := capture.get_pixel(int(mark_center.x) - 10, int(mark_center.y))
				assert(disc.r < 0.2 and disc.b < 0.4 and disc.b > disc.r, "Keep the warning background dark navy")
			capture.save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/armies-%dx%d.png" % [dimensions.x,dimensions.y])
		await click(army.squad_cards[0].warning_button)
		assert(not army.details_panel.visible)
		print("ARMY_LAYOUT ", dimensions)
	var previously_selected: Button = army.squad_cards[4]
	world.rts.set_selection([world.player_units[0]])
	var orders_before: Array = world.player_units[0].move_orders.duplicate()
	var revision_before: int = world.player_units[0].order_revision
	await click(army.squad_cards[1].warning_button)
	assert(army.details_panel.visible)
	await click(army.squad_cards[1].warning_button, MOUSE_BUTTON_RIGHT)
	assert(not army.details_panel.visible)
	assert(army.squads.size() == 5 and not army.add_button.disabled)
	check_draft_row(army)
	assert(army.squad_cards[army.selected] == previously_selected, "Right-click removes the hovered, not selected, squad")
	assert(world.player_units[0].move_orders == orders_before, "UI right-click must not issue a movement order")
	assert(world.player_units[0].order_revision == revision_before)
	await click(army.choices[4])
	await create_timer(0.3).timeout
	assert(army.squads.size() == 6)
	await click(army.squad_cards[0].warning_button)
	await click(world.hud.dock.buttons[0])
	assert(not army.details_panel.visible)
	assert(not army.visible and world.hud.buildings.visible)
	await click(world.hud.dock.buttons[1])
	assert(army.squads.size() == 6 and army.visible)
	await click(world.hud.dock.buttons[1])
	assert(not army.visible)
	assert(not army.contains(army.add_button.get_global_rect().get_center()))
	assert(world.stockpile == stock and world.player_units.size() == 15)
	print("ARMY_PASS five_types six_slots animation requirements removal centered_drafts grayscale_pending layout isolation")
	quit()
