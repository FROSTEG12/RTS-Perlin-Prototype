extends SceneTree
func finish_build(world, site) -> void:
	var worker = world.lead_unit
	var g = world.rts.orders.gathering
	var geo = preload("res://scripts/buildings/building_geometry.gd")
	var ring: Array = Geometry2D.offset_polygon(site.shape,1.0)
	for cell in geo.cells(ring[0],world.map_renderer):
		var p: Vector3 = world.map_renderer.cell_to_world(cell.x,cell.y)
		if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),site.shape) and not world.pathfinder.find_path(cell,cell).is_empty():
			worker.place_on_cell(cell,p); break
	g.start_build([worker],site)
	assert(g.jobs.has(worker))
	var seen := {1:true}
	for i in 100:
		worker._process(.1); g.update(.1)
		seen[site.construction_stage]=true
	var saved: float = site.construction_work
	assert(saved>0 and saved<site.CONSTRUCTION_SECONDS)
	if DisplayServer.get_name()!="headless":
		world.game_camera.focus_on(site.position)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/building-stage-progress.png")
	world.rts.orders.stop([worker])
	for i in 30: g.update(.1)
	assert(site.construction_work==saved)
	g.start_build([worker],site)
	for i in 600:
		worker._process(.1); g.update(.1)
		seen[site.construction_stage]=true
		if site.stage==&"completed": break
	assert(site.stage==&"completed" and seen.size()==5)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.rts.orders.set_process(false)
	world.placement.set_process(false)
	world.game_camera.set_process(false)
	var worker = world.lead_unit
	worker.set_process(false)
	var g = world.rts.orders.gathering
	assert(world.stockpile["Дерево"]==30 and world.stockpile["Камень"]==30)
	world.placement.begin(&"warehouse")
	assert(world.placement.validate(Vector2i(20,20)).contains("лесопилку"))
	world.placement.begin(&"sawmill")
	var origin := Vector2i(-1,-1)
	for y in range(12,85,3):
		for x in range(12,85,3):
			if world.placement.validate(Vector2i(x,y)).is_empty(): origin=Vector2i(x,y); break
		if origin.x>=0: break
	assert(origin.x>=0)
	world.placement.origin_cell=origin
	world.placement.cancel()
	assert(world.stockpile["Дерево"]==30)
	world.placement.begin(&"sawmill")
	world.placement.origin_cell=origin
	assert(world.placement.commit())
	assert(world.stockpile["Дерево"]==0 and world.stockpile["Камень"]==0)
	world.placement.begin(&"warehouse")
	assert(not world.placement.commit())
	world.placement.cancel()
	var warehouse = world.placement.sites[0]
	assert(warehouse.stage==&"construction")
	await finish_build(world,warehouse)
	var resources: Array = []
	for resource in world.map_renderer.resources:
		if resource.kind=="tree": resources.append(resource)
	resources.sort_custom(func(a,b): return g.position_of(a).distance_squared_to(warehouse.position)<g.position_of(b).distance_squared_to(warehouse.position))
	var selected: Array = []
	for r in resources:
		var cell := Vector2i(r.x,r.y)
		if world.pathfinder.find_path(cell,cell).is_empty(): continue
		selected.append(r)
		if selected.size()==2: break
	assert(selected.size()==2)
	world.game_camera.focus_on(g.position_of(selected[0]))
	var a: Vector2 = world.game_camera.unproject_position(g.position_of(selected[0]))
	var b: Vector2 = world.game_camera.unproject_position(g.position_of(selected[1]))
	g.select_area([worker],Rect2(a,b-a).abs().grow(2))
	assert(selected[0] in g.jobs[worker].queue and selected[1] in g.jobs[worker].queue)
	worker.place_on_cell(Vector2i(selected[0].x,selected[0].y),world.map_renderer.cell_to_world(selected[0].x,selected[0].y))
	g.start_area([worker],selected)
	var saw_cargo := false
	for i in 8000:
		worker._process(.1); g.update(.1)
		if g.carried(worker)>0 and not saw_cargo:
			assert(world.stockpile["Дерево"]==0,"Cargo cannot be credited before delivery")
			saw_cargo=true
		if g.jobs.is_empty(): break
	assert(saw_cargo and g.jobs.is_empty())
	assert(world.stockpile["Дерево"]==60 and g.carried(worker)==0)
	for r in selected: assert(r not in world.map_renderer.resources)
	var stones: Array = world.map_renderer.resources.filter(func(r): return r.kind=="stone")
	stones.sort_custom(func(a,b): return g.position_of(a).distance_squared_to(warehouse.position)<g.position_of(b).distance_squared_to(warehouse.position))
	var deposit: Dictionary = stones[0]
	worker.place_on_cell(Vector2i(deposit.x,deposit.y),world.map_renderer.cell_to_world(deposit.x,deposit.y))
	g.start([worker],deposit)
	for i in 8000:
		worker._process(.1); g.update(.1)
		if g.jobs.is_empty(): break
	assert(world.stockpile["Камень"]==50)
	world.placement.begin(&"warehouse")
	var store_origin := Vector2i(-1,-1)
	for y in range(12,85,3):
		for x in range(12,85,3):
			if world.placement.validate(Vector2i(x,y)).is_empty(): store_origin=Vector2i(x,y); break
		if store_origin.x>=0: break
	assert(store_origin.x>=0)
	world.placement.origin_cell=store_origin
	assert(world.placement.commit())
	assert(world.stockpile["Дерево"]==30 and world.stockpile["Камень"]==20)
	await finish_build(world,world.placement.sites.back())
	# No warehouse: work fills cargo, waits, and stopping never destroys cargo.
	world.placement.reset_world()
	var stone: Dictionary = world.map_renderer.resources.filter(func(r): return r.kind=="stone")[0]
	worker.place_on_cell(Vector2i(stone.x,stone.y),world.map_renderer.cell_to_world(stone.x,stone.y))
	g.start([worker],stone)
	for i in 500: worker._process(.1); g.update(.1)
	assert(g.carried(worker)==10 and world.stockpile["Камень"]==20)
	assert(g.jobs[worker].state=="wait")
	world.rts.orders.stop([worker])
	assert(g.jobs.is_empty() and g.carried(worker)==10)
	g.reset()
	assert(g.cargo.is_empty())
	assert(worker.get_children().filter(func(c): return c is Label3D).is_empty())
	print("HAULING_PASS sawmill_first cost five_stages pause_resume area_queue deliveries no_early_credit no_warehouse cargo_preserved")
	world.queue_free()
	await process_frame
	quit()
