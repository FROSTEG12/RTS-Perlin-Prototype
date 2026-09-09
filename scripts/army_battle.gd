extends Node3D
## Disposable local battle sandbox. No networking or permanent combat rules.
const REACH := 1.7
const BODY_DISTANCE := 0.85
const DAMAGE := 20
const PATH_BUDGET := 4
var world: Node3D
var blood: Node3D
var enabled := false
var states := {}
var jobs := {}
var deaths := {}
var spawn_cells: Array[Vector2i] = []
var spawn_seed := -1
var reservations := {}
var clock := 0.0
var cursor := 0
var rng := RandomNumberGenerator.new()
var toggle: CheckButton
var counter: Label
var message: Label
var attacks := 0
var hits := 0
var death_bag: Array[int] = []
var previous_death := 0
var combat_pathfinder := GridPathfinder.new()

func _ready() -> void:
	rng.randomize()
	blood = preload("res://scripts/training_blood.gd").new()
	blood.world = world
	world.map_renderer.add_child(blood)
	for unit in world.player_units:
		unit.movement_guard = can_step
	var panel := PanelContainer.new()
	panel.name = "TrainingPanel" # Existing input guard excludes this panel.
	world.get_node("UI").add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -320
	panel.offset_right = -18
	panel.offset_top = 18
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Тест боя · 50 × 50"
	rows.add_child(title)
	counter = Label.new()
	rows.add_child(counter)
	toggle = CheckButton.new()
	toggle.text = "Автобой"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(set_autobattle)
	rows.add_child(toggle)
	var selections := HBoxContainer.new()
	rows.add_child(selections)
	for team in [0, 1, -1]:
		var button := Button.new()
		button.text = ["Синие", "Красные", "Все"][team if team >= 0 else 2]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): world.rts.set_selection(living(team)))
		selections.add_child(button)
	var reset := Button.new()
	reset.text = "Начать заново"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(reset_arena)
	rows.add_child(reset)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(280, 50)
	message.text = "Обе команды управляемые и смертные.\nПКМ / Стоп выводит выбранных из автобоя.\nВключи автобой снова, чтобы вернуть всех."
	message.add_theme_font_size_override("font_size", 12)
	rows.add_child(message)

func living(team: int = -1) -> Array[TestUnit3D]:
	var result: Array[TestUnit3D] = []
	for unit in world.player_units:
		if not unit.battle_dead and (team < 0 or unit.team_id == team): result.append(unit)
	return result

func reset_arena() -> void:
	enabled = false
	toggle.set_pressed_no_signal(false)
	world.rts.reset()
	jobs.clear()
	deaths.clear()
	states.clear()
	reservations.clear()
	blood.clear()
	combat_pathfinder.setup(world.current_cells, world.DEFAULT_MAP_SIZE)
	attacks = 0
	hits = 0
	clock = 0.0
	if spawn_seed != world.world_seed or spawn_cells.size() != world.player_units.size():
		spawn_seed = world.world_seed
		spawn_cells.clear()
		for unit in world.player_units: spawn_cells.append(unit.grid_cell)
		spawn_cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.x != b.x else a.y < b.y)
	for index in world.player_units.size():
		var unit: TestUnit3D = world.player_units[index]
		unit.battle_dead = false
		unit.movement_locked = false
		unit.add_to_group("rts_units")
		unit.set_hovered(false)
		unit.visual.player.speed_scale = 1.0
		var cell := spawn_cells[index]
		unit.place_on_cell(cell, world.map_renderer.cell_to_world(cell.x, cell.y))
		unit.visual.rotation.y = PI * 0.5 if unit.team_id == 0 else -PI * 0.5
		states[unit] = {"hp": 100, "manual": false, "next": rng.randf_range(0.0, 0.8), "cooldown": 0.0, "last": ""}
	message.text = "Обе команды управляемые и смертные.\nПКМ / Стоп выводит выбранных из автобоя.\nВключи автобой снова, чтобы вернуть всех."
	_update_counter()

