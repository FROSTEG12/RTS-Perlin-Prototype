# Transparent army portrait revision — 2026-09-10

Current assets are `infantry_cutout.png`, `pikemen_cutout.png`, `spearmen_cutout.png`, `archers_cutout.png`, `crossbowmen_cutout.png` in this directory. Built-in imagegen edited the original portraits; all five final PNGs have actual alpha (verified). Original opaque portraits are retained. No Python/CLI image editing was used. Initial checkerboard-background generations were rejected, not imported.

The runtime renders the alpha cutout above a recessed neutral charcoal card. Head and weapon are not masked by a card-shaped shader. Import: 512 px, mipmaps, linear filtering.

## Final prompts and source outputs

### infantry_cutout.png

Edit target: infantry.png

Prompt: Remove the background from this image. Output a transparent PNG with actual alpha transparency. Keep only the soldier and his equipment, preserving the original illustration.

Generated source: C:/Users/FROSTEG/.codex/generated_images/01a0740b-72c9-7ad0-82c7-59653fa63728/exec-f2b6fa27-3a29-432d-8c02-35fad362662a.png

### pikemen_cutout.png

Edit target: pikemen.png

Prompt: Remove the background from this image. Output a transparent PNG with actual alpha transparency. Keep only the soldier and his equipment, preserving the original illustration.

Generated source: C:/Users/FROSTEG/.codex/generated_images/01a0740b-72c9-7ad0-82c7-59653fa63728/exec-9656883c-d57c-4a4d-b307-66f9b256f7e8.png

### spearmen_cutout.png

Edit target: spearmen.png

Prompt: Make the background transparent. Preserve this spearman.

Generated source: C:/Users/FROSTEG/.codex/generated_images/01a0740b-72c9-7ad0-82c7-59653fa63728/exec-4c189c5d-0cd1-449b-851f-b988e60cb106.png

### archers_cutout.png

Edit target: archers.png

Prompt: Remove the background from this image. Output a transparent PNG with actual alpha transparency. Keep only the soldier and his equipment, preserving the original illustration.

Generated source: C:/Users/FROSTEG/.codex/generated_images/01a0740b-72c9-7ad0-82c7-59653fa63728/exec-2547f330-fab3-44c9-905f-443e39a49687.png

### crossbowmen_cutout.png

Edit target: crossbowmen.png

Prompt: Remove the background from this image. Output a transparent PNG with actual alpha transparency. Keep only the soldier and his equipment, preserving the original illustration.

Generated source: C:/Users/FROSTEG/.codex/generated_images/01a0740b-72c9-7ad0-82c7-59653fa63728/exec-3a55d42a-0cc7-463f-8d54-86ea8bbf77a9.png

