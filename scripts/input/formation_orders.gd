extends RefCounted
## Formation templates and command intent belong to squads, never soldier numbers.
const LIBRARY := preload("res://scripts/units/formation_library.gd")
const GROUPS := preload("res://scripts/units/unit_control_groups.gd")
var dispatcher: Node
var active := {}
var intentions := {}
var facing := {}
var last_error := ""
var pace = preload("res://scripts/input/formation_pace.gd").new()

func key(unit: Unit3D) -> String:
	return "unit:%d" % unit.get_instance_id() if unit.individual_control else "squad:%d" % unit.squad_id

func groups(units: Array) -> Array:
	var result: Array = []
	var seen := {}
	for unit in GROUPS.expand(units,dispatcher.world.rts.units()):
		var id := key(unit)
		if seen.has(id): continue
		seen[id] = true
		result.append(GROUPS.members(unit,dispatcher.world.rts.units()))
	return result

func center(group: Array) -> Vector3:
	var point := Vector3.ZERO
	for unit in group: point += unit.global_position
	return point/group.size()

func record(group: Array, goal: Vector2i, ends: Dictionary, queued: bool, transient: bool = false) -> void:
	var id := key(group[0])
	if not queued or not intentions.has(id): intentions[id] = []
	intentions[id].append({"goal":goal,"ends":ends,"transient":transient})

func prune() -> void:
	for id in intentions:
		while not intentions[id].is_empty():
			var waiting := false
			for unit in intentions[id][0].ends:
				if not is_instance_valid(unit): continue
				var cell: Vector2i = intentions[id][0].ends[unit]
				if cell in unit.move_orders: waiting = true
				for job in dispatcher.pending:
					if job.unit == unit and job.target == cell: waiting = true
			if waiting: break
			intentions[id].pop_front()

func clear(units: Array) -> void:
	for group in groups(units):
		intentions.erase(key(group[0]))
		pace.clear(key(group[0]))

func reset() -> void:
	pace.reset()
	active.clear()
	intentions.clear()
	facing.clear()

func apply(units: Array, template: Dictionary) -> bool:
	last_error = LIBRARY.validate(template)
	if not last_error.is_empty(): return false
	var selected_groups := groups(units)
	if selected_groups.is_empty():
		last_error = "Сначала выбери отряд"
		return false
	prune()
	var plans: Array = []
	for group in selected_groups:
		if group.size() != 15 or group[0].individual_control:
			last_error = "Построение рассчитано на отряд из 15 бойцов"
			return false
		for unit in group:
			if unit.troop_type not in template.types:
				last_error = "Построение не разрешено для этого типа войск"
				return false
		var id := key(group[0])
		var goals: Array = []
		for intent in intentions.get(id,[]):
			if not intent.get("transient",false): goals.append(intent.goal)
		var anchor := center(group)
		var direction: Vector2 = facing.get(id,Vector2(0,-1))
		if not goals.is_empty():
			var destination: Vector3 = dispatcher.world.map_renderer.cell_to_world(goals[0].x,goals[0].y)
			var delta := Vector2(destination.x-anchor.x,destination.z-anchor.z)
			if delta.length() > 0.5: direction = delta.normalized()
		# First take new slots close to the moving squad, then resume every queued goal.
		var stages: Array = [dispatcher.world.map_renderer.world_to_cell(anchor)]
		stages.append_array(goals)
		var plan := build_plan(group,template,stages,direction,false)
		if plan.is_empty(): return false
		plan.stages[0].transient = true
		plans.append(plan)
	for plan in plans:
		install(plan,false)
		active[key(plan.group[0])] = template.duplicate(true)
		facing[key(plan.group[0])] = plan.direction
	return true

