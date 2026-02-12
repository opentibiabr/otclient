/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma once

namespace Otc
{
    enum OperatingSystem_t : uint16_t
    {
        CLIENTOS_NONE = 0,
        CLIENTOS_OTCLIENT_LINUX = 10,
        CLIENTOS_OTCLIENT_WINDOWS = 11,
        CLIENTOS_OTCLIENT_MAC = 12,
    };

    enum Operation : uint8_t
    {
        OPERATION_ADD, OPERATION_REMOVE, OPERATION_CLEAN
    };

    enum DrawFlags : uint32_t
    {
        DrawThings = 1 << 0,
        DrawLights = 1 << 1,
        DrawBars = 1 << 2,
        DrawNames = 1 << 3,
        DrawManaBar = 1 << 4,
        DrawHarmony = 1 << 5,
        DrawThingsAndLights = DrawThings | DrawLights,
        DrawCreatureInfo = DrawBars | DrawNames | DrawManaBar | DrawHarmony,
    };

    enum DatOpts : uint8_t
    {
        DatGround = 0,
        DatGroundClip,
        DatOnBottom,
        DatOnTop,
        DatContainer,
        DatStackable,
        DatForceUse,
        DatMultiUse,
        DatWritable,
        DatWritableOnce,
        DatFluidContainer,
        DatSplash,
        DatBlockWalk,
        DatNotMoveable,
        DatBlockProjectile,
        DatBlockPathFind,
        DatPickupable,
        DatHangable,
        DatHookSouth,
        DatHookEast,
        DatRotable,
        DatLight,
        DatDontHide,
        DatTranslucent,
        DatDisplacement,
        DatElevation,
        DatLyingCorpse,
        DatAnimateAlways,
        DatMinimapColor,
        DatLensHelp,
        DatFullGround,
        DatIgnoreLook,
        DatCloth,
        DatAnimation, // lastest tibia
        DatLastOpt = 255
    };

    enum InventorySlot : uint8_t
    {
        InventorySlotHead = 1,
        InventorySlotNecklace,
        InventorySlotBackpack,
        InventorySlotArmor,
        InventorySlotRight,
        InventorySlotLeft,
        InventorySlotLegs,
        InventorySlotFeet,
        InventorySlotRing,
        InventorySlotAmmo,
        InventorySlotPurse,
        InventorySlotExt1,
        InventorySlotExt2,
        InventorySlotExt3,
        InventorySlotExt4,
        LastInventorySlot
    };

    enum Statistic : uint8_t
    {
        Health = 0,
        MaxHealth,
        FreeCapacity,
        Experience,
        Level,
        LevelPercent,
        Mana,
        MaxMana,
        MagicLevel,
        MagicLevelPercent,
        Soul,
        Stamina,
        LastStatistic
    };

    enum Skill : uint8_t
    {
        Fist = 0,
        Club,
        Sword,
        Axe,
        Distance,
        Shielding,
        Fishing,
        CriticalChance,
        CriticalDamage,
        LifeLeechChance,
        LifeLeechAmount,
        ManaLeechChance,
        ManaLeechAmount,
        Fatal,
        Dodge,
        Momentum,
        Transcendence,
        LastSkill
    };

    enum Direction : uint8_t
    {
        North = 0,
        East,
        South,
        West,
        NorthEast,
        SouthEast,
        SouthWest,
        NorthWest,
        InvalidDirection
    };

    enum FluidsColor : uint8_t
    {
        FluidTransparent = 0,
        FluidBlue,
        FluidRed,
        FluidOrange,
        FluidGreen,
        FluidYellow,
        FluidWhite,
        FluidPurple,
        FluidBlack,
        FluidBrown,
        FluidPink
    };

    enum FluidsType : uint8_t
    {
        FluidNone = 0,
        FluidWater,
        FluidMana,
        FluidBeer,
        FluidOil,
        FluidBlood,
        FluidSlime,
        FluidMud,
        FluidLemonade,
        FluidMilk,
        FluidWine,
        FluidHealth,
        FluidUrine,
        FluidRum,
        FluidFruitJuice,
        FluidCoconutMilk,
        FluidTea,
        FluidMead,
        FluidInk,
        FluidCandy,
        FluidChocolate
    };

    enum FightModes : uint8_t
    {
        FightOffensive = 1,
        FightBalanced = 2,
        FightDefensive = 3
    };

    enum ChaseModes : uint8_t
    {
        DontChase = 0,
        ChaseOpponent = 1
    };

    enum PVPModes : uint8_t
    {
        WhiteDove = 0,
        WhiteHand = 1,
        YellowHand = 2,
        RedFist = 3
    };

    enum PlayerSkulls : uint8_t
    {
        SkullNone = 0,
        SkullYellow,
        SkullGreen,
        SkullWhite,
        SkullRed,
        SkullBlack,
        SkullOrange
    };

    enum PlayerShields : uint8_t
    {
        ShieldNone = 0,
        ShieldWhiteYellow, // 1 party leader
        ShieldWhiteBlue, // 2 party member
        ShieldBlue, // 3 party member sexp off
        ShieldYellow, // 4 party leader sexp off
        ShieldBlueSharedExp, // 5 party member sexp on
        ShieldYellowSharedExp, // 6 // party leader sexp on
        ShieldBlueNoSharedExpBlink, // 7 party member sexp inactive guilty
        ShieldYellowNoSharedExpBlink, // 8 // party leader sexp inactive guilty
        ShieldBlueNoSharedExp, // 9 party member sexp inactive innocent
        ShieldYellowNoSharedExp, // 10 party leader sexp inactive innocent
        ShieldGray // 11 member of another party
    };

    enum PlayerEmblems : uint8_t
    {
        EmblemNone = 0,
        EmblemGreen,
        EmblemRed,
        EmblemBlue,
        EmblemMember,
        EmblemOther
    };

    enum CreatureIcons : uint8_t
    {
        NpcIconNone = 0,
        NpcIconChat,
        NpcIconTrade,
        NpcIconQuest,
        NpcIconTradeQuest
    };

    enum PlayerStates : uint64_t
    {
        IconNone = 0,
        IconPoison = 1,
        IconBurn = 2,
        IconEnergy = 4,
        IconDrunk = 8,
        IconManaShield = 16,
        IconParalyze = 32,
        IconHaste = 64,
        IconSwords = 128,
        IconDrowning = 256,
        IconFreezing = 512,
        IconDazzled = 1024,
        IconCursed = 2048,
        IconPartyBuff = 4096,
        IconPzBlock = 8192,
        IconPz = 16384,
        IconBleeding = 32768,
        IconHungry = 65536
    };

