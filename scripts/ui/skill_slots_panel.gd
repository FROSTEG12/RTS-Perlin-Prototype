extends PanelContainer
## Input scaffold only: skills will subscribe to slot_requested later.
signal slot_requested(index: int)
signal slot_toggled(index: int, active: bool)
const KEYS := [KEY_Q, KEY_W, KEY_E, KEY_D, KEY_F, KEY_R]
const CAPTIONS := ["Q", "W", "E", "D", "F", "R"]
const SLOT_SIZE := 64.0
const SLOT_GAP := 6.0
var slots: Array[Button] = []
var last_requested := -1
var library: RefCounted

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var padding := StyleBoxFlat.new()
	padding.bg_color = Color("#0c1720e6")
	padding.border_color = Color("#40546060")
	padding.set_border_width_all(1)
	padding.set_corner_radius_all(3)
	padding.content_margin_left = 10
	padding.content_margin_right = 10
	padding.content_margin_top = 10
	padding.content_margin_bottom = 10
	add_theme_stylebox_override("panel", padding)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for i in 6:
		var slot := preload("res://scripts/ui/formation_quick_button.gd").new()
		slot.name = "SkillSlot%d" % (i + 1)
		slot.custom_minimum_size = Vector2.ONE * SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.toggle_mode = true
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("#193443") if state in ["pressed", "hover_pressed"] else Color("#081219")
			style.border_color = Color("#f0f1ee") if state != "normal" else Color("#8b9da580")
			style.set_border_width_all(1)
			style.set_corner_radius_all(2)
			slot.add_theme_stylebox_override(state, style)
		row.add_child(slot)
		var key_cap := Panel.new()
		key_cap.position = Vector2(2, -2)
		key_cap.size = Vector2(20, 22)
		key_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = Color("#293c48")
		key_style.border_color = Color("#9eafb8")
		key_style.set_border_width_all(1)
		key_style.set_corner_radius_all(2)
		key_cap.add_theme_stylebox_override("panel", key_style)
		slot.add_child(key_cap)
		var key := Label.new()
		key.text = CAPTIONS[i]
		key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", Color.WHITE)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_cap.add_child(key)
		slot.toggled.connect(_on_slot_toggled.bind(i))
		slot.formation_dropped.connect(func(id):
			if library != null: library.bind_slot(i,id))
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and library != null:
				library.bind_slot(i,"")
				slot.accept_event())
		slots.append(slot)

func fit_width(available: float) -> Vector2:
	var side := clampf(floorf((available - 20 - SLOT_GAP * 5) / 6), 48, SLOT_SIZE)
	for slot in slots: slot.custom_minimum_size = Vector2.ONE * side
	return Vector2(side * 6 + SLOT_GAP * 5 + 20, side + 20)

func request_slot(index: int) -> void:
	slots[index].button_pressed = not slots[index].button_pressed

func _on_slot_toggled(active: bool, index: int) -> void:
	if library != null and get_parent().formation_panel.editing:
		slots[index].set_pressed_no_signal(not active)
		return
	if library != null and not library.bindings[index].is_empty():
		var panel = get_parent().formation_panel
		if not active:
			slots[index].set_pressed_no_signal(true)
			active = true # A bound formation is a command, not a toggle-off ability.
		if not panel.apply_template(library.get_template(library.bindings[index])):
			slots[index].set_pressed_no_signal(false)
			sync_active()
			get_parent()._set_section(2)
			return
		slots[index].set_pressed_no_signal(true)
	if active:
		for other in slots.size():
			if other != index and slots[other].button_pressed:
				slots[other].set_pressed_no_signal(false)
				slot_toggled.emit(other, false)
	last_requested = index
	slot_requested.emit(index)
	slot_toggled.emit(index, active)

func connect_library(provider: RefCounted) -> void:
	library = provider
	library.changed.connect(refresh_bindings)
	refresh_bindings()

func refresh_bindings() -> void:
	for i in 6:
		var item: Dictionary = library.get_template(library.bindings[i])
		slots[i].preview = item.get("slots",[])
		if item.is_empty(): slots[i].set_pressed_no_signal(false)
		slots[i].tooltip_text = item.get("name","Пустой слот")+" · ПКМ — убрать назначение"
		slots[i].queue_redraw()
	sync_active()

func sync_active() -> void:
	if library == null: return
	var world = get_parent().world
	var ids := {}
	for unit in world.rts.selected:
		var forms = world.rts.orders.formations
		ids[forms.active.get(forms.key(unit),{}).get("id","")] = true
	var marked := false
	for i in 6:
		if library.bindings[i].is_empty(): continue
		var active: bool = not marked and ids.size() == 1 and ids.has(library.bindings[i])
		slots[i].set_pressed_no_signal(active)
		marked = marked or active
	if marked:
		for i in 6:
			if library.bindings[i].is_empty(): slots[i].set_pressed_no_signal(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if get_tree().paused: return
	var world = get_parent().world
	if world.is_generating or world.developer_tools.visible: return
	if world.hud.formation_panel.editing: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if not event is InputEventKey or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var index := KEYS.find(code)
	if index < 0: return
	if event.pressed: request_slot(index)
	get_viewport().set_input_as_handled()
