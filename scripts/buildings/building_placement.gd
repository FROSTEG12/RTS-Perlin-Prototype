extends Node3D
## One placement transaction: preview never mutates forest, navigation or resources.
const DEFINITIONS := {
	&"sawmill": {"title":"Лесопилка","size":Vector2i(7,7),"clear_forest":true,"model":"sawmill"},
	&"house": {"title":"Жилой дом","size":Vector2i(4,5),"clear_forest":true,"model":"house"},
	&"warehouse": {"title":"Склад","size":Vector2i(6,8),"clear_forest":true,"model":"warehouse"},
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
var arrow: Label3D
var status: Label
var hint_panel: PanelContainer
var preview_model: Node3D
var projection_material: ShaderMaterial
const MODEL = preload("res://scripts/buildings/building_model.gd")
const GEO = preload("res://scripts/buildings/building_geometry.gd")
const JOINTS = preload("res://scripts/buildings/fortress_connections.gd")
var connection := {}
var orbit_locked := false
var orbit_pointer := Vector2.ZERO

func _ready() -> void:
	preview = Node3D.new()
	add_child(preview)
	grid = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20,20)
	grid.mesh = plane
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_material = ShaderMaterial.new()
	grid_material.render_priority = 1
	grid_material.shader = preload("res://shaders/building_grid.gdshader")
	grid.material_override = grid_material
	preview.add_child(grid)
	arrow = Label3D.new()
	arrow.text = "↑"
	arrow.font_size = 100
	arrow.pixel_size = .015
	arrow.rotation.x = -PI/2
	arrow.position.y = .7
	arrow.no_depth_test = true
	arrow.render_priority = 3
	preview.add_child(arrow)
	var hints := CanvasLayer.new()
	add_child(hints)
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.position = Vector2(16,132)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1720ed")
	style.border_color = Color("#405460")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	hint_panel.add_theme_stylebox_override("panel",style)
	hints.add_child(hint_panel)
	status = Label.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size",14)
	hint_panel.add_child(status)
	hint_panel.hide()
	preview.hide()

func begin(id: StringName) -> void:
	cancel()
	if not DEFINITIONS.has(id): return
	building_id = id
	quarter_turn = 0
	active = true
	var definition: Dictionary = DEFINITIONS[id]
	preview_model = MODEL.create(definition.model)
	preview.add_child(preview_model)
	projection_material = ShaderMaterial.new()
	projection_material.shader = preload("res://shaders/building_ghost.gdshader")
	projection_material.render_priority = 2
	for mesh in MODEL.meshes(preview_model):
		mesh.material_override = projection_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.hud.buildings.list_panel.hide()
	world.rts.cancel_drag()
	update_pointer(get_viewport().get_mouse_position())

func cancel() -> void:
	if active and world.hud.buildings.active_category >= 0:
		world.hud.buildings.list_panel.show()
	active = false
	connection.clear()
	orbit_locked = false
	if is_instance_valid(preview_model): preview_model.free()
	preview_model = null
	projection_material = null
	if preview != null: preview.hide()
	if hint_panel != null: hint_panel.hide()

func dimensions() -> Vector2i:
	var value: Vector2i = DEFINITIONS[building_id].size
	return Vector2i(value.y,value.x) if quarter_turn%2 else value

func cells_at(origin: Vector2i) -> Array[Vector2i]:
	return GEO.cells(shape_at(origin),world.map_renderer)

func pose_at(origin: Vector2i) -> Dictionary:
	if origin == origin_cell and not connection.is_empty(): return connection
	var point: Vector3 = world.map_renderer.cell_to_world(origin.x,origin.y)
	return {"center":Vector2(point.x,point.z)+(Vector2(dimensions())-Vector2.ONE)*.5,"yaw":quarter_turn*PI/2.0}

func shape_at(origin: Vector2i) -> PackedVector2Array:
	var pose := pose_at(origin)
	return GEO.polygon(pose.center,Vector2(DEFINITIONS[building_id].size),pose.yaw,JOINTS.is_round(building_id))

func bounds_at(origin: Vector2i) -> Rect2:
	return GEO.bounds(shape_at(origin))

func snap(point: Vector3) -> Vector2i:
	var size := dimensions()
	return world.map_renderer.world_to_cell(point-Vector3((size.x-1)*.5,0,(size.y-1)*.5))

func set_pointer_ground(point: Vector3) -> void:
	origin_cell = snap(point)
	connection = JOINTS.nearest(sites,building_id,Vector2(point.x,point.z)) if str(building_id).begins_with("fortress_") else {}

