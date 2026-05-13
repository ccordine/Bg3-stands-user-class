Ext.Require("StandFramework/StandDefinitions.lua")
Ext.Require("StandFramework/StandSystem.lua")
Ext.Require("StandFramework/SpellHandlers.lua")

Ext.Events.SessionLoaded:Subscribe(function(_)
  if not Osi or not Osi.DB_Players then
    return
  end

  for _, player in pairs(Osi.DB_Players:Get(nil)) do
    local char = player[1]
    if char and Osi.HasPassive(char, "STAND_USER_BASE_CLASS_PASSIVE") == 1 then
      StandSystem.CleanupStaleState(char, "session_load")
      StandSystem.ApplyProgression(char)
    end
  end
end)
