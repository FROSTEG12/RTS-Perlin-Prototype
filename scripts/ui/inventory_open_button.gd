extends Button
const GLYPH := preload("res://assets/ui/generated_navigation/inventory.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#081219") if state == "normal" else Color("#193443")
		style.border_color = Color("#8b9da580") if state == "normal" else Color("#f0f1ee")
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		add_theme_stylebox_override(state,style)
	resized.connect(queue_redraw)

func _draw() -> void:
	var side := minf(size.x,size.y)*0.72
	draw_texture_rect(GLYPH,Rect2((size-Vector2.ONE*side)*0.5,Vector2.ONE*side),false)
