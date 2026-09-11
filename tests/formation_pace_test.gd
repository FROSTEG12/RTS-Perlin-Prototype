extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	world.rts.orders.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var forms = world.rts.orders.formations
	var pace = forms.pace
	var id: String = forms.key(world.lead_unit)
	# Different distances to regroup slots, followed by equal-length forward routes.
	var lengths := {}
	var onward := {}
	for i in world.player_units.size():
		var unit: Unit3D = world.player_units[i]
		unit.stop_orders(world.map_renderer)
		var approach := 1.0+float(i)*0.55
		unit.target_positions = [unit.position+Vector3(approach,0,0),unit.position+Vector3(approach+35,0,0)]
		unit.target_cells = [unit.grid_cell,unit.grid_cell]
		lengths[unit] = approach
		onward[unit] = 35.0
	pace.begin(id,world.player_units,false,true)
	pace.add_stage(id,lengths)
	pace.add_stage(id,onward)
	var saw_mixed_gaits := false
	var resumed_frames := 0
	var max_split := 0.0
	var transitions := {}
	var previous_modes := {}
	var last_switch := {}
	for unit in world.player_units:
		transitions[unit] = 0
		previous_modes[unit] = false
		last_switch[unit] = -1000
	for frame in 1500:
		pace.update(1.0/30.0)
		var walking := false
		var running := false
		var moving := 0
		for unit in world.player_units:
			var before: float = unit.formation_speed_scale
			unit._process(1.0/30.0)
			if unit.target_positions.is_empty(): continue
			assert(unit.move_speed*unit.formation_speed_scale >= 1.499,"Walking cannot degrade into crawling")
			assert(absf(unit.formation_speed_scale-before) <= Unit3D.FORMATION_ACCELERATION/30.0+0.00001,"Speed must blend, not jump")
			var mode: bool = unit.formation_speed_target < 1.0
			if mode != previous_modes[unit]:
				assert(frame-last_switch[unit] >= 29,"No frame-to-frame walk/run flipping")
				last_switch[unit] = frame
				transitions[unit] += 1
				previous_modes[unit] = mode
			moving += 1
			if unit.formation_speed_scale < 0.7:
				walking = walking or unit.visual.player.current_animation == "walk"
			else: running = running or unit.visual.player.current_animation == "jog"
		if walking and running: saw_mixed_gaits = true
		if saw_mixed_gaits and moving == 15 and not walking: resumed_frames += 1
		if pace.tracks.has(id):
			var min_progress := INF
			var max_progress := 0.0
			for unit in world.player_units:
				var value: Vector2 = pace.progress(unit,pace.tracks[id].members[unit],pace.tracks[id].stages)
				min_progress = minf(min_progress,value.x)
				max_progress = maxf(max_progress,value.x)
			max_split = maxf(max_split,max_progress-min_progress)
	assert(saw_mixed_gaits,"Leaders must use walk animation while laggards jog")
	assert(resumed_frames > 90,"All 15 must resume the same running pace while still moving")
	for unit in transitions: assert(transitions[unit] <= 6,"Regrouping must settle without perpetual gait oscillation")
	for unit in world.player_units:
		assert(unit.target_positions.is_empty() and unit.formation_speed_scale == 1.0)
	assert(pace.tracks.is_empty())
	# Stop/replacement/reset cannot leave walking speed on unrelated commands.
	pace.begin(id,world.player_units,false)
	world.lead_unit.formation_speed_scale = 0.5
	pace.begin(id,world.player_units,false)
	assert(world.lead_unit.formation_speed_scale == 0.5 and world.lead_unit.formation_speed_target == 1.0,"New order blends back to running instead of snapping")
	world.rts.orders.stop(world.player_units)
	assert(pace.tracks.is_empty() and world.lead_unit.formation_speed_scale == 1.0)
	pace.begin(id,world.player_units,false)
	world.lead_unit.formation_speed_scale = 0.5
	world.rts.orders.reset()
	assert(pace.tracks.is_empty() and world.lead_unit.formation_speed_scale == 1.0)
	# Sub-frame corners must not change jog to walk from net-displacement loss.
	var corner_unit: Unit3D = world.lead_unit
	corner_unit.stop_orders(world.map_renderer)
	var cursor := corner_unit.position
	for i in 100:
		cursor += (Vector3.RIGHT if i%2 == 0 else Vector3.FORWARD)*0.0375
		corner_unit.target_positions.append(cursor)
		corner_unit.target_cells.append(corner_unit.grid_cell)
	for i in 30:
		corner_unit._process(1.0/30.0)
		assert(corner_unit.visual.player.current_animation == "jog","Corners must not cause one-frame walk animations")
	corner_unit.stop_orders(world.map_renderer)
	print("FORMATION_PACE_PASS walk_and_jog catch_up shared_pace speed_floor smooth_acceleration mode_hold corners stop reset max_progress_gap=",max_split," resumed_frames=",resumed_frames," mode_switches=",transitions.values())
	quit()
