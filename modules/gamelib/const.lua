-- @docconsts @{
FloorHigher = 0
FloorLower = 15

SkullNone = 0
SkullYellow = 1
SkullGreen = 2
SkullWhite = 3
SkullRed = 4
SkullBlack = 5
SkullOrange = 6

ShieldNone = 0
ShieldWhiteYellow = 1
ShieldWhiteBlue = 2
ShieldBlue = 3
ShieldYellow = 4
ShieldBlueSharedExp = 5
ShieldYellowSharedExp = 6
ShieldBlueNoSharedExpBlink = 7
ShieldYellowNoSharedExpBlink = 8
ShieldBlueNoSharedExp = 9
ShieldYellowNoSharedExp = 10
ShieldGray = 11

EmblemNone = 0
EmblemGreen = 1
EmblemRed = 2
EmblemBlue = 3
EmblemMember = 4
EmblemOther = 5

VipIconFirst = 0
VipIconLast = 10

Directions = {
    North = 0,
    East = 1,
    South = 2,
    West = 3,
    NorthEast = 4,
    SouthEast = 5,
    SouthWest = 6,
    NorthWest = 7,
    Invalid = 8
}

Skill = {
    Fist = 0,
    Club = 1,
    Sword = 2,
    Axe = 3,
    Distance = 4,
    Shielding = 5,
    Fishing = 6,
    CriticalChance = 7,
    CriticalDamage = 8,
    LifeLeechChance = 9,
    LifeLeechAmount = 10,
    ManaLeechChance = 11,
    ManaLeechAmount = 12,
    Fatal = 13,
    Dodge = 14,
    Momentum = 15,
    Transcendence = 16
}

North = Directions.North
East = Directions.East
South = Directions.South
West = Directions.West
NorthEast = Directions.NorthEast
SouthEast = Directions.SouthEast
SouthWest = Directions.SouthWest
NorthWest = Directions.NorthWest

DirectionString = {
    [North] = "North",
    [East] = "East",
    [South] = "South",
    [West] = "West",
    [NorthEast] = "North East",
    [SouthEast] = "South East",
    [SouthWest] = "South West",
    [NorthWest] = "North West"
}

FightOffensive = 1
FightBalanced = 2
FightDefensive = 3

DontChase = 0
ChaseOpponent = 1

PVPWhiteDove = 0
PVPWhiteHand = 1
PVPYellowHand = 2
PVPRedFist = 3

GameProtocolChecksum = 1
GameAccountNames = 2
GameChallengeOnLogin = 3
GamePenalityOnDeath = 4
GameNameOnNpcTrade = 5
GameDoubleFreeCapacity = 6
GameDoubleExperience = 7
GameTotalCapacity = 8
GameSkillsBase = 9
GamePlayerRegenerationTime = 10
GameChannelPlayerList = 11
GamePlayerMounts = 12
GameEnvironmentEffect = 13
GameCreatureEmblems = 14
GameItemAnimationPhase = 15
GameMagicEffectU16 = 16
GamePlayerMarket = 17
GameSpritesU32 = 18
GameChargeableItems = 19
GameOfflineTrainingTime = 20
GamePurseSlot = 21
GameFormatCreatureName = 22
GameSpellList = 23
GameClientPing = 24
GameExtendedClientPing = 25
GameDoubleHealth = 28
GameDoubleSkills = 29
GameChangeMapAwareRange = 30
GameMapMovePosition = 31
GameAttackSeq = 32
GameBlueNpcNameColor = 33
GameDiagonalAnimatedText = 34
GameLoginPending = 35
GameNewSpeedLaw = 36
GameForceFirstAutoWalkStep = 37
GameMinimapRemove = 38
GameDoubleShopSellAmount = 39
GameContainerPagination = 40
GameThingMarks = 41
GameLooktypeU16 = 42
GamePlayerStamina = 43
GamePlayerAddons = 44
GameMessageStatements = 45
GameMessageLevel = 46
GameNewFluids = 47
GamePlayerStateU16 = 48
GameNewOutfitProtocol = 49
GamePVPMode = 50
GameWritableDate = 51
GameAdditionalVipInfo = 52
GameBaseSkillU16 = 53
GameCreatureIcons = 54
GameHideNpcNames = 55
GameSpritesAlphaChannel = 56
GamePremiumExpiration = 57
GameBrowseField = 58
GameEnhancedAnimations = 59
GameOGLInformation = 60
GameMessageSizeCheck = 61
GamePreviewState = 62
GameLoginPacketEncryption = 63
GameClientVersion = 64
GameContentRevision = 65
GameExperienceBonus = 66
GameAuthenticator = 67
GameUnjustifiedPoints = 68
GameSessionKey = 69
GameDeathType = 70
GameIdleAnimations = 71
GameKeepUnawareTiles = 72
GameIngameStore = 73
GameIngameStoreHighlights = 74
GameIngameStoreServiceType = 75
GameAdditionalSkills = 76
GameDistanceEffectU16 = 77
GameLevelU16 = 78
GameSoul = 79
GameMapOldEffectRendering = 80
GameMapDontCorrectCorpse = 81
GamePrey = 82
GameThingQuickLoot = 83
GameThingQuiver = 84
GameThingPodium = 85
GameThingUpgradeClassification = 86
GameThingCounter = 87
GameThingClock = 88
GameThingPodiumItemType = 89
GameSequencedPackets = 90
GameUshortSpell = 91
GameTournamentPackets = 92
GameDynamicForgeVariables = 93
GameConcotions = 94
GameAnthem = 95
GameVipGroups = 96
GameBosstiary = 97
GameDoublePlayerGoodsMoney = 98
GameLoadSprInsteadProtobuf = 100
GameItemShader = 101
GameCreatureShader = 102
GameCreatureAttachedEffect = 103
GameCountU16 = 104
GameEffectU16 = 105
GameContainerTypes = 106
GameBosstiaryTracker = 107
GamePlayerStateCounter = 108
GameLeechAmount = 109
GameItemAugment = 110
GameDynamicBugReporter = 111
GameWrapKit = 112
GameContainerFilter = 113
GameEnterGameShowAppearance = 114
GameSmoothWalkElevation = 115
GameNegativeOffset = 116
GameItemTooltipV8 = 117
GameWingsAurasEffectsShader = 118
GameForgeConvergence = 119
GameAllowCustomBotScripts = 120
GameColorizedLootValue = 121
GameAllowPreWalk = 122
GamePlayerFamiliars = 123
GameTileAddThingWithStackpos = 124
GameMapCache = 125
GameForgeSkillStats = 126
GameCharacterSkillStats = 127
GameCreaturePaperdoll = 128
GameMultiSpr = 129
GameVocationMonk = 130

TextColors = {
    red = '#f55e5e',    -- '#c83200'
    orange = '#f36500', -- '#c87832'
    yellow = '#ffff00', -- '#e6c832'
    green = '#00EB00',  -- '#3fbe32'
    lightblue = '#5ff7f7',
    blue = '#9f9dfd',
    -- blue1     = '#6e50dc',
    -- blue2     = '#3264c8',
    -- blue3     = '#0096c8',
    white = '#ffffff', -- '#bebebe'
    grey = '#AAAAAA'
}

MessageModes = {
    None = 0,
    Say = 1,
    Whisper = 2,
    Yell = 3,
    PrivateFrom = 4,
    PrivateTo = 5,
    ChannelManagement = 6,
    Channel = 7,
    ChannelHighlight = 8,
    Spell = 9,
    NpcFrom = 10,
    NpcTo = 11,
    GamemasterBroadcast = 12,
    GamemasterChannel = 13,
    GamemasterPrivateFrom = 14,
    GamemasterPrivateTo = 15,
    Login = 16,
    Warning = 17,
    Game = 18,
    Failure = 19,
    Look = 20,
    DamageDealed = 21,
    DamageReceived = 22,
    Heal = 23,
    Exp = 24,
    DamageOthers = 25,
    HealOthers = 26,
    ExpOthers = 27,
    Status = 28,
    Loot = 29,
    TradeNpc = 30,
    Guild = 31,
    PartyManagement = 32,
    Party = 33,
    BarkLow = 34,
    BarkLoud = 35,
    Report = 36,
    HotkeyUse = 37,
    TutorialHint = 38,
    Thankyou = 39,
    Market = 40,
    Mana = 41,
    BeyondLast = 42,
    MonsterYell = 43,
    MonsterSay = 44,
    Red = 45,
    Blue = 46,
    RVRChannel = 47,
    RVRAnswer = 48,
    RVRContinue = 49,
    GameHighlight = 50,
    NpcFromStartBlock = 51,

    -- 12x
    Attention = 52,
    BoostedCreature = 53,
    OfflineTrainning = 54,
    Transaction = 55,
    Potion = 56,
    ValuableLoot = 57,

    Last = 58,
    Invalid = 255
}

OTSERV_RSA = '1091201329673994292788609605089955415282375029027981291234687579' ..
    '3726629149257644633073969600111060390723088861007265581882535850' ..
    '3429057592827629436413108566029093628212635953836686562675849720' ..
    '6207862794310902180176810615217550567108238764764442605581471797' ..
    '07119674283982419152118103759076030616683978566631413'

CIPSOFT_RSA = '1321277432058722840622950990822933849527763264961655079678763618' ..
    '4334395343554449668205332383339435179772895415509701210392836078' ..
    '6959821132214473291575712138800495033169914814069637740318278150' ..
    '2907336840325241747827401343576296990629870233111328210165697754' ..
    '88792221429527047321331896351555606801473202394175817'

-- set to the latest Tibia.pic signature to make otclient compatible with official tibia
PIC_SIGNATURE = 0x56C5DDE7

OsTypes = {
    Linux = 1,
    Windows = 2,
    Flash = 3,
    OtclientLinux = 10,
    OtclientWindows = 11,
    OtclientMac = 12
}

PathFindResults = {
    Ok = 0,
    Position = 1,
    Impossible = 2,
    TooFar = 3,
    NoWay = 4
}

PathFindFlags = {
    AllowNullTiles = 1,
    AllowCreatures = 2,
    AllowNonPathable = 4,
    AllowNonWalkable = 8
}

VipState = {
    Offline = 0,
    Online = 1,
    Pending = 2
}

ExtendedIds = {
    Activate = 0,
    Locale = 1,
    Ping = 2,
    Sound = 3,
    Game = 4,
    Particles = 5,
    MapShader = 6,
    NeedsUpdate = 7
}

PreviewState = {
    Default = 0,
    Inactive = 1,
    Active = 2
}

Blessings = {
    None = 0,
    Adventurer = 1,
    SpiritualShielding = 2,
    EmbraceOfTibia = 4,
    FireOfSuns = 8,
    WisdomOfSolitude = 16,
    SparkOfPhoenix = 32
}

DeathType = {
    Regular = 0,
    Blessed = 1
}

ProductType = {
    Other = 0,
    NameChange = 1
}

StoreErrorType = {
    NoError = -1,
    PurchaseError = 0,
    NetworkError = 1,
    HistoryError = 2,
    TransferError = 3,
    Information = 4
}

StoreState = {
    None = 0,
    New = 1,
    Sale = 2,
    Timed = 3
}

AccountStatus = {
    Ok = 0,
    Frozen = 1,
    Suspended = 2
}

SubscriptionStatus = {
    Free = 0,
    Premium = 1
}

ChannelEvent = {
    Join = 0,
    Leave = 1,
    Invite = 2,
    Exclude = 3
}

ResourceTypes = {
    BANK_BALANCE = 0,
    GOLD_EQUIPPED = 1,
    CURRENCY_CUSTOM_EQUIPPED = 2,
    PREY_WILDCARDS = 10,
    DAILYREWARD_STREAK = 20,
    DAILYREWARD_JOKERS = 21,
    CHARM = 30,
    MINOR_CHARM = 31,
    MAX_CHARM = 32,
    MAX_MINOR_CHARM = 33,
    TASK_HUNTING = 50,
    FORGE_DUST = 70,
    FORGE_SLIVER = 71,
    FORGE_CORES = 72,
    LESSER_GEMS = 81,
    REGULAR_GEMS = 82,
    GREATER_GEMS = 83,
    LESSER_FRAGMENTS = 84,
    GREATER_FRAGMENTS = 85,
    WHEEL_OF_DESTINY = 86,
    COIN_NORMAL = 90,
    COIN_TRANSFERRABLE = 91,
    COIN_AUCTION = 92,
    COIN_TOURNAMENT = 93
}

CyclopediaCharacterInfoTypes = {
    BaseInformation = 0,
    GeneralStats = 1,
    CombatStats = 2,
    RecentDeaths = 3,
    RecentPVPKills = 4,
    Achievements = 5,
    ItemSummary = 6,
    OutfitsAndMounts = 7,
    StoreSummary = 8,
    Ispection = 9,
    Badges = 10,
    Titles = 11,
    Wheel = 12,
    Offencestats = 13,
    Defencestats = 14,
    Miscstats = 15
}

StoreConst = {
    InstantRewardAccess = 233,
}

ExperienceRate = {
    BASE = 0,
    VOUCHER = 1,
    LOW_LEVEL = 2,
    XP_BOOST = 3,
    STAMINA_MULTIPLIER = 4
}

PriceTypeEnum = {
    Market = 0,
    Leader = 1
}

-- Analyzer constants
ANALYZER_HEAL = 0
ANALYZER_DAMAGE_DEALT = 1
ANALYZER_DAMAGE_RECEIVED = 2
-- Party Analyser constants
PARTYANALYZERACTION_RESET = 0
PARTYANALYZERACTION_PRICETYPE = 1
PARTYANALYZERACTION_PRICEVALUE = 2

-- @}

FlipDirection = {
    None = 0,
    Horizontal = 1,
    Vertical = 2,
}
