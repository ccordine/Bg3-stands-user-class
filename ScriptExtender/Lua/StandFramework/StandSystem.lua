if not StandSystem then
  StandSystem = {}
end

StandSystem.Active = {}
StandSystem.StandOwner = {}
StandSystem.UserArcana = {}
StandSystem.UserProgression = {}
StandSystem.DamageLinkGuard = {}

local NULL_GUID = "NULL_00000000-0000-0000-0000-000000000000"
local DEFAULT_CLOSE_RANGE_TETHER = 9.0

local MIRRORABLE_STATUSES = {
  BURNING = true,
  BLEEDING = true,
  POISONED = true,
  PRONE = true,
  DAZED = true,
  PARALYZED = true,
  STUNNED = true
}

local STAND_WEAPON_SLOTS = {
  "Weapon",
  "Shield",
  "Melee Main Weapon",
  "Melee Offhand Weapon",
  "Ranged Main Weapon",
  "Ranged Offhand Weapon"
}

local USER_FORBIDDEN_STAND_SPELLS = {
  "Target_Stand_Barrage",
  "Target_Stand_HeavyPunch",
  "Target_Stand_Intercept",
  "Target_Stand_PrecisionCounter",
  "Target_Stand_LeapCloser",
  "Target_Stand_Rush",
  "Target_Stand_StarFinger",
  "Target_Stand_RelentlessBarrage",
  "Target_Stand_TimeStop"
}


local GLOBAL_INHERITED_STAND_SPELL_BLOCKLIST = {
  "Target_LifeDrain_Wraith",
  "Target_CreateShadow_Wraith",
  "Target_EtherealJaunt",
  "Target_EtherealJaunt_Queen",
  "Target_EtherealJaunt_Spiderling"
}

local KNOWN_FEAT_PASSIVE_SYNC_CANDIDATES = {
  "Actor",
  "Alert",
  "Athlete_PassiveBonuses",
  "Athlete_StandUp",
  "DefensiveDuelist",
  "DualWielder_BonusAC",
  "DualWielder_PassiveBonuses",
  "ElementalAdept_Acid",
  "ElementalAdept_Cold",
  "ElementalAdept_Fire",
  "ElementalAdept_Lightning",
  "ElementalAdept_Thunder",
  "GreatWeaponMaster_BonusAttack",
  "GreatWeaponMaster_BonusDamage",
  "Lucky",
  "Lucky_Unlock",
  "MageSlayer_Advantage",
  "MageSlayer_AttackCaster",
  "MageSlayer_BreakConcentration",
  "MagicInitiate_Bard",
  "MagicInitiate_Cleric",
  "MagicInitiate_Druid",
  "MagicInitiate_Sorcerer",
  "MagicInitiate_Warlock",
  "MagicInitiate_Wizard",
  "MediumArmorMaster",
  "Mobile",
  "Mobile_PassiveBonuses",
  "Mobile_CounterAttackOfOpportunity",
  "Mobile_DashAcrossDifficultTerrain",
  "PolearmMaster_AttackOfOpportunity",
  "PolearmMaster_BonusAttack",
  "Resilient_Charisma",
  "Resilient_Constitution",
  "Resilient_Dexterity",
  "Resilient_Intelligence",
  "Resilient_Strength",
  "Resilient_Wisdom",
  "RitualCaster_FreeSpells",
  "SavageAttacker",
  "Sentinel",
  "Sentinel_Attack",
  "Sentinel_OpportunityAdvantage",
  "Sentinel_ZeroSpeed",
  "Sharpshooter_AllIn",
  "Sharpshooter_Bonuses",
  "SpellSniper_Critical",
  "TavernBrawler",
  "TavernBrawler_Bonuses",
  "Tough",
  "WarCaster_Bonuses",
  "WarCaster_OpportunitySpell",
  "WeaponMaster"
}

local function ensureTables()
  StandSystem.Active = StandSystem.Active or {}
  StandSystem.StandOwner = StandSystem.StandOwner or {}
  StandSystem.UserArcana = StandSystem.UserArcana or {}
  StandSystem.UserProgression = StandSystem.UserProgression or {}
  StandSystem.DamageLinkGuard = StandSystem.DamageLinkGuard or {}
end

local function isValidGuid(guid)
  return guid and guid ~= "" and guid ~= NULL_GUID
end

local function trace(msg)
  if Ext and Ext.Utils and Ext.Utils.PrintWarning then
    Ext.Utils.PrintWarning("[StandPrototype] " .. tostring(msg))
  end
end

local function logInfo(msg)
  trace("INFO " .. tostring(msg))
end

local function logWarn(msg)
  trace("WARN " .. tostring(msg))
end

local function logError(msg)
  if Ext and Ext.Utils and Ext.Utils.PrintError then
    Ext.Utils.PrintError("[StandPrototype] ERROR " .. tostring(msg))
  else
    trace("ERROR " .. tostring(msg))
  end
end

local function formatCallResult(ok, ...)
  local parts = { ok and "ok" or "error" }
  local count = select("#", ...)
  for i = 1, count do
    table.insert(parts, tostring(select(i, ...)))
  end
  return table.concat(parts, " | ")
end

local function callAndTrace(label, fn, ...)
  local ok, a, b, c, d = pcall(fn, ...)
  local line = label .. " => " .. formatCallResult(ok, a, b, c, d)
  if ok then
    logInfo(line)
  else
    logError(line)
  end
  return ok, a, b, c, d
end

local function safeOsi(label, fn, ...)
  return callAndTrace(label, fn, ...)
end

local function statusSafe(target, status, duration, force, source, reason)
  return safeOsi(
    "Osi.ApplyStatus"
      .. " reason=[" .. tostring(reason) .. "]"
      .. " target=[" .. tostring(target) .. "]"
      .. " status=[" .. tostring(status) .. "]"
      .. " duration=[" .. tostring(duration) .. "]"
      .. " source=[" .. tostring(source) .. "]",
    Osi.ApplyStatus,
    target,
    status,
    duration,
    force,
    source
  )
end

local function startsWith(value, prefix)
  return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local function isProbablyStatsId(value)
  return type(value) == "string"
    and value ~= ""
    and not value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
    and not value:match("^%d+$")
end

local function safeForEachPair(value, callback)
  local ok, iter, state, initial = pcall(pairs, value)
  if not ok or not iter then
    return
  end

  local key = initial
  while true do
    local okNext, nextKey, nextValue = pcall(iter, state, key)
    if not okNext then
      break
    end
    if nextKey == nil then
      break
    end
    callback(nextKey, nextValue)
    key = nextKey
  end
end

local function addIfStatsId(out, value, allow)
  if isProbablyStatsId(value) and (not allow or allow(value)) then
    out[value] = true
  end
end

local function getExtEntity(guid)
  if not Ext or not Ext.Entity or not Ext.Entity.Get then
    return nil
  end

  local ok, entity = pcall(Ext.Entity.Get, guid)
  if ok then
    return entity
  end
  return nil
end

local getUserState

local function getTemplateSafe(guid)
  if type(Osi.GetTemplate) ~= "function" then
    return "Osi.GetTemplate unavailable"
  end

  local ok, template = pcall(Osi.GetTemplate, guid)
  if ok then
    return tostring(template)
  end

  return "GetTemplate error: " .. tostring(template)
end

