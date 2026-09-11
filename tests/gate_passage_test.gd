extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.vision.set_enabled(false)
	world.placement.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var placement = world.placement
	var renderer = world.map_renderer
	for turn in 4:
		placement.begin(&"fortress_gate")
		placement.connection.clear()
		placement.quarter_turn=turn
		var origin := Vector2i(-1,-1)
		for y in range(12,85,3):
			for x in range(12,85,3):
				if not placement.validate(Vector2i(x,y)).is_empty(): continue
				var land := true
				for dy in range(-4,10):
					for dx in range(-4,10):
						if not renderer.is_land(Vector2i(x+dx,y+dy)): land=false
				if land: origin=Vector2i(x,y); break
			if origin.x>=0: break
		assert(origin.x>=0,"Need dry test ground")
		placement.origin_cell=origin
		var footprint: Array[Vector2i] = placement.cells_at(origin)
		assert(placement.commit())
		var gate = placement.sites.back()
		var open_cells: Array[Vector2i] = []
		for cell in footprint:
			assert(placement.occupied.has(cell),"Arch remains reserved for construction")
			var solid: bool = world.pathfinder.astar_grid.is_point_solid(cell)
			assert(solid==gate.blocks_navigation(renderer.cell_to_world(cell.x,cell.y)))
			if not solid: open_cells.append(cell)
		assert(not open_cells.is_empty() and open_cells.size()<footprint.size())
		var forward := Vector3.BACK.rotated(Vector3.UP,gate.yaw)
		var start: Vector2i = renderer.world_to_cell(gate.position-forward*4)
		var finish: Vector2i = renderer.world_to_cell(gate.position+forward*4)
		for pair in [[start,finish],[finish,start]]:
			var path: Array[Vector2i] = world.pathfinder.find_path(pair[0],pair[1])
			assert(not path.is_empty())
			assert(path.any(func(cell): return cell in open_cells),"Path must go through arch, not around gate")
			for cell in path: assert(not world.pathfinder.astar_grid.is_point_solid(cell))
			var soldier = world.lead_unit
			soldier.place_on_cell(pair[0],renderer.cell_to_world(pair[0].x,pair[0].y))
			assert(soldier.accept_move(path,renderer,false))
			for frame in 900: soldier._process(1.0/60.0)
			assert(soldier.target_cells.is_empty(),"Soldier must complete passage")
			assert(soldier.global_position.distance_to(renderer.cell_to_world(pair[1].x,pair[1].y))<.1)
		placement.begin(&"fortress_gate")
		placement.connection.clear()
		placement.quarter_turn=turn
		assert(not placement.validate(origin).is_empty(),"Cannot build in existing gate")
		placement.reset_world()
		for cell in footprint: assert(not world.pathfinder.astar_grid.is_point_solid(cell))
	print("GATE_PASSAGE_PASS four_rotations both_directions solid_jambs reserved_footprint reset")
	world.queue_free()
	await process_frame
	quit()
