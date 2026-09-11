extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	if DisplayServer.get_name() != "headless":
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	world.vision.set_enabled(false)
	world.weather.set_process(false)
	world.weather.fog_quad.hide()
	var placement = world.placement
	placement.set_process(false)
	world.hud._set_section(0)
	world.hud.buildings.select_category(5)
	assert(world.hud.buildings.building_buttons.size()==5)
	for card in world.hud.buildings.building_buttons:
		world.hud.buildings.scroll.ensure_control_visible(card)
		for i in 4: await process_frame
		var point: Vector2 = card.get_visual_rect().get_center()
		root.warp_mouse(point)
		for down in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=down
			event.position=point
			root.push_input(event,true)
			await process_frame
		assert(placement.active and placement.building_id != &"fortress_walls")
		assert(placement.preview_model is MeshInstance3D)
		assert(placement.preview_model.mesh.resource_path.begins_with("res://assets/buildings/fortress/"))
		var bounds: AABB = placement.preview_model.get_aabb()
		assert(absf(bounds.position.y)<.001 and bounds.size.x<=6.001 and bounds.size.z<=3.001 and bounds.size.y<9)
		assert(bounds.get_center().x<.001 and absf(bounds.get_center().z)<.001)
		var origin := Vector2i(-1,-1)
		for y in range(10,90,3):
			for x in range(10,90,3):
				if card.entry.id == &"fortress_wall" and not placement.validate(Vector2i(x+6,y)).is_empty(): continue
				if placement.validate(Vector2i(x,y)).is_empty(): origin=Vector2i(x,y); break
			if origin.x>=0: break
		assert(origin.x>=0)
		placement.origin_cell=origin
		placement.refresh_preview()
		var initial: Rect2 = placement.bounds_at(origin)
		placement.rotate_step(1)
		assert(placement.quarter_turn==1)
		assert(is_equal_approx(placement.preview_model.rotation.y,PI/2))
		placement.rotate_step(-1)
		assert(placement.bounds_at(placement.origin_cell)==initial)
		var tint: Color = placement.projection_material.get_shader_parameter("tint")
		assert(tint == Color("#8cdaef"))
		world.game_camera.focus_on(placement.preview.position)
		world.game_camera.position+=placement.preview.position-world.game_camera.screen_to_ground(Vector2(640,320))
		placement.preview.show()
		if DisplayServer.get_name() != "headless":
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+str(card.entry.id)+"-ghost.png")
		assert(placement.commit())
		var site = placement.sites.back()
		assert(site.stage==&"completed" and site.model_anchor.get_child_count()==1)
		assert(site.model_anchor.get_child(0) is MeshInstance3D)
		assert(site.model_anchor.get_child(0).material_override == null)
		# An adjacent same-width section shares the exact footprint boundary.
		placement.begin(card.entry.id)
		placement.origin_cell=origin
		placement.refresh_preview()
		assert(not placement.last_error.is_empty())
		assert(placement.projection_material.get_shader_parameter("tint") == Color("#ee7971"))
		if card.entry.id == &"fortress_wall":
			var adjacent: Vector2i = origin+Vector2i(6,0)
			assert(placement.snap_neighbors(adjacent+Vector2i(1,0),false) == adjacent+Vector2i(1,0))
			assert(placement.snap_neighbors(adjacent+Vector2i(1,0),true) == adjacent)
			placement.origin_cell=adjacent
			assert(placement.commit(true) and placement.active)
			assert(not placement.commit(),"Repeated placement cannot overlap the previous module")
		var next_area: Rect2 = placement.bounds_at(origin+Vector2i(placement.dimensions().x,0))
		assert(is_equal_approx(next_area.position.x,initial.end.x))
		placement.cancel()
		world.game_camera.focus_on(site.position)
		world.game_camera.position+=site.position-world.game_camera.screen_to_ground(Vector2(640,270))
		world.game_camera.position.y=world.game_camera.CAMERA_HEIGHT
		# Put one existing test soldier beside the module, not a synthetic size marker.
		var soldier_cell := origin+Vector2i(-1,1)
		if world.map_renderer.is_land(soldier_cell): world.lead_unit.place_on_cell(soldier_cell,world.map_renderer.cell_to_world(soldier_cell.x,soldier_cell.y))
		if DisplayServer.get_name() != "headless":
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+str(card.entry.id)+"-scale.png")
	assert(placement.sites.size()==6)
	print("FORTRESS_MODULES_PASS five_independent_models no_assembly mesh_bounds rotated footprint_adjacent placement")
	quit()
