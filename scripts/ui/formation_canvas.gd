extends Control
signal changed
var points: Array = []
var editable := true
var mirrored := false
var dragging := -1
var press_cell := Vector2i(99,99)
var moved := false
var spacing := 1.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP if editable else MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func step_size() -> float: return minf(size.x-48,size.y-50)/11.0
func point_position(point: Vector2) -> Vector2: return size*0.5+point*step_size()
func cell_at(point: Vector2) -> Vector2i: return Vector2i(((point-size*0.5)/step_size()).round())
func index_at(cell: Vector2i) -> int:
	for i in points.size():
		if Vector2i(points[i][0],points[i][1]) == cell: return i
	return -1

func toggle(cell: Vector2i) -> void:
	if absi(cell.x)>5 or absi(cell.y)>5: return
	var cells := [cell]
	if mirrored and cell.x != 0: cells.append(Vector2i(-cell.x,cell.y))
	var remove := index_at(cell) >= 0
	var adding := 0
	for target in cells:
		if index_at(target) < 0: adding += 1
	if not remove and points.size()+adding > 15: return
	for target in cells:
		var index := index_at(target)
		if remove and index >= 0: points.remove_at(index)
		elif not remove and index < 0: points.append([target.x,target.y])
	changed.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_cell = cell_at(event.position)
			dragging = index_at(press_cell)
			moved = false
		else:
			if not moved: toggle(press_cell)
			dragging = -1
		accept_event()
	elif event is InputEventMouseMotion and dragging >= 0:
		var cell := cell_at(event.position)
		if cell == press_cell or absi(cell.x)>5 or absi(cell.y)>5 or index_at(cell)>=0: return
		var old := Vector2i(points[dragging][0],points[dragging][1])
		var partner := index_at(Vector2i(-old.x,old.y))
		var opposite := index_at(Vector2i(-cell.x,cell.y))
		if mirrored and partner >= 0 and partner != dragging:
			if cell.x == 0 or (opposite >= 0 and opposite != partner): return
			points[partner] = [-cell.x,cell.y]
		points[dragging] = [cell.x,cell.y]
		moved = true
		changed.emit()
		queue_redraw()

func _draw() -> void:
	var step := step_size()
	if step <= 0: return
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var mid := size*0.5
	draw_line(Vector2(mid.x,12),Vector2(mid.x,30),Color("#82bfd6"),2,true)
	draw_line(Vector2(mid.x,12),Vector2(mid.x-5,18),Color("#82bfd6"),2,true)
	draw_line(Vector2(mid.x,12),Vector2(mid.x+5,18),Color("#82bfd6"),2,true)
	for y in range(-5,6):
		for x in range(-5,6): draw_circle(point_position(Vector2(x,y)),1.4,Color("#344c5c"),true,-1,true)
	var mean := Vector2.ZERO
	for point in points: mean += Vector2(point[0],point[1])
	if not points.is_empty(): mean /= points.size()
	var origin := point_position(mean)
	draw_line(origin-Vector2(9,0),origin+Vector2(9,0),Color("#647884"),1,true)
	draw_line(origin-Vector2(0,9),origin+Vector2(0,9),Color("#647884"),1,true)
	var font := ThemeDB.fallback_font
	for i in points.size():
		var position := point_position(Vector2(points[i][0],points[i][1]))
		draw_circle(position,minf(11,step*0.39),Color("#295a82"),true,-1,true)
		draw_arc(position,minf(11,step*0.39),0,TAU,24,Color("#b8dfed"),1,true)
		var label := str(i+1)
		var text_size := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11)
		draw_string(font,position+Vector2(-text_size.x*0.5,4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081219")
	style.border_color = Color("#415f7280")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.corner_detail = 16
	return style
