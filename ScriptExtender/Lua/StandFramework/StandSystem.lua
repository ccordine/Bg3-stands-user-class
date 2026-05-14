if not StandSystem then
  StandSystem = {}
end

StandSystem.Active = {}
StandSystem.StandOwner = {}
StandSystem.UserArcana = {}
StandSystem.UserProgression = {}

local NULL_GUID = "NULL_00000000-0000-0000-0000-000000000000"

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
  "Target_Stand_StarFinger",
  "Target_Stand_RushUltimate",
  "Target_Stand_TimeStop"
}

local function ensureTables()
  StandSystem.Active = StandSystem.Active or {}
  StandSystem.StandOwner = StandSystem.StandOwner or {}
  StandSystem.UserArcana = StandSystem.UserArcana or {}
  StandSystem.UserProgression = StandSystem.UserProgression or {}
end

local function isValidGuid(guid)
  return guid and guid ~= "" and guid ~= NULL_GUID
end

local function trace(msg)
  if Ext and Ext.Utils and Ext.Utils.PrintWarning then
    Ext.Utils.PrintWarning("[StandPrototype] " .. tostring(msg))
  end
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

local function getUserState(user)
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
    if Osi.HasPassive(entity, id) == 1 then
      return true
    end
  end
  return false
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
    return
  end
  pcall(Osi.Unequip, character, itemGuid)
end

local function enforceCharacterUnarmed(character)
  for _, slot in ipairs(STAND_WEAPON_SLOTS) do
    local ok, itemGuid = pcall(Osi.GetEquippedItem, character, slot)
    if ok and isValidGuid(itemGuid) then
      unequipIfEquipped(character, itemGuid)
    end
  end

  local okWeapon, weaponGuid = pcall(Osi.GetEquippedWeapon, character)
  if okWeapon and isValidGuid(weaponGuid) then
    unequipIfEquipped(character, weaponGuid)
  end

  local okShield, shieldGuid = pcall(Osi.GetEquippedShield, character)
  if okShield and isValidGuid(shieldGuid) then
    unequipIfEquipped(character, shieldGuid)
  end
end

local function removeSpellSafe(character, spell)
  local ok = pcall(Osi.RemoveSpell, character, spell, 1)
  if not ok then
    pcall(Osi.RemoveSpell, character, spell)
  end
end

local function enforceUserCommandOnlySpellbook(user)
  for _, spell in ipairs(USER_FORBIDDEN_STAND_SPELLS) do
    removeSpellSafe(user, spell)
  end
end

local function grantStandTierSpells(user, stand, def)
  local level = StandSystem.GetUserStandProgressLevel(user)
  for _, unlockLevel in ipairs(sortedKeys(def.progression)) do
    if unlockLevel <= level then
      local tier = def.progression[unlockLevel]
      if tier.standSpells then
        for _, spell in ipairs(tier.standSpells) do
          Osi.AddSpell(stand, spell, 1, 0)
        end
      end
    end
  end
end

local function tryCreateStand(template, user, x, y, z)
  if not template or template == "" then
    return nil, "template_empty"
  end

  local okCreateAt, created = pcall(Osi.CreateAt, template, x + 1.2, y, z, 1, 0, "")
  if okCreateAt and isValidGuid(created) then
    return created, "CreateAt"
  end

  local okCreateAtObject, createdAtObject = pcall(Osi.CreateAtObject, template, user, 1, 0, "", 1)
  if okCreateAtObject and isValidGuid(createdAtObject) then
    return createdAtObject, "CreateAtObject"
  end

  return nil, "spawn_failed"
end

function StandSystem.RefreshUnarmoredDiscipline(user)
  if not isStandUser(user) then
    return
  end

  if isWearingArmor(user) then
    Osi.RemoveStatus(user, "STAND_USER_UNARMORED_DEFENSE")
    Osi.RemoveStatus(user, "STAND_USER_STYLISH_PRESENCE")
  else
    Osi.ApplyStatus(user, "STAND_USER_UNARMORED_DEFENSE", -1.0, 1, user)
    Osi.ApplyStatus(user, "STAND_USER_STYLISH_PRESENCE", -1.0, 1, user)
  end
end

