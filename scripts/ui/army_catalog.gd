extends RefCounted
## Fifteen soldiers per squad. Empty requirements mean unknown, NEVER free.
const MAX_SQUADS := 6
const TYPES := [
	{"id": "infantry", "title": "Пехотинцы", "head_y": 0.014},
	{"id": "pikemen", "title": "Пикинёры", "head_y": 0.185},
	{"id": "spearmen", "title": "Копейщики", "head_y": 0.088},
	{"id": "archers", "title": "Лучники", "head_y": 0.025},
	{"id": "crossbowmen", "title": "Арбалетчики", "head_y": 0.012},
]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for type in TYPES:
		var entry: Dictionary = type.duplicate()
		entry["portrait"] = load("res://assets/ui/armies/%s_cutout.png" % type.id)
		entry["emblem"] = load("res://assets/ui/army_emblems/%s.png" % type.id)
		entry["capacity"] = preload("res://scripts/units/squad_formation.gd").SIZE
		entry["requirements"] = {}
		result.append(entry)
	return result
