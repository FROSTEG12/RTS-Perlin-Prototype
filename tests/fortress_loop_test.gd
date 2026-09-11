extends SceneTree
const J = preload("res://scripts/buildings/fortress_connections.gd")
const S = preload("res://scripts/buildings/building_site.gd")
const G = preload("res://scripts/buildings/building_geometry.gd")
var sites: Array[Node3D] = []
func piece(id: StringName,p: Vector2) -> Node3D:
	var s = S.new()
	s.building_id=id
	s.position=Vector3(p.x,0,p.y)
	s.shape=G.polygon(p,Vector2(3,3),0)
	sites.append(s)
	return s
func _initialize() -> void:
	var length := 2*(J.SQUARE_JOIN+J.WALL_HALF)
	var a := piece(&"fortress_square_tower",Vector2.ZERO)
	var b := piece(&"fortress_square_tower",Vector2(length,0))
	var c := piece(&"fortress_square_tower",Vector2(length,length))
	var d := piece(&"fortress_square_tower",Vector2(0,length))
	for edge in [[a,0,b],[b,2,c],[c,1,d],[d,3,a]]:
		var link := J.candidate(edge[0],edge[1],J.port_direction(edge[0],edge[1]),&"fortress_wall")
		J.complete_connections(link,sites,&"fortress_wall")
		assert(link.secondary.size()==1 and link.secondary[0].site==edge[2])
		assert(link.secondary[0].error.is_empty())
		var wall_shape := G.polygon(link.center,Vector2(6,2),link.yaw)
		for other in sites:
			assert(not G.intersects(wall_shape,other.shape) or J.collision_allowed(other,link,wall_shape))
		var wall := piece(&"fortress_wall",link.center)
		wall.yaw=link.yaw
		wall.shape=wall_shape
		J.register(wall,link)
		assert(wall.connections.size()==2)
		assert(wall.connections[0].port!=wall.connections[1].port)
	for tower in [a,b,c,d]: assert(tower.connections.size()==2)
	var duplicate := J.candidate(a,0,Vector2.RIGHT,&"fortress_wall")
	J.complete_connections(duplicate,sites,&"fortress_wall")
	assert(not duplicate.error.is_empty() and not duplicate.secondary[0].error.is_empty())
	# Near a second tower is not enough: do not permit a gap or arbitrary overlap.
	b.position.x+=.2
	J.complete_connections(duplicate,sites,&"fortress_wall")
	assert(duplicate.secondary.is_empty())
	for s in sites: s.free()
	print("FORTRESS_LOOP_PASS four_sides reciprocal_both_ends occupied_rejected mismatch_rejected")
	quit()
