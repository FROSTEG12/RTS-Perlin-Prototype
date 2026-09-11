extends RefCounted

static func polygon(center: Vector2, size: Vector2, yaw: float, circular: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	if circular:
		for i in 24: points.append(center+Vector2.from_angle(TAU*i/24.0)*size.x*.5)
	else:
		for p in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			points.append(center+(p*size*.5).rotated(-yaw))
	return points

static func bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for p in points: result = result.expand(p)
	return result

static func intersects(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	# Convex SAT, excluding touching edges: adjacent navigation cells aren't overlaps.
	for poly in [a,b]:
		for i in poly.size():
			var axis: Vector2 = (poly[(i+1)%poly.size()]-poly[i]).orthogonal().normalized()
			var lo_a := INF
			var hi_a := -INF
			var lo_b := INF
			var hi_b := -INF
			for p in a: lo_a=minf(lo_a,p.dot(axis)); hi_a=maxf(hi_a,p.dot(axis))
			for p in b: lo_b=minf(lo_b,p.dot(axis)); hi_b=maxf(hi_b,p.dot(axis))
			if minf(hi_a,hi_b)-maxf(lo_a,lo_b)<.0001: return false
	return true

static func cells(points: PackedVector2Array, renderer: Node3D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var box := bounds(points)
	var first: Vector2i = renderer.world_to_cell(Vector3(box.position.x,0,box.position.y))-Vector2i.ONE
	var last: Vector2i = renderer.world_to_cell(Vector3(box.end.x,0,box.end.y))+Vector2i.ONE
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var p: Vector3 = renderer.cell_to_world(x,y)
			if intersects(points,polygon(Vector2(p.x,p.z),Vector2.ONE,0)): result.append(Vector2i(x,y))
	return result
