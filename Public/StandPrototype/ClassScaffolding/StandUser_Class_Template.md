# Stand User Class/Subclass Toolkit Scaffolding

This file is a concrete mapping for creating true BG3 toolkit class/subclass records that match this prototype runtime.

## Base Class
- Class Internal Name: `StandUser`
- Display: `Stand User`
- Primary Ability Suggestion: `CHA`
- Hit Die Suggestion: `d8`
- Save Proficiencies Suggestion: `WIS`, `CHA`
- Core Passive at Level 1: `STAND_USER_BASE_CLASS_PASSIVE`
- Core spells at Level 1:
  - `Target_Stand_Manifest`
  - `Target_Stand_Withdraw`

## Subclass Group (Arcana)
Create subclass choice at class level 1 or 3 (recommended: 1 for prototype).

### The Star
- Subclass Internal Name: `StandUser_TheStar`
- Grant passive: `STAND_SUBCLASS_THE_STAR`
- Progression by class level:
  - L1: `STAND_USER_THE_STAR_TIER_EARLY`
  - L5: `STAND_USER_THE_STAR_TIER_MID`
  - L9: `STAND_USER_THE_STAR_TIER_LATE`
  - L12: `STAND_USER_THE_STAR_CAPSTONE`

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
