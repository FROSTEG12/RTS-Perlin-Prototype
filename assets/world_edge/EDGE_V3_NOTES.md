# Connected overflow + static contact shading

The sea and falling sheet now share water_edge_common.gdshaderinc, with the
same boundary coordinates, depth-dependent base colors and advected foam.
Signed flow distance continues from the sea through a 0.18-unit rounded lip
and down the curtain. No separate waterfall palette remains.

Sea heights and all finite-difference normal samples use the same boundary/
shore attenuation; detailed normals also fade consistently at the boundary.
This fixes the previous incorrect normal gradient on the flattened edge.

Rock vertex color B contains a static wet-perimeter proximity mask, with
0.9-unit soft lateral falloff. world_edge.gdshader applies contact darkening
below the waterline (waterfall_shadow_strength = 0.46). This is static shading,
not another light or moving shadow map. Fog still applies after shading.
The curtain itself has mild contact-depth shading (0.18) behind foam.

Geometry tests verify exact top positions, continuous boundary UVs and
vertical descent after the lip. Visual tests include four corners and four
times of day, plus a close-up on/off comparison for rock contact shading.

No simulation, new particle system or separate optimization pass was added.
Original third-party Worley noise remains MIT-credited in ../waterfall.
