extends RefCounted
## Measured masonry sockets, independent of grid/base bounds. Yaw is Godot Y.
const WALL_HALF := 2.694366
const SQUARE_JOIN := .98
const ROUND_JOIN := .72 # Wall corners tuck inside the 1.256 m shaft.
const ORBIT_STEP := PI / 12.0
const DIRECTIONS := [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]

static func kind(id: StringName) -> String:
	return str(id).trim_prefix("fortress_")

static func is_round(id: StringName) -> bool:
	return kind(id).begins_with("round_tower")

static func compatible(a: StringName, b: StringName) -> bool:
	var ka := kind(a)
	var kb := kind(b)
	if ka == "gate" or kb == "gate": return (ka == "square_tower" or kb == "square_tower")
	if ka == "wall": return kb == "wall" or kb == "square_tower" or is_round(b)
	if kb == "wall": return ka == "square_tower" or is_round(a)
	return false

static func reach(id: StringName) -> float:
	if kind(id) in ["wall","gate"]: return WALL_HALF
	if is_round(id): return ROUND_JOIN
	return SQUARE_JOIN

static func port_direction(site: Node3D, port: int) -> Vector2:
	return DIRECTIONS[port].rotated(-site.yaw)

static func availability(site: Node3D, port: int, direction: Vector2, child_id: StringName) -> String:
	if not compatible(site.building_id,child_id): return "К воротам подходят только квадратные башни"
	var wall_count := 0
	var gate_count := 0
	for link in site.connections:
		if kind(link.site.building_id) == "wall": wall_count += 1
		if kind(link.site.building_id) == "gate": gate_count += 1
		if is_round(site.building_id):
			if absf(link.direction.angle_to(direction)) < deg_to_rad(65): return "Слишком близко к соседней стене"
		elif link.port == port: return "Это соединение уже занято"
	if kind(site.building_id) == "square_tower":
		if kind(child_id) == "wall" and wall_count >= 3: return "У квадратной башни максимум три стены"
		if kind(child_id) == "gate" and gate_count >= 1: return "У башни уже есть ворота"
	return ""

static func candidate(site: Node3D, port: int, direction: Vector2, child_id: StringName) -> Dictionary:
	if not compatible(site.building_id,child_id): return {}
	var yaw := -direction.angle()
	# Socket direction is not facade direction. Keep both gate towers facing
	# the same way, and propagate the outside face along a straight wall.
	if kind(child_id) == "square_tower" or is_round(child_id):
		yaw = site.yaw
	elif absf(direction.dot(Vector2.RIGHT.rotated(-site.yaw)))>.999:
		yaw = site.yaw
	elif is_round(site.building_id) and absf(angle_difference(site.yaw,yaw))>PI*.5:
		yaw += PI
	var target_port := 1 if direction.dot(Vector2.RIGHT.rotated(-yaw))>0 else 0
	var center := Vector2(site.position.x,site.position.z)+direction*(reach(site.building_id)+reach(child_id))
	return {"site":site,"port":port,"target_port":-1 if is_round(child_id) else target_port,
		"direction":direction,"center":center,"yaw":yaw,
		"error":availability(site,port,direction,child_id)}

static func nearest(sites: Array[Node3D], child_id: StringName, point: Vector2) -> Dictionary:
	var result := {}
	var best := 3.2*3.2
	for site in sites:
		if not compatible(site.building_id,child_id): continue
		var count := 4 if kind(site.building_id) == "square_tower" else 2
		if is_round(site.building_id): count = 1
		for port in count:
			var direction := port_direction(site,port)
			if is_round(site.building_id):
				direction = (point-Vector2(site.position.x,site.position.z)).normalized()
				if direction.length_squared() < .5: continue
				# Mouse and keyboard share a fixed angular grid around the tower.
				direction = Vector2.RIGHT.rotated(snappedf(direction.angle(),ORBIT_STEP))
			var item := candidate(site,-1 if is_round(site.building_id) else port,direction,child_id)
			var distance: float = point.distance_squared_to(item.center)
			if distance < best:
				best = distance
				result = item
	return result

static func register(site: Node3D, connection: Dictionary) -> void:
	if connection.is_empty(): return
	var parent: Node3D = connection.site
	parent.connections.append({"site":site,"port":connection.port,"direction":connection.direction})
	site.connections.append({"site":parent,"port":connection.target_port,"direction":-connection.direction})

static func collision_allowed(other: Node3D, connection: Dictionary, shape: PackedVector2Array) -> bool:
	if connection.is_empty(): return false
	if other == connection.site: return true # Exact socket pose, never arbitrary overlap.
	# At a tower junction, foundations can overlap only INSIDE that same tower.
	var parent: Node3D = connection.site
	if kind(parent.building_id) in ["wall","gate"]: return false
	var neighbor := false
	for link in parent.connections:
		if link.site == other: neighbor = true
	if not neighbor: return false
	for intersection in Geometry2D.intersect_polygons(shape,other.shape):
		for p in intersection:
			if not Geometry2D.is_point_in_polygon(p,parent.shape): return false
	return true
