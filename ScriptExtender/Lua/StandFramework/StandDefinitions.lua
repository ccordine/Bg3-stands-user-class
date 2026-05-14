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
      standName = "Star Platinum",
      archetype = "CloseRangePowerStand",
      entityTemplate = "STANDPROTOTYPE_STAR_PLATINUM_6f8d9ac1-1d13-4cb4-aa64-85c2e2bc07c1",
      -- Dedicated Star Platinum template first; stock strong-human fallback keeps
      -- manifest reliable without reintroducing Specter/Wraith combat kits.
      summonTemplates = {
        "STANDPROTOTYPE_STAR_PLATINUM_6f8d9ac1-1d13-4cb4-aa64-85c2e2bc07c1",
        "BASE_Humans_Male_Strong_12c0a711-1459-48e2-a50e-7b792eee0918"
      },
      summonTemplate = "STANDPROTOTYPE_STAR_PLATINUM_6f8d9ac1-1d13-4cb4-aa64-85c2e2bc07c1",
      allowUserTemplateFallback = false,
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