    enum MessageMode : uint8_t
    {
        MessageNone = 0,
        MessageSay = 1,
        MessageWhisper = 2,
        MessageYell = 3,
        MessagePrivateFrom = 4,
        MessagePrivateTo = 5,
        MessageChannelManagement = 6,
        MessageChannel = 7,
        MessageChannelHighlight = 8,
        MessageSpell = 9,
        MessageNpcFrom = 10,
        MessageNpcTo = 11,
        MessageGamemasterBroadcast = 12,
        MessageGamemasterChannel = 13,
        MessageGamemasterPrivateFrom = 14,
        MessageGamemasterPrivateTo = 15,
        MessageLogin = 16,
        MessageWarning = 17,
        MessageGame = 18,
        MessageFailure = 19,
        MessageLook = 20,
        MessageDamageDealed = 21,
        MessageDamageReceived = 22,
        MessageHeal = 23,
        MessageExp = 24,
        MessageDamageOthers = 25,
        MessageHealOthers = 26,
        MessageExpOthers = 27,
        MessageStatus = 28,
        MessageLoot = 29,
        MessageTradeNpc = 30,
        MessageGuild = 31,
        MessagePartyManagement = 32,
        MessageParty = 33,
        MessageBarkLow = 34,
        MessageBarkLoud = 35,
        MessageReport = 36,
        MessageHotkeyUse = 37,
        MessageTutorialHint = 38,
        MessageThankyou = 39,
        MessageMarket = 40,
        MessageMana = 41,
        MessageBeyondLast = 42,

        // deprecated
        MessageMonsterYell = 43,
        MessageMonsterSay = 44,
        MessageRed = 45,
        MessageBlue = 46,
        MessageRVRChannel = 47,
        MessageRVRAnswer = 48,
        MessageRVRContinue = 49,
        MessageGameHighlight = 50,
        MessageNpcFromStartBlock = 51,

        // 12x
        MessageAttention = 52,
        MessageBoostedCreature = 53,
        MessageOfflineTrainning = 54,
        MessageTransaction = 55,
        MessagePotion = 56,
        LastMessage = 57,
        MessageInvalid = 255
    };

    enum PreySlotNum_t : uint8_t
    {
        PREY_SLOTNUM_FIRST = 0,
        PREY_SLOTNUM_SECOND = 1,
        PREY_SLOTNUM_THIRD = 2,
        PREY_SLOTNUM_LAST = PREY_SLOTNUM_THIRD
    };

    enum PreyState_t : uint8_t
    {
        PREY_STATE_LOCKED = 0,
        PREY_STATE_INACTIVE = 1,
        PREY_STATE_ACTIVE = 2,
        PREY_STATE_SELECTION = 3,
        PREY_STATE_SELECTION_CHANGE_MONSTER = 4,
        PREY_STATE_LIST_SELECTION = 5,
        PREY_STATE_WILDCARD_SELECTION = 6,
    };

    enum PreyTaskstate_t : uint8_t
    {
        PREY_TASK_STATE_LOCKED = 0,
        PREY_TASK_STATE_INACTIVE = 1,
        PREY_TASK_STATE_SELECTION = 2,
        PREY_TASK_STATE_LIST_SELECTION = 3,
        PREY_TASK_STATE_ACTIVE = 4,
        PREY_TASK_STATE_COMPLETED = 5
    };

    enum PreyMessageDialog_t : uint8_t
    {
        //PREY_MESSAGEDIALOG_IMBUEMENT_SUCCESS = 0,
        //PREY_MESSAGEDIALOG_IMBUEMENT_ERROR = 1,
        //PREY_MESSAGEDIALOG_IMBUEMENT_ROLL_FAILED = 2,
        //PREY_MESSAGEDIALOG_IMBUEMENT_STATION_NOT_FOUND = 3,
        //PREY_MESSAGEDIALOG_IMBUEMENT_CHARM_SUCCESS = 10,
        //PREY_MESSAGEDIALOG_IMBUEMENT_CHARM_ERROR = 11,
        PREY_MESSAGEDIALOG_PREY_MESSAGE = 20,
        PREY_MESSAGEDIALOG_PREY_ERROR = 21,
    };
    enum PreyResourceType_t : uint8_t
    {
        PREY_RESOURCETYPE_BANK_GOLD = 0,
        PREY_RESOURCETYPE_INVENTORY_GOLD = 1,
        PREY_RESOURCETYPE_PREY_BONUS_REROLLS = 10
    };
    enum PreyBonusType_t : uint8_t
    {
        PREY_BONUS_DAMAGE_BOOST = 0,
        PREY_BONUS_DAMAGE_REDUCTION = 1,
        PREY_BONUS_XP_BONUS = 2,
        PREY_BONUS_IMPROVED_LOOT = 3,
        PREY_BONUS_NONE = 4, // internal usage but still added to client;
        PREY_BONUS_FIRST = PREY_BONUS_DAMAGE_BOOST,
        PREY_BONUS_LAST = PREY_BONUS_IMPROVED_LOOT,
    };
    enum PreyAction_t : uint8_t
    {
        PREY_ACTION_LISTREROLL = 0,
        PREY_ACTION_BONUSREROLL = 1,
        PREY_ACTION_MONSTERSELECTION = 2,
        PREY_ACTION_REQUEST_ALL_MONSTERS = 3,
        PREY_ACTION_CHANGE_FROM_ALL = 4,
        PREY_ACTION_OPTION = 5,
    };
    enum PreyOption_t : uint8_t
    {
        PREY_OPTION_UNTOGGLE = 0,
        PREY_OPTION_TOGGLE_AUTOREROLL = 1,
        PREY_OPTION_TOGGLE_LOCK_PREY = 2,
    };
    enum PreyConfigState : uint8_t
    {
        PREY_CONFIG_STATE_FREE,
        PREY_CONFIG_STATE_PREMIUM,
        PREY_CONFIG_STATE_TIBIACOINS
    };
    enum PreyUnlockState_t : uint8_t
    {
        PREY_UNLOCK_STORE_AND_PREMIUM = 0,
        PREY_UNLOCK_STORE = 1,
        PREY_UNLOCK_NONE = 2,
    };
    enum class ForgeAction_t : uint8_t
    {
        FUSION = 0,
        TRANSFER = 1,
        DUST2SLIVER = 2,
        SLIVER2CORE = 3,
        INCREASELIMIT = 4,
    };

