extends Node
## A bounded UI pixel scale, independent of the 3D rendering resolution.
## At 1080p 1 UI unit = 1 pixel; at 4K only 1.4 pixels, not 3 pixels.
var pending := false

static func scale_for(window_size: Vector2i) -> float:
	var height := float(window_size.y)
	return clampf(1.0 + (height - 1080.0) / 2700.0, 1.0, 1.4)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size_changed.connect(_schedule)
	refresh()

func _schedule() -> void:
	if pending: return
	pending = true
	refresh.call_deferred()

func refresh() -> void:
	pending = false
	var window := get_window()
	var pixels := window.size
	# Ignore startup/minimized placeholder surfaces below the supported minimum.
	# A headless Window also starts at 64x64 before a test sets its dimensions.
	if pixels.x < 960 or pixels.y < 540: return
	var virtual_size := Vector2i((Vector2(pixels) / scale_for(pixels)).round())
	# Setting these does not resize the OS window or change its display mode.
	# Guards also prevent a resize-signal feedback loop.
	if window.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if window.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if window.content_scale_size != virtual_size:
		window.content_scale_size = virtual_size
