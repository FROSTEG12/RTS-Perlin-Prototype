extends Node
## Local command dispatcher. UI does not move units directly.
signal result_received(accepted: bool, point: Vector3, message: String)
const PATHS_PER_FRAME := 4
const MAX_PENDING := 1024
var pending: Array[Dictionary] = []
var world: Node3D


func move(units: Array, cell: Vector2i, queued: bool) -> void:
	var point: Vector3 = world.map_renderer.cell_to_world(cell.x, cell.y)
	if not world.map_renderer.is_land(cell):
		result_received.emit(false, point, "Здесь нельзя пройти")
		return
	var occupied := {}
	if world.training != null and world.training.has_method("manual_override"):
		world.training.manual_override(units)
		for other in world.player_units:
			if other.battle_dead or other in units: continue
			var center: Vector2i = world.map_renderer.world_to_cell(other.position)
			for y in range(-1, 2):
				for x in range(-1, 2):
					var candidate := center + Vector2i(x, y)
					var position: Vector3 = world.map_renderer.cell_to_world(candidate.x, candidate.y)
					if position.distance_squared_to(other.position) < 0.85 * 0.85: occupied[candidate] = true
			if not other.target_cells.is_empty(): occupied[other.target_cells.back()] = true
	for unit: TestUnit3D in units:
		if not is_instance_valid(unit) or unit.battle_dead:
			continue
		if not queued:
			unit.order_revision += 1
			pending = pending.filter(func(job: Dictionary): return job.unit != unit)
		if pending.size() >= MAX_PENDING:
			result_received.emit(false, point, "Очередь приказов заполнена")
			break
		var target := _free_destination(cell, occupied)
		if target == Vector2i(-1, -1):
			result_received.emit(false, point, "Не хватает свободных целей для группы")
			continue
		occupied[target] = true
		pending.append({"unit": unit, "revision": unit.order_revision,
			"target": target, "queued": queued})


func _free_destination(center: Vector2i, occupied: Dictionary) -> Vector2i:
	# Spread group endpoints over nearby land. This is not dynamic unit avoidance.
	# With physical bodies, one-cell packing seals the inner ranks behind arrivals.
	var spacing := 2 if world.training != null and world.training.has_method("find_unit_path") else 1
	for radius in range(9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := center + Vector2i(x, y) * spacing
				if not occupied.has(candidate) and world.map_renderer.is_land(candidate):
					return candidate
	return Vector2i(-1, -1)


func stop(units: Array) -> void:
	for unit: TestUnit3D in units:
		if is_instance_valid(unit):
			unit.stop_orders(world.map_renderer)
	pending = pending.filter(func(job: Dictionary): return job.unit not in units)


func reset() -> void:
	pending.clear()


func _process(_delta: float) -> void:
	for index in mini(PATHS_PER_FRAME, pending.size()):
		var job: Dictionary = pending.pop_front()
		var unit = job.unit
		if not is_instance_valid(unit) or unit.order_revision != job.revision:
			continue
		var route: Array[Vector2i] = world.pathfinder.find_path(
			unit.order_anchor(world.map_renderer, job.queued), job.target)
		if world.training != null and world.training.has_method("find_unit_path"):
			var start: Vector2i = unit.order_anchor(world.map_renderer, true) if job.queued else world.map_renderer.world_to_cell(unit.position)
			var avoidance: Array[Vector2i] = world.training.find_unit_path(unit, start, job.target)
			if not avoidance.is_empty(): route = avoidance
		var accepted: bool = unit.accept_move(route, world.map_renderer, job.queued)
		result_received.emit(accepted, world.map_renderer.cell_to_world(job.target.x, job.target.y),
			("Приказ добавлен" if job.queued else "Движение") if accepted else "Нет пути / очередь заполнена")