function StandSystem.RefreshStandDerivedBonuses(user)
  local state = getUserState(user)
  if not state or not state.stand then
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
  -- Wisdom tightens control and extends reliable projection modestly.
  state.tetherRange = (state.baseTetherRange or state.tetherRange or 12.0) + math.max(0, wisMod * 0.5)

  -- Clear previous derived statuses first.
  Osi.RemoveStatus(stand, "STAND_DERIVED_ALERT_INITIATIVE")
  Osi.RemoveStatus(stand, "STAND_DERIVED_MOBILE_SURGE")
  Osi.RemoveStatus(stand, "STAND_DERIVED_TAVERN_PRESSURE")
  Osi.RemoveStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_BASE")
  Osi.RemoveStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_MID")
  Osi.RemoveStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_LATE")

  if hasAnyPassive(user, {"Alert", "ALERT"}) then
    Osi.ApplyStatus(stand, "STAND_DERIVED_ALERT_INITIATIVE", -1.0, 1, user)
  end
  if hasAnyPassive(user, {"Mobile", "MOBILE"}) then
    Osi.ApplyStatus(stand, "STAND_DERIVED_MOBILE_SURGE", -1.0, 1, user)
  end
  if state.tavernBrawler then
    Osi.ApplyStatus(stand, "STAND_DERIVED_TAVERN_PRESSURE", -1.0, 1, user)
  end

  if def and def.forceUnarmed then
    enforceCharacterUnarmed(stand)
  end

  if def and def.id == "the_star" then
    if (def.baseStandACBonus or 0) > 0 then
      Osi.ApplyStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_BASE", -1.0, 1, user)
    end
    if standLevel >= 6 and (def.midStandACBonus or 0) > 0 then
      Osi.ApplyStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_MID", -1.0, 1, user)
    end
    if standLevel >= 10 and (def.lateStandACBonus or 0) > 0 then
      Osi.ApplyStatus(stand, "STAND_DERIVED_STAR_PLATINUM_GUARD_LATE", -1.0, 1, user)
    end
  end
end

function StandSystem.ResolveArcana(user)
  ensureTables()
  if StandSystem.UserArcana[user] then
    return StandSystem.UserArcana[user]
  end

  if Osi.HasPassive(user, "STAND_SUBCLASS_THE_WORLD") == 1 then
    StandSystem.UserArcana[user] = "TheWorld"
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_HERMIT") == 1 then
    StandSystem.UserArcana[user] = "TheHermit"
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_STAR") == 1 then
    StandSystem.UserArcana[user] = "TheStar"
  else
    StandSystem.UserArcana[user] = StandDefinitions.Core.defaultArcana
  end

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
  elseif Osi.HasPassive(user, "STAND_SUBCLASS_THE_STAR") == 1 then
    return 3
  end

  -- Before Arcana subclass selection, keep the base progression gate at 1.
  return 1
end

function StandSystem.GetDefinition(user)
  local arcana = StandSystem.ResolveArcana(user)
  return StandDefinitions.Arcana[arcana] or StandDefinitions.Arcana[StandDefinitions.Core.defaultArcana]
end

function StandSystem.GetOwnerForEntity(entity)
  ensureTables()
  return StandSystem.StandOwner[entity]
end

function StandSystem.CleanupStaleState(user, reason)
  local state = getUserState(user)
  if not state then
    -- Defensive status cleanup for users without a tracked active stand.
    Osi.RemoveStatus(user, "STAND_USER_ACTIVE")
    Osi.RemoveStatus(user, "STAND_SPIRITUAL_LINK")
    Osi.RemoveStatus(user, "STAND_VISION")
    return
  end

  local stand = state.stand
  if not stand or stand == "" then
    StandSystem.Active[user] = nil
    Osi.RemoveStatus(user, "STAND_USER_ACTIVE")
    Osi.RemoveStatus(user, "STAND_SPIRITUAL_LINK")
    Osi.RemoveStatus(user, "STAND_VISION")
    return
  end

  local dead = Osi.IsDead(stand)
  if dead == 1 then
    StandSystem.Active[user] = nil
    StandSystem.StandOwner[stand] = nil
    Osi.RemoveStatus(user, "STAND_USER_ACTIVE")
    Osi.RemoveStatus(user, "STAND_SPIRITUAL_LINK")
    Osi.RemoveStatus(user, "STAND_VISION")
  end
end

function StandSystem.ApplyProgression(user)
  ensureTables()
  if not isStandUser(user) then
    return
  end

  local def = StandSystem.GetDefinition(user)
  if not def then
    return
  end

  local level = StandSystem.GetUserStandProgressLevel(user)
  local maxGranted = StandSystem.UserProgression[user] or 0

  for _, unlockLevel in ipairs(sortedKeys(def.progression)) do
    if unlockLevel <= level and unlockLevel > maxGranted then
      local tier = def.progression[unlockLevel]
      if tier.userSpells then
        for _, spell in ipairs(tier.userSpells) do
          Osi.AddSpell(user, spell, 1, 0)
        end
      end
      if tier.passives then
        for _, passive in ipairs(tier.passives) do
          Osi.AddPassive(user, passive)
        end
      end
      StandSystem.UserProgression[user] = unlockLevel
    end
  end

  enforceUserCommandOnlySpellbook(user)

  local state = getUserState(user)
  if state and state.stand and isValidGuid(state.stand) then
    grantStandTierSpells(user, state.stand, def)
  end

  StandSystem.RefreshUnarmoredDiscipline(user)
