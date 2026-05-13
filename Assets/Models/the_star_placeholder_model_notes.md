# The Star Placeholder Model Notes

Current runtime stand template is a stock humanoid record configured in Lua:
- `ScriptExtender/Lua/StandFramework/StandDefinitions.lua`
- field: `summonTemplate`

Replacement workflow (future):
1. Author/import a dedicated The Star character template.
2. Replace `summonTemplate` UUID with new template UUID.
3. Keep archetype/tether/damage link data unchanged.
