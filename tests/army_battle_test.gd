extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D
var battle: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("ARMY_TEST_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	world.set_script(load("res://tests/stress_world.gd"))
	root.add_child(world)
	world.set_process(false)
	world.rts.set_process_input(false)
	world.rts.set_process_unhandled_input(false)
	world.game_camera.set_process_unhandled_input(false)
	world.set_process_unhandled_input(false)
	for button in world.get_node("UI").find_children("*", "BaseButton", true, false): button.disabled = true
	world._set_time_of_day(12)
	battle = world.training
	battle.rng.seed = 456
	if "--live" in OS.get_cmdline_user_args():
		await live_test()
		return
	assert(battle.living(0).size() == 50 and battle.living(1).size() == 50)
	assert(world.rts.units().size() == 100)
	assert(not battle.enabled)
	var blue: TestUnit3D = battle.living(0)[0]
	var red: TestUnit3D = battle.living(1)[0]
	assert(red.visual.get_node("Model").scene_file_path.ends_with("/red.scn"))
	world.rts.set_selection(battle.living(1))
	assert(world.rts.selected.size() == 50)
	# Aim across the army: an adjacent occupied destination may legitimately
	# resolve to the selected unit's own free cell after occupancy-aware placement.
	world.rts.orders.move([red], blue.grid_cell, false)
	for frame in 5: await process_frame
	assert(not red.target_positions.is_empty())
	battle.reset_arena()
	battle.set_autobattle(true)
	battle.manual_override([red])
	assert(battle.states[red].manual and not red.movement_locked)
	battle.set_autobattle(false)
	assert(battle.jobs.is_empty())
	battle.reset_arena()
	battle.set_autobattle(true)
	# Deterministic simulation accelerated independently of visual pose frequency.
	battle.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var frame_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	for tick in 3000:
		battle._process(0.1)
		for unit in world.player_units: unit._process(0.1)
		if tick % 10 == 0:
			await process_frame
			frame_ms.append((Time.get_ticks_usec() - last) / 1000.0)
			last = Time.get_ticks_usec()
		if tick == 100 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT + "army-battle-test.png")
		if tick % 300 == 0: print("ARMY_PROGRESS t=", tick / 10, " blue=", battle.living(0).size(), " red=", battle.living(1).size(), " hits=", battle.hits)
		if not battle.enabled: break
	assert(battle.living(0).size() < 50 and battle.living(1).size() < 50)
	if battle.enabled:
		for unit in battle.living(): print("STUCK team=", unit.team_id, " pos=", unit.position, " path=", unit.target_positions)
	assert(not battle.enabled, "Battle must reach a winner, not jam indefinitely")
	assert(battle.hits > 0)
	var dead: TestUnit3D
	for unit in world.player_units:
		assert(world.map_renderer.is_land(world.map_renderer.world_to_cell(unit.position)))
		if unit.battle_dead: dead = unit
	assert(dead != null and not dead.is_in_group("rts_units") and dead.movement_locked)
	world.rts.set_selection([dead])
	assert(world.rts.selected.is_empty())
	print("ARMY_RESULT blue=", battle.living(0).size(), " red=", battle.living(1).size(), " attacks=", battle.attacks, " hits=", battle.hits)
	battle.reset_arena()
	assert(world.rts.units().size() == 100 and battle.jobs.is_empty() and battle.deaths.is_empty())
	assert(battle.blood.records.is_empty())
	for unit in world.player_units: assert(not unit.battle_dead and not unit.movement_locked)
	# Regeneration must not preserve corpses or occupancy in either navigation grid.
	world.generate_world()
	assert(world.rts.units().size() == 100 and not battle.enabled)
	var occupied := {}
	for unit in world.player_units:
		assert(not occupied.has(unit.grid_cell) and not unit.battle_dead)
		occupied[unit.grid_cell] = true
	print("ARMY_BATTLE_PASS")
	quit()

func live_test() -> void:
	world.weather.climate.fog_override = 0
	world.weather.climate.set_rain(false)
	world._apply_day_night_lighting()
	battle.set_autobattle(true)
	var times: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < 30_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
	assert(battle.hits > 0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "army-battle-live.png")
	times.sort()
	print("ARMY_LIVE frames=", times.size(), " median_ms=", times[times.size() / 2], " p95_ms=", times[int(times.size() * 0.95)], " blue=", battle.living(0).size(), " red=", battle.living(1).size(), " hits=", battle.hits)
	battle.set_autobattle(false)
	var hits_before: int = battle.hits
	for frame in 60: await process_frame
	assert(battle.hits == hits_before and battle.jobs.is_empty())
	print("ARMY_LIVE_PASS")
	quit()
