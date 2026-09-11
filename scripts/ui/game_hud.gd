extends Control
## HUD presentation only. No economy, construction or combat simulation.
var world: Node3D
var top: PanelContainer
var buildings: Control
var armies: Control
var minimap: Control
var clock_label: Label
var day_label: Label
var weather_icon: Control
var resource_labels: Dictionary = {}
var refresh := 0.0
var dock: Control
var skill_slots: PanelContainer
var active_section := -1
var status_panel: PanelContainer
var formation_panel: PanelContainer
var formation_library = preload("res://scripts/units/formation_library.gd").new()
var formation_scrim: ColorRect
var daylight: Control
var navigation_buttons: Array[Button] = []
var menu_button: Button
const ICONS := ["wood", "stone", "metal", "meat", "berries", "coal"]
const TOP_PANEL = preload("res://scripts/ui/top_bar_panel.gd")
var resource_icons: Array[TextureRect] = []
var stacked_header := false
var layout_pending := false

func surface(radius: int = 12, accent: bool = false, padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1012e6")
	style.set_corner_radius_all(radius)
	style.border_color = Color("#d1aa6390") if accent else Color("#32404760")
	style.set_border_width_all(1)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color("#00000035")
	style.shadow_size = 5
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", Color("#f0f1ee"))
	result.set_color("font_color", "Button", Color("#f0f1ee"))
	result.set_color("font_disabled_color", "Button", Color("#707977"))
	for type in ["PanelContainer", "Button", "TabContainer"]:
		for state in (["panel"] if type != "Button" else ["normal", "hover", "pressed", "disabled"]):
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#0b1012e6")
			if type == "Button": style.bg_color = Color("#151b1d")
			if state == "hover": style.bg_color = Color("#232b2d")
			if state == "pressed": style.bg_color = Color("#23221df5")
			if state == "disabled": style.bg_color = Color("#151b1d80")
			style.border_color = Color("#71867a38")
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 5
			style.content_margin_bottom = 5
			result.set_stylebox(state, type, style)
	return result

func button(text: String, parent: Node, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.pressed.connect(action)
	parent.add_child(item)
	return item


func icon(file: String, parent: Node, tint: Color = Color.WHITE) -> void:
	var image := TextureRect.new()
	image.texture = load("res://assets/ui/resources/" + file + ".svg")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(26, 26)
	image.modulate = tint
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = make_theme()
	skill_slots = preload("res://scripts/ui/skill_slots_panel.gd").new()
	skill_slots.name = "SkillSlots"
	add_child(skill_slots)
	top = TOP_PANEL.new(true)
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	var index := 0
	for key in world.stockpile:
		var box := HBoxContainer.new()
		box.size_flags_horizontal = SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		box.tooltip_text = key
		row.add_child(box)
		var art := TextureRect.new()
		art.texture = load("res://assets/ui/generated_resources/" + ICONS[index] + ".png")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(34, 34)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(art)
		resource_icons.append(art)
		var amount := Label.new()
		amount.custom_minimum_size.x = 52
		amount.size_flags_horizontal = SIZE_EXPAND_FILL
		amount.add_theme_font_size_override("font_size", 18)
		amount.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(amount)
		resource_labels[key] = amount
		index += 1
		if index < world.stockpile.size(): _top_divider(row)
	status_panel = TOP_PANEL.new()
	status_panel.slant_left = true
	add_child(status_panel)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_panel.add_child(status_row)
	daylight = preload("res://scripts/ui/day_cycle_indicator.gd").new()
	status_row.add_child(daylight)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 17)
	status_row.add_child(clock_label)
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 17)
	day_label.size_flags_horizontal = SIZE_EXPAND_FILL
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_row.add_child(day_label)
	_top_divider(status_row)
	weather_icon = preload("res://scripts/ui/weather_indicator.gd").new()
	status_row.add_child(weather_icon)
	menu_button = button("", self, func(): world.pause_menu.set_open(true))
	menu_button.icon = preload("res://assets/ui/resources/menu.svg")
	menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button.expand_icon = true
	menu_button.add_theme_constant_override("icon_max_width", 26)
	for state in ["normal", "hover", "pressed"]:
		var menu_style := surface(18, false, 8)
		menu_style.bg_color = Color("#0a151de6") if state == "normal" else Color("#172731f0")
		menu_style.shadow_color = Color("#00000010")
		menu_style.set_border_width_all(0)
		menu_button.add_theme_stylebox_override(state, menu_style)
	menu_button.tooltip_text = "Меню · Esc"
	dock = preload("res://scripts/ui/command_dock.gd").new()
	dock.name = "CommandDock"
	add_child(dock)
	navigation_buttons = dock.buttons
	dock.section_requested.connect(_open_section)
	buildings = preload("res://scripts/ui/building_browser.gd").new()
	buildings.name = "BuildingBrowser"
	add_child(buildings)
	buildings.close_requested.connect(func(): _set_section(-1))
	buildings.hide()
	armies = preload("res://scripts/ui/army_browser.gd").new()
	armies.name = "ArmyBrowser"
	armies.world = world
	add_child(armies)
	armies.hide()
	formation_panel = preload("res://scripts/ui/formation_panel.gd").new()
	formation_panel.world = world
	formation_panel.library = formation_library
	add_child(formation_panel)
	formation_panel.hide()
	skill_slots.connect_library(formation_library)
	minimap = preload("res://scripts/ui/minimap.gd").new()
	minimap.world = world
	add_child(minimap)
	formation_scrim = ColorRect.new()
	formation_scrim.color = Color(0.01,0.02,0.03,0.5)
	formation_scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(formation_scrim)
	formation_scrim.hide()
	move_child(formation_panel,-1)
	_update()
	resized.connect(_schedule_layout)
	top.minimum_size_changed.connect(_schedule_layout)
	status_panel.minimum_size_changed.connect(_schedule_layout)
	buildings.minimum_size_changed.connect(_schedule_layout)
	_layout_hud()

