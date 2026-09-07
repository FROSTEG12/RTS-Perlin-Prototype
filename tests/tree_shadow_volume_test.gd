extends SceneTree
const TREES = preload("res://scripts/tree_resources.gd")
const CYCLE = preload("res://scripts/day_night_lighting.gd")
func _initialize() -> void:
	var smallest_area := INF
	for variant in 6:
		var mesh := TREES.shadow_mesh(variant, 3.5)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		assert(arrays[Mesh.ARRAY_INDEX].size() / 3 <= 200)
		for minute in 1440:
			var direction := -Basis.from_euler(CYCLE.sample(minute / 60.0).rotation).z
			var projected := PackedVector2Array()
			for p in vertices:
				var shadow := p - direction * (p.y / direction.y)
				projected.append(Vector2(shadow.x, shadow.z))
			var hull := Geometry2D.convex_hull(projected)
			var twice_area := 0.0
			for index in range(hull.size() - 1):
				twice_area += hull[index].cross(hull[index + 1])
			var area := absf(twice_area) * 0.5
			assert(area > 0.25, "Shadow volume collapsed at hour %s" % (minute / 60.0))
			smallest_area = minf(smallest_area, area)
	print("TREE_VOLUME PASS: 6 variants x 1440 sun positions; min projected area=", smallest_area, "; <=200 triangles per proxy")
	quit()
