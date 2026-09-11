extends SceneTree
const MATCH := preload("res://scripts/units/formation_assignment.gd")
const LIB := preload("res://scripts/units/formation_library.gd")
func _initialize() -> void: call_deferred("run")

func score(sources: Array[Vector3], slots: Array[Vector3], assignment: Array[int]) -> float:
	var value := 0.0
	var unique := {}
	for i in slots.size():
		assert(not unique.has(assignment[i]))
		unique[assignment[i]] = true
		value += sources[assignment[i]].distance_squared_to(slots[i])
	return value

func exact_cost(sources: Array[Vector3], slots: Array[Vector3]) -> float:
	# Independent exhaustive subset DP oracle for small randomized cases.
	var costs := PackedFloat64Array()
	costs.resize(1 << sources.size())
	costs.fill(INF)
	costs[0] = 0
	for mask in costs.size()-1:
		var occupied := 0
		for i in sources.size():
			if mask & (1 << i): occupied += 1
		for i in sources.size():
			if mask & (1 << i): continue
			var next := mask | (1 << i)
			costs[next] = minf(costs[next],costs[mask]+sources[i].distance_squared_to(slots[occupied]))
	return costs[-1]

func run() -> void:
	var sources: Array[Vector3] = [Vector3.ZERO,Vector3(3,0,0)]
	var slots: Array[Vector3] = [Vector3(2,0,0),Vector3(4,0,0)]
	assert(score(sources,slots,MATCH.match_positions(sources,slots)) == 5,"Greedy cost 17 must become 5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 84017
	for trial in 40:
		sources.clear()
		slots.clear()
		for i in 7:
			sources.append(Vector3(rng.randi_range(-10,10),0,rng.randi_range(-10,10)))
			slots.append(Vector3(rng.randi_range(-10,10),0,rng.randi_range(-10,10)))
		assert(absf(score(sources,slots,MATCH.match_positions(sources,slots))-exact_cost(sources,slots))<0.00001)
	sources.clear()
	for point in LIB.offsets(LIB.default_template()): sources.append(Vector3(point.x,0,point.y))
	slots = sources.duplicate()
	slots.reverse()
	var assignment := MATCH.match_positions(sources,slots)
	assert(score(sources,slots,assignment) == 0,"Reversing 1..15 must not move anyone")
	for i in slots.size(): slots[i] += Vector3(20,0,-13)
	assignment = MATCH.match_positions(sources,slots)
	for i in slots.size(): assert(sources[assignment[i]]+Vector3(20,0,-13) == slots[i],"Translation must preserve front/back and left/right")
	# Geometric mapping stays the same under permutation of both input arrays.
	var mapping := {}
	for i in slots.size(): mapping[slots[i]] = sources[assignment[i]]
	sources.reverse()
	slots.reverse()
	assignment = MATCH.match_positions(sources,slots)
	for i in slots.size(): assert(mapping[slots[i]] == sources[assignment[i]])
	print("FORMATION_ASSIGNMENT_SOLVER_PASS optimal unique order_independent translated_5x3")
	await integration()
	quit()

func integration() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	world.rts.orders.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var renderer = world.map_renderer
	var cells := PackedByteArray()
	cells.resize(world.current_cells.size())
	cells.fill(0)
	renderer.cells = cells
	world.pathfinder.setup(cells,renderer.map_size)
	var forms = world.rts.orders.formations
	var group: Array = world.player_units
	var template := LIB.default_template()
	var anchor := Vector2i(50,50)
	var origin: Vector3 = renderer.cell_to_world(anchor.x,anchor.y)
	var offsets := LIB.offsets(template)
	for i in group.size():
		var position: Vector3 = origin+Vector3(offsets[i].x,0,offsets[i].y)
		group[i].place_on_cell(renderer.world_to_cell(position),position)
	template.slots.reverse()
	var plan: Dictionary = forms.build_plan(group,template,[anchor],Vector2(0,-1),false)
	assert(not plan.is_empty())
	for job in plan.stages[0].jobs: assert(job.unit.position.distance_to(job.point)<0.001)
	# Already queued endpoints are deliberately reversed relative to live bodies.
	for i in group.size():
		var unit: Unit3D = group[i]
		var point: Vector3 = origin+Vector3(offsets[14-i].x,0,offsets[14-i].y)
		unit.target_positions = [point]
		unit.target_cells = [renderer.world_to_cell(point)]
	var destination := anchor+Vector2i(0,-20)
	plan = forms.build_plan(group,template,[destination],Vector2(0,-1),true)
	assert(not plan.is_empty())
	var translation: Vector3 = renderer.cell_to_world(destination.x,destination.y)-origin
	for job in plan.stages[0].jobs:
		assert(job.unit.target_positions.back().distance_to(job.point-translation)<0.001,"Shift must assign from the planned endpoint, not the current body")
	# Every following stage retains exactly the same assignment.
	plan = forms.build_plan(group,template,[anchor,destination],Vector2(0,-1),false)
	for i in 15: assert(plan.stages[0].jobs[i].unit == plan.stages[1].jobs[i].unit)
	print("FORMATION_ASSIGNMENT_INTEGRATION_PASS renumbered_stationary queued_endpoints stable_stages")
