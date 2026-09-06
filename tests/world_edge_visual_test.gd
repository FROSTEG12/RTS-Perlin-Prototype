extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.world_seed = 4242
	world.generate_world()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	world._set_time_of_day(12.0)
	var renderer = world.get_node("MapRenderer")
	var edge = renderer.get_node_or_null("WorldEdge")
	if edge != null:
		assert(edge.get_child_count() <= 3)
		var rock = edge.get_node("RockStrata")
		var arrays = rock.mesh.surface_get_arrays(0)
		var perimeter_count: int = renderer.map_size * renderer.GROUND_SUBDIVISIONS * 4
		assert(arrays[Mesh.ARRAY_VERTEX].size() == perimeter_count * 7)
		for point in arrays[Mesh.ARRAY_VERTEX]:
			assert(point.is_finite())
		for index in perimeter_count:
			var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			assert(absf(point.y - renderer._ground_surface_y(point.x, point.z)) < 0.001)
			for ring in range(1, 7):
				var below: Vector3 = arrays[Mesh.ARRAY_VERTEX][ring * perimeter_count + index]
				assert(Vector2(point.x, point.z).distance_to(Vector2(below.x, below.z)) < 0.0001)
		print("EDGE_GEOMETRY PASS: exact terrain seam; finite vertices; wet segments=", edge.get_meta("wet_edge_segments", 0))
		if edge.has_node("FallingWater"):
			var fa = edge.get_node("FallingWater").mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = fa[Mesh.ARRAY_VERTEX]
			var boundary: PackedVector2Array = fa[Mesh.ARRAY_TEX_UV2]
			for first in range(0, vertices.size(), 110):
				for col in range(2):
					var top := vertices[first + col]
					assert(absf(top.y - renderer.WATER_Y) < 0.00001)
					assert(Vector2(top.x, top.z).distance_to(boundary[first + col]) < 0.00001)
					var bend_end := vertices[first + 12 + col]
					var bottom := vertices[first + 108 + col]
					assert(Vector2(bend_end.x, bend_end.z).distance_to(Vector2(bottom.x, bottom.z)) < 0.00001)
			print("FLOW_SEAM PASS: shared boundary coordinates; vertical fall after rounded bend")
	var camera = world.get_node("GameCamera")
	camera.size = 22.0
	if "--preview" in OS.get_cmdline_user_args():
		camera.size = 16.0
		var target := Vector3(51.5, 0, 51.5)
		var score := INF
		if edge != null and edge.has_node("FallingWater"):
			var points = edge.get_node("FallingWater").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for p in points:
				if p.y > -0.17 and (p.x > 51.0 or p.z > 51.0):
					var candidate_score := minf(absf(p.x), absf(p.z))
					if candidate_score < score:
						score = candidate_score
						target = Vector3(p.x, 0, p.z)
		camera.global_position = target + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
		camera._clamp_position()
		world.process_mode = Node.PROCESS_MODE_INHERIT
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		for frame in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/edge_preview_v2.png")
		print("WATERFALL_PREVIEW ready; gameplay controls active")
		return
	var targets := [Vector3(51.5, 0, 51.5), Vector3(-51.5, 0, 51.5), Vector3(51.5, 0, -51.5), Vector3(-51.5, 0, -51.5)]
	if edge.has_node("FallingWater"):
		var points = edge.get_node("FallingWater").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var best_score := INF
		var fall_target := Vector3.ZERO
		for p in points:
			if p.y > -0.17 and (p.x > 51.0 or p.z > 51.0):
				var score := minf(absf(p.x), absf(p.z))
				if score < best_score:
					best_score = score
					fall_target = Vector3(p.x, -1.5, p.z)
		targets.append(fall_target)
	for index in targets.size():
		camera.global_position = targets[index] + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
		camera._clamp_position()
		for frame in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/world_edge_%d.png" % index)
		print("EDGE_VIEW ", index)
	for hour in [0.0, 6.5, 18.5]:
		world._set_time_of_day(hour)
		for frame in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/edge_hour_%s.png" % str(hour))
	world._set_time_of_day(0.0)
	for frame in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/world_edge_night.png")
	# Close-up A/B: static occlusion must visibly darken the actual rock.
	world._set_time_of_day(12.0)
	var rock = edge.get_node("RockStrata")
	var rock_arrays = rock.mesh.surface_get_arrays(0)
	var contact_target := Vector3.ZERO
	var contact_score := INF
	for index in renderer.map_size * renderer.GROUND_SUBDIVISIONS * 4:
		var p: Vector3 = rock_arrays[Mesh.ARRAY_VERTEX][index]
		var occlusion: float = rock_arrays[Mesh.ARRAY_COLOR][index].b
		if occlusion > 0.3 and occlusion < 0.8 and (p.x > 51 or p.z > 51):
			var score := minf(absf(p.x), absf(p.z))
			if score < contact_score:
				contact_score = score
				contact_target = p + Vector3(0, -1.0, 0)
	assert(contact_score < INF)
	camera.size = 10.0
	camera.global_position = contact_target + camera.global_basis.z * (18.0 / camera.global_basis.z.y)
	camera._clamp_position()
	Engine.time_scale = 0.0
	var shadow_images: Array[Image] = []
	for strength in [0.46, 0.0]:
		rock.material_override.set_shader_parameter("waterfall_shadow_strength", strength)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/contact_shadow_%s.png" % str(strength))
		shadow_images.append(shot)
	var darkened := 0
	for y in range(shadow_images[0].get_height()):
		for x in range(shadow_images[0].get_width()):
			if shadow_images[1].get_pixel(x, y).get_luminance() - shadow_images[0].get_pixel(x, y).get_luminance() > 0.015:
				darkened += 1
	assert(darkened > 30)
	print("STATIC_CONTACT PASS: ", darkened, " darkened pixels in close-up A/B")
	Engine.time_scale = 1.0
	quit()
