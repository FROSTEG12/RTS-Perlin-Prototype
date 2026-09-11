extends Node
## Local command dispatcher. UI does not move units directly.
signal result_received(accepted: bool, point: Vector3, message: String)
const PATHS_PER_FRAME := 4
const MAX_PENDING := 1024
const FORMATION := preload("res://scripts/units/squad_formation.gd")
const CONTROL_GROUPS := preload("res://scripts/units/unit_control_groups.gd")
var pending: Array[Dictionary] = []
var world: Node3D
var formations = preload("res://scripts/input/formation_orders.gd").new()

func _ready() -> void:
	formations.dispatcher = self


func move(units: Array, cell: Vector2i, queued: bool) -> void:
	var point: Vector3 = world.map_renderer.cell_to_world(cell.x, cell.y)
	if not world.map_renderer.is_land(cell):
		result_received.emit(false, point, "Здесь нельзя пройти")
		return
	var valid_units := CONTROL_GROUPS.expand(units, world.rts.units())
	if valid_units.any(func(unit): return formations.active.has(formations.key(unit))):
		if not formations.move(valid_units,cell,queued): result_received.emit(false,point,formations.last_error)
		return
	var targets := FORMATION.find_cells(world.map_renderer, cell, valid_units.size())
	if targets.is_empty():
		result_received.emit(false, point, "Не хватает места для строя")
		return
	for index in valid_units.size():
		var unit: Unit3D = valid_units[index]
		if not queued:
			unit.order_revision += 1
			pending = pending.filter(func(job: Dictionary): return job.unit != unit)
		if pending.size() >= MAX_PENDING:
			result_received.emit(false, point, "Очередь приказов заполнена")
			break
		var target: Vector2i = targets[index]
		pending.append({"unit": unit, "revision": unit.order_revision,
			"target": target, "queued": queued})
	for group in formations.groups(valid_units):
		var ends := {}
		for unit in group: ends[unit] = targets[valid_units.find(unit)]
		formations.record(group,cell,ends,queued)


func stop(units: Array) -> void:
	formations.clear(units)
	var controlled := CONTROL_GROUPS.expand(units, world.rts.units())
	for unit: Unit3D in controlled:
		if is_instance_valid(unit):
			unit.stop_orders(world.map_renderer)
	pending = pending.filter(func(job: Dictionary): return job.unit not in controlled)


func reset() -> void:
	pending.clear()
	formations.reset()


func _process(_delta: float) -> void:
	formations.pace.update()
	formations.prune()
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
