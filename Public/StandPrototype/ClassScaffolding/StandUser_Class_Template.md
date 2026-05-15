# Stand User Class/Subclass Toolkit Scaffolding

This file is a concrete mapping for BG3 Toolkit class/subclass records that match the data-first Stand contract.

## Base Class
- Class Internal Name: `StandUser`
- Display: `Stand User`
- Primary Ability Suggestion: `CHA`
- Hit Die Suggestion: `d8`
- Save Proficiencies Suggestion: `WIS`, `CHA`
- Core Passive at Level 1: `STAND_USER_BASE_CLASS_PASSIVE`
- Class Equipment: `EQP_CC_StandUser`
- Core spells at Level 1:
  - `Shout_Stand_Manifest`
  - `Shout_Stand_Withdraw`

## Subclass Group (Arcana)
Create subclass choice at class level 3.

### The Star
- Subclass Internal Name: `StandUser_TheStar`
- Grant passive: `STAND_SUBCLASS_THE_STAR`
- Progression by class level:
  - L3: `STAND_USER_THE_STAR_TIER_EARLY`
  - L6: `STAND_USER_THE_STAR_TIER_MID`
  - L10: `STAND_USER_THE_STAR_TIER_LATE`
  - L12: `STAND_USER_THE_STAR_CAPSTONE`

## Stand Entity Contract
- `TheStar.summonTemplate` must point to the concrete Star Platinum root template.
- Do not add `fallbackSummonTemplate` or stock-body fallback paths.
- Star Platinum combat actions belong on the concrete character/stat entry, not on player spell lists.
- Lua must not repair missing Stand actions with `AddSpell`; missing Stand actions are a data/config failure.

### Future Reserved
- `StandUser_TheWorld` -> `STAND_SUBCLASS_THE_WORLD`
- `StandUser_TheHermit` -> `STAND_SUBCLASS_THE_HERMIT`

## Runtime Integration Contract
The Lua runtime resolves subclass by passive and expects these IDs:
- `STAND_SUBCLASS_THE_STAR`
- `STAND_SUBCLASS_THE_WORLD`
- `STAND_SUBCLASS_THE_HERMIT`

If you rename passives in toolkit records, update:
- `ScriptExtender/Lua/StandFramework/StandSystem.lua`

## Why this is included
BG3 class records are best authored in toolkit UI/lsx flows and vary by patch. This template prevents architecture drift while you wire native class data.
