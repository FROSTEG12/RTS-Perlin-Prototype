extends RefCounted
## Worker cargo is credited only on arrival at a completed warehouse.
const INTERVAL := 4.0
const YIELD := 2
const CAPACITY := 10
var dispatcher: Node
var jobs := {}
var cargo := {}

func position_of(resource: Dictionary) -> Vector3:
	var p: Vector3 = dispatcher.world.map_renderer.cell_to_world(resource.x,resource.y)
	if resource.kind=="tree": p+=Vector3(resource.get("offset_x",0),0,resource.get("offset_y",0))
	return p

func pick(screen: Vector2, _ground: Vector3) -> Dictionary:
	var world = dispatcher.world
	var best := INF
	var found := {}
	for resource in world.map_renderer.resources:
		if resource.kind not in ["tree","stone"]: continue
		var p := position_of(resource)
		if world.vision.enabled and not world.vision.state.is_visible(p): continue
		if world.game_camera.is_position_behind(p): continue
		var radius := 24.0 if resource.kind=="tree" else 14.0
		var distance := screen.distance_to(world.game_camera.unproject_position(p+Vector3.UP*(1.2 if resource.kind=="tree" else 0)))
		var base_distance := screen.distance_to(world.game_camera.unproject_position(p))
		distance=minf(distance,base_distance)
		if distance<=radius and distance<best: best=distance; found=resource
	return found

func cancel(unit: Node3D) -> void:
	if jobs.has(unit) and is_instance_valid(jobs[unit].bar): jobs[unit].bar.queue_free()
	jobs.erase(unit)

func reset() -> void:
	for unit in jobs.keys(): cancel(unit)
	cargo.clear()

func start(units: Array, resource: Dictionary) -> void:
	start_area(units,[resource])

func deposit_at(units: Array, point: Vector3) -> bool:
	for site in dispatcher.world.placement.sites:
		if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),site.shape):
			if site.stage!=&"completed": start_build(units,site); return true
			if site.building_id in [&"warehouse",&"sawmill"]: start_area(units,[]); return true
	return false

func route_to_site(unit: Node3D, site: Node3D) -> bool:
	var world = dispatcher.world
	var geo = preload("res://scripts/buildings/building_geometry.gd")
	var expanded: Array = Geometry2D.offset_polygon(site.shape,1.0)
	if expanded.is_empty(): return false
	var candidates: Array[Vector2i] = []
	for cell in geo.cells(expanded[0],world.map_renderer):
		var p: Vector3 = world.map_renderer.cell_to_world(cell.x,cell.y)
		if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),site.shape): candidates.append(cell)
	return follow_candidates(unit,candidates)

func start_build(units: Array, site: Node3D) -> void:
	if site.stage==&"completed": return
	for unit in units:
		if not unit.individual_control: continue
		dispatcher.stop([unit])
		if not route_to_site(unit,site):
			dispatcher.result_received.emit(false,site.position,"Нет пути к стройке")
			continue
		var bar := preload("res://scripts/ui/gathering_progress.gd").new()
		unit.add_child(bar)
		jobs[unit]={"state":"build","site":site,"revision":unit.order_revision,"bar":bar}
		dispatcher.result_received.emit(true,site.position,"Строительство")
		return

func select_area(units: Array, area: Rect2) -> void:
	var world = dispatcher.world
	var resources: Array = []
	for resource in world.map_renderer.resources:
		if resource.kind!="tree": continue
		var p := position_of(resource)
		if world.vision.enabled and not world.vision.state.is_visible(p): continue
		if not world.game_camera.is_position_behind(p) and area.has_point(world.game_camera.unproject_position(p)): resources.append(resource)
	if resources.is_empty():
		dispatcher.result_received.emit(false,Vector3.ZERO,"В области нет деревьев")
		return
	start_area(units,resources)

func start_area(units: Array, resources: Array) -> void:
	for unit in units:
		if not unit.individual_control: continue
		dispatcher.stop([unit])
		if not cargo.has(unit): cargo[unit]={"Дерево":0,"Камень":0}
		var bar := preload("res://scripts/ui/gathering_progress.gd").new()
		unit.add_child(bar)
		jobs[unit]={"queue":resources.duplicate(),"resource":{},"elapsed":0.0,"retry":0.0,"revision":unit.order_revision,"state":"choose","warehouse":null,"bar":bar}
		dispatcher.result_received.emit(true,unit.global_position,"Зона добычи: %d ресурсов"%resources.size())

func carried(unit: Node3D) -> int:
	if not cargo.has(unit): return 0
	return int(cargo[unit]["Дерево"])+int(cargo[unit]["Камень"])

func route_to_resource(unit: Node3D, target: Vector3) -> bool:
	var world = dispatcher.world
	var candidates: Array[Vector2i] = []
	var cell: Vector2i = world.map_renderer.world_to_cell(target)
	for y in range(-2,3):
		for x in range(-2,3):
			var c := cell+Vector2i(x,y)
			if world.map_renderer.cell_to_world(c.x,c.y).distance_to(target)<=1.65: candidates.append(c)
	return follow_candidates(unit,candidates)

func follow_candidates(unit: Node3D, candidates: Array[Vector2i]) -> bool:
	var world = dispatcher.world
	var origin: Vector2i = world.map_renderer.world_to_cell(unit.global_position)
	candidates.sort_custom(func(a,b): return Vector2(a).distance_squared_to(Vector2(origin))<Vector2(b).distance_squared_to(Vector2(origin)))
	for cell in candidates:
		var route: Array[Vector2i] = world.pathfinder.find_path(origin,cell)
		if not route.is_empty(): return unit.accept_move(route,world.map_renderer,false)
	return false

