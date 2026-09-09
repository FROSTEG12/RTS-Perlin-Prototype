extends SceneTree
var world: Node3D
var arena: Node3D
var origin: Vector3

func _initialize(): call_deferred("run")

func simulate(seconds: float) -> void:
	for frame in ceili(seconds * 60):
		arena._process(1.0 / 60)
		for unit in [arena.hero, arena.npc]:
			unit._process(1.0 / 60)
			unit.visual._process(1.0 / 60)

func pair(offscreen: bool) -> void:
	arena.reset_arena()
	arena.hero.position = origin
	arena.npc.position = origin + Vector3.BACK * 1.6
	for unit in [arena.hero, arena.npc]:
		unit.grid_cell = world.map_renderer.world_to_cell(unit.position)
		unit.visual.reset_pose()
	world.game_camera.size = 5
	world.game_camera.focus_on(origin + (Vector3.ONE * 1000 if offscreen else Vector3.ZERO))
	arena.bags.clear()
	arena.previous.clear()
	arena.rng.seed = 321

func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("ANIMATION_BUDGET_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	world.set_script(load("res://tests/stress_world.gd"))
	world.battle_test = false
	root.add_child(world)
	world.set_process(false)
	world.simulation_speed = 0
	world._set_time_of_day(12)
	arena = world.training
	arena.set_process(false)
	arena.blood.set_process(false)
	origin = arena.hero.global_position
	for y in range(10, 94):
		var found := false
		for x in range(10, 94):
			if arena.blood.interior[y*104+x] == 1:
				origin = world.map_renderer.cell_to_world(x,y)
				found = true
				break
		if found: break
	for unit in world.player_units + [arena.npc]:
		unit.set_process(false)
		unit.visual.set_process(false)
		if unit != arena.hero and unit != arena.npc: unit.position = origin + Vector3(20,0,20)
	# Real movement and real training logic, only visual evaluation differs.
	pair(false)
	arena.set_npc_attacking(true)
	simulate(40)
	assert(arena.dead and not arena.death_blood_pending)
	var position: Vector3 = arena.hero.position
	var npc_position: Vector3 = arena.npc.position
	var clip: StringName = arena.hero.visual.player.assigned_animation
	var hits: int = arena.blood.spawned
	pair(true)
	var start_updates: int = arena.hero.visual.pose_updates
	arena.set_npc_attacking(true)
	simulate(40)
	assert(arena.dead and arena.health == 0 and not arena.death_blood_pending)
	assert(arena.blood.spawned == hits)
	assert(arena.hero.position.distance_to(position) < 0.00001)
	assert(arena.npc.position.distance_to(npc_position) < 0.00001)
	assert(arena.hero.visual.player.assigned_animation == clip)
	assert(arena.hero.visual.pose_updates - start_updates <= hits + 2, "Only sparse contact sockets evaluated offscreen")
	world.game_camera.focus_on(origin)
	arena.hero.visual._process(1.0/60)
	assert(arena.hero.visual.player.current_animation_position >= arena.death_length - 0.01, "Return at final corpse pose, not restart")
	# Small on-screen models use 20 Hz poses; close view stays full rate.
	pair(false)
	var visual: Node3D = arena.hero.visual
	start_updates = visual.pose_updates
	simulate(2)
	assert(visual.pose_updates-start_updates >= 118)
	world.game_camera.size = 42
	start_updates = visual.pose_updates
	simulate(2)
	assert(visual.pose_updates-start_updates >= 39 and visual.pose_updates-start_updates <= 41)
	# Move while offscreen. Position/arrival cannot depend on pose updates.
	pair(true)
	var cell: Vector2i = arena.hero.grid_cell
	var path: Array[Vector2i] = world.pathfinder.find_path(cell, cell+Vector2i(2,0))
	assert(arena.hero.accept_move(path, world.map_renderer, false))
	simulate(3)
	assert(arena.hero.target_positions.is_empty())
	assert(arena.hero.position.distance_to(world.map_renderer.cell_to_world(cell.x+2,cell.y)) < 0.001)
	# A low sun can project an offscreen caster's shadow into the current view.
	var light: DirectionalLight3D = world.key_light
	var saved_transform := light.transform
	light.rotation_degrees = Vector3(-5, 0, 0)
	light.shadow_enabled = true
	light.shadow_opacity = 1
	world.game_camera.focus_on(arena.hero.position + Vector3(0,0,-20))
	assert(visual._shadow_reaches_view(world.game_camera, root.get_visible_rect()))
	light.shadow_enabled = false
	assert(not visual._shadow_reaches_view(world.game_camera, root.get_visible_rect()))
	light.shadow_enabled = true
	light.transform = saved_transform
	# Cached interior must agree with original shore/height test, including edges.
	var blood: Node3D = arena.blood
	var expected := []
	var samples := []
	for y in range(0, 104, 3):
		for x in range(0, 104, 3):
			var point: Vector3 = world.map_renderer.cell_to_world(x,y) + Vector3(0.39,0,-0.39)
			samples.append(point)
			expected.append(blood._dry_footprint(point, 0.36, 0))
	var saved: PackedByteArray = blood.interior.duplicate()
	blood.interior.fill(0)
	for i in samples.size(): assert(expected[i] == blood._dry_footprint(samples[i], 0.36, 0))
	blood.interior = saved
	# Queue is bounded, coalesces only cosmetics, reset removes unfinished work.
	blood.clear()
	for i in 200: assert(blood.spawn_hit(origin, Vector3.RIGHT))
	assert(blood.pending.size() <= 49 and blood.coalesced > 0 and blood.spawned == 200)
	blood._process(1.0/60)
	blood.clear()
	blood._process(1)
	assert(blood.pending.is_empty() and blood.active_count() == 0 and blood.merged.is_empty())
	print("ANIMATION_BUDGET_PASS offscreen_combat_hp_combo_death_reentry_movement near60_far20 dry_cache_equivalence blood_queue_reset")
	quit()
