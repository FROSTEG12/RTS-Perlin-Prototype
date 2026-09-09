extends Node3D
## Disposable local animation/combat sandbox. Not the future RTS combat system.
const RED := preload("res://assets/units/low_poly_knight/red.scn")
const ATTACKS := ["Attack_Combo", "Attack_Splash"]
const DEATHS := ["Death_1", "Death_2", "Death_3"]
const REACH := 1.65
var world: Node3D
var hero: TestUnit3D
var npc: TestUnit3D
var health := 100
var dead := false
var npc_attacking := false
var hero_requested := false
var jobs := {}
var bags := {}
var previous := {}
var rng := RandomNumberGenerator.new()
var path_timer := 0.0
var npc_cooldown := 0.0
var npc_hits := 0
var panel: PanelContainer
var health_label: Label
var clip_label: Label
var health_bar: ProgressBar
var npc_toggle: CheckButton
var attack_button: Button
var speed_slider: HSlider
var test_speed := 1.0
var last_message := "Готов к тренировке"
var active := false

func _ready() -> void:
	rng.randomize()
	hero = world.test_unit
	hero.display_name = "Синий рыцарь №1"
	npc = preload("res://scenes/worker_unit.tscn").instantiate()
	npc.name = "ImmortalRedKnight"
	add_child(npc)
	npc.remove_from_group("rts_units")
	npc.visual.set_model(RED)
	npc.display_name = "Тренировочный NPC"
	var label := Label3D.new()
	label.text = "NPC · ∞"
	label.position.y = 1.6
	label.font_size = 32
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 0.55, 0.48)
	npc.add_child(label)
	_build_panel()

func _button(text: String, callback: Callable, rows: VBoxContainer) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	rows.add_child(button)
	return button

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "TrainingPanel"
	world.get_node("UI").add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -326
	panel.offset_top = 16
	panel.offset_right = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "ТРЕНИРОВКА · рыцарь №1"
	rows.add_child(title)
	health_label = Label.new()
	rows.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 16
	health_bar.show_percentage = false
	rows.add_child(health_bar)
	attack_button = _button("Ударить NPC", request_attack, rows)
	npc_toggle = CheckButton.new()
	npc_toggle.text = "NPC атакует меня"
	npc_toggle.focus_mode = Control.FOCUS_NONE
	npc_toggle.toggled.connect(set_npc_attacking)
	rows.add_child(npc_toggle)
	var walking := CheckButton.new()
	walking.text = "Идти шагом (Walk / Run)"
	walking.focus_mode = Control.FOCUS_NONE
	walking.toggled.connect(func(enabled: bool): hero.move_speed = 1.1 if enabled else hero.MOVE_SPEED)
	rows.add_child(walking)
	_button("Возродиться / сбросить бой", reset_arena, rows)
	_button("К тренировке — крупный план", focus_arena, rows)
	var speed_label := Label.new()
	speed_label.text = "Скорость теста: 1.00×"
	rows.add_child(speed_label)
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.25
	speed_slider.max_value = 1.5
	speed_slider.step = 0.05
	speed_slider.value = 1.0
	speed_slider.focus_mode = Control.FOCUS_NONE
	speed_slider.value_changed.connect(func(value: float):
		test_speed = value
		speed_label.text = "Скорость теста: %.2f×" % value)
	rows.add_child(speed_slider)
	clip_label = Label.new()
	clip_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(clip_label)
	var hint := Label.new()
	hint.text = "Красный бессмертен. Синий: 100 HP.\nАтаки и смерти — случайно без повтора подряд.\nХодьба/бег — обычный ПКМ по карте."
	hint.add_theme_font_size_override("font_size", 11)
	rows.add_child(hint)

func reset_arena() -> void:
	if world.current_cells.is_empty(): return
	active = true
	jobs.clear()
	health = 100
	dead = false
	npc_attacking = false
	hero_requested = false
	npc_cooldown = 0.5
	npc_hits = 0
	npc_toggle.set_pressed_no_signal(false)
	world.rts.orders.stop([hero])
	hero.movement_locked = false
	npc.movement_locked = false
	npc.stop_orders(world.map_renderer)
	hero.visual.player.stop()
	hero.visual.reset_pose()
	npc.visual.player.stop()
	npc.visual.reset_pose()
	var origin: Vector2i = world.map_renderer.world_to_cell(hero.global_position)
	var found := false
	for radius in range(2, 15):
		if found: break
		for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var cell: Vector2i = origin + direction * radius
			if not world.map_renderer.is_land(cell): continue
			if world.pathfinder.find_path(origin, cell).is_empty(): continue
			var point: Vector3 = world.map_renderer.cell_to_world(cell.x, cell.y)
			var occupied := false
			for unit in world.player_units:
				if unit.global_position.distance_to(point) < 1.0: occupied = true
			if occupied: continue
			npc.place_on_cell(cell, point)
			found = true
			break
	if not found:
		active = false
		last_message = "Нет места для NPC — создайте новую карту"
	else:
		last_message = "Готов к тренировке"
		hero.visual.rotation.y = _angle(hero, npc)
		npc.visual.rotation.y = _angle(npc, hero)
	npc.visible = active
	_update_panel()

func focus_arena() -> void:
	world.rts.set_selection([hero])
	world.game_camera.size = 7.0
	world.game_camera.focus_on((hero.global_position + npc.global_position) * 0.5)

