extends Button
func _draw() -> void:
	for y in 3:
		for x in 2:
			draw_rect(Rect2(size*0.5+Vector2(x*8-7,y*8-11),Vector2(6,6)),Color("#d5e7ef"))