local function getPositionSummary(guid)
  local ok, x, y, z = pcall(Osi.GetPosition, guid)
  if ok and x then
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
  end
  return "unavailable:" .. tostring(x)
end

local function hasPassiveSummary(entity, passive)
  local ok, result = pcall(Osi.HasPassive, entity, passive)
  if ok then
    return tostring(result)
  end
  return "error:" .. tostring(result)
end

local function describeDefinition(def)
  if not def then
    return "def=nil"
  end

  return "defId=[" .. tostring(def.id) .. "]"
    .. " displayName=[" .. tostring(def.displayName) .. "]"
    .. " standName=[" .. tostring(def.standName) .. "]"
    .. " summonTemplate=[" .. tostring(def.summonTemplate) .. "]"
    .. " fallbackSummonTemplate=[" .. tostring(def.fallbackSummonTemplate) .. "]"
    .. " nameHandle=[" .. tostring(def.standDisplayNameHandle) .. "]"
end

local function describeEntity(label, guid)
  return tostring(label) .. "=["
    .. "guid=" .. tostring(guid)
    .. " template=" .. tostring(getTemplateSafe(guid))
    .. " pos=" .. tostring(getPositionSummary(guid))
    .. " standUserPassive=" .. tostring(hasPassiveSummary(guid, "STAND_USER_BASE_CLASS_PASSIVE"))
    .. " theStarPassive=" .. tostring(hasPassiveSummary(guid, "STAND_SUBCLASS_THE_STAR"))
    .. "]"
end

local function logStateSnapshot(label, user, stand, def)
  local state = user and getUserState(user) or nil
  logInfo(
    "SNAPSHOT " .. tostring(label)
      .. " " .. describeEntity("user", user)
      .. " " .. describeEntity("stand", stand)
      .. " stateStand=[" .. tostring(state and state.stand) .. "]"
      .. " stateArcana=[" .. tostring(state and state.arcana) .. "]"
      .. " stateTether=[" .. tostring(state and state.tetherRange) .. "]"
      .. " activeCountApprox=[" .. tostring(StandSystem.Active and "available" or "nil") .. "]"
      .. " " .. describeDefinition(def)
  )
end

local function collectIdsFromObject(value, out, candidateFields, allow, depth, seen)
  if depth <= 0 or value == nil then
    return
  end

  local valueType = type(value)
  if valueType == "string" then
    addIfStatsId(out, value, allow)
    return
  elseif valueType ~= "table" and valueType ~= "userdata" then
    return
  end

  seen = seen or {}
  if seen[value] then
    return
  end
  seen[value] = true

  for field, _ in pairs(candidateFields) do
    local ok, fieldValue = pcall(function()
      return value[field]
    end)
    if ok then
      collectIdsFromObject(fieldValue, out, candidateFields, allow, depth - 1, seen)
    end
  end

  safeForEachPair(value, function(key, child)
    if candidateFields[key] then
      collectIdsFromObject(child, out, candidateFields, allow, depth - 1, seen)
    elseif type(child) == "table" or type(child) == "userdata" then
      collectIdsFromObject(child, out, candidateFields, allow, depth - 1, seen)
    end
  end)
end

local function collectEntityComponentIds(guid, componentNames, candidateFields, allow)
  local out = {}
  local entity = getExtEntity(guid)
  if not entity then
    return out
  end

  for _, componentName in ipairs(componentNames) do
    local ok, component = pcall(function()
      return entity[componentName]
    end)
    if ok and component then
      collectIdsFromObject(component, out, candidateFields, allow, 4, {})
    end
  end

  return out
end