func request_attack() -> void:
	if dead or not active or jobs.has(hero): return
	hero_requested = true
	last_message = "Подходим к красному NPC"
	path_timer = 0.0

func set_npc_attacking(value: bool) -> void:
	npc_attacking = value and not dead and active
	npc_toggle.set_pressed_no_signal(npc_attacking)
	if not npc_attacking:
		_cancel_action(npc)
		npc.stop_orders(world.map_renderer)
	path_timer = 0.0

func pick_clip(category: String, choices: Array) -> String:
	# Shuffle bag: see every variant before refilling; never repeat at boundary.
	var bag: Array = bags.get(category, [])
	if bag.is_empty():
		bag = choices.duplicate()
		for index in range(bag.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var value = bag[index]
			bag[index] = bag[other]
			bag[other] = value
		if bag.size() > 1 and bag.back() == previous.get(category, ""):
			var value = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = value
	var clip: String = bag.pop_back()
	bags[category] = bag
	previous[category] = clip
	return clip

func _angle(actor: TestUnit3D, target: TestUnit3D) -> float:
	var direction := target.global_position - actor.global_position
	return atan2(direction.x, direction.z)

func _cancel_action(actor: TestUnit3D) -> void:
	jobs.erase(actor)
	if actor == hero and dead: return
	actor.movement_locked = false
	actor.visual.player.speed_scale = 1.0
	actor.visual.player.play("idle", 0.2)

func _start_attack(actor: TestUnit3D, target: TestUnit3D) -> void:
	if jobs.has(actor) or dead: return
	if actor == hero: world.rts.orders.stop([hero])
	else: npc.stop_orders(world.map_renderer)
	actor.movement_locked = true
	var clip := pick_clip("attack", ATTACKS)
	actor.visual.player.speed_scale = test_speed
	actor.visual.player.play(clip, 0.18)
	var length: float = actor.visual.player.get_animation(clip).length
	# Two contacts for combo, one for splash. Temporary hit timing, not sword collision.
	var impacts: Array = [0.95, 2.35] if clip == "Attack_Combo" else [0.65]
	jobs[actor] = {"target": target, "clip": clip, "time": 0.0, "length": length, "impacts": impacts}
	last_message = ("Синий: " if actor == hero else "Красный: ") + clip

func _die() -> void:
	dead = true
	hero_requested = false
	npc_attacking = false
	npc_toggle.set_pressed_no_signal(false)
	jobs.erase(hero)
	_cancel_action(npc)
	world.rts.orders.stop([hero])
	npc.stop_orders(world.map_renderer)
	hero.movement_locked = true
	var clip := pick_clip("death", DEATHS)
	hero.visual.player.speed_scale = test_speed
	hero.visual.player.play(clip, 0.2)
	last_message = "Синий погиб: " + clip

func _approach(actor: TestUnit3D, target: TestUnit3D) -> void:
	if actor.movement_locked: return
	var start: Vector2i = world.map_renderer.world_to_cell(actor.global_position)
	var finish: Vector2i = world.map_renderer.world_to_cell(target.global_position)
	var path: Array[Vector2i] = world.pathfinder.find_path(start, finish)
	if path.size() > 1:
		if actor == hero: world.rts.orders.stop([hero])
		actor.follow_path(path, world.map_renderer)
	else:
		last_message = "Нет пути к сопернику"
		if actor == hero: hero_requested = false

func _process(delta: float) -> void:
	if not active: return
	if dead: hero.visual.player.speed_scale = test_speed
	path_timer -= delta
	npc_cooldown -= delta * test_speed
	for actor in jobs.keys():
		if not jobs.has(actor): continue
		var job: Dictionary = jobs[actor]
		actor.visual.rotation.y = lerp_angle(actor.visual.rotation.y, _angle(actor, job.target), 1.0 - exp(-12.0 * delta))
		actor.visual.player.speed_scale = test_speed
		job.time += delta * test_speed
		while not job.impacts.is_empty() and job.time >= job.impacts[0]:
			job.impacts.pop_front()
			if actor.global_position.distance_to(job.target.global_position) <= REACH + 0.35:
				if actor == npc and not dead:
					health = maxi(0, health - 20)
					if health == 0:
						_die()
						break
				elif actor == hero:
					npc_hits += 1
		if not jobs.has(actor): continue
		if job.time >= job.length:
			_cancel_action(actor)
			if actor == npc: npc_cooldown = 0.75
	if not dead:
		var distance := hero.global_position.distance_to(npc.global_position)
		if hero_requested and not jobs.has(hero):
			if distance <= REACH:
				hero_requested = false
				_start_attack(hero, npc)
			elif path_timer <= 0: _approach(hero, npc)
		if npc_attacking and not jobs.has(npc) and npc_cooldown <= 0:
			if distance <= REACH: _start_attack(npc, hero)
			elif path_timer <= 0: _approach(npc, hero)
	if path_timer <= 0: path_timer = 0.5
	_update_panel()

func _update_panel() -> void:
	health_label.text = "Синий: %d / 100 HP  ·  Красный: ∞" % health
	health_bar.value = health
	attack_button.disabled = dead or not active or jobs.has(hero) or hero_requested
	npc_toggle.disabled = dead or not active
	clip_label.text = "%s\nПопаданий по NPC: %d" % [last_message, npc_hits]
