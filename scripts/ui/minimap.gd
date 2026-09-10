extends Control
## Cached terrain, live friendly markers. Enemy contacts must be supplied by vision.
var world: Node3D
var terrain: ImageTexture
var cached_seed := -1
var refresh := 0.0
var dragging := false
var enemy_contacts: Dictionary = {}
var landmarks: Dictionary = {}
var resource_regions: Array[Dictionary] = []
var terrain_layer: Control
var terrain_material: ShaderMaterial
const SYMBOLS := preload("res://scripts/ui/minimap_symbols.gd")
const TEAM_COLORS := {0: Color("#397fff"), 1: Color("#ef4d42")}
const FRIENDLY_POINT_RADIUS := 5.5

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tooltip_text = "ЛКМ / перетаскивание: переместить камеру\nСиняя точка — союзный отряд · Красные — замеченные враги\nКрепость — постройки · Башня — обзор\nБелый контур — текущая область камеры"
	terrain_layer = Control.new()
	terrain_layer.mouse_filter = MOUSE_FILTER_IGNORE
	terrain_layer.show_behind_parent = true
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://shaders/minimap_terrain.gdshader")
	terrain_layer.material = terrain_material
	add_child(terrain_layer)
	terrain_layer.draw.connect(_draw_terrain)
	resized.connect(func(): terrain_layer.queue_redraw())
	rebuild()

func rebuild() -> void:
	var renderer: MapRenderer3D = world.map_renderer
	if renderer.map_size == 0: return
	var map: Image = preload("res://scripts/ui/minimap_terrain.gd").build(renderer, world.world_seed)
	terrain = ImageTexture.create_from_image(map)
	_cache_resource_regions()
	terrain_material.set_shader_parameter("wear_texture", renderer.trail_wear.texture)
	bind_visibility()
	terrain_layer.queue_redraw()
	cached_seed = world.world_seed
	enemy_contacts.clear()
	landmarks.clear()
	queue_redraw()

func project(point: Vector3) -> Vector2:
	var extent: float = world.map_renderer.get_half_extent()
	var normalized := Vector2(point.x, point.z) / (extent * 2.0)
	var inner := size - Vector2(40, 40)
	return size * 0.5 + Vector2((normalized.x - normalized.y) * inner.x * 0.5, (normalized.x + normalized.y) * inner.y * 0.5)

func bind_visibility() -> void:
	if world.vision == null or world.vision.state.texture == null: return
	terrain_material.set_shader_parameter("sight_mask",world.vision.state.texture)
	terrain_material.set_shader_parameter("previous_mask",world.vision.state.previous)
	terrain_material.set_shader_parameter("mask_blend",world.vision.state.blend)
	terrain_material.set_shader_parameter("visibility_enabled",true)
	terrain_material.set_shader_parameter("memory_darkness",world.vision.MEMORY_DARKNESS)

func _cache_resource_regions() -> void:
	# One sign per nearby resource area, not a sea of overlapping deposit icons.
	var regions := {}
	for resource in world.map_renderer.resources:
		if resource.kind == "tree": continue
		var key := Vector2i(int(resource.x) / 16, int(resource.y) / 16)
		if not regions.has(key):
			regions[key] = {"position": Vector3.ZERO, "count": 0, "samples": []}
		var sample: Vector3 = world.map_renderer.cell_to_world(int(resource.x), int(resource.y))
		regions[key].position += sample
		regions[key].samples.append(sample)
		regions[key].count += 1
	resource_regions.clear()
	for region in regions.values():
		region.position /= region.count
		var center: Vector3 = region.position
		var nearest := INF
		for sample: Vector3 in region.samples:
			if sample.distance_squared_to(center) < nearest:
				nearest = sample.distance_squared_to(center)
				region.position = sample
		region.erase("samples")
		resource_regions.append(region)
	resource_regions.sort_custom(func(a: Dictionary, b: Dictionary): return a.count > b.count)

func visible_resource_markers() -> Array[Vector2]:
	# Resources stay in the world, but no deposit symbols are shown on the map.
	return []

func unproject(point: Vector2) -> Vector3:
	var offset := (point - size * 0.5) / ((size - Vector2(40, 40)) * 0.5)
	var extent: float = world.map_renderer.get_half_extent()
	return Vector3((offset.x + offset.y) * extent, 0, (offset.y - offset.x) * extent)

func diamond() -> PackedVector2Array:
	return PackedVector2Array([Vector2(size.x * 0.5, 20), Vector2(size.x - 20, size.y * 0.5), Vector2(size.x * 0.5, size.y - 20), Vector2(20, size.y * 0.5)])

func is_contact_visible(team: int, seen_by: Array, point: Vector3 = Vector3.INF) -> bool:
	if team == world.local_team_id: return true
	if world.local_team_id not in seen_by: return false
	return not point.is_finite() or world.vision == null or world.vision.state.is_visible(point)

func set_contact(id: int, point: Vector3, team: int, seen_by: Array) -> void:
	# No omniscient enemy enumeration: future vision owns these reports.
	enemy_contacts[id] = {"position": point, "team": team, "seen_by": seen_by.duplicate()}

func set_landmark(id: int, point: Vector3, kind: String, team: int = -1, seen_by: Array = []) -> void:
	# Registration hook for real structures/vision. Never invent map buildings.
	if kind not in ["building", "watchtower"]: return
	var remembered: Dictionary = landmarks.get(id,{}).get("remembered",{})
	landmarks[id] = {"position": point, "kind": kind, "team": team, "seen_by": seen_by.duplicate(),"remembered":remembered,"removed":false}
	refresh_landmarks()

func remove_landmark(id: int) -> void:
	if not landmarks.has(id): return
	landmarks[id].removed = true
	refresh_landmarks()

