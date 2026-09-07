extends Node
const SIZE := 104
const SPEED := 2.25
const STEP := 0.05
const CLIMATE_FIELDS := ["phase", "remaining_hours", "wet_period", "period_remaining_hours",
	"automatic", "manual_rain", "rain", "cloud", "fog", "moisture", "wind", "storm_strength", "fog_override"]
var seed_value := 1
var cells: PackedByteArray
var pathfinder := GridPathfinder.new()
var climate = preload("res://scripts/weather_model.gd").new()
var players := {}
var ready_peers := {}
var origin := Vector2i.ZERO
var hour := 8.0
var day := 1
var tick := 0
var last_usec := 0
var accumulator := 0.0
var empty_since := 0
var bridge: Node

func start(port: int, world_seed: int) -> Error:
	seed_value = world_seed
	var generator := MapGenerator.new()
	cells = generator.generate_map(seed_value, 34.0, 40, SIZE)["cells"]
	pathfinder.setup(cells, SIZE)
	origin = generator.find_mainland_spawn(cells, SIZE)
	climate.reset(seed_value)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, 4)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int):
		peer.get_peer(id).set_timeout(32, 60000, 120000))
	bridge = get_node("/root/MatchNetwork")
	bridge.server = self
	multiplayer.peer_disconnected.connect(func(id: int):
		players.erase(id)
		ready_peers.erase(id))
	last_usec = Time.get_ticks_usec()
	empty_since = Time.get_ticks_msec()
	print("DEDICATED_READY port=", port, " pid=", OS.get_process_id())
	return OK

func cell_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - (SIZE - 1) * 0.5, 0.1, cell.y - (SIZE - 1) * 0.5)

func position_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x + (SIZE - 1) * 0.5), roundi(pos.z + (SIZE - 1) * 0.5))

func send_world(id: int) -> void:
	if id not in multiplayer.get_peers():
		return
	if not players.has(id):
		var spawn := origin
		for radius in range(0, SIZE):
			var found := false
			for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
				var candidate: Vector2i = origin + offset
				if pathfinder.find_path(origin, candidate).is_empty():
					continue
				var occupied := false
				for p in players.values():
					if Vector2(p.spawn_cell).distance_to(Vector2(candidate)) < 3.0:
						occupied = true
				if not occupied:
					spawn = candidate
					found = true
					break
			if found:
				break
		players[id] = {"peer_id": id, "spawn_cell": spawn, "position": cell_position(spawn),
			"path": [], "target": spawn, "last_command": -1000}
	bridge.receive_world.rpc_id(id, snapshot())

func move_unit(id: int, target: Vector2i) -> void:
	if not players.has(id) or not ready_peers.has(id):
		return
	var p: Dictionary = players[id]
	if tick - p.last_command < 2 or target == p.target:
		return
	p.last_command = tick
	var route := pathfinder.find_path(position_cell(p.position), target)
	if route.is_empty():
		return
	# Start from current position; repeated clicks never return to the previous cell centre.
	route.pop_front()
	p.path = route
	p.target = target

func stop_unit(id: int) -> void:
	if players.has(id):
		players[id].path = []
		players[id].target = Vector2i(-1, -1)

func _process(_delta: float) -> void:
	if bridge == null:
		return
	var now := Time.get_ticks_usec()
	accumulator += (now - last_usec) / 1000000.0
	last_usec = now
	var steps := 0
	while accumulator >= STEP and steps < 20:
		accumulator -= STEP
		steps += 1
		tick += 1
		var hours := STEP / 30.0
		climate.advance(STEP, hours, hour)
		day += floori((hour + hours) / 24.0)
		hour = fmod(hour + hours, 24.0)
		for p in players.values():
			var remaining := SPEED * STEP
			while remaining > 0.0 and not p.path.is_empty():
				var target := cell_position(p.path[0])
				var distance: float = p.position.distance_to(target)
				p.position = p.position.move_toward(target, remaining)
				remaining -= distance
				if distance <= SPEED * STEP and p.position.is_equal_approx(target):
					p.path.pop_front()
				else:
					break
	if steps > 0:
		var state := snapshot()
		for id in ready_peers:
			bridge.receive_snapshot.rpc_id(id, state)
	if multiplayer.get_peers().is_empty():
		if Time.get_ticks_msec() - empty_since > 60000:
			get_tree().quit()
	else:
		empty_since = Time.get_ticks_msec()

func snapshot() -> Dictionary:
	var units: Array = []
	for p in players.values():
		units.append({"peer_id": p.peer_id, "spawn_cell": p.spawn_cell, "position": p.position,
			"route": p.path.duplicate()})
	var weather := {}
	for key in CLIMATE_FIELDS:
		weather[key] = climate.get(key)
	return {"seed": seed_value, "hour": hour, "day": day, "speed": 1.0,
		"weather": weather, "time": get_node("/root/NetworkTime").time, "tick": tick, "simulation_time": tick * STEP,
		"ready_count": ready_peers.size(), "players": units}
