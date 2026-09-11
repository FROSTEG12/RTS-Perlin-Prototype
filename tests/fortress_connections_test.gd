extends SceneTree
const J = preload("res://scripts/buildings/fortress_connections.gd")
const G = preload("res://scripts/buildings/building_geometry.gd")
const S = preload("res://scripts/buildings/building_site.gd")
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var items: Array[Node3D] = []
var stage: Node3D
func _initialize() -> void: call_deferred("run")

func add_piece(id: StringName, center: Vector2, yaw: float = 0, link: Dictionary = {}) -> Node3D:
	var item = S.new()
	item.building_id=id
	item.model_name=J.kind(id)
	item.footprint=Vector2i(6,2) if J.kind(id) in ["wall","gate"] else Vector2i(3,3)
	item.position=Vector3(center.x,0,center.y)
	item.yaw=yaw
	item.shape=G.polygon(center,Vector2(item.footprint),yaw,J.is_round(id))
	stage.add_child(item)
	items.append(item)
	J.register(item,link)
	return item

func connect_to(parent: Node3D, port: int, id: StringName, direction: Vector2 = Vector2.ZERO) -> Node3D:
	if direction == Vector2.ZERO: direction=J.port_direction(parent,port)
	var link := J.candidate(parent,port,direction,id)
	assert(not link.is_empty() and link.error.is_empty(),str(link))
	var shape := G.polygon(link.center,Vector2(6,2) if J.kind(id) in ["wall","gate"] else Vector2(3,3),link.yaw,J.is_round(id))
	for other in items:
		assert(not G.intersects(shape,other.shape) or J.collision_allowed(other,link,shape),"Collision outside tower joint")
	return add_piece(id,link.center,link.yaw,link)

func run() -> void:
	stage=Node3D.new()
	root.add_child(stage)
	var gate_model := preload("res://scripts/buildings/building_model.gd").create("gate")
	stage.add_child(gate_model)
	var grate_surfaces := 0
	for mesh in preload("res://scripts/buildings/building_model.gd").meshes(gate_model):
		for surface in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_material(surface).resource_name != "lambert7SG": continue
			grate_surfaces+=1
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				assert((mesh.global_transform*vertex).z>0,"Gate front +Z must be the near portcullis side")
	assert(grate_surfaces>0)
	gate_model.free()
	for turn in 4:
		var rotated_gate = S.new()
		rotated_gate.building_id=&"fortress_gate"
		rotated_gate.yaw=turn*PI/2.0
		for port in 2:
			var socket := J.candidate(rotated_gate,port,J.port_direction(rotated_gate,port),&"fortress_square_tower")
			assert(socket.yaw==rotated_gate.yaw)
			assert(socket.target_port==1-port)
		rotated_gate.free()
	var gate := add_piece(&"fortress_gate",Vector2.ZERO)
	assert(not J.compatible(gate.building_id,&"fortress_wall"))
	assert(not J.compatible(gate.building_id,&"fortress_round_tower"))
	var right := connect_to(gate,0,&"fortress_square_tower")
	var left := connect_to(gate,1,&"fortress_square_tower")
	assert(is_equal_approx(right.yaw,gate.yaw) and is_equal_approx(left.yaw,gate.yaw),"Gate towers must show the same facade, doors and banners")
	assert(not J.availability(gate,0,Vector2.RIGHT,&"fortress_square_tower").is_empty())
	var right_wall := connect_to(right,0,&"fortress_wall")
	var left_wall := connect_to(left,1,&"fortress_wall")
	var round_right := connect_to(right_wall,0,&"fortress_round_tower")
	var round_left := connect_to(left_wall,1,&"fortress_round_tower_alt")
	for tower in [round_right,round_left]:
		var only_tower: Array[Node3D] = [tower]
		var center := Vector2(tower.position.x,tower.position.z)
		for degrees in range(-179,180,2):
			var point := center+Vector2.RIGHT.rotated(deg_to_rad(degrees))*(J.ROUND_JOIN+J.WALL_HALF)
			var snapped := J.nearest(only_tower,&"fortress_wall",point)
			assert(not snapped.is_empty())
			assert(absf(angle_difference(snapped.direction.angle(),snappedf(deg_to_rad(degrees),J.ORBIT_STEP)))<.0001)
			assert(is_equal_approx(center.distance_to(snapped.center),J.ROUND_JOIN+J.WALL_HALF))
	var turned := connect_to(round_right,-1,&"fortress_wall",Vector2.RIGHT.rotated(deg_to_rad(30)))
	connect_to(round_left,-1,&"fortress_wall",Vector2.LEFT.rotated(deg_to_rad(-20)))
	assert(absf(turned.yaw+deg_to_rad(30))<.001)
	assert(not J.availability(round_right,-1,Vector2.RIGHT.rotated(deg_to_rad(35)),&"fortress_wall").is_empty())
	# All three fixed wall sockets are usable; the fourth cannot become a fourth wall.
	var test_tower := add_piece(&"fortress_square_tower",Vector2(0,20))
	for port in [0,2,3]: connect_to(test_tower,port,&"fortress_wall")
	assert(J.availability(test_tower,1,Vector2.LEFT,&"fortress_wall").contains("три"))
	assert(J.availability(test_tower,1,Vector2.LEFT,&"fortress_gate").is_empty())
	# Fixed wall continuation cannot turn, even when the cursor is off-axis.
	var wall_link := J.candidate(turned,0,J.port_direction(turned,0),&"fortress_wall")
	assert(is_equal_approx(wall_link.yaw,turned.yaw))
	assert(is_equal_approx(Vector2(turned.position.x,turned.position.z).distance_to(wall_link.center),J.WALL_HALF*2))
	for item in items:
		for link in item.connections:
			assert(link.site.connections.any(func(back): return back.site==item))
	if DisplayServer.get_name() != "headless":
		root.size=Vector2i(1500,850)
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color("#263039")
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color("#cfdae0")
		environment.environment.ambient_light_energy=.65
		stage.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-45,-25,0)
		light.light_energy=1.1
		stage.add_child(light)
		var camera := Camera3D.new()
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=22
		stage.add_child(camera)
		camera.position=Vector3(16,15,28)
		camera.look_at(Vector3(0,2,0))
		for item in items:
			if item.position.z>10: item.hide()
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"fortress-connected.png")
		camera.size=14
		camera.position=round_right.position+Vector3(9,9,12)
		camera.look_at(round_right.position+Vector3(0,2,0))
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"fortress-round-joint.png")
	print("FORTRESS_CONNECTIONS_PASS compatibility occupied_ports square_three reciprocal_graph tower_overlap curved_wall straight_continuation")
	quit()
