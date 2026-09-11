extends Button
signal edit_requested
const ICON := preload("res://scripts/ui/formation_icon.gd")
var template: Dictionary
var drag_copy := false
const SIDE := 88.0

func _ready() -> void:
	custom_minimum_size = Vector2.ONE*SIDE
	clip_contents = true
	focus_mode = FOCUS_NONE
	toggle_mode = not drag_copy and not template.is_empty()
	disabled = template.is_empty()
	mouse_filter = MOUSE_FILTER_IGNORE if drag_copy else MOUSE_FILTER_STOP
	tooltip_text = "Бафы в разработке" if not template.is_empty() and not drag_copy else ""
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#142d3d") if state in ["pressed","hover_pressed"] else Color("#081219")
		style.border_color = Color("#9acfe4") if state != "normal" else Color("#49616f")
		if state == "disabled":
			style.bg_color = Color("#09131a")
			style.border_color = Color("#293d4b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		add_theme_stylebox_override(state,style)
	if template.is_empty(): return
	var title := Label.new()
	title.text = template.name
	title.position = Vector2(4,69)
	title.size = Vector2(80,16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",11)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			edit_requested.emit()
			accept_event())

func _draw() -> void:
	if template.is_empty(): return
	ICON.draw_on(self,template.slots,Rect2(17,12,54,48),2.5)

func _get_drag_data(_position: Vector2) -> Variant:
	if drag_copy or template.is_empty(): return null
	var card = get_script().new()
	card.template = template.duplicate(true)
	card.drag_copy = true
	var holder := Control.new()
	holder.add_child(card)
	card.position = Vector2.ONE*(-SIDE*0.5)
	set_drag_preview(holder)
	return {"kind":"formation","id":template.id}