func refresh_landmarks() -> void:
	for id in landmarks.keys():
		var item: Dictionary = landmarks[id]
		if item.removed:
			if item.remembered.is_empty() or world.vision == null or world.vision.state.is_visible(item.remembered.position): landmarks.erase(id)
			continue
		var reported: bool = item.team == -1 or item.team == world.local_team_id or world.local_team_id in item.seen_by
		if reported and (world.vision == null or world.vision.state.is_visible(item.position)):
			item.remembered = {"position":item.position,"kind":item.kind,"team":item.team}

func visible_landmarks() -> Array:
	return landmarks.values().map(func(item): return item.remembered).filter(func(item): return not item.is_empty())

func marker_visible(point: Vector3) -> bool:
	if not point.is_finite(): return false
	var extent: float = world.map_renderer.get_half_extent()
	return absf(point.x) < extent and absf(point.z) < extent

func friendly_marker_positions() -> Array[Vector3]:
	var groups := {}
	for unit in world.player_units:
		if not is_instance_valid(unit): continue
		var key: String = "unit:%d" % unit.get_instance_id() if unit.individual_control or unit.squad_id <= 0 else "squad:%d" % unit.squad_id
		if not groups.has(key): groups[key] = {"sum": Vector3.ZERO, "count": 0}
		groups[key].sum += unit.global_position
		groups[key].count += 1
	var points: Array[Vector3] = []
	for group in groups.values(): points.append(group.sum / group.count)
	return points

func camera_footprint() -> Array[PackedVector2Array]:
	var viewport: Rect2 = world.game_camera.get_viewport().get_visible_rect()
	var footprint := PackedVector2Array()
	for corner in [viewport.position, Vector2(viewport.end.x, viewport.position.y), viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
		var ground: Vector3 = world.game_camera.screen_to_ground(corner)
		if not ground.is_finite(): return []
		footprint.append(project(ground))
	return Geometry2D.intersect_polygons(footprint, diamond())

func remove_contact(id: int) -> void:
	enemy_contacts.erase(id)

func _process(delta: float) -> void:
	if cached_seed != world.world_seed: rebuild()
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging = false
	refresh -= delta
	if refresh <= 0:
		refresh = 0.1
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed and Geometry2D.is_point_in_polygon(event.position, diamond())
		if dragging: world.game_camera.focus_on(unproject(event.position))
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if Geometry2D.is_point_in_polygon(event.position, diamond()):
			world.game_camera.focus_on(unproject(event.position))
		accept_event()

func _draw_terrain() -> void:
	if terrain == null: return
	terrain_layer.draw_polygon(diamond(), PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2(1,0), Vector2.ONE, Vector2(0,1)]), terrain)

func _draw() -> void:
	if terrain == null: return
	var frame := PackedVector2Array([Vector2(size.x * 0.5, 2), Vector2(size.x - 2, size.y * 0.5), Vector2(size.x * 0.5, size.y - 2), Vector2(2, size.y * 0.5)])
	var bounds := diamond()
	# Four frame strips leave the detailed terrain layer beneath unobscured.
	for i in 4:
		var j := (i + 1) % 4
		draw_colored_polygon(PackedVector2Array([frame[i], frame[j], bounds[j], bounds[i]]), Color("#0b131bf5"))
	var edge := frame.duplicate()
	edge.append(frame[0])
	draw_polyline(edge, Color("#02070be0"), 6, true)
	draw_polyline(edge, Color("#88969e"), 1.2, true)
	var outline := bounds.duplicate()
	outline.append(bounds[0])
	draw_polyline(outline, Color("#43525b"), 1, true)
	var font := ThemeDB.fallback_font
	var labels := ["N", "E", "S", "W"]
	for i in 4:
		var inward := (size * 0.5 - frame[i]).normalized()
		var point := frame[i] + inward * 11
		var left := Vector2(-inward.y, inward.x)
		draw_colored_polygon(PackedVector2Array([point-inward*5, point+inward*1+left*3, point+inward*1-left*3]), Color("#d0d9de"))
		var text_point := frame[i] + inward * 22
		draw_circle(text_point, 10, Color("#0b131bf5"), true, -1, true)
		draw_string(font, text_point + Vector2(-5,4), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ecf0f2"))
	var symbol_scale := clampf(size.x / 340.0, 0.65, 1.15)
	for landmark in visible_landmarks():
		if not marker_visible(landmark.position): continue
		var tint: Color = Color("#e4e8e6") if landmark.team == -1 else TEAM_COLORS.get(landmark.team, Color.WHITE)
		SYMBOLS.draw(self, project(landmark.position), landmark.kind, tint, symbol_scale)
	for contact in enemy_contacts.values():
		if not is_contact_visible(contact.team, contact.seen_by,contact.position) or not marker_visible(contact.position): continue
		SYMBOLS.draw(self, project(contact.position), "troop", TEAM_COLORS.get(contact.team, Color.WHITE), symbol_scale)
	for clipped in camera_footprint():
		clipped.append(clipped[0])
		draw_polyline(clipped, Color("#07101999"), 3, true)
		draw_polyline(clipped, Color("#ffffffed"), 1.3, true)
	# Troops have highest visual priority, even where the camera frame crosses.
	for point in friendly_marker_positions():
		if not marker_visible(point): continue
		var marker := project(point)
		draw_circle(marker, FRIENDLY_POINT_RADIUS + 2.5, Color("#08131ee6"), true, -1, true)
		draw_circle(marker, FRIENDLY_POINT_RADIUS + 1.3, Color("#edf5ff"), true, -1, true)
		draw_circle(marker, FRIENDLY_POINT_RADIUS, Color("#397fff"), true, -1, true)
