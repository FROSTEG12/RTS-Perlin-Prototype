extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)

func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	root.warp_mouse(point)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+filename)

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var placement = world.placement
	placement.set_process(false)
	world.vision.set_enabled(false)
	world.hud._set_section(0)
	world.hud.buildings.select_category(2)
	for i in 4: await process_frame
	world.hud.buildings.building_buttons[1].pressed.emit()
	assert(placement.active and placement.building_id == &"sawmill")
	assert(placement.dimensions() == Vector2i(8,6))
	var model_bounds: AABB = placement.MODEL.bounds(placement.preview_model)
	assert(model_bounds.size.x > 7.6 and model_bounds.size.x < 7.7)
	assert(model_bounds.size.z < 5.3 and absf(model_bounds.position.y)<.001)
	for mesh in placement.MODEL.meshes(placement.preview_model):
		assert(mesh.material_override == placement.projection_material)
		assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var location := Vector2i(-1,-1)
	for resource in world.map_renderer.resources:
		if resource.kind != "tree": continue
		var cell := Vector2i(resource.x-1,resource.y-2)
		if placement.validate(cell).is_empty(): location = cell; break
	assert(location.x >= 0,"Generated world must contain a forest site")
	placement.origin_cell = location
	var area: Rect2 = placement.bounds_at(location)
	var center: Vector2 = area.get_center()
	world.game_camera.focus_on(Vector3(center.x,0,center.y))
	world.game_camera.position+=Vector3(center.x,0,center.y)-world.game_camera.screen_to_ground(Vector2(640,250))
	var pointer: Vector2 = world.game_camera.unproject_position(Vector3(center.x,0,center.y))
	root.warp_mouse(pointer)
	placement.update_pointer(pointer)
	assert(placement.origin_cell == location and placement.last_error.is_empty())
	assert(placement.arrow.position.z>0,"Front arrow must mark the sawmill door on +Z")
	var old_requested: int = world.hud.skill_slots.last_requested
	key(KEY_E)
	assert(placement.quarter_turn == 1 and placement.dimensions() == Vector2i(6,8))
	assert(placement.arrow.position.x>0 and absf(placement.arrow.position.z)<.001)
	assert(placement.arrow.basis.y.dot(Vector3.RIGHT)>.999,"Arrow must point toward the rotated entrance, not away from it")
	assert(world.hud.skill_slots.last_requested == old_requested)
	key(KEY_Q)
	assert(placement.quarter_turn == 0 and placement.origin_cell == location)
	var before: Array = world.map_renderer.resources.duplicate(true)
	await capture("sawmill-placement.png")
	key(KEY_ESCAPE)
	assert(not placement.active and not world.pause_menu.visible)
	assert(world.map_renderer.resources == before)
	placement.begin(&"sawmill")
	placement.origin_cell = Vector2i(-1,-1)
	assert(not placement.commit() and placement.sites.is_empty())
	assert(world.map_renderer.resources == before)
	placement.origin_cell = location
	world.vision.set_enabled(true)
	assert(not placement.validate(location).is_empty(),"Cannot build in unseen land")
	world.vision.set_enabled(false)
	# Mouse over inventory/editor must never place on the map behind it.
	world.hud.open_inventory()
	for i in 4: await process_frame
	var blocked_point: Vector2 = world.hud.formation_inventory.global_position+Vector2(4,80)
	await click(blocked_point)
	assert(placement.sites.is_empty())
	world.hud.formation_inventory.hide()
	placement.update_pointer(pointer)
	assert(placement.origin_cell == location)
	var expected := 0
	for resource in before:
		var p: Vector3 = world.map_renderer.cell_to_world(resource.x,resource.y)+Vector3(resource.get("offset_x",0),0,resource.get("offset_y",0))
		if resource.kind == "tree" and area.has_point(Vector2(p.x,p.z)): expected += 1
	assert(expected > 0)
	await click(pointer)
	assert(placement.sites.size() == 1 and not placement.active)
	assert(before.size()-world.map_renderer.resources.size() == expected)
	assert(placement.occupied.size() == 48)
	for cell in placement.occupied: assert(world.pathfinder.astar_grid.is_point_solid(cell))
	var visible_removed := 0
	var shadow_removed := 0
	for batch in world.map_renderer.resource_root.get_children():
		if not batch is MultiMeshInstance3D: continue
		for i in batch.multimesh.instance_count:
			var transform: Transform3D = batch.multimesh.get_instance_transform(i)
			if transform.basis.x.length() > .0001: continue
			assert(area.has_point(Vector2(transform.origin.x,transform.origin.z)))
			if str(batch.name).begins_with("Trees_"): visible_removed += 1
			if str(batch.name).begins_with("TreeShadows_"): shadow_removed += 1
	if DisplayServer.get_name() != "headless": assert(visible_removed == expected and shadow_removed == expected)
	# Incremental forest refresh must match a fresh minimap, without losing contacts.
	var incremental: PackedByteArray = world.hud.minimap.terrain.get_image().get_data()
	var rebuilt := preload("res://scripts/ui/minimap_terrain.gd").build(world.map_renderer,world.world_seed).get_data()
	assert(incremental==rebuilt,"Local forest update must exactly match full redraw")
	var site = placement.sites[0]
	assert(site.stage == &"completed" and site.model_anchor.name == "ModelAnchor")
	assert(placement.MODEL.bounds(site.model_anchor.get_child(0)).is_equal_approx(model_bounds))
	for mesh in placement.MODEL.meshes(site.model_anchor): assert(mesh.material_override == null)
	assert(world.hud.minimap.landmarks.has(site.get_instance_id()))
	await capture("sawmill-site.png")
	placement.begin(&"sawmill")
	placement.origin_cell = location
	assert(not placement.commit() and placement.sites.size() == 1)
	var after_count: int = world.map_renderer.resources.size()
	await click(pointer,MOUSE_BUTTON_RIGHT)
	assert(not placement.active and world.map_renderer.resources.size() == after_count)
	placement.begin(&"sawmill")
	world.hud.buildings.select_category(1)
	assert(not placement.active)
	placement.reset_world()
	assert(placement.sites.is_empty() and placement.occupied.is_empty())
	assert(not world.pathfinder.astar_grid.is_point_solid(location))
	print("BUILDING_PLACEMENT_PASS snap rotate hotkey_priority cancel invalid fog ui forest shadows reservation reset")
	quit()
