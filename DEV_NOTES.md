# Dev Notes - Stand User / Arcana Refactor

## What changed
Refactored from one-off summon behavior into:
- Base class framework: `Stand User` core mechanics
- Subclass framework: Arcana-driven stand definitions
- First implemented Arcana: `The Star`

## Runtime architecture
- `StandDefinitions.lua`
  - `Core` section for universal class features
  - `Arcana` table for subclass-specific stand definitions
  - Progression tiers per Arcana using unlock levels
- `StandSystem.lua`
  - Arcana resolution from passives
  - Progression grant pipeline
  - Manifest/withdraw lifecycle
  - Tether + linked damage processing
  - Stand owner index for efficient lookup
  - Debilitating status feedback mirroring
  - Stand clash and capstone trigger logic
- `SpellHandlers.lua`
  - Spell triggers
  - Damage/tether/intercept listeners
  - Level-up / party join progression refresh

## Data contracts (implemented)
Arcana definition supports:
- `id`
- `displayName`
- `archetype`
- `summonTemplate`
- `rangeProfile`
- `damageLinkProfile`
- `initiativeMode`
- `controllable`
- `progression[level]`

## Files changed
- `ScriptExtender/Lua/BootstrapServer.lua`
- `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`
- `ScriptExtender/Lua/StandFramework/StandSystem.lua`
- `ScriptExtender/Lua/StandFramework/SpellHandlers.lua`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Statuses.txt`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Passives.txt`
- `Public/StandPrototype/ClassDescriptions/ClassDescriptions.lsx`
- `Public/StandPrototype/Progressions/Progressions.lsx`
- `Public/StandPrototype/ClassScaffolding/StandUser_Class_Template.md`
- `README.md`

## BG3-specific hacks / workarounds
- Uses stock NPC UUID as stand body placeholder.
- Uses `HitpointsChanged` listener for stand->user damage mirror.
- Tether behavior is deterministic `AutoReturn` teleport for close-range prototype.
- Time Stop is implemented as a freeze-pulse placeholder spell chain.

## Runtime-uncertain audit items
- Skill selection at class level 1 now uses BG3-style GUID skill list selector:
  - `SelectSkills(0d9c53e6-52c4-4c21-89f5-60467f0d95c3,2)`
- Status: `Partial` until in-game class creation confirms the skill picker appears correctly.
- Required test:
  - New game -> choose `StandUser` -> verify exactly 2 skill picks are presented from the intended list.
- Do not replace this with canonical skill-list UUID selectors unless copying a known-good BG3 class pattern.

## Multiclass / Safe-State Audit
- Static implemented:
  - `StandUser` has a dedicated `IsMulticlass=true` class-description row.
  - Subclass choice is defined by `StandUser` progression at class level 3.
  - ASI/feat cadence is owned by base class levels 4/8/12.
  - `TheStar` level 12 grants capstone only (no duplicate `AllowImprovement`).
  - Level 1 now grants full stand combat loop actions (Manifest/Withdraw/Barrage/Intercept/Reposition).
  - Level 2 now grants resource loop + panic spike (`Combat Reading` + `Heavy Stand Blow`).
- Runtime defensive cleanup implemented:
  - On turn start for Stand Users: stale stand/user link status cleanup.
  - On party join/session load: cleanup + progression refresh.
  - On death: forced withdraw and cleanup.
- Runtime progression gating note:
  - Lua stand progression now uses `GetUserStandProgressLevel()` with class-feature passive checks
    (`TheStar` 3/6/10/12 tiers) and no longer falls back to raw total level before subclass.
- Runtime checks still requiring in-game verification:
  - multiclass into StandUser from another class
  - multiclass out from StandUser
  - Withers respec cleanup/persistence
  - zone transition + long rest + save/load while stand active
  - wildshape/disguise/polymorph/silence/stun/downed interactions

## Practical migration path to full class records
1. Keep `StandDefinitions`/`StandSystem` unchanged.
2. Keep progression unlocks aligned to class/subclass level milestones.
