extends RefCounted
## Six groups. Placement is owned by BuildingPlacement, not the menu.
static func preview(id: String) -> Texture2D:
	var filename := "fortress_walls_closeup" if id == "fortress_walls" else id
	var path := "res://assets/ui/buildings/" + filename + ".png"
	if id.begins_with("fortress_") and id != "fortress_walls": path = "res://assets/ui/buildings/modules/"+id.trim_prefix("fortress_")+".png"
	return load(path) if ResourceLoader.exists(path) else null

static func entry(id: String, title: String, description: String = "") -> Dictionary:
	if id=="sawmill": description="Стоимость: 30 дерева и 30 камня. До первого склада принимает оба ресурса."
	if id=="warehouse": description="Нужна готовая лесопилка. Стоимость: 30 дерева и 30 камня."
	return {"id": StringName(id), "title": title, "preview": preview(id), "description": description}

static func categories() -> Array:
	return [
		{"id": &"settlement", "title": "Управление поселением", "icon": preload("res://assets/ui/navigation/settlement.svg"), "items": [entry("town_hall", "Ратуша", "Ратуша с отдельной башней")]},
		{"id": &"housing", "title": "Жильё", "icon": preload("res://assets/ui/navigation/housing.svg"), "items": [entry("house", "Жилой дом")]},
		{"id": &"production", "title": "Производство", "icon": preload("res://assets/ui/resources/build.svg"), "items": [entry("smithy", "Кузница"), entry("sawmill", "Лесопилка")]},
		{"id": &"storage", "title": "Хранение ресурсов", "icon": preload("res://assets/ui/navigation/storage.svg"), "items": [entry("warehouse", "Склад", "Стоимость: 30 дерева и 30 камня. Принимает добытые ресурсы.")]},
		{"id": &"livestock", "title": "Животноводство", "icon": preload("res://assets/ui/navigation/livestock.svg"), "items": [entry("animal_pen", "Загон для животных")]},
		{"id": &"fortifications", "title": "Укрепления", "icon": preload("res://assets/ui/navigation/fortifications.svg"), "items": [entry("fortress_wall", "Секция стены"),entry("fortress_gate", "Ворота"),entry("fortress_round_tower", "Круглая башня"),entry("fortress_round_tower_alt", "Круглая башня II"),entry("fortress_square_tower", "Квадратная башня")]},
	]