    enum GameFeature : uint8_t
    {
        GameProtocolChecksum = 1,
        GameAccountNames = 2,
        GameChallengeOnLogin = 3,
        GamePenalityOnDeath = 4,
        GameNameOnNpcTrade = 5,
        GameDoubleFreeCapacity = 6,
        GameDoubleExperience = 7,
        GameTotalCapacity = 8,
        GameSkillsBase = 9,
        GamePlayerRegenerationTime = 10,
        GameChannelPlayerList = 11,
        GamePlayerMounts = 12,
        GameEnvironmentEffect = 13,
        GameCreatureEmblems = 14,
        GameItemAnimationPhase = 15,
        GameMagicEffectU16 = 16,
        GamePlayerMarket = 17,
        GameSpritesU32 = 18,
        // 19 unused
        GameOfflineTrainingTime = 20,
        GamePurseSlot = 21,
        GameFormatCreatureName = 22,
        GameSpellList = 23,
        GameClientPing = 24,
        GameExtendedClientPing = 25,
        GameDoubleHealth = 28,
        GameDoubleSkills = 29,
        GameChangeMapAwareRange = 30,
        GameMapMovePosition = 31,
        GameAttackSeq = 32,
        GameBlueNpcNameColor = 33,
        GameDiagonalAnimatedText = 34,
        GameLoginPending = 35,
        GameNewSpeedLaw = 36,
        GameForceFirstAutoWalkStep = 37,
        GameMinimapRemove = 38,
        GameDoubleShopSellAmount = 39,
        GameContainerPagination = 40,
        GameThingMarks = 41,
        GameLooktypeU16 = 42,
        GamePlayerStamina = 43,
        GamePlayerAddons = 44,
        GameMessageStatements = 45,
        GameMessageLevel = 46,
        GameNewFluids = 47,
        GamePlayerStateU16 = 48,
        GameNewOutfitProtocol = 49,
        GamePVPMode = 50,
        GameWritableDate = 51,
        GameAdditionalVipInfo = 52,
        GameBaseSkillU16 = 53,
        GameCreatureIcons = 54,
        GameHideNpcNames = 55,
        GameSpritesAlphaChannel = 56,
        GamePremiumExpiration = 57,
        GameBrowseField = 58,
        GameEnhancedAnimations = 59,
        GameOGLInformation = 60,
        GameMessageSizeCheck = 61,
        GamePreviewState = 62,
        GameLoginPacketEncryption = 63,
        GameClientVersion = 64,
        GameContentRevision = 65,
        GameExperienceBonus = 66,
        GameAuthenticator = 67,
        GameUnjustifiedPoints = 68,
        GameSessionKey = 69,
        GameDeathType = 70,
        GameIdleAnimations = 71,
        GameKeepUnawareTiles = 72,
        GameIngameStore = 73,
        GameIngameStoreHighlights = 74,
        GameIngameStoreServiceType = 75,
        GameAdditionalSkills = 76,
        GameDistanceEffectU16 = 77,
        GameLevelU16 = 78,
        GameSoul = 79,
        GameMapOldEffectRendering = 80,
        GameMapDontCorrectCorpse = 81,
        GamePrey = 82,
        GameThingQuickLoot = 83,
        GameThingQuiver = 84,
        GameThingPodium = 85,
        GameThingUpgradeClassification = 86,
        GameThingCounter = 87,
        GameThingClock = 88,
        GameThingPodiumItemType = 89,
        GameSequencedPackets = 90,
        GameUshortSpell = 91,
        GameTournamentPackets = 92,
        GameDynamicForgeVariables = 93,
        GameConcotions = 94,
        GameAnthem = 95,
        GameVipGroups = 96,
        GameBosstiary = 97,
        GameDoublePlayerGoodsMoney = 98,

        //  others
        GameLoadSprInsteadProtobuf = 100,
        GameItemShader = 101,
        GameCreatureShader = 102,
        GameCreatureAttachedEffect = 103,
        GameCountU16 = 104,
        GameEffectU16 = 105,
        GameContainerTypes = 106,
        GameBosstiaryTracker = 107,
        GamePlayerStateCounter = 108,
        GameLeechAmount = 109,
        GameItemAugment = 110,
        GameDynamicBugReporter = 111,
        GameWrapKit = 112,
        GameContainerFilter = 113,
        GameEnterGameShowAppearance = 114,
        GameSmoothWalkElevation = 115,
        GameNegativeOffset = 116,
        GameItemTooltipV8 = 117,
        GameWingsAurasEffectsShader = 118,
        GameForgeConvergence = 119,
        GameAllowCustomBotScripts = 120,
        GameColorizedLootValue = 121,
        GameAllowPreWalk = 122,
        GamePlayerFamiliars = 123,
        GameTileAddThingWithStackpos = 124,
        GameMapCache = 125,
        GameForgeSkillStats = 126,
        GameCharacterSkillStats = 127,
        GameCreaturePaperdoll = 128,
        GameMultiSpr = 129,
        GameVocationMonk = 130,
        GameLevelPercentU16 = 131,
        GameEffectSource = 132,
        GameNpcWindowRedesign = 133,
        LastGameFeature
    };

    enum MagicEffectsType_t : uint8_t
    {
        MAGIC_EFFECTS_END_LOOP = 0, // ends the magic effect loop
        MAGIC_EFFECTS_DELTA = 1, // needs uint8_t delta after type to adjust position
        MAGIC_EFFECTS_DELAY = 2, // needs uint16_t delay after type to delay in miliseconds effect display
        MAGIC_EFFECTS_CREATE_EFFECT = 3, // needs uint8_t effectid after type
        MAGIC_EFFECTS_CREATE_DISTANCEEFFECT = 4, // needs uint8_t and deltaX(int8_t), deltaY(int8_t) after type
        MAGIC_EFFECTS_CREATE_DISTANCEEFFECT_REVERSED = 5, // needs uint8_t and deltaX(int8_t), deltaY(int8_t) after type
        MAGIC_EFFECTS_CREATE_SOUND_MAIN_EFFECT = 6, // needs uint16_t after type
        MAGIC_EFFECTS_CREATE_SOUND_SECONDARY_EFFECT = 7, // needs uint8_t and uint16_t after type
    };

    enum PathFindResult : uint8_t
    {
        PathFindResultOk = 0,
        PathFindResultSamePosition,
        PathFindResultImpossible,
        PathFindResultTooFar,
        PathFindResultNoWay
    };

    enum PathFindFlags : uint8_t
    {
        PathFindAllowNotSeenTiles = 1,
        PathFindAllowCreatures = 2,
        PathFindAllowNonPathable = 4,
        PathFindAllowNonWalkable = 8,
        PathFindIgnoreCreatures = 16
    };

    enum AutomapFlags : uint8_t
    {
        MapMarkTick = 0,
        MapMarkQuestion,
        MapMarkExclamation,
        MapMarkStar,
        MapMarkCross,
        MapMarkTemple,
        MapMarkKiss,
        MapMarkShovel,
        MapMarkSword,
        MapMarkFlag,
        MapMarkLock,
        MapMarkBag,
        MapMarkSkull,
        MapMarkDollar,
        MapMarkRedNorth,
        MapMarkRedSouth,
        MapMarkRedEast,
        MapMarkRedWest,
        MapMarkGreenNorth,
        MapMarkGreenSouth
    };

    enum VipState : uint8_t
    {
        VipStateOffline = 0,
        VipStateOnline = 1,
        VipStatePending = 2
    };

    enum Blessings : uint32_t
    {
        BlessingNone = 0,
        BlessingAdventurer = 1,
        BlessingSpiritualShielding = 1 << 1,
        BlessingEmbraceOfTibia = 1 << 2,
        BlessingFireOfSuns = 1 << 3,
        BlessingWisdomOfSolitude = 1 << 4,
        BlessingSparkOfPhoenix = 1 << 5
    };

