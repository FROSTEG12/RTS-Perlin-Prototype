> Технические заметки предыдущих этапов. Игровые тестовые режимы удалены;
> текущее состояние описано в README.md и docs/ARCHITECTURE.md проекта.

# Traffic-driven trails

## Approach / sources

Use one world-space splat/wear mask to blend existing grass and soil in the
existing terrain material, not decals or meshes per footprint:
https://catlikecoding.com/unity/tutorials/rendering/part-3/

Reuse an allocated ImageTexture via `update`, with identical size/format:
https://docs.godotengine.org/en/stable/classes/class_imagetexture.html

These sources establish the blending and upload mechanisms. The distance-based
traffic accumulation, budget/queue and pixel reveal below are project-specific.
No external addon or generated bitmap is added. Soil source is the existing
`assets/world_edge/soil_albedo.png`, sampled with reduced color precision and
a small tint adjustment; the original file is unchanged.

## Runtime and integration

- `scripts/effects/trail_wear.gd`: one service per map, one 512×512 R8 mask (256 KiB),
  and a CPU float field (1 MiB) to accumulate increments without frame-dependent
  byte rounding. Memory does not grow with path length or number of footsteps.
- Any ground walker calls `record_movement(id, previous_world_position,
  current_world_position, weight=1)` after actual movement. The current test
  unit is connected through `set_trail_wear`. Units share the same field and
  their contributions add. No polling of all scene nodes is required.
- Call `forget_unit(id)` on spawn/teleport/despawn or before reusing an ID.
  The existing unit does so on placement/rebind/exit. There is also a 4-unit
  per-report teleport guard. Large normal movement steps should be split by
  the movement controller; crossing the guard intentionally creates no trail.
- Stamp every 0.18 world units of traveled distance, not every frame or second.
  Stopping does not wear grass. Carry distance is independent per unit.
  Brush radius 0.34, gain 0.045/sample; center fills before soft shoulders.
  Accumulation clamps to 0–1. Repeated routes reveal a noticeable path after
  several traversals and a dense center after roughly 15–25, depending on
  exact offset/overlap. Offsets between units naturally broaden busy routes.
- No pathfinder costs, map cells, resource locations or geometry are changed.
  Water cells are rejected by the CPU; shader additionally limits dirt to
  grass-dominant terrain, protecting the beach and submerged terrain.
- Trails reset with new map generation. No disk save, regrowth, rain erosion,
  footstep decals, mud mechanics or automatic road speed bonus is implied.

## Pixel look

Stable world-space thresholds at 0.08-unit cells expose small soil patches as
wear grows. No random-per-frame or screen-space threshold. At 0% wear grass
is unchanged, at 100% eligible grass becomes soil. Subpixel details converge
to average coverage with distance using derivatives to reduce shimmer on zoom.
Lighting, shadows and weather continue shading the original terrain material.

## Cost boundaries

- At most 256 stamps processed per frame, capped pending backlog of 8192.
  Overflow drops visual samples and counts `dropped_samples`, never stalls
  gameplay or grows memory indefinitely. This is a quality fallback at extreme
  load, not a guarantee of exact wear with arbitrary unit counts.
- At most 10 texture uploads/sec, only while changed. No GPU readback, mipmap
  regeneration, per-step allocations of textures/meshes, or extra draw pass.
  The whole 256 KiB mask is uploaded (at most ~2.5 MiB/s logical data); this is
  not a dirty-rectangle GPU uploader. Driver overhead is additional.
- The grass shader adds two texture reads and small mask/noise/derivative math.
  GPU cost scales with visible terrain pixels, not number of units.
- Core headless CPU stress test: 1000 reported walkers moving at 2.25 units/sec,
  60 updates/sec for 3 simulated seconds: median ~2.2 ms, p95 ~3.0 ms on this
  machine, 36,768 processed stamps, zero dropped samples, 29 uploads. This is
  an isolated subsystem measurement, NOT 1000 full AI/rendered units or a GPU
  frame-time guarantee. Larger maps should use chunked masks rather than simply
  increasing global mask resolution/update bandwidth.

## Verification

- `tests/trail_wear_test.gd`: idle/spawn/teleport rejection, incremental wear,
  saturation, 12 vs 360 movement subdivisions, additive units, water exclusion,
  edge clipping, queue cap/frame budget, no idle uploads, texture reuse,
  1000-report stress load and new-map clearing.
- `tests/trail_visual_test.gd`: screenshots after 0/1/4/10/24 passes; actual
  test-unit route integration and stopping; night, rain and zoomed-out forest.
  Resource visuals are hidden temporarily in material closeups, never in the
  production game. Outputs live in the task's `work` folder.
