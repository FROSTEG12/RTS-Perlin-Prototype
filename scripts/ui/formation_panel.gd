extends PanelContainer
const LIBRARY := preload("res://scripts/units/formation_library.gd")
var world: Node3D
var library: RefCounted
var editing := false
var draft_id := ""
var rows: VBoxContainer
var list_view: VBoxContainer
var list_rows: GridContainer
var editor_view: HBoxContainer
var canvas: Control
var name_input: LineEdit
var interval: HSlider
var interval_label: Label
var count_label: Label
var message: Label
var allowed: Array[CheckBox] = []
var save_button: Button
var heading: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1720f5")
	style.border_color = Color("#718d9e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	for edge in ["left","right","top","bottom"]: style.set("content_margin_"+edge,14)
	add_theme_stylebox_override("panel",style)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",8)
	add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	heading = title
	title.text = "ПОСТРОЕНИЯ"
	title.add_theme_font_size_override("font_size",18)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	make_button("Закрыть",header,func(): close_editor(); world.hud._set_section(-1))
	list_view = VBoxContainer.new()
	list_view.size_flags_vertical = SIZE_EXPAND_FILL
	rows.add_child(list_view)
	var help := Label.new()
	help.text = "Инвентарь навыков · перетащи построение на быстрый слот"
	help.add_theme_font_size_override("font_size",12)
	list_view.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_view.add_child(scroll)
	list_rows = GridContainer.new()
	list_rows.columns = 4
	list_rows.add_theme_constant_override("h_separation",10)
	list_rows.add_theme_constant_override("v_separation",10)
	list_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list_rows)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	list_view.add_child(footer)
	make_button("+ Создать построение",footer,func(): edit_template({}))
	editor_view = HBoxContainer.new()
	editor_view.add_theme_constant_override("separation",14)
	editor_view.size_flags_vertical = SIZE_EXPAND_FILL
	rows.add_child(editor_view)
	var drawing := VBoxContainer.new()
	drawing.size_flags_horizontal = SIZE_EXPAND_FILL
	editor_view.add_child(drawing)
	var front := Label.new()
	front.text = "НАПРАВЛЕНИЕ АТАКИ ↑"
	front.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drawing.add_child(front)
	canvas = preload("res://scripts/ui/formation_canvas.gd").new()
	canvas.size_flags_vertical = SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(240,230)
	drawing.add_child(canvas)
	canvas.changed.connect(update_count)
	count_label = Label.new()
	drawing.add_child(count_label)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 246
	controls.add_theme_constant_override("separation",8)
	editor_view.add_child(controls)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Название построения"
	name_input.max_length = 32
	controls.add_child(name_input)
	interval_label = Label.new()
	controls.add_child(interval_label)
	interval = HSlider.new()
	interval.min_value = 1
	interval.max_value = 3
	interval.step = 0.5
	interval.value = 1
	controls.add_child(interval)
	interval.value_changed.connect(func(value): interval_label.text = "Интервал между точками: %.1f м" % value)
	var label := Label.new()
	label.text = "Разрешено для:"
	controls.add_child(label)
	var types := GridContainer.new()
	types.columns = 2
	controls.add_child(types)
	for i in LIBRARY.TYPES.size():
		var check := CheckBox.new()
		check.text = LIBRARY.TYPE_NAMES[i]
		check.add_theme_font_size_override("font_size",12)
		types.add_child(check)
		allowed.append(check)
	var tools := HBoxContainer.new()
	controls.add_child(tools)
	make_button("Очистить",tools,func(): canvas.points.clear(); canvas.queue_redraw(); update_count())
	var symmetry := CheckButton.new()
	symmetry.text = "Симметрия"
	symmetry.tooltip_text = "Добавлять, удалять и перемещать зеркальные пары"
	symmetry.toggled.connect(func(value): canvas.mirrored = value)
	tools.add_child(symmetry)
	save_button = make_button("Сохранить",controls,save_draft)
	make_button("Отмена",controls,close_editor)
	var hint := Label.new()
	hint.text = "Клик — добавить / убрать\nПеретаскивание — переместить\nКрест — средний центр отряда"
	hint.add_theme_font_size_override("font_size",12)
	controls.add_child(hint)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size",12)
	message.custom_minimum_size.y = 30
	rows.add_child(message)
	library.changed.connect(refresh_list)
	editor_view.hide()
	refresh_list()

func make_button(text: String, parent: Node, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = FOCUS_NONE
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func refresh_list() -> void:
	for child in list_rows.get_children():
		list_rows.remove_child(child)
		child.queue_free()
	var selection := ButtonGroup.new()
	for template in library.templates:
		var item := preload("res://scripts/ui/formation_list_button.gd").new()
		item.template = template
		item.button_group = selection
		item.edit_requested.connect(func(): edit_template(template))
		item.pressed.connect(func(): message.text = template.name+" · перетащи на быстрый слот. ПКМ — изменить.")
		list_rows.add_child(item)
	if library.load_error: message.text = "Файл построений повреждён: запись заблокирована для сохранности данных."

func edit_template(template: Dictionary) -> void:
	editing = true
	heading.text = "СОЗДАНИЕ ПОСТРОЕНИЯ" if template.is_empty() or template.id == "default" else "РЕДАКТОР ПОСТРОЕНИЯ"
	draft_id = template.get("id", "")
	name_input.text = template.get("name", "") if draft_id != "default" else "Моё построение"
	canvas.points = template.get("slots", []).duplicate(true)
	interval.value = template.get("spacing",1.0)
	interval_label.text = "Интервал между точками: %.1f м" % interval.value
	for i in allowed.size(): allowed[i].button_pressed = LIBRARY.TYPES[i] in template.get("types",LIBRARY.TYPES)
	list_view.hide()
	editor_view.show()
	message.text = "15 слотов — позиции, а не конкретные солдаты."
	world.game_camera.formation_editing = true
	world.hud.formation_scrim.show()
	world.game_camera.dragging = false
	world.rts.cancel_drag()
	update_count()
	world.hud._schedule_layout()
	canvas.queue_redraw()

func close_editor() -> void:
	editing = false
	heading.text = "ПОСТРОЕНИЯ"
	world.game_camera.formation_editing = false
	world.hud.formation_scrim.hide()
	name_input.release_focus()
	editor_view.hide()
	list_view.show()
	world.hud._schedule_layout()

func update_count() -> void:
	count_label.text = "Мест: %d / 15" % canvas.points.size()
	save_button.disabled = canvas.points.size() != 15

func save_draft() -> void:
	var types: Array = []
	for i in allowed.size():
		if allowed[i].button_pressed: types.append(LIBRARY.TYPES[i])
	var error: String = library.save_template({"id":draft_id,"name":name_input.text,"slots":canvas.points.duplicate(true),"spacing":interval.value,"types":types})
	if not error.is_empty():
		message.text = error
		return
	close_editor()
	message.text = "«%s» добавлено в инвентарь навыков. Перетащи карточку на Q/W/E/D/F/R." % name_input.text

func apply_template(template: Dictionary) -> bool:
	var formations = world.rts.orders.formations
	var accepted: bool = formations.apply(world.rts.selected,template)
	message.text = "Построение: "+template.name if accepted else formations.last_error
	world.hud.skill_slots.sync_active()
	return accepted
