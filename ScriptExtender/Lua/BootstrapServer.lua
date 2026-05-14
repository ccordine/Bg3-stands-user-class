Ext.Require("StandFramework/StandDefinitions.lua")
Ext.Require("StandFramework/StandSystem.lua")
Ext.Require("StandFramework/SpellHandlers.lua")

if Ext and Ext.Utils and Ext.Utils.PrintWarning then
  Ext.Utils.PrintWarning("[StandPrototype] BootstrapServer loaded")
end

local CLASS_LOCA_OVERRIDES = {
  h4f6dfd10g4ca5g4b2fg8c76g1df52ef9c8c1 = "A spiritual close-range martial class. Stand Users rely on presence, reflexes, and force of will rather than armor. At level 3, choose an Arcana path to manifest a combat Stand with linked-risk tether mechanics.",
  h1a91b8c8g7d65g4c7eg9f1ag36640f1499ef = "Stand User",
  h84f4a14eg56e5g4ec8ga998g67fe7dcef8b3 = "The Star manifests as a precision close-range powerhouse, overwhelming foes with relentless impact and reaction pressure.",
  h4e09986egf919g4605gb7f5g62cf7b2a6e54 = "The Star",
  h901ea68cg1717g46d6g8d95g396ab70c4cf6 = "Star",
  h00010001g0000g0000g0000g00000000009A = "Star Platinum",
  -- Legacy class handles from earlier builds kept for compatibility.
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
end)
