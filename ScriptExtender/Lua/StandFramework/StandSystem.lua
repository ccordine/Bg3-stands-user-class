if not StandSystem then
  StandSystem = {}
end

StandSystem.Active = {}
StandSystem.StandOwner = {}
StandSystem.UserArcana = {}
StandSystem.UserProgression = {}

local MIRRORABLE_STATUSES = {
  BURNING = true,
  BLEEDING = true,
  POISONED = true,
  PRONE = true,
  DAZED = true,
  PARALYZED = true,
  STUNNED = true
}

local function ensureTables()
  StandSystem.Active = StandSystem.Active or {}
  StandSystem.StandOwner = StandSystem.StandOwner or {}
  StandSystem.UserArcana = StandSystem.UserArcana or {}
  StandSystem.UserProgression = StandSystem.UserProgression or {}
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

  if hasAnyPassive(user, {"Alert", "ALERT"}) then
    Osi.ApplyStatus(stand, "STAND_DERIVED_ALERT_INITIATIVE", -1.0, 1, user)
  end
  if hasAnyPassive(user, {"Mobile", "MOBILE"}) then
    Osi.ApplyStatus(stand, "STAND_DERIVED_MOBILE_SURGE", -1.0, 1, user)
  end
  if state.tavernBrawler then
    Osi.ApplyStatus(stand, "STAND_DERIVED_TAVERN_PRESSURE", -1.0, 1, user)
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

  StandSystem.RefreshUnarmoredDiscipline(user)
end

function StandSystem.Manifest(user)
  ensureTables()
  if not isStandUser(user) then
    return
  end
  StandSystem.ApplyProgression(user)

  if getUserState(user) then
    return
  end

  -- Combat-first framework: manifestation is restricted to active combat.
  if Osi.IsInCombat(user) ~= 1 then
    Osi.ApplyStatus(user, "STAND_MANIFEST_BLOCKED", 6.0, 1, user)
    return
  end

  local def = StandSystem.GetDefinition(user)
  local x, y, z = Osi.GetPosition(user)
  if not x then
    return
  end

  -- BG3 hack: stock humanoid template until dedicated Stand asset is authored.
  local stand = Osi.CreateAt(def.summonTemplate, x + 1.2, y, z, 1, 0, "")
  if not stand then
    return
  end

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
  pcall(Osi.AddPartyFollower, stand, user)
  pcall(Osi.JoinCombat, stand, user)

  Osi.ApplyStatus(user, "STAND_USER_ACTIVE", -1, 1, stand)
  Osi.ApplyStatus(stand, "STAND_ENTITY_ACTIVE", -1, 1, user)
  Osi.ApplyStatus(user, "STAND_SPIRITUAL_LINK", -1, 1, stand)
  Osi.ApplyStatus(user, "STAND_VISION", -1, 1, stand)

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
