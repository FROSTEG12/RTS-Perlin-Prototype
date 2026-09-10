extends Node3D
## Exploration mask + softly displaced cloud surface, separate from weather.
const STATE := preload("res://scripts/world/fog_of_war_state.gd")
const SIGHT_RADIUS := 12.0
var world: Node3D
var state = STATE.new()
var cloud: MeshInstance3D
var cloud_material: ShaderMaterial
var memory: MeshInstance3D
var batches: Array[Dictionary] = []
var refresh := 0.0
var last_sources: Array = []

func _ready() -> void:
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = preload("res://shaders/fog_of_war.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 73519
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	cloud_material.set_shader_parameter("cloud_noise", texture)
	cloud = MeshInstance3D.new()
	cloud.name = "ExplorationClouds"
	cloud.material_override = cloud_material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.layers = 2
	add_child(cloud)
	memory = MeshInstance3D.new()
	memory.name = "ExploredOutsideSight"
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	memory.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fog_of_war_memory.gdshader")
	material.render_priority = 105
	memory.material_override = material
	memory.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	memory.layers = 2
	memory.extra_cull_margin = 16384
	world.game_camera.add_child(memory)
	memory.position.z = -1.0

func reset_world() -> void:
	var extent: float = world.map_renderer.get_half_extent()
	state.configure(extent)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * extent * 2
	plane.subdivide_width = 255
	plane.subdivide_depth = 255
	cloud.mesh = plane
	cloud.custom_aabb = AABB(Vector3(-extent,-1,-extent), Vector3(extent*2,10,extent*2))
	for material in [cloud_material, memory.material_override]:
		material.set_shader_parameter("sight_mask", state.texture)
		material.set_shader_parameter("world_size", extent*2)
	batches.clear()
	for node in world.map_renderer.resource_root.get_children():
		if not node is MultiMeshInstance3D: continue
		var transforms: Array[Transform3D] = []
		for i in node.multimesh.instance_count: transforms.append(node.multimesh.get_instance_transform(i))
		batches.append({"node": node, "transforms": transforms, "revealed": {}})
	refresh = 0
	update_sight()
	if world.hud != null: world.hud.minimap.bind_fog()

func sources() -> Array:
	var groups := {}
	for unit in world.player_units:
		if not is_instance_valid(unit): continue
		var key: String = "unit:%d" % unit.get_instance_id() if unit.individual_control or unit.squad_id <= 0 else "squad:%d" % unit.squad_id
		if not groups.has(key): groups[key] = {"position": Vector3.ZERO, "count": 0}
		groups[key].position += unit.global_position
		groups[key].count += 1
	var result: Array = []
	for group in groups.values():
		result.append({"position": group.position / group.count, "radius": SIGHT_RADIUS, "feather": 4.0})
	return result

func update_sight(force: bool = true) -> void:
	var active_sources := sources()
	if force or active_sources != last_sources:
		state.update(active_sources)
		last_sources = active_sources
		_reveal_resources()
	# Opt-in hooks for future objects; dynamic objects can move while scouts stand still.
	for node in get_tree().get_nodes_in_group("fog_static"):
		if node is Node3D: node.visible = state.is_explored(node.global_position)
	for node in get_tree().get_nodes_in_group("fog_dynamic"):
		if node is Node3D: node.visible = state.is_visible(node.global_position)

func _reveal_resources() -> void:
	# Tall trees and their shadow batches must not protrude through unknown fog.
	for batch in batches:
		if not is_instance_valid(batch.node): continue
		for i in batch.transforms.size():
			if batch.revealed.get(i, false): continue
			var original: Transform3D = batch.transforms[i]
			var known: bool = state.is_explored(batch.node.to_global(original.origin))
			if batch.revealed.get(i) == known: continue
			batch.revealed[i] = known
			batch.node.multimesh.set_instance_transform(i, original if known else Transform3D(Basis.from_scale(Vector3.ZERO), original.origin))

func _process(delta: float) -> void:
	if state.texture == null: return
	refresh -= delta
	if refresh <= 0:
		refresh = 0.1
		update_sight(false)
	var daylight := smoothstep(5.5,8.0,world.current_time) * (1.0-smoothstep(17.0,20.5,world.current_time))
	cloud_material.set_shader_parameter("cloud_color", Color("#566578").lerp(Color("#a3b6bf"), daylight))
	cloud_material.set_shader_parameter("sun_direction", world.key_light.global_basis.z)
