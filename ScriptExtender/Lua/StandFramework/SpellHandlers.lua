local NULL_GUID = "NULL_00000000-0000-0000-0000-000000000000"

local function trace(msg)
  if Ext and Ext.Utils and Ext.Utils.PrintWarning then
    Ext.Utils.PrintWarning("[StandPrototype] " .. tostring(msg))
  end
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
  local ok, err
  local owner = StandSystem.GetOwnerForEntity(caster)
  local controlTarget = owner or caster
  if spell == "Target_Stand_Manifest" then
    ok, err = pcall(StandSystem.Manifest, caster)
  elseif spell == "Target_Stand_Withdraw" then
    ok, err = pcall(StandSystem.Withdraw, caster)
  elseif spell == "Target_Stand_Reposition" then
    ok, err = pcall(StandSystem.Reposition, controlTarget)
  elseif spell == "Target_Stand_Intercept" then
    ok, err = pcall(Osi.ApplyStatus, controlTarget, "STAND_INTERCEPT_READY", 6.0, 1, caster)
  elseif spell == "Target_Stand_CombatPrediction" then
    ok, err = pcall(Osi.ApplyStatus, controlTarget, "STAND_PREDICTION_EDGE", 12.0, 1, caster)
  elseif spell == "Target_Stand_TimeStop" then
    ok, err = pcall(StandSystem.TriggerTimeStop, controlTarget)
  else
    return
  end

  if not ok then
    trace("Spell handler error spell=[" .. tostring(spell) .. "] caster=[" .. tostring(caster) .. "] err=[" .. tostring(err) .. "]")
    if spell == "Target_Stand_Manifest" then
      pcall(Osi.ApplyStatus, caster, "STAND_MANIFEST_BLOCKED", 6.0, 1, caster)
    end
  end
end

Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionId)
  handleStandSpell(caster, spell)
end)

Ext.Osiris.RegisterListener("CastSpellFailed", 5, "after", function(caster, spell, spellType, spellElement, storyActionId)
  -- Some custom shout actions fail engine prechecks in edge cases;
  -- keep core Stand loop responsive by handling manifest/withdraw fallbacks.
  if spell == "Target_Stand_Manifest" or spell == "Target_Stand_Withdraw" then
    handleStandSpell(caster, spell)
  end
end)

Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(entity)
  StandSystem.OnTurnStarted(entity)
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, causee, storyActionId)
  StandSystem.MirrorStandStatus(target, status)
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "after", function(defender, attackerOwner, attacker, damageType, damageAmount, damageCause, storyActionId)
  local source = resolveSource(attackerOwner, attacker) or attacker
  local damage = tonumber(damageAmount) or 0

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
  StandSystem.ApplyProgression(character)
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
  StandSystem.CleanupStaleState(character, "join_party")
  StandSystem.ApplyProgression(character)
end)

Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
  if Osi.HasPassive(character, "STAND_USER_BASE_CLASS_PASSIVE") == 1 then
    StandSystem.Withdraw(character)
    StandSystem.CleanupStaleState(character, "death")
  end
end)