func rotate_step(direction: int) -> void:
	if not active: return
	if not connection.is_empty():
		if JOINTS.is_round(connection.site.building_id) and JOINTS.kind(building_id) == "wall":
			var next_yaw: float = connection.yaw+direction*JOINTS.ORBIT_STEP
			var target_port: int = connection.target_port
			connection = JOINTS.candidate(connection.site,-1,connection.direction.rotated(-direction*JOINTS.ORBIT_STEP),building_id)
			connection.yaw = next_yaw
			connection.target_port = target_port
			orbit_locked = true
			orbit_pointer = get_viewport().get_mouse_position()
		# Fixed sockets stay aligned; a wall cannot turn at another wall/gate.
		refresh_preview()
		return
	var center := bounds_at(origin_cell).get_center()
	quarter_turn = posmod(quarter_turn+direction,4)
	origin_cell = snap(Vector3(center.x,0,center.y))
	refresh_preview()

func validate(origin: Vector2i) -> String:
	if building_id==&"warehouse" and not sites.any(func(site): return site.building_id==&"sawmill" and site.stage==&"completed"): return "Сначала постройте лесопилку"
	if building_id in [&"warehouse",&"sawmill"] and (world.stockpile["Дерево"]<30 or world.stockpile["Камень"]<30): return "Нужно 30 дерева и 30 камня"
	if not active: return "Выберите лесопилку"
	var renderer = world.map_renderer
	var area := bounds_at(origin)
	var shape := shape_at(origin)
	var joint: Dictionary = connection if origin == origin_cell else {}
	if not joint.is_empty():
		JOINTS.complete_connections(joint,sites,building_id)
		var error: String = JOINTS.availability(joint.site,joint.port,joint.direction,building_id)
		if not error.is_empty(): return error
		for link in joint.secondary:
			if not link.error.is_empty(): return link.error
	for other in sites:
		if joint.is_empty() and area.grow(.8).intersects(GEO.bounds(other.shape)) and (JOINTS.kind(building_id) == "gate" or JOINTS.kind(other.building_id) == "gate") and not JOINTS.compatible(building_id,other.building_id) and str(building_id).begins_with("fortress_"):
			return "К воротам подходят только квадратные башни"
		if GEO.intersects(shape,other.shape):
			if not JOINTS.collision_allowed(other,joint,shape): return "Объекты пересекаются вне соединения"
		elif joint.is_empty() and str(building_id).begins_with("fortress_") and str(other.building_id).begins_with("fortress_") and area.grow(.8).intersects(GEO.bounds(other.shape)):
			return "Подведите модуль к совместимому соединению"
	var footprint := cells_at(origin)
	if not GEO.supported_by_land(shape,renderer): return "Фундамент выходит в воду"
	for cell in footprint:
		if not world.pathfinder.astar_grid.is_in_boundsv(cell): return "Нужна суша в пределах карты"
		# Shared raster cells at joints are legal; true model overlaps were checked above.
		if renderer.is_land(cell) and world.pathfinder.astar_grid.is_point_solid(cell) and not occupied.has(cell): return "Место занято"
		var point: Vector3 = renderer.cell_to_world(cell.x,cell.y)
		if world.vision.enabled and not world.vision.state.is_visible(point): return "Нужен обзор всей площадки"
	# Never trap a soldier or cut through an already accepted/queued route.
	var expanded := Geometry2D.offset_polygon(shape,.3)
	for unit in world.player_units:
		if not expanded.is_empty() and Geometry2D.is_point_in_polygon(Vector2(unit.global_position.x,unit.global_position.z),expanded[0]): return "На площадке бойцы"
		for cell in unit.target_cells:
			if cell in footprint: return "Через площадку проходит отряд"
	return ""

func update_pointer(point: Vector2) -> void:
	if not active: return
	preview.visible = not world.rts.over_ui(point) and not world.is_generating and not world.developer_tools.visible and not world.game_camera.dragging
	hint_panel.visible = preview.visible
	if not preview.visible: return
	var ground: Vector3 = world.game_camera.screen_to_ground(point)
	if not ground.is_finite(): preview.hide(); hint_panel.hide(); return
	if not orbit_locked or point.distance_to(orbit_pointer)>4:
		orbit_locked = false
		set_pointer_ground(ground)
	refresh_preview()

