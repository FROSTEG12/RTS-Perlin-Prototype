extends Node3D

signal network_world_synchronized(seed_value: int)

const DEFAULT_MAP_SIZE := 104
const DEFAULT_SCALE := 34.0
const DEFAULT_WATER := 40
const DEFAULT_RESOURCE_DENSITY := 130
const MINUTES_PER_DAY := 12.0
const DAY_NIGHT_LIGHTING := preload("res://scripts/day_night_lighting.gd")
const NETWORK_SESSION := preload("res://scripts/network_session.gd")
const NETWORK_PLAYER_SCENE := preload("res://scenes/network_player.tscn")
const TEMP_BUILDING_SCENE := preload("res://assets/temporary_building/house4.18.fbx")
const TEMP_BUILDING_FOOTPRINT := 4.5
const NETWORK_SNAPSHOT_INTERVAL := 0.1

@onready var map_renderer: MapRenderer3D = $MapRenderer
@onready var test_unit: TestUnit3D = $MapRenderer/TestUnit
@onready var game_camera: IsometricGameCamera = $GameCamera
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var temporary_buildings: Node3D = $TemporaryBuildings
@onready var new_map_button: Button = $UI/MapControls/Margin/Rows/NewMapButton
@onready var building_button: Button = $UI/MapControls/Margin/Rows/BuildingButton
@onready var seed_label: Label = $UI/MapControls/Margin/Rows/SeedLabel
@onready var time_label: Label = $UI/MapControls/Margin/Rows/TimeLabel
@onready var time_slider: HSlider = $UI/MapControls/Margin/Rows/TimeSlider

var world_seed: int
var current_cells := PackedByteArray()
var pathfinder := GridPathfinder.new()
var is_generating := false
var is_placing_building := false
var current_time := 8.0
var current_day := 1
var simulation_speed := 1.0
var weather: Node3D
var network_session: NetworkSession
var network_snapshot_elapsed := 0.0
var network_address: LineEdit
var network_host_button: Button
var network_join_button: Button
var network_leave_button: Button
var network_status: Label
var network_players_root: Node3D
var local_network_player: NetworkPlayer3D
var remote_players: Dictionary[int, NetworkPlayer3D] = {}
var player_spawn_cells: Dictionary[int, Vector2i] = {}


func _ready() -> void:
	network_session = NETWORK_SESSION.new()
	network_session.name = "NetworkSession"
	add_child(network_session)
	network_session.status_changed.connect(_on_network_status_changed)
	network_session.host_started.connect(_on_host_started)
	network_session.connected_to_host.connect(_on_connected_to_host)
	network_session.peer_joined.connect(_on_network_peer_joined)
	network_session.peer_left.connect(_on_network_peer_left)
	network_session.join_failed.connect(_return_to_offline)
	network_session.host_disconnected.connect(_return_to_offline)
	$UI/MapControls/Margin/Rows/ColorGradeToggle.toggled.connect(_on_color_grade_toggled)
	$UI/MapControls/Margin/Rows/ColorGradeStrength.value_changed.connect(_on_color_grade_strength)
	_on_color_grade_strength($UI/MapControls/Margin/Rows/ColorGradeStrength.value)
	world_seed = int(Time.get_unix_time_from_system()) % 2_000_000_000
	weather = preload("res://scripts/weather_effects.gd").new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(game_camera, test_unit, world_seed)
	network_players_root = Node3D.new()
	network_players_root.name = "NetworkPlayers"
	map_renderer.add_child(network_players_root)
	_setup_weather_controls()
	_setup_network_controls()
	time_slider.value_changed.connect(_on_time_slider_changed)
	_set_time_of_day(current_time)
	new_map_button.pressed.connect(_on_new_map_pressed)
	building_button.toggled.connect(_on_building_button_toggled)
	generate_world()
	_update_network_controls()
	_sync_weather_controls()


func _process(delta: float) -> void:
	var hours_per_second := 24.0 / (MINUTES_PER_DAY * 60.0)
	var game_hours := delta * hours_per_second * simulation_speed
	# Shared elapsed clock for date, weather and lighting. The lighting slider
	# is an explicit preview override; it does not fabricate elapsed days.
	current_day += floori((current_time + game_hours) / 24.0)
	weather.climate.advance(delta, game_hours, current_time)
	_set_time_of_day(fmod(current_time + game_hours, 24.0))
	_sync_weather_controls()
	if network_session != null and network_session.has_connection():
		network_snapshot_elapsed += delta
		if network_snapshot_elapsed >= NETWORK_SNAPSHOT_INTERVAL:
			network_snapshot_elapsed = fmod(network_snapshot_elapsed, NETWORK_SNAPSHOT_INTERVAL)
			if network_session.is_host():
				_broadcast_network_snapshot()


