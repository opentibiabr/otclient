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

#include "global.h"

namespace Proto
{
    enum LoginServerOpts
    {
        LoginServerError = 10,
        LoginServerMotd = 20,
        LoginServerUpdateNeeded = 30,
        LoginServerCharacterList = 100
    };

    enum ItemOpcode
    {
        StaticText = 96,
        UnknownCreature = 97,
        OutdatedCreature = 98,
        Creature = 99
    };

    enum GameServerOpcodes : uint8_t
    {
        GameServerLoginOrPendingState = 10,
        GameServerGMActions = 11,
        GameServerEnterGame = 15,
        GameServerUpdateNeeded = 17,
        GameServerLoginError = 20,
        GameServerLoginAdvice = 21,
        GameServerLoginWait = 22,
        GameServerLoginSuccess = 23,
        GameServerSessionEnd = 24,
        GameServerStoreButtonIndicators = 25,
        GameServerBugReport = 26,
        GameServerPingBack = 29,
        GameServerPing = 30,
        GameServerChallenge = 31,
        GameServerDeath = 40,
        GameServerSupplyStash = 41,
        GameServerSpecialContainer = 42,
        GameServerPartyAnalyzer = 43,

        // all in game opcodes must be greater than 50
        GameServerFirstGameOpcode = 50,

        // otclient ONLY
        GameServerExtendedOpcode = 50,

        // NOTE: add any custom opcodes in this range
        // 51 - 99
        GameServerChangeMapAwareRange = 51,
        GameServerAttchedEffect = 52,
        GameServerDetachEffect = 53,
        GameServerCreatureShader = 54,
        GameServerMapShader = 55,
        GameServerCreatureTyping = 56,
        GameServerAttachedPaperdoll = 60,
        GameServerDetachPaperdoll = 61,
        GameServerFeatures = 67,
        GameServerFloorDescription = 75,

