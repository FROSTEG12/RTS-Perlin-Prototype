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
	for unit: Unit3D in units:
		if not is_instance_valid(unit):
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
	for radius in range(9):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := center + Vector2i(x, y)
				if not occupied.has(candidate) and world.map_renderer.is_land(candidate):
					return candidate
	return Vector2i(-1, -1)


func stop(units: Array) -> void:
	for unit: Unit3D in units:
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
		var accepted: bool = unit.accept_move(route, world.map_renderer, job.queued)
		result_received.emit(accepted, world.map_renderer.cell_to_world(job.target.x, job.target.y),
			("Приказ добавлен" if job.queued else "Движение") if accepted else "Нет пути / очередь заполнена")
