# Engvee — FREE Animated Isometric Trees

Source: https://engvee.itch.io/free-animated-isometric-trees
Author: Engvee. Plants by Pandora and Adri.
The source page permits commercial and non-commercial use in unlimited
projects and modification. No separate license file was provided in the pack.

Only six 256px, direction-000 sheets are copied from the resource inbox.
Included: three Carpinus, two Spruce and one Pine variant. Willow was
removed at the user's request; its original remains in the resource inbox.
Each is a 4x4 animation, played at the author's suggested 16 FPS.
Original downloads and other sizes/directions remain untouched in the inbox.

Integration: lit alpha-cutout camera-aligned quads, instanced per variant.
The existing resource coordinates/data are unchanged. Positions determine
variant, size, tint and animation phase; no per-frame CPU tree updates.
Stem pivots include the source image's transparent padding.
The shader rejects the black baked-shadow pixels in the source sheets so
they do not appear as a second, static ground shadow. PNGs are not modified.

These are pre-rendered 2D assets, not 3D trees. They fit the current fixed
orthographic camera. Shadows use the cutout silhouette, not a volumetric canopy;
authored highlights do not rotate with the sun. A rotating camera or physically
accurate canopy lighting would require replacing them with 3D models.
