controller = Controller:new()
controller:registerEvents(g_game, {
    onClientVersionChange = function(version)
        -- g_game.enableFeature(GameKeepUnawareTiles)
        -- g_game.enableFeature(GameNegativeOffset)
        -- g_game.enableFeature(GameWingsAurasEffectsShader)
        -- g_game.enableFeature(GameCreaturePaperdoll)
        -- g_game.enableFeature(GameAllowCustomBotScripts)

        g_game.enableFeature(GameFormatCreatureName)

        -- For Walk
        g_game.enableFeature(GameAllowPreWalk)
        g_game.enableFeature(GameMapCache)
        -- g_game.enableFeature(GameSmoothWalkElevation)

        if version >= 750 then
            g_game.enableFeature(GameSoul)
        end

        if version >= 760 then
            g_game.enableFeature(GameLevelU16)
        end

        if version >= 770 then
            g_game.enableFeature(GameLooktypeU16)
            g_game.enableFeature(GameMessageStatements)
            g_game.enableFeature(GameLoginPacketEncryption)
        end

        if version >= 780 then
            g_game.enableFeature(GamePlayerAddons)
            g_game.enableFeature(GamePlayerStamina)
            g_game.enableFeature(GameNewFluids)
            g_game.enableFeature(GameMessageLevel)
            g_game.enableFeature(GamePlayerStateU16)
            g_game.enableFeature(GameNewOutfitProtocol)
        end

        if version >= 790 then
            g_game.enableFeature(GameWritableDate)
        end

        if version >= 840 then
            g_game.enableFeature(GameProtocolChecksum)
            g_game.enableFeature(GameAccountNames)
            g_game.enableFeature(GameDoubleFreeCapacity)
        end

        if version >= 841 then
            g_game.enableFeature(GameChallengeOnLogin)
            g_game.enableFeature(GameMessageSizeCheck)
            g_game.enableFeature(GameTileAddThingWithStackpos)
        end

        if version >= 854 then
            g_game.enableFeature(GameCreatureEmblems)
        end

        if version >= 860 then
            g_game.enableFeature(GameAttackSeq)
        end

        if version >= 862 then
            g_game.enableFeature(GamePenalityOnDeath)
        end

        if version >= 870 then
            g_game.enableFeature(GameDoubleExperience)
            g_game.enableFeature(GamePlayerMounts)
            g_game.enableFeature(GameSpellList)
        end

        if version >= 910 then
            g_game.enableFeature(GameNameOnNpcTrade)
            g_game.enableFeature(GameTotalCapacity)
            g_game.enableFeature(GameSkillsBase)
            g_game.enableFeature(GamePlayerRegenerationTime)
            g_game.enableFeature(GameChannelPlayerList)
            g_game.enableFeature(GameEnvironmentEffect)
            g_game.enableFeature(GameItemAnimationPhase)
        end

        if version >= 940 then
            g_game.enableFeature(GamePlayerMarket)
        end

        if version >= 953 then
            g_game.enableFeature(GamePurseSlot)
            g_game.enableFeature(GameClientPing)
        end

        if version >= 960 then
            g_game.enableFeature(GameSpritesU32)
            g_game.enableFeature(GameOfflineTrainingTime)
        end

        if version >= 963 then
            g_game.enableFeature(GameAdditionalVipInfo)
        end

        if version >= 972 then
            g_game.enableFeature(GameDoublePlayerGoodsMoney)
        end

        if version >= 980 then
            g_game.enableFeature(GamePreviewState)
            g_game.enableFeature(GameClientVersion)
        end

        if version >= 981 then
            g_game.enableFeature(GameLoginPending)
            g_game.enableFeature(GameNewSpeedLaw)
        end

        if version >= 984 then
            g_game.enableFeature(GameContainerPagination)
            g_game.enableFeature(GameBrowseField)
        end

        if version >= 1000 then
            g_game.enableFeature(GameThingMarks)
            g_game.enableFeature(GamePVPMode)
        end

        if version >= 1035 then
            g_game.enableFeature(GameDoubleSkills)
            g_game.enableFeature(GameBaseSkillU16)
        end

        if version >= 1036 then
            g_game.enableFeature(GameCreatureIcons)
            g_game.enableFeature(GameHideNpcNames)
        end

        if version >= 1038 then
            g_game.enableFeature(GamePremiumExpiration)
        end

        if version >= 1050 then
            g_game.enableFeature(GameEnhancedAnimations)
        end

        if version >= 1053 then
            g_game.enableFeature(GameUnjustifiedPoints)
        end

        if version >= 1054 then
            g_game.enableFeature(GameExperienceBonus)
        end

        if version >= 1055 then
            g_game.enableFeature(GameDeathType)
        end

        if version >= 1057 then
            g_game.enableFeature(GameIdleAnimations)
        end

        if version >= 1061 then
            g_game.enableFeature(GameOGLInformation)
        end

        if version >= 1071 then
            g_game.enableFeature(GameContentRevision)
        end

        if version >= 1072 then
            g_game.enableFeature(GameAuthenticator)
        end

        if version >= 1074 then
            g_game.enableFeature(GameSessionKey)
        end

        if version >= 1080 then
            g_game.enableFeature(GameIngameStore)
        end

        if version >= 1092 then
            g_game.enableFeature(GameIngameStoreServiceType)
        end

        if version >= 1093 then
            g_game.enableFeature(GameIngameStoreHighlights)
        end

        if version >= 1094 then
            g_game.enableFeature(GameAdditionalSkills)
            g_game.enableFeature(GameLeechAmount)
        end

        if version >= 1100 then
            g_game.enableFeature(GamePrey)
        end

        if version >= 1200 then
            g_game.enableFeature(GameColorizedLootValue)
            g_game.enableFeature(GameThingQuickLoot)
            g_game.enableFeature(GameTournamentPackets)
            g_game.enableFeature(GameVipGroups)
            g_game.enableFeature(GameEnterGameShowAppearance)
        end

        if version >= 1260 then
            g_game.enableFeature(GameThingQuiver)
        end

        if version >= 1264 then
            g_game.enableFeature(GameThingPodium)
        end

        if version >= 1272 then
            g_game.enableFeature(GameThingUpgradeClassification)
        end

        if version >= 1281 then
            g_game.enableFeature(GameForgeSkillStats)
            g_game.enableFeature(GamePlayerFamiliars)
            g_game.disableFeature(GameEnvironmentEffect)
            g_game.disableFeature(GameItemAnimationPhase)
        end

        if version >= 1290 then
            g_game.enableFeature(GameSequencedPackets)
            g_game.enableFeature(GameBosstiary)
            g_game.enableFeature(GameThingClock)
            g_game.enableFeature(GameThingCounter)
            g_game.enableFeature(GameThingPodiumItemType)
            g_game.enableFeature(GameDoubleShopSellAmount)
        end

        if version >= 1300 then
            g_game.enableFeature(GameDoubleHealth)
            g_game.enableFeature(GameUshortSpell)
            g_game.enableFeature(GameConcotions)
            g_game.enableFeature(GameAnthem)
        end

        if version >= 1314 then
            g_game.disableFeature(GameTournamentPackets)
            g_game.enableFeature(GameDynamicForgeVariables)
        end

        if version >= 1320 then
            g_game.enableFeature(GameEffectU16)
            g_game.enableFeature(GameContainerTypes)
            g_game.enableFeature(GameBosstiaryTracker)
            g_game.enableFeature(GamePlayerStateCounter)
            g_game.disableFeature(GameLeechAmount)
            g_game.enableFeature(GameItemAugment)
            g_game.enableFeature(GameDynamicBugReporter)
        end

        if version >= 1321 then
            g_game.enableFeature(GameWrapKit)
            g_game.enableFeature(GameContainerFilter)
        end

        if version >= 1332 then
            g_game.enableFeature(GameForgeConvergence)
        end

        if version >= 1410 then
            g_game.disableFeature(GameAdditionalSkills)
            g_game.disableFeature(GameForgeSkillStats)
            g_game.enableFeature(GameCharacterSkillStats)
        end

        if version >= 1500 then
            g_game.enableFeature(GameVocationMonk)
        end
    end
})
