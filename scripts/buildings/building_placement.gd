extends Node3D
## One placement transaction: preview never mutates forest, navigation or resources.
const DEFINITIONS := {
	&"sawmill": {"title":"Лесопилка","size":Vector2i(4,6),"clear_forest":true},
	&"fortress_wall": {"title":"Секция стены","size":Vector2i(6,2),"clear_forest":true,"model":"wall"},
	&"fortress_gate": {"title":"Ворота","size":Vector2i(6,2),"clear_forest":true,"model":"gate"},
	&"fortress_round_tower": {"title":"Круглая башня","size":Vector2i(3,3),"clear_forest":true,"model":"round_tower"},
	&"fortress_round_tower_alt": {"title":"Круглая башня II","size":Vector2i(3,3),"clear_forest":true,"model":"round_tower_alt"},
	&"fortress_square_tower": {"title":"Квадратная башня","size":Vector2i(3,3),"clear_forest":true,"model":"square_tower"},
}
var world: Node3D
var active := false
var building_id: StringName = &""
var quarter_turn := 0
var origin_cell := Vector2i.ZERO
var occupied := {}
var sites: Array[Node3D] = []
var last_error := ""
var preview: Node3D
var grid: MeshInstance3D
var grid_material: ShaderMaterial
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var arrow: Label3D
var status: Label3D
var preview_model: Node3D

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	grid = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	grid.mesh = plane
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_material = ShaderMaterial.new()
	grid_material.shader = preload("res://shaders/building_grid.gdshader")
	grid.material_override = grid_material
	preview.add_child(grid)
	ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4,.65,6)
	ghost.mesh = box
	ghost.position.y = .325
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = ghost_material
	preview.add_child(ghost)
	arrow = Label3D.new()
	arrow.text = "↑"
	arrow.font_size = 100
	arrow.pixel_size = .015
	arrow.rotation.x = -PI/2
	arrow.position.y = .7
	preview.add_child(arrow)
	status = Label3D.new()
	status.font_size = 26
	status.pixel_size = .012
	status.position.y = 1.6
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	preview.add_child(status)
	preview.hide()

func begin(id: StringName) -> void:
	cancel()
	if not DEFINITIONS.has(id): return
	building_id = id
	quarter_turn = 0
	active = true
	var definition: Dictionary = DEFINITIONS[id]
	ghost.visible = not definition.has("model")
	status.position.y = 1.6
	if definition.has("model"):
		preview_model = load("res://assets/buildings/fortress/"+definition.model+".tscn").instantiate()
		preview.add_child(preview_model)
		preview_model.transparency = .4
		preview_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		status.position.y = preview_model.get_aabb().size.y+.6
	world.rts.cancel_drag()
	update_pointer(get_viewport().get_mouse_position())

func cancel() -> void:
	active = false
	if is_instance_valid(preview_model): preview_model.free()
	preview_model = null
	if preview != null: preview.hide()

func dimensions() -> Vector2i:
	var value: Vector2i = DEFINITIONS[building_id].size
	return Vector2i(value.y,value.x) if quarter_turn%2 else value