local function getDistance(a, b)
  if not a or not b or a == "" or b == "" then
    return 0.0
  end

  local okA, ax, ay, az = pcall(Osi.GetPosition, a)
  local okB, bx, by, bz = pcall(Osi.GetPosition, b)
  if not okA or not okB or not ax or not bx then
    return 0.0
  end

  local dx = ax - bx
  local dy = ay - by
  local dz = az - bz
  return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function sortedKeys(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

getUserState = function(user)
  return StandSystem.Active[user]
end

local function getOwnerFromStand(stand)
  return StandSystem.StandOwner[stand]
end

local function isStandUser(user)
  return Osi.HasPassive(user, "STAND_USER_BASE_CLASS_PASSIVE") == 1
end

local function hasAnyPassive(entity, ids)
  for _, id in ipairs(ids) do
    local ok, hasPassive = pcall(Osi.HasPassive, entity, id)
    if ok and hasPassive == 1 then
      return true
    end
  end
  return false
end

local function hasPassiveSafe(entity, passive)
  local ok, hasPassive = pcall(Osi.HasPassive, entity, passive)
  return ok and hasPassive == 1
end

local function getAbilityValue(entity, abilityName)
  local ok, val = pcall(Osi.GetAbility, entity, abilityName)
  if not ok then
    return 10
  end
  local n = tonumber(val)
  if not n then
    return 10
  end
  return n
end

local function getAbilityMod(entity, abilityName)
  local score = getAbilityValue(entity, abilityName)
  return math.floor((score - 10) / 2)
end

local function isWearingArmor(user)
  local ok, chest = pcall(Osi.GetEquippedItem, user, "Breast")
  if not ok or not chest or chest == "" then
    return false
  end

  -- Safe heuristic: armor-tagged chest pieces count as armor.
  local armorTagged = 0
  local armorOk, armorResult = pcall(Osi.IsTagged, chest, "ARMOR", 1)
  if armorOk and armorResult then
    armorTagged = armorResult
  end

  return armorTagged == 1
end

local function unequipIfEquipped(character, itemGuid)
  if not isValidGuid(itemGuid) then
    logWarn("unequip skipped invalid item character=[" .. tostring(character) .. "] item=[" .. tostring(itemGuid) .. "]")
    return
  end
  safeOsi("Osi.Unequip character=[" .. tostring(character) .. "] item=[" .. tostring(itemGuid) .. "]", Osi.Unequip, character, itemGuid)
end

local function enforceCharacterUnarmed(character)
  logInfo("enforceCharacterUnarmed start character=[" .. tostring(character) .. "]")
  for _, slot in ipairs(STAND_WEAPON_SLOTS) do
    local ok, itemGuid = pcall(Osi.GetEquippedItem, character, slot)
    if ok and isValidGuid(itemGuid) then
      logWarn("stand weapon slot occupied; unequipping character=[" .. tostring(character) .. "] slot=[" .. tostring(slot) .. "] item=[" .. tostring(itemGuid) .. "]")
      unequipIfEquipped(character, itemGuid)
    elseif not ok then
      logError("Osi.GetEquippedItem failed character=[" .. tostring(character) .. "] slot=[" .. tostring(slot) .. "] err=[" .. tostring(itemGuid) .. "]")
    end
  end

  local okWeapon, weaponGuid = pcall(Osi.GetEquippedWeapon, character)
  if okWeapon and isValidGuid(weaponGuid) then
    logWarn("stand equipped weapon detected; unequipping character=[" .. tostring(character) .. "] weapon=[" .. tostring(weaponGuid) .. "]")
    unequipIfEquipped(character, weaponGuid)
  elseif not okWeapon then
    logError("Osi.GetEquippedWeapon failed character=[" .. tostring(character) .. "] err=[" .. tostring(weaponGuid) .. "]")
  end

  local okShield, shieldGuid = pcall(Osi.GetEquippedShield, character)
  if okShield and isValidGuid(shieldGuid) then
    logWarn("stand equipped shield detected; unequipping character=[" .. tostring(character) .. "] shield=[" .. tostring(shieldGuid) .. "]")
    unequipIfEquipped(character, shieldGuid)
  elseif not okShield then
    logError("Osi.GetEquippedShield failed character=[" .. tostring(character) .. "] err=[" .. tostring(shieldGuid) .. "]")
  end
  logInfo("enforceCharacterUnarmed complete character=[" .. tostring(character) .. "]")
end

local function removeSpellSafe(character, spell)
  local ok, err = pcall(Osi.RemoveSpell, character, spell, 1)
  if not ok then
    logWarn("Osi.RemoveSpell arity-3 failed character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "] err=[" .. tostring(err) .. "]; retrying arity-2")
    safeOsi("Osi.RemoveSpell retry character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "]", Osi.RemoveSpell, character, spell)
  else
    logInfo("Osi.RemoveSpell checked/removed character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "]")
  end
end

local function hasSpellSafe(character, spell)
  if type(Osi.HasSpell) ~= "function" then
    logWarn("Osi.HasSpell unavailable; cannot verify concrete spell ownership character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "]")
    return nil
  end

  local ok, result = pcall(Osi.HasSpell, character, spell)
  if ok then
    logInfo("Osi.HasSpell character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "] result=[" .. tostring(result) .. "]")
    return result == 1 or result == true
  end

  logError("Osi.HasSpell failed character=[" .. tostring(character) .. "] spell=[" .. tostring(spell) .. "] err=[" .. tostring(result) .. "]")
  return nil
end

local function enforceUserCommandOnlySpellbook(user)
  logInfo("enforceUserCommandOnlySpellbook start user=[" .. tostring(user) .. "]")
  for _, spell in ipairs(USER_FORBIDDEN_STAND_SPELLS) do
    removeSpellSafe(user, spell)
  end
  logInfo("enforceUserCommandOnlySpellbook complete user=[" .. tostring(user) .. "]")
end

local function collectActionsByLevel(actionTable, level)
  local actions = {}
  local seen = {}
  if not actionTable then
    return actions
  end

  for _, unlockLevel in ipairs(sortedKeys(actionTable)) do
    if unlockLevel <= level then
      for _, spell in ipairs(actionTable[unlockLevel]) do
        if not seen[spell] then
          seen[spell] = true
          table.insert(actions, spell)
        end
      end
    end
  end

  return actions
end

local function collectAllActions(actionTable)
  return collectActionsByLevel(actionTable, 99)
end

local function repairStandActionSpellbook(user, stand, def)
  local level = StandSystem.GetUserStandProgressLevel(user)
  local arcana = StandSystem.ResolveArcana(user)
  local allowed = {}

  trace(
    "repairStandActionSpellbook start: concrete template/stat ownership is primary; runtime AddSpell is repair fallback only"
      .. " user=[" .. tostring(user) .. "]"
      .. " stand=[" .. tostring(stand) .. "]"
      .. " arcana=[" .. tostring(arcana) .. "]"
      .. " defId=[" .. tostring(def and def.id) .. "]"
      .. " level=[" .. tostring(level) .. "]"
  )

  for _, spell in ipairs(GLOBAL_INHERITED_STAND_SPELL_BLOCKLIST) do
    removeSpellSafe(stand, spell)
  end
  if def.inheritedSpellBlocklist then
    for _, spell in ipairs(def.inheritedSpellBlocklist) do
      removeSpellSafe(stand, spell)
    end
  end

  for _, spell in ipairs(collectActionsByLevel(def.standActions, level)) do
    allowed[spell] = true
    local hasSpell = hasSpellSafe(stand, spell)
    if hasSpell == true then
      trace("Concrete stand spell already present spell=[" .. tostring(spell) .. "] stand=[" .. tostring(stand) .. "]")
    else
      trace(
        "Runtime AddSpell repair fallback"
          .. " spell=[" .. tostring(spell) .. "]"
          .. " stand=[" .. tostring(stand) .. "]"
          .. " concreteCheck=[" .. tostring(hasSpell) .. "]"
      )
      callAndTrace(
        "Osi.AddSpell repair fallback spell=[" .. tostring(spell) .. "]",
        Osi.AddSpell,
        stand,
        spell,
        0,
        1
      )
    end
  end

  for _, spell in ipairs(collectAllActions(def.standActions)) do
    if not allowed[spell] then
      removeSpellSafe(stand, spell)
    end
  end

  for _, spell in ipairs(USER_FORBIDDEN_STAND_SPELLS) do
    if not allowed[spell] then
      removeSpellSafe(stand, spell)
    end
  end

  trace(
    "repairStandActionSpellbook complete"
      .. " user=[" .. tostring(user) .. "]"
      .. " stand=[" .. tostring(stand) .. "]"
      .. " level=[" .. tostring(level) .. "]"
  )
end

local function grantTierPassives(user, def, maxGranted)
  local level = StandSystem.GetUserStandProgressLevel(user)
  local highestGranted = maxGranted or 0
  logInfo(
    "grantTierPassives start"
      .. " user=[" .. tostring(user) .. "]"
      .. " level=[" .. tostring(level) .. "]"
      .. " maxGranted=[" .. tostring(maxGranted) .. "]"
      .. " " .. describeDefinition(def)
  )

  for _, unlockLevel in ipairs(sortedKeys(def.passives)) do
    if unlockLevel <= level and unlockLevel > highestGranted then
      for _, passive in ipairs(def.passives[unlockLevel]) do
        safeOsi("Osi.AddPassive tier user=[" .. tostring(user) .. "] unlockLevel=[" .. tostring(unlockLevel) .. "] passive=[" .. tostring(passive) .. "]", Osi.AddPassive, user, passive)
      end
      highestGranted = unlockLevel
    end
  end

  StandSystem.UserProgression[user] = highestGranted
  logInfo("grantTierPassives complete user=[" .. tostring(user) .. "] highestGranted=[" .. tostring(highestGranted) .. "]")
end

local function shouldMirrorUserPassive(passive)
  return isProbablyStatsId(passive) and not startsWith(passive, "STAND_")
end

local function syncUserPassivesToStand(user, stand)
  logInfo("syncUserPassivesToStand start user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "]")
  for _, passive in ipairs(KNOWN_FEAT_PASSIVE_SYNC_CANDIDATES) do
    if shouldMirrorUserPassive(passive) and hasPassiveSafe(user, passive) and not hasPassiveSafe(stand, passive) then
      safeOsi("Osi.AddPassive mirrored-known stand=[" .. tostring(stand) .. "] passive=[" .. tostring(passive) .. "] user=[" .. tostring(user) .. "]", Osi.AddPassive, stand, passive)
    end
  end

  local passives = collectEntityComponentIds(user, {
    "PassiveContainer",
    "Passives",
    "ServerPassiveContainer"
  }, {
    ID = true,
    Id = true,
    Passive = true,
    PassiveId = true,
    PassiveName = true
  }, shouldMirrorUserPassive)

  for passive, _ in pairs(passives) do
    if hasPassiveSafe(user, passive) and not hasPassiveSafe(stand, passive) then
      safeOsi("Osi.AddPassive mirrored-component stand=[" .. tostring(stand) .. "] passive=[" .. tostring(passive) .. "] user=[" .. tostring(user) .. "]", Osi.AddPassive, stand, passive)
    end
  end
  logInfo("syncUserPassivesToStand complete user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "]")
end

local function syncUserCapabilitiesToStand(user, stand)
  syncUserPassivesToStand(user, stand)
end

local function applyStandDisplayName(stand, def)
  local standName = (def and (def.standName or def.displayName)) or "Stand"
  local nameHandle = def and def.standDisplayNameHandle
  local applied = false

  if not nameHandle or nameHandle == "" then
    logError("Stand display name handle missing stand=[" .. tostring(stand) .. "] " .. describeDefinition(def))
    return
  end

  if type(Osi.SetDisplayName) == "function" and nameHandle and nameHandle ~= "" then
    local ok = safeOsi("Osi.SetDisplayName stand=[" .. tostring(stand) .. "] handle=[" .. tostring(nameHandle) .. "]", Osi.SetDisplayName, stand, nameHandle)
    applied = ok
  else
    logWarn("Osi.SetDisplayName unavailable; relying on root template DisplayName stand=[" .. tostring(stand) .. "] handle=[" .. tostring(nameHandle) .. "]")
  end

  logInfo(
    "Stand display name resolved from concrete localization/template wiring"
      .. " stand=[" .. tostring(stand) .. "]"
      .. " name=[" .. tostring(standName) .. "]"
      .. " handle=[" .. tostring(nameHandle) .. "]"
      .. " runtimeApplied=[" .. tostring(applied) .. "]"
  )
end

local function applyStandPresentation(user, stand, def, includeEquipment)
  logInfo("applyStandPresentation start user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "] includeEquipment=[" .. tostring(includeEquipment) .. "] " .. describeDefinition(def))
  if def.visualStatuses then
    for _, status in ipairs(def.visualStatuses) do
      statusSafe(stand, status, -1.0, 1, user, "stand_visual")
    end
  else
    logWarn("Stand definition has no visualStatuses " .. describeDefinition(def))
  end

  if includeEquipment and def.standEquipmentTemplates then
    for _, template in ipairs(def.standEquipmentTemplates) do
      local ok, item = safeOsi("Osi.TemplateAddTo stand presentation template=[" .. tostring(template) .. "] stand=[" .. tostring(stand) .. "]", Osi.TemplateAddTo, template, stand, 1)
      if ok and isValidGuid(item) then
        safeOsi("Osi.CharacterEquipItem stand presentation stand=[" .. tostring(stand) .. "] item=[" .. tostring(item) .. "]", Osi.CharacterEquipItem, stand, item)
      else
        logError("Stand presentation equipment failed template=[" .. tostring(template) .. "] stand=[" .. tostring(stand) .. "] result=[" .. tostring(item) .. "]")
      end
    end
  elseif includeEquipment then
    logWarn("includeEquipment requested but no standEquipmentTemplates present " .. describeDefinition(def))
  end
  logInfo("applyStandPresentation complete stand=[" .. tostring(stand) .. "]")
end

local function tryCreateStand(template, user, x, y, z)
  if not template or template == "" then
    logError("tryCreateStand failed: empty template user=[" .. tostring(user) .. "] pos=[" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "]")
    return nil, "template_empty"
  end

  logInfo("tryCreateStand start template=[" .. tostring(template) .. "] user=[" .. tostring(user) .. "] pos=[" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "]")
  local okCreateAt, created = pcall(Osi.CreateAt, template, x + 1.2, y, z, 1, 0, "")
  if okCreateAt and isValidGuid(created) then
    logInfo("tryCreateStand CreateAt succeeded template=[" .. tostring(template) .. "] created=[" .. tostring(created) .. "]")
    return created, "CreateAt"
  end
  logWarn("tryCreateStand CreateAt failed template=[" .. tostring(template) .. "] ok=[" .. tostring(okCreateAt) .. "] result=[" .. tostring(created) .. "]")

  local okCreateAtObject, createdAtObject = pcall(Osi.CreateAtObject, template, user, 1, 0, "", 1)
  if okCreateAtObject and isValidGuid(createdAtObject) then
    logInfo("tryCreateStand CreateAtObject succeeded template=[" .. tostring(template) .. "] created=[" .. tostring(createdAtObject) .. "]")
    return createdAtObject, "CreateAtObject"
  end
  logWarn("tryCreateStand CreateAtObject failed template=[" .. tostring(template) .. "] ok=[" .. tostring(okCreateAtObject) .. "] result=[" .. tostring(createdAtObject) .. "]")

  logError(
    "Template spawn failed template=[" .. tostring(template)
    .. "] CreateAt=[" .. tostring(okCreateAt) .. ":" .. tostring(created)
    .. "] CreateAtObject=[" .. tostring(okCreateAtObject) .. ":" .. tostring(createdAtObject) .. "]"
  )
  return nil, "spawn_failed"
end

local function tryCreateStandFromDefinition(def, user, x, y, z)
  local template = def and def.summonTemplate
  logInfo("tryCreateStandFromDefinition " .. describeDefinition(def) .. " user=[" .. tostring(user) .. "]")

  if template and template ~= "" then
    local stand, spawnMethod = tryCreateStand(template, user, x, y, z)
    if isValidGuid(stand) then
      return stand, spawnMethod, template
    end
    return nil, spawnMethod, template
  end

  logError("tryCreateStandFromDefinition failed: no concrete summonTemplate " .. describeDefinition(def) .. " user=[" .. tostring(user) .. "]")
  return nil, "template_empty", template
end

local function enforceStandTether(owner, stand, state)
  if not owner or not stand or not state then
    logError("enforceStandTether missing input owner=[" .. tostring(owner) .. "] stand=[" .. tostring(stand) .. "] state=[" .. tostring(state) .. "]")
    return
  end

  local dist = getDistance(owner, stand)
  if dist <= (state.tetherRange or DEFAULT_CLOSE_RANGE_TETHER) then
    logInfo("enforceStandTether ok owner=[" .. tostring(owner) .. "] stand=[" .. tostring(stand) .. "] distance=[" .. tostring(dist) .. "] tether=[" .. tostring(state.tetherRange) .. "]")
    return
  end

  logWarn("enforceStandTether breach owner=[" .. tostring(owner) .. "] stand=[" .. tostring(stand) .. "] distance=[" .. tostring(dist) .. "] tether=[" .. tostring(state.tetherRange) .. "] breakBehavior=[" .. tostring(state.breakBehavior) .. "]")
  if state.breakBehavior == "AutoReturn" then
    local okPos, ux, uy, uz = pcall(Osi.GetPosition, owner)
    if ux then
      safeOsi("Osi.TeleportToPosition tether autoreturn stand=[" .. tostring(stand) .. "] owner=[" .. tostring(owner) .. "]", Osi.TeleportToPosition, stand, ux + 1.0, uy, uz, "", 0, 1, 0)
      statusSafe(owner, "STAND_TETHER_WARNING", 6.0, 1, stand, "tether_autoreturn")
    else
      logError("enforceStandTether failed: owner position unavailable owner=[" .. tostring(owner) .. "] ok=[" .. tostring(okPos) .. "] result=[" .. tostring(ux) .. "]")
    end
  else
    statusSafe(stand, "STAND_TETHER_LOCKED", 6.0, 1, owner, "tether_locked")
  end
end

function StandSystem.RefreshUnarmoredDiscipline(user)
  if not isStandUser(user) then
    logWarn("RefreshUnarmoredDiscipline skipped non-stand-user user=[" .. tostring(user) .. "]")
    return
  end

  if isWearingArmor(user) then
    logInfo("RefreshUnarmoredDiscipline removing unarmored statuses user=[" .. tostring(user) .. "]")
    safeOsi("Osi.RemoveStatus STAND_USER_UNARMORED_DEFENSE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_UNARMORED_DEFENSE")
    safeOsi("Osi.RemoveStatus STAND_USER_STYLISH_PRESENCE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_STYLISH_PRESENCE")
  else
    logInfo("RefreshUnarmoredDiscipline applying unarmored statuses user=[" .. tostring(user) .. "]")
    statusSafe(user, "STAND_USER_UNARMORED_DEFENSE", -1.0, 1, user, "unarmored_discipline")
    statusSafe(user, "STAND_USER_STYLISH_PRESENCE", -1.0, 1, user, "unarmored_discipline")
  end
end

function StandSystem.RefreshStandDerivedBonuses(user)
  local state = getUserState(user)
  if not state or not state.stand then
    logInfo("RefreshStandDerivedBonuses skipped no active stand user=[" .. tostring(user) .. "]")
    return
  end

  local stand = state.stand
  local def = StandSystem.GetDefinition(user)
  local standLevel = StandSystem.GetUserStandProgressLevel(user)
  local strMod = getAbilityMod(user, "Strength")
  local dexMod = getAbilityMod(user, "Dexterity")
  local conMod = getAbilityMod(user, "Constitution")
  local wisMod = getAbilityMod(user, "Wisdom")

  state.offenseMod = math.max(strMod, dexMod)
  state.tavernBrawler = hasAnyPassive(user, {
    "TavernBrawler",
    "TAVERN_BRAWLER",
    "Tavern_Brawler"
  })

  -- Constitution reduces reflected damage slightly; never below 50%.
  state.damageLinkRatio = math.max(0.5, (state.baseDamageLinkRatio or state.damageLinkRatio or 1.0) - (conMod * 0.03))
  state.tetherRange = state.baseTetherRange or state.tetherRange or DEFAULT_CLOSE_RANGE_TETHER
  if def and def.rules and def.rules.allowTetherScaling then
    state.tetherRange = state.tetherRange + math.max(0, wisMod * 0.5)
  end
  logInfo(
    "RefreshStandDerivedBonuses"
      .. " user=[" .. tostring(user) .. "]"
      .. " stand=[" .. tostring(stand) .. "]"
      .. " level=[" .. tostring(standLevel) .. "]"
      .. " strMod=[" .. tostring(strMod) .. "] dexMod=[" .. tostring(dexMod) .. "] conMod=[" .. tostring(conMod) .. "] wisMod=[" .. tostring(wisMod) .. "]"
      .. " damageLinkRatio=[" .. tostring(state.damageLinkRatio) .. "]"
      .. " tetherRange=[" .. tostring(state.tetherRange) .. "]"
      .. " tavernBrawler=[" .. tostring(state.tavernBrawler) .. "]"
  )

  -- Clear previous derived statuses first.
  safeOsi("Osi.RemoveStatus derived ALERT stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_ALERT_INITIATIVE")
  safeOsi("Osi.RemoveStatus derived MOBILE stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_MOBILE_SURGE")
  safeOsi("Osi.RemoveStatus derived TAVERN stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_TAVERN_PRESSURE")
  safeOsi("Osi.RemoveStatus derived STAR_BASE stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_BASE")
  safeOsi("Osi.RemoveStatus derived STAR_MID stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_MID")
  safeOsi("Osi.RemoveStatus derived STAR_LATE stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_LATE")

  if hasAnyPassive(user, {"Alert", "ALERT"}) then
    statusSafe(stand, "STAND_DERIVED_ALERT_INITIATIVE", -1.0, 1, user, "derived_alert")
  end
  if hasAnyPassive(user, {"Mobile", "MOBILE"}) then
    statusSafe(stand, "STAND_DERIVED_MOBILE_SURGE", -1.0, 1, user, "derived_mobile")
  end
  if state.tavernBrawler then
    statusSafe(stand, "STAND_DERIVED_TAVERN_PRESSURE", -1.0, 1, user, "derived_tavern_brawler")
  end

  if def and def.forceUnarmed then
    enforceCharacterUnarmed(stand)
  end
  applyStandPresentation(user, stand, def, false)
  syncUserCapabilitiesToStand(user, stand)
  enforceStandTether(user, stand, state)

  if def and def.id == "the_star" then
    if (def.baseStandACBonus or 0) > 0 then
      statusSafe(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_BASE", -1.0, 1, user, "star_guard_base")
    end
    if standLevel >= 6 and (def.midStandACBonus or 0) > 0 then
      statusSafe(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_MID", -1.0, 1, user, "star_guard_mid")
    end
    if standLevel >= 10 and (def.lateStandACBonus or 0) > 0 then
      statusSafe(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_LATE", -1.0, 1, user, "star_guard_late")
    end
  end
end

function StandSystem.ResolveArcana(user)
  ensureTables()
  local previous = StandSystem.UserArcana[user]
  if Osi.HasPassive(user, "STAND_SUBCLASS_THE_WORLD") == 1 then
    StandSystem.UserArcana[user] = "TheWorld"
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_HERMIT") == 1 then
    StandSystem.UserArcana[user] = "TheHermit"
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_STAR") == 1 then
    StandSystem.UserArcana[user] = "TheStar"
  else
    StandSystem.UserArcana[user] = StandDefinitions.Core.defaultArcana
  end

  logInfo("ResolveArcana user=[" .. tostring(user) .. "] previous=[" .. tostring(previous) .. "] resolved=[" .. tostring(StandSystem.UserArcana[user]) .. "]")
  return StandSystem.UserArcana[user]
end

function StandSystem.GetUserStandProgressLevel(user)
  -- Multiclass-safe progression gate: derive from granted class/subclass passives,
  -- not total character level.
  if Osi.HasPassive(user, "STAND_USER_THE_STAR_CAPSTONE") == 1 then
    return 12
  elseif Osi.HasPassive(user, "STAND_USER_THE_STAR_TIER_LATE") == 1 then
    return 10
  elseif Osi.HasPassive(user, "STAND_USER_THE_STAR_TIER_MID") == 1 then
    return 6
  elseif Osi.HasPassive(user, "STAND_USER_LEVEL5_DISCIPLINE_NOTE") == 1 and Osi.HasPassive(user, "STAND_SUBCLASS_THE_STAR") == 1 then
    return 5
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_STAR") == 1 then
    return 3
  elseif Osi.HasPassive(user, "STAND_USER_DEFENSIVE_SENSE") == 1
    or Osi.HasPassive(user, "STAND_USER_SPIRIT_POOL_TIER1") == 1 then
    return 2
  end

  -- Before Arcana subclass selection, keep the base Stand generic.
  return 1
end

function StandSystem.GetDefinition(user)
  local arcana = StandSystem.ResolveArcana(user)
  local def = StandDefinitions.Arcana[arcana] or StandDefinitions.Arcana[StandDefinitions.Core.defaultArcana]
  if not StandDefinitions.Arcana[arcana] then
    logError("GetDefinition missing arcana definition arcana=[" .. tostring(arcana) .. "] usingDefault=[" .. tostring(StandDefinitions.Core.defaultArcana) .. "] user=[" .. tostring(user) .. "]")
  else
    logInfo("GetDefinition user=[" .. tostring(user) .. "] " .. describeDefinition(def))
  end
  return def
end

function StandSystem.GetOwnerForEntity(entity)
  ensureTables()
  return StandSystem.StandOwner[entity]
end

function StandSystem.CleanupStaleState(user, reason)
  logInfo("CleanupStaleState start user=[" .. tostring(user) .. "] reason=[" .. tostring(reason) .. "]")
  local state = getUserState(user)
  if not state then
    -- Defensive status cleanup for users without a tracked active stand.
    safeOsi("Osi.RemoveStatus cleanup no-state STAND_USER_ACTIVE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_ACTIVE")
    safeOsi("Osi.RemoveStatus cleanup no-state STAND_SPIRITUAL_LINK user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_SPIRITUAL_LINK")
    safeOsi("Osi.RemoveStatus cleanup no-state STAND_VISION user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_VISION")
    logInfo("CleanupStaleState complete no state user=[" .. tostring(user) .. "]")
    return
  end

  local stand = state.stand
  if not stand or stand == "" then
    logWarn("CleanupStaleState found empty stand user=[" .. tostring(user) .. "] reason=[" .. tostring(reason) .. "]")
    StandSystem.Active[user] = nil
    safeOsi("Osi.RemoveStatus cleanup empty-stand STAND_USER_ACTIVE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_ACTIVE")
    safeOsi("Osi.RemoveStatus cleanup empty-stand STAND_SPIRITUAL_LINK user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_SPIRITUAL_LINK")
    safeOsi("Osi.RemoveStatus cleanup empty-stand STAND_VISION user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_VISION")
    return
  end

  local dead = Osi.IsDead(stand)
  if dead == 1 then
    logWarn("CleanupStaleState removing dead stand user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "] reason=[" .. tostring(reason) .. "]")
    StandSystem.Active[user] = nil
    StandSystem.StandOwner[stand] = nil
    safeOsi("Osi.RemoveStatus cleanup dead-stand STAND_USER_ACTIVE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_ACTIVE")
    safeOsi("Osi.RemoveStatus cleanup dead-stand STAND_SPIRITUAL_LINK user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_SPIRITUAL_LINK")
    safeOsi("Osi.RemoveStatus cleanup dead-stand STAND_VISION user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_VISION")
  end
  logStateSnapshot("CleanupStaleState complete", user, stand, StandSystem.GetDefinition(user))
end

function StandSystem.ApplyProgression(user)
  ensureTables()
  if not isStandUser(user) then
    logInfo("ApplyProgression skipped non-stand-user user=[" .. tostring(user) .. "]")
    return
  end

  local def = StandSystem.GetDefinition(user)
  if not def then
    logError("ApplyProgression failed: no definition user=[" .. tostring(user) .. "]")
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "apply_progression_no_definition")
    return
  end

  local level = StandSystem.GetUserStandProgressLevel(user)
  local maxGranted = StandSystem.UserProgression[user] or 0
  logInfo("ApplyProgression start user=[" .. tostring(user) .. "] level=[" .. tostring(level) .. "] maxGranted=[" .. tostring(maxGranted) .. "] " .. describeDefinition(def))

  grantTierPassives(user, def, maxGranted)
  enforceUserCommandOnlySpellbook(user)

  local state = getUserState(user)
  if state and state.stand and isValidGuid(state.stand) and state.arcana ~= def.id then
    logWarn(
      "Active Stand definition changed; remanifesting"
        .. " user=[" .. tostring(user) .. "]"
        .. " oldArcana=[" .. tostring(state.arcana) .. "]"
        .. " newArcana=[" .. tostring(def.id) .. "]"
    )
    StandSystem.Withdraw(user)
    StandSystem.Manifest(user)
    return
  end
  if state and state.stand and isValidGuid(state.stand) then
    repairStandActionSpellbook(user, state.stand, def)
    syncUserCapabilitiesToStand(user, state.stand)
  end

  StandSystem.RefreshUnarmoredDiscipline(user)
  logStateSnapshot("ApplyProgression complete", user, state and state.stand, def)
end

function StandSystem.Manifest(user)
  ensureTables()
  logInfo("Manifest start " .. describeEntity("user", user))
  if not isStandUser(user) then
    logError("Manifest aborted: caster is not a stand user " .. describeEntity("user", user))
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "manifest_non_stand_user")
    return
  end
  StandSystem.ApplyProgression(user)

  if getUserState(user) then
    logWarn("Manifest skipped: user already has active state user=[" .. tostring(user) .. "] stand=[" .. tostring(getUserState(user).stand) .. "]")
    logStateSnapshot("Manifest already active", user, getUserState(user).stand, StandSystem.GetDefinition(user))
    return
  end

  local inCombat = Osi.IsInCombat(user) == 1

  local def = StandSystem.GetDefinition(user)
  if not def or not def.summonTemplate or def.summonTemplate == "" then
    logError("Manifest failed before spawn: missing concrete summonTemplate user=[" .. tostring(user) .. "] " .. describeDefinition(def))
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "manifest_missing_template")
    return
  end
  if def.fallbackSummonTemplate then
    logError("Manifest failed architecture guard: fallbackSummonTemplate present user=[" .. tostring(user) .. "] " .. describeDefinition(def))
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "manifest_fallback_guard")
    return
  end

  local okPos, x, y, z = pcall(Osi.GetPosition, user)
  if not x then
    logError("Manifest aborted: no valid user position user=[" .. tostring(user) .. "] ok=[" .. tostring(okPos) .. "] result=[" .. tostring(x) .. "]")
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "manifest_no_position")
    return
  end

  if Osi.HasActiveStatus(user, "TUT_SUMMON_BLOCK") == 1 then
    logWarn("Manifest removing TUT_SUMMON_BLOCK user=[" .. tostring(user) .. "]")
    safeOsi("Osi.RemoveStatus TUT_SUMMON_BLOCK user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "TUT_SUMMON_BLOCK")
  end

  local stand, spawnMethod, usedTemplate = tryCreateStandFromDefinition(def, user, x, y, z)

  if not isValidGuid(stand) then
    logError(
      "Manifest failed: concrete stand template did not spawn"
        .. " user=[" .. tostring(user) .. "]"
        .. " arcana=[" .. tostring(def.id) .. "]"
        .. " template=[" .. tostring(usedTemplate) .. "]"
        .. " spawnMethodOrFailure=[" .. tostring(spawnMethod) .. "]"
    )
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user, "manifest_spawn_failed")
    return
  end

  logInfo("Manifest spawn succeeded via " .. tostring(spawnMethod) .. " template=[" .. tostring(usedTemplate) .. "] stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]")

  StandSystem.Active[user] = {
    stand = stand,
    arcana = def.id,
    standName = def.standName or def.displayName,
    baseDamageLinkRatio = def.damageLinkProfile.hpRatio,
    damageLinkRatio = def.damageLinkProfile.hpRatio,
    damageLinkType = def.damageLinkProfile.damageType,
    baseTetherRange = def.rangeProfile.tetherRange,
    tetherRange = def.rangeProfile.tetherRange,
    breakBehavior = def.rangeProfile.breakBehavior
  }
  StandSystem.StandOwner[stand] = user
  logStateSnapshot("Manifest state established", user, stand, def)

  local factionOk, faction = pcall(Osi.GetFaction, user)
  if factionOk then
    safeOsi("Osi.SetFaction stand=[" .. tostring(stand) .. "] faction=[" .. tostring(faction) .. "]", Osi.SetFaction, stand, faction)
  else
    logError("Manifest failed to read user faction user=[" .. tostring(user) .. "] err=[" .. tostring(faction) .. "]")
  end
  safeOsi("Osi.SetCanJoinCombat stand=[" .. tostring(stand) .. "]", Osi.SetCanJoinCombat, stand, 1)
  -- Force player-facing identity away from source template names.
  applyStandDisplayName(stand, def)
  if def.forceUnarmed then
    enforceCharacterUnarmed(stand)
  end
  applyStandPresentation(user, stand, def, true)
  safeOsi("Osi.SetTag SUMMON stand=[" .. tostring(stand) .. "]", Osi.SetTag, stand, "SUMMON")
  safeOsi("Osi.AddPartyFollower stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]", Osi.AddPartyFollower, stand, user)
  if inCombat then
    safeOsi("Osi.JoinCombat stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]", Osi.JoinCombat, stand, user)
  end

  statusSafe(user, "STAND_USER_ACTIVE", -1, 1, stand, "manifest_link")
  statusSafe(stand, "STAND_ENTITY_ACTIVE", -1, 1, user, "manifest_link")
  statusSafe(user, "STAND_SPIRITUAL_LINK", -1, 1, stand, "manifest_link")
  statusSafe(user, "STAND_VISION", -1, 1, stand, "manifest_link")

  repairStandActionSpellbook(user, stand, def)
  syncUserCapabilitiesToStand(user, stand)

  StandSystem.RefreshStandDerivedBonuses(user)
  logStateSnapshot("Manifest complete", user, stand, def)
