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
		for mesh in placement.MODEL.meshes(placement.preview_model):
			assert(mesh.mesh.resource_path.begins_with("res://assets/buildings/fortress/"))
		var bounds: AABB = placement.MODEL.bounds(placement.preview_model)
		assert(absf(bounds.position.y)<.001 and bounds.size.x<=6.001 and bounds.size.z<=3.001 and bounds.size.y<9)
		assert(absf(bounds.get_center().x)<.18 and absf(bounds.get_center().z)<.025)
		# This section checks a free-standing module, independently of the mouse
		# position left by previous graphical captures near existing sockets.
		placement.connection.clear()
		placement.orbit_locked=false
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
		for mesh in placement.MODEL.meshes(site.model_anchor): assert(mesh.material_override == null)
		# An adjacent same-width section shares the exact footprint boundary.
		placement.begin(card.entry.id)
		placement.origin_cell=origin
		placement.refresh_preview()
		assert(not placement.last_error.is_empty())
		assert(placement.projection_material.get_shader_parameter("tint") == Color("#ee7971"))
		if card.entry.id == &"fortress_wall":
			var joint: Dictionary = placement.JOINTS.candidate(site,0,Vector2.RIGHT,&"fortress_wall")
			placement.set_pointer_ground(Vector3(joint.center.x,0,joint.center.y))
			assert(placement.connection.site == site)
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
	# Actual placement transaction at an arbitrary tower angle, including Q/E input.
	var tower: Node3D
	placement.begin(&"fortress_wall")
	var chosen := Vector2.INF
	for item in placement.sites:
		if not placement.JOINTS.is_round(item.building_id): continue
		tower=item
		for degrees in range(0,360,15):
			var dir := Vector2.from_angle(deg_to_rad(degrees))
			var link: Dictionary = placement.JOINTS.candidate(tower,-1,dir,&"fortress_wall")
			placement.set_pointer_ground(Vector3(link.center.x,0,link.center.y))
			if placement.connection.is_empty() or placement.connection.site != tower: continue
			if not placement.validate(placement.origin_cell).is_empty(): continue
			placement.rotate_step(1)
			if placement.validate(placement.origin_cell).is_empty(): chosen=link.center; break
		if chosen.is_finite(): break
	assert(chosen.is_finite(),"Test tower must have one clear wall direction")
	placement.orbit_locked=false
	placement.set_pointer_ground(Vector3(chosen.x,0,chosen.y))
	var start_orbit: Dictionary = placement.connection.duplicate()
	for step in 24:
		placement.rotate_step(1)
		assert(is_equal_approx(placement.connection.yaw,start_orbit.yaw+(step+1)*PI/12.0))
		assert(placement.connection.target_port==start_orbit.target_port)
	assert(placement.connection.center.is_equal_approx(start_orbit.center))
	placement.connection=start_orbit
	placement.orbit_locked=false
	world.game_camera.focus_on(Vector3(chosen.x,0,chosen.y))
	world.game_camera.position+=Vector3(chosen.x,0,chosen.y)-world.game_camera.screen_to_ground(Vector2(640,320))
	root.warp_mouse(Vector2(640,320))
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(640,320)
	root.push_input(motion,true)
	var before_yaw: float = placement.connection.yaw
	var key := InputEventKey.new()
	key.physical_keycode=KEY_E
	key.pressed=true
	root.push_input(key,true)
	assert(placement.orbit_locked)
	assert(absf(angle_difference(before_yaw,placement.connection.yaw)-PI/12.0)<.001)
	var expected_pose: Dictionary = placement.pose_at(placement.origin_cell).duplicate()
	var expected_shape: PackedVector2Array = placement.shape_at(placement.origin_cell)
	var before_resources: Array = world.map_renderer.resources.duplicate(true)
	var expected_removed := 0
	for resource in before_resources:
		var p: Vector3 = world.map_renderer.cell_to_world(resource.x,resource.y)+Vector3(resource.get("offset_x",0),0,resource.get("offset_y",0))
		if resource.kind == "tree" and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),expected_shape): expected_removed+=1
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=down
		click.position=Vector2(640,320)
		root.push_input(click,true)
		await process_frame
	assert(placement.sites.size()==7 and not placement.active)
	var angled: Node3D = placement.sites.back()
	assert(is_equal_approx(angled.yaw,expected_pose.yaw),"Click must preserve the keyboard-selected angle")
	assert(Vector2(angled.position.x,angled.position.z).is_equal_approx(expected_pose.center))
	assert(angled.connections[0].site == tower)
	assert(before_resources.size()-world.map_renderer.resources.size()==expected_removed)
	for cell in placement.GEO.cells(angled.shape,world.map_renderer):
		assert(world.pathfinder.astar_grid.is_point_solid(cell))
		assert(angled in placement.occupied[cell])
	var incremental: PackedByteArray = world.hud.minimap.terrain.get_image().get_data()
	assert(incremental==preload("res://scripts/ui/minimap_terrain.gd").build(world.map_renderer,world.world_seed).get_data())
	placement.reset_world()
	assert(placement.occupied.is_empty() and placement.sites.is_empty())
	print("FORTRESS_MODULES_PASS five_independent_models no_assembly mesh_bounds rotated footprint_adjacent placement")
	quit()
