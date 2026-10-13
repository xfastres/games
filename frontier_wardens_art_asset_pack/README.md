# Frontier Wardens — AI Art Asset Pack

## Included
- Cropped PNG RGBA assets for buildings, terrain, projectiles, effects and UI icons.
- The generated source atlas is preserved in `source/`.
- `asset_manifest.json` records source crop boxes and actual output dimensions.

## Important quality note
This is a **prototype starter pack**, not a fully production-validated library. The source atlas is an AI-generated catalog image with a textured backdrop and captions. The transparent PNGs were extracted with automated image segmentation, so some assets may have edge halos, residual backdrop, caption fragments, or imperfect crop boundaries. Review every PNG before shipping.

Character animation poses are visible in the source atlas, but this pack does not claim to contain verified, consistently aligned animation frame sequences. For production use, regenerate each character action as separate frames with a fixed canvas and validate in Godot.

## Godot 4 usage
- Copy selected files into your project's `assets/` directory.
- Configure sprite scale and anchor per scene; PNG canvas centers are not guaranteed to match ground-contact points.
- For isometric Y-sort, use the logical ground-contact position rather than the visual center of tall sprites.
- Inspect texture filtering/import settings against your project's current pixel-art or painted-art policy.

## Suggested next step
Import `buildings/archer_tower.png`, `buildings/wooden_palisade.png`, and one terrain tile into a test scene first. If edge extraction or perspective looks wrong, regenerate those assets individually rather than applying this atlas extraction approach to the whole game.
