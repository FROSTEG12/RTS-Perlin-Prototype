extends RefCounted
## One-to-one minimum squared displacement, not slot-number-first greedy picks.
## Squared distance preserves relative rows during a translation of the squad.
## Returns slot index -> source index. Canonical order makes ties independent
## of the order in which the player drew the slots. Runs once per order, O(n^3).
static func match_positions(sources: Array[Vector3], slots: Array[Vector3]) -> Array[int]:
	var count := sources.size()
	if count == 0 or slots.size() != count: return []
	var source_order := ordered(sources)
	var slot_order := ordered(slots)
	var costs: Array[PackedFloat64Array] = []
	for source in source_order:
		var row := PackedFloat64Array()
		for slot in slot_order:
			var offset := sources[source]-slots[slot]
			row.append(float(offset.x)*offset.x+float(offset.z)*offset.z)
		costs.append(row)
	# Hungarian augmenting paths; index zero is the unmatched sentinel.
	var u := PackedFloat64Array()
	var v := PackedFloat64Array()
	var owner := PackedInt32Array()
	var previous := PackedInt32Array()
	u.resize(count+1)
	v.resize(count+1)
	owner.resize(count+1)
	previous.resize(count+1)
	for source in range(1,count+1):
		owner[0] = source
		var column := 0
		var minimum := PackedFloat64Array()
		var used := PackedByteArray()
		minimum.resize(count+1)
		minimum.fill(INF)
		used.resize(count+1)
		while true:
			used[column] = 1
			var current := owner[column]
			var delta := INF
			var next_column := 0
			for candidate in range(1,count+1):
				if used[candidate]: continue
				var cost := costs[current-1][candidate-1]-u[current]-v[candidate]
				if cost < minimum[candidate]:
					minimum[candidate] = cost
					previous[candidate] = column
				if minimum[candidate] < delta:
					delta = minimum[candidate]
					next_column = candidate
			for candidate in range(count+1):
				if used[candidate]:
					u[owner[candidate]] += delta
					v[candidate] -= delta
				else: minimum[candidate] -= delta
			column = next_column
			if owner[column] == 0: break
		while column != 0:
			var next_column := previous[column]
			owner[column] = owner[next_column]
			column = next_column
	var result: Array[int] = []
	result.resize(count)
	for column in range(1,count+1):
		result[slot_order[column-1]] = source_order[owner[column]-1]
	return result

static func ordered(points: Array[Vector3]) -> Array[int]:
	var result: Array[int] = []
	for index in points.size(): result.append(index)
	result.sort_custom(func(a,b):
		if points[a].x != points[b].x: return points[a].x < points[b].x
		if points[a].z != points[b].z: return points[a].z < points[b].z
		return a < b)
	return result
