extends SceneTree
const LIB := preload("res://scripts/units/formation_library.gd")
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name)
func mouse_button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event,true)
func mouse_motion(point: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)
func run() -> void:
	var library = LIB.new(OUT+"formations-test-%d.json" % Time.get_ticks_usec())
	var wedge: Array = []
	for row in 5:
		for x in range(-row,row+1,2): wedge.append([x,row-2])
	var template := {"id":"test_wedge","name":"Клин","slots":wedge,"spacing":1.5,"types":["infantry"]}
	assert(LIB.validate(template).is_empty())
	assert(library.save_template(template).is_empty())
	assert(library.bind_slot(0,"test_wedge"))
	var restored = LIB.new(library.storage_path)
	assert(restored.get_template("test_wedge").slots == wedge and restored.bindings[0] == "test_wedge")
	var invalid := template.duplicate(true)
	invalid.slots[1] = invalid.slots[0]
	assert(not LIB.validate(invalid).is_empty())
	var offsets := LIB.offsets(template)
	var mean := Vector2.ZERO
	for point in offsets: mean += point
	assert(mean.length() < 0.001)
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
	world.set_process(false)
	world.game_camera.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var panel = world.hud.formation_panel
	# Keep all test persistence out of the real player's library.
	world.hud.formation_library.storage_path = library.storage_path
	assert(world.hud.formation_library.save_template(template).is_empty())
	world.hud._set_section(2)
	panel.edit_template({})
	assert(panel.draft_spacing == 1.0 and panel.draft_types == LIB.TYPES)
	assert(panel.find_children("*","HSlider",true,false).is_empty())
	assert(panel.find_children("*","CheckBox",true,false).is_empty())
	panel.edit_template(template)
	assert(panel.editing and not world.game_camera.controls_blocked)
	panel.name_input.grab_focus()
	var typing := InputEventKey.new()
	typing.physical_keycode = KEY_Q
	typing.keycode = KEY_Q
	typing.unicode = 113
	typing.pressed = true
	root.push_input(typing,true)
	await process_frame
	assert(not world.hud.skill_slots.slots[0].button_pressed)
	panel.name_input.text = "Клин"
	panel.canvas.points = []
	panel.canvas.mirrored = true
	panel.canvas.toggle(Vector2i(2,0))
	assert(panel.canvas.points.size() == 2 and panel.canvas.index_at(Vector2i(-2,0)) >= 0)
	panel.canvas.toggle(Vector2i(2,0))
	assert(panel.canvas.points.is_empty())
	panel.canvas.mirrored = false
	panel.canvas.points = wedge.duplicate(true)
	var points_before: Array = panel.canvas.points.duplicate(true)
	panel.canvas.toggle(Vector2i(5,5))
	assert(panel.canvas.points == points_before) # full template cannot exceed 15
	panel.canvas.toggle(Vector2i(0,-2))
	assert(panel.canvas.points.size() == 14 and panel.save_button.disabled)
	panel.canvas.toggle(Vector2i(0,-2))
	assert(panel.canvas.points.size() == 15 and not panel.save_button.disabled)
	await capture("formation-editor.png")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960,540)
		for i in 8: await process_frame
		assert(panel.get_global_rect().end.y <= world.hud.size.y)
		assert(panel.canvas.get_global_rect().end.y < panel.get_global_rect().end.y)
		await capture("formation-editor-960.png")
		root.size = Vector2i(1280,720)
	panel.save_draft()
	var saved: Dictionary = world.hud.formation_library.get_template("test_wedge")
	assert(saved.spacing == 1.5 and saved.types == ["infantry"],"Removing metadata controls must not change existing templates")
	assert(panel.editing and panel.visible,"Save must not close a floating editor")
	panel.close_button.pressed.emit()
	world.hud.open_inventory()
	for i in 8: await process_frame
	var inventory = world.hud.formation_inventory
	await check_floating_windows(world)
	var inventory_card = inventory.list_rows.get_child(world.hud.formation_library.templates.size()-1)
	inventory.list_rows.get_parent().ensure_control_visible(inventory_card)
	for i in 4: await process_frame
	world.rts.set_selection([world.lead_unit])
	var revision: int = world.lead_unit.order_revision
	inventory_card.pressed.emit()
	assert(world.lead_unit.order_revision == revision,"Inventory clicks must never apply a formation")
	await capture("formation-inventory.png")
	var quick = world.hud.skill_slots.slots[0]
	if DisplayServer.get_name() != "headless":
		var source: Vector2 = inventory_card.get_global_rect().get_center()
		var target: Vector2 = quick.get_global_rect().get_center()
		root.warp_mouse(source)
		mouse_button(source,true)
		await process_frame
		mouse_motion(source+Vector2(20,0),Vector2(20,0))
		await process_frame
		assert(root.gui_is_dragging(),"Dragging a skill card must start a GUI drag")
		root.warp_mouse(target)
		mouse_motion(target,target-source-Vector2(20,0))
		await process_frame
		mouse_button(target,false)
		for i in 3: await process_frame
		assert(world.hud.formation_library.bindings[0] == "test_wedge","Real mouse drag must assign Q")
		assert(world.lead_unit.order_revision == revision,"Assigning a skill must not apply it")
		print("FORMATION_INVENTORY_DRAG_PASS")
	assert(quick._can_drop_data(Vector2.ZERO,{"kind":"formation","id":"test_wedge"}))
	quick._drop_data(Vector2.ZERO,{"kind":"formation","id":"test_wedge"})
	assert(world.hud.formation_library.bindings[0] == "test_wedge" and quick.preview.size() == 15)
	world.rts.set_selection([world.lead_unit])
	var forms = world.rts.orders.formations
	# Use an all-land test map so formation routing is deterministic, not seed luck.
	var cells := PackedByteArray()
	cells.resize(world.current_cells.size())
	cells.fill(0)
	world.map_renderer.cells = cells
	world.pathfinder.setup(cells,world.map_renderer.map_size)
	print("FORMATION_TEST_READY")
	var orders = world.rts.orders
	var anchor: Vector2i = world.map_renderer.world_to_cell(forms.center(world.player_units))
	anchor = anchor.clamp(Vector2i(25,25),Vector2i(75,75))
	orders.move(world.player_units,anchor,false)
	orders.move(world.player_units,anchor+Vector2i(5,5),true)
	assert(orders.pending.size() == 30)
	var before: Vector3 = world.lead_unit.position
	var accepted: bool = forms.apply(world.rts.selected,template)
	if not accepted:
		print("FORMATION_INITIAL_REJECT ",forms.last_error)
	assert(accepted)
	assert(world.lead_unit.position == before and orders.pending.is_empty())
	var intents: Array = forms.intentions[forms.key(world.lead_unit)]
	assert(intents.size() == 3 and intents[-1].goal == anchor+Vector2i(5,5))
	for i in 6: assert(forms.apply(world.rts.selected,template))
	assert(forms.intentions[forms.key(world.lead_unit)].size() == 3,"Rapid switches replace the old regrouping stage")
	for i in 2400:
		forms.pace.update(1.0/30.0)
		for unit in world.player_units: unit._process(1.0/30.0)
	for unit in world.player_units: assert(unit.target_positions.is_empty())
	var expected_distances: Array[float] = []
	var actual_distances: Array[float] = []
	for i in 15:
		for j in range(i+1,15):
			expected_distances.append(offsets[i].distance_to(offsets[j]))
			actual_distances.append(world.player_units[i].position.distance_to(world.player_units[j].position))
	expected_distances.sort()
	actual_distances.sort()
	for i in expected_distances.size(): assert(absf(expected_distances[i]-actual_distances[i]) < 0.01,"Exact 1.5 m layout, independent of rotation/assignment")
	forms.prune()
	assert(forms.intentions[forms.key(world.lead_unit)].is_empty())
	var positions: Array = []
	for unit in world.player_units: positions.append(unit.position)
	assert(forms.apply(world.rts.selected,template))
	orders.move(world.player_units,anchor+Vector2i(8,0),false)
	orders.move(world.player_units,anchor+Vector2i(8,8),true)
	for i in 20:
		forms.pace.update(1.0/30.0)
		for unit in world.player_units: unit._process(1.0/30.0)
	var rectangle: Dictionary = library.get_template("default")
	assert(forms.apply(world.rts.selected,rectangle))
	intents = forms.intentions[forms.key(world.lead_unit)]
	assert(intents[-1].goal == anchor+Vector2i(8,8))
	var target_before: Array = world.lead_unit.target_positions.duplicate()
	var blocked := cells.duplicate()
	blocked.fill(1)
	world.map_renderer.cells = blocked
	assert(not forms.apply(world.rts.selected,template))
	assert(world.lead_unit.target_positions == target_before)
	world.map_renderer.cells = cells
	var original_type: String = world.lead_unit.troop_type
	world.lead_unit.troop_type = "cavalry"
	assert(not forms.apply(world.rts.selected,template))
	world.lead_unit.troop_type = original_type
	assert(world.hud.formation_library.bind_slot(0,"test_wedge"))
	assert(world.hud.formation_library.bind_slot(1,"default"))
	world.hud.skill_slots.refresh_bindings()
	for key_code in [KEY_W,KEY_Q]:
		for down in [true,false]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key_code
			key_event.pressed = down
			root.push_input(key_event,true)
			await process_frame
	assert(world.hud.skill_slots.slots[0].button_pressed)
	assert(not world.hud.skill_slots.slots[1].button_pressed)
	world.hud._set_section(-1)
	world.game_camera.focus_on(forms.center(world.player_units))
	world.game_camera.size = 18
	await capture("formation-applied.png")
	world.rts.orders.stop(world.player_units)
	assert(forms.intentions.is_empty())
	print("FORMATION_EDITOR_PASS persistence validation 15_slots centered spacing apply types quickslot moving_queue no_teleport reject_atomic stop")
	quit()

