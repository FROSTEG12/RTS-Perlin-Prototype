extends Button
## Large bare cross: no square background in any interaction state.
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var color := Color("#81857d") if disabled else Color("#f2f1df")
	if is_hovered() and not disabled: color = Color.WHITE
	var arm := minf(size.x, size.y) * 0.34
	draw_line(center - Vector2(arm,0), center + Vector2(arm,0), color, 5.0, true)
	draw_line(center - Vector2(0,arm), center + Vector2(0,arm), color, 5.0, true)
