extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var world: Node3D
var training: Node3D
var blood: Node3D
var center: Vector3

func _initialize(): call_deferred("run")

func simulate(seconds: float) -> void:
	for step in ceili(seconds * 60):
		training._process(1.0 / 60)
		for unit in [training.hero, training.npc]:
			unit._process(1.0 / 60)
			unit.visual.player.advance(1.0 / 60)

func snap(label: String) -> void:
	blood.flush()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "knight-blood-" + label + ".png")

func position_pair() -> void:
	training.hero.global_position = center
	training.npc.global_position = center + Vector3(1.4, 0, 0)
	for unit in [training.hero, training.npc]:
		unit.grid_cell = world.map_renderer.world_to_cell(unit.global_position)
		unit.visual.player.advance(0)
	training.focus_arena()

func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("BLOOD_TEST_TIMEOUT"); quit(1))
	world = load("res://scenes/main.tscn").instantiate()
	world.battle_test = false
	root.add_child(world)
	world.set_process(false)
	world.simulation_speed = 0
	world._set_time_of_day(12)
	world.weather.climate.fog_override = 0
	world.weather.climate.fog = 0
	world.weather.climate.set_rain(false)
	world._apply_day_night_lighting()
	training = world.training
	blood = training.blood
	training.set_process(false)
	blood.set_process(false)
	blood.rng.seed = 92371
	training.rng.seed = 83712
	# Open dry fixture on the real generated terrain; foliage hidden only in this test.
	world.map_renderer.resource_root.visible = false
	var found := false
	for y in range(8, 96):
		if found: break
		for x in range(8, 96):
			var point: Vector3 = world.map_renderer.cell_to_world(x, y)
			if blood._dry_footprint(point, 8.0, 0.0):
				center = point
				found = true
				break
	assert(found)
	for unit in world.player_units:
		unit.set_process(false)
		if unit != training.hero: unit.global_position = center + Vector3(12, 0, 12)
	for unit in [training.hero, training.npc]:
		unit.set_process(false)
		unit.visual.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	position_pair()
	assert(blood.get_child_count() == 0, "No stacked Decal projectors")
	assert(blood.image.get_format() == Image.FORMAT_RG8)
	assert(world.map_renderer.terrain_material.get_shader_parameter("blood_field_texture") == blood.texture)
	simulate(2)
	assert(blood.spawned == 0)
	training.bags["attack"] = ["Attack_Splash"]
	training._start_attack(training.hero, training.npc)
	simulate(0.3)
	training._cancel_action(training.hero)
	simulate(2)
	assert(blood.spawned == 0, "Cancelled swing cannot bleed")
	training.bags["attack"] = ["Attack_Splash"]
	training._start_attack(training.hero, training.npc)
	training.npc.global_position += Vector3(5, 0, 0)
	simulate(4)
	assert(blood.spawned == 0, "Miss cannot bleed")
	position_pair()
	training.bags["attack"] = ["Attack_Combo"]
	training._start_attack(training.hero, training.npc)
	simulate(5)
	assert(training.npc_hits == 2 and blood.spawned == 2)
	assert(training.health == 100 and not training.dead)
	await snap("hits")
	training.npc_toggle.button_pressed = true
	simulate(40)
	assert(training.dead and not training.death_blood_pending)
	assert(blood.spawned == 8, "2 NPC contacts + 5 damaging hits + one death pool")
	await snap("death")
	world.get_node("UI").visible = false
	world.game_camera.size = 3.8
	await snap("noise-death-close")
	world.get_node("UI").visible = true
	world.game_camera.size = 7
	simulate(10)
	assert(blood.spawned == 8, "Death pool must not repeat")
	blood._process(135)
	assert(blood.active_count() == 8 and not blood.merged.is_empty())
	blood._process(16)
	assert(blood.active_count() == 0)
	assert(not blood.spawn_death(Vector3(999, 0, 999)))
	var water_checked := false
	for y in 104:
		if water_checked: break
		for x in 104:
			if not world.map_renderer.is_land(Vector2i(x, y)):
				assert(not blood.spawn_death(world.map_renderer.cell_to_world(x, y)))
				water_checked = true
				break
	assert(water_checked)
	# Repeated stationary impacts must grow a common field, never lighten existing
	# coverage or stamp a brighter outline over a previous patch.
	assert(blood.spawn_hit(center, Vector3.RIGHT))
	blood.flush()
	var first: Dictionary = blood.merged.duplicate(true)
	await snap("noise-one")
	var started := Time.get_ticks_usec()
	for index in 11: assert(blood.spawn_hit(center, Vector3.RIGHT))
	blood.flush()
	print("BLOOD_11_CONTACTS_AND_UPLOAD_US ", Time.get_ticks_usec() - started)
	for pixel: Vector2i in first:
		assert(blood.merged.has(pixel) and blood.merged[pixel].x >= first[pixel].x)
	assert(blood.merged.size() > first.size() * 1.3, "Stationary spray must spread")
	await snap("noise-twelve")
	world.get_node("UI").visible = false
	world.game_camera.size = 3.8
	await snap("noise-twelve-close")
	world.get_node("UI").visible = true
	world.game_camera.size = 7
	var stable: PackedByteArray = blood.image.get_data()
	var uploads: int = blood.upload_count
	blood.flush()
	assert(blood.image.get_data() == stable and blood.upload_count == uploads)
	for index in 110:
		assert(blood.spawn_hit(center, Vector3.RIGHT))
		blood._drain() # Capacity test, not the separate overload/coalescing test.
	blood.flush()
	assert(blood.active_count() == 96 and blood.get_child_count() == 0)
	assert(blood.dry_pixels.size() == blood.RESOLUTION * blood.RESOLUTION)
	await snap("noise-saturated")
	training.reset_arena()
	assert(blood.active_count() == 0 and not training.death_blood_pending)
	position_pair()
	for index in 6:
		assert(blood.spawn_hit(center + Vector3(index * 0.55 - 1.5, 0, 1.5), Vector3.FORWARD))
	await snap("ground")
	world._set_time_of_day(0)
	world._apply_day_night_lighting()
	await snap("night")
	world.generate_world()
	assert(blood.active_count() == 0)
	assert(world.map_renderer.terrain_material.get_shader_parameter("blood_field_texture") == blood.texture)
	print("KNIGHT_BLOOD_PASS actual_contacts missed_cancelled death_once terrain_only water_edge cap96 fade reset regeneration noise_union_stationary_spread")
	quit()
