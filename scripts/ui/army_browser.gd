extends Control
## Six recruitment plans, not spawned units. No deductions before economy is agreed.
const CATALOG = preload("res://scripts/ui/army_catalog.gd")
const CARD = preload("res://scripts/ui/army_card.gd")
var world: Node3D
var entries: Array[Dictionary] = CATALOG.entries()
var squads: Array[Dictionary] = []
var selected := -1
var chooser_open := false
var compact := false
var choices: Array[Button] = []
var squad_cards: Array[Button] = []
var add_button: Button
var chooser: Control
var heading: Label
var flights: Array[Control] = []
var details_panel: Control
var details_card: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chooser = Control.new()
	chooser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chooser)
	heading = _label("Сформировать армию", chooser, 17)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_shadow_color", Color("#000000e0"))
	heading.add_theme_constant_override("shadow_offset_x", 1)
	heading.add_theme_constant_override("shadow_offset_y", 1)
	for i in entries.size():
		var card := CARD.new(entries[i], true)
		chooser.add_child(card)
		card.pressed.connect(_add_squad.bind(i))
		choices.append(card)
	add_button = preload("res://scripts/ui/army_add_button.gd").new()
	add_child(add_button)
	add_button.pressed.connect(_open_chooser)
	add_button.tooltip_text = "Добавить отряд"
	details_panel = preload("res://scripts/ui/army_details_panel.gd").new()
	add_child(details_panel)
	details_panel.hide()
	details_panel.z_index = 20
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _close_details())
	resized.connect(_layout)
	refresh()

func _label(value: String, parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _open_chooser() -> void:
	_close_details()
	if squads.size() >= CATALOG.MAX_SQUADS: return
	chooser_open = not chooser_open
	_layout()

func _add_squad(type_index: int) -> void:
	if type_index < 0 or type_index >= entries.size() or squads.size() >= CATALOG.MAX_SQUADS: return
	_close_details()
	var start := choices[type_index].global_position - global_position
	squads.append({"type": type_index, "members": 0, "state": "planned"})
	selected = squads.size() - 1
	var card := CARD.new(entries[type_index])
	add_child(card)
	card.pressed.connect(_select_squad.bind(card))
	card.removal_requested.connect(_remove_squad)
	card.details_requested.connect(_toggle_details)
	squad_cards.append(card)
	refresh()
	# Animate a separate mouse-transparent portrait; real button stays at target.
	var flying := CARD.new(entries[type_index])
	add_child(flying)
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.warning_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.position = start
	flying.size = choices[type_index].size
	flights.append(flying)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying, "position", card.position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "size", card.size, 0.24)
	tween.finished.connect(func():
		if is_instance_valid(card): card.modulate.a = 1.0
		flights.erase(flying)
		flying.queue_free())

func _select_squad(card: Button) -> void:
	_close_details()
	selected = squad_cards.find(card)
	chooser_open = true
	refresh()

func _remove_squad(card: Button) -> void:
	var index := squad_cards.find(card)
	if index < 0: return
	if details_card == card: _close_details()
	squads.remove_at(index)
	squad_cards.remove_at(index)
	remove_child(card)
	card.queue_free()
	if index < selected: selected -= 1
	elif index == selected: selected = mini(index, squads.size() - 1)
	refresh()

func refresh() -> void:
	if not add_button: return
	var full := squads.size() >= CATALOG.MAX_SQUADS
	add_button.disabled = full
	add_button.queue_redraw()
	add_button.tooltip_text = "Максимум 6 отрядов" if full else "Добавить отряд"
	for choice in choices:
		choice.disabled = full
		choice.refresh()
	for i in squad_cards.size():
		var entry := entries[int(squads[i].type)]
		# UI selection never forms a squad or supplies its resources.
		squad_cards[i].pending = squads[i].state == "planned"
		squad_cards[i].count_text = "%d / %s" % [squads[i].members, str(entry.capacity) if entry.capacity > 0 else "—"]
		squad_cards[i].set_pressed_no_signal(i == selected)
		squad_cards[i].refresh()
	_update_requirements()
	_layout()

func _update_requirements() -> void:
	if not is_instance_valid(details_card) or not details_panel.visible: return
	var index := squad_cards.find(details_card)
	if index < 0:
		_close_details()
		return
	details_panel.set_details(entries[int(squads[index].type)], squads[index], world.stockpile)
	_place_details()

func _toggle_details(card: Button) -> void:
	if details_card == card and details_panel.visible:
		_close_details()
		return
	_close_details()
	details_card = card
	card.warning_button.set_pressed_no_signal(true)
	card.warning_button.queue_redraw()
	move_child(details_panel, -1)
	details_panel.show()
	_update_requirements()

func _close_details() -> void:
	if is_instance_valid(details_card):
		details_card.warning_button.set_pressed_no_signal(false)
		details_card.warning_button.queue_redraw()
	details_card = null
	if details_panel: details_panel.hide()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not details_panel or not details_panel.visible: return
	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if details_panel.get_global_rect().has_point(point): return
		for card in squad_cards:
			if card.warning_button.get_global_rect().has_point(point): return
		_close_details()

func _place_details() -> void:
	if not is_instance_valid(details_card) or not details_panel.visible: return
	var anchor: Rect2 = details_card.warning_button.get_global_rect()
	var viewport_rect := get_viewport_rect()
	var x := clampf(anchor.get_center().x - details_panel.size.x * 0.5, 8, viewport_rect.size.x - details_panel.size.x - 8)
	var y := maxf(8, anchor.position.y - details_panel.size.y - 10)
	details_panel.global_position = Vector2(x, y)

func total_requirements() -> Dictionary:
	var total := {}
	for squad in squads:
		for key in entries[int(squad.type)].requirements:
			total[key] = int(total.get(key, 0)) + int(entries[int(squad.type)].requirements[key])
	return total

func _layout() -> void:
	if not chooser: return
	var tile := Vector2(84, 122) if compact else Vector2(108, 164)
	var upper_offset := 48.0 if compact else 56.0
	var upper_h := tile.y + upper_offset
	chooser.position = Vector2.ZERO
	chooser.size = Vector2(size.x, upper_h)
	chooser.visible = chooser_open
	heading.position = Vector2(0, 0)
	heading.size = Vector2(size.x, 26)
	var step_x := tile.x + 18.0
	var choice_left := (size.x - (5 * tile.x + 4 * 18.0)) * 0.5
	for i in choices.size():
		choices[i].size = tile
		choices[i].position = Vector2(choice_left + i * step_x, upper_offset)
	var lower_y := size.y - tile.y - 28
	# Center the warriors alone. The add control is outside their row bounds.
	var row_width := squads.size() * tile.x + maxi(0, squads.size() - 1) * 8.0
	var left := (size.x - row_width)/2
	for i in squad_cards.size():
		squad_cards[i].size = tile
		squad_cards[i].position = Vector2(left + i * (tile.x+8), lower_y)
	var add_x := left + row_width + 8.0 if not squads.is_empty() else (size.x - 72.0) * 0.5
	add_button.position = Vector2(add_x, lower_y + (tile.y-72)/2)
	if squads.is_empty():
		add_button.position.y = world.hud.dock.position.y-global_position.y-72-8
	add_button.size = Vector2(72,72)
	_place_details()

func contains(point: Vector2) -> bool:
	if not is_visible_in_tree(): return false
	if details_panel and details_panel.visible and details_panel.get_global_rect().has_point(point): return true
	for control in [add_button] + choices + squad_cards:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false