func move(units: Array, cell: Vector2i, queued: bool) -> bool:
	var plans: Array = []
	var selected_groups := groups(units)
	var separation := 0.0
	for group in selected_groups:
		var shape: Dictionary = active.get(key(group[0]),LIBRARY.default_template())
		for offset in LIBRARY.offsets(shape): separation = maxf(separation,offset.length()*2.0+3.0)
	for group_index in selected_groups.size():
		var group: Array = selected_groups[group_index]
		var id := key(group[0])
		var template: Dictionary = active.get(id,{})
		if template.is_empty():
			template = LIBRARY.default_template()
		if group.size() != 15:
			last_error = "Для этого построения нужен полный отряд"
			return false
		var anchor := center(group)
		if queued and not intentions.get(id,[]).is_empty():
			var previous: Vector2i = intentions[id][-1].goal
			anchor = dispatcher.world.map_renderer.cell_to_world(previous.x,previous.y)
		var point: Vector3 = dispatcher.world.map_renderer.cell_to_world(cell.x,cell.y)
		var direction := Vector2(point.x-anchor.x,point.z-anchor.z).normalized()
		if direction.length_squared() < 0.5: direction = facing.get(id,Vector2(0,-1))
		var lateral := Vector2(-direction.y,direction.x)*separation*(group_index-(selected_groups.size()-1)*0.5)
		var group_goal := cell+Vector2i(lateral.round())
		var plan := build_plan(group,template,[group_goal],direction,queued)
		if plan.is_empty(): return false
		plans.append(plan)
	for plan in plans:
		install(plan,queued)
		facing[key(plan.group[0])] = plan.direction
	return true

func build_plan(group: Array, template: Dictionary, goals: Array, direction: Vector2, queued: bool) -> Dictionary:
	var renderer = dispatcher.world.map_renderer
	var paths = dispatcher.world.pathfinder
	var origins := {}
	for unit in group:
		if goals.size()+(unit.move_orders.size() if queued else 0) > 30:
			last_error = "Слишком длинная очередь приказов"
			return {}
		origins[unit] = unit.order_anchor(renderer,queued)
	var stages: Array = []
	var assignment: Array = []
	var offsets := LIBRARY.offsets(template)
	var right := Vector2(-direction.y,direction.x)
	for goal in goals:
		var points: Array[Vector3] = []
		for radius in range(9):
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					if maxi(absi(x),absi(y)) != radius: continue
					var origin: Vector3 = renderer.cell_to_world(goal.x+x,goal.y+y)
					var candidate: Array[Vector3] = []
					for offset in offsets:
						var rotated: Vector2 = right*offset.x-direction*offset.y
						var point := origin+Vector3(rotated.x,0,rotated.y)
						if not renderer.is_land(renderer.world_to_cell(point)): break
						candidate.append(point)
					if candidate.size() == group.size():
						points = candidate
						break
				if not points.is_empty(): break
			if not points.is_empty(): break
		if points.is_empty():
			last_error = "Не хватает суши для этого построения"
			return {}
		var jobs: Array = []
		# Assign each free slot to the nearest remaining soldier; slot numbers are not IDs.
		var available := group.duplicate()
		for index in points.size():
			var point := points[index]
			if stages.is_empty():
				available.sort_custom(func(a,b): return a.global_position.distance_squared_to(point) < b.global_position.distance_squared_to(point))
				assignment.append(available.pop_front())
			var unit = assignment[index]
			var cell: Vector2i = renderer.world_to_cell(point)
			var path: Array[Vector2i] = paths.find_path(origins[unit],cell)
			if path.is_empty():
				last_error = "Нет пути для всего отряда — приказ сохранён"
				return {}
			jobs.append({"unit":unit,"path":path,"point":point,"target":cell})
			origins[unit] = cell
		stages.append({"goal":goal,"jobs":jobs})
	if goals.size() > 30:
		last_error = "Слишком длинная очередь приказов"
		return {}
	return {"group":group,"stages":stages,"direction":direction}

func install(plan: Dictionary, queued: bool) -> void:
	var group: Array = plan.group
	if not queued:
		for unit in group: unit.order_revision += 1
		dispatcher.pending = dispatcher.pending.filter(func(job): return job.unit not in group)
	var append := queued
	var id := key(group[0])
	pace.begin(id,group,queued)
	for stage in plan.stages:
		var ends := {}
		var lengths := {}
		for job in stage.jobs:
			var unit: Unit3D = job.unit
			var count := unit.target_positions.size() if append else 0
			var previous: Vector3 = unit.target_positions.back() if count > 0 else unit.position
			job.unit.accept_move(job.path,dispatcher.world.map_renderer,append,job.point)
			var length := 0.0
			for index in range(count,unit.target_positions.size()):
				length += previous.distance_to(unit.target_positions[index])
				previous = unit.target_positions[index]
			lengths[unit] = length
			ends[job.unit] = job.target
		pace.add_stage(id,lengths)
		record(group,stage.goal,ends,append,stage.get("transient",false))
		append = true
	pace.update()