end

function StandSystem.Withdraw(user)
  ensureTables()
  logInfo("Withdraw start user=[" .. tostring(user) .. "]")
  local state = getUserState(user)
  if not state then
    logWarn("Withdraw skipped: no active stand state user=[" .. tostring(user) .. "]")
    return
  end

  local stand = state.stand
  if stand then
    logInfo("Withdraw removing stand user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "]")
    StandSystem.StandOwner[stand] = nil
    safeOsi("Osi.RemoveStatus STAND_ENTITY_ACTIVE stand=[" .. tostring(stand) .. "]", Osi.RemoveStatus, stand, "STAND_ENTITY_ACTIVE")
    safeOsi("Osi.RemovePartyFollower stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]", Osi.RemovePartyFollower, stand, user)
    safeOsi("Osi.LeaveCombat stand=[" .. tostring(stand) .. "]", Osi.LeaveCombat, stand)
    safeOsi("Osi.Die stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]", Osi.Die, stand, 0, user)
  end

  safeOsi("Osi.RemoveStatus STAND_USER_ACTIVE user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_USER_ACTIVE")
  safeOsi("Osi.RemoveStatus STAND_SPIRITUAL_LINK user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_SPIRITUAL_LINK")
  safeOsi("Osi.RemoveStatus STAND_VISION user=[" .. tostring(user) .. "]", Osi.RemoveStatus, user, "STAND_VISION")
  StandSystem.Active[user] = nil
  logInfo("Withdraw complete user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "]")
