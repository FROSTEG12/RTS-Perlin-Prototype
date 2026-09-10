extends RefCounted
## Shared grid footprint: fifteen soldiers, five files, three ranks, no gaps.
const SIZE := 15
const COLUMNS := 5

static func offsets(count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count <= 0: return result
	var columns := mini(COLUMNS, count)
	var rows := ceili(float(count) / columns)
	for i in count:
		result.append(Vector2i(i % columns - columns / 2, i / columns - rows / 2))
	return result

static func find_cells(renderer: Node, center: Vector2i, count: int, max_radius: int = 8,
		pathfinder: RefCounted = null, origin: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var shape := offsets(count)
	if shape.is_empty(): return []
	# Translate the entire footprint near shore/edges; never scatter its members.
	for radius in range(max_radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius: continue
				var cells: Array[Vector2i] = []
				for offset in shape:
					var cell := center + Vector2i(x, y) + offset
					if not renderer.is_land(cell): break
					cells.append(cell)
				if cells.size() != count: continue
				if pathfinder != null and pathfinder.find_path(origin, cells[0]).is_empty(): continue
				return cells
	return []
