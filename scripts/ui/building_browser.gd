extends VBoxContainer
## Floating building tiles above a dark category strip. Selection is UI-only.
signal close_requested
signal building_selected(id: StringName)
var categories: Array = []
var category_buttons: Array[Button] = []
var building_buttons: Array[Button] = []
var active_category := -1
var active_building: StringName = &""
var category_bar: PanelContainer
var list_panel: PanelContainer
var category_row: HBoxContainer
var strip: HBoxContainer
var scroll: ScrollContainer
var empty_label: Label

# Match the blue-black surfaces of top_bar_panel.gd.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1720e6")
	style.set_content_margin_all(10)
	return style

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	list_panel = PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list_panel)
	var contents := VBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_panel.add_child(contents)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = preload("res://scripts/ui/building_card.gd").SLOT_HEIGHT
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contents.add_child(scroll)
	strip = HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 14)
	scroll.add_child(strip)
	empty_label = Label.new()
	empty_label.text = "В этой категории пока нет зданий"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.custom_minimum_size.y = 160
	contents.add_child(empty_label)
	category_bar = PanelContainer.new()
	var bar_style := panel_style()
	bar_style.bg_color = Color("#0c1720e6")
	bar_style.content_margin_top = 0
	bar_style.content_margin_bottom = 0
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(4)
	bar_style.border_color = Color("#40546045")
	category_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(category_bar)
	category_row = HBoxContainer.new()
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_theme_constant_override("separation", 12)
	category_bar.add_child(category_row)
	set_catalog(preload("res://scripts/ui/building_catalog.gd").categories())

func set_catalog(value: Array) -> void:
	categories = value.duplicate(true)
	active_category = -1
	active_building = &""
	if category_row == null: return
	for child in category_row.get_children():
		category_row.remove_child(child)
		child.queue_free()
	category_buttons.clear()
	for i in categories.size():
		var item := Button.new()
		item.custom_minimum_size = Vector2(56, 46)
		item.tooltip_text = str(categories[i].get("title", ""))
		item.icon = categories[i].get("icon")
		item.expand_icon = true
		item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_theme_constant_override("icon_max_width", 28)
		item.focus_mode = Control.FOCUS_NONE
		item.toggle_mode = true
		item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		item.add_theme_color_override("icon_normal_color", Color("#f0f1ee"))
		item.add_theme_color_override("icon_hover_color", Color.WHITE)
		item.add_theme_color_override("icon_pressed_color", Color("#82bfd6"))
		item.add_theme_color_override("icon_hover_pressed_color", Color("#b0e0f2"))
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT if state == "normal" else Color("#40546038")
			style.border_color = Color("#82bfd680") if state in ["pressed", "hover_pressed"] else Color.TRANSPARENT
			style.border_width_top = 1
			style.set_content_margin_all(4)
			item.add_theme_stylebox_override(state, style)
		item.pressed.connect(select_category.bind(i))
		category_buttons.append(item)
		category_row.add_child(item)
	clear_category()

func clear_category() -> void:
	building_selected.emit(&"")
	active_category = -1
	active_building = &""
	list_panel.hide()
	for item in category_buttons: item.set_pressed_no_signal(false)
	_clear_building_cards()

func _clear_building_cards() -> void:
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	building_buttons.clear()

func select_category(index: int) -> void:
	if index < 0 or index >= categories.size(): return
	building_selected.emit(&"")
	if active_category == index:
		clear_category()
		return
	active_category = index
	active_building = &""
	_clear_building_cards()
	for i in category_buttons.size(): category_buttons[i].set_pressed_no_signal(i == index)
	var category: Dictionary = categories[index]
	var items: Array = category.get("items", [])
	empty_label.visible = items.is_empty()
	scroll.visible = not items.is_empty()
	scroll.scroll_horizontal = 0
	for entry in items:
		var presentation: Dictionary = entry.duplicate()
		presentation["glyph"] = category.get("icon")
		var card := preload("res://scripts/ui/building_card.gd").new(presentation)
		card.pressed.connect(_select_building.bind(entry, card))
		strip.add_child(card)
		building_buttons.append(card)
	list_panel.show()

func _select_building(entry: Dictionary, card: Button) -> void:
	active_building = StringName(entry.get("id", ""))
	for item in building_buttons:
		item.set_pressed_no_signal(item == card)
		item.refresh_selection()
	building_selected.emit(active_building)

func contains(point: Vector2) -> bool:
	if category_bar.is_visible_in_tree() and category_bar.get_global_rect().has_point(point): return true
	for card in building_buttons:
		if card.is_visible_in_tree() and card.get_visual_rect().intersection(scroll.get_global_rect()).has_point(point): return true
	if scroll.is_visible_in_tree() and scroll.get_h_scroll_bar().visible and scroll.get_h_scroll_bar().get_global_rect().has_point(point): return true
	return false
