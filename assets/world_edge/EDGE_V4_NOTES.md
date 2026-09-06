# Slower overflow, foam coverage and moving corners

- Shared flow speed 0.42, down from 0.85. This slows the sea-to-fall animation
  together. Downstream stretching remains gradual.
- Added sparse crest foam driven by shared flow coordinates, without the
  open-sea depth/wind gates which excluded shallow lateral ends.
- Wave height attenuation now multiplies the two side fades. The old minimum
  distance had a diagonal derivative discontinuity at corners.
- Overflow samples blend smoothly between adjacent boundaries only in their
  shared corner region, remaining exact on the boundary itself. Blend sampled
  values rather than UV coordinates to avoid diagonal stretching.
- Rounded-lip extrusion and shading normals use a smooth shared corner field,
  instead of face-specific normals and a special diagonal offset at one vertex.
- Curtain swells use boundary position, travel and time for both faces. There
  is no face-dependent displacement and no pinned single corner vertex.
  The top is anchored; below the bend, horizontal swells are bounded to
  0.005..0.255 units and shade with the wave gradient.

Tests: 3200 boundary cases, 220 matching corner vertex pairs, six animated
camera views (front and side corners), existing visual/day/night/contact tests.
This is still the visual baseline; no separate optimization pass.
