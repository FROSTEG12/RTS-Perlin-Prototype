extends Button
## Stable container slot; the complete tile slides within reserved headroom.
const ACCENT := Color("#82bfd6")
const TILE_SIZE := Vector2(128, 204)
const RISE := 18.0
const SLOT_HEIGHT := 222.0
var entry: Dictionary
var artwork: TextureRect
var face: Control
var footer_style: StyleBoxFlat
var marker: ColorRect
var slide: Tween
var last_selected := false

func _init(value: Dictionary = {}) -> void:
	entry = value
	custom_minimum_size = Vector2(TILE_SIZE.x, SLOT_HEIGHT)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	tooltip_text = str(value.get("title", ""))
	var detail := str(value.get("description", ""))
	if not detail.is_empty() and detail != tooltip_text: tooltip_text += "\n" + detail
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _ready() -> void:
	face = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = Vector2(0, RISE)
	face.size = TILE_SIZE
	add_child(face)
	var layout := VBoxContainer.new()
	face.add_child(layout)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	artwork = TextureRect.new()
	artwork.texture = entry.get("preview")
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.custom_minimum_size.y = 170
	artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(artwork)
	var foot := PanelContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.custom_minimum_size.y = 34
	footer_style = StyleBoxFlat.new()
	footer_style.bg_color = Color("#081219eb")
	footer_style.content_margin_top = 5
	footer_style.content_margin_bottom = 5
	foot.add_theme_stylebox_override("panel", footer_style)
	layout.add_child(foot)
	var glyph := TextureRect.new()
	glyph.texture = entry.get("glyph")
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(24, 24)
	glyph.modulate = Color("#f0f1ee")
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(glyph)
	marker = ColorRect.new()
	marker.color = ACCENT
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(marker)
	marker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	marker.offset_top = -3
	marker.hide()
	toggled.connect(func(_pressed: bool): refresh_selection())
	resized.connect(_resize_face)
	_resize_face()
	refresh_selection()

func _resize_face() -> void:
	if face: face.size = Vector2(size.x, TILE_SIZE.y)

func refresh_selection() -> void:
	if not face: return
	marker.visible = button_pressed
	footer_style.bg_color = Color("#193443f5") if button_pressed else Color("#081219eb")
	if last_selected == button_pressed: return
	last_selected = button_pressed
	if slide and slide.is_valid(): slide.kill()
	slide = create_tween()
	slide.tween_property(face, "position:y", 0.0 if button_pressed else RISE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_visual_rect() -> Rect2:
	return face.get_global_rect() if face else get_global_rect()

func _has_point(point: Vector2) -> bool:
	return Rect2(face.position, face.size).has_point(point) if face else false