    enum DeathType : uint8_t
    {
        DeathRegular = 0,
        DeathBlessed = 1
    };

    enum StoreProductTypes : uint8_t
    {
        ProductTypeOther = 0,
        ProductTypeNameChange = 1
    };

    enum StoreErrorTypes : int8_t
    {
        StoreNoError = -1,
        StorePurchaseError = 0,
        StoreNetworkError = 1,
        StoreHistoryError = 2,
        StoreTransferError = 3,
        StoreInformation = 4
    };

    enum StoreStates : uint8_t
    {
        StateNone = 0,
        StateNew = 1,
        StateSale = 2,
        StateTimed = 3
    };

    enum ResourceTypes_t : uint8_t
    {
        RESOURCE_BANK_BALANCE = 0,
        RESOURCE_GOLD_EQUIPPED = 1,
        RESOURCE_CURRENCY_CUSTOM_EQUIPPED = 2,
        RESOURCE_PREY_WILDCARDS = 10,
        RESOURCE_DAILYREWARD_STREAK = 20,
        RESOURCE_DAILYREWARD_JOKERS = 21,
        RESOURCE_CHARM = 30,
        RESOURCE_MINOR_CHARM = 31,
        RESOURCE_MAX_CHARM = 32,
        RESOURCE_MAX_MINOR_CHARM = 33,
        RESOURCE_TASK_HUNTING = 50,
        RESOURCE_FORGE_DUST = 70,
        RESOURCE_FORGE_SLIVER = 71,
        RESOURCE_FORGE_CORES = 72,
        RESOURCE_LESSER_GEMS = 81,
        RESOURCE_REGULAR_GEMS = 82,
        RESOURCE_GREATER_GEMS = 83,
        RESOURCE_LESSER_FRAGMENTS = 84,
        RESOURCE_GREATER_FRAGMENTS = 85,
        RESOURCE_WHEEL_OF_DESTINY = 86,
        RESOURE_COIN_NORMAL = 90,
        RESOURE_COIN_TRANSFERRABLE = 91,
        RESOURE_COIN_AUCTION = 92,
        RESOURE_COIN_TOURNAMENT = 93,
    };

    enum ExperienceRate_t : uint8_t
    {
        EXP_BASE = 0,
        EXP_VOUCHER = 1,
        EXP_LOWLEVEL = 2,
        EXP_XPBOOST = 3,
        EXP_STANINAMULTIPLIER = 4
    };

    enum MarketItemDescription : uint8_t
    {
        ITEM_DESC_ARMOR = 1,
        ITEM_DESC_ATTACK = 2,
        ITEM_DESC_CONTAINTER = 3,
        ITEM_DESC_DEFENSE = 4,
        ITEM_DESC_GENERAL = 5,
        ITEM_DESC_DECAY_TIME = 6,
        ITEM_DESC_COMBAT = 7,
        ITEM_DESC_MINLEVEL = 8,
        ITEM_DESC_MINMAGICLEVEL = 9,
        ITEM_DESC_VOCATION = 10,
        ITEM_DESC_RUNE = 11,
        ITEM_DESC_ABILITY = 12,
        ITEM_DESC_CHARGES = 13,
        ITEM_DESC_WEAPONTYPE = 14,
        ITEM_DESC_WEIGHT = 15,
        ITEM_DESC_AUGMENT = 16,
        ITEM_DESC_IMBUINGSLOTS = 17,
        ITEM_DESC_MAGICSHIELD = 18,
        ITEM_DESC_CLEAVE = 19,
        ITEM_DESC_REFLECTION = 20,
        ITEM_DESC_PERFECT = 21,
        ITEM_DESC_UPGRADECLASS = 22,
        ITEM_DESC_CURRENTTIER = 23,
        ITEM_DESC_ELEMENTALBOND = 24,
        ITEM_DESC_MANTRA = 25,
        ITEM_DESC_IMBUEMENTEFFECT = 26,

        ITEM_DESC_FIRST = ITEM_DESC_ARMOR,
        ITEM_DESC_LAST = ITEM_DESC_IMBUEMENTEFFECT,
    };

    enum MarketAction : uint8_t
    {
        MARKETACTION_BUY = 0,
        MARKETACTION_SELL = 1
    };

    enum MarketRequest : uint16_t
    {
        MARKETREQUEST_OWN_HISTORY = 1,
        MARKETREQUEST_OWN_OFFERS = 2,
        MARKETREQUEST_ITEM_BROWSE = 3,
        OLD_MARKETREQUEST_MY_OFFERS = 0xFFFE,
        OLD_MARKETREQUEST_MY_HISTORY = 0xFFFF,
    };

    enum MarketOfferState : uint8_t
    {
        OFFER_STATE_ACTIVE = 0,
        OFFER_STATE_CANCELLED = 1,
        OFFER_STATE_EXPIRED = 2,
        OFFER_STATE_ACCEPTED = 3,
        OFFER_STATE_ACCEPTEDEX = 255
    };

    enum Supply_Stash_Actions_t : uint8_t
    {
        SUPPLY_STASH_ACTION_STOW_ITEM = 0,
        SUPPLY_STASH_ACTION_STOW_CONTAINER = 1,
        SUPPLY_STASH_ACTION_STOW_STACK = 2,
        SUPPLY_STASH_ACTION_WITHDRAW = 3
    };

    enum CyclopediaHouseState_t : uint8_t
    {
        CYCLOPEDIA_HOUSE_STATE_AVAILABLE = 0,
        // 1 ?
        CYCLOPEDIA_HOUSE_STATE_RENTED = 2,
        CYCLOPEDIA_HOUSE_STATE_TRANSFER = 3,
        CYCLOPEDIA_HOUSE_STATE_MOVEOUT = 4,
    };

    enum CyclopediaHouseAuctionType_t : uint8_t
    {
        CYCLOPEDIA_HOUSE_TYPE_NONE = 0,
        CYCLOPEDIA_HOUSE_TYPE_BID = 1,
        CYCLOPEDIA_HOUSE_TYPE_MOVEOUT = 2,
        CYCLOPEDIA_HOUSE_TYPE_TRANSFER = 3,
        CYCLOPEDIA_HOUSE_TYPE_CANCEL_MOVEOUT = 4,
        CYCLOPEDIA_HOUSE_TYPE_CANCEL_TRANSFER = 5,
        CYCLOPEDIA_HOUSE_TYPE_ACCEPT_TRANSFER = 6,
        CYCLOPEDIA_HOUSE_TYPE_REFECT_TRANSFER = 7,
    };

