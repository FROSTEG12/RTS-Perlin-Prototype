extends Button
## Flat HUD disc: one fill and one uniform ring, without bevels or shadows.
const ACCENT := Color("#82bfd6")
var glyph: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_down: bool): queue_redraw())
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	var lit := button_pressed or is_hovered()
	draw_circle(center, radius, Color("#193443f5") if lit else Color("#0c1720eb"), true, -1, true)
	draw_arc(center, radius, 0, TAU, 80, ACCENT if lit else Color("#71818a"), 1.2, true)
	if glyph:
		# Generated glyphs include safe transparent margins and their off-white color.
		var area := Rect2(center - Vector2(18, 18), Vector2(36, 36))
		draw_texture_rect(glyph, area, false, ACCENT if button_pressed else Color.WHITE)

func refresh_selection() -> void:
	queue_redraw()