        // original tibia ONLY
        GameServerWeaponProficiencyExperience = 92,
        GameServerImbuementDurations = 93,
        GameServerPassiveCooldown = 94,
        GameServerOpenWheelWindow = 95, // 0x5F
        GameServerBosstiaryData = 97,
        GameServerBosstiarySlots = 98,
        GameServerSendClientCheck = 99,
        GameServerFullMap = 100,
        GameServerMapTopRow = 101,
        GameServerMapRightRow = 102,
        GameServerMapBottomRow = 103,
        GameServerMapLeftRow = 104,
        GameServerUpdateTile = 105,
        GameServerCreateOnMap = 106,
        GameServerChangeOnMap = 107,
        GameServerDeleteOnMap = 108,
        GameServerMoveCreature = 109,
        GameServerOpenContainer = 110,
        GameServerCloseContainer = 111,
        GameServerCreateContainer = 112,
        GameServerChangeInContainer = 113,
        GameServerDeleteInContainer = 114,
        GameServerBosstiaryInfo = 115,
        GameServerTakeScreenshot = 117,
        GameServerCyclopediaItemDetail = 118,
        GameServerSetInventory = 120,
        GameServerDeleteInventory = 121,
        GameServerOpenNpcTrade = 122,
        GameServerPlayerGoods = 123,
        GameServerCloseNpcTrade = 124,
        GameServerOwnTrade = 125,
        GameServerCounterTrade = 126,
        GameServerCloseTrade = 127,
        GameServerAmbient = 130,
        GameServerGraphicalEffect = 131,
        GameServerTextEffect = 132,
        GameServerMissleEffect = 133, // Anthem on 13.x
        GameServerItemClasses = 134,
        GameServerTrappers = 135, // GameServerOpenForge = 135,
        GameServerBrowseForgeHistory = 136,
        GameServerCloseForgeWindow = 137,
        GameServerForgeResult = 138,
        GameServerCreatureData = 139,
        GameServerCreatureHealth = 140,
        GameServerCreatureLight = 141,
        GameServerCreatureOutfit = 142,
        GameServerCreatureSpeed = 143,
        GameServerCreatureSkull = 144,
        GameServerCreatureParty = 145,
        GameServerCreatureUnpass = 146,
        GameServerCreatureMarks = 147,
        GameServerPlayerHelpers = 148,
        GameServerCreatureType = 149,
        GameServerEditText = 150,
        GameServerEditList = 151,
        GameServerSendGameNews = 152,
        GameServerSendBlessDialog = 155,
        GameServerBlessings = 156,
        GameServerPreset = 157,
        GameServerPremiumTrigger = 158,
        GameServerPlayerDataBasic = 159,
        GameServerPlayerData = 160,
        GameServerPlayerSkills = 161,
        GameServerPlayerState = 162,
        GameServerClearTarget = 163,
        GameServerSpellDelay = 164,
        GameServerSpellGroupDelay = 165,
        GameServerMultiUseDelay = 166,
        GameServerPlayerModes = 167,
        GameServerSetStoreDeepLink = 168,
        GameServerSendRestingAreaState = 169,
        GameServerTalk = 170,
        GameServerChannels = 171,
        GameServerOpenChannel = 172,
        GameServerOpenPrivateChannel = 173,
        GameServerRuleViolationChannel = 174,
        GameServerRuleViolationRemove = 175,
        GameServerRuleViolationCancel = 176,
        GameServerRuleViolationLock = 177,
        GameServerOpenOwnChannel = 178,
        GameServerCloseChannel = 179,
        GameServerTextMessage = 180,
        GameServerCancelWalk = 181,
        GameServerWalkWait = 182,
        GameServerUnjustifiedStats = 183,
        GameServerPvpSituations = 184,
        GameServerBestiaryRefreshTracker = 185,
        GameServerTaskHuntingBasicData = 186,
        GameServerTaskHuntingData = 187,
        GameServerBosstiaryCooldownTimer = 189,
        GameServerFloorChangeUp = 190,
        GameServerFloorChangeDown = 191,
        GameServerLootContainers = 192,
        GameServerMonkData = 193,
        GameServerCyclopediaHouseAuctionMessage = 195,
        GameServerWeaponProficiencyInfo = 196,
        GameServerCyclopediaHousesInfo = 198,
        GameServerCyclopediaHouseList = 199,
        GameServerChooseOutfit = 200,
        GameServerSendUpdateImpactTracker = 204,
        GameServerSendItemsPrice = 205,
        GameServerSendUpdateSupplyTracker = 206,
        GameServerSendUpdateLootTracker = 207,
        GameServerQuestTracker = 208,
        GameServerKillTracker = 209,
        GameServerVipAdd = 210,
        GameServerVipState = 211,
        GameServerVipLogout = 212,
        GameServerBestiaryRaces = 213,
        GameServerBestiaryOverview = 214,
        GameServerBestiaryMonsterData = 215,
        GameServerBestiaryCharmsData = 216,
        GameServerBestiaryEntryChanged = 217,
        GameServerCyclopediaCharacterInfoData = 218,
        GameServerTutorialHint = 220,
        GameServerAutomapFlag = 221,
        GameServerSendDailyRewardCollectionState = 222,
        GameServerCoinBalance = 223,
        GameServerStoreError = 224,
        GameServerRequestPurchaseData = 225,
        GameServerSendOpenRewardWall = 226,
        GameServerSendDailyReward = 228,
        GameServerSendRewardHistory = 229,
        GameServerSendPreyFreeRerolls = 230, // GameServerSendBosstiaryEntryChanged = 230,
        GameServerSendPreyTimeLeft = 231,
        GameServerSendPreyData = 232,
        GameServerSendPreyRerollPrice = 233,
        GameServerSendShowDescription = 234,
        GameServerSendImbuementWindow = 235,
        GameServerSendCloseImbuementWindow = 236,
        GameServerSendError = 237,
        GameServerResourceBalance = 238,
        GameServerWorldTime = 239,
        GameServerQuestLog = 240,
        GameServerQuestLine = 241,
        GameServerCoinBalanceUpdating = 242,
        GameServerChannelEvent = 243,
        GameServerItemInfo = 244,
        GameServerPlayerInventory = 245,
        GameServerMarketEnter = 246,
        GameServerMarketLeave = 247,
        GameServerMarketDetail = 248,
        GameServerMarketBrowse = 249,
        GameServerModalDialog = 250,
        GameServerStore = 251,
        GameServerStoreOffers = 252,
        GameServerStoreTransactionHistory = 253,
        GameServerStoreCompletePurchase = 254
    };

    enum ClientOpcodes : uint8_t
    {
        ClientEnterAccount = 1,
        ClientPendingGame = 10,
        ClientEnterGame = 15,
        ClientLeaveGame = 20,
        ClientPing = 29,
        ClientPingBack = 30,
        ClientUseStash = 40,
        ClientBestiaryTrackerStatus = 42,
        ClientPartyAnalyzerAction = 43,

        // all in game opcodes must be equal or greater than 50
        ClientFirstGameOpcode = 50,

        // otclient ONLY
        ClientExtendedOpcode = 50,
        ClientChangeMapAwareRange = 51,

        // NOTE: add any custom opcodes in this range
        // 51 - 99