func set_autobattle(value: bool) -> void:
	enabled = value and not living(0).is_empty() and not living(1).is_empty()
	toggle.set_pressed_no_signal(enabled)
	for unit in living():
		_cancel(unit)
		unit.stop_orders(world.map_renderer)
		states[unit].manual = false
		states[unit].next = clock + rng.randf_range(0.0, 0.6)
	reservations.clear()
	message.text = "Автобой: обе команды атакуют.\nРучной приказ выводит выбранных из боя." if enabled else "Автобой выключен. Можно двигать обе команды."

func manual_override(units: Array) -> void:
	for unit in units:
		if unit.battle_dead: continue
		states[unit].manual = true
		_cancel(unit)
		_release_slot(unit)

func _release_slot(unit: TestUnit3D) -> void:
	for cell in reservations.keys():
		if reservations[cell] == unit: reservations.erase(cell)

func _cancel(unit: TestUnit3D) -> void:
	jobs.erase(unit)
	if unit.battle_dead: return
	unit.movement_locked = false
	unit.visual.player.speed_scale = 1.0
	unit.visual.player.play("idle", 0.2)

func can_step(unit: TestUnit3D, next: Vector3) -> bool:
	# Test-scale body guard; no pair can move closer through an occupied body.
	# Substeps also protect callers running at low frame rates.
	var distance := unit.position.distance_to(next)
	for step in range(1, ceili(distance / 0.2) + 1):
		var point := unit.position.lerp(next, minf(step * 0.2 / maxf(distance, 0.001), 1.0))
		for other in world.player_units:
			if other == unit or other.battle_dead: continue
			var after := point.distance_squared_to(other.position)
			if after < BODY_DISTANCE * BODY_DISTANCE and after < unit.position.distance_squared_to(other.position) - 0.00001: return false
	return true

func _process(delta: float) -> void:
	if states.is_empty() or world.is_generating: return
	clock += delta
	for unit in deaths.keys():
		deaths[unit] -= delta
		if deaths[unit] <= 0.0:
			# Only corpses due for a stain need a current skeleton pose.
			unit.visual.sample_pose()
			var skeleton: Skeleton3D = unit.visual.get_node("Model").find_child("Skeleton3D", true, false)
			var bone := skeleton.find_bone("pelvis")
			var point: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin) if bone >= 0 else unit.global_position
			blood.spawn_death(point)
			deaths.erase(unit)
	if not enabled: return
	for unit in jobs.keys():
		if not jobs.has(unit): continue
		var job: Dictionary = jobs[unit]
		var target: TestUnit3D = job.target
		if unit.battle_dead or target.battle_dead:
			_cancel(unit)
			continue
		job.time += delta
		unit.visual.rotation.y = lerp_angle(unit.visual.rotation.y, job.heading, minf(1.0, delta * 12.0))
		while not job.impacts.is_empty() and job.time >= job.impacts[0]:
			job.impacts.pop_front()
			if unit.position.distance_to(target.position) <= REACH + 0.25:
				_damage(unit, target)
				if target.battle_dead: break
		if job.time >= job.length:
			_cancel(unit)
			states[unit].cooldown = clock + rng.randf_range(0.3, 0.8)
	var budget := PATH_BUDGET
	for scanned in world.player_units.size():
		cursor = (cursor + 1) % world.player_units.size()
		var unit: TestUnit3D = world.player_units[cursor]
		var state: Dictionary = states[unit]
		if unit.battle_dead or state.manual or jobs.has(unit) or clock < state.next or clock < state.cooldown: continue
		state.next = clock + rng.randf_range(0.65, 1.0)
		_think(unit)
		budget -= 1
		if budget == 0: break
	var blue := living(0).size()
	var red := living(1).size()
	if blue == 0 or red == 0:
		set_autobattle(false)
		message.text = "Победа синих" if blue > 0 else "Победа красных"
	_update_counter()