    enum CyclopediaCharacterInfoType_t : uint8_t
    {
        CYCLOPEDIA_CHARACTERINFO_BASEINFORMATION = 0,
        CYCLOPEDIA_CHARACTERINFO_GENERALSTATS = 1,
        CYCLOPEDIA_CHARACTERINFO_COMBATSTATS = 2,
        CYCLOPEDIA_CHARACTERINFO_RECENTDEATHS = 3,
        CYCLOPEDIA_CHARACTERINFO_RECENTPVPKILLS = 4,
        CYCLOPEDIA_CHARACTERINFO_ACHIEVEMENTS = 5,
        CYCLOPEDIA_CHARACTERINFO_ITEMSUMMARY = 6,
        CYCLOPEDIA_CHARACTERINFO_OUTFITSMOUNTS = 7,
        CYCLOPEDIA_CHARACTERINFO_STORESUMMARY = 8,
        CYCLOPEDIA_CHARACTERINFO_INSPECTION = 9,
        CYCLOPEDIA_CHARACTERINFO_BADGES = 10,
        CYCLOPEDIA_CHARACTERINFO_TITLES = 11,
        CYCLOPEDIA_CHARACTERINFO_WHEEL = 12,
        CYCLOPEDIA_CHARACTERINFO_OFFENCESTATS = 13,
        CYCLOPEDIA_CHARACTERINFO_DEFENCESTATS = 14,
        CYCLOPEDIA_CHARACTERINFO_MISCSTATS = 15
    };

    enum InspectObjectTypes : uint8_t
    {
        INSPECT_NORMALOBJECT = 0,
        INSPECT_NPCTRADE = 1,
        INSPECT_PLAYERTRADE = 2,
        INSPECT_CYCLOPEDIA = 3
    };

    enum GameStoreInfoType_t : uint8_t
    {
        SHOW_NONE = 0,
        SHOW_MOUNT = 1,
        SHOW_OUTFIT = 2,
        SHOW_ITEM = 3,
        SHOW_HIRELING = 4
    };

    enum GameStoreInfoStatesType_t : uint8_t
    {
        STATE_NONE = 0,
        STATE_NEW = 1,
        STATE_SALE = 2,
        STATE_TIMED = 3
    };

    enum GroupsEditInfoType_t : uint8_t
    {
        VIP_GROUP_NONE = 0,
        VIP_GROUP_ADD = 1,
        VIP_GROUP_EDIT = 2,
        VIP_GROUP_REMOVE = 3,
    };

    enum Store_Type_Actions_t : uint8_t
    {
        OPEN_HOME = 0,
        OPEN_PREMIUM_BOOST = 1,
        OPEN_CATEGORY = 2,
        OPEN_USEFUL_THINGS = 3,
        OPEN_OFFER = 4,
        OPEN_SEARCH = 5,
    };

    enum WeaponProficiency_t : uint8_t
    {
        WEAPON_PROFICIENCY_ITEM_INFO = 0,
        WEAPON_PROFICIENCY_LIST_INFO = 1,
        WEAPON_PROFICIENCY_RESET_PERKS = 2,
        WEAPON_PROFICIENCY_APPLY_PERKS = 3
    };

    enum Imbuement_Window_t : uint8_t
    {
        IMBUEMENT_WINDOW_CHOICE = 0,
        IMBUEMENT_WINDOW_SELECT_ITEM = 1,
        IMBUEMENT_WINDOW_SCROLL = 2
    };

    enum ClientEventType_t : uint8_t
    {
        CLIENT_EVENT_TYPE_SIMPLE = 1,
        CLIENT_EVENT_TYPE_ACHIEVEMENT = 2,
        CLIENT_EVENT_TYPE_TITLE = 3,
        CLIENT_EVENT_TYPE_LEVEL = 4,
        CLIENT_EVENT_TYPE_SKILL = 5,
        CLIENT_EVENT_TYPE_BESTIARY = 6,
        CLIENT_EVENT_TYPE_BOSSTIARY = 7,
        CLIENT_EVENT_TYPE_QUEST = 8,
        CLIENT_EVENT_TYPE_COSMETIC = 9,
        CLIENT_EVENT_TYPE_PROFICIENCY = 10,
        CLIENT_EVENT_TYPE_LAST
    };

    enum ClientEvent_t : uint8_t
    {
        // screenshot
        CLIENT_EVENT_NONE = 0,
        CLIENT_EVENT_BOSSDEFEATED = 1,
        CLIENT_EVENT_DEATHPVE = 2,
        CLIENT_EVENT_DEATHPVP = 3,
        CLIENT_EVENT_PLAYERKILLASSIST = 4,
        CLIENT_EVENT_PLAYERKILL = 5,
        CLIENT_EVENT_PLAYERATTACKING = 6,
        CLIENT_EVENT_TREASUREFOUND = 7,
        CLIENT_EVENT_GIFTOFLIFE = 8,
        // pop up
        CLIENT_EVENT_ATTACKSTOPPED = 9,
        CLIENT_EVENT_CAPACITYLIMIT = 10,
        CLIENT_EVENT_OUTOFAMMO = 11,
        CLIENT_EVENT_TARGETTOOCLOSE = 12,
        CLIENT_EVENT_OUTOFSOULPOINTS = 13,
        CLIENT_EVENT_TUTORIALCOMPLETE = 14,
        CLIENT_EVENT_LAST
    };

    enum Vocations_t : uint8_t
    {
        NONE = 0,
        KNIGHT = 1,
        PALADIN = 2,
        SORCERER = 3,
        DRUID = 4,
        MONK = 5,
        ELITE_KNIGHT = 11,
        ROYAL_PALADIN = 12,
        MASTER_SORCERER = 13,
        ELDER_DRUID = 14,
        EXALTED_MONK = 15,
        FIRST = KNIGHT,
        LAST = MONK,
    };

    enum PartyAnalyzerAction_t : uint8_t
    {
        PARTYANALYZERACTION_RESET = 0,
        PARTYANALYZERACTION_PRICETYPE = 1,
        PARTYANALYZERACTION_PRICEVALUE = 2,
    };

    enum VocationMonkTypes_t : uint8_t
    {
        TYPES_MONK_HARMONY = 0,
        TYPES_MONK_SERENE = 1,
        TYPES_MONK_VIRTUE = 2,
        TYPES_MONK_LAST
    };

    enum FloorViewMode
    {
        NORMAL,
        FADE,
        LOCKED,
        ALWAYS,
        ALWAYS_WITH_TRANSPARENCY
    };

    enum AntialiasingMode :uint8_t
    {
        ANTIALIASING_DISABLED,
        ANTIALIASING_ENABLED,
        ANTIALIASING_SMOOTH_RETRO
    };

    enum MagicEffectSources : uint8_t
    {
        // always 100% opacity, not configurable
        ME_SOURCE_DEFAULT = 0,
        // configurable with sliders in the client
        ME_SOURCE_OWN = 1,
        ME_SOURCE_OTHER_PLAYER = 2,
        ME_SOURCE_MONSTER = 3,
        ME_SOURCE_BOSS = 4,
        ME_SOURCE_LAST = ME_SOURCE_BOSS
    }; 

