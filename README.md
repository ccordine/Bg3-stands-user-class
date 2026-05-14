# StandPrototype (BG3 Mod Prototype)

Combat-first JoJo-inspired framework with a base `Stand User` path and first subclass `Arcana: The Star`.

## Stage 2 Scope
Implemented now:
- Real class/subclass record files (`ClassDescriptions`, `Progressions`) for `StandUser` and `TheStar`
- Base stand framework mechanics (manifest/withdraw/tether/shared-damage)
- Subclass architecture via Arcana definitions
- StandDefinition ownership split: player/user actions are separate from Stand combat actions
- Concrete entity contract: each Stand identity owns one root template, one character stat block, one display-name handle, and explicit action tables
- Pre-subclass manifests use generic `BaseStand`; level 3 Arcana subclass selection changes the concrete Stand identity
- Concrete class kit: `StandUser` owns its starter equipment IDs, item names, skill list, ability preset, passives, and action spell lists
- `The Star` (close-range power) as first active Arcana
- Dedicated Star Platinum root template with Star Platinum-owned stats/localization/actions
- Themed starter presentation: Stand User field gear, camp gear, custom starter dyes, Star Platinum ghost VFX, and a stock underwear/loincloth-style equip attempt
- Tiered progression hooks (early/mid/late/capstone)
- Status feedback mirroring from Stand to User
- Stand clash detection between manifested Stands
- Time Stop capstone with functional freeze pulse placeholder
- Toolkit class/subclass scaffolding document

Still out of scope:
- Cutscenes/dialogue/cinematics
- Full custom stand creator UI
- Multiplayer polish

## Install / Test
0. Create env file:
`cp .env.example .env`
1. Install build dependencies on Arch:
`./scripts/setup-arch.sh`
Single-command pipeline (recommended):
`./scripts/run-all.sh`
2. Build a `.pak`:
`./scripts/build.sh`
If Linux `dll` backend fails with URI errors, provision Wine fallback runtime:
`./scripts/setup-divine-wine-runtime.sh`
Then build with:
`WINEPREFIX=$HOME/.wine-divine DIVINE_BACKEND=wine ./scripts/build.sh`
3. Install package into BG3 `Mods`:
`./scripts/install.sh --build-if-missing`
   - Proton note: use the compatdata profile directory as config root, not the legacy native path.
     Example:
     `./scripts/install.sh --build-if-missing --bg3-config "$HOME/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3"`
4. Add/enable module entry in `modsettings.lsx`:
`./scripts/enable-modsettings.sh`
5. Optional but recommended for runtime Lua mechanics: install BG3 Script Extender and ensure `ScriptExtender/Lua/BootstrapServer.lua` loads.
6. Start a new character and select `StandUser` class.
7. At level 3, choose `TheStar` subclass when prompted.
8. Enter combat and validate:
- Player hotbar: `Manifest Stand`, `Withdraw Stand`, `Reposition Stand`, `Combat Reading`
- Before level 3 subclass selection: manifested entity is generic `Stand`, not Star Platinum
- Star Platinum hotbar after manifest: `ORA Barrage`, `Stand Intercept`
- Stand User starts with a dark formal camp outfit plus black/blue dye options for a closer Jotaro-inspired look using stock assets
- Stand User starter inventory uses `STANDUSER_*` item stat IDs rather than direct stock equipment entries
- Star Platinum manifests with ghost VFX/glowing-eye VFX and attempts to equip a black underwear/loincloth-style stock item
- Star Platinum is hard-capped to a 30ft / 9m close-range tether from the Stand User
- Star Platinum gains `Star Finger` at Stand User level 5
- Star Platinum gains `Stand Rush` at Stand User level 6
- Star Platinum gains `Relentless Barrage` at Stand User level 10
- Star Platinum gains `Time Stop` at Stand User level 12
- Stand spawns as Star Platinum, joins combat, and owns the Star attack spells
- If the configured concrete root template fails to spawn, manifest fails visibly instead of falling back to the wrong body
- Tether auto-return triggers when too far
- Stand damage mirrors to user
- Debilitating Stand statuses echo to user
9. Cast `Withdraw Stand` to end link and despawn.

## Current Ability Progression (Stand User + The Star)
- Player/user actions: Manifest Stand, Withdraw Stand, Reposition Stand, Combat Reading
- Free user actions: Manifest Stand, Withdraw Stand
- Bonus user actions: Reposition Stand, Combat Reading
- Base Stand before subclass: generic `Stand`, command/anchor actions only, no Star Platinum combat kit
- Star Platinum level 3: ORA Barrage action, Stand Intercept reaction
- Star Platinum level 5: Star Finger action
- Star Platinum level 6: Stand Rush action
- Star Platinum level 10: Relentless Barrage action
- Star Platinum level 12: Time Stop bonus action (freeze pulse placeholder with extra action tempo)
- User feat mirroring currently covers Alert, Mobile, Tavern Brawler, and Sentinel/Guardian ids when the runtime exposes those passives.

## Known Limitations
- Stand visuals still use stock game visual resources until custom art/model assets are authored.
- Reaction/counter pipeline is implemented through status/listener approximation, not full interrupt redirection.
- Initiative and controllability behavior depend on current BG3 patch/runtime behavior.
- Time Stop is a practical prototype, not final cinematic-accurate temporal logic.
- Build/packaging currently depends on Divine backend compatibility on your host runtime.

## Next Stage
1. Replace inherited spectral placeholder visuals with a final Star Platinum model.
2. Upgrade intercept to true reaction redirection and hard attack cancellation.
3. Add `The World` and `The Hermit` Arcana implementations using the same framework.

## Documentation Index
- Arcana expansion workflow: `docs/EXPANDING_ARCANA.md`
- Class records: `Public/StandPrototype/ClassDescriptions/ClassDescriptions.lsx`
- Progression records: `Public/StandPrototype/Progressions/Progressions.lsx`
- Art/icon workflow: `docs/ART_ASSETS.md`
- Toolkit class/subclass mapping: `Public/StandPrototype/ClassScaffolding/StandUser_Class_Template.md`
- Linux auto-install script: `scripts/install.sh`
- Arch dependency setup: `scripts/setup-arch.sh`
- Build script (.pak): `scripts/build.sh`
- One-command pipeline: `scripts/run-all.sh`
- Wine runtime fallback setup: `scripts/setup-divine-wine-runtime.sh`
- Modsettings snippet helper: `scripts/print_modsettings_snippet.sh`
- Env template: `.env.example`
- Asset replacement map: `docs/ASSET_REPLACEMENT.md`
# Bg3-stands-user-class
