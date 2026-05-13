# Art and Icon Pipeline

## Copyright-safe policy
Do not ship scraped manga/anime art directly in the mod.

Use one of:
- Original art you made
- Commissioned/licensed art
- AI-generated original art inspired by tarot/stand themes

## Current structure
Place UI icon assets in:
- `Public/StandPrototype/GUI/Assets/Icons/`

Recommended naming:
- `icon_manifest_stand.dds`
- `icon_withdraw_stand.dds`
- `icon_the_star.dds`
- `icon_barrage.dds`
- `icon_heavy_strike.dds`
- `icon_intercept.dds`
- `icon_time_stop.dds`

## Style direction
- Tarot card framing
- Strong ink lines
- High-contrast gold/teal/crimson accents
- Muscular astral silhouette motifs
- Speed-line and starburst overlays for combat skills

## Replacing placeholder icons
Update `data "Icon"` values in:
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt`

Point each spell to your asset IDs once imported through toolkit.

## Mod thumbnail
You can add a non-infringing tarot-style key art image for the mod preview in your distribution package metadata.
