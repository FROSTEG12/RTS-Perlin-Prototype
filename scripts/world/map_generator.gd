class_name MapGenerator
extends RefCounted

const RESOURCE_BASELINE_SIZE := 72
const BATHYMETRY_RESOLUTION := 6
const BATHYMETRY_MAX_DEPTH := 2.2
# Forest coverage and stem density are separate: dense woods, open meadows.
const FOREST_COVERAGE := 0.62
const FOREST_STEM_SPACING := 0.92
const FOREST_JITTER := 0.22
const RESOURCE_RULES: Array[Dictionary] = [
	{"kind": "iron", "base_count": 7, "spacing": 7.0, "field_scale": 15.0, "salt": 7919},
	{"kind": "stone", "base_count": 13, "spacing": 5.0, "field_scale": 12.0, "salt": 5051},
	{"kind": "food", "base_count": 18, "spacing": 4.0, "field_scale": 10.0, "salt": 3253},
	{"kind": "coal", "base_count": 7, "spacing": 7.0, "field_scale": 15.0, "salt": 9283},
]


func _make_permutation(seed_value: int) -> PackedInt32Array:
	var values: Array[int] = []
	for index in range(256):
		values.append(index)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for index in range(255, 0, -1):
		var other := random.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[other]
		values[other] = temporary
	var permutation := PackedInt32Array()
	permutation.resize(512)
	for index in range(512):
		permutation[index] = values[index % 256]
	return permutation


func _fade(value: float) -> float:
	return value * value * value * (value * (value * 6.0 - 15.0) + 10.0)


func _gradient(hash_value: int, x: float, y: float) -> float:
	match hash_value & 7:
		0: return x + y
		1: return -x + y
		2: return x - y
		3: return -x - y
		4: return x
		5: return -x
		6: return y
		_: return -y


func _perlin(x: float, y: float, permutation: PackedInt32Array) -> float:
	var floor_x := floori(x)
	var floor_y := floori(y)
	var xi := floor_x & 255
	var yi := floor_y & 255
	var xf := x - floor_x
	var yf := y - floor_y
	var u := _fade(xf)
	var v := _fade(yf)
	var aa := permutation[permutation[xi] + yi]
	var ab := permutation[permutation[xi] + yi + 1]
	var ba := permutation[permutation[xi + 1] + yi]
	var bb := permutation[permutation[xi + 1] + yi + 1]
	return lerpf(
		lerpf(_gradient(aa, xf, yf), _gradient(ba, xf - 1.0, yf), u),
		lerpf(_gradient(ab, xf, yf - 1.0), _gradient(bb, xf - 1.0, yf - 1.0), u), v
	)


func _fractal_noise(x: float, y: float, permutation: PackedInt32Array) -> float:
	var value := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var total_amplitude := 0.0
	for _octave in range(4):
		value += _perlin(x * frequency, y * frequency, permutation) * amplitude
		total_amplitude += amplitude
		amplitude *= 0.52
		frequency *= 2.0
	return value / total_amplitude


func _find_land_components(cells: PackedByteArray, map_size: int) -> Array:
	var visited := PackedByteArray()
	visited.resize(cells.size())
	var components: Array = []
	for start in range(cells.size()):
		if cells[start] == 1 or visited[start] == 1:
			continue
		var component: Array[int] = []
		var queue: Array[int] = [start]
		visited[start] = 1
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			component.append(current)
			var x := current % map_size
			var y: int = current / map_size
			for next in [current - 1, current + 1, current - map_size, current + map_size]:
				if next < 0 or next >= cells.size() or visited[next] == 1 or cells[next] == 1:
					continue
				var next_x: int = next % map_size
				var next_y: int = next / map_size
				if abs(next_x - x) + abs(next_y - y) != 1:
					continue
				visited[next] = 1
				queue.append(next)
		components.append(component)
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return components


func _remove_small_islands(cells: PackedByteArray, map_size: int) -> PackedByteArray:
	var cleaned := cells.duplicate()
	var components := _find_land_components(cleaned, map_size)
	var minimum_area := maxi(10, floori(map_size * map_size * 0.004))
	for component_index in range(1, components.size()):
		var component: Array = components[component_index]
		if component.size() >= minimum_area:
			continue
		for index in component:
			cleaned[index] = 1
	return cleaned


func _largest_land_share(cells: PackedByteArray, map_size: int) -> int:
	var components := _find_land_components(cells, map_size)
	var total_land := 0
	for component in components:
		total_land += component.size()
	if total_land == 0:
		return 0
	return roundi(float(components[0].size()) / total_land * 100.0)