func _on_color_grade_toggled(_enabled: bool) -> void:
	_on_color_grade_strength($UI/MapControls/Margin/Rows/ColorGradeStrength.value)


func _on_color_grade_strength(amount: float) -> void:
	var effect = world_environment.compositor.compositor_effects[0]
	effect.enabled = $UI/MapControls/Margin/Rows/ColorGradeToggle.button_pressed and amount > 0.0
	# Hue and tint are OKHSL controls supplied by Rytelier's effect.
	effect.shadows = Vector4(0.65, 0.055 * amount, lerpf(1.0, 1.18, amount), lerpf(1.0, 0.84, amount))
	effect.midtones = Vector4(0.30, 0.025 * amount, lerpf(1.0, 1.65, amount), lerpf(1.0, 1.12, amount))
	effect.highlights = Vector4(0.12, 0.055 * amount, lerpf(1.0, 1.08, amount), lerpf(1.0, 0.96, amount))
	effect.night_noise = 0.0


func _on_time_slider_changed(value: float) -> void:
	_set_time_of_day(value)


func _set_time_of_day(value: float) -> void:
	current_time = fposmod(value, 24.0)
	_apply_day_night_lighting()
	time_slider.set_value_no_signal(current_time)
	var hour := floori(current_time)
	var minute := floori(fmod(current_time, 1.0) * 60.0)
	time_label.text = "День %d · %02d:%02d" % [current_day, hour, minute]


func _apply_day_night_lighting() -> void:
	DAY_NIGHT_LIGHTING.apply(current_time, key_light, world_environment.environment)
	preload("res://scripts/tree_resources.gd").update_shadow_direction(map_renderer, -key_light.global_basis.z)
	if weather != null:
		weather.update_visuals(current_time, key_light, world_environment.environment)
	map_renderer.WORLD_EDGE.set_mist_color(map_renderer, world_environment.environment.background_color)


func _on_building_button_toggled(enabled: bool) -> void:
	if network_session != null and network_session.is_online():
		building_button.set_pressed_no_signal(false)
		is_placing_building = false
		return
	is_placing_building = enabled
	building_button.text = "Кликните по суше…" if enabled else "Поставить дом"


func _place_temporary_building(world_position: Vector3) -> void:
	var building := TEMP_BUILDING_SCENE.instantiate() as Node3D
	if building == null:
		push_error("Temporary FBX root is not a Node3D")
		return
	temporary_buildings.add_child(building)
	_normalize_temporary_building_materials(building)
	var bounds := _get_model_bounds(building)
	var footprint := maxf(bounds.size.x, bounds.size.z)
	var uniform_scale := TEMP_BUILDING_FOOTPRINT / footprint if footprint > 0.001 else 1.0
	building.scale = Vector3.ONE * uniform_scale
	building.position = Vector3(
		world_position.x,
		MapRenderer3D.LAND_Y + 0.02 - bounds.position.y * uniform_scale,
		world_position.z
	)
	weather.refresh_world(map_renderer.get_half_extent())


func _normalize_temporary_building_materials(root: Node3D) -> void:
	# The source FBX flags every material as emissive and stores several diffuse
	# colors with partial alpha. Both make it turn white by day and reveal only
	# fragments of its textures at night.
	var corrected_materials := {}
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if not source is StandardMaterial3D:
				continue
			var source_id := source.get_instance_id()
			if not corrected_materials.has(source_id):
				var corrected := source.duplicate() as StandardMaterial3D
				corrected.emission_enabled = false
				corrected.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				corrected.albedo_color.a = 1.0
				corrected.roughness = 0.82
				corrected_materials[source_id] = corrected
			mesh_instance.set_surface_override_material(surface_index, corrected_materials[source_id])


func _get_model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var root_inverse := root.global_transform.affine_inverse()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative_transform := root_inverse * mesh_instance.global_transform
		var child_bounds := relative_transform * mesh_instance.get_aabb()
		result = result.merge(child_bounds) if has_bounds else child_bounds
		has_bounds = true
	return result


