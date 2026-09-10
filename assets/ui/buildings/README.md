# Building menu previews

Current close-up fortification preview: [fortress_walls_closeup.png](fortress_walls_closeup.png);
source attribution and imagegen prompt: [FORTRESS_WALLS.md](FORTRESS_WALLS.md).

Six complete opaque images generated with the built-in imagegen tool on 2026-09-10. Each image contains the referenced building and its environment; no background-only compositing is used at runtime. Source GLB/BLEND models were not modified. These are AI-edited illustrations based on the user's renders, not exact geometry renders.

Source: `C:/Users/FROSTEG/Documents/Codex/2026-09-08/new-chat/outputs/Settlement_Pack/Previews/` (BLU variants).

## Assets and individual prompts

- `town_hall.png` ← `TownHall_BLU.png`: Rural town hall on a tidy grass-and-earth village green. Preserve the tall detached bell tower beside the main building, its bell, its blue roof, the passage between tower and house, and the main house's stairs and balcony. The tower must stay detached, not merged into a wall or roof.
- `house.png` ← `Residence_BLU.png`: Residential house standing in a small grassy yard with a modest worn-earth approach and distant trees. Preserve exactly the house from the reference, including blue intersecting roofs and stone corner blocks.
- `smithy.png` ← `Blacksmith_BLU.png`: Blacksmith building in a compact packed-earth and fine-gravel workshop yard. Preserve its covered open forge annex, workbench, tools and weapon rack exactly. Subdued grass around the yard, trees in the distance.
- `sawmill.png` ← `LumberMill_BLU.png`: Sawmill at the edge of a quiet woodland clearing. Preserve exactly the main house, attached roofed workshop, piles of timber, saw and chopping stump in the source. Add only natural earth/grass around them, no new structures.
- `warehouse.png` ← `Warehouse_BLU.png`: Warehouse complex on a quiet storage yard of packed earth with grass at the edges. Preserve both roofed parts, wooden crates with cross braces, rear fence, logs and barrel exactly as shown. No added or removed building parts.
- `animal_pen.png` ← `AnimalPen_BLU.png`: Animal pen in a grassy pasture with worn earth inside its enclosure. Preserve the entire round wooden fence and gate, blue-roofed open shelter, existing hay and feeding trough. Add ground through the currently empty interior of the fence. No animals. Keep the complete fence inside the frame.

## Shared final prompt

Use case: precise-object-edit.
Input image 1 is the EDIT TARGET: the user's exact finished low-poly building render with an empty transparent/black background.
Create a complete finished building preview illustration for a medieval RTS construction menu: the supplied building AND natural surroundings in one opaque image, not a separate background.
CRITICAL: preserve the building's exact design, proportions, blue/slate roof color, roof shapes, wall pattern, windows, chimneys, accessories, and original three-quarter camera angle. Do not redesign or replace the model. Keep ALL of the original structure visible, no cropping of roofs or towers. The building must remain the large dominant subject, about 80% of the image height.
Change the empty background and ground only: add a believable quiet rural medieval environment, soft neutral daylight matching the model, grounded contact shadows, muted green vegetation and earth, subdued distant tree line. Gently stylized surroundings consistent with the low-poly architecture, clean polished game-card composition. The ground must continue naturally through open parts of the model. Complete rectangular 6:5 landscape image, full bleed, no transparency, no cutout edge, no frame or rounded corners.
No lettering, captions, UI, arrows, badges, watermarks, characters, animals, extra buildings, extra annexes or invented modifications. Make it readable as a small 140-pixel building thumbnail. Preserve the source foreground building and its accessories.

## Original generated files

- town_hall: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-6db4cd95-4a89-4fbf-ab4f-ba1f2d7f2332.png`
- house: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-20c944fb-bce2-4bea-a608-099fe9371d8f.png`
- smithy: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-e9e401a1-18a1-4a0f-8700-042132cf5610.png`
- sawmill: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-fdeeac38-96c7-4a77-b00d-97cf977bab32.png`
- warehouse: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-a4d5ee40-e92a-4dff-bee1-1894e5d460b8.png`
- animal_pen: `C:\Users\FROSTEG\.codex\generated_images\01a0740b-72c9-7ad0-82c7-59653fa63728\exec-b1f540ae-e5eb-44ba-b400-ee791de1633d.png`
