extends Button
## Separate, high-contrast details target; never a hover tooltip.
func _ready() -> void:
	# Draw the mark after the disc: Button's built-in text is drawn before _draw.
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		add_theme_color_override(state, Color.WHITE)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_down: bool): queue_redraw())

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 16, Color("#193443") if is_hovered() or button_pressed else Color("#0c1720"), true, -1, true)
	draw_arc(center, 16, 0, TAU, 48, Color.WHITE, 2.0, true)
	var font := get_theme_font("font")
	var mark_width := font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, Vector2(center.x - mark_width * 0.5, center.y + 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