end

function StandSystem.OnStandDamaged(stand, attacker, damage)
  ensureTables()
  if StandSystem.DamageLinkGuard[stand] then
    logInfo("OnStandDamaged skipped recursion guard stand=[" .. tostring(stand) .. "] attacker=[" .. tostring(attacker) .. "] damage=[" .. tostring(damage) .. "]")
    return
  end

  local user = getOwnerFromStand(stand)
  if not user then
    logInfo("OnStandDamaged ignored non-stand defender=[" .. tostring(stand) .. "] attacker=[" .. tostring(attacker) .. "] damage=[" .. tostring(damage) .. "]")
    return
  end

  local state = getUserState(user)
  if not state then
    logError("OnStandDamaged missing user state stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "] damage=[" .. tostring(damage) .. "]")
    return
  end

  local linked = math.floor(tonumber(damage or 0) * (state.damageLinkRatio or 1.0))
  logInfo("OnStandDamaged stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "] attacker=[" .. tostring(attacker) .. "] rawDamage=[" .. tostring(damage) .. "] linked=[" .. tostring(linked) .. "] ratio=[" .. tostring(state.damageLinkRatio) .. "]")
  if linked > 0 then
    StandSystem.DamageLinkGuard[user] = true
    safeOsi("Osi.ApplyDamage linked stand-to-user user=[" .. tostring(user) .. "] linked=[" .. tostring(linked) .. "]", Osi.ApplyDamage, user, linked, state.damageLinkType or "Psychic", attacker)
    StandSystem.DamageLinkGuard[user] = nil
    statusSafe(user, "STAND_LINKED_DAMAGE_FEEDBACK", 3.0, 1, stand, "linked_damage_stand_to_user")
  end
