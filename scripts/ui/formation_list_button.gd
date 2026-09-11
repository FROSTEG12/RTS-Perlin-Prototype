extends Button
signal edit_requested
const ICON := preload("res://scripts/ui/formation_icon.gd")
var template: Dictionary
var drag_copy := false

func _ready() -> void:
	custom_minimum_size = Vector2(108,130)
	focus_mode = FOCUS_NONE
	toggle_mode = not drag_copy
	mouse_filter = MOUSE_FILTER_IGNORE if drag_copy else MOUSE_FILTER_STOP
	tooltip_text = "%s\n15 мест · %s\nПеретащи на Q/W/E/D/F/R\nПКМ — изменить; клик не отдаёт приказ" % [template.name,"стандартное" if template.id == "default" else "пользовательское"]
	for state in ["normal","hover","pressed","hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#142d3d") if state in ["pressed","hover_pressed"] else Color("#081219")
		style.border_color = Color("#9acfe4") if state != "normal" else Color("#49616f")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		add_theme_stylebox_override(state,style)
	var title := Label.new()
	title.text = template.name
	title.position = Vector2(7,94)
	title.size = Vector2(94,28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",13)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			edit_requested.emit()
			accept_event())

func _draw() -> void:
	ICON.draw_on(self,template.slots,Rect2(22,22,64,59),3)
	draw_line(Vector2(12,91),Vector2(size.x-12,91),Color("#344c5c"),1,true)

func _get_drag_data(_position: Vector2) -> Variant:
	if drag_copy: return null
	var card = get_script().new()
	card.template = template.duplicate(true)
	card.drag_copy = true
	var holder := Control.new()
	holder.add_child(card)
	card.position = Vector2(-54,-65)
	set_drag_preview(holder)
	return {"kind":"formation","id":template.id}
