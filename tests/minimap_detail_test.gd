extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	for frame in 5: await process_frame
	var map = world.hud.minimap
	assert(map.visible_resource_markers().is_empty(), "Resources must not clutter the minimap")
	assert(map.FRIENDLY_POINT_RADIUS == 5.5)
	var troops: Array[Vector3] = map.friendly_marker_positions()
	assert(troops.size() == 1, "One blue point for all fifteen squad members")
	var center := Vector3.ZERO
	for unit in world.player_units: center += unit.global_position
	assert(troops[0].is_equal_approx(center / 15))
	world.player_units[14].squad_id = 2
	assert(map.friendly_marker_positions().size() == 2)
	world.player_units[14].squad_id = 1
	world.player_units[14].individual_control = true
	assert(map.friendly_marker_positions().size() == 2, "Special units keep their own marker")
	world.player_units[14].individual_control = false
	assert(map.friendly_marker_positions().size() == 1)
	var coal := 0
	for resource in world.map_renderer.resources:
		if resource.kind == "coal": coal += 1
	assert(coal > 0)
	assert(world.map_renderer.RESOURCE_COLORS.coal != world.map_renderer.RESOURCE_COLORS.stone)
	assert(map.terrain.get_width() == world.map_renderer.map_size * 10)
	assert(map.terrain_material.get_shader_parameter("wear_texture") == world.map_renderer.trail_wear.texture)
	assert(map.landmarks.is_empty() and map.enemy_contacts.is_empty())
	for region in map.resource_regions:
		assert(world.map_renderer.is_land(world.map_renderer.world_to_cell(region.position)), "Grouped markers stay on real deposits, not water")
	assert(map.marker_visible(Vector3.ZERO) and not map.marker_visible(Vector3.INF))
	assert(not map.marker_visible(Vector3(1000,0,1000)))
	for point in [Vector3.ZERO, Vector3(21,0,-34), Vector3(-50,0,50)]:
		assert(map.unproject(map.project(point)).distance_to(point) < 0.001)
	map.set_contact(1, Vector3.ZERO, 1, [])
	assert(not map.is_contact_visible(map.enemy_contacts[1].team, map.enemy_contacts[1].seen_by))
	map.set_contact(1, Vector3.ZERO, 1, [0])
	assert(map.is_contact_visible(map.enemy_contacts[1].team, map.enemy_contacts[1].seen_by))
	map.set_landmark(2, Vector3.ZERO, "building")
	map.set_landmark(3, Vector3(5,0,5), "watchtower", 1, [])
	assert(map.landmarks.size() == 2 and map.landmarks[3].kind == "watchtower")
	map.remove_landmark(2)
	map.remove_landmark(3)
	map.remove_contact(1)
	var cached: Texture2D = map.terrain
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080), Vector2i(3440,1440)]:
		root.size = dimensions
		for frame in 8: await process_frame
		assert(map.terrain == cached)
		var deposits: Array[Vector2] = map.visible_resource_markers()
		for i in deposits.size():
			for j in range(i+1, deposits.size()): assert(deposits[i].distance_to(deposits[j]) >= 24)
		assert(root.get_visible_rect().encloses(map.get_global_rect()))
		assert(not map.camera_footprint().is_empty())
		for polygon in map.camera_footprint():
			for point in polygon: assert(Rect2(Vector2.ZERO, map.size).has_point(point))
	# Rebuild clears previous-world contacts but preserves deterministic terrain.
	map.set_contact(99, Vector3.ZERO, 1, [0])
	map.set_landmark(99, Vector3.ZERO, "building")
	map.rebuild()
	assert(map.landmarks.is_empty() and map.enemy_contacts.is_empty())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/minimap-detailed-hud.png")
		var actual_scale: Vector2 = root.get_stretch_transform().get_scale()
		image.get_region(Rect2i(map.global_position * actual_scale, map.size * actual_scale)).save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/minimap-readable.png")
		# Inspect the same real terrain in a larger temporary test-only viewport area.
		map.position = Vector2(50,100)
		map.size = Vector2(720,720)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var scale: Vector2 = root.get_stretch_transform().get_scale()
		var rect := Rect2i(map.global_position * scale, map.size * scale)
		root.get_texture().get_image().get_region(rect).save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/minimap-detail.png")
	print("MINIMAP_DETAIL_PASS raster resolution visibility landmarks projection footprint cache resize")
	quit()