func check_floating_windows(world: Node) -> void:
	var hud = world.hud
	var editor = hud.formation_panel
	var inventory = hud.formation_inventory
	assert(hud.skill_slots.inventory_button.get_global_rect().end.x < hud.skill_slots.slots[0].global_position.x)
	for button in inventory.find_children("*","Button",true,false):
		assert(not "Создать" in button.text)
		assert(button.tooltip_text in ["","Бафы в разработке"],"No instructional tooltips")
	assert(hud.skill_slots.inventory_button.size.x >= 48)
	var glyph: Texture2D = hud.skill_slots.inventory_button.GLYPH
	assert(glyph.resource_path.ends_with("generated_navigation/inventory.png"))
	assert(glyph.get_image().has_mipmaps())
	var original := Image.load_from_file(ProjectSettings.globalize_path(glyph.resource_path))
	assert(original.detect_alpha() != Image.ALPHA_NONE and original.get_pixel(0,0).a == 0)
	assert(inventory.list_rows.columns == 5 and inventory.list_rows.get_child_count() >= 15)
	assert(not inventory.message.visible)
	assert(inventory.size == Vector2(500,360))
	for cell in inventory.list_rows.get_children():
		assert(cell.size == Vector2(88,88),"Inventory cells must be square")
		if cell.template.is_empty():
			assert(cell.disabled and cell._get_drag_data(Vector2.ZERO) == null)
	var original_templates: Array = hud.formation_library.templates.duplicate(true)
	while hud.formation_library.templates.size() < 21:
		var extra := LIB.default_template()
		extra.id = "overflow_%d" % hud.formation_library.templates.size()
		hud.formation_library.templates.append(extra)
	inventory.refresh_list()
	for i in 4: await process_frame
	assert(inventory.size == Vector2(500,360) and inventory.list_rows.get_child_count() == 25)
	var last = inventory.list_rows.get_child(20)
	inventory.list_rows.get_parent().ensure_control_visible(last)
	for i in 4: await process_frame
	assert(inventory.list_rows.get_parent().get_global_rect().encloses(last.get_global_rect()),"Overflow skills remain reachable by scrolling")
	hud.formation_library.templates = original_templates
	inventory.refresh_list()
	for i in 4: await process_frame
	hud._open_section(2)
	editor.name_input.text = "Несохранённый черновик"
	editor.canvas.points = [[0,0],[1,0]]
	hud._open_section(2)
	hud._open_section(1)
	hud._open_section(0)
	hud._set_section(-1)
	hud.skill_slots.inventory_button.pressed.emit()
	hud.skill_slots.inventory_button.pressed.emit()
	assert(editor.visible and inventory.visible and editor.canvas.points.size() == 2)
	assert(editor.name_input.text == "Несохранённый черновик")
	for label in editor.find_children("*","Label",true,false):
		assert(not "конкретные" in label.text and not "Клик —" in label.text)
	if DisplayServer.get_name() != "headless":
		for window in [inventory,editor]:
			window.bring_forward()
			for i in 3: await process_frame
			var previous: Vector2 = window.position
			var source: Vector2 = window.header.global_position+Vector2(60,16)
			var delta := Vector2(35,20)
			root.warp_mouse(source)
			mouse_button(source,true)
			mouse_motion(source+delta,delta)
			mouse_button(source+delta,false)
			await process_frame
			assert(window.position.distance_to(previous+delta)<1,"Window header must drag")
			var moved: Vector2 = window.position
			hud._layout_hud()
			assert(window.position == moved,"HUD layout must preserve window position")
	# Outside input remains available; inside clicks cannot create a selection box.
	var empty_point := Vector2(12,140)
	assert(not hud.contains(empty_point))
	mouse_button(empty_point,true)
	assert(world.rts.selecting)
	mouse_button(empty_point,false)
	assert(editor.visible and inventory.visible)
	var bindings: Array = hud.formation_library.bindings.duplicate()
	hud.formation_library.bindings = ["","","","","",""]
	hud.skill_slots.refresh_bindings()
	var hotkey := InputEventKey.new()
	hotkey.physical_keycode = KEY_R
	hotkey.pressed = true
	root.push_input(hotkey,true)
	assert(hud.skill_slots.slots[5].button_pressed,"Hotkeys must work while editor is open")
	hotkey.pressed = false
	root.push_input(hotkey,true)
	hud.formation_library.bindings = bindings
	hud.skill_slots.refresh_bindings()
	var zoom_before: float = world.game_camera.size
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = empty_point
	root.warp_mouse(empty_point)
	mouse_motion(empty_point,Vector2.ZERO)
	world.game_camera.window_focused = true
	root.push_input(wheel,true)
	assert(world.game_camera.size < zoom_before,"Camera must work outside floating windows")
	editor.bring_forward()
	mouse_button(editor.global_position+Vector2(4,70),true)
	assert(not world.rts.selecting)
	mouse_button(editor.global_position+Vector2(4,70),false)
	zoom_before = world.game_camera.size
	wheel.position = editor.global_position+Vector2(4,70)
	root.warp_mouse(wheel.position)
	mouse_motion(wheel.position,Vector2.ZERO)
	root.push_input(wheel,true)
	assert(world.game_camera.size == zoom_before,"Window blocks wheel input to world")
	hud._open_section(1)
	hud.armies._layout()
	assert(absf(hud.armies.add_button.get_global_rect().end.y-hud.dock.global_position.y+8)<1)
	hud._set_section(-1)
	world.pause_menu.set_open(true)
	world.pause_menu.set_open(false)
	assert(editor.visible and inventory.visible)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	assert(editor.visible and inventory.visible)
	world.pause_menu.set_open(false)
	editor.close_button.pressed.emit()
	assert(not editor.visible and inventory.visible)
	inventory.close_button.pressed.emit()
	assert(not inventory.visible)
	hud.open_inventory()
	print("FLOATING_WINDOWS_PASS independent persistent non_modal drag close no_clickthrough")
