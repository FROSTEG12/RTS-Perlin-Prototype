extends RefCounted
## First gathering loop: no hauling, production or building costs yet.
const INTERVAL := 2.0
const YIELD := 5
var dispatcher: Node
var jobs := {}

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
	if not jobs.has(unit): return
	if is_instance_valid(jobs[unit].label): jobs[unit].label.queue_free()
	jobs.erase(unit)

func reset() -> void:
	for unit in jobs.keys(): cancel(unit)

func start(units: Array, resource: Dictionary) -> void:
	var world = dispatcher.world
	var target := position_of(resource)
	for unit in units:
		if not unit.individual_control: continue
		var candidates: Array[Vector2i] = []
		var cell: Vector2i = world.map_renderer.world_to_cell(target)
		for y in range(-2,3):
			for x in range(-2,3):
				var c := cell+Vector2i(x,y)
				if world.map_renderer.cell_to_world(c.x,c.y).distance_to(target)<=1.65: candidates.append(c)
		candidates.sort_custom(func(a,b): return Vector2(a).distance_squared_to(Vector2(unit.grid_cell))<Vector2(b).distance_squared_to(Vector2(unit.grid_cell)))
		var route: Array[Vector2i] = []
		for c in candidates:
			route=world.pathfinder.find_path(unit.order_anchor(world.map_renderer,false),c)
			if not route.is_empty(): break
		if route.is_empty():
			dispatcher.result_received.emit(false,target,"Нет пути к ресурсу")
			continue
		dispatcher.stop([unit])
		unit.accept_move(route,world.map_renderer,false)
		var label := Label3D.new()
		label.position.y=2.2
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=28
		label.pixel_size=.008
		unit.add_child(label)
		if not resource.has("remaining"): resource.remaining=30 if resource.kind=="tree" else 50
		jobs[unit]={"resource":resource,"elapsed":0.0,"revision":unit.order_revision,"label":label}
		dispatcher.result_received.emit(true,target,"Рубка дерева" if resource.kind=="tree" else "Добыча камня")

func update(delta: float) -> void:
	var world = dispatcher.world
	for unit in jobs.keys():
		var job: Dictionary = jobs[unit]
		var resource: Dictionary = job.resource
		if not is_instance_valid(unit) or unit.order_revision!=job.revision or resource not in world.map_renderer.resources:
			cancel(unit); continue
		if not unit.target_cells.is_empty(): job.label.text="К ресурсу"; continue
		if unit.global_position.distance_to(position_of(resource))>1.8: cancel(unit); continue
		job.elapsed+=delta
		job.label.text=("Дерево" if resource.kind=="tree" else "Камень")+" · %d%%"%mini(100,int(job.elapsed/INTERVAL*100))
		if job.elapsed<INTERVAL: continue
		job.elapsed-=INTERVAL
		var amount := mini(YIELD,int(resource.remaining))
		resource.remaining-=amount
		var key := "Дерево" if resource.kind=="tree" else "Камень"
		world.stockpile[key]+=amount
		if resource.remaining<=0:
			var p := position_of(resource)
			world.map_renderer.TREE_RESOURCES.remove_resource(world.map_renderer,resource)
			world.hud.minimap.refresh_forest(Rect2(Vector2(p.x,p.z)-Vector2.ONE,Vector2.ONE*2))
			cancel(unit)
