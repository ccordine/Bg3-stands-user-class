# Expanding Arcana Subclasses

This guide adds new subclasses (The World, The Hermit, etc.) without rewriting core systems.

## 1. Add Arcana Definition
Edit:
- `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`

Add a new entry under `StandDefinitions.Arcana`:
- `id`
- `displayName`
- `standName`
- `archetype`
- `entityTemplate`
- `summonTemplate`
- `userActions`
- `standActions`
- `passives`
- `rangeProfile`
- `damageLinkProfile`
- `initiativeMode`
- `controllable`
- `rules`

Contract:
- `StandUser` is the base class; Arcana entries are subclass paths.
- `BaseStand` is the only pre-subclass Stand identity.
- Do not add user-template, stock-body, or multi-template runtime fallbacks.
- Each Arcana Stand must have one concrete `summonTemplate`, one root template, one character stat entry, one localization handle, and explicit `userActions`/`standActions`.

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

Add tier passives (`EARLY/MID/LATE/CAPSTONE`) and spells used by the Stand. Put player/control spells in `userActions` and Stand combat spells in `standActions`. Do not rely on runtime mirroring of the user spellbook; every Stand-owned action should be listed explicitly.

## 5. Add Concrete Stand Entity Data
Create the concrete entity records before wiring runtime manifest:
- `Public/StandPrototype/RootTemplates/StandPrototype_<StandName>.lsx`
- `Public/StandPrototype/Stats/Generated/Data/StandPrototype_Characters.txt`
- `Localization/English/StandPrototype.xml`

The root template `DisplayName` should point to the Stand localization handle. The runtime should not need to rename normal Stand identities after spawn.

## 6. Add Concrete Class/Kit Data
For new class-facing features, add mod-owned data IDs instead of directly adding stock IDs to class records:
- starter equipment: create `STANDUSER_*` or Arcana-specific item stats, then reference those IDs from `Equipment.txt`
- skills/choices: create or extend mod-owned list records
- passives/features: create mod-owned passive IDs and localization handles
- spells/actions: create explicit spell IDs and place them in `userActions` or `standActions`

Stock inheritance is acceptable only as an engine behavior base. It should not be the public class/subclass contract.

## 7. Add Toolkit Subclass Record
In BG3 Toolkit class/subclass records:
- Create `StandUser_<ArcanaName>` subclass
- Add `STAND_SUBCLASS_<ARCANA_NAME>` at entry
- Add tier passives at class level breakpoints

Reference scaffold:
- `Public/StandPrototype/ClassScaffolding/StandUser_Class_Template.md`

## 8. Validate In Combat
- Manifest in combat
- Verify stand spell loadout by level
- Verify player hotbar does not receive Stand combat spells
- Verify tether and shared damage logic
- Verify subclass-only effects trigger correctly

## Suggested Archetype Defaults
- CloseRangePowerStand: short tether, high burst, intercept tools
- RemoteStand: longer tether, lower link ratio, control/utility kit
- CloseRangePowerStand: use a 30ft / 9m tether unless the Stand is explicitly remote or long-distance
- AutomaticStand: limited direct control, trigger behaviors
- BoundStand: object-linked manifestation, zone effects
- ColonyStand: multi-unit spawn abstraction, shared pool mechanics
- PhenomenonStand: no humanoid body, status/zone-focused abilities
