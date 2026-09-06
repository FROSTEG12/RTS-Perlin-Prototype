# Simplified Godot Waterfall Shader

Source: https://github.com/frepiso/godot-waterfall-shader
Commit: a8d71c7ae3e17dc3663644195d175b20ba402640
Original author: CaptainProton42 (2020), MIT; see LICENSE.

Copied Worley noise and reference palette from the source. The reference
palette is retained only for provenance; runtime sea and falls share
water_edge_common.gdshaderinc with depth-based color and flowing foam.
The Godot 4 adaptation keeps scrolling Worley noise and small displacement,
with continuous signed flow coordinates across a rounded lip.
The extra camera, world-position render target and obstacle-height filtering
are intentionally omitted: these waterfalls fall outside the playable map.
The curtain writes depth and fades into local fog instead of alpha blending,
so back-facing waterfalls do not sort over the transparent map water.
Geometry intersects the same 0.1-unit boundary segments as the terrain with
the exact water level, including partial shoreline segments. Both generator
and renderer extend the last valid land sample at the map boundary.
The top meets the water plane with no inward strip; a 0.18-unit rounded
outward lip joins a vertical curtain. Small relief stays outside the cliff.
Flow begins at 0.42 world units/second and stretches gradually downstream.
Shared world-space swells deform the curtain below the bend; duplicated
corner vertices use identical coordinates, extrusion and displacement.
The underside uses world-space ray-integrated mist with matching height
slices on the cliff, falling water and background, including at night.
