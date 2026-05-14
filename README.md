# StandPrototype (BG3 Mod Prototype)

Combat-first JoJo-inspired framework with a base `Stand User` path and first subclass `Arcana: The Star`.

## Stage 2 Scope
Implemented now:
- Real class/subclass record files (`ClassDescriptions`, `Progressions`) for `StandUser` and `TheStar`
- Base stand framework mechanics (manifest/withdraw/tether/shared-damage)
- Subclass architecture via Arcana definitions
- `The Star` (close-range power) as first active Arcana
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
4. Add/enable module entry in `modsettings.lsx`:
`./scripts/enable-modsettings.sh`
5. Optional but recommended for runtime Lua mechanics: install BG3 Script Extender and ensure `ScriptExtender/Lua/BootstrapServer.lua` loads.
6. Start a new character and select `StandUser` class.
7. At level 3, choose `TheStar` subclass when prompted.
8. Enter combat, cast `Manifest Stand`, and validate:
- Stand spawns and joins combat
- Stand has Star abilities by level
- Tether auto-return triggers when too far
- Stand damage mirrors to user
- Debilitating Stand statuses echo to user
9. Cast `Withdraw Stand` to end link and despawn.

## Current Ability Progression (The Star)
- Early: Manifest, Withdraw, Barrage, Heavy Strike, Projectile Intercept
- Mid (level 6): Precision Counter, Stand Leap
- Late (level 10): Combat Prediction, Stand Rush Ultimate
- Capstone (level 12): Time Stop (freeze pulse placeholder with extra action tempo)

## Known Limitations
- Stand visual uses stock NPC template UUID placeholder.
- Reaction/counter pipeline is implemented through status/listener approximation, not full interrupt redirection.
- Initiative and controllability behavior depend on current BG3 patch/runtime behavior.
- Time Stop is a practical prototype, not final cinematic-accurate temporal logic.
- Build/packaging currently depends on Divine backend compatibility on your host runtime.

## Next Stage
1. Replace placeholder model/template with dedicated Stand actor template.
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
