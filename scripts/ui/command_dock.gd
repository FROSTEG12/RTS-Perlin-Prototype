extends HBoxContainer
## Three exclusive entry points. Panels are owned by the HUD, not by the buttons.
signal section_requested(index: int)
var buttons: Array[Button] = []
var active_section := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 6)
	var names := ["Постройки", "Армии", "Создать построение"]
	var icons := ["buildings", "armies", "formations"]
	for i in names.size():
		var item := preload("res://scripts/ui/menu_medallion.gd").new()
		item.name = ["Buildings", "Armies", "Formations"][i]
		item.tooltip_text = names[i]
		item.focus_mode = Control.FOCUS_NONE
		item.toggle_mode = i != 2
		item.custom_minimum_size = Vector2(56, 56)
		item.glyph = load("res://assets/ui/generated_navigation/" + icons[i] + ".png")
		item.pressed.connect(func(): section_requested.emit(i))
		buttons.append(item)
		add_child(item)

func set_active(index: int) -> void:
	active_section = index
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == index)
		buttons[i].refresh_selection()

func contains(point: Vector2) -> bool:
	for item in buttons:
		if item.is_visible_in_tree() and item.get_global_rect().has_point(point): return true
	return false
