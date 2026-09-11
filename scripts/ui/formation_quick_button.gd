extends Button
const ICON := preload("res://scripts/ui/formation_icon.gd")
signal formation_dropped(id: String)
var preview: Array = []

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "formation" and data.get("id") is String
func _drop_data(_position: Vector2, data: Variant) -> void:
	formation_dropped.emit(data.id)
func _draw() -> void:
	ICON.draw_on(self,preview,Rect2(Vector2(11,23),size-Vector2(22,33)),2)
	if get_viewport().gui_is_dragging() and _can_drop_data(Vector2.ZERO,get_viewport().gui_get_drag_data()):
		draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("#82bfd6"),false,2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END: queue_redraw()
