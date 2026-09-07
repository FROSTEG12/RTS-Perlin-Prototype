extends RefCounted
## Presentation clock independent of render FPS and netfox's discrete tick clock.
const DELAY := 0.10
var latest := -1.0
var received_at := 0.0
var cursor := -1.0

func reset() -> void:
	latest = -1.0
	cursor = -1.0

func receive(server_time: float, now: float) -> void:
	if server_time <= latest:
		return
	latest = server_time
	received_at = now
	# Bound stale backlog after suspension; never replay seconds of old movement.
	cursor = maxf(cursor, latest - DELAY)

func render_time(now: float) -> float:
	if latest < 0.0:
		return 0.0
	cursor = maxf(cursor, minf(latest, latest + maxf(0.0, now - received_at) - DELAY))
	return cursor