func find_mainland_spawn(cells: PackedByteArray, map_size: int) -> Vector2i:
	var components := _find_land_components(cells, map_size)
	if components.is_empty():
		return Vector2i.ZERO
	var mainland: Array = components[0]
	var map_center := Vector2(map_size / 2.0, map_size / 2.0)
	var best_cell := Vector2i(mainland[0] % map_size, mainland[0] / map_size)
	var best_score := -INF
	for cell_index in mainland:
		var cell := Vector2i(cell_index % map_size, cell_index / map_size)
		var nearby_land := 0
		for offset_y in range(-3, 4):
			for offset_x in range(-3, 4):
				var neighbor := cell + Vector2i(offset_x, offset_y)
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size or neighbor.y >= map_size:
					continue
				if cells[neighbor.y * map_size + neighbor.x] == 0:
					nearby_land += 1
		var center_distance := Vector2(cell).distance_squared_to(map_center)
		var score := nearby_land * 10_000.0 - center_distance
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell


func generate_map(seed_value: int, scale: float, water: int, map_size: int) -> Dictionary:
	var permutation := _make_permutation(seed_value)
	var cells := PackedByteArray()
	cells.resize(map_size * map_size)
	var offset_x := float(seed_value % 997) / 37.0
	var offset_y := float(seed_value % 617) / 29.0
	for y in range(map_size):
		for x in range(map_size):
			var index := y * map_size + x
			var value := _fractal_noise(
				(float(x) - map_size / 2.0) / scale + offset_x,
				(float(y) - map_size / 2.0) / scale + offset_y, permutation
			)
			cells[index] = 1 if value < (water - 50.0) / 95.0 else 0
	var cleaned := _remove_small_islands(cells, map_size)
	var water_cells := 0
	for cell in cleaned:
		if cell == 1:
			water_cells += 1
	return {
		"cells": cleaned,
		"bathymetry": _generate_bathymetry(cleaned, map_size, seed_value),
		"water_percent": roundi(float(water_cells) / cleaned.size() * 100.0),
		"largest_land_percent": _largest_land_share(cleaned, map_size),
	}


func _generate_bathymetry(cells: PackedByteArray, map_size: int, seed_value: int) -> Dictionary:
	var field_size := map_size * BATHYMETRY_RESOLUTION
	var water_distance := PackedFloat32Array()
	var land_distance := PackedFloat32Array()
	water_distance.resize(field_size * field_size)
	land_distance.resize(field_size * field_size)
	var far := float(field_size * 2)
	for y in range(field_size):
		for x in range(field_size):
			var world_x := (float(x) + 0.5) / BATHYMETRY_RESOLUTION - map_size * 0.5
			var world_y := (float(y) + 0.5) / BATHYMETRY_RESOLUTION - map_size * 0.5
			var visual_land := _sample_land_density(cells, map_size, world_x, world_y) >= 0.5
			var index := y * field_size + x
			water_distance[index] = 0.0 if visual_land else far
			land_distance[index] = far if visual_land else 0.0
	water_distance = _distance_transform(water_distance, field_size)
	land_distance = _distance_transform(land_distance, field_size)

	var depth := PackedFloat32Array()
	depth.resize(field_size * field_size)
	var normalized_water_distance := PackedFloat32Array()
	var normalized_land_distance := PackedFloat32Array()
	normalized_water_distance.resize(field_size * field_size)
	normalized_land_distance.resize(field_size * field_size)
	var floor_permutation := _make_permutation(seed_value ^ 0x45D9F3B)
	for y in range(field_size):
		for x in range(field_size):
			var index := y * field_size + x
			var distance_world := maxf(0.0, (water_distance[index] - 0.5) / BATHYMETRY_RESOLUTION)
			normalized_water_distance[index] = clampf(distance_world / 7.0, 0.0, 1.0)
			normalized_land_distance[index] = clampf(
				(land_distance[index] - 0.5) / (7.0 * BATHYMETRY_RESOLUTION), 0.0, 1.0
			)
			# A shallow sandy shelf first, then a broad continental slope. Noise
			# only shapes the basin, so it cannot cut terraces into the shoreline.
			# A fractional-power profile starts descending immediately instead of
			# leaving a constant-width, constant-depth ribbon around every coast.
			var shelf := pow(clampf(distance_world / 4.6, 0.0, 1.0), 0.72)
			var basin := smoothstep(1.6, 10.5, distance_world)
			var world_x := (float(x) + 0.5) / BATHYMETRY_RESOLUTION - map_size * 0.5
			var world_y := (float(y) + 0.5) / BATHYMETRY_RESOLUTION - map_size * 0.5
			var floor_noise := _fractal_noise(world_x / 18.0 + 43.0, world_y / 18.0 - 29.0, floor_permutation)
			var irregularity := floor_noise * 0.18 * smoothstep(2.2, 7.0, distance_world)
			var shore_irregularity := floor_noise * 0.055 * smoothstep(0.18, 1.2, distance_world) * (1.0 - smoothstep(3.2, 6.0, distance_world))
			depth[index] = clampf(0.035 + shelf * 0.58 + basin * 1.58 + irregularity + shore_irregularity, 0.035, BATHYMETRY_MAX_DEPTH)
	return {
		"resolution": BATHYMETRY_RESOLUTION,
		"max_depth": BATHYMETRY_MAX_DEPTH,
		"water_distance": normalized_water_distance,
		"land_distance": normalized_land_distance,
		"depth": depth,
	}


