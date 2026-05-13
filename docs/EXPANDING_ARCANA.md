# Expanding Arcana Subclasses

This guide adds new subclasses (The World, The Hermit, etc.) without rewriting core systems.

## 1. Add Arcana Definition
Edit:
- `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`

Add a new entry under `StandDefinitions.Arcana`:
- `id`
- `displayName`
- `archetype`
- `summonTemplate`
- `rangeProfile`
- `damageLinkProfile`
- `initiativeMode`
- `controllable`
- `progression`

## 2. Add Subclass Passive ID
Edit:
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Passives.txt`

Create:
- `STAND_SUBCLASS_<ARCANA_NAME>`

Example:
- `STAND_SUBCLASS_THE_WORLD`

## 3. Wire Arcana Resolution
Edit:
- `ScriptExtender/Lua/StandFramework/StandSystem.lua`

In `StandSystem.ResolveArcana(user)`, map passive -> arcana key.

## 4. Add Tier Passives and Spells
Edit:
- `StandPrototype_Passives.txt`
- `StandPrototype_Spells.txt`

Add tier passives (`EARLY/MID/LATE/CAPSTONE`) and spells used in progression unlocks.

## 5. Add Toolkit Subclass Record
In BG3 Toolkit class/subclass records:
- Create `StandUser_<ArcanaName>` subclass
- Add `STAND_SUBCLASS_<ARCANA_NAME>` at entry
- Add tier passives at class level breakpoints

Reference scaffold:
- `Public/StandPrototype/ClassScaffolding/StandUser_Class_Template.md`

## 6. Validate In Combat
- Manifest in combat
- Verify stand spell loadout by level
- Verify tether and shared damage logic
- Verify subclass-only effects trigger correctly

## Suggested Archetype Defaults
- CloseRangePowerStand: short tether, high burst, intercept tools
- RemoteStand: longer tether, lower link ratio, control/utility kit
- AutomaticStand: limited direct control, trigger behaviors
- BoundStand: object-linked manifestation, zone effects
- ColonyStand: multi-unit spawn abstraction, shared pool mechanics
- PhenomenonStand: no humanoid body, status/zone-focused abilities