end

function StandSystem.OnUserDamaged(user, attacker, damage)
  ensureTables()
  if StandSystem.DamageLinkGuard[user] then
    logInfo("OnUserDamaged skipped recursion guard user=[" .. tostring(user) .. "] attacker=[" .. tostring(attacker) .. "] damage=[" .. tostring(damage) .. "]")
    return
  end

  local state = getUserState(user)
  if not state or not state.stand or not isValidGuid(state.stand) then
    logInfo("OnUserDamaged ignored no active stand user=[" .. tostring(user) .. "] attacker=[" .. tostring(attacker) .. "] damage=[" .. tostring(damage) .. "]")
    return
  end

  local linked = math.floor(tonumber(damage or 0) * (state.damageLinkRatio or 1.0))
  logInfo("OnUserDamaged user=[" .. tostring(user) .. "] stand=[" .. tostring(state.stand) .. "] attacker=[" .. tostring(attacker) .. "] rawDamage=[" .. tostring(damage) .. "] linked=[" .. tostring(linked) .. "] ratio=[" .. tostring(state.damageLinkRatio) .. "]")
  if linked > 0 then
    StandSystem.DamageLinkGuard[state.stand] = true
    safeOsi("Osi.ApplyDamage linked user-to-stand stand=[" .. tostring(state.stand) .. "] linked=[" .. tostring(linked) .. "]", Osi.ApplyDamage, state.stand, linked, state.damageLinkType or "Psychic", attacker)
    StandSystem.DamageLinkGuard[state.stand] = nil
  end
