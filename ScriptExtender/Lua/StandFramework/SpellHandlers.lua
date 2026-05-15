local NULL_GUID = "NULL_00000000-0000-0000-0000-000000000000"

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

local function statusSafe(target, status, duration, force, source, reason)
  local ok, err = pcall(Osi.ApplyStatus, target, status, duration, force, source)
  if ok then
    logInfo("Osi.ApplyStatus reason=[" .. tostring(reason) .. "] target=[" .. tostring(target) .. "] status=[" .. tostring(status) .. "] source=[" .. tostring(source) .. "] => ok")
  else
    logError("Osi.ApplyStatus reason=[" .. tostring(reason) .. "] target=[" .. tostring(target) .. "] status=[" .. tostring(status) .. "] source=[" .. tostring(source) .. "] => error [" .. tostring(err) .. "]")
  end
  return ok
end

local function isStandSpell(spell)
  return type(spell) == "string"
    and (
      spell:find("^Target_Stand_") ~= nil
      or spell:find("^Shout_Stand_") ~= nil
      or spell:find("^Zone_Stand_") ~= nil
      or spell:find("^Projectile_Stand_") ~= nil
    )
end

local function isStandUser(entity)
  local ok, result = pcall(Osi.HasPassive, entity, "STAND_USER_BASE_CLASS_PASSIVE")
  return ok and result == 1
end

local function isStandRelevant(entity)
  if not entity or entity == "" or entity == NULL_GUID then
    return false
  end
  if isStandUser(entity) then
    return true
  end
  return StandSystem.GetOwnerForEntity(entity) ~= nil
end

local function resolveSource(primary, fallback)
  if primary and primary ~= "" and primary ~= NULL_GUID then
    return primary
  end
  if fallback and fallback ~= "" and fallback ~= NULL_GUID then
    return fallback
  end
  return nil
end

local function getPositionSummary(entity)
  if not entity or entity == "" or entity == NULL_GUID then
    return "nil"
  end

  local ok, x, y, z = pcall(Osi.GetPosition, entity)
  if ok and x then
    return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
  end

  return "error:" .. tostring(x)
end

local function getDistanceSummary(a, b)
  if not a or not b or a == "" or b == "" or a == NULL_GUID or b == NULL_GUID then
    return "nil"
  end

  local okA, ax, ay, az = pcall(Osi.GetPosition, a)
  local okB, bx, by, bz = pcall(Osi.GetPosition, b)
  if not okA or not okB or not ax or not bx then
    return "error"
  end

  local dx = ax - bx
  local dy = ay - by
  local dz = az - bz
  return tostring(math.sqrt((dx * dx) + (dy * dy) + (dz * dz)))
end

local function logStandTargetingEvent(label, caster, target, spell, spellType, spellElement, storyActionId)
  if not isStandSpell(spell) then
    return
  end

  local owner = StandSystem.GetOwnerForEntity(caster)
  local active = owner and StandSystem.Active and StandSystem.Active[owner] or nil
  local activeStand = active and active.stand or nil
  logWarn(
    tostring(label)
      .. " caster=[" .. tostring(caster) .. "]"
      .. " target=[" .. tostring(target) .. "]"
      .. " spell=[" .. tostring(spell) .. "]"
      .. " spellType=[" .. tostring(spellType) .. "]"
      .. " element=[" .. tostring(spellElement) .. "]"
      .. " storyActionId=[" .. tostring(storyActionId) .. "]"
      .. " owner=[" .. tostring(owner) .. "]"
      .. " activeStand=[" .. tostring(activeStand) .. "]"
      .. " casterIsActiveStand=[" .. tostring(activeStand ~= nil and caster == activeStand) .. "]"
      .. " casterPos=[" .. tostring(getPositionSummary(caster)) .. "]"
      .. " targetPos=[" .. tostring(getPositionSummary(target)) .. "]"
      .. " casterTargetDistance=[" .. tostring(getDistanceSummary(caster, target)) .. "]"
      .. " ownerTargetDistance=[" .. tostring(getDistanceSummary(owner, target)) .. "]"
  )
end

local function handleStandSpell(caster, spell)
  if not isStandSpell(spell) then
    return
  end

  local ok, err
  local owner = StandSystem.GetOwnerForEntity(caster)
  local controlTarget = owner or caster
  logInfo(
    "handleStandSpell start"
      .. " caster=[" .. tostring(caster) .. "]"
      .. " spell=[" .. tostring(spell) .. "]"
      .. " owner=[" .. tostring(owner) .. "]"
      .. " controlTarget=[" .. tostring(controlTarget) .. "]"
  )
  if spell == "Shout_Stand_Manifest" then
    ok, err = pcall(StandSystem.Manifest, caster)
  elseif spell == "Shout_Stand_Withdraw" then
    logWarn(
      "WITHDRAW_TRACE spell handler routing Withdraw"
        .. " caster=[" .. tostring(caster) .. "]"
        .. " owner=[" .. tostring(owner) .. "]"
        .. " controlTarget=[" .. tostring(controlTarget) .. "]"
        .. " casterIsStand=[" .. tostring(owner ~= nil) .. "]"
    )
    ok, err = pcall(StandSystem.Withdraw, caster)
  elseif spell == "Shout_Stand_Reposition" then
    ok, err = pcall(StandSystem.Reposition, controlTarget)
  elseif spell == "Shout_Stand_Intercept" then
    ok = statusSafe(controlTarget, "STAND_INTERCEPT_READY", 6.0, 1, caster, "spell_intercept")
  elseif spell == "Shout_Stand_BasicGuard" then
    ok = statusSafe(controlTarget, "STAND_INTERCEPT_READY", 6.0, 1, caster, "spell_basic_guard")
  elseif spell == "Shout_Stand_CombatPrediction" then
    ok = statusSafe(controlTarget, "STAND_PREDICTION_EDGE", 12.0, 1, caster, "spell_combat_prediction")
  elseif spell == "Shout_Stand_TimeStop" then
    ok, err = pcall(StandSystem.TriggerTimeStop, controlTarget)
  elseif spell == "Target_Stand_BasicStrike"
    or spell == "Target_Stand_BasicBarrage"
    or spell == "Target_Stand_Barrage"
    or spell == "Target_Stand_Rush"
    or spell == "Target_Stand_StarFinger"
    or spell == "Target_Stand_RelentlessBarrage" then
    logInfo("handleStandSpell direct SpellData technique has no Lua route spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "]")
    return
  else
    logWarn("handleStandSpell has no route for Stand spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "]")
    return
  end

  if not ok then
    logError("Spell handler error spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "] owner=[" .. tostring(owner) .. "] controlTarget=[" .. tostring(controlTarget) .. "] err=[" .. tostring(err) .. "]")
    if spell == "Shout_Stand_Manifest" then
      statusSafe(caster, "STAND_MANIFEST_BLOCKED", 6.0, 1, caster, "spell_handler_manifest_error")
    end
  else
    logInfo("handleStandSpell complete spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "]")
  end