func generate_world() -> void:
	for building in temporary_buildings.get_children():
		building.queue_free()
	var generator := MapGenerator.new()
	var map_data := generator.generate_map(world_seed, DEFAULT_SCALE, DEFAULT_WATER, DEFAULT_MAP_SIZE)
	var generated_resources := generator.generate_resources(
		map_data["cells"], DEFAULT_MAP_SIZE, world_seed, DEFAULT_RESOURCE_DENSITY
	)
	current_cells = map_data["cells"]
	pathfinder.setup(current_cells, DEFAULT_MAP_SIZE)
	map_renderer.set_world(current_cells, DEFAULT_MAP_SIZE, generated_resources, map_data["bathymetry"])
	var cloud_random := RandomNumberGenerator.new()
	cloud_random.seed = world_seed ^ 0x5A17C9E3
	map_renderer.set_cloud_shadow_offset(Vector2(
		cloud_random.randf_range(-10_000.0, 10_000.0),
		cloud_random.randf_range(-10_000.0, 10_000.0)
	))
	game_camera.configure_map(map_renderer.get_half_extent())
	var spawn_cell := generator.find_mainland_spawn(current_cells, DEFAULT_MAP_SIZE)
	test_unit.set_trail_wear(map_renderer.trail_wear)
	test_unit.place_on_cell(spawn_cell, map_renderer.cell_to_world(spawn_cell.x, spawn_cell.y))
	seed_label.text = "Seed: %d  •  Вода: %d%%" % [world_seed, int(map_data["water_percent"])]
	if weather != null:
		weather.refresh_world(map_renderer.get_half_extent())


func _setup_weather_controls() -> void:
	var rows := $UI/MapControls/Margin/Rows
	time_slider.tooltip_text = "Проверка освещения: переводит часы, но не проматывает погоду. Для смены погоды используй скорость времени."
	var speed := OptionButton.new()
	speed.name = "SimulationSpeed"
	for value in [1, 3, 6]:
		speed.add_item("Время ×%d" % value)
	speed.tooltip_text = "Ускоряет часы, смену дней и погоду вместе. Не ускоряет юнита или анимации."
	speed.item_selected.connect(func(index: int): simulation_speed = [1.0, 3.0, 6.0][index])
	rows.add_child(speed)
	var separator := HSeparator.new()
	rows.add_child(separator)
	var automatic := CheckButton.new()
	automatic.name = "AutoWeather"
	automatic.text = "Автопогода"
	automatic.button_pressed = true
	automatic.toggled.connect(func(enabled: bool): weather.climate.automatic = enabled)
	rows.add_child(automatic)
	var rain := CheckButton.new()
	rain.name = "RainToggle"
	rain.text = "Дождь"
	rain.tooltip_text = "Ручное управление дождём. Автопогода отключится; переход занимает несколько секунд."
	rain.toggled.connect(func(enabled: bool):
		weather.climate.set_rain(enabled)
		automatic.set_pressed_no_signal(false))
	rows.add_child(rain)
	var fog := CheckButton.new()
	fog.name = "FogPreview"
	fog.text = "Туман: тест"
	fog.tooltip_text = "Показать плотный туман в любое время. Выключение возвращает естественный расчёт."
	fog.toggled.connect(func(enabled: bool): weather.climate.fog_override = 0.95 if enabled else -1.0)
	rows.add_child(fog)
	var focus := Button.new()
	focus.text = "К юниту"
	focus.pressed.connect(func():
		game_camera.global_position = test_unit.global_position + game_camera.global_basis.z * (18.0 / game_camera.global_basis.z.y)
		game_camera._clamp_position())
	rows.add_child(focus)
	var status := Label.new()
	status.name = "WeatherStatus"
	status.add_theme_font_size_override("font_size", 12)
	rows.add_child(status)


func _sync_weather_controls() -> void:
	var rows := $UI/MapControls/Margin/Rows
	rows.get_node("AutoWeather").set_pressed_no_signal(weather.climate.automatic)
	var requested_rain: bool = weather.climate.phase == weather.MODEL.Phase.RAIN if weather.climate.automatic else weather.climate.manual_rain
	rows.get_node("RainToggle").set_pressed_no_signal(requested_rain)
	rows.get_node("WeatherStatus").text = "%s · Влажность %d%%" % [weather.climate.description(), roundi(weather.climate.moisture * 100.0)]


