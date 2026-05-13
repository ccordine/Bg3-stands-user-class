Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function(caster, spell, target, target2, target3)
  if spell == "Target_Stand_Manifest" then
    StandSystem.Manifest(caster)
  elseif spell == "Target_Stand_Withdraw" then
    StandSystem.Withdraw(caster)
  elseif spell == "Target_Stand_Intercept" then
    Osi.ApplyStatus(caster, "STAND_INTERCEPT_READY", 6.0, 1, caster)
  elseif spell == "Target_Stand_CombatPrediction" then
    Osi.ApplyStatus(caster, "STAND_PREDICTION_EDGE", 12.0, 1, caster)
  elseif spell == "Target_Stand_TimeStop" then
    StandSystem.TriggerTimeStop(caster)
  end
end)

Ext.Osiris.RegisterListener("TurnStarted", 1, "after", function(entity)
  StandSystem.OnTurnStarted(entity)
end)

Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", function(entity, change)
  if change < 0 then
    StandSystem.OnStandDamaged(entity, entity, math.abs(change))
  end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, causee, storyActionId)
  StandSystem.MirrorStandStatus(target, status)
end)

Ext.Osiris.RegisterListener("AttackedBy", 4, "after", function(defender, attacker, event, isMain)
  StandSystem.TryStandClash(attacker, defender)
  StandSystem.TryBulletCatch(defender, attacker)
  StandSystem.OnStandHitTarget(attacker, defender)

  if Osi.HasActiveStatus(defender, "STAND_INTERCEPT_READY") == 1 then
    Osi.RemoveStatus(defender, "STAND_INTERCEPT_READY")
    StandSystem.TryIntercept(defender, attacker)
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
