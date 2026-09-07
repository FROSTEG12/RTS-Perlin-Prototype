# Tree shadow volumes — 2026-09-07

## Cause

Visible tree cards are all aligned to the isometric camera. Their plane normal
is parallel to (10.5, 18, 10.5). With the existing sun orbit the projected card
area reaches only 0.000740 of its face-on area at 07:44. Thin alpha-tested
shadows consequently flicker/disappear around 07:27–08:00. Weather is unrelated.
The angle diagnostic is retained in `tests/tree_shadow_angle_diagnostic.gd`.

## Change

- Original card textures, wind frames, tints, positions, scales and resource
  generation are unchanged; the cards no longer cast shadows.
- Each tree gets an upright closed low-poly shadow volume. Six profiles match
  rounded broadleaf crowns, tiered spruces and longer-trunk pine forms.
- Volumes share the tree root and scale. Height accounts for orthographic
  foreshortening; radii account for transparent sprite margins.
- Six instanced `TreeShadows_*` batches, not separate per-tree nodes. Each
  volume has at most 188 triangles, no textures or frame-by-frame CPU animation.
- Godot `SHADOW_CASTING_SETTING_SHADOWS_ONLY` hides the volumes from the camera
  while retaining sunlight/moonlight shadows. No new light or duplicate card
  shadow; no sun-orbit changes.
- Profiles approximate crowns rather than reproduce individual leaves or
  animated wind frames. Shadowing on nearby objects can naturally differ.
  Performance has not been benchmarked; this is not an optimization claim.

API reference:
https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html

## Checks

- `tree_shadow_volume_test.gd`: six types × 1440 solar positions; projected
  volume footprint never collapses; triangle budget assertion.
- `tree_shadow_render_test.gd`: actual GPU shadow pixels in 48 variant/time
  cases including 07:27, 07:40, 07:44, 07:50, 08:00, noon/evening/night;
  exact image equality with shadow rendering disabled confirms proxies hidden.
- `tree_resources_test.gd`: equal card/proxy/resource counts, one shadow source
  per tree, no duplicate instances after rebuilding, full-game captures.
- Existing continuous light-orbit regression retained.
