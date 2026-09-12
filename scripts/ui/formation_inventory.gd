extends "res://scripts/ui/floating_panel.gd"
## Independent, non-modal inventory. Only its close button hides it.
var library: RefCounted
var list_rows: GridContainer
var message: Label
const COLUMNS := 5
const VISIBLE_CELLS := 15
const WINDOW_SIZE := Vector2(500,360)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	size = WINDOW_SIZE
	add_theme_stylebox_override("panel",WINDOW_STYLE.window(14))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	add_child(rows)
	var title := Label.new()
	title.text = "ИНВЕНТАРЬ НАВЫКОВ"
	title.add_theme_font_size_override("font_size",17)
	setup_header(title,rows,hide)
	close_button.tooltip_text = ""
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	WINDOW_STYLE.scrollbar(scroll.get_v_scroll_bar())
	list_rows = GridContainer.new()
	list_rows.columns = COLUMNS
	list_rows.add_theme_constant_override("h_separation",6)
	list_rows.add_theme_constant_override("v_separation",6)
	scroll.add_child(list_rows)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size",12)
	message.add_theme_color_override("font_color",Color("#edb0aa"))
	message.hide() # Only real errors, never instructional/status copy.
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
		list_rows.add_child(item)
	var capacity := maxi(VISIBLE_CELLS,ceili(float(library.templates.size())/COLUMNS)*COLUMNS)
	for i in range(library.templates.size(),capacity):
		var empty := preload("res://scripts/ui/formation_list_button.gd").new()
		list_rows.add_child(empty)
	if library.load_error: show_error("Файл навыков повреждён: запись заблокирована.")
	if positioned: clamp_to_screen.call_deferred()

func show_error(value: String) -> void:
	message.text = value
	message.visible = not value.is_empty()

func clamp_to_screen() -> void:
	size = WINDOW_SIZE
	super.clamp_to_screen()

func open() -> void:
	if not world.formation_features_enabled: return
	if not positioned:
		position = Vector2(maxf(10,world.hud.skill_slots.position.x),world.hud.skill_slots.position.y-size.y-12)
		positioned = true
	clamp_to_screen()
	show()
	bring_forward()
