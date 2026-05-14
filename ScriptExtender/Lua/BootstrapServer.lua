Ext.Require("StandFramework/StandDefinitions.lua")
Ext.Require("StandFramework/StandSystem.lua")
Ext.Require("StandFramework/SpellHandlers.lua")

local CLASS_LOCA_OVERRIDES = {
  SPSTANDUSERDESC01 = "A spiritual close-range martial class. Stand Users rely on presence, reflexes, and force of will rather than armor. At level 3, choose an Arcana path to manifest a combat Stand with linked-risk tether mechanics.",
  SPSTANDUSERNAME01 = "Stand User",
  SPTHESTARDESC001 = "The Star manifests as a precision close-range powerhouse, overwhelming foes with relentless impact and reaction pressure.",
  SPTHESTARNAME001 = "The Star",
  SPTHESTARSHORT001 = "Star",
  -- Legacy handles from early builds kept for compatibility.
  SP_STANDUSER_DESC = "A spiritual close-range martial class. Stand Users rely on presence, reflexes, and force of will rather than armor. At level 3, choose an Arcana path to manifest a combat Stand with linked-risk tether mechanics.",
  SP_STANDUSER_NAME = "Stand User",
  SP_THESTAR_DESC = "The Star manifests as a precision close-range powerhouse, overwhelming foes with relentless impact and reaction pressure.",
  SP_THESTAR_NAME = "The Star",
  SP_THESTAR_SHORT = "Star"
}

local function applyClassLocaOverrides()
  if not Ext or not Ext.Loca or not Ext.Loca.UpdateTranslatedString then
    return
  end

  for handle, text in pairs(CLASS_LOCA_OVERRIDES) do
    pcall(Ext.Loca.UpdateTranslatedString, handle, text)
  end
end

applyClassLocaOverrides()

Ext.Events.SessionLoaded:Subscribe(function(_)
  applyClassLocaOverrides()

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