end

function StandSystem.OnTurnStarted(entity)
  ensureTables()
  if isStandUser(entity) then
    StandSystem.CleanupStaleState(entity, "turn")
    StandSystem.RefreshUnarmoredDiscipline(entity)
    StandSystem.RefreshStandDerivedBonuses(entity)
  end

  local owner = getOwnerFromStand(entity)
  if not owner then
    return
  end

  local state = getUserState(owner)
  if not state then
    return
  end

  enforceStandTether(owner, entity, state)
end

function StandSystem.TryIntercept(user, incomingAttacker)
  local state = getUserState(user)
  if not state then
    logWarn("TryIntercept skipped no state user=[" .. tostring(user) .. "] incomingAttacker=[" .. tostring(incomingAttacker) .. "]")
    return
  end

  local stand = state.stand
  local dist = getDistance(user, stand)
  logInfo("TryIntercept user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "] incomingAttacker=[" .. tostring(incomingAttacker) .. "] dist=[" .. tostring(dist) .. "] tether=[" .. tostring(state.tetherRange) .. "]")
  if dist <= (state.tetherRange or DEFAULT_CLOSE_RANGE_TETHER) then
    statusSafe(user, "STAND_INTERCEPT_GUARD", 6.0, 1, stand, "intercept")
    statusSafe(user, "STAND_INTERCEPT_TRIGGERED", 3.0, 1, stand, "intercept")
  else
    logWarn("TryIntercept out of range user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "] dist=[" .. tostring(dist) .. "]")
  end