func _on_new_map_pressed() -> void:
	if is_generating or (network_session != null and network_session.is_online()):
		return
	is_generating = true
	new_map_button.disabled = true
	new_map_button.text = "Генерация…"
	await get_tree().process_frame
	test_unit.cancel_movement(map_renderer)
	var random := RandomNumberGenerator.new()
	random.randomize()
	world_seed = random.randi_range(1, 2_000_000_000)
	generate_world()
	new_map_button.text = "Новая карта"
	new_map_button.disabled = false
	is_generating = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_placing_building:
			building_button.button_pressed = false
			get_viewport().set_input_as_handled()
			return
		test_unit.cancel_movement(map_renderer)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ground_position := game_camera.screen_to_ground(event.position, MapRenderer3D.LAND_Y)
		if not ground_position.is_finite():
			return
		var target := map_renderer.world_to_cell(ground_position)
		if not map_renderer.is_land(target):
			return
		if is_placing_building:
			_place_temporary_building(map_renderer.cell_to_world(target.x, target.y))
			get_viewport().set_input_as_handled()
			return
		var current_cell := test_unit.nearest_route_cell(map_renderer)
		var path := pathfinder.find_path(current_cell, target)
		if not path.is_empty():
			test_unit.follow_path(path, map_renderer)
			get_viewport().set_input_as_handled()


func _setup_network_controls() -> void:
	var rows := $UI/MapControls/Margin/Rows
	rows.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Сетевой прототип"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	network_address = LineEdit.new()
	network_address.placeholder_text = "IP хоста"
	network_address.text = "127.0.0.1"
	network_address.tooltip_text = "IP-адрес компьютера, создавшего матч"
	rows.add_child(network_address)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	rows.add_child(actions)
	network_host_button = Button.new()
	network_host_button.text = "Создать"
	network_host_button.pressed.connect(func(): network_session.start_host())
	actions.add_child(network_host_button)
	network_join_button = Button.new()
	network_join_button.text = "Войти"
	network_join_button.pressed.connect(func(): network_session.join_host(network_address.text))
	actions.add_child(network_join_button)
	network_leave_button = Button.new()
	network_leave_button.text = "Выйти"
	network_leave_button.pressed.connect(_return_to_offline)
	actions.add_child(network_leave_button)
	network_status = Label.new()
	network_status.text = "Автономная игра"
	network_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	network_status.add_theme_font_size_override("font_size", 11)
	rows.add_child(network_status)


func _on_network_status_changed(message: String) -> void:
	if network_status != null:
		network_status.text = message
	_update_network_controls()


func _update_network_controls() -> void:
	if network_session == null or network_host_button == null:
		return
	var online := network_session.is_online()
	var client := online and not network_session.is_host()
	network_host_button.disabled = online
	network_join_button.disabled = online
	network_leave_button.disabled = not online
	network_address.editable = not online
	new_map_button.disabled = online or is_generating
	building_button.disabled = online
	var rows := $UI/MapControls/Margin/Rows
	for control_name in ["TimeSlider", "SimulationSpeed", "AutoWeather", "RainToggle", "FogPreview"]:
		var control := rows.get_node_or_null(control_name) as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
			if control is BaseButton:
				(control as BaseButton).disabled = client
			elif control is Slider:
				(control as Slider).editable = not client
			control.modulate.a = 0.55 if client else 1.0


func _on_host_started() -> void:
	network_snapshot_elapsed = 0.0
	_clear_remote_players()
	player_spawn_cells = {1: test_unit.grid_cell}
	_ensure_network_player(1, test_unit.global_position)
	_update_network_controls()
	_update_match_status()


func _on_connected_to_host() -> void:
	network_snapshot_elapsed = 0.0
	_update_network_controls()


func _on_network_peer_joined(peer_id: int) -> void:
	if network_session.is_host() and peer_id != 1:
		var spawn_cell := _find_network_spawn_cell()
		player_spawn_cells[peer_id] = spawn_cell
		var spawn_position := map_renderer.cell_to_world(spawn_cell.x, spawn_cell.y)
		_ensure_network_player(peer_id, spawn_position)
		_add_network_player.rpc(peer_id, spawn_cell)
		_receive_world.rpc_id(
			peer_id,
			world_seed,
			current_time,
			current_day,
			simulation_speed,
			_weather_state(),
			_network_time(),
			_collect_player_states()
		)
		_update_match_status()


