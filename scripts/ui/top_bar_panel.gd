extends PanelContainer
## Rounded, tapered HUD surface. Only the background is angled, never its content.
var slant_left := false
var flush_left := false

func _init(dock_left: bool = false) -> void:
	flush_left = dock_left
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = 18
	padding.content_margin_right = 18
	padding.content_margin_top = 8
	padding.content_margin_bottom = 8
	add_theme_stylebox_override("panel", padding)
	custom_minimum_size.y = 52
	# Both top bars use the same dense surface, including their tapered edge.
	# A horizontal alpha fade would wash out the backdrop behind the clock ring.
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 64 or h < 2: return
	var corners := PackedVector2Array([Vector2(22, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]) if slant_left else PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w - 22, h), Vector2(0, h)])
	var radii := [16.0, 20.0, 20.0, 16.0] if slant_left else [34.0, 16.0, 16.0, 34.0]
	if flush_left:
		radii[0] = 0.0
		radii[3] = 0.0
	var outline := PackedVector2Array()
	for i in 4:
		var corner := corners[i]
		var radius: float = minf(radii[i], h * 0.49)
		if is_zero_approx(radius):
			outline.append(corner)
			continue
		var before := corner.move_toward(corners[posmod(i - 1, 4)], radius)
		var after := corner.move_toward(corners[(i + 1) % 4], radius)
		for step in 13:
			var t := step / 12.0
			outline.append(before.lerp(corner, t).lerp(corner.lerp(after, t), t))
	var shadow := PackedVector2Array()
	var colors := PackedColorArray()
	for point in outline:
		shadow.append(point + Vector2(0, 2))
		# Background alpha only: labels and artwork remain fully opaque.
		colors.append(Color("#0c1720e0").lerp(Color("#081219eb"), point.y / h))
	draw_colored_polygon(shadow, Color("#00000008"))
	draw_polygon(outline, colors)
	outline.append(outline[0])
	draw_polyline(outline, Color("#40546024"), 1.0, true)
