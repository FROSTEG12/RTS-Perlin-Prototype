extends RefCounted
## Selection/command policy, separate from per-unit movement implementation.
static func members(unit: Unit3D, roster: Array) -> Array[Unit3D]:
	var result: Array[Unit3D] = []
	if not is_instance_valid(unit): return result
	if unit.individual_control:
		result.append(unit)
	elif unit.squad_id > 0:
		for candidate: Unit3D in roster:
			if is_instance_valid(candidate) and not candidate.individual_control and candidate.squad_id == unit.squad_id:
				result.append(candidate)
	return result

static func expand(requested: Array, roster: Array) -> Array[Unit3D]:
	var result: Array[Unit3D] = []
	for unit: Unit3D in requested:
		for member in members(unit, roster):
			if member not in result: result.append(member)
	return result