func _think(unit: TestUnit3D) -> void:
	var target: TestUnit3D
	var best := INF
	for other in world.player_units:
		if other.battle_dead or other.team_id == unit.team_id: continue
		var distance := unit.position.distance_squared_to(other.position)
		if distance < best:
			best = distance
			target = other
	if target == null: return
	if best <= REACH * REACH:
		_start_attack(unit, target)
		return
	_release_slot(unit)
	var center: Vector2i = world.map_renderer.world_to_cell(target.position)
	var finish := Vector2i(-999, -999)
	best = INF
	for y in range(-2, 3):
		for x in range(-2, 3):
			if x == 0 and y == 0: continue
			var cell := center + Vector2i(x, y)
			if reservations.has(cell) or not world.map_renderer.is_land(cell): continue
			var point: Vector3 = world.map_renderer.cell_to_world(cell.x, cell.y)
			var occupied := false
			for other in world.player_units:
				if other != unit and not other.battle_dead and point.distance_squared_to(other.position) < BODY_DISTANCE * BODY_DISTANCE:
					occupied = true
					break
			if occupied: continue
			var score := point.distance_squared_to(unit.position) + point.distance_squared_to(target.position) * 2.0
			if score < best:
				best = score
				finish = cell
	if finish.x == -999: return
	var start: Vector2i = world.map_renderer.world_to_cell(unit.position)
	# Plan around live bodies as well as checking each actual movement step.
	# Use a private grid: temporary occupancy must never leak into normal orders.
	var blocked: Array[Vector2i] = []
	for other in world.player_units:
		if other == unit or other.battle_dead: continue
		var cell: Vector2i = world.map_renderer.world_to_cell(other.position)
		if cell == start or cell == finish or not combat_pathfinder.astar_grid.is_in_boundsv(cell): continue
		if not combat_pathfinder.astar_grid.is_point_solid(cell):
			blocked.append(cell)
			combat_pathfinder.astar_grid.set_point_solid(cell, true)
	var path: Array[Vector2i] = combat_pathfinder.find_path(start, finish)
	for cell in blocked: combat_pathfinder.astar_grid.set_point_solid(cell, false)
	if path.is_empty(): return
	reservations[finish] = unit
	unit.follow_path(path, world.map_renderer)
	# Replanning must not walk back to the center of the current cell.
	if unit.target_cells.size() > 1 and unit.target_cells[0] == start:
		unit.target_cells.pop_front()
		unit.target_positions.pop_front()

func _start_attack(unit: TestUnit3D, target: TestUnit3D) -> void:
	world.rts.orders.stop([unit])
	_release_slot(unit)
	unit.movement_locked = true
	var state: Dictionary = states[unit]
	var clip: String = "Attack_Combo" if state.last == "Attack_Splash" else "Attack_Splash"
	if state.last == "": clip = "Attack_Combo" if rng.randf() < 0.5 else "Attack_Splash"
	state.last = clip
	var direction := target.position - unit.position
	unit.visual.player.speed_scale = rng.randf_range(0.92, 1.08)
	unit.visual.player.play(clip, 0.18)
	var speed: float = unit.visual.player.speed_scale
	# In-place extracted clips: do not replay authored lunges into another body.
	jobs[unit] = {"target": target, "time": 0.0, "heading": atan2(direction.x, direction.z), "length": unit.visual.player.get_animation(clip).length / speed,
		"impacts": [0.95 / speed, 2.35 / speed] if clip == "Attack_Combo" else [0.65 / speed]}
	attacks += 1

func _damage(attacker: TestUnit3D, target: TestUnit3D) -> void:
	if target.battle_dead: return
	states[target].hp = maxi(0, states[target].hp - DAMAGE)
	hits += 1
	blood.spawn_hit(target.global_position, attacker.global_position.direction_to(target.global_position))
	if states[target].hp > 0: return
	target.battle_dead = true
	jobs.erase(target)
	_release_slot(target)
	world.rts.orders.stop([target])
	target.movement_locked = true
	target.set_selected(false)
	target.set_hovered(false)
	target.remove_from_group("rts_units")
	if death_bag.is_empty():
		death_bag.assign([1, 2, 3])
		for index in range(2, 0, -1):
			var other := rng.randi_range(0, index)
			var value := death_bag[index]
			death_bag[index] = death_bag[other]
			death_bag[other] = value
		if death_bag.back() == previous_death:
			var value := death_bag[0]
			death_bag[0] = death_bag[2]
			death_bag[2] = value
	previous_death = death_bag.pop_back()
	var clip := "Death_%d" % previous_death
	target.visual.player.speed_scale = 1.0
	target.visual.player.play(clip, 0.2)
	deaths[target] = target.visual.player.get_animation(clip).length * 0.85

func _update_counter() -> void:
	counter.text = "Синие: %d / 50    Красные: %d / 50" % [living(0).size(), living(1).size()]