func _sample_land_density(cells: PackedByteArray, map_size: int, world_x: float, world_y: float) -> float:
	var center := (map_size - 1) * 0.5
	var warp_x := sin(world_y * 0.37 + world_x * 0.11) * 0.13 + sin(world_y * 0.83 - world_x * 0.19) * 0.045
	var warp_y := sin(world_x * 0.41 - world_y * 0.09) * 0.13 + sin(world_x * 0.91 + world_y * 0.17) * 0.045
	var grid_x := world_x + warp_x + center
	var grid_y := world_y + warp_y + center
	var base_x := floori(grid_x)
	var base_y := floori(grid_y)
	var weights_x := _cubic_weights(grid_x - base_x)
	var weights_y := _cubic_weights(grid_y - base_y)
	var density := 0.0
	for offset_y in range(4):
		for offset_x in range(4):
			# Same edge-extension rule as MapRenderer3D: no phantom sea outside.
			var cell_x := clampi(base_x + offset_x - 1, 0, map_size - 1)
			var cell_y := clampi(base_y + offset_y - 1, 0, map_size - 1)
			if cells[cell_y * map_size + cell_x] == 0:
				density += weights_x[offset_x] * weights_y[offset_y]
	return density


func _cubic_weights(amount: float) -> PackedFloat32Array:
	var squared := amount * amount
	var cubed := squared * amount
	return PackedFloat32Array([
		pow(1.0 - amount, 3.0) / 6.0,
		(3.0 * cubed - 6.0 * squared + 4.0) / 6.0,
		(-3.0 * cubed + 3.0 * squared + 3.0 * amount + 1.0) / 6.0,
		cubed / 6.0,
	])


func _distance_transform(source: PackedFloat32Array, field_size: int) -> PackedFloat32Array:
	var distances := source
	var diagonal := sqrt(2.0)
	for y in range(field_size):
		for x in range(field_size):
			var index := y * field_size + x
			if distances[index] == 0.0:
				continue
			if x > 0: distances[index] = minf(distances[index], distances[index - 1] + 1.0)
			if y > 0:
				distances[index] = minf(distances[index], distances[index - field_size] + 1.0)
				if x > 0: distances[index] = minf(distances[index], distances[index - field_size - 1] + diagonal)
				if x < field_size - 1: distances[index] = minf(distances[index], distances[index - field_size + 1] + diagonal)
	for y in range(field_size - 1, -1, -1):
		for x in range(field_size - 1, -1, -1):
			var index := y * field_size + x
			if distances[index] == 0.0:
				continue
			if x < field_size - 1: distances[index] = minf(distances[index], distances[index + 1] + 1.0)
			if y < field_size - 1:
				distances[index] = minf(distances[index], distances[index + field_size] + 1.0)
				if x > 0: distances[index] = minf(distances[index], distances[index + field_size - 1] + diagonal)
				if x < field_size - 1: distances[index] = minf(distances[index], distances[index + field_size + 1] + diagonal)
	return distances


func generate_resources(cells: PackedByteArray, map_size: int, seed_value: int, density: int) -> Array[Dictionary]:
	var deposits: Array[Dictionary] = []
	for rule in RESOURCE_RULES:
		var permutation := _make_permutation(seed_value ^ int(rule["salt"]))
		var random := RandomNumberGenerator.new()
		random.seed = seed_value + int(rule["salt"])
		var candidates: Array[Dictionary] = []
		for y in range(1, map_size - 1):
			for x in range(1, map_size - 1):
				if cells[y * map_size + x] == 1:
					continue
				var score := _fractal_noise(
					(float(x) + int(rule["salt"]) % 31) / float(rule["field_scale"]),
					(float(y) + int(rule["salt"]) % 23) / float(rule["field_scale"]), permutation
				) + random.randf() * 0.035
				candidates.append({"x": x, "y": y, "score": score})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
		var area_factor := float(map_size * map_size) / (RESOURCE_BASELINE_SIZE * RESOURCE_BASELINE_SIZE)
		var target := roundi(int(rule["base_count"]) * density / 100.0 * area_factor)
		var count := 0
		for candidate in candidates:
			if not _position_is_clear(candidate, deposits, float(rule["spacing"]), String(rule["kind"])):
				continue
			deposits.append({"x": candidate["x"], "y": candidate["y"], "kind": rule["kind"]})
			count += 1
			if count >= target:
				break
	return deposits + _generate_forest(cells, map_size, seed_value, density, deposits)


