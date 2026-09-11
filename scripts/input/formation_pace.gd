extends RefCounted
## Compare progress along assigned routes, including regroup and Shift stages.
## Early soldiers walk; lagging soldiers keep their normal running speed.
const WALK_SPEED := 1.15
const JOIN_TOLERANCE := 0.28
const SPLIT_TOLERANCE := 0.85
var tracks := {}

func begin(id: String, group: Array, queued: bool) -> void:
	if queued and tracks.has(id): return
	clear(id)
	var members := {}
	for unit in group:
		members[unit] = {"origin":unit.travelled_distance,"lengths":[],"revision":unit.order_revision,"walking":false}
	tracks[id] = {"members":members,"stages":[],"regrouping":true}

func add_stage(id: String, lengths: Dictionary) -> void:
	var longest := 0.0
	for unit in lengths: longest = maxf(longest,lengths[unit])
	tracks[id].stages.append(longest)
	for unit in lengths: tracks[id].members[unit].lengths.append(lengths[unit])

func clear(id: String) -> void:
	if not tracks.has(id): return
	for unit in tracks[id].members:
		if is_instance_valid(unit): unit.formation_speed_scale = 1.0
	tracks.erase(id)

func reset() -> void:
	for id in tracks.keys(): clear(id)

func progress(unit: Unit3D, member: Dictionary, stages: Array) -> Vector2:
	var remaining := maxf(0,unit.travelled_distance-float(member.origin))
	var along := 0.0
	for i in stages.size():
		var length: float = member.lengths[i]
		if remaining < length-0.0001:
			return Vector2(along+remaining/length*float(stages[i]),length/maxf(stages[i],0.0001))
		remaining -= length
		along += float(stages[i])
	return Vector2(along,1)

func update() -> void:
	for id in tracks.keys():
		var track: Dictionary = tracks[id]
		var positions := {}
		var slowest := INF
		var fastest := 0.0
		var moving := false
		for unit in track.members.keys():
			if not is_instance_valid(unit):
				track.members.erase(unit)
				continue
			if unit.order_revision != track.members[unit].revision:
				unit.formation_speed_scale = 1.0
				track.members.erase(unit)
				continue
			var state := progress(unit,track.members[unit],track.stages)
			positions[unit] = state
			slowest = minf(slowest,state.x)
			fastest = maxf(fastest,state.x)
			moving = moving or not unit.target_positions.is_empty()
		if not moving:
			clear(id)
			continue
		var spread := fastest-slowest
		if spread <= JOIN_TOLERANCE: track.regrouping = false
		elif spread > SPLIT_TOLERANCE: track.regrouping = true
		for unit in positions:
			var ahead: float = positions[unit].x-slowest
			var member: Dictionary = track.members[unit]
			if not track.regrouping or ahead < 0.10: member.walking = false
			elif ahead > 0.55: member.walking = true
			var walking: bool = member.walking
			# Normalize detour lengths so a short-route walker cannot outrun a
			# long-route runner. No speed boosts, teleporting or path shortcuts.
			unit.formation_speed_scale = minf(1.0,WALK_SPEED/maxf(unit.move_speed,0.001))*minf(1.0,positions[unit].y) if walking else 1.0