end

Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionId)
  if isStandSpell(spell) then
    logInfo("UsingSpell event caster=[" .. tostring(caster) .. "] spell=[" .. tostring(spell) .. "] spellType=[" .. tostring(spellType) .. "] element=[" .. tostring(spellElement) .. "] storyActionId=[" .. tostring(storyActionId) .. "]")
  end
  handleStandSpell(caster, spell)
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function(caster, target, spell, spellType, spellElement, storyActionId)
  logStandTargetingEvent("UsingSpellOnTarget event", caster, target, spell, spellType, spellElement, storyActionId)
end)

Ext.Osiris.RegisterListener("CastSpellFailed", 5, "after", function(caster, spell, spellType, spellElement, storyActionId)
  if isStandSpell(spell) then
    logError("CastSpellFailed event caster=[" .. tostring(caster) .. "] spell=[" .. tostring(spell) .. "] spellType=[" .. tostring(spellType) .. "] element=[" .. tostring(spellElement) .. "] storyActionId=[" .. tostring(storyActionId) .. "]")
  end
  -- Some custom shout actions fail engine prechecks in edge cases;
  -- keep core Stand loop responsive by routing manifest/withdraw through Lua.
  if spell == "Shout_Stand_Manifest" or spell == "Shout_Stand_Withdraw" then
    handleStandSpell(caster, spell)
  end
end)

Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(entity)
  if isStandRelevant(entity) then
    logInfo("TurnStarted event entity=[" .. tostring(entity) .. "]")
  end
  StandSystem.OnTurnStarted(entity)
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, causee, storyActionId)
  if status and tostring(status):find("STAND") then
    logInfo("StatusApplied event target=[" .. tostring(target) .. "] status=[" .. tostring(status) .. "] causee=[" .. tostring(causee) .. "] storyActionId=[" .. tostring(storyActionId) .. "]")
  end
  StandSystem.MirrorStandStatus(target, status)
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "after", function(defender, attackerOwner, attacker, damageType, damageAmount, damageCause, storyActionId)
  local source = resolveSource(attackerOwner, attacker) or attacker
  local damage = tonumber(damageAmount) or 0
  if isStandRelevant(defender) or isStandRelevant(attacker) or isStandRelevant(attackerOwner) then
    logInfo(
      "AttackedBy event"
        .. " defender=[" .. tostring(defender) .. "]"
        .. " attackerOwner=[" .. tostring(attackerOwner) .. "]"
        .. " attacker=[" .. tostring(attacker) .. "]"
        .. " source=[" .. tostring(source) .. "]"
        .. " damageType=[" .. tostring(damageType) .. "]"
        .. " damageAmount=[" .. tostring(damageAmount) .. "]"
        .. " damageCause=[" .. tostring(damageCause) .. "]"
        .. " storyActionId=[" .. tostring(storyActionId) .. "]"
    )
  end

  if damage > 0 then
    StandSystem.OnStandDamaged(defender, source, damage)
    StandSystem.OnUserDamaged(defender, source, damage)
  end

  StandSystem.TryStandClash(attacker, defender)
  StandSystem.TryBulletCatch(defender, source)
  StandSystem.OnStandHitTarget(attacker, defender)

  if Osi.HasActiveStatus(defender, "STAND_INTERCEPT_READY") == 1 then
    Osi.RemoveStatus(defender, "STAND_INTERCEPT_READY")
    StandSystem.TryIntercept(defender, source)
  end

  StandSystem.OnStandAttackHit(attacker)
end)

Ext.Osiris.RegisterListener("LeveledUp", 1, "after", function(character)
  if isStandRelevant(character) then
    logInfo("LeveledUp event character=[" .. tostring(character) .. "]")
  end
  StandSystem.ApplyProgression(character)
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
  if isStandRelevant(character) then
    logInfo("CharacterJoinedParty event character=[" .. tostring(character) .. "]")
  end
  StandSystem.CleanupStaleState(character, "join_party")
  StandSystem.ApplyProgression(character)
end)

Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
  if isStandRelevant(character) then
    logInfo("Died event character=[" .. tostring(character) .. "]")
  end
  StandSystem.OnEntityDied(character)
  if Osi.HasPassive(character, "STAND_USER_BASE_CLASS_PASSIVE") == 1 then
    StandSystem.Withdraw(character)
    StandSystem.CleanupStaleState(character, "death")
  end
end)
