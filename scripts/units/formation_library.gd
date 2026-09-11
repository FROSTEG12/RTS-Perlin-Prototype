extends RefCounted
signal changed
const PATH := "user://formations_v1.json"
const TYPES := ["infantry", "pikemen", "spearmen", "archers", "crossbowmen", "cavalry"]
const TYPE_NAMES := ["Пехота", "Пикинёры", "Копейщики", "Лучники", "Арбалетчики", "Кавалерия"]
var templates: Array = []
var bindings: Array = ["", "", "", "", "", ""]
var storage_path := PATH
var load_error := false

func _init(path: String = PATH) -> void:
	storage_path = path
	templates.append(default_template())
	load_storage()

static func default_template() -> Dictionary:
	var points: Array = []
	for y in range(-1,2):
		for x in range(-2,3): points.append([x,y])
	return {"id":"default", "name":"Стандартный 5 × 3", "slots":points, "spacing":1.0, "types":TYPES.duplicate()}

func load_storage() -> void:
	if not FileAccess.file_exists(storage_path): return
	var file := FileAccess.open(storage_path,FileAccess.READ)
	if file == null:
		load_error = true
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version") != 1 or not data.get("templates") is Array or not data.get("bindings") is Array:
		load_error = true
		return
	for entry in data.templates:
		if not entry is Dictionary or not validate(entry).is_empty() or str(entry.get("id", "")).is_empty() or not get_template(str(entry.id)).is_empty():
			load_error = true
			continue
		for point in entry.slots:
			point[0] = int(point[0])
			point[1] = int(point[1])
		templates.append(entry)
	if data.bindings.size() == 6:
		for i in 6:
			if data.bindings[i] is String and not get_template(data.bindings[i]).is_empty(): bindings[i] = data.bindings[i]
	else: load_error = true

static func validate(value: Dictionary) -> String:
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length() > 32: return "Название: от 1 до 32 символов"
	if not value.get("slots") is Array or value.slots.size() != 15: return "Нужно ровно 15 позиций"
	var seen := {}
	for point in value.slots:
		if not point is Array or point.size() != 2: return "Некорректная позиция"
		for number in point:
			if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number)) > 5 or float(number) != roundf(float(number)): return "Позиции должны быть на сетке"
		var key := Vector2i(point[0],point[1])
		if seen.has(key): return "Позиции не должны совпадать"
		seen[key] = true
	if not (value.get("spacing") is float or value.get("spacing") is int): return "Некорректный интервал"
	if not is_finite(float(value.spacing)) or value.spacing < 1 or value.spacing > 3: return "Интервал: от 1 до 3 м"
	if not value.get("types") is Array or value.types.is_empty(): return "Выбери хотя бы один тип войск"
	for type in value.types:
		if type not in TYPES: return "Неизвестный тип войск"
	return ""

func get_template(id: String) -> Dictionary:
	for item in templates:
		if item.id == id: return item.duplicate(true)
	return {}

func save_template(value: Dictionary) -> String:
	var error := validate(value)
	if not error.is_empty(): return error
	var entry := value.duplicate(true)
	entry.name = entry.name.strip_edges()
	entry.id = str(entry.get("id", ""))
	if entry.id.is_empty() or entry.id == "default": entry.id = "formation_%d" % Time.get_ticks_usec()
	var before := templates.duplicate(true)
	var found := false
	for i in templates.size():
		if templates[i].id == entry.id:
			templates[i] = entry
			found = true
	if not found: templates.append(entry)
	if not persist():
		templates = before
		return "Не удалось сохранить файл построений"
	changed.emit()
	return ""

func bind_slot(index: int, id: String) -> bool:
	if index < 0 or index >= 6 or (not id.is_empty() and get_template(id).is_empty()): return false
	var previous := bindings.duplicate()
	bindings[index] = id
	if not persist():
		bindings = previous
		return false
	changed.emit()
	return true

func persist() -> bool:
	# A malformed existing file must never be silently overwritten.
	if load_error: return false
	var custom := templates.filter(func(t): return t.id != "default")
	var file := FileAccess.open(storage_path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":1,"templates":custom,"bindings":bindings},"\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(storage_path+".tmp",storage_path) == OK

static func offsets(value: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var center := Vector2.ZERO
	for point in value.slots: center += Vector2(point[0],point[1])
	center /= value.slots.size()
	for point in value.slots: result.append((Vector2(point[0],point[1])-center)*float(value.spacing))
	return result