    enum class WheelSlots_t : uint8_t
    {
        SLOT_GREEN_200 = 1,
        SLOT_GREEN_TOP_150 = 2,
        SLOT_GREEN_TOP_100 = 3,

        SLOT_RED_TOP_100 = 4,
        SLOT_RED_TOP_150 = 5,
        SLOT_RED_200 = 6,

        SLOT_GREEN_BOTTOM_150 = 7,
        SLOT_GREEN_MIDDLE_100 = 8,
        SLOT_GREEN_TOP_75 = 9,

        SLOT_RED_TOP_75 = 10,
        SLOT_RED_MIDDLE_100 = 11,
        SLOT_RED_BOTTOM_150 = 12,

        SLOT_GREEN_BOTTOM_100 = 13,
        SLOT_GREEN_BOTTOM_75 = 14,
        SLOT_GREEN_50 = 15,

        SLOT_RED_50 = 16,
        SLOT_RED_BOTTOM_75 = 17,
        SLOT_RED_BOTTOM_100 = 18,

        SLOT_BLUE_TOP_100 = 19,
        SLOT_BLUE_TOP_75 = 20,
        SLOT_BLUE_50 = 21,

        SLOT_PURPLE_50 = 22,
        SLOT_PURPLE_TOP_75 = 23,
        SLOT_PURPLE_TOP_100 = 24,

        SLOT_BLUE_TOP_150 = 25,
        SLOT_BLUE_MIDDLE_100 = 26,
        SLOT_BLUE_BOTTOM_75 = 27,

        SLOT_PURPLE_BOTTOM_75 = 28,
        SLOT_PURPLE_MIDDLE_100 = 29,
        SLOT_PURPLE_TOP_150 = 30,

        SLOT_BLUE_200 = 31,
        SLOT_BLUE_BOTTOM_150 = 32,
        SLOT_BLUE_BOTTOM_100 = 33,

        SLOT_PURPLE_BOTTOM_100 = 34,
        SLOT_PURPLE_BOTTOM_150 = 35,
        SLOT_PURPLE_200 = 36,

        SLOT_FIRST = SLOT_GREEN_200,
        SLOT_LAST = SLOT_PURPLE_200
    };
    // Qualidade das gemas
    enum WheelGemQuality_t : uint8_t {
        WheelGemQuality_Lesser   = 0,
        WheelGemQuality_Regular  = 1,
        WheelGemQuality_Greater  = 2,
        WheelGemQuality_Supreme  = 3
    };
}

enum FrameGroupType : uint8_t
{
    FrameGroupDefault = 0,
    FrameGroupIdle = FrameGroupDefault,
    FrameGroupMoving,
    FrameGroupInitial
};

enum ThingCategory : uint8_t
{
    ThingCategoryItem = 0,
    ThingCategoryCreature,
    ThingCategoryEffect,
    ThingCategoryMissile,
    ThingInvalidCategory,
    ThingExternalTexture,
    ThingLastCategory = ThingInvalidCategory,
};

enum StaticDataCategory : uint8_t
{
    StaticDataMonster = 0,
    StaticDataAchievement,
    StaticDataHouse,
    StaticDataBoss,
    StaticDataQuest,
    StaticDataLast = StaticDataQuest,
};

enum ThingAttr : uint8_t
{
    ThingAttrGround = 0,
    ThingAttrGroundBorder = 1,
    ThingAttrOnBottom = 2,
    ThingAttrOnTop = 3,
    ThingAttrContainer = 4,
    ThingAttrStackable = 5,
    ThingAttrForceUse = 6,
    ThingAttrMultiUse = 7,
    ThingAttrWritable = 8,
    ThingAttrWritableOnce = 9,
    ThingAttrFluidContainer = 10,
    ThingAttrSplash = 11,
    ThingAttrNotWalkable = 12,
    ThingAttrNotMoveable = 13,
    ThingAttrBlockProjectile = 14,
    ThingAttrNotPathable = 15,
    ThingAttrPickupable = 16,
    ThingAttrHangable = 17,
    ThingAttrHookSouth = 18,
    ThingAttrHookEast = 19,
    ThingAttrRotateable = 20,
    ThingAttrLight = 21,
    ThingAttrDontHide = 22,
    ThingAttrTranslucent = 23,
    ThingAttrDisplacement = 24,
    ThingAttrElevation = 25,
    ThingAttrLyingCorpse = 26,
    ThingAttrAnimateAlways = 27,
    ThingAttrMinimapColor = 28,
    ThingAttrLensHelp = 29,
    ThingAttrFullGround = 30,
    ThingAttrLook = 31,
    ThingAttrCloth = 32,
    ThingAttrMarket = 33,
    ThingAttrUsable = 34,
    ThingAttrWrapable = 35,
    ThingAttrUnwrapable = 36,
    ThingAttrTopEffect = 37,
    ThingAttrUpgradeClassification = 38,
    ThingAttrWearOut = 39,
    ThingAttrClockExpire = 40,
    ThingAttrExpire = 41,
    ThingAttrExpireStop = 42,
    ThingAttrPodium = 43,
    ThingAttrDecoKit = 44,

    // additional
    ThingAttrOpacity = 100,

    ThingAttrDefaultAction = 251,

    ThingAttrFloorChange = 252,
    ThingAttrNoMoveAnimation = 253, // 10.10: real value is 16, but we need to do this for backwards compatibility
    ThingAttrChargeable = 254, // deprecated
    ThingLastAttr = 255
};

