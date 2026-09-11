extends RefCounted
## One automatic icon for inventory, dragging and the assigned hotbar slot.
static func draw_on(control: Control, points: Array, rect: Rect2, radius: float = 2.5) -> void:
	if points.is_empty(): return
	var bounds := Rect2(Vector2(points[0][0],points[0][1]),Vector2.ZERO)
	for point in points: bounds = bounds.expand(Vector2(point[0],point[1]))
	var factor := minf(rect.size.x/maxf(bounds.size.x,1),rect.size.y/maxf(bounds.size.y,1))
	for point in points:
		var position := rect.get_center()+(Vector2(point[0],point[1])-bounds.get_center())*factor
		control.draw_circle(position,radius,Color("#c5e7f4"),true,-1,true)
