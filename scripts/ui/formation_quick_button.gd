extends Button
signal formation_dropped(id: String)
var preview: Array = []

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "formation" and data.get("id") is String
func _drop_data(_position: Vector2, data: Variant) -> void:
	formation_dropped.emit(data.id)
func _draw() -> void:
	if preview.is_empty(): return
	var bounds := Rect2(Vector2(preview[0][0],preview[0][1]),Vector2.ZERO)
	for point in preview: bounds = bounds.expand(Vector2(point[0],point[1]))
	var factor := minf((size.x-22)/maxf(bounds.size.x,1),(size.y-30)/maxf(bounds.size.y,1))
	for point in preview:
		var p := Vector2(point[0],point[1])-bounds.get_center()
		draw_circle(Vector2(size.x*0.5,size.y*0.60)+p*factor,2,Color("#bedfec"),true,-1,true)
