extends "res://scripts/ui/floating_panel.gd"
## Independent, non-modal inventory. Only its close button hides it.
var library: RefCounted
var list_rows: GridContainer
var message: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	size = Vector2(520,380)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1720fa")
	style.border_color = Color("#718d9e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	for edge in ["left","right","top","bottom"]: style.set("content_margin_"+edge,12)
	add_theme_stylebox_override("panel",style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	add_child(rows)
	var title := Label.new()
	title.text = "ИНВЕНТАРЬ НАВЫКОВ"
	title.add_theme_font_size_override("font_size",17)
	setup_header(title,rows,hide)
	var help := Label.new()
	help.text = "Перетащи навык на Q / W / E / D / F / R"
	help.add_theme_font_size_override("font_size",12)
	rows.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	list_rows = GridContainer.new()
	list_rows.columns = 4
	list_rows.add_theme_constant_override("h_separation",10)
	list_rows.add_theme_constant_override("v_separation",10)
	scroll.add_child(list_rows)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 28
	message.add_theme_font_size_override("font_size",12)
	rows.add_child(message)
	library.changed.connect(refresh_list)
	refresh_list()
	hide()

func refresh_list() -> void:
	for child in list_rows.get_children():
		list_rows.remove_child(child)
		child.queue_free()
	var selection := ButtonGroup.new()
	for template in library.templates:
		var item := preload("res://scripts/ui/formation_list_button.gd").new()
		item.template = template
		item.button_group = selection
		item.edit_requested.connect(func(): world.hud.formation_panel.edit_template(template))
		item.pressed.connect(func(): message.text = template.name+" · ПКМ — изменить")
		list_rows.add_child(item)
	if library.load_error: message.text = "Файл навыков повреждён: запись заблокирована."

func open() -> void:
	if not positioned:
		position = Vector2(maxf(10,world.hud.skill_slots.position.x),world.hud.skill_slots.position.y-size.y-12)
		positioned = true
	clamp_to_screen()
	show()
	bring_forward()
