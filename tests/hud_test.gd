extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.game_camera.set_process(false)
	for frame in 4: await process_frame
	# Labels refresh at 10 Hz; initial asset uploads can advance the clock by a
	# large frame before the next HUD tick. Sample the same model state here.
	world.hud._update()
	assert(world.stockpile.size() == 6)
	assert(world.hud.daylight.custom_minimum_size == Vector2(36,36))
	assert(world.hud.weather_icon.condition == world.weather.climate.condition())
	assert(world.hud.weather_icon.tooltip_text == world.weather.climate.description())
	assert(world.hud.day_label.text == "День %d" % world.current_day)
	assert(world.hud.daylight.get_index() < world.hud.clock_label.get_index())
	assert(world.hud.clock_label.get_index() < world.hud.day_label.get_index())
	assert(world.hud.day_label.get_index() < world.hud.weather_icon.get_index())
	assert(world.hud.resource_icons.size() == 6)
	assert(world.hud.top.material == null and world.hud.top.flush_left)
	assert(world.hud.status_panel.material == null)
	assert(world.hud.status_panel.slant_left)
	assert(not world.hud.status_panel.flush_left)
	for art in world.hud.resource_icons:
		assert(not art.use_parent_material and art.modulate.a == 1.0)
		assert(art.texture.resource_path.begins_with("res://assets/ui/generated_resources/"))
		assert(art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		# Read the source PNG: headless rendering does not expose imported texture pixels.
		var original := Image.load_from_file(ProjectSettings.globalize_path(art.texture.resource_path))
		assert(original.detect_alpha() != Image.ALPHA_NONE)
		assert(original.get_pixel(0, 0).a < 0.05)
	assert(world.rts.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert(world.rts.SQUAD_BADGE.resource_path.ends_with("army_emblems/infantry.png"))
	assert(world.hud.dock.buttons.size() == 3)
	for button in world.hud.dock.buttons:
		assert(button.glyph.resource_path.begins_with("res://assets/ui/generated_navigation/"))
		var icon_image: Image = button.glyph.get_image()
		assert(icon_image.get_width() <= 256 and icon_image.has_mipmaps())
		assert(icon_image.detect_alpha() != Image.ALPHA_NONE)
		assert(icon_image.get_pixel(0, 0).a == 0.0)
	assert(world.hud.dock.buttons[0].custom_minimum_size == Vector2(56,56))
	assert(world.hud.buildings.get_theme_constant("separation") == 8)
	assert(world.hud.buildings.list_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert(world.hud.buildings.list_panel.material == null)
	assert(world.hud.buildings.category_row.get_child_count() == 6, "No permanent captions or close-box in the category strip")
	assert(world.hud.buildings.categories.size() == 6)
	var building_count := 0
	for category in world.hud.buildings.categories:
		building_count += category.items.size()
		for entry in category.items:
			assert(entry.preview != null)
			assert(entry.preview.resource_path.begins_with("res://assets/ui/buildings/"))
	assert(building_count == 11)
	assert(not "bottom" in world.hud and not "cards" in world.hud)
	assert(not world.hud.buildings.visible)
	world.hud._open_section(0)
	assert(world.hud.buildings.visible)
	world.hud._open_section(2)
	assert(world.hud.buildings.visible and world.hud.formation_panel.visible)
	world.hud._open_section(2)
	assert(world.hud.formation_panel.visible)
	world.hud.formation_panel.close_button.pressed.emit()
	world.hud.formation_library.bindings = ["","","","","",""]
	world.hud.skill_slots.refresh_bindings()
	world.hud.dock.buttons[1].pressed.emit()
	assert(world.hud.armies.visible)
	assert(world.hud.dock.buttons[1].tooltip_text == "Армии")
	world.hud._set_section(-1)
	world.rts.select_unit(world.player_units[2])
	assert(world.rts.selected.size() == 15)
	assert(not world.pause_menu.visible)
	world.rts.set_selection([world.player_units[3]])
	assert(world.rts.selected.size() == 15)
	assert(world.rts.over_ui(world.hud.top.get_global_rect().get_center()))
	var layouts := [Vector2i(960,540), Vector2i(1024,768), Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080), Vector2i(2752,1152), Vector2i(2560,1440), Vector2i(3440,1440), Vector2i(3840,2160)]
	if OS.get_cmdline_user_args().has("--hud-single-size"):
		layouts = [Vector2i(1280,720)]
	var cached_minimap_texture: Texture2D = world.hud.minimap.terrain
	if DisplayServer.get_name() == "headless": root.notify_mouse_entered()
	for dimensions in layouts:
		root.size = dimensions
		for frame in 8: await process_frame
		var physical_scale := root.get_stretch_transform().get_scale().x
		assert(physical_scale <= 1.401)
		assert(world.hud.top.size.x < 800)
		assert(is_zero_approx(world.hud.top.get_global_rect().position.x))
		assert(world.hud.top.size.y * physical_scale < 75)
		for control in [world.hud.top, world.hud.status_panel, world.hud.menu_button, world.hud.dock.buttons[1], world.hud.skill_slots, world.hud.minimap]:
			assert(root.get_visible_rect().encloses(control.get_global_rect()))
			assert(world.rts.over_ui(control.get_global_rect().get_center()))
		assert(absf(world.hud.dock.get_global_rect().get_center().x - root.get_visible_rect().get_center().x) < 1.0)
		assert(not world.hud.contains(Vector2(30, 220)), "Old sidebar must no longer capture world clicks")
		if dimensions == Vector2i(960,540): assert(world.hud.stacked_header)
		if dimensions == Vector2i(1920,1080): assert(not world.hud.stacked_header)
		assert(world.hud.top.get_global_rect().end.x <= root.get_visible_rect().end.x)
		assert(not world.hud.top.get_global_rect().intersects(world.hud.status_panel.get_global_rect()))
		assert(not world.hud.status_panel.get_global_rect().intersects(world.hud.menu_button.get_global_rect()))
		assert(not world.hud.buildings.get_global_rect().intersects(world.hud.minimap.get_global_rect()))
		var map_pixels: float = world.hud.minimap.size.x * physical_scale
		assert(is_equal_approx(world.hud.minimap.size.x, world.hud.minimap.size.y))
		assert(map_pixels >= 219.0 and map_pixels <= 641.0)
		if dimensions.y >= 1080:
			assert(absf(map_pixels - dimensions.y * 0.28) <= 2.0)
		assert(world.hud.minimap.terrain == cached_minimap_texture, "Resizing must not rebuild terrain")
		assert(world.hud.skill_slots.slots.size() == 6)
		assert(world.hud.skill_slots.get_global_rect().end.x < world.hud.dock.global_position.x)
		for slot in world.hud.skill_slots.slots:
			assert(is_equal_approx(slot.size.x, slot.size.y) and slot.size.x >= 48 and slot.size.x <= 64)
			if dimensions.x >= 1280: assert(slot.size == Vector2(64, 64))
		assert(world.hud.skill_slots.get_global_rect().end.x <= world.hud.dock.global_position.x - 8)
		await gui_click(world.hud.skill_slots.slots[0])
		assert(world.rts.selected.size() == 15)
		# Click the same world destination through the resized map's actual GUI.
		var camera_before: Transform3D = world.game_camera.global_transform
		var destination := Vector3(8, 0, 6)
		var map_point: Vector2 = world.hud.minimap.global_position + world.hud.minimap.project(destination)
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = map_point
			click.global_position = map_point
			root.push_input(click, true)
			await process_frame
		var centered: Vector3 = world.game_camera.screen_to_ground(root.get_visible_rect().get_center())
		assert(centered.distance_to(destination) < 0.01, "Minimap click must match world position after resize")
		assert(world.rts.selected.size() == 15)
		world.game_camera.global_transform = camera_before
		await gui_click(world.hud.dock.buttons[0])
		world.hud.buildings.clear_category()
		for frame in 8: await process_frame
		await gui_click(world.hud.buildings.category_buttons[2])
		for frame in 8: await process_frame
		assert(world.hud.buildings.building_buttons.size() == 2)
		assert(is_equal_approx(world.hud.buildings.list_panel.size.x, world.hud.buildings.category_bar.size.x))
		assert(is_equal_approx(world.hud.buildings.list_panel.get_global_rect().end.y + 8, world.hud.buildings.category_bar.global_position.y))
		var empty_point: Vector2 = world.hud.buildings.list_panel.global_position + Vector2(5, 30)
		assert(not world.hud.contains(empty_point), "Removed preview backdrop must not block world input")
		for tile in world.hud.buildings.building_buttons:
			assert(tile.size.x < tile.size.y, "Portrait-format building tile")
			assert(tile.find_children("*", "Label", true, false).is_empty(), "Tile names are hover tooltips only")
			assert(not tile.tooltip_text.is_empty())
		await gui_click(world.hud.buildings.building_buttons[1])
		assert(world.placement.active and not world.hud.buildings.list_panel.visible)
		world.placement.cancel()
		await create_timer(0.22).timeout
		var raised: Control = world.hud.buildings.building_buttons[1]
		var resting: Control = world.hud.buildings.building_buttons[0]
		assert(raised.face.size == Vector2(128,204))
		assert(is_zero_approx(raised.face.position.y))
		assert(is_equal_approx(resting.face.position.y, 18))
		assert(raised.marker.visible and not resting.marker.visible)
		assert(world.hud.contains(raised.get_visual_rect().position + Vector2(5,5)))
		assert(not world.hud.contains(resting.global_position + Vector2(5,5)))
		# Selecting the other tile returns the old tile to its resting position.
		await gui_click(resting)
		await create_timer(0.22).timeout
		assert(is_equal_approx(raised.face.position.y, 18))
		assert(is_zero_approx(resting.face.position.y))
		await gui_click(raised)
		assert(world.placement.active and not world.hud.buildings.list_panel.visible)
		world.placement.cancel()
		await create_timer(0.22).timeout
		assert(world.hud.buildings.active_building == &"sawmill")
		assert(world.rts.selected.size() == 15)
		for panel in [world.hud.buildings.list_panel, world.hud.buildings.category_bar]:
			assert(root.get_visible_rect().encloses(panel.get_global_rect()))
			assert(not panel.get_global_rect().intersects(world.hud.minimap.get_global_rect()))
			assert(not panel.get_global_rect().intersects(world.hud.dock.get_global_rect()))
		if DisplayServer.get_name() != "headless" and dimensions in [Vector2i(960,540), Vector2i(1280,720)]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/buildings-%dx%d.png" % [dimensions.x, dimensions.y])
			if dimensions == Vector2i(1280,720):
				var shelf: Rect2 = world.hud.buildings.get_global_rect().merge(world.hud.dock.get_global_rect()).grow(4)
				root.get_texture().get_image().get_region(Rect2i(shelf)).save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/manor-menu-detail.png")
		await gui_click(world.hud.buildings.category_buttons[2])
		assert(not world.hud.buildings.list_panel.visible)
		for category_index in 6:
			await gui_click(world.hud.buildings.category_buttons[category_index])
			for frame in 4: await process_frame
			assert(world.hud.buildings.building_buttons.size() == [1, 1, 2, 1, 1, 5][category_index])
			assert(root.get_visible_rect().encloses(world.hud.buildings.get_global_rect()))
			await gui_click(world.hud.buildings.building_buttons[0])
			assert(not world.hud.buildings.active_building.is_empty())
			if category_index == 5:
				assert(world.hud.buildings.active_building == &"fortress_wall")
				await create_timer(0.22).timeout
				assert(world.hud.buildings.building_buttons[0].artwork.texture.resource_path.ends_with("modules/wall.png"))
				if dimensions == Vector2i(1280,720) and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var shelf: Rect2 = world.hud.buildings.get_global_rect().merge(world.hud.dock.get_global_rect()).grow(4)
					root.get_texture().get_image().get_region(Rect2i(shelf)).save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/fortifications-menu-detail.png")
			assert(world.rts.selected.size() == 15)
		world.hud.buildings.clear_category()
		await gui_click(world.hud.dock.buttons[1])
		assert(world.hud.armies.visible)
		world.hud._set_section(-1)
		for frame in 8: await process_frame
		print("MINIMAP_LAYOUT ", dimensions, " side_px=", map_pixels)
		print("HUD_LAYOUT ", root.size, " virtual=", root.get_visible_rect().size, " scale=", physical_scale, " bar=", world.hud.top.size, " stacked=", world.hud.stacked_header)
		if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--hud-screenshots"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/hud-adaptive-%dx%d.png" % [dimensions.x, dimensions.y])
	assert(not world.hud.minimap.is_contact_visible(1, []))
	assert(world.hud.minimap.is_contact_visible(1, [0]))
	world.local_team_id = 1
	assert(not world.hud.minimap.is_contact_visible(0, [0]))
	assert(world.hud.minimap.is_contact_visible(0, [1]))
	world.local_team_id = 0
	for point in [Vector3.ZERO, Vector3(20,0,-30), Vector3(-50,0,50)]:
		assert(world.hud.minimap.unproject(world.hud.minimap.project(point)).distance_to(point) < 0.001)
	for unit in world.player_units:
		for mesh in unit.visual.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			assert(mesh.material_overlay == null)
	world.pause_menu.set_open(true)
	assert(paused and world.game_camera.controls_blocked)
	var time: float = world.current_time
	root.size = Vector2i(1280,720)
	for frame in 8: await process_frame
	assert(root.get_visible_rect().size.is_equal_approx(Vector2(1280,720)))
	assert(root.get_visible_rect().encloses(world.hud.menu_button.get_global_rect()))
	assert(world.current_time == time)
	world.pause_menu.apply_preview()
	assert(world.pause_menu.remaining > 0)
	world.pause_menu._process(16)
	assert(world.pause_menu.remaining == 0)
	world.pause_menu.set_open(false)
	assert(not paused and not world.game_camera.controls_blocked)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/hud-world.png")
		world.pause_menu.set_open(true)
		world.pause_menu.panel.hide()
		world.pause_menu.settings.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/hud-settings.png")
	print("HUD_PASS resources roster selection aspect pause timeout")
	quit()

func gui_click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	# Move the pointer too, including after graphical resize/screenshot capture.
	# This clears stale hover/tooltip state before the actual press and release.
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = point
		click.global_position = point
		root.push_input(click, true)
		await process_frame