end

function StandSystem.Reposition(user)
  local state = getUserState(user)
  if not state or not state.stand then
    logError("Reposition failed: no active stand user=[" .. tostring(user) .. "]")
    statusSafe(user, "STAND_MANIFEST_BLOCKED", 3.0, 1, user, "reposition_no_stand")
    return
  end

  local stand = state.stand
  local okUserPos, ux, uy, uz = pcall(Osi.GetPosition, user)
  if not ux then
    logError("Reposition failed: user position unavailable user=[" .. tostring(user) .. "] ok=[" .. tostring(okUserPos) .. "] result=[" .. tostring(ux) .. "]")
    return
  end

  local okStandPos, sx, sy, sz = pcall(Osi.GetPosition, stand)
  local tx = ux + 1.2
  local ty = uy
  local tz = uz

  if sx then
    local dx = sx - ux
    local dy = sy - uy
    local planar = math.sqrt((dx * dx) + (dy * dy))
    if planar > 0.1 then
      tx = ux + (dx / planar) * 1.2
      ty = uy + (dy / planar) * 1.2
    end
  elseif not okStandPos then
    logError("Reposition stand position unavailable stand=[" .. tostring(stand) .. "] err=[" .. tostring(sx) .. "]")
  end

  logInfo("Reposition teleport user=[" .. tostring(user) .. "] stand=[" .. tostring(stand) .. "] target=[" .. tostring(tx) .. "," .. tostring(ty) .. "," .. tostring(tz) .. "]")
  safeOsi("Osi.TeleportToPosition reposition stand=[" .. tostring(stand) .. "]", Osi.TeleportToPosition, stand, tx, ty, tz, "", 0, 1, 0)
end

function StandSystem.TryBulletCatch(defender, attacker)
  if Osi.HasPassive(defender, "STAND_FEATURE_BULLET_CATCH") ~= 1 then
    return
  end
  local state = getUserState(defender)
  if not state then
    return
  end
  local stand = state.stand
  local dist = getDistance(defender, attacker)
  if dist >= 8.0 then
    logInfo("TryBulletCatch triggered defender=[" .. tostring(defender) .. "] attacker=[" .. tostring(attacker) .. "] stand=[" .. tostring(stand) .. "] dist=[" .. tostring(dist) .. "]")
    statusSafe(defender, "STAND_BULLET_CATCH_TRIGGERED", 3.0, 1, stand, "bullet_catch")
    statusSafe(defender, "STAND_INTERCEPT_GUARD", 3.0, 1, stand, "bullet_catch")
  end
end

function StandSystem.MirrorStandStatus(stand, status)
  local user = getOwnerFromStand(stand)
  if not user then
    return
  end

  if MIRRORABLE_STATUSES[status] then
    logInfo("MirrorStandStatus status=[" .. tostring(status) .. "] stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]")
    statusSafe(user, "STAND_STATUS_FEEDBACK", 6.0, 1, stand, "status_mirror_feedback")
    statusSafe(user, status, 6.0, 1, stand, "status_mirror_original")
  end
end

function StandSystem.OnStandAttackHit(attacker)
  local owner = getOwnerFromStand(attacker)
  if owner then
    statusSafe(owner, "STAND_REACTION_SYNC", 1.0, 1, attacker, "stand_attack_hit")
  end
end

function StandSystem.OnStandHitTarget(attacker, defender)
  local owner = getOwnerFromStand(attacker)
  if not owner then
    return
  end
  local state = getUserState(owner)
  if not state then
    return
  end

  local bonus = math.max(0, math.floor((state.offenseMod or 0) / 2))
  if state.tavernBrawler then
    bonus = bonus + 1
  end

  if bonus > 0 then
    logInfo("OnStandHitTarget bonus damage attacker=[" .. tostring(attacker) .. "] defender=[" .. tostring(defender) .. "] owner=[" .. tostring(owner) .. "] bonus=[" .. tostring(bonus) .. "]")
    safeOsi("Osi.ApplyDamage stand bonus defender=[" .. tostring(defender) .. "] bonus=[" .. tostring(bonus) .. "]", Osi.ApplyDamage, defender, bonus, "Bludgeoning", attacker)
  end
end

function StandSystem.TryStandClash(attacker, defender)
  local attackerOwner = getOwnerFromStand(attacker)
  local defenderOwner = getOwnerFromStand(defender)
  if not attackerOwner or not defenderOwner then
    return
  end

  local dist = getDistance(attacker, defender)
  if dist <= 4.0 then
    logInfo("TryStandClash attacker=[" .. tostring(attacker) .. "] defender=[" .. tostring(defender) .. "] dist=[" .. tostring(dist) .. "]")
    statusSafe(attacker, "STAND_CLASHING", 1.0, 1, defender, "stand_clash")
    statusSafe(defender, "STAND_CLASHING", 1.0, 1, attacker, "stand_clash")
  end
end

function StandSystem.TriggerTimeStop(user)
  local state = getUserState(user)
  if not state then
    logError("TriggerTimeStop failed: no active stand user=[" .. tostring(user) .. "]")
    statusSafe(user, "STAND_TIMESTOP_NO_STAND", 6.0, 1, user, "timestop_no_stand")
    return
  end

  logInfo("TriggerTimeStop user=[" .. tostring(user) .. "] stand=[" .. tostring(state.stand) .. "]")
  statusSafe(user, "STAND_TIMESTOP_CASTER", 12.0, 1, user, "timestop")
  local stand = state.stand
  statusSafe(stand, "STAND_TIMESTOP_CASTER", 12.0, 1, user, "timestop")

  -- Placeholder capstone behavior: short burst battlefield freeze around Stand.
  safeOsi("Osi.UseSpell Target_Stand_TimeStopPulse stand=[" .. tostring(stand) .. "]", Osi.UseSpell, stand, "Target_Stand_TimeStopPulse", stand, 0, 0, 0)
end

Ext.RegisterNetListener("StandPrototype_Manifest", function(cmd, payload, user)
  logInfo("NetListener StandPrototype_Manifest cmd=[" .. tostring(cmd) .. "] payload=[" .. tostring(payload) .. "] user=[" .. tostring(user) .. "]")
  if payload and payload ~= "" then
    StandSystem.Manifest(payload)
  else
    logError("NetListener StandPrototype_Manifest missing payload cmd=[" .. tostring(cmd) .. "] user=[" .. tostring(user) .. "]")
  end
end)

Ext.RegisterNetListener("StandPrototype_Withdraw", function(cmd, payload, user)
  logInfo("NetListener StandPrototype_Withdraw cmd=[" .. tostring(cmd) .. "] payload=[" .. tostring(payload) .. "] user=[" .. tostring(user) .. "]")
  if payload and payload ~= "" then
    StandSystem.Withdraw(payload)
  else
    logError("NetListener StandPrototype_Withdraw missing payload cmd=[" .. tostring(cmd) .. "] user=[" .. tostring(user) .. "]")
  end
end)

return StandSystem
