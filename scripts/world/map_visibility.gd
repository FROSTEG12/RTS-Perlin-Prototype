extends Node3D
signal enabled_changed(value: bool)
const MEMORY_DARKNESS := 0.65
const RANGE := preload("res://scripts/world/vision_range.gd")
## Flat screen-space darkness. No cloud mesh and no toggling trees on discovery.
var world: Node3D
var state = preload("res://scripts/world/visibility_mask.gd").new()
var overlay: MeshInstance3D
var material: ShaderMaterial
var objects: Node3D
var last_sources: Array = []
var edge_clock := 0.0
var enabled := true

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	_sync_visuals()
	objects.refresh()
	if world.hud != null: world.hud.minimap.queue_redraw()
	enabled_changed.emit(enabled)

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
	for group in groups.values(): result.append({"position":group.position/group.count,"radius":RANGE.radius(world.current_time),"feather":RANGE.FEATHER})
	return result

func reset_world() -> void:
	edge_clock = 0.0
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
		return (not enabled or state.is_visible(node.global_position)) and node.is_visible_in_tree()
	return true

func _sync_visuals() -> void:
	overlay.visible = enabled
	material.set_shader_parameter("mask_blend",state.blend)
	material.set_shader_parameter("edge_time",edge_clock)
	if world.hud != null:
		world.hud.minimap.terrain_material.set_shader_parameter("visibility_enabled",enabled)
		world.hud.minimap.terrain_material.set_shader_parameter("mask_blend",state.blend)

func _process(delta: float) -> void:
	if state.texture == null: return
	edge_clock += delta
	state.advance(delta)
	if state.blend >= 1.0 and sources() != last_sources: refresh_sight()
	objects.refresh()
	_sync_visuals()
