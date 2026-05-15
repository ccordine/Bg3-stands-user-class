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
  return type(spell) == "string" and spell:find("^Target_Stand_") ~= nil
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
  if spell == "Target_Stand_Manifest" then
    ok, err = pcall(StandSystem.Manifest, caster)
  elseif spell == "Target_Stand_Withdraw" then
    ok, err = pcall(StandSystem.Withdraw, caster)
  elseif spell == "Target_Stand_Reposition" then
    ok, err = pcall(StandSystem.Reposition, controlTarget)
  elseif spell == "Target_Stand_Intercept" then
    ok = statusSafe(controlTarget, "STAND_INTERCEPT_READY", 6.0, 1, caster, "spell_intercept")
  elseif spell == "Target_Stand_CombatPrediction" then
    ok = statusSafe(controlTarget, "STAND_PREDICTION_EDGE", 12.0, 1, caster, "spell_combat_prediction")
  elseif spell == "Target_Stand_TimeStop" then
    ok, err = pcall(StandSystem.TriggerTimeStop, controlTarget)
  else
    logWarn("handleStandSpell has no route for Stand spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "]")
    return
  end

  if not ok then
    logError("Spell handler error spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "] owner=[" .. tostring(owner) .. "] controlTarget=[" .. tostring(controlTarget) .. "] err=[" .. tostring(err) .. "]")
    if spell == "Target_Stand_Manifest" then
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

Ext.Osiris.RegisterListener("CastSpellFailed", 5, "after", function(caster, spell, spellType, spellElement, storyActionId)
  if isStandSpell(spell) then
    logError("CastSpellFailed event caster=[" .. tostring(caster) .. "] spell=[" .. tostring(spell) .. "] spellType=[" .. tostring(spellType) .. "] element=[" .. tostring(spellElement) .. "] storyActionId=[" .. tostring(storyActionId) .. "]")
  end
  -- Some custom shout actions fail engine prechecks in edge cases;
  -- keep core Stand loop responsive by routing manifest/withdraw through Lua.
  if spell == "Target_Stand_Manifest" or spell == "Target_Stand_Withdraw" then
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
  if Osi.HasPassive(character, "STAND_USER_BASE_CLASS_PASSIVE") == 1 then
    StandSystem.Withdraw(character)
    StandSystem.CleanupStaleState(character, "death")
  end
end)
