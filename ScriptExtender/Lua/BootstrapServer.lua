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
  h00010001g0000g0000g0000g00000000009B = "Stand",
  h00010001g0000g0000g0000g0000000000A0 = "Stand User Field Jacket",
  h00010001g0000g0000g0000g0000000000A1 = "A flexible starter jacket tailored for Stand Users who fight unarmored and need unrestricted movement.",
  h00010001g0000g0000g0000g0000000000A2 = "Stand User Field Boots",
  h00010001g0000g0000g0000g0000000000A3 = "Light boots built for close-range footwork and quick Stand repositioning.",
  h00010001g0000g0000g0000g0000000000A4 = "Spirit Draught",
  h00010001g0000g0000g0000g0000000000A5 = "A field medicine prepared for Stand Users. Mechanically equivalent to a basic healing potion.",
  h00010001g0000g0000g0000g0000000000A6 = "Emergency Soul Anchor",
  h00010001g0000g0000g0000g0000000000A7 = "A sealed emergency charm carried by Stand Users. Mechanically equivalent to a revivify scroll.",
  h00010001g0000g0000g0000g0000000000A8 = "Stand User Keychain",
  h00010001g0000g0000g0000g0000000000A9 = "A dedicated key ring issued with the Stand User kit.",
  h00010001g0000g0000g0000g0000000000AA = "Stand User Alchemy Satchel",
  h00010001g0000g0000g0000g0000000000AB = "A compact alchemy pouch for reagents gathered during Stand User fieldwork.",
  h00010001g0000g0000g0000g0000000000AC = "Stand User Camp Coat",
  h00010001g0000g0000g0000g0000000000AD = "Formal camp clothing selected for a Stand User's composed field presence.",
  h00010001g0000g0000g0000g0000000000AE = "Stand User Camp Boots",
  h00010001g0000g0000g0000g0000000000AF = "Simple camp boots matched to the Stand User field kit.",
  h00010001g0000g0000g0000g0000000000B0 = "Midnight Stand Dye",
  h00010001g0000g0000g0000g0000000000B1 = "A dark blue-black dye reserved for Stand User starting gear.",
  h00010001g0000g0000g0000g0000000000B2 = "Stardust Dye",
  h00010001g0000g0000g0000g0000000000B3 = "A vivid blue dye reserved for Stand User starting gear.",
  h00010001g0000g0000g0000g0000000000B4 = "Arcana Dye",
  h00010001g0000g0000g0000g0000000000B5 = "A blue-purple dye reserved for Stand User starting gear.",
  h00010001g0000g0000g0000g0000000000B6 = "Stand User Camp Supplies",
  h00010001g0000g0000g0000g0000000000B7 = "A compact starter supply pack for a newly awakened Stand User.",
  h00010001g0000g0000g0000g0000000000B8 = "Stand Combat Body",
  h00010001g0000g0000g0000g0000000000B9 = "Internal passive marking a manifested Stand entity controlled by the Stand User framework.",
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
