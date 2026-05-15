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
      characterStat = "STAND_BASE_BODY",
      entityTemplate = "STANDPROTOTYPE_BASE_STAND_72b4f830-2f41-4f50-8f80-0f7cc1383d01",
      summonTemplate = "STANDPROTOTYPE_BASE_STAND_72b4f830-2f41-4f50-8f80-0f7cc1383d01",
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
          "Shout_Stand_Manifest",
          "Shout_Stand_Withdraw"
        },
        [2] = {
          "Shout_Stand_Reposition"
        }
      },
      standActions = {
        [1] = {
          "Target_Stand_BasicStrike",
          "Target_Stand_BasicBarrage",
          "Shout_Stand_BasicGuard"
        }
      },
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
      }
    },
    TheStar = {
      id = "the_star",
      displayName = "The Star",
      standName = "Star Platinum",
      standDisplayNameHandle = "h00010001g0000g0000g0000g00000000009A",
      archetype = "CloseRangePowerStand",
      characterStat = "STAND_STAR_PLATINUM_BODY_L3",
      entityTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0",
      summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0",
      tiers = {
        [3] = {
          characterStat = "STAND_STAR_PLATINUM_BODY_L3",
          summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L3_f50e6a61-772e-45c9-bfd6-45e68d33a4c0",
          actions = {
            "Target_Stand_Barrage",
            "Shout_Stand_Intercept"
          }
        },
        [5] = {
          characterStat = "STAND_STAR_PLATINUM_BODY_L5",
          summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L5_7e39fd60-9bce-44b4-9bcd-e600494dbcd8",
          actions = {
            "Target_Stand_Barrage",
            "Shout_Stand_Intercept",
            "Target_Stand_StarFinger"
          }
        },
        [6] = {
          characterStat = "STAND_STAR_PLATINUM_BODY_L6",
          summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L6_fb4208dd-761b-448c-99d8-ef8fbabc5077",
          actions = {
            "Target_Stand_Barrage",
            "Shout_Stand_Intercept",
            "Target_Stand_StarFinger",
            "Target_Stand_Rush"
          }
        },
        [10] = {
          characterStat = "STAND_STAR_PLATINUM_BODY_L10",
          summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L10_f3934f6f-2bc6-4693-8055-2ee6d8c5816c",
          actions = {
            "Target_Stand_Barrage",
            "Shout_Stand_Intercept",
            "Target_Stand_StarFinger",
            "Target_Stand_Rush",
            "Target_Stand_RelentlessBarrage"
          }
        },
        [12] = {
          characterStat = "STAND_STAR_PLATINUM_BODY_L12",
          summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_L12_4986fbe6-dc51-44cd-a617-bd54c29c5bf9",
          actions = {
            "Target_Stand_Barrage",
            "Shout_Stand_Intercept",
            "Target_Stand_StarFinger",
            "Target_Stand_Rush",
            "Target_Stand_RelentlessBarrage",
            "Shout_Stand_TimeStop"
          }
        }
      },
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
          "Shout_Stand_Manifest",
          "Shout_Stand_Withdraw",
          "Shout_Stand_Reposition",
          "Shout_Stand_CombatPrediction"
        }
      },
      standActions = {
        [3] = {
          "Target_Stand_Barrage",
          "Shout_Stand_Intercept"
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
          "Shout_Stand_TimeStop"
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
      }
    }
  }
}

return StandDefinitions
