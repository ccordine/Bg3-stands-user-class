StandDefinitions = {
  Core = {
    classId = "StandUser",
    baseFeatures = {
      "ManifestStand",
      "WithdrawStand",
      "SharedDamage",
      "StandVision",
      "TetherMechanics",
      "SpiritualResistance",
      "ReactionCoordination"
    },
    defaultArcana = "TheStar"
  },
  Arcana = {
    TheStar = {
      id = "the_star",
      displayName = "The Star",
      archetype = "CloseRangePowerStand",
      summonTemplate = "S_GOB_Barbarian_A_4f5403e2-6f2f-4c74-9f4a-8a4ef2db5c1a",
      rangeProfile = {
        tetherRange = 12.0,
        breakBehavior = "AutoReturn"
      },
      damageLinkProfile = {
        hpRatio = 1.0,
        damageType = "Psychic"
      },
      initiativeMode = "JoinCombat",
      controllable = true,
      progression = {
        [3] = {
          userSpells = { "Target_Stand_Manifest", "Target_Stand_Withdraw" },
          standSpells = {
            "Target_Stand_Barrage",
            "Target_Stand_HeavyPunch",
            "Target_Stand_Intercept"
          },
          passives = { "STAND_USER_THE_STAR_TIER_EARLY" }
        },
        [6] = {
          standSpells = {
            "Target_Stand_LeapCloser"
          },
          passives = { "STAND_USER_THE_STAR_TIER_MID" }
        },
        [10] = {
          standSpells = {
            "Target_Stand_RushUltimate"
          },
          passives = { "STAND_USER_THE_STAR_TIER_LATE" }
        },
        [12] = {
          userSpells = { "Target_Stand_TimeStop" },
          passives = { "STAND_USER_THE_STAR_CAPSTONE" }
        }
      }
    }
  }
}

return StandDefinitions
