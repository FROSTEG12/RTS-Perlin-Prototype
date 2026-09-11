extends "res://scripts/ui/floating_panel.gd"
const LIBRARY := preload("res://scripts/units/formation_library.gd")
var library: RefCounted
var editing := false
var draft_id := ""
var rows: VBoxContainer
var editor_view: HBoxContainer
var canvas: Control
var name_input: LineEdit
var draft_spacing := 1.0
var draft_types: Array = LIBRARY.TYPES.duplicate()
var count_label: Label
var message: Label
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
	var title := Label.new()
	heading = title
	title.text = "СОЗДАНИЕ ПОСТРОЕНИЯ"
	title.add_theme_font_size_override("font_size",18)
	setup_header(title,rows,close_editor)
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
	var tools := HBoxContainer.new()
	controls.add_child(tools)
	make_button("Очистить",tools,func(): canvas.points.clear(); canvas.queue_redraw(); update_count())
	var symmetry := CheckButton.new()
	symmetry.text = "Симметрия"
	symmetry.tooltip_text = "Добавлять, удалять и перемещать зеркальные пары"
	symmetry.toggled.connect(func(value): canvas.mirrored = value)
	tools.add_child(symmetry)
	save_button = make_button("Сохранить",controls,save_draft)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size",12)
	message.hide()
	rows.add_child(message)

func make_button(text: String, parent: Node, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = FOCUS_NONE
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func open() -> void:
	if not editing: edit_template({})
	else:
		show()
		bring_forward()

func edit_template(template: Dictionary) -> void:
	editing = true
	heading.text = "СОЗДАНИЕ ПОСТРОЕНИЯ" if template.is_empty() or template.id == "default" else "РЕДАКТОР ПОСТРОЕНИЯ"
	draft_id = template.get("id", "")
	name_input.text = template.get("name", "") if draft_id != "default" else "Моё построение"
	canvas.points = template.get("slots", []).duplicate(true)
	# Metadata stays compatible with saved formations; these are no longer UI options.
	draft_spacing = template.get("spacing",1.0)
	draft_types = template.get("types",LIBRARY.TYPES).duplicate()
	message.text = ""
	message.hide()
	show()
	bring_forward()
	if not positioned:
		size = Vector2(minf(world.hud.size.x-20,760),minf(world.hud.size.y-40,520))
		position = (world.hud.size-size)*0.5
		positioned = true
	clamp_to_screen()
	world.game_camera.dragging = false
	world.rts.cancel_drag()
	update_count()
	world.hud._schedule_layout()
	canvas.queue_redraw()

func close_editor() -> void:
	editing = false
	name_input.release_focus()
	hide()

func update_count() -> void:
	count_label.text = "Мест: %d / 15" % canvas.points.size()
	save_button.disabled = canvas.points.size() != 15

func save_draft() -> void:
	var error: String = library.save_template({"id":draft_id,"name":name_input.text,"slots":canvas.points.duplicate(true),"spacing":draft_spacing,"types":draft_types.duplicate()})
	if not error.is_empty():
		message.text = error
		message.show()
		return
	# Keep the editor and draft open; subsequent saves update this same skill.
	if draft_id.is_empty() or draft_id == "default": draft_id = library.templates.back().id
	message.text = "Сохранено"
	message.show()
	name_input.release_focus()

func apply_template(template: Dictionary) -> bool:
	var formations = world.rts.orders.formations
	var accepted: bool = formations.apply(world.rts.selected,template)
	world.hud.formation_inventory.message.text = "Построение: "+template.name if accepted else formations.last_error
	world.hud.skill_slots.sync_active()
	return accepted