func deliver(unit: Node3D, job: Dictionary) -> bool:
	var world = dispatcher.world
	var warehouses: Array = world.placement.sites.filter(func(site): return site.building_id==&"warehouse" and site.stage==&"completed")
	# Bootstrap depot: the sawmill accepts both materials before the first store.
	if warehouses.is_empty(): warehouses=world.placement.sites.filter(func(site): return site.building_id==&"sawmill" and site.stage==&"completed")
	warehouses.sort_custom(func(a,b): return a.position.distance_squared_to(unit.position)<b.position.distance_squared_to(unit.position))
	for warehouse in warehouses:
		var candidates: Array[Vector2i] = []
		var geo = preload("res://scripts/buildings/building_geometry.gd")
		var expanded: Array = Geometry2D.offset_polygon(warehouse.shape,1.0)
		if expanded.is_empty(): continue
		for cell in geo.cells(expanded[0],world.map_renderer):
			var p: Vector3 = world.map_renderer.cell_to_world(cell.x,cell.y)
			if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),warehouse.shape): candidates.append(cell)
		if follow_candidates(unit,candidates):
			job.state="deliver"
			job.warehouse=warehouse
			return true
	var was_waiting: bool = job.state=="wait"
	job.state="wait"
	job.retry=2.0
	if not was_waiting: dispatcher.result_received.emit(false,unit.global_position,"Нет доступного места сдачи — груз сохранён")
	return false

func update(delta: float) -> void:
	var world = dispatcher.world
	for unit in jobs.keys():
		var job: Dictionary = jobs[unit]
		job.bar.hide()
		if not is_instance_valid(unit) or unit.order_revision!=job.revision:
			cancel(unit); continue
		if not unit.target_cells.is_empty(): continue
		if job.state=="build":
			if not is_instance_valid(job.site) or job.site not in world.placement.sites or job.site.stage==&"completed": cancel(unit); continue
			var close := false
			var p := Vector2(unit.global_position.x,unit.global_position.z)
			var shape: PackedVector2Array = job.site.shape
			for i in shape.size():
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,shape[i],shape[(i+1)%shape.size()]))<=1.8: close=true
			if not close: cancel(unit); continue
			job.site.construction_work=minf(job.site.CONSTRUCTION_SECONDS,job.site.construction_work+delta)
			var progress: float = job.site.construction_work/job.site.CONSTRUCTION_SECONDS
			job.site.set_construction_stage(mini(5,1+int(progress*4)))
			job.bar.show(); job.bar.set_progress(progress)
			if progress>=1:
				dispatcher.result_received.emit(true,job.site.position,"Здание готово")
				cancel(unit)
			continue
		if job.state=="wait":
			job.retry-=delta
			if job.retry<=0: deliver(unit,job)
			continue
		if job.state=="deliver":
			if not is_instance_valid(job.warehouse) or job.warehouse not in world.placement.sites or job.warehouse.stage!=&"completed": deliver(unit,job); continue
			# Verify the worker actually reached the perimeter before crediting cargo.
			var near := false
			var p := Vector2(unit.global_position.x,unit.global_position.z)
			var shape: PackedVector2Array = job.warehouse.shape
			for i in shape.size():
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,shape[i],shape[(i+1)%shape.size()]))<=1.8: near=true
			if not near: deliver(unit,job); continue
			for key in cargo[unit]: world.stockpile[key]+=cargo[unit][key]; cargo[unit][key]=0
			job.state="choose"
		if job.state=="choose":
			if carried(unit)>0: deliver(unit,job); continue
			job.queue=job.queue.filter(func(r): return r in world.map_renderer.resources)
			job.queue.sort_custom(func(a,b): return position_of(a).distance_squared_to(unit.position)<position_of(b).distance_squared_to(unit.position))
			var found := false
			for resource in job.queue:
				if route_to_resource(unit,position_of(resource)):
					job.resource=resource
					if not resource.has("remaining"): resource.remaining=30 if resource.kind=="tree" else 50
					job.state="gather"; job.elapsed=0.0; found=true; break
			if not found: cancel(unit)
			continue
		var resource: Dictionary = job.resource
		if resource not in world.map_renderer.resources: job.state="choose"; continue
		if unit.global_position.distance_to(position_of(resource))>1.8: job.state="choose"; continue
		job.elapsed+=delta
		job.bar.show()
		job.bar.set_progress(job.elapsed/INTERVAL)
		if job.elapsed<INTERVAL: continue
		job.elapsed-=INTERVAL
		var amount := mini(mini(YIELD,int(resource.remaining)),CAPACITY-carried(unit))
		resource.remaining-=amount
		var key := "Дерево" if resource.kind=="tree" else "Камень"
		cargo[unit][key]+=amount
		if resource.remaining<=0:
			var p := position_of(resource)
			world.map_renderer.TREE_RESOURCES.remove_resource(world.map_renderer,resource)
			world.hud.minimap.refresh_forest(Rect2(Vector2(p.x,p.z)-Vector2.ONE,Vector2.ONE*2))
			job.state="choose"
		if carried(unit)>=CAPACITY or resource.remaining<=0: deliver(unit,job)
