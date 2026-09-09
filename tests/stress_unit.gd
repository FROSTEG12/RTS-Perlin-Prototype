extends TestUnit3D
## Coarse instrumentation, only loaded by the standalone stress runner.
static var process_us := 0
static var preview_us := 0
func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	process_us += Time.get_ticks_usec() - started
func _rebuild_path_preview() -> void:
	var started := Time.get_ticks_usec()
	super._rebuild_path_preview()
	preview_us += Time.get_ticks_usec() - started
