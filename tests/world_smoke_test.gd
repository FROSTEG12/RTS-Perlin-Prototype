extends SceneTree
var world: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	assert(world.player_units.size() == 10)
	assert(world.get_node_or_null("KnightTraining") == null)
	assert(world.get_node_or_null("UI/TrainingPanel") == null)
	assert(world.get_node_or_null("TemporaryBuildings") == null)
	var occupied := {}
	for unit in world.player_units:
		assert(world.map_renderer.is_land(unit.grid_cell) and not occupied.has(unit.grid_cell))
		occupied[unit.grid_cell] = true
		assert(unit.visual.get_node("Model").scene_file_path.ends_with("/blue.scn"))
		unit.set_process(false)
	world.rts.set_selection(world.player_units)
	assert(world.rts.selected.size() == 10)
	world.rts.orders.move(world.player_units, world.lead_unit.grid_cell, false)
	for tick in 400:
		world.rts.orders._process(0.1)
		for unit in world.player_units: unit._process(0.1)
	for unit in world.player_units: assert(unit.target_positions.is_empty())
	world.rts.stop_selected()
	# No test flags can inflate the squad; regeneration still creates only ten.
	world.generate_world()
	assert(world.player_units.size() == 10 and world.rts.units().size() == 10)
	print("WORLD_SMOKE_PASS ten_blue_units movement selection reset no_combat")
	quit()
