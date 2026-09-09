extends SceneTree

func _initialize() -> void:
	var renderer := MapRenderer3D.new()
	var generator := MapGenerator.new()
	renderer.map_size = 8
	renderer.cells.resize(64)
	var checks := 0
	# All-land, all-water, then irregular mixed edges including every corner.
	for pattern in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242 + pattern
		for index in 64:
			renderer.cells[index] = pattern if pattern < 2 else rng.randi_range(0, 1)
		for side in range(4):
			for i in range(80):
				var along := -4.0 + i * 0.1
				var a := Vector3(along, 0, -4.0)
				var b := Vector3(along + 0.1, 0, -4.0)
				if side == 1:
					a = Vector3(4, 0, along)
					b = Vector3(4, 0, along + 0.1)
				elif side == 2:
					a = Vector3(along, 0, 4)
					b = Vector3(along + 0.1, 0, 4)
				elif side == 3:
					a = Vector3(-4, 0, along)
					b = Vector3(-4, 0, along + 0.1)
				var density := renderer._sample_land_density(a.x, a.z)
				assert(absf(density - generator._sample_land_density(renderer.cells, 8, a.x, a.z)) < 0.00001)
				if pattern < 2:
					assert(absf(density - (1.0 - pattern)) < 0.00001)
				var h0 := renderer._ground_surface_y(a.x, a.z)
				var h1 := renderer._ground_surface_y(b.x, b.z)
				var interval := renderer.WORLD_EDGE._water_interval(renderer, a, b)
				assert(interval.is_empty() == (h0 >= renderer.WATER_Y and h1 >= renderer.WATER_Y))
				if not interval.is_empty():
					var center := (interval[0] + interval[1]) * 0.5
					var cell := renderer.world_to_cell(center)
					cell.x = clampi(cell.x, 0, 7)
					cell.y = clampi(cell.y, 0, 7)
					assert(renderer.cells[cell.y * 8 + cell.x] == 1 or renderer._touches_water(cell.x, cell.y))
					for p in interval:
						assert(absf(p.y - renderer.WATER_Y) < 0.00001)
						assert(p.distance_to(a) + p.distance_to(b) < 0.42)
					if (h0 < renderer.WATER_Y) != (h1 < renderer.WATER_Y):
						var expected := a.lerp(b, (renderer.WATER_Y - h0) / (h1 - h0))
						expected.y = renderer.WATER_Y
						assert(interval[1 if h0 < renderer.WATER_Y else 0].distance_to(expected) < 0.00001)
				checks += 1
	renderer.trail_wear.free() # Not parented: renderer never entered the scene tree.
	renderer.free()
	print("WATERFALL_BOUNDARY PASS: ", checks, " segments; shared density, no phantom coast, exact terrain/water intersection")
	quit()