end

function StandSystem.Manifest(user)
  ensureTables()
  if not isStandUser(user) then
    trace("Manifest aborted: caster is not a stand user [" .. tostring(user) .. "]")
    return
  end
  StandSystem.ApplyProgression(user)

  if getUserState(user) then
    return
  end

  local inCombat = Osi.IsInCombat(user) == 1

  local def = StandSystem.GetDefinition(user)
  local _, x, y, z = pcall(Osi.GetPosition, user)
  if not x then
    trace("Manifest aborted: no valid user position [" .. tostring(user) .. "]")
    return
  end

  if Osi.HasActiveStatus(user, "TUT_SUMMON_BLOCK") == 1 then
    Osi.RemoveStatus(user, "TUT_SUMMON_BLOCK")
  end

  -- BG3 hack: stock humanoid template until dedicated Stand asset is authored.
  local templates = {}
  if type(def.summonTemplates) == "table" then
    for _, t in ipairs(def.summonTemplates) do
      if t and t ~= "" then
        table.insert(templates, t)
      end
    end
  end
  if def.summonTemplate and def.summonTemplate ~= "" then
    table.insert(templates, def.summonTemplate)
  end
  if def.allowUserTemplateFallback ~= false then
    local okTemplate, userTemplate = pcall(Osi.GetTemplate, user)
    if okTemplate and userTemplate and userTemplate ~= "" then
      table.insert(templates, userTemplate)
    end
  end

  -- De-duplicate while preserving priority order.
  local dedup = {}
  local uniqueTemplates = {}
  for _, t in ipairs(templates) do
    if not dedup[t] then
      dedup[t] = true
      table.insert(uniqueTemplates, t)
    end
  end
  templates = uniqueTemplates

  local stand = nil
  local spawnMethod = "none"
  local usedTemplate = "none"
  for _, template in ipairs(templates) do
    local created, method = tryCreateStand(template, user, x, y, z)
    if created then
      stand = created
      spawnMethod = method
      usedTemplate = template
      break
    end
  end

  if not isValidGuid(stand) then
    trace("Manifest failed: no stand created for user [" .. tostring(user) .. "]")
    Osi.ApplyStatus(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user)
    return
  end

  trace("Manifest succeeded via " .. tostring(spawnMethod) .. " template=[" .. tostring(usedTemplate) .. "] stand=[" .. tostring(stand) .. "] user=[" .. tostring(user) .. "]")

  StandSystem.Active[user] = {
    stand = stand,
    arcana = def.id,
    baseDamageLinkRatio = def.damageLinkProfile.hpRatio,
    damageLinkRatio = def.damageLinkProfile.hpRatio,
    damageLinkType = def.damageLinkProfile.damageType,
    baseTetherRange = def.rangeProfile.tetherRange,
    tetherRange = def.rangeProfile.tetherRange,
    breakBehavior = def.rangeProfile.breakBehavior
  }
  StandSystem.StandOwner[stand] = user

  Osi.SetFaction(stand, Osi.GetFaction(user))
  Osi.SetCanJoinCombat(stand, 1)
  -- Force player-facing identity away from source template names like "Specter".
  pcall(Osi.SetStoryDisplayName, stand, "h4e09986egf919g4605gb7f5g62cf7b2a6e54")
  if def.forceUnarmed then
    enforceCharacterUnarmed(stand)
  end
  pcall(Osi.SetTag, stand, "SUMMON")
  pcall(Osi.AddPartyFollower, stand, user)
  if inCombat then
    pcall(Osi.JoinCombat, stand, user)
  end

  Osi.ApplyStatus(user, "STAND_USER_ACTIVE", -1, 1, stand)
  Osi.ApplyStatus(stand, "STAND_ENTITY_ACTIVE", -1, 1, user)
  Osi.ApplyStatus(user, "STAND_SPIRITUAL_LINK", -1, 1, stand)
  Osi.ApplyStatus(user, "STAND_VISION", -1, 1, stand)

  grantStandTierSpells(user, stand, def)

  StandSystem.RefreshStandDerivedBonuses(user)
end

function StandSystem.Withdraw(user)
  ensureTables()
  local state = getUserState(user)
  if not state then
    return
  end

  local stand = state.stand
  if stand then
    StandSystem.StandOwner[stand] = nil
    Osi.RemoveStatus(stand, "STAND_ENTITY_ACTIVE")
    pcall(Osi.RemovePartyFollower, stand, user)
    pcall(Osi.LeaveCombat, stand)
    pcall(Osi.Die, stand, 0, user)
  end

  Osi.RemoveStatus(user, "STAND_USER_ACTIVE")
  Osi.RemoveStatus(user, "STAND_SPIRITUAL_LINK")
  Osi.RemoveStatus(user, "STAND_VISION")
  StandSystem.Active[user] = nil