func _on_network_peer_left(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	player_spawn_cells.erase(peer_id)
	if network_session.is_host() and network_status != null:
		network_status.text = "Игрок %d отключился · осталось %d" % [peer_id, _player_count()]


func _return_to_offline() -> void:
	if network_session != null and network_session.is_online():
		network_session.stop()
	_clear_remote_players()
	player_spawn_cells.clear()
	if network_status != null:
		network_status.text = "Автономная игра"
	_update_network_controls()


@rpc("authority", "call_remote", "reliable", 0)
func _receive_world(
	seed_value: int,
	hour: float,
	day: int,
	speed: float,
	climate_state: Dictionary,
	sample_time: float,
	player_states: Array
) -> void:
	world_seed = seed_value
	weather.climate.reset(world_seed, hour)
	generate_world()
	var synchronized_peer_ids: Array[int] = []
	for state in player_states:
		var peer_id: int = state.get("peer_id", 0)
		var spawn_cell: Vector2i = state.get("spawn_cell", Vector2i.ZERO)
		var world_position: Vector3 = state.get("position", Vector3.ZERO)
		synchronized_peer_ids.append(peer_id)
		player_spawn_cells[peer_id] = spawn_cell
		if peer_id == multiplayer.get_unique_id():
			test_unit.place_on_cell(spawn_cell, world_position)
		var player := _ensure_network_player(peer_id, world_position)
		if peer_id != multiplayer.get_unique_id():
			player.apply_snapshot(world_position, sample_time)
	for peer_id in remote_players.keys():
		if peer_id not in synchronized_peer_ids:
			_remove_remote_player(peer_id)
	for peer_id in player_spawn_cells.keys():
		if peer_id not in synchronized_peer_ids:
			player_spawn_cells.erase(peer_id)
	_apply_host_timeline(hour, day, speed, climate_state, sample_time)
	_update_match_status()
	network_world_synchronized.emit(world_seed)


func _broadcast_network_snapshot() -> void:
	if not network_session.is_host():
		return
	_receive_network_snapshot.rpc(
		current_time,
		current_day,
		simulation_speed,
		_weather_state(),
		_network_time(),
		_collect_player_states()
	)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_network_snapshot(
	hour: float,
	day: int,
	speed: float,
	climate_state: Dictionary,
	sample_time: float,
	player_states: Array
) -> void:
	_apply_host_timeline(hour, day, speed, climate_state, sample_time)
	for state in player_states:
		var peer_id: int = state.get("peer_id", 0)
		if peer_id == multiplayer.get_unique_id():
			continue
		var world_position: Vector3 = state.get("position", Vector3.ZERO)
		var remote := _ensure_network_player(peer_id, world_position)
		remote.apply_snapshot(world_position, sample_time)


@rpc("authority", "call_remote", "reliable", 0)
func _add_network_player(peer_id: int, spawn_cell: Vector2i) -> void:
	player_spawn_cells[peer_id] = spawn_cell
	var spawn_position := map_renderer.cell_to_world(spawn_cell.x, spawn_cell.y)
	if peer_id == multiplayer.get_unique_id():
		test_unit.place_on_cell(spawn_cell, spawn_position)
	_ensure_network_player(peer_id, spawn_position)
	_update_match_status()


func _apply_host_timeline(
	hour: float,
	day: int,
	speed: float,
	climate_state: Dictionary,
	sample_time: float
) -> void:
	simulation_speed = speed
	_apply_weather_state(climate_state)
	var elapsed_seconds := 0.0
	var clock := get_node_or_null("/root/NetworkTime")
	if clock != null and clock.is_initial_sync_done():
		elapsed_seconds = maxf(clock.time - sample_time, 0.0)
	var game_hours := elapsed_seconds * 24.0 / (MINUTES_PER_DAY * 60.0) * speed
	current_day = day + floori((hour + game_hours) / 24.0)
	weather.climate.advance(elapsed_seconds, game_hours, hour)
	_set_time_of_day(fmod(hour + game_hours, 24.0))


func _collect_player_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var peer_ids := player_spawn_cells.keys()
	peer_ids.sort()
	for key in peer_ids:
		var peer_id: int = key
		var world_position := test_unit.global_position
		if peer_id != 1:
			var remote := remote_players.get(peer_id) as NetworkPlayer3D
			if remote != null:
				world_position = remote.network_position
		result.append({
			"peer_id": peer_id,
			"spawn_cell": player_spawn_cells[peer_id],
			"position": world_position,
		})
	return result


func _ensure_network_player(peer_id: int, spawn_position: Vector3) -> NetworkPlayer3D:
	if peer_id == multiplayer.get_unique_id() and local_network_player != null:
		return local_network_player
	var existing := remote_players.get(peer_id) as NetworkPlayer3D
	if existing != null:
		return existing
	var remote := NETWORK_PLAYER_SCENE.instantiate() as NetworkPlayer3D
	remote.name = "Player_%d" % peer_id
	network_players_root.add_child(remote)
	if peer_id == multiplayer.get_unique_id():
		remote.setup(peer_id, spawn_position, test_unit)
		local_network_player = remote
	else:
		remote.setup(peer_id, spawn_position)
		remote_players[peer_id] = remote
	return remote


func _remove_remote_player(peer_id: int) -> void:
	var remote := remote_players.get(peer_id) as NetworkPlayer3D
	if remote != null:
		remote.queue_free()
	remote_players.erase(peer_id)


func _clear_remote_players() -> void:
	if local_network_player != null:
		local_network_player.free()
		local_network_player = null
	for remote in remote_players.values():
		if is_instance_valid(remote):
			remote.free()
	remote_players.clear()


func _find_network_spawn_cell() -> Vector2i:
	var origin: Vector2i = player_spawn_cells.get(1, test_unit.grid_cell)
	for radius in range(4, 42):
		var candidates := [
			origin + Vector2i(radius, 0),
			origin + Vector2i(-radius, 0),
			origin + Vector2i(0, radius),
			origin + Vector2i(0, -radius),
			origin + Vector2i(radius, radius),
			origin + Vector2i(-radius, radius),
			origin + Vector2i(radius, -radius),
			origin + Vector2i(-radius, -radius),
		]
		for candidate in candidates:
			if not map_renderer.is_land(candidate):
				continue
			var occupied := false
			for existing in player_spawn_cells.values():
				if Vector2(candidate).distance_squared_to(Vector2(existing)) < 9.0:
					occupied = true
					break
			if not occupied and not pathfinder.find_path(origin, candidate).is_empty():
				return candidate
	return origin


func _player_count() -> int:
	return player_spawn_cells.size()


func _network_time() -> float:
	var clock := get_node_or_null("/root/NetworkTime")
	return clock.time if clock != null else Time.get_ticks_msec() / 1000.0


func _update_match_status() -> void:
	if network_status == null or not network_session.is_online():
		return
	network_status.text = "%s · игроков %d · ID %d" % [
		"Хост" if network_session.is_host() else "Клиент",
		_player_count(),
		multiplayer.get_unique_id(),
	]


func _weather_state() -> Dictionary:
	var climate = weather.climate
	return {
		"phase": climate.phase,
		"remaining_hours": climate.remaining_hours,
		"wet_period": climate.wet_period,
		"period_remaining_hours": climate.period_remaining_hours,
		"automatic": climate.automatic,
		"manual_rain": climate.manual_rain,
		"rain": climate.rain,
		"cloud": climate.cloud,
		"fog": climate.fog,
		"moisture": climate.moisture,
		"wind": climate.wind,
		"storm_strength": climate.storm_strength,
		"fog_override": climate.fog_override,
	}


func _apply_weather_state(state: Dictionary) -> void:
	var climate = weather.climate
	climate.phase = state.get("phase", climate.phase)
	climate.remaining_hours = state.get("remaining_hours", climate.remaining_hours)
	climate.wet_period = state.get("wet_period", climate.wet_period)
	climate.period_remaining_hours = state.get("period_remaining_hours", climate.period_remaining_hours)
	climate.automatic = state.get("automatic", climate.automatic)
	climate.manual_rain = state.get("manual_rain", climate.manual_rain)
	climate.rain = state.get("rain", climate.rain)
	climate.cloud = state.get("cloud", climate.cloud)
	climate.fog = state.get("fog", climate.fog)
	climate.moisture = state.get("moisture", climate.moisture)
	climate.wind = state.get("wind", climate.wind)
	climate.storm_strength = state.get("storm_strength", climate.storm_strength)
	climate.fog_override = state.get("fog_override", climate.fog_override)
