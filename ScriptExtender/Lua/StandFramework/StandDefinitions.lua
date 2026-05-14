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
    defaultArcana = "BaseStand"
  },
  Arcana = {
    BaseStand = {
      id = "base_stand",
      displayName = "Stand",
      standName = "Stand",
      standDisplayNameHandle = "h00010001g0000g0000g0000g00000000009B",
      archetype = "UnawakenedStand",
      entityTemplate = "72b4f830-2f41-4f50-8f80-0f7cc1383d01",
      summonTemplate = "72b4f830-2f41-4f50-8f80-0f7cc1383d01",
      fallbackSummonTemplate = "BASE_Humans_Male_Strong_12c0a711-1459-48e2-a50e-7b792eee0918",
      forceUnarmed = true,
      rangeProfile = {
        tetherRange = 9.0,
        breakBehavior = "AutoReturn"
      },
      damageLinkProfile = {
        hpRatio = 1.0,
        damageType = "Psychic"
      },
      initiativeMode = "JoinCombat",
      controllable = true,
      userActions = {
        [1] = {
          "Target_Stand_Manifest",
          "Target_Stand_Withdraw"
        },
        [2] = {
          "Target_Stand_Reposition"
        }
      },
      standActions = {},
      passives = {},
      rules = {
        forceUnarmed = true,
        linkedDamage = true,
        tetherRange = 9.0,
        canUseWeapons = false,
        allowTetherScaling = false
      },
      visualStatuses = {
        "GHOST_FX",
        "WRAITH_GLOWING_EYES_TECHNICAL"
      },
      inheritedSpellBlocklist = {
        "Target_LifeDrain_Wraith",
        "Target_CreateShadow_Wraith",
        "Target_EtherealJaunt",
        "Target_EtherealJaunt_Queen",
        "Target_EtherealJaunt_Spiderling"
      }
    },
    TheStar = {
      id = "the_star",
      displayName = "The Star",
      standName = "Star Platinum",
      standDisplayNameHandle = "h00010001g0000g0000g0000g00000000009A",
      archetype = "CloseRangePowerStand",
      entityTemplate = "6f8d9ac1-1d13-4cb4-aa64-85c2e2bc07c1",
      summonTemplate = "6f8d9ac1-1d13-4cb4-aa64-85c2e2bc07c1",
      fallbackSummonTemplate = "BASE_Humans_Male_Strong_12c0a711-1459-48e2-a50e-7b792eee0918",
      forceUnarmed = true,
      baseStandACBonus = 3,
      midStandACBonus = 1,
      lateStandACBonus = 1,
      rangeProfile = {
        -- BG3 uses metric internally; 9m is the tabletop 30ft close-range radius.
        tetherRange = 9.0,
        breakBehavior = "AutoReturn"
      },
      damageLinkProfile = {
        hpRatio = 1.0,
        damageType = "Psychic"
      },
      initiativeMode = "JoinCombat",
      controllable = true,
      userActions = {
        [3] = {
          "Target_Stand_Manifest",
          "Target_Stand_Withdraw",
          "Target_Stand_Reposition",
          "Target_Stand_CombatPrediction"
        }
      },
      standActions = {
        [3] = {
          "Target_Stand_Barrage",
          "Target_Stand_Intercept"
        },
        [5] = {
          "Target_Stand_StarFinger"
        },
        [6] = {
          "Target_Stand_Rush"
        },
        [10] = {
          "Target_Stand_RelentlessBarrage"
        },
        [12] = {
          "Target_Stand_TimeStop"
        }
      },
      passives = {
        [3] = {
          "STAND_USER_THE_STAR_TIER_EARLY"
        },
        [6] = {
          "STAND_USER_THE_STAR_TIER_MID"
        },
        [10] = {
          "STAND_USER_THE_STAR_TIER_LATE"
        },
        [12] = {
          "STAND_USER_THE_STAR_CAPSTONE"
        }
      },
      rules = {
        forceUnarmed = true,
        linkedDamage = true,
        tetherRange = 9.0,
        canUseWeapons = false,
        allowTetherScaling = false
      },
      visualStatuses = {
        "GHOST_FX",
        "WRAITH_GLOWING_EYES_TECHNICAL"
      },
      standEquipmentTemplates = {
        -- Barbarian starter clothing gives Star Platinum a close stock "warrior" silhouette.
        "f6599c3f-cfcd-4721-9cc2-1df5d8ff0154"
      },
      inheritedSpellBlocklist = {
        "Target_LifeDrain_Wraith",
        "Target_CreateShadow_Wraith",
        "Target_EtherealJaunt",
        "Target_EtherealJaunt_Queen",
        "Target_EtherealJaunt_Spiderling"
      }
    }
  }
}

return StandDefinitions
