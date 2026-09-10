extends SceneTree

func _initialize() -> void:
	var generator := MapGenerator.new()
	for seed_value in [177, 4242, 20260906, 1788727711]:
		var data := generator.generate_map(seed_value, 34.0, 40, 104)
		var cells: PackedByteArray = data.cells
		var start := Time.get_ticks_msec()
		var resources := generator.generate_resources(cells, 104, seed_value, 130)
		var elapsed := Time.get_ticks_msec() - start
		var trees := 0
		var coal: Array[Vector2i] = []
		var occupied := {}
		var tiles := {}
		var interior_land := 0
		for y in range(1, 103):
			for x in range(1, 103):
				if cells[y * 104 + x] == 0:
					interior_land += 1
		for resource in resources:
			var cell := Vector2i(resource.x, resource.y)
			assert(cells[cell.y * 104 + cell.x] == 0)
			assert(not occupied.has(cell), "Resources must not share a cell")
			occupied[cell] = true
			if resource.kind == "coal":
				for previous in coal: assert(Vector2(previous).distance_to(Vector2(cell)) >= 7.0)
				coal.append(cell)
			if resource.kind == "tree":
				trees += 1
				var tile := Vector2i(cell.x / 8, cell.y / 8)
				tiles[tile] = int(tiles.get(tile, 0)) + 1
		var dense_tiles := 0
		assert(not coal.is_empty(), "Coal deposits generated on land like iron")
		for count in tiles.values():
			if count >= 18:
				dense_tiles += 1
		print("FOREST seed=", seed_value, " trees=", trees, " land=", interior_land,
			" dense_8x8_tiles=", dense_tiles, " generation_ms=", elapsed)
		if "--baseline" not in OS.get_cmdline_user_args():
			assert(trees > interior_land * 0.17, "Forest must be substantially denser than old markers")
			assert(trees < interior_land * 0.5, "Keep open ground")
			assert(dense_tiles >= 8, "Need coherent forest interiors")
			assert(resources == generator.generate_resources(cells, 104, seed_value, 130), "Seed must be reproducible")
	print("FOREST_TEST PASS")
	quit()
