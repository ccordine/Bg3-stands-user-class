# Asset Replacement Guide

This project ships with placeholder assets under `Assets/` so build/staging never depends on final art/audio.

## Placeholder Tree
- `Assets/Audio/Music/stand_theme_placeholder.wav`
- `Assets/Audio/Voice/the_star_barrage_placeholder.wav`
- `Assets/Audio/Voice/the_star_heavy_punch_placeholder.wav`
- `Assets/Audio/Voice/the_star_manifest_placeholder.wav`
- `Assets/Audio/Voice/the_star_withdraw_placeholder.wav`
- `Assets/Audio/SFX/stand_manifest_placeholder.wav`
- `Assets/Audio/SFX/stand_withdraw_placeholder.wav`
- `Assets/Audio/SFX/barrage_hit_placeholder.wav`
- `Assets/Audio/SFX/heavy_punch_placeholder.wav`
- `Assets/Audio/SFX/time_stop_placeholder.wav`
- `Assets/Icons/stand_user_class_placeholder.png`
- `Assets/Icons/the_star_subclass_placeholder.png`
- `Assets/Icons/manifest_stand_placeholder.png`
- `Assets/Icons/withdraw_stand_placeholder.png`
- `Assets/Icons/barrage_placeholder.png`
- `Assets/Icons/heavy_punch_placeholder.png`
- `Assets/Icons/time_stop_placeholder.png`
- `Assets/Models/the_star_placeholder_model_notes.md`

## Asset Safety
- Audio placeholders are valid 1-second silent WAV files (44.1kHz mono).
- Icon placeholders are valid transparent PNG files.
- Model placeholder is documentation-only, not runtime-bound.

## Wiring Policy
To avoid breaking build/runtime, placeholders are not force-wired into uncertain BG3 audio pipelines in this pass.

Safe existing icon usage remains in stats records (`Skill_*` icons). Replace later only when your asset import IDs are confirmed.

## Replace Later
1. Replace file contents while keeping filenames the same for external pipeline stability.
2. If you change filenames, update references in your toolkit/import mapping.
3. For stand model replacement, update the root template and the matching `summonTemplate`/`entityTemplate` in official `Name_UUID` format in:
   - `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`

## Naming Policy
All placeholder names use Stand User / The Star naming and avoid copyrighted character names.
