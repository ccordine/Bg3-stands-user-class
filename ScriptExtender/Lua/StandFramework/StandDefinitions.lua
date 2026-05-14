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
      -- Prefer ghostly humanoid templates to keep a stand-like projection body.
      summonTemplates = {
        "Shadow_Wraith_A_066133a8-5dce-4636-8ba1-13efb1140c54",
        "S_WYR_Gortash_Office_BaneGhost_08_027d8705-11bb-4697-8d3f-8918554ff45f"
      },
      summonTemplate = "Shadow_Wraith_A_066133a8-5dce-4636-8ba1-13efb1140c54",
      -- Reliability fallback: if no spectral template resolves in this patch level,
      -- use the user template so manifest never hard-fails.
      allowUserTemplateFallback = true,
      forceUnarmed = true,
      baseStandACBonus = 3,
      midStandACBonus = 1,
      lateStandACBonus = 1,
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
            "Target_Stand_LeapCloser",
            "Target_Stand_StarFinger"
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
          standSpells = { "Target_Stand_TimeStop" },
          passives = { "STAND_USER_THE_STAR_CAPSTONE" }
        }
      }
    }
  }
}

return StandDefinitions
