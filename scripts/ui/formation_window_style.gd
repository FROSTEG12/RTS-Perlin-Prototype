extends RefCounted
## Shared navy surfaces for the two floating formation windows.
static func surface(fill: String, border: String, radius: int, margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.corner_detail = 16
	style.anti_aliasing = true
	for edge in ["left","right","top","bottom"]: style.set("content_margin_"+edge,margin)
	return style

static func window(margin: int) -> StyleBoxFlat:
	var style := surface("#0c1720fa","#49616f80",22,margin)
	style.shadow_color = Color("#02080d70")
	style.shadow_size = 12
	style.shadow_offset = Vector2(0,5)
	return style

static func button(target: Button, primary: bool = false, radius: int = 10) -> void:
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var fill := "#192b36"
		var border := "#526f8055"
		if primary: fill = "#285777"; border = "#81b5d080"
		if state in ["hover","hover_pressed"]:
			fill = "#326480" if primary else "#253f50"
			border = "#9acfe4b0"
		elif state == "pressed":
			fill = "#214966" if primary else "#1e4259"
			border = "#85bfd8"
		elif state == "disabled":
			fill = "#15242e"
			border = "#41586540"
		var style := surface(fill,border,radius)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		target.add_theme_stylebox_override(state,style)
	target.add_theme_color_override("font_color",Color("#e1eaf0"))
	target.add_theme_color_override("font_disabled_color",Color("#718692"))
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func field(target: LineEdit) -> void:
	var style := surface("#08131c","#506b7d70",10,12)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	target.add_theme_stylebox_override("normal",style)
	var focus := surface("#00000000","#8bc7e2",10)
	target.add_theme_stylebox_override("focus",focus)
	target.add_theme_color_override("font_placeholder_color",Color("#8198a7"))
	target.add_theme_color_override("caret_color",Color("#b8dfed"))
	target.add_theme_color_override("selection_color",Color("#295a82"))

static func scrollbar(target: ScrollBar) -> void:
	target.add_theme_stylebox_override("scroll",surface("#08131c80","#00000000",3,3))
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		target.add_theme_stylebox_override(state,surface("#55788b" if state == "grabber" else "#91bdd3","#00000000",3,3))