func _schedule_layout() -> void:
	if layout_pending: return
	layout_pending = true
	_layout_hud.call_deferred()

func _place(control: Control, origin: Vector2, extent: Vector2) -> void:
	control.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	control.position = origin.round()
	control.size = extent.round()

func _layout_hud() -> void:
	layout_pending = false
	if minimap == null: return
	const EDGE := 10.0
	const GAP := 8.0
	const BAR := 52.0
	var resources_width := maxf(704.0, top.get_combined_minimum_size().x)
	var status_width := maxf(292.0, status_panel.get_combined_minimum_size().x)
	# Natural/capped widths: ultrawide monitors reveal more world, not empty HUD.
	stacked_header = size.x < resources_width + status_width + BAR + EDGE * 2 + GAP * 2
	var status_y := EDGE + BAR + GAP if stacked_header else EDGE
	_place(top, Vector2(0, EDGE), Vector2(resources_width, BAR))
	_place(menu_button, Vector2(size.x - EDGE - BAR, EDGE), Vector2(BAR, BAR))
	_place(status_panel, Vector2(size.x - EDGE - BAR - GAP - status_width, status_y), Vector2(status_width, BAR))
	var tools_y := status_y + BAR + GAP
	# Keep the minimap's approved independent size, not tied to the active tab.
	var details_width := 610.0 if size.x >= 1100 else 528.0 # Preserve approved minimap limits.
	var pixel_scale := maxf(get_viewport().get_stretch_transform().get_scale().x, 0.01)
	var map_side := clampf(size.y * 0.28, 220.0, 640.0 / pixel_scale)
	var horizontal_room := size.x - (110.0 + details_width) - EDGE - GAP
	var vertical_room := size.y - tools_y - EDGE - GAP
	map_side = floorf(minf(map_side, minf(horizontal_room, vertical_room)))
	_place(minimap, size - Vector2.ONE * (map_side + EDGE), Vector2.ONE * map_side)
	var dock_width := dock.get_combined_minimum_size().x
	_place(dock, Vector2((size.x - dock_width) * 0.5, size.y - 6 - 56), Vector2(dock_width, 56))
	var skill_gap := 64.0 if size.x >= 1100 else 24.0
	var skill_extent: Vector2 = skill_slots.fit_width(dock.position.x - skill_gap - EDGE)
	_place(skill_slots, Vector2(dock.position.x - skill_gap - skill_extent.x, size.y - 6 - skill_extent.y), skill_extent)
	# Panels grow upwards from one baseline. On narrow screens only the panel
	# shifts left to avoid the map; the three entry buttons stay screen-centred.
	var panel_bottom := minf(dock.position.y, skill_slots.position.y) - 6.0
	var panel_right := minimap.position.x - GAP
	var browser_width := minf(480.0, panel_right - EDGE)
	var browser_height := buildings.get_combined_minimum_size().y
	var browser_x := clampf((size.x - browser_width) * 0.5, EDGE, panel_right - browser_width)
	_place(buildings, Vector2(browser_x, panel_bottom - browser_height), Vector2(browser_width, browser_height))
	var army_width := minf(900.0, panel_right - EDGE)
	armies.compact = size.y < 650 or army_width < 800
	var army_height := 346.0 if armies.compact else 446.0
	var army_x := clampf((size.x - army_width) * 0.5, EDGE, panel_right - army_width)
	_place(armies, Vector2(army_x, panel_bottom - army_height), Vector2(army_width, army_height))
	armies._layout()
	var formation_width := minf(size.x-20,760.0) if formation_panel.editing else 500.0
	var formation_height := minf(size.y-100,520.0) if formation_panel.editing else 280.0
	formation_height = maxf(formation_height,formation_panel.get_combined_minimum_size().y)
	var formation_x := (size.x-formation_width)*0.5 if formation_panel.editing else clampf((size.x-formation_width)*0.5,EDGE,panel_right-formation_width)
	var formation_y := (size.y-formation_height)*0.5 if formation_panel.editing else panel_bottom-formation_height
	_place(formation_panel, Vector2(formation_x,formation_y), Vector2(formation_width,formation_height))
	minimap.queue_redraw()

