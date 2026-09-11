extends RefCounted
## Compare progress along assigned routes, including regroup and Shift stages.
## Early soldiers walk; lagging soldiers keep their normal running speed.
const WALK_SPEED := 1.5
const JOIN_TOLERANCE := 0.45
const SPLIT_TOLERANCE := 1.4
const MODE_HOLD := 1.0
const SETTLE_TIME := 0.6
var tracks := {}

func begin(id: String, group: Array, queued: bool, starts_with_regroup: bool = false) -> void:
	if queued and tracks.has(id): return
	clear(id,false)
	var members := {}
	for unit in group:
		members[unit] = {"origin":unit.travelled_distance,"lengths":[],"revision":unit.order_revision,"walking":false,"mode_time":MODE_HOLD}
	tracks[id] = {"members":members,"stages":[],"regrouping":true,"settled":0.0,"starts_with_regroup":starts_with_regroup}

func add_stage(id: String, lengths: Dictionary) -> void:
	var longest := 0.0
	for unit in lengths: longest = maxf(longest,lengths[unit])
	tracks[id].stages.append(longest)
	for unit in lengths: tracks[id].members[unit].lengths.append(lengths[unit])

func clear(id: String, immediate: bool = true) -> void:
	if not tracks.has(id): return
	for unit in tracks[id].members:
		if is_instance_valid(unit):
			if immediate: unit.reset_formation_speed()
			else: unit.formation_speed_target = 1.0
	tracks.erase(id)

func reset() -> void:
	for id in tracks.keys(): clear(id)

func progress(unit: Unit3D, member: Dictionary, stages: Array) -> Vector2:
	var remaining := maxf(0,unit.travelled_distance-float(member.origin))
	var along := 0.0
	for i in stages.size():
		var length: float = member.lengths[i]
		if remaining < length-0.0001:
			return Vector2(along+remaining/length*float(stages[i]),i)
		remaining -= length
		along += float(stages[i])
	return Vector2(along,stages.size())

func update(delta: float = 0.0) -> void:
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
				unit.reset_formation_speed()
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
		track.settled = float(track.settled)+delta if spread <= JOIN_TOLERANCE else 0.0
		if track.settled >= SETTLE_TIME: track.regrouping = false
		elif spread > SPLIT_TOLERANCE: track.regrouping = true
		for unit in positions:
			var ahead: float = positions[unit].x-slowest
			var member: Dictionary = track.members[unit]
			member.mode_time += delta
			var wants_walk: bool = member.walking
			if not track.regrouping or ahead < 0.20: wants_walk = false
			elif ahead > 0.90: wants_walk = true
			# First run into the assigned regroup slot, then wait at a normal walk.
			if track.starts_with_regroup and positions[unit].y == 0: wants_walk = false
			if wants_walk != member.walking and member.mode_time >= MODE_HOLD:
				member.walking = wants_walk
				member.mode_time = 0.0
			var walking: bool = member.walking
			# Route-length ratios are for progress only, never physical speed.
			unit.formation_speed_target = minf(1.0,WALK_SPEED/maxf(unit.move_speed,0.001)) if walking else 1.0
