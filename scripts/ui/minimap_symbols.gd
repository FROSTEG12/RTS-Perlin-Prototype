extends RefCounted
## Small native map glyphs: flat silhouettes, independent of scene lighting.
static func draw(canvas: CanvasItem, point: Vector2, kind: String, color: Color, scale: float = 1.0) -> void:
	canvas.draw_set_transform(point, 0, Vector2.ONE * scale)
	if kind == "troop":
		canvas.draw_circle(Vector2.ZERO, 2.7, Color("#09111bc0"), true, -1, true)
		canvas.draw_circle(Vector2.ZERO, 1.9, color, true, -1, true)
	elif kind == "resource":
		_line(canvas, Vector2(-5,5), Vector2(4,-5), color)
		_line(canvas, Vector2(5,5), Vector2(-4,-5), color)
		_line(canvas, Vector2(-7,-2), Vector2(-3,-6), color)
		_line(canvas, Vector2(7,-2), Vector2(3,-6), color)
	elif kind == "building":
		canvas.draw_rect(Rect2(-8,-8,16,16), Color("#071019b0"))
		canvas.draw_rect(Rect2(-6,-4,12,10), color)
		for x in [-6, -1, 4]: canvas.draw_rect(Rect2(x,-7,3,6), color)
		canvas.draw_rect(Rect2(-1.5,1,3,5), Color("#0c1720"))
	elif kind == "watchtower":
		_line(canvas, Vector2(-4,7), Vector2(-3,-6), color)
		_line(canvas, Vector2(4,7), Vector2(3,-6), color)
		_line(canvas, Vector2(-3,5), Vector2(3,-2), color)
		_line(canvas, Vector2(3,5), Vector2(-3,-2), color)
		canvas.draw_rect(Rect2(-5,-7,10,4), color)
		_line(canvas, Vector2(-6,-8), Vector2(0,-10), color)
		_line(canvas, Vector2(0,-10), Vector2(6,-8), color)
	canvas.draw_set_transform(Vector2.ZERO)

static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color) -> void:
	canvas.draw_line(a,b,Color("#081018"),4,true)
	canvas.draw_line(a,b,color,1.8,true)