func _top_divider(parent: Node) -> void:
	var divider := ColorRect.new()
	divider.color = Color("#83909345")
	divider.custom_minimum_size = Vector2(1, 26)
	divider.size_flags_vertical = SIZE_SHRINK_CENTER
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(divider)

func _section_panel(title: String) -> PanelContainer:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", surface(10, true))
	add_child(section)
	var rows := VBoxContainer.new()
	section.add_child(rows)
	var label := Label.new()
	label.text = title
	rows.add_child(label)
	section.hide()
	return section

func _open_section(index: int) -> void:
	_set_section(-1 if active_section == index else index)

func _set_section(index: int) -> void:
	if index != 2 and formation_panel.editing: formation_panel.close_editor()
	active_section = index
	buildings.visible = index == 0
	armies.visible = index == 1
	formation_panel.visible = index == 2
	dock.set_active(index)
	_schedule_layout()

func _process(delta: float) -> void:
	# Read every frame so the marker also moves smoothly at accelerated game time.
	daylight.set_hour(world.current_time)
	refresh -= delta
	if refresh <= 0:
		refresh = 0.1
		_update()

func _update() -> void:
	if armies.visible: armies._update_requirements()
	var minutes := int(world.current_time * 60.0)
	clock_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	day_label.text = "День %d" % world.current_day
	daylight.set_hour(world.current_time)
	weather_icon.set_weather(world.weather.climate.condition(), daylight.is_day(world.current_time))
	weather_icon.tooltip_text = world.weather.climate.description()
	for key in resource_labels:
		resource_labels[key].text = str(world.stockpile[key])
		resource_labels[key].tooltip_text = "%s: %s" % [key, world.stockpile[key]]

func contains(point: Vector2) -> bool:
	if formation_panel.editing: return true
	if dock.contains(point): return true
	if buildings.contains(point): return true
	if armies.contains(point): return true
	for panel in [top, status_panel, menu_button, formation_panel, minimap, skill_slots]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(point): return true
	return false
