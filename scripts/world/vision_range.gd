extends RefCounted
const DAY_RADIUS := 10.0
const NIGHT_RADIUS := 7.0
const FEATHER := 2.5

static func radius(hour: float) -> float:
	var time := fposmod(hour,24.0)
	var daylight := smoothstep(6.0,8.0,time)*(1.0-smoothstep(18.0,20.0,time))
	return lerpf(NIGHT_RADIUS,DAY_RADIUS,daylight)