        // original tibia ONLY
        ClientImbuementDurations = 96,
        ClientOpenWheel = 97, // server received 0x61
        ClientSaveWheel = 98, // server received 0x62
        ClientAutoWalk = 100,
        ClientWalkNorth = 101,
        ClientWalkEast = 102,
        ClientWalkSouth = 103,
        ClientWalkWest = 104,
        ClientStop = 105,
        ClientWalkNorthEast = 106,
        ClientWalkSouthEast = 107,
        ClientWalkSouthWest = 108,
        ClientWalkNorthWest = 109,
        ClientTurnNorth = 111,
        ClientTurnEast = 112,
        ClientTurnSouth = 113,
        ClientTurnWest = 114,
        ClientGmTeleport = 115,
        ClientEquipItem = 119,
        ClientMove = 120,
        ClientInspectNpcTrade = 121,
        ClientBuyItem = 122,
        ClientSellItem = 123,
        ClientCloseNpcTrade = 124,
        ClientRequestTrade = 125,
        ClientInspectTrade = 126,
        ClientAcceptTrade = 127,
        ClientRejectTrade = 128,
        ClientUseItem = 130,
        ClientUseItemWith = 131,
        ClientUseOnCreature = 132,
        ClientRotateItem = 133,
        ClientCloseContainer = 135,
        ClientUpContainer = 136,
        ClientEditText = 137,
        ClientEditList = 138,
        ClientOnWrapItem = 139,
        ClientLook = 140,
        ClientLookCreature = 141,
        ClientSendQuickLoot = 143,
        ClientLootContainer = 144,
        ClientQuickLootBlackWhitelist = 145,
        ClientTalk = 150,
        ClientRequestChannels = 151,
        ClientJoinChannel = 152,
        ClientLeaveChannel = 153,
        ClientOpenPrivateChannel = 154,
        ClientOpenRuleViolation = 155,
        ClientCloseRuleViolation = 156,
        ClientCancelRuleViolation = 157,
        ClientCloseNpcChannel = 158,
        ClientChangeFightModes = 160,
        ClientAttack = 161,
        ClientFollow = 162,
        ClientInviteToParty = 163,
        ClientJoinParty = 164,
        ClientRevokeInvitation = 165,
        ClientPassLeadership = 166,
        ClientLeaveParty = 167,
        ClientShareExperience = 168,
        ClientDisbandParty = 169,
        ClientOpenOwnChannel = 170,
        ClientInviteToOwnChannel = 171,
        ClientExcludeFromOwnChannel = 172,
        ClientCyclopediaHouseAuction = 173,
        ClientBosstiaryRequestInfo = 174,
        ClientBosstiaryRequestSlotInfo = 175,
        ClientBosstiaryRequestSlotAction = 176,
        ClientRequestHighscore = 177,
        ClientCancelAttackAndFollow = 190,
        ClientForgeEnter = 191,
        ClientForgeBrowseHistory = 192,
        ClientUpdateTile = 201,
        ClientRefreshContainer = 202,
        ClientBrowseField = 203,
        ClientSeekInContainer = 204,
        ClientInspectionObject = 205,
        ClientRequestBless = 207,
        ClientRequestTrackerQuestLog = 208,
        ClientRequestOutfit = 210,
        ClientChangeOutfit = 211,
        ClientMount = 212,
        ClientApplyImbuement = 213,
        ClientClearImbuement = 214,
        ClientCloseImbuingWindow = 215,
        ClientOpenRewardWall = 216,
        ClientOpenRewardHistory = 217,
        sendGetRewardDaily = 218,
        ClientAddVip = 220,
        ClientRemoveVip = 221,
        ClientEditVip = 222,
        ClientEditVipGroups = 223,
        ClientBestiaryRequest = 225,
        ClientBestiaryRequestOverview = 226,
        ClientBestiaryRequestSearch = 227,
        ClientCyclopediaSendBuyCharmRune = 228,
        ClientCyclopediaRequestCharacterInfo = 229,
        ClientBugReport = 230,
        ClientWheelGemAction = 231, // 0xE7 usado em gemas, desabilitado para ClientRuleViolation = 231
        ClientDebugReport = 232,
        ClientPreyAction = 235,
        ClientPreyRequest = 237,
        ClientTransferCoins = 239,
        ClientRequestQuestLog = 240,
        ClientRequestQuestLine = 241,
        ClientNewRuleViolation = 242,
        ClientRequestItemInfo = 243,
        ClientMarketLeave = 244,
        ClientMarketBrowse = 245,
        ClientMarketCreate = 246,
        ClientMarketCancel = 247,
        ClientMarketAccept = 248,
        ClientAnswerModalDialog = 249,
        ClientOpenStore = 250,
        ClientRequestStoreOffers = 251,
        ClientBuyStoreOffer = 252,
        ClientOpenTransactionHistory = 253,
        ClientRequestTransactionHistory = 254
    };

    enum CreatureType
    {
        CreatureTypePlayer = 0,
        CreatureTypeMonster,
        CreatureTypeNpc,
        CreatureTypeSummonOwn,
        CreatureTypeSummonOther,
        CreatureTypeHidden,
        CreatureTypeUnknown = 0xFF
    };

    enum CreaturesIdRange
    {
        PlayerStartId = 0x10000000,
        PlayerEndId = 0x40000000,
        MonsterStartId = 0x40000000,
        MonsterEndId = 0x80000000,
        NpcStartId = 0x80000000,
        NpcEndId = 0xffffffff
    };

    void buildMessageModesMap(int version);
    Otc::MessageMode translateMessageModeFromServer(uint8_t mode);
    uint8_t translateMessageModeToServer(Otc::MessageMode mode);
}
