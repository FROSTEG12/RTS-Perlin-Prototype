extends Control
## Click-open requirements card. Data stays in the catalog and real stockpile.
const RESOURCE_ICONS := {"Дерево": "wood", "Камень": "stone", "Металл": "metal", "Мясо": "meat", "Ягоды": "berries", "Уголь": "coal"}
const LIGHT := Color("#e9eceb")
const MUTED := Color("#a9b4ba")
const SHORTAGE := Color("#ff7373")
var title := ""
var class_emblem: Texture2D
var rows: Array[Dictionary] = []
var unknown_cost := false
var last_data: Array = []
var icons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for key in RESOURCE_ICONS:
		icons[key] = load("res://assets/ui/generated_resources/%s.png" % RESOURCE_ICONS[key])
	icons["Бойцы"] = load("res://assets/ui/generated_navigation/armies.png")

func set_details(entry: Dictionary, squad: Dictionary, stock: Dictionary) -> void:
	var data := [entry.title, entry.capacity, entry.requirements.duplicate(), squad.members, stock.duplicate()]
	if last_data == data: return
	last_data = data
	title = entry.title
	class_emblem = entry.emblem
	unknown_cost = entry.requirements.is_empty()
	rows.clear()
	rows.append({"label": "Бойцы", "value": "%d / %s" % [squad.members, str(entry.capacity) if entry.capacity > 0 else "—"], "color": SHORTAGE})
	for key in entry.requirements:
		var available := int(stock.get(key, 0))
		var needed := int(entry.requirements[key])
		rows.append({"label": str(key), "value": "%d / %d" % [available, needed], "color": SHORTAGE if available < needed else LIGHT})
	size = Vector2(280, 52 + rows.size() * 32 + (28 if unknown_cost else 12))
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_style_box(_surface(), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(1, 1, size.x - 2, 43), Color("#24343e"))
	draw_line(Vector2(12, 44), Vector2(size.x - 12, 44), Color("#71818a"), 1)
	if class_emblem: draw_texture_rect(class_emblem, Rect2(12, 7, 30, 30), false)
	draw_string(font, Vector2(50, 23), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 18, LIGHT)
	draw_string(font, Vector2(50, 38), "Не сформирован", HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 11, MUTED)
	for i in rows.size():
		var row := rows[i]
		var y := 52.0 + i * 32
		if icons.has(row.label): draw_texture_rect(icons[row.label], Rect2(14, y, 26, 26), false)
		draw_string(font, Vector2(48, y + 19), row.label, HORIZONTAL_ALIGNMENT_LEFT, 123, 13, LIGHT)
		draw_string(font, Vector2(173, y + 19), row.value, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 189, 16, row.color)
	if unknown_cost:
		draw_line(Vector2(14, size.y - 28), Vector2(size.x - 14, size.y - 28), Color("#39464e"), 1)
		draw_string(font, Vector2(14, size.y - 10), "Стоимость пока не задана", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 12, MUTED)

func _surface() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b141bf5")
	style.border_color = Color("#71818a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
