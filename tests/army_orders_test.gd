extends SceneTree
var world: Node3D
var battle: Node3D
func _initialize() -> void: call_deferred("run")
func advance(seconds: float) -> void:
	for tick in ceili(seconds * 10.0):
		world.rts.orders._process(0.1)
		battle._process(0.1)
		for unit in world.player_units: unit._process(0.1)
		if tick % 20 == 0: await process_frame
func remaining() -> int:
	var count := 0
	for unit in world.player_units:
		if not unit.target_positions.is_empty(): count += 1
	return count
func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("ARMY_ORDERS_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.rts.set_process_unhandled_input(false)
	battle = world.training
	battle.set_process(false)
	world.rts.orders.set_process(false)
	# Flat, unobstructed test terrain isolates crowd deadlocks from coast/path errors.
	world.current_cells.fill(0)
	world.map_renderer.cells.fill(0)
	world.pathfinder.setup(world.current_cells, 104)
	battle.combat_pathfinder.setup(world.current_cells, 104)
	for index in world.player_units.size():
		var unit: TestUnit3D = world.player_units[index]
		unit.set_process(false)
		var cell := Vector2i(20 + (index % 10) * 2, 30 + (index / 10) * 2)
		unit.place_on_cell(cell, world.map_renderer.cell_to_world(cell.x, cell.y))
	world.rts.set_selection(world.player_units)
	battle.manual_override(world.rts.selected)
	world.rts.orders.move(world.rts.selected, Vector2i(70, 40), false)
	await advance(120)
	print("ARMY_ORDERS remaining=", remaining())
	if remaining() > 0:
		for unit in world.player_units:
			if not unit.target_positions.is_empty(): print("BLOCKED pos=", unit.position, " next=", unit.target_positions.front(), " goal=", unit.target_positions.back())
	if "--repro" in OS.get_cmdline_user_args(): quit(); return
	assert(remaining() == 0, "All 100 must arrive, not stall behind completed units")
	world.rts.orders.move(world.rts.selected, Vector2i(30, 40), false)
	await advance(120)
	assert(remaining() == 0, "The same 100 must accept another command")
	for unit in world.player_units: assert(not unit.movement_locked and not unit.battle_dead)
	world.rts.orders.move(world.rts.selected, Vector2i(70, 40), false)
	world.rts.orders.move(world.rts.selected, Vector2i(35, 70), true)
	await advance(200)
	assert(remaining() == 0, "Shift queue must survive local replanning")
	world.rts.orders.move(world.rts.selected, Vector2i(70, 40), false)
	await advance(2)
	world.rts.stop_selected()
	var stopped: Array[Vector3] = []
	for unit in world.player_units: stopped.append(unit.position)
	await advance(5)
	for index in world.player_units.size(): assert(world.player_units[index].position == stopped[index])
	var blue: TestUnit3D = battle.living(0)[0]
	var red: TestUnit3D = battle.living(1)[0]
	battle.set_autobattle(true)
	battle._start_attack(blue, red)
	assert(blue.movement_locked)
	world.rts.orders.move([blue], Vector2i(50, 50), false)
	assert(not blue.movement_locked and not battle.jobs.has(blue) and battle.states[blue].manual)
	battle.set_autobattle(false)
	print("ARMY_ORDERS_PASS")
	quit()