func cells_at(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := dimensions()
	for y in size.y:
		for x in size.x: result.append(origin+Vector2i(x,y))
	return result

func bounds_at(origin: Vector2i) -> Rect2:
	var point: Vector3 = world.map_renderer.cell_to_world(origin.x,origin.y)
	return Rect2(Vector2(point.x,point.z)-Vector2.ONE*.5,Vector2(dimensions()))

func snap(point: Vector3) -> Vector2i:
	var size := dimensions()
	return world.map_renderer.world_to_cell(point-Vector3((size.x-1)*.5,0,(size.y-1)*.5))

func rotate_step(direction: int) -> void:
	if not active: return
	var center := bounds_at(origin_cell).get_center()
	quarter_turn = posmod(quarter_turn+direction,4)
	origin_cell = snap(Vector3(center.x,0,center.y))
	refresh_preview()

func validate(origin: Vector2i) -> String:
	if not active: return "Выберите лесопилку"
	var renderer = world.map_renderer
	var area := bounds_at(origin)
	var footprint := cells_at(origin)
	for cell in footprint:
		if not renderer.is_land(cell): return "Нужна суша в пределах карты"
		if occupied.has(cell) or world.pathfinder.astar_grid.is_point_solid(cell): return "Место занято"
		var point: Vector3 = renderer.cell_to_world(cell.x,cell.y)
		if world.vision.enabled and not world.vision.state.is_visible(point): return "Нужен обзор всей площадки"
		# Logical land cells near a smoothed coastline can still contain water.
		for offset in [Vector2.ZERO,Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
			if renderer._ground_surface_y(point.x+offset.x,point.z+offset.y)<-.04: return "Слишком близко к воде"
	for resource in renderer.resources:
		if resource.kind == "tree": continue
		var point: Vector3 = renderer.cell_to_world(resource.x,resource.y)
		if area.has_point(Vector2(point.x,point.z)): return "На площадке есть ресурс"
	# Never trap a soldier or cut through an already accepted/queued route.
	for unit in world.player_units:
		if area.grow(.3).has_point(Vector2(unit.global_position.x,unit.global_position.z)): return "На площадке бойцы"
		for cell in unit.target_cells:
			if cell in footprint: return "Через площадку проходит отряд"
	return ""

func update_pointer(point: Vector2) -> void:
	if not active: return
	preview.visible = not world.rts.over_ui(point) and not world.is_generating and not world.developer_tools.visible and not world.game_camera.dragging
	if not preview.visible: return
	var ground: Vector3 = world.game_camera.screen_to_ground(point)
	if not ground.is_finite(): preview.hide(); return
	origin_cell = snap(ground)
	refresh_preview()

func refresh_preview() -> void:
	last_error = validate(origin_cell)
	var center := bounds_at(origin_cell).get_center()
	preview.position = Vector3(center.x,.045,center.y)
	var tint := Color("#8cdaef") if last_error.is_empty() else Color("#ee7971")
	grid_material.set_shader_parameter("tint",tint)
	grid_material.set_shader_parameter("footprint",Vector2(dimensions()))
	grid_material.set_shader_parameter("map_min",Vector2.ONE*(-world.map_renderer.get_half_extent()))
	ghost.rotation.y = quarter_turn*PI/2.0
	if is_instance_valid(preview_model): preview_model.rotation.y = ghost.rotation.y
	ghost_material.albedo_color = Color(tint,.13)
	arrow.rotation = Vector3(-PI/2,0,-quarter_turn*PI/2.0)
	arrow.modulate = tint
	status.modulate = tint
	status.text = DEFINITIONS[building_id].title+" · Q / E — поворот\n"+("ЛКМ — поставить · ПКМ / Esc — отмена" if last_error.is_empty() else last_error)

func commit() -> bool:
	last_error = validate(origin_cell)
	if not last_error.is_empty(): refresh_preview(); return false
	var area := bounds_at(origin_cell)
	var site = preload("res://scripts/buildings/building_site.gd").new()
	site.building_id = building_id
	site.origin_cell = origin_cell
	site.quarter_turn = quarter_turn
	site.footprint = DEFINITIONS[building_id].size
	site.model_name = DEFINITIONS[building_id].get("model","")
	add_child(site)
	site.position = Vector3(area.get_center().x,.02,area.get_center().y)
	sites.append(site)
	for cell in cells_at(origin_cell):
		occupied[cell] = site
		world.pathfinder.astar_grid.set_point_solid(cell,true)
	if DEFINITIONS[building_id].clear_forest:
		world.map_renderer.TREE_RESOURCES.clear_area(world.map_renderer,area)
		world.hud.minimap.refresh_forest(area)
	world.hud.minimap.set_landmark(site.get_instance_id(),site.global_position,"building",world.local_team_id,[world.local_team_id])
	world.rts.grid_overlay.refresh()
	world.weather.refresh_world(world.map_renderer.get_half_extent())
	cancel()
	return true

func reset_world() -> void:
	cancel()
	for cell in occupied:
		if world.pathfinder.astar_grid.is_in_boundsv(cell): world.pathfinder.astar_grid.set_point_solid(cell,not world.map_renderer.is_land(cell))
	occupied.clear()
	for site in sites:
		world.hud.minimap.landmarks.erase(site.get_instance_id())
		site.free()
	sites.clear()

func _process(_delta: float) -> void:
	if active: update_pointer(get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if not active or world.is_generating or world.developer_tools.visible or world.pause_menu.visible: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_Q,KEY_E]:
			if event.pressed and not event.echo: rotate_step(-1 if code == KEY_Q else 1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not world.rts.over_ui(event.position):
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT: cancel()
				elif not world.game_camera.dragging:
					update_pointer(event.position)
					if preview.visible: commit()
			get_viewport().set_input_as_handled()