enum ThingFlagAttr :uint64_t
{
    ThingFlagAttrNone = 0,
    ThingFlagAttrGround = 1 << 0,
    ThingFlagAttrGroundBorder = 1 << 1,
    ThingFlagAttrOnBottom = 1 << 2,
    ThingFlagAttrOnTop = 1 << 3,
    ThingFlagAttrContainer = 1 << 4,
    ThingFlagAttrStackable = 1 << 5,
    ThingFlagAttrForceUse = 1 << 6,
    ThingFlagAttrMultiUse = 1 << 7,
    ThingFlagAttrWritable = 1 << 8,
    ThingFlagAttrChargeable = 1 << 9,
    ThingFlagAttrWritableOnce = 1 << 10,
    ThingFlagAttrFluidContainer = 1 << 11,
    ThingFlagAttrSplash = 1 << 12,
    ThingFlagAttrNotWalkable = 1 << 13,
    ThingFlagAttrNotMoveable = 1 << 14,
    ThingFlagAttrBlockProjectile = 1 << 15,
    ThingFlagAttrNotPathable = 1 << 16,
    ThingFlagAttrPickupable = 1 << 17,
    ThingFlagAttrHangable = 1 << 18,
    ThingFlagAttrHookSouth = 1 << 19,
    ThingFlagAttrHookEast = 1 << 20,
    ThingFlagAttrRotateable = 1 << 21,
    ThingFlagAttrLight = 1 << 22,
    ThingFlagAttrDontHide = 1 << 23,
    ThingFlagAttrTranslucent = 1 << 24,
    ThingFlagAttrDisplacement = 1 << 25,
    ThingFlagAttrElevation = 1 << 26,
    ThingFlagAttrLyingCorpse = 1 << 27,
    ThingFlagAttrAnimateAlways = 1 << 28,
    ThingFlagAttrMinimapColor = 1 << 29,
    ThingFlagAttrLensHelp = 1 << 30,
    ThingFlagAttrFullGround = static_cast<uint64_t>(1) << 31,
    ThingFlagAttrLook = static_cast<uint64_t>(1) << 32,
    ThingFlagAttrCloth = static_cast<uint64_t>(1) << 33,
    ThingFlagAttrMarket = static_cast<uint64_t>(1) << 34,
    ThingFlagAttrUsable = static_cast<uint64_t>(1) << 35,
    ThingFlagAttrWrapable = static_cast<uint64_t>(1) << 36,
    ThingFlagAttrUnwrapable = static_cast<uint64_t>(1) << 37,
    ThingFlagAttrWearOut = static_cast<uint64_t>(1) << 38,
    ThingFlagAttrClockExpire = static_cast<uint64_t>(1) << 39,
    ThingFlagAttrExpire = static_cast<uint64_t>(1) << 40,
    ThingFlagAttrExpireStop = static_cast<uint64_t>(1) << 41,
    ThingFlagAttrPodium = static_cast<uint64_t>(1) << 42,
    ThingFlagAttrTopEffect = static_cast<uint64_t>(1) << 43,
    ThingFlagAttrDefaultAction = static_cast<uint64_t>(1) << 44,
    ThingFlagAttrDecoKit = static_cast<uint64_t>(1) << 45,
    ThingFlagAttrNPC = static_cast<uint64_t>(1) << 46,
    ThingFlagAttrAmmo = static_cast<uint64_t>(1) << 47,
    ThingFlagAttrFloorChange = static_cast<uint64_t>(1) << 48,
    ThingFlagAttrDualWield = static_cast<uint64_t>(1) << 49,
    ThingFlagAttrSkillWheelGem = static_cast<uint64_t>(1) << 50,
};

enum STACK_PRIORITY : uint8_t
{
    GROUND = 0,
    GROUND_BORDER = 1,
    ON_BOTTOM = 2,
    ON_TOP = 3,
    CREATURE = 4,
    COMMON_ITEMS = 5
};

enum PLAYER_ACTION : uint8_t
{
    PLAYER_ACTION_NONE = 0,
    PLAYER_ACTION_LOOK = 1,
    PLAYER_ACTION_USE = 2,
    PLAYER_ACTION_OPEN = 3,
    PLAYER_ACTION_AUTOWALK_HIGHLIGHT = 4
};

enum ITEM_CATEGORY : uint8_t
{
    ITEM_CATEGORY_ARMORS = 1,
    ITEM_CATEGORY_AMULETS = 2,
    ITEM_CATEGORY_BOOTS = 3,
    ITEM_CATEGORY_CONTAINERS = 4,
    ITEM_CATEGORY_DECORATION = 5,
    ITEM_CATEGORY_FOOD = 6,
    ITEM_CATEGORY_HELMETS_HATS = 7,
    ITEM_CATEGORY_LEGS = 8,
    ITEM_CATEGORY_OTHERS = 9,
    ITEM_CATEGORY_POTIONS = 10,
    ITEM_CATEGORY_RINGS = 11,
    ITEM_CATEGORY_RUNES = 12,
    ITEM_CATEGORY_SHIELDS = 13,
    ITEM_CATEGORY_TOOLS = 14,
    ITEM_CATEGORY_VALUABLES = 15,
    ITEM_CATEGORY_AMMUNITION = 16,
    ITEM_CATEGORY_AXES = 17,
    ITEM_CATEGORY_CLUBS = 18,
    ITEM_CATEGORY_DISTANCE_WEAPONS = 19,
    ITEM_CATEGORY_SWORDS = 20,
    ITEM_CATEGORY_WANDS_RODS = 21,
    ITEM_CATEGORY_PREMIUM_SCROLLS = 22,
    ITEM_CATEGORY_TIBIA_COINS = 23,
    ITEM_CATEGORY_CREATURE_PRODUCTS = 24,
    ITEM_CATEGORY_QUIVER = 25,
    ITEM_CATEGORY_SOUL_CORES = 26,
    ITEM_CATEGORY_FIST_WEAPONS = 27,
};

enum SpriteMask :uint8_t
{
    SpriteMaskRed = 1,
    SpriteMaskGreen,
    SpriteMaskBlue,
    SpriteMaskYellow
};

#ifdef FRAMEWORK_EDITOR
enum tileflags_t : uint32_t
{
    TILESTATE_NONE = 0,
    TILESTATE_PROTECTIONZONE = 1 << 0,
    TILESTATE_TRASHED = 1 << 1,
    TILESTATE_OPTIONALZONE = 1 << 2,
    TILESTATE_NOLOGOUT = 1 << 3,
    TILESTATE_HARDCOREZONE = 1 << 4,
    TILESTATE_REFRESH = 1 << 5,

    // internal usage
    TILESTATE_HOUSE = 1 << 6,
    TILESTATE_TELEPORT = 1 << 17,
    TILESTATE_MAGICFIELD = 1 << 18,
    TILESTATE_MAILBOX = 1 << 19,
    TILESTATE_TRASHHOLDER = 1 << 20,
    TILESTATE_BED = 1 << 21,
    TILESTATE_DEPOT = 1 << 22,
    TILESTATE_TRANSLUECENT_LIGHT = 1 << 23,

    TILESTATE_LAST = 1 << 24
};

enum ItemTypeAttr : uint8_t
{
    ItemTypeAttrServerId = 16,
    ItemTypeAttrClientId = 17,
    ItemTypeAttrName = 18,   // deprecated
    ItemTypeAttrDesc = 19,   // deprecated
    ItemTypeAttrSpeed = 20,
    ItemTypeAttrSlot = 21,   // deprecated
    ItemTypeAttrMaxItems = 22,   // deprecated
    ItemTypeAttrWeight = 23,   // deprecated
    ItemTypeAttrWeapon = 24,   // deprecated
    ItemTypeAttrAmmunition = 25,   // deprecated
    ItemTypeAttrArmor = 26,   // deprecated
    ItemTypeAttrMagicLevel = 27,   // deprecated
    ItemTypeAttrMagicField = 28,   // deprecated
    ItemTypeAttrWritable = 29,   // deprecated
    ItemTypeAttrRotateTo = 30,   // deprecated
    ItemTypeAttrDecay = 31,   // deprecated
    ItemTypeAttrSpriteHash = 32,
    ItemTypeAttrMinimapColor = 33,
    ItemTypeAttr07 = 34,
    ItemTypeAttr08 = 35,
    ItemTypeAttrLight = 36,
    ItemTypeAttrDecay2 = 37,   // deprecated
    ItemTypeAttrWeapon2 = 38,   // deprecated
    ItemTypeAttrAmmunition2 = 39,   // deprecated
    ItemTypeAttrArmor2 = 40,   // deprecated
    ItemTypeAttrWritable2 = 41,   // deprecated
    ItemTypeAttrLight2 = 42,
    ItemTypeAttrTopOrder = 43,
    ItemTypeAttrWrtiable3 = 44,   // deprecated
    ItemTypeAttrWareId = 45,
    ItemTypeAttrLast = 46
};

