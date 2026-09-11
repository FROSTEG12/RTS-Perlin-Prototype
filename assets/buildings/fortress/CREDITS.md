# Fortress modules

Source: **Modular Medieval Walls**, Daniel Vicente (@danielvicente97cesur).
https://sketchfab.com/3d-models/modular-medieval-walls-c67ba1ad848d4f7ca7b83b944ff6631c
License: CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/

Original.glb is an unmodified development source copy (SHA256
4B11DDAE5AA172093AA4389D841317E005401FC6319D49712D59369D0888E5EC).
The assembled demonstration wall is NOT instantiated by the game.

Adaptations: tools/prepare_fortress.gd extracts five standalone modules from
the isolated upper display row, retaining normals and untextured materials.
Each module is grounded, centered and uniformly scaled; red cloth is blue.
No endorsement by the original author is implied.

| Module | Grid footprint | Mesh height (m) |
|---|---|---|
| wall | 6 × 2 | 4.18 |
| gate | 6 × 2 | 4.18 |
| round_tower | 3 × 3 | 6.28 |
| round_tower_alt | 3 × 3 | 6.32 |
| square_tower | 3 × 3 | 8.04 (including flags) |

These are initial game-scale values for user review, not historical dimensions.
Each .tscn references its own .res mesh. Previews in assets/ui/buildings/modules
are actual Godot renders from tools/render_fortress_previews.gd, not AI images.
The gate has no opening animation or passable navigation yet: this is a size test.