end

function StandSystem.OnStandDamaged(stand, attacker, damage)
  ensureTables()
  local user = getOwnerFromStand(stand)
  if not user then
    return
  end

  local state = getUserState(user)
  if not state then
    return
  end

  local linked = math.floor(tonumber(damage or 0) * (state.damageLinkRatio or 1.0))
  if linked > 0 then
    pcall(Osi.ApplyDamage, user, linked, state.damageLinkType or "Psychic", attacker)
    pcall(Osi.ApplyStatus, user, "STAND_LINKED_DAMAGE_FEEDBACK", 3.0, 1, stand)
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

  local dist = getDistance(owner, state.stand)
  if dist > (state.tetherRange or 12.0) then
    if state.breakBehavior == "AutoReturn" then
      local ux, uy, uz = Osi.GetPosition(owner)
      if ux then
        Osi.TeleportToPosition(entity, ux + 1.0, uy, uz, "", 0, 1, 0)
        Osi.ApplyStatus(owner, "STAND_TETHER_WARNING", 6.0, 1, entity)
      end
    else
      Osi.ApplyStatus(entity, "STAND_TETHER_LOCKED", 6.0, 1, owner)
    end
  end
end

function StandSystem.TryIntercept(user, incomingAttacker)
  local state = getUserState(user)
  if not state then
    return
  end

  local stand = state.stand
  local dist = getDistance(user, stand)
  if dist <= (state.tetherRange or 12.0) then
    Osi.ApplyStatus(user, "STAND_INTERCEPT_GUARD", 6.0, 1, stand)
    Osi.ApplyStatus(user, "STAND_INTERCEPT_TRIGGERED", 3.0, 1, stand)
  end
end

function StandSystem.Reposition(user)
  local state = getUserState(user)
  if not state or not state.stand then
    return
  end

  local stand = state.stand
  local ux, uy, uz = Osi.GetPosition(user)
  if not ux then
    return
  end

  local sx, sy, sz = Osi.GetPosition(stand)
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
  end

  Osi.TeleportToPosition(stand, tx, ty, tz, "", 0, 1, 0)
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
    Osi.ApplyStatus(defender, "STAND_BULLET_CATCH_TRIGGERED", 3.0, 1, stand)
    Osi.ApplyStatus(defender, "STAND_INTERCEPT_GUARD", 3.0, 1, stand)
  end
end

function StandSystem.MirrorStandStatus(stand, status)
  local user = getOwnerFromStand(stand)
  if not user then
    return
  end

  if MIRRORABLE_STATUSES[status] then
    Osi.ApplyStatus(user, "STAND_STATUS_FEEDBACK", 6.0, 1, stand)
    Osi.ApplyStatus(user, status, 6.0, 1, stand)
  end
end

function StandSystem.OnStandAttackHit(attacker)
  local owner = getOwnerFromStand(attacker)
  if owner then
    Osi.ApplyStatus(owner, "STAND_REACTION_SYNC", 1.0, 1, attacker)
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
    pcall(Osi.ApplyDamage, defender, bonus, "Bludgeoning", attacker)
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
    Osi.ApplyStatus(attacker, "STAND_CLASHING", 1.0, 1, defender)
    Osi.ApplyStatus(defender, "STAND_CLASHING", 1.0, 1, attacker)
  end
end

function StandSystem.TriggerTimeStop(user)
  local state = getUserState(user)
  if not state then
    Osi.ApplyStatus(user, "STAND_TIMESTOP_NO_STAND", 6.0, 1, user)
    return
  end

  Osi.ApplyStatus(user, "STAND_TIMESTOP_CASTER", 12.0, 1, user)
  local stand = state.stand
  Osi.ApplyStatus(stand, "STAND_TIMESTOP_CASTER", 12.0, 1, user)

  -- Placeholder capstone behavior: short burst battlefield freeze around Stand.
  Osi.UseSpell(stand, "Target_Stand_TimeStopPulse", stand, 0, 0, 0)
end

Ext.RegisterNetListener("StandPrototype_Manifest", function(cmd, payload, user)
  if payload and payload ~= "" then
    StandSystem.Manifest(payload)
  end
end)

Ext.RegisterNetListener("StandPrototype_Withdraw", function(cmd, payload, user)
  if payload and payload ~= "" then
    StandSystem.Withdraw(payload)
  end
end)

return StandSystem
