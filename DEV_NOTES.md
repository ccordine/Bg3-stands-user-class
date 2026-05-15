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
  - Split `userActions`, `standActions`, and tier passives per Arcana
- `StandSystem.lua`
  - Arcana resolution from passives
  - User command cleanup, Stand action repair checks, and passive progression
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
- `standName`
- `archetype`
- `entityTemplate`
- `summonTemplate`
- `userActions[level]`
- `standActions[level]`
- `passives[level]`
- `rangeProfile`
- `damageLinkProfile`
- `initiativeMode`
- `controllable`
- `rules`

Entity contract:
- `StandUser` is the base class.
- Arcana paths such as `TheStar` are subclasses.
- Before subclass selection, the resolved Arcana is `BaseStand`.
- Each Stand identity must define exactly one concrete `summonTemplate`.
- Each concrete Stand template must have its own root-template record, character stat entry, and localization handle.
- Stand combat actions should be owned by the concrete Stand character/stat data before Lua runs.
- Runtime must not silently replace a failed concrete Stand with the player template or a stock fallback body.
- Runtime must not mirror arbitrary user spellbook contents onto the Stand; `standActions` exists for level gates and logged repair fallback only.

Class kit contract:
- `StandUser` starter inventory uses `EQP_CC_StandUser` in `Equipment.txt`, with mod-owned `STANDUSER_*` item stat IDs and no equipped weapon set.
- `StandUser` item stat IDs live in `StandPrototype_Items.txt` and own display-name/description handles.
- `StandUser` owns its skill list, ability preset, progression table, command spell lists, and class/subclass passives.
- If a stock item or character stat is inherited, it should be treated as an engine behavior base, not as the public class surface.

## Files changed
- `ScriptExtender/Lua/BootstrapServer.lua`
- `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`
- `ScriptExtender/Lua/StandFramework/StandSystem.lua`
- `ScriptExtender/Lua/StandFramework/SpellHandlers.lua`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Spells.txt`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Statuses.txt`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Passives.txt`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Items.txt`
- `Public/StandPrototype/ClassDescriptions/ClassDescriptions.lsx`
- `Public/StandPrototype/Progressions/Progressions.lsx`
- `Public/StandPrototype/RootTemplates/StandPrototype_StarPlatinum.lsx`
- `Public/StandPrototype/ClassScaffolding/StandUser_Class_Template.md`
- `README.md`

## BG3-specific hacks / workarounds
- Star Platinum and Base Stand use dedicated root templates backed by stock visual resources until final custom assets exist.
- Uses `HitpointsChanged` listener for stand->user damage mirror.
- Tether behavior is deterministic `AutoReturn` teleport for close-range prototype.
- The Star / Star Platinum uses a fixed 30ft / 9m close-range tether; future remote Stand subclasses should opt into larger ranges or explicit tether scaling in their StandDefinition.
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
  - `StandUser` has one class-description row with `ClassEquipment=EQP_CC_StandUser`.
  - Subclass choice is defined by `StandUser` progression at class level 3.
  - ASI/feat cadence is owned by base class levels 4/8/12.
  - `TheStar` level 12 grants capstone only (no duplicate `AllowImprovement`).
  - Player spell lists grant command/anchor actions only.
  - Star Platinum owns stand combat actions through `STAND_STAR_PLATINUM_BODY` character stats.
  - Runtime `AddSpell` remains only as a logged repair fallback when concrete ownership is unavailable at runtime.
  - Base Stand is the default pre-subclass entity and does not receive Star Platinum combat actions.
  - Concrete Stand manifest uses `def.summonTemplate` only; no user-template or multi-template fallback is allowed.
- Runtime defensive cleanup implemented:
  - On turn start for Stand Users: stale stand/user link status cleanup.
  - On party join/session load: cleanup + progression refresh.
  - On death: forced withdraw and cleanup.
- Runtime progression gating note:
  - Lua stand progression now uses `GetUserStandProgressLevel()` with class-feature passive checks
    (`TheStar` 3/5/6/10/12 stand action gates) and no longer falls back to raw total level before subclass.
- Action economy note:
  - Manifest/Withdraw are free user actions.
  - Stand attack techniques are action-cost attacks.
  - Stand Intercept remains a reaction and Time Stop is a bonus-action capstone.
- Runtime checks still requiring in-game verification:
  - multiclass into StandUser from another class
  - multiclass out from StandUser
  - Withers respec cleanup/persistence
  - zone transition + long rest + save/load while stand active
  - wildshape/disguise/polymorph/silence/stun/downed interactions

## Practical migration path to full class records
1. Add future Stand actions as real SpellData and concrete Stand character/stat ownership.
2. Mirror future Stand action IDs in `standActions` for level gates and repair fallback, not as the primary spellbook source.
3. Keep progression unlocks aligned to class/subclass level milestones.
