class_name MapGenerator
extends RefCounted

const RESOURCE_BASELINE_SIZE := 72
const RESOURCE_RULES: Array[Dictionary] = [
	{"kind": "iron", "base_count": 7, "spacing": 7.0, "field_scale": 15.0, "salt": 7919},
	{"kind": "stone", "base_count": 13, "spacing": 5.0, "field_scale": 12.0, "salt": 5051},
	{"kind": "food", "base_count": 18, "spacing": 4.0, "field_scale": 10.0, "salt": 3253},
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
		"water_percent": roundi(float(water_cells) / cleaned.size() * 100.0),
		"largest_land_percent": _largest_land_share(cleaned, map_size),
	}


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
	var threshold := 0.055 - (density - 100) * 0.0017
	var candidates: Array[Dictionary] = []
	for y in range(1, map_size - 1):
		for x in range(1, map_size - 1):
			if cells[y * map_size + x] == 1:
				continue
			var warp_x := _perlin(x / 24.0 + 17.0, y / 24.0 - 9.0, warp_permutation) * 10.0
			var warp_y := _perlin(x / 24.0 - 31.0, y / 24.0 + 23.0, warp_permutation) * 10.0
			var world_x := x + warp_x
			var world_y := y + warp_y
			var massif := _fractal_noise(world_x / 20.0 + 41.0, world_y / 20.0 - 17.0, macro_permutation)
			var belt := _fractal_noise(world_x / 34.0 - 11.0, world_y / 8.0 + 29.0, macro_permutation)
			var edge := _fractal_noise(x / 6.0 + 73.0, y / 6.0 - 47.0, detail_permutation)
			var clearing := _fractal_noise(x / 10.0 - 59.0, y / 10.0 + 83.0, detail_permutation)
			var clearing_cut := (clearing - 0.25) * 1.35 if clearing > 0.25 else 0.0
			var score := massif * 0.78 + belt * 0.34 + edge * 0.16 - clearing_cut
			if score <= threshold:
				continue
			var chance := minf(0.88, 0.24 + (score - threshold) * 2.4)
			candidates.append({"x": x, "y": y, "score": score + random.randf() * 0.012, "chance": chance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var trees: Array[Dictionary] = []
	for candidate in candidates:
		if random.randf() > float(candidate["chance"]):
			continue
		if not _far_from_all(candidate, occupied, 2.25):
			continue
		if not _far_from_all(candidate, trees, 1.45):
			continue
		trees.append({"x": candidate["x"], "y": candidate["y"], "kind": "tree"})
	return trees


func _far_from_all(candidate: Dictionary, nodes: Array[Dictionary], minimum: float) -> bool:
	for node in nodes:
		var dx := float(node["x"] - candidate["x"])
		var dy := float(node["y"] - candidate["y"])
		if dx * dx + dy * dy < minimum * minimum:
			return false
	return true
