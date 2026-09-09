> Технические заметки предыдущих этапов. Игровые тестовые режимы удалены;
> текущее состояние описано в README.md и docs/ARCHITECTURE.md проекта.

# Tree silhouette shadows

## Length and water contrast tuning

`tree_shadow_silhouette.gdshader`: `low_sun_shortening = 0.28` reduces the
shadow-only card height at low light elevations. It fades smoothly to zero
shortening between vertical light components 0.55 and 0.83. The stem, visible
tree dimensions, atlas and wind phase are unchanged. This is art direction,
not a change to the astronomical light orbit or the size of buildings/units.
On level ground low-sun tree shadows are 28% shorter; across lower water/seabed
receivers the additional drop to the receiver still affects total length.

`water.gdshader`: `water_shadow_strength = 0.52` retains 52% of directional
diffuse-light shadow contrast. Specular occlusion is unchanged. The water's
direct lighting uses Burley diffuse and isotropic GGX/Schlick, with a guarded
denominator. It does not add a new pass, light, texture or shadow atlas. The
custom path omits the engine's internal GGX multiscattering compensation LUT;
the unshadowed visual comparison below checks the practical difference for
this water. Future area-light use would need a separate lighting review.

Reference for the equations and light built-ins:
https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl
https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html

`tests/tree_water_shadow_tuning_test.gd` compares original, shorter-only and
shorter/lighter variants on the same generated map, camera and frozen wind
frame at 17:30. On the checked map, 4078 sampled pixels became >0.02 brighter
in green; with shadows disabled the old vs new mean maximum-channel error was
0.00009044 (0..1 range). Dawn/noon/night screenshots were also captured.
The 48-case silhouette raster test still passes after shortening. No claim
of measured full-forest FPS improvement is made.

## Main-game integration

The user requested deployment after reviewing the pilot. `tree_resources.gd`
now uses the silhouette shader for all six shadow-only MultiMesh batches.
Instances have identity rotation, uniform scale, matching root positions and
the same custom wind data as the visible sprites. `main.gd` updates six light
direction uniforms, including when the time slider is used. Culling margins
cover the shader-rotated cards. Rebuilding a map replaces the material list.
The old volume builder remains only for comparison/regression tests.

The production visible sprites disable shadow reception, with the same
self-shadow / external-shadow tradeoff described below. Ground, buildings,
weather, resource placement and camera controls are unchanged.

Integration check: 2089 trees across six visible and six shadow batches;
equal roots/wind phases, unchanged resource data, no duplicated trees after
rebuild, light direction follows the clock. Main-game screenshots captured
at dawn, noon, night and dusk. Full-forest performance is not benchmarked.

## Original isolated pilot

Run Godot with `--path . --script tests/tree_silhouette_pilot.gd`.
Add `-- --quit-after-tests` for the automated GPU checks only.

The visible sprite stays camera-facing and does not cast shadows. A second,
shadow-only alpha-tested quad stays upright and rotates around world Y to face
the horizontal light direction. Its atlas, pivot, dimensions and wind phase
match the visible tree. Rotating the vertices (rather than overriding the
view matrix) keeps the normal shadow-pass transform. This pilot assumes an
identity instance rotation. Do not reuse with randomly rotated instances
without transforming the light direction into the corresponding local space.

The test uses the main scene's camera far distance (180), directional shadow
distance (80), two cascades and bias settings. An initially unbounded test
camera was unsuitable for this close-up shadow comparison.

Controls: time slider, run time, six tree variants, silhouette / old volume /
no shadow, receive shadows, textured / plain ground. Starts paused at 07:44.
The scene is deliberately simple; the production terrain color grading and
weather are not reproduced here.

Known compromise: receiving shadows is OFF for the visible tree by default.
This prevents the hidden card from casting intersection artifacts onto the
camera-facing tree. It also prevents that sprite from receiving other objects'
shadows. The toggle exposes this tradeoff; it has not been applied to the forest.

Verification: actual rendered shadow vs no-shadow baseline for 6 variants at
07:27, 07:40, 07:44, 07:50, 08:00, 12:00, 18:30 and 00:00. Flat neutral ground
and hidden visible sprite avoid texture patterns and sprite occlusion affecting
the coverage measurement. All 48 comparisons pass (minimum 2995 sampled pixels
differ by >0.01 in at least one color channel). The shadow proxy contributes no
visible geometry when the light's shadows are disabled. This is not a forest
performance benchmark or proof that every possible camera configuration works.

Reference investigated: Joey_Bland's CC0 spatial billboard shader:
https://godotshaders.com/shader/spatial-view-depending-directional-billboard/
The pilot's upright orientation, alpha cleanup and pivot handling are specific
to this project's wind atlases; the reference is not installed as an addon.
