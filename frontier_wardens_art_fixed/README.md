# Frontier Wardens — AI Art Asset Pack (Fixed Revision)

## Included
- 42 cropped PNG RGBA assets for buildings, terrain, projectiles, effects and UI icons.
- The generated source atlas remains preserved in the original pack's `source/` directory.
- `asset_manifest.json` records source crop boxes and actual output dimensions for this revision.
- `fix_report.json` records, per file: fix method, old/new canvas size, and atlas crop box.
- `_qa/` contains technical check output and before/after overview images for visual review.

## What was fixed
The original pack contained 24 unusable crops: fully transparent PNGs, a few stray pixels, or fragments of the Chinese caption text baked into the source atlas.

- **24 assets rebuilt from the source atlas** (`source/generated_asset_atlas_reference.png`) using GrabCut segmentation with per-asset initialization, edge feathering, and transparent-trim: 8 terrain tiles/roads, pine forest tile, deciduous tree, bush, dead tree, 2 arrows, magic bolt, explosion, and 10 UI icons.
- **18 assets conservatively cleaned in place**: sub-32 alpha zeroing, removal only of isolated fragments smaller than 20 px that are more than 10 px away from the main connected body, then re-trimmed with 2 px padding. Intended effect particles (e.g. green death effect) are preserved.

Every rebuilt PNG was checked: none is fully transparent, none contains caption fragments, and all content is a single connected subject.

## Known limitations (still apply)
This remains a **prototype starter pack**, not a production-validated library.

- The source is an AI-generated catalog image on a textured dark backdrop. Rebuilt alpha edges are re-segmented rather than authored, so minor edge halos or feathering artifacts are possible at full zoom.
- Terrain tiles are diamond-shaped painted patches; seamless 64x64 grid tiling of the road/dirt/stone tiles has **not** been verified in-engine.
- `terrain/pine_tree.png` is the atlas's 4-tree pine **forest tile**, not a single pine tree — no isolated pine exists in the source atlas.
- `ui/icons/upgrade.png` is a gear icon and `ui/icons/quest.png` is a scroll icon; filenames follow the original pack's naming.
- Character animation poses exist in the source atlas but are not part of this pack.

## Godot 4 usage
- Copy selected files into your project's `assets/` directory and re-import; canvas sizes differ from the original pack (see `asset_manifest.json`).
- PNG canvas centers are not guaranteed to match ground-contact points; use logical ground positions for isometric Y-sort.
- Inspect texture filtering/import settings against your project's pixel-art or painted-art policy.

## Review artifacts
- `_qa/fixed_01_buildings.png` … `_qa/fixed_05_ui.png`: every fixed asset on checker/black backgrounds plus its alpha channel.
- `_qa/before_after.png`: before/after pairs for all 28 corrected assets.
- `_qa/fixed_stats.json`: visible-pixel counts and content bounding boxes.
