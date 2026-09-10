extends Node3D
const MEMORY_DARKNESS := 0.65
## Flat screen-space darkness. No cloud mesh and no toggling trees on discovery.
var world: Node3D
var state = preload("res://scripts/world/visibility_mask.gd").new()
var overlay: MeshInstance3D
var material: ShaderMaterial
var objects: Node3D
var last_sources: Array = []

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/map_visibility.gdshader")
	material.render_priority = 127
	material.set_shader_parameter("memory_darkness",MEMORY_DARKNESS)
	overlay = MeshInstance3D.new()
	overlay.name = "MapDarkness"
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	overlay.mesh = quad
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.layers = 2
	overlay.extra_cull_margin = 16384
	world.game_camera.add_child(overlay)
	overlay.position.z = -1
	objects = preload("res://scripts/world/visibility_objects.gd").new()
	objects.vision = self
	add_child(objects)

func sources() -> Array:
	var groups := {}
	for unit in world.player_units:
		if not is_instance_valid(unit): continue
		var key: String = "unit:%d" % unit.get_instance_id() if unit.individual_control or unit.squad_id <= 0 else "squad:%d" % unit.squad_id
		if not groups.has(key): groups[key] = {"position": Vector3.ZERO,"count": 0}
		groups[key].position += unit.global_position
		groups[key].count += 1
	var result: Array = []
	for group in groups.values(): result.append({"position":group.position/group.count,"radius":12.0,"feather":3.0})
	return result

func reset_world() -> void:
	objects.reset()
	state.configure(world.map_renderer.get_half_extent())
	last_sources = sources()
	state.update(last_sources,true)
	material.set_shader_parameter("world_size",state.extent*2)
	material.set_shader_parameter("sight_mask",state.texture)
	material.set_shader_parameter("previous_mask",state.previous)
	_sync_visuals()
	objects.refresh()
	if world.hud != null: world.hud.minimap.bind_visibility()

func refresh_sight(immediate: bool = false) -> void:
	last_sources = sources()
	state.update(last_sources,immediate)
	objects.refresh()
	_sync_visuals()

func can_observe(node: Node3D) -> bool:
	if node.is_in_group("vision_dynamic") or node.is_in_group("vision_static"):
		return state.is_visible(node.global_position) and node.is_visible_in_tree()
	return true

func _sync_visuals() -> void:
	material.set_shader_parameter("mask_blend",state.blend)
	if world.hud != null:
		world.hud.minimap.terrain_material.set_shader_parameter("mask_blend",state.blend)

func _process(delta: float) -> void:
	if state.texture == null: return
	state.advance(delta)
	if state.blend >= 1.0 and sources() != last_sources: refresh_sight()
	objects.refresh()
	_sync_visuals()