func _position_is_clear(candidate: Dictionary, nodes: Array[Dictionary], same_kind_spacing: float, kind: String) -> bool:
	for node in nodes:
		var dx := float(node["x"] - candidate["x"])
		var dy := float(node["y"] - candidate["y"])
		var minimum := same_kind_spacing if node["kind"] == kind else 2.25
		if dx * dx + dy * dy < minimum * minimum:
			return false
	return true


func _generate_forest(cells: PackedByteArray, map_size: int, seed_value: int, density: int, occupied: Array[Dictionary]) -> Array[Dictionary]:
	var macro_permutation := _make_permutation(seed_value ^ 1879)
	var detail_permutation := _make_permutation(seed_value ^ 6421)
	var warp_permutation := _make_permutation(seed_value ^ 4243)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ 991
	var candidates: Array[Dictionary] = []
	var scores: Array[float] = []
	if density <= 0:
		return []
	var spawn := Vector2(find_mainland_spawn(cells, map_size))
	for y in range(1, map_size - 1):
		for x in range(1, map_size - 1):
			if cells[y * map_size + x] == 1:
				continue
			# Keep trunks off the smooth beach and out of narrow coastal strips.
			var coastal := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if cells[(y + oy) * map_size + x + ox] == 1:
						coastal = true
			if coastal:
				continue
			var warp_x := _perlin(x / 24.0 + 17.0, y / 24.0 - 9.0, warp_permutation) * 10.0
			var warp_y := _perlin(x / 24.0 - 31.0, y / 24.0 + 23.0, warp_permutation) * 10.0
			var world_x := x + warp_x
			var world_y := y + warp_y
			var massif := _fractal_noise(world_x / 20.0 + 41.0, world_y / 20.0 - 17.0, macro_permutation)
			var belt := _fractal_noise(world_x / 34.0 - 11.0, world_y / 8.0 + 29.0, macro_permutation)
			var edge := _fractal_noise(x / 6.0 + 73.0, y / 6.0 - 47.0, detail_permutation)
			var clearing := _fractal_noise(x / 10.0 - 59.0, y / 10.0 + 83.0, detail_permutation)
			var clearing_cut := maxf(0.0, clearing - 0.12) * 1.6
			var score := massif * 0.78 + belt * 0.34 + edge * 0.16 - clearing_cut
			scores.append(score)
			candidates.append({"x": x, "y": y, "score": score})
	if candidates.is_empty():
		return []
	# A land-relative percentile keeps different seeds consistently wooded.
	# The spatial noise still defines the shapes, rather than random scatter.
	scores.sort()
	var coverage := clampf(FOREST_COVERAGE + (density - 130) * 0.002, 0.15, 0.82)
	var threshold := scores[clampi(int(scores.size() * (1.0 - coverage)), 0, scores.size() - 1)]
	# Shuffle with the local seeded RNG (Array.shuffle uses global state).
	for index in range(candidates.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var temporary: Dictionary = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = temporary
	var trees: Array[Dictionary] = []
	var stem_grid := {}
	for candidate in candidates:
		var forest_amount := smoothstep(threshold - 0.035, threshold + 0.065, float(candidate["score"]))
		var chance := lerpf(0.008, 0.97, forest_amount)
		var point := Vector2(candidate["x"], candidate["y"])
		chance *= smoothstep(3.5, 6.0, point.distance_to(spawn))
		if random.randf() > chance:
			continue
		# Deposits stay accessible without punching huge holes in every grove.
		if not _far_from_all(candidate, occupied, 1.4):
			continue
		var offset := Vector2(random.randf_range(-FOREST_JITTER, FOREST_JITTER), random.randf_range(-FOREST_JITTER, FOREST_JITTER))
		var stem := point + offset
		var cell := Vector2i(point)
		var clear := true
		# Only nine local cells instead of scanning every previously placed tree.
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var neighbor := cell + Vector2i(ox, oy)
				if stem_grid.has(neighbor) and stem.distance_squared_to(stem_grid[neighbor]) < FOREST_STEM_SPACING * FOREST_STEM_SPACING:
					clear = false
		if not clear:
			continue
		stem_grid[cell] = stem
		trees.append({"x": candidate["x"], "y": candidate["y"], "kind": "tree", "offset_x": offset.x, "offset_y": offset.y})
	return trees


func _far_from_all(candidate: Dictionary, nodes: Array[Dictionary], minimum: float) -> bool:
	for node in nodes:
		var dx := float(node["x"] - candidate["x"])
		var dy := float(node["y"] - candidate["y"])
		if dx * dx + dy * dy < minimum * minimum:
			return false
	return true
