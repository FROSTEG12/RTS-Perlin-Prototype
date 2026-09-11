extends Button
var template: Dictionary
func _get_drag_data(_position: Vector2) -> Variant:
	var label := Label.new()
	label.text = template.name+" → Q / W / E / D / F / R"
	set_drag_preview(label)
	return {"kind":"formation","id":template.id}
