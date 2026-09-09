extends "res://scripts/main.gd"
## Benchmark-only deterministic map. Production main script is unchanged.
func generate_world() -> void:
	world_seed = 1788918610
	super.generate_world()
