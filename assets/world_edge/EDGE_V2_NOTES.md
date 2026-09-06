# World edge visual revision

- Both density samplers clamp lattice indices to the nearest valid map cell.
  The void is no longer a zero-valued water sample. This changes only the
  smoothed boundary/bathymetry, not procedural cell layout or resource placement.
- Rock walls retain perimeter XZ at every depth, including shared corners.
- Falling water clips each terrain boundary segment at WATER_Y, not at a
  separately inset density threshold. Surface waves settle to that same level
  over the last 0.8 world units. No inward-facing lip is drawn.
- Source Worley noise scrolls vertically at 1.4 world units/second, with fine
  foam and outward corrugation. It is not a fluid simulation.
- Mist is integrated along orthographic world-space rays. Cliff, falls and
  backdrop share fixed height slices, avoiding transparent-sheet sorting and
  differing integration at geometry seams. Fog remains below the playable map.
- Stylized generated texture and final prompt: GENERATION_STYLIZED.md.
- Third-party waterfall attribution: ../waterfall/README.md and LICENSE.

Validation: waterfall_boundary_test (3200 boundary segments, 10 patterns),
camera_bounds_test (81 cases), day_night_lighting_test (1440 time steps),
world_edge_visual_test (seed 4242, four corners, front falls, noon/midnight/
06:30/18:30). Godot 4.7.2, Forward+, RX 6600. No shader errors in visual run.

This is a visual-review baseline. No comparative performance measurements or
separate optimization pass have been performed; obtain user approval first.
Rollback checkpoint before world styling: ff72ed4. Original photographic
textures are retained but no longer used by the cliff material.