func refresh_preview() -> void:
	last_error = validate(origin_cell)
	var pose := pose_at(origin_cell)
	var center: Vector2 = pose.center
	preview.position = Vector3(center.x,.02,center.y)
	var tint := Color("#8cdaef") if last_error.is_empty() else Color("#ee7971")
	grid_material.set_shader_parameter("tint",tint)
	if projection_material: projection_material.set_shader_parameter("tint",tint)
	grid_material.set_shader_parameter("footprint",Vector2(DEFINITIONS[building_id].size))
	grid_material.set_shader_parameter("circular",JOINTS.is_round(building_id))
	grid.rotation.y = pose.yaw
	grid_material.set_shader_parameter("map_min",Vector2.ONE*(-world.map_renderer.get_half_extent()))
	if is_instance_valid(preview_model): preview_model.rotation.y = pose.yaw
	# The arrow follows the door/banner side, normalized to local +Z in MODEL.
	arrow.basis = Basis(Vector3.UP,pose.yaw)*Basis(Vector3.RIGHT,-PI/2)*Basis(Vector3.BACK,PI)
	arrow.position = Vector3(0,.10,DEFINITIONS[building_id].size.y*.5+.8).rotated(Vector3.UP,pose.yaw)
	arrow.modulate = tint
	status.add_theme_color_override("font_color",tint)
	status.text = DEFINITIONS[building_id].title+" · %d × %d м"%[dimensions().x,dimensions().y]+"\n"+("Q / E — поворот · " if connection.is_empty() else "")+"ЛКМ — поставить\nShift + ЛКМ — ещё · ПКМ / Esc — отмена"
	if str(building_id).begins_with("fortress_"):
		if connection.is_empty(): status.text += "\nАвтоматическое соединение рядом с модулями"
		else:
			status.text += "\nСоединение: "+DEFINITIONS[connection.site.building_id].title
			if JOINTS.is_round(connection.site.building_id): status.text += "\nМышь и Q/E — шаг по кругу 15°"
			else: status.text += "\nНаправление закреплено точкой соединения"
	if not last_error.is_empty(): status.text += "\n"+last_error
	elif building_id in [&"sawmill",&"warehouse"]: status.text += "\nСтоимость: 30 дерева · 30 камня"

func commit(repeat: bool = false) -> bool:
	last_error = validate(origin_cell)
	if not last_error.is_empty(): refresh_preview(); return false
	if building_id in [&"warehouse",&"sawmill"]:
		world.stockpile["Дерево"]-=30
		world.stockpile["Камень"]-=30
	var area := bounds_at(origin_cell)
	var pose := pose_at(origin_cell)
	var shape := shape_at(origin_cell)
	var site = preload("res://scripts/buildings/building_site.gd").new()
	site.building_id = building_id
	site.origin_cell = origin_cell
	site.quarter_turn = quarter_turn
	site.footprint = DEFINITIONS[building_id].size
	site.model_name = DEFINITIONS[building_id].model
	site.yaw = pose.yaw
	site.shape = shape
	if building_id in [&"sawmill",&"warehouse",&"house"]: site.construction_stage=1
	add_child(site)
	site.position = Vector3(pose.center.x,.02,pose.center.y)
	sites.append(site)
	JOINTS.register(site,connection)
	for cell in cells_at(origin_cell):
		if not occupied.has(cell): occupied[cell] = []
		occupied[cell].append(site)
		# Keep the entire footprint reserved for building, but leave the arch
		# walkable. Never clear terrain or another module's navigation obstacle.
		if site.blocks_navigation(world.map_renderer.cell_to_world(cell.x,cell.y)):
			world.pathfinder.astar_grid.set_point_solid(cell,true)
	if DEFINITIONS[building_id].clear_forest:
		world.map_renderer.TREE_RESOURCES.clear_area(world.map_renderer,area,shape)
		world.hud.minimap.refresh_forest(area.grow(2.0))
	world.hud.minimap.set_landmark(site.get_instance_id(),site.global_position,"building",world.local_team_id,[world.local_team_id])
	world.rts.grid_overlay.refresh()
	world.weather.refresh_world(world.map_renderer.get_half_extent())
	if site.stage!=&"completed":
		var builders: Array = world.rts.selected.duplicate()
		if builders.is_empty(): builders=[world.lead_unit]
		world.rts.orders.gathering.start_build(builders,site)
	if repeat: refresh_preview()
	else: cancel()
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
					# A click confirms the keyboard-selected orbit pose; only pointer
					# movement unlocks it. Don't re-aim it at the last instant.
					if not orbit_locked: update_pointer(event.position)
					if preview.visible: commit(event.shift_pressed)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		update_pointer(event.position)
