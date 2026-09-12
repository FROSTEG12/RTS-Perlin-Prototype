extends Sprite3D
var pixels := Image.create(96,12,false,Image.FORMAT_RGBA8)
var last_step := -1
func _ready() -> void:
	position.y=2.15
	billboard=BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test=true
	pixel_size=.009
	texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	texture=ImageTexture.create_from_image(pixels)
	set_progress(0)
	hide()
func set_progress(value: float) -> void:
	var step := clampi(int(value*94),0,94)
	if step==last_step: return
	last_step=step
	pixels.fill(Color.TRANSPARENT)
	for y in 12:
		for x in 96:
			var dx := maxf(5.5-x,x-89.5)
			var dy := absf(y-5.5)
			if Vector2(maxf(dx,0),dy).length()>5.5: continue
			var color := Color("#12212aea")
			if y==1 or y==10: color=Color("#637a85")
			elif y>=3 and y<=8 and x>=4 and x<=step: color=Color("#8fcbb8")
			pixels.set_pixel(x,y,color)
	texture.update(pixels)
