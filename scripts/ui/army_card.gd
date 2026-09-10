extends Button
signal removal_requested(card: Button)
signal details_requested(card: Button)
## Flat illustrated banner. Recruitment state lives in army_browser.
var entry: Dictionary
var recruitment := false
var pending := true
var count_text := "0 / —"
var art: TextureRect
var title_label: Label
var frame_front: Control
var warning_button: Button
const INK := Color("#0b1116f5")
const EDGE := Color("#e9eceb")
const DEFICIT := Color("#ff7373")

func _init(value: Dictionary = {}, choice: bool = false) -> void:
	entry = value
	recruitment = choice
	pending = not choice
	focus_mode = Control.FOCUS_NONE
	toggle_mode = not choice
	tooltip_text = ""
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _ready() -> void:
	art = TextureRect.new()
	art.texture = entry.get("portrait")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var readiness := ShaderMaterial.new()
	readiness.shader = preload("res://shaders/army_readiness.gdshader")
	art.material = readiness
	# True-alpha portrait is drawn above the recessed card. Never mask the head.
	add_child(art)
	# Foreground plaque hides the portrait's waist edge and joins the back frame.
	frame_front = Control.new()
	frame_front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_front)
	frame_front.draw.connect(_draw_front)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = entry.get("title", "")
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	warning_button = preload("res://scripts/ui/army_warning_button.gd").new()
	warning_button.toggle_mode = true
	add_child(warning_button)
	warning_button.pressed.connect(func(): details_requested.emit(self))
	warning_button.gui_input.connect(_on_gui_input)
	resized.connect(refresh)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_value: bool): refresh())
	refresh()
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if recruitment or not event is InputEventMouseButton: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		# Remove on release so both halves are consumed before this node disappears.
		if not event.pressed: removal_requested.emit(self)

func background_top() -> float:
	return footer_top() * 0.35

func footer_top() -> float:
	return size.y - (48.0 if size.x < 100 else 50.0)

func refresh() -> void:
	if not art: return
	# Normalize from crown to waist, not from the tallest weapon to the waist.
	var head_y: float = entry.get("head_y", 0.0)
	var height := (footer_top() - 2.0) / (1.0 - head_y)
	var aspect := float(art.texture.get_width()) / art.texture.get_height()
	art.size = Vector2(height * aspect, height)
	art.position = Vector2((size.x - art.size.x) * 0.5, 2.0 - height * head_y)
	art.material.set_shader_parameter("desaturated", pending or disabled)
	art.modulate = Color("#aaaaaa") if disabled else Color.WHITE
	frame_front.size = size
	frame_front.queue_redraw()
	title_label.position = Vector2(3, footer_top() + 16)
	title_label.size = Vector2(size.x - 6, 16)
	title_label.add_theme_font_size_override("font_size", 11 if size.x < 100 else 12)
	warning_button.visible = pending
	warning_button.position = Vector2(size.x - 34, background_top() - 8)
	warning_button.size = Vector2(34, 34)
	queue_redraw()

func _draw() -> void:
	if size.x < 10 or size.y < 10: return
	var h := footer_top() + 4
	var upper := background_top()
	var shape := PackedVector2Array([Vector2(size.x/2,upper),Vector2(size.x-5,upper+17),Vector2(size.x-5,h),Vector2(5,h),Vector2(5,upper+17)])
	draw_colored_polygon(shape, INK)
	_outline(self, shape, EDGE if button_pressed else Color("#a3aaac"), 1.2)
	var inner := PackedVector2Array([Vector2(size.x/2,upper+3),Vector2(size.x-8,upper+19),Vector2(size.x-8,h),Vector2(8,h),Vector2(8,upper+19)])
	_outline(self, inner, Color("#485158"), 0.7)

func _outline(canvas: CanvasItem, polygon: PackedVector2Array, color: Color, width: float) -> void:
	var closed := polygon.duplicate()
	closed.append(polygon[0])
	canvas.draw_polyline(closed, color, width, true)

func _draw_front() -> void:
	if size.x < 10 or size.y < 10: return
	var w := size.x
	var y := footer_top()
	var bottom := size.y - 2.0
	var mid := w * 0.5
	var plaque := PackedVector2Array([Vector2(7,y),Vector2(w-7,y),Vector2(w-1,y+6),Vector2(w-1,bottom-8),Vector2(w-7,bottom-3),Vector2(mid+14,bottom-3),Vector2(mid+11,bottom),Vector2(mid-11,bottom),Vector2(mid-14,bottom-3),Vector2(7,bottom-3),Vector2(1,bottom-8),Vector2(1,y+6)])
	frame_front.draw_colored_polygon(plaque, Color("#172027fa") if button_pressed else INK)
	_outline(frame_front, plaque, EDGE if button_pressed else Color("#a3aaac"), 1.2)
	# Class emblems are retained as assets, but no longer drawn on squad cards.
