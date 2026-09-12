extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.rts.orders.set_process(false)
	var worker = world.lead_unit
	worker.set_process(false)
	var gather = world.rts.orders.gathering
	for kind in ["tree","stone"]:
		var resource := {}
		for candidate in world.map_renderer.resources:
			if candidate.kind==kind and world.map_renderer.is_land(Vector2i(candidate.x,candidate.y)):
				resource=candidate; break
		assert(not resource.is_empty())
		var cell := Vector2i(resource.x,resource.y)
		worker.place_on_cell(cell,world.map_renderer.cell_to_world(cell.x,cell.y))
		world.game_camera.focus_on(gather.position_of(resource))
		assert(not gather.pick(world.game_camera.unproject_position(gather.position_of(resource)),gather.position_of(resource)).is_empty())
		gather.start([worker],resource)
		assert(gather.jobs.has(worker))
		for i in 900:
			worker._process(.05)
			gather.update(.05)
		assert(not gather.jobs.has(worker))
		assert(resource not in world.map_renderer.resources)
		var incremental: PackedByteArray = world.hud.minimap.terrain.get_image().get_data()
		assert(incremental==preload("res://scripts/ui/minimap_terrain.gd").build(world.map_renderer,world.world_seed).get_data())
		assert(world.stockpile["Дерево" if kind=="tree" else "Камень"]==(30 if kind=="tree" else 50))
	# A newly issued movement/stop cancels the gathering job.
	var another: Dictionary = world.map_renderer.resources.filter(func(r): return r.kind=="tree")[0]
	worker.place_on_cell(Vector2i(another.x,another.y),world.map_renderer.cell_to_world(another.x,another.y))
	gather.start([worker],another)
	world.rts.orders.stop([worker])
	assert(gather.jobs.is_empty())
	world.placement.begin(&"warehouse")
	world.placement.set_process(false)
	var origin := Vector2i(-1,-1)
	for y in range(10,85,3):
		for x in range(10,85,3):
			if world.placement.validate(Vector2i(x,y)).is_empty(): origin=Vector2i(x,y); break
		if origin.x>=0: break
	assert(origin.x>=0)
	world.placement.origin_cell=origin
	assert(world.placement.commit())
	var site = world.placement.sites.back()
	var model = preload("res://scripts/buildings/building_model.gd")
	var box: AABB = model.bounds(site.model_anchor)
	print("WAREHOUSE_BOUNDS ",box)
	assert(box.size.x<=site.footprint.x and box.size.z<=site.footprint.y)
	for step in range(1,6):
		site.set_construction_stage(step)
		var visible_meshes: Array = model.meshes(site.model_anchor).filter(func(m): return m.is_visible_in_tree())
		assert(visible_meshes.size()==(9 if step==5 else 1))
	if DisplayServer.get_name()!="headless":
		world.game_camera.focus_on(site.position)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/new-warehouse.png")
	print("GATHERING_PASS wood stone depletion stop warehouse_placement five_stages props")
	world.queue_free()
	await process_frame
	quit()