enum ItemCategory : uint8_t
{
    ItemCategoryInvalid = 0,
    ItemCategoryGround = 1,
    ItemCategoryContainer = 2,
    ItemCategoryWeapon = 3,
    ItemCategoryAmmunition = 4,
    ItemCategoryArmor = 5,
    ItemCategoryCharges = 6,
    ItemCategoryTeleport = 7,
    ItemCategoryMagicField = 8,
    ItemCategoryWritable = 9,
    ItemCategoryKey = 10,
    ItemCategorySplash = 11,
    ItemCategoryFluid = 12,
    ItemCategoryDoor = 13,
    ItemCategoryDeprecated = 14
};

enum ClientVersion
{
    ClientVersion750 = 1,
    ClientVersion755 = 2,
    ClientVersion760 = 3,
    ClientVersion770 = 3,
    ClientVersion780 = 4,
    ClientVersion790 = 5,
    ClientVersion792 = 6,
    ClientVersion800 = 7,
    ClientVersion810 = 8,
    ClientVersion811 = 9,
    ClientVersion820 = 10,
    ClientVersion830 = 11,
    ClientVersion840 = 12,
    ClientVersion841 = 13,
    ClientVersion842 = 14,
    ClientVersion850 = 15,
    ClientVersion854_OLD = 16,
    ClientVersion854 = 17,
    ClientVersion855 = 18,
    ClientVersion860_OLD = 19,
    ClientVersion860 = 20,
    ClientVersion861 = 21,
    ClientVersion862 = 22,
    ClientVersion870 = 23,
    ClientVersion871 = 24,
    ClientVersion872 = 25,
    ClientVersion873 = 26,
    ClientVersion900 = 27,
    ClientVersion910 = 28,
    ClientVersion920 = 29,
    ClientVersion940 = 30,
    ClientVersion944_V1 = 31,
    ClientVersion944_V2 = 32,
    ClientVersion944_V3 = 33,
    ClientVersion944_V4 = 34,
    ClientVersion946 = 35,
    ClientVersion950 = 36,
    ClientVersion952 = 37,
    ClientVersion953 = 38,
    ClientVersion954 = 39,
    ClientVersion960 = 40,
    ClientVersion961 = 41
};

enum OTBM_NodeTypes_t
{
    OTBM_ROOTV2 = 1,
    OTBM_MAP_DATA = 2,
    OTBM_ITEM_DEF = 3,
    OTBM_TILE_AREA = 4,
    OTBM_TILE = 5,
    OTBM_ITEM = 6,
    OTBM_TILE_SQUARE = 7,
    OTBM_TILE_REF = 8,
    OTBM_SPAWNS = 9,
    OTBM_SPAWN_AREA = 10,
    OTBM_MONSTER = 11,
    OTBM_TOWNS = 12,
    OTBM_TOWN = 13,
    OTBM_HOUSETILE = 14,
    OTBM_WAYPOINTS = 15,
    OTBM_WAYPOINT = 16
};

enum OTBM_ItemAttr
{
    OTBM_ATTR_DESCRIPTION = 1,
    OTBM_ATTR_EXT_FILE = 2,
    OTBM_ATTR_TILE_FLAGS = 3,
    OTBM_ATTR_ACTION_ID = 4,
    OTBM_ATTR_UNIQUE_ID = 5,
    OTBM_ATTR_TEXT = 6,
    OTBM_ATTR_DESC = 7,
    OTBM_ATTR_TELE_DEST = 8,
    OTBM_ATTR_ITEM = 9,
    OTBM_ATTR_DEPOT_ID = 10,
    OTBM_ATTR_SPAWN_FILE = 11,
    OTBM_ATTR_RUNE_CHARGES = 12,
    OTBM_ATTR_HOUSE_FILE = 13,
    OTBM_ATTR_HOUSEDOORID = 14,
    OTBM_ATTR_COUNT = 15,
    OTBM_ATTR_DURATION = 16,
    OTBM_ATTR_DECAYING_STATE = 17,
    OTBM_ATTR_WRITTENDATE = 18,
    OTBM_ATTR_WRITTENBY = 19,
    OTBM_ATTR_SLEEPERGUID = 20,
    OTBM_ATTR_SLEEPSTART = 21,
    OTBM_ATTR_CHARGES = 22,
    OTBM_ATTR_CONTAINER_ITEMS = 23,
    OTBM_ATTR_ATTRIBUTE_MAP = 128,
    /// just random numbers, they're not actually used by the binary reader...
    OTBM_ATTR_WIDTH = 129,
    OTBM_ATTR_HEIGHT = 130
};

#endif

enum class TileSelectType : uint8_t
{
    NONE, FILTERED, NO_FILTERED
};

enum TileThingType : uint32_t
{
    FULL_GROUND = 1 << 0,
    NOT_WALKABLE = 1 << 1,
    NOT_PATHABLE = 1 << 2,
    NOT_SINGLE_DIMENSION = 1 << 3,
    BLOCK_PROJECTTILE = 1 << 4,
    HAS_DISPLACEMENT = 1 << 5,
    IS_NOT_PATHAB = 1 << 6,
    ELEVATION = 1 << 7,
    // IS_OPAQUE = 1 << 8,
    HAS_LIGHT = 1 << 9,
    HAS_TALL_THINGS = 1 << 10,
    HAS_WIDE_THINGS = 1 << 11,
    HAS_TALL_THINGS_2 = 1 << 12,
    HAS_WIDE_THINGS_2 = 1 << 13,
    HAS_WALL = 1 << 14,
    HAS_HOOK_EAST = 1 << 15,
    HAS_HOOK_SOUTH = 1 << 16,
    HAS_CREATURE = 1 << 17,
    HAS_COMMON_ITEM = 1 << 18,
    HAS_TOP_ITEM = 1 << 19,
    HAS_BOTTOM_ITEM = 1 << 20,
    HAS_GROUND_BORDER = 1 << 21,
    HAS_TOP_GROUND_BORDER = 1 << 22,
    HAS_THING_WITH_ELEVATION = 1 << 23,
    IGNORE_LOOK = 1 << 24,
    CORRECT_CORPSE = 1 << 25
};

enum
{
    OTCM_SIGNATURE = 0x4D43544F,
    OTCM_VERSION = 1
};

enum
{
    BLOCK_SIZE = 32
};

enum : uint8_t
{
    Animation_Force,
    Animation_Show
};
