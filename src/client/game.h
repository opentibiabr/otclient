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

#include "declarations.h"
#include "protocolgame.h"
#include "staticdata.h"

#include "framework/core/declarations.h"

 //@bindsingleton g_game
class Game
{
public:
    void init();
    void terminate();

private:
    void resetGameStates();

protected:
    void processConnectionError(const std::error_code& ec);
    void processDisconnect();
    void processPing();
    void processPingBack();

    static void processUpdateNeeded(std::string_view signature);
    static void processLoginError(std::string_view error);
    static void processLoginAdvice(std::string_view message);
    static void processLoginWait(std::string_view message, uint8_t time);
    static void processSessionEnd(uint8_t reason);
    static void processLogin();
    void processPendingGame();
    void processEnterGame();

    void processGameStart();
    void processGameEnd();
    void processDeath(uint8_t deathType, uint8_t penality);

    void processGMActions(const std::vector<uint8_t>& actions);
    void processInventoryChange(uint8_t slot, const ItemPtr& item);
    void processAttackCancel(uint32_t seq);
    void processWalkCancel(Otc::Direction direction);

    static void processPlayerHelpers(uint16_t helpers);
    void processPlayerModes(Otc::FightModes fightMode, Otc::ChaseModes chaseMode, bool safeMode, Otc::PVPModes pvpMode);

    // message related
    static void processTextMessage(Otc::MessageMode mode, std::string_view text);
    static void processTalk(std::string_view name, uint16_t level, Otc::MessageMode mode, std::string_view text, uint16_t channelId, const Position& pos);

    // container related
    void processOpenContainer(uint8_t containerId, const ItemPtr& containerItem, std::string_view name, uint8_t capacity, bool hasParent, const std::vector<ItemPtr>& items, bool isUnlocked, bool hasPages, uint16_t containerSize, uint16_t firstIndex);
    void processCloseContainer(uint8_t containerId);
    void processContainerAddItem(uint8_t containerId, const ItemPtr& item, uint16_t slot);
    void processContainerUpdateItem(uint8_t containerId, uint16_t slot, const ItemPtr& item);
    void processContainerRemoveItem(uint8_t containerId, uint16_t slot, const ItemPtr& lastItem);

    // channel related
    static void processChannelList(const std::vector<std::tuple<uint16_t, std::string>>& channelList);
    static void processOpenChannel(uint16_t channelId, std::string_view name);
    static void processOpenPrivateChannel(std::string_view name);
    static void processOpenOwnPrivateChannel(uint16_t channelId, std::string_view name);
    static void processCloseChannel(uint16_t channelId);

    // rule violations
    static void processRuleViolationChannel(uint16_t channelId);
    static void processRuleViolationRemove(std::string_view name);
    static void processRuleViolationCancel(std::string_view name);
    static void processRuleViolationLock();

    // vip related
    void processVipAdd(uint32_t id, std::string_view name, uint32_t status, std::string_view description, uint32_t iconId, bool notifyLogin, const std::vector<uint8_t>& groupID);
    void processVipStateChange(uint32_t id, uint32_t status);
    void processVipGroupChange(const std::vector<std::tuple<uint8_t, std::string, bool>>& vipGroups, uint8_t groupsAmountLeft);

    // tutorial hint
    static void processTutorialHint(uint8_t id);
    static void processAddAutomapFlag(const Position& pos, uint8_t icon, std::string_view message);
    static void processRemoveAutomapFlag(const Position& pos, uint8_t icon, std::string_view message);

    // outfit
    void processOpenOutfitWindow(const Outfit& currentOutfit, const std::vector<std::tuple<uint16_t, std::string, uint8_t, uint8_t>>& outfitList,
                                const std::vector<std::tuple<uint16_t, std::string, uint8_t>>& mountList,
                                const std::vector<std::tuple<uint16_t, std::string>>& familiarList,
                                const std::vector<std::tuple<uint16_t, std::string>>& wingsList,
                                const std::vector<std::tuple<uint16_t, std::string>>& aurasList,
                                const std::vector<std::tuple<uint16_t, std::string>>& effectsList,
                                const std::vector<std::tuple<uint16_t, std::string>>& shaderList);

    // npc trade
    static void processOpenNpcTrade(const std::vector<std::tuple<ItemPtr, std::string, uint32_t, uint32_t, uint32_t>>& items);
    static void processPlayerGoods(uint64_t money, const std::vector<std::tuple<ItemPtr, uint16_t>>& goods);
    static void processCloseNpcTrade();

    // player trade
    static void processOwnTrade(std::string_view name, const std::vector<ItemPtr>& items);
    static void processCounterTrade(std::string_view name, const std::vector<ItemPtr>& items);
    static void processCloseTrade();

    // edit text/list
    static void processEditText(uint32_t id, uint32_t itemId, uint16_t maxLength, std::string_view text, std::string_view writer, std::string_view date);
    static void processEditList(uint32_t id, uint8_t doorId, std::string_view text);

    // questlog
    static void processQuestLog(const std::vector<std::tuple<uint16_t, std::string, bool>>& questList);
    static void processQuestLine(uint16_t questId, const std::vector<std::tuple<std::string, std::string, uint16_t>>& questMissions);

    // modal dialogs >= 970
    static void processModalDialog(uint32_t id, std::string_view title, std::string_view message, const std::vector<std::tuple<uint8_t, std::string>>
                                   & buttonList, uint8_t enterButton, uint8_t escapeButton, const std::vector<std::tuple<uint8_t, std::string>>
                                   & choiceList, bool priority);

    // cyclopedia
    static void processItemDetail(uint32_t itemId, const std::vector<std::tuple<std::string, std::string>>& descriptions);
    static void processCyclopediaCharacterGeneralStats(const CyclopediaCharacterGeneralStats& stats, const std::vector<std::vector<uint16_t>>& skills,
                                                    const std::vector<std::tuple<uint8_t, uint16_t>>& combats);
    static void processCyclopediaCharacterCombatStats(const CyclopediaCharacterCombatStats& data, double mitigation,
                                                    const std::vector<std::vector<uint16_t>>& additionalSkillsArray,
                                                    const std::vector<std::vector<uint16_t>>& forgeSkillsArray, const std::vector<uint16_t>& perfectShotDamageRangesArray,
                                                    const std::vector<std::tuple<uint8_t, uint16_t>>& combatsArray,
                                                    const std::vector<std::tuple<uint16_t, uint16_t>>& concoctionsArray);
    static void processCyclopediaCharacterGeneralStatsBadge(uint8_t showAccountInformation, uint8_t playerOnline, uint8_t playerPremium,
                                                            std::string_view loyaltyTitle,
                                                            const std::vector<std::tuple<uint32_t, std::string>>& badgesVector);
    static void processCyclopediaCharacterItemSummary(const CyclopediaCharacterItemSummary& data);
    static void processCyclopediaCharacterAppearances(const OutfitColorStruct& currentOutfit, const std::vector<CharacterInfoOutfits>& outfits,
                                                    const std::vector<CharacterInfoMounts>& mounts, const std::vector<CharacterInfoFamiliar>& familiars);
    static void processCyclopediaCharacterRecentDeaths(const CyclopediaCharacterRecentDeaths& data);
    static void processCyclopediaCharacterRecentPvpKills(const CyclopediaCharacterRecentPvPKills& data);
    static void processParseBestiaryRaces(const std::vector<CyclopediaBestiaryRace>& bestiaryData);
    static void processParseBestiaryOverview(std::string_view raceName, const std::vector<BestiaryOverviewMonsters>& data, uint16_t animusMasteryPoints);
    static void processUpdateBestiaryMonsterData(const BestiaryMonsterData& data);
    static void processUpdateBestiaryCharmsData(const BestiaryCharmsData& charmData);
    static void processBosstiaryInfo(const std::vector<BosstiaryData>& boss);
    static void processBosstiarySlots(const BosstiarySlotsData& data);

    friend class ProtocolGame;
    friend class Map;

public:
    // login related
    void loginWorld(std::string_view account, std::string_view password, std::string_view worldName, std::string_view worldHost, int worldPort, std::string_view characterName, std::string_view authenticatorToken, std::string_view sessionKey, const std::string_view& recordTo);
    void playRecord(const std::string_view& file);
    void cancelLogin();
    void forceLogout();
    void safeLogout();

    // walk related
    bool walk(Otc::Direction direction);
    void autoWalk(const std::vector<Otc::Direction>& dirs, const Position& startPos);
    void forceWalk(Otc::Direction direction);
    void turn(Otc::Direction direction);
    void stop();

    // item related
    void look(const ThingPtr& thing, bool isBattleList = false);
    void move(const ThingPtr& thing, const Position& toPos, int count);
    void moveToParentContainer(const ThingPtr& thing, int count);
    void rotate(const ThingPtr& thing);
    void wrap(const ThingPtr& thing);
    void use(const ThingPtr& thing);
    void useWith(const ItemPtr& item, const ThingPtr& toThing);
    void useInventoryItem(uint16_t itemId);
    void useInventoryItemWith(uint16_t itemId, const ThingPtr& toThing);
    ItemPtr findItemInContainers(uint32_t itemId, int subType, uint8_t tier);

    // container related
    int open(const ItemPtr& item, const ContainerPtr& previousContainer);
    void openParent(const ContainerPtr& container);
    void close(const ContainerPtr& container);
    void refreshContainer(const ContainerPtr& container);

    // attack/follow related
    void attack(CreaturePtr creature);
    void cancelAttack() { attack(nullptr); }
    void follow(CreaturePtr creature);
    void cancelFollow() { follow(nullptr); }
    void cancelAttackAndFollow();

    // talk related
    void talk(std::string_view message);
    void talkChannel(Otc::MessageMode mode, uint16_t channelId, std::string_view message);
    void talkPrivate(Otc::MessageMode mode, std::string_view receiver, std::string_view message);

    // channel related
    void openPrivateChannel(std::string_view receiver);
    void requestChannels();
    void joinChannel(uint16_t channelId);
    void leaveChannel(uint16_t channelId);
    void closeNpcChannel();
    void openOwnChannel();
    void inviteToOwnChannel(std::string_view name);
    void excludeFromOwnChannel(std::string_view name);

    // party related
    void partyInvite(uint32_t creatureId);
    void partyJoin(uint32_t creatureId);
    void partyRevokeInvitation(uint32_t creatureId);
    void partyPassLeadership(uint32_t creatureId);
    void partyLeave();
    void partyShareExperience(bool active);
    void sendPartyAnalyzerReset();
    void sendPartyAnalyzerPriceType();
    void sendPartyAnalyzerPriceValue(); // For action 3, will get items from cyclopedia
    void sendPartyAnalyzerAction(uint8_t action, const std::vector<std::tuple<uint16_t, uint64_t>>& items = {});

    // outfit related
    void requestOutfit();
    void changeOutfit(const Outfit& outfit);

    void sendTyping(bool typing);

    // vip related
    void addVip(std::string_view name);
    void removeVip(uint32_t playerId);
    void editVip(uint32_t playerId, std::string_view description, uint32_t iconId, bool notifyLogin, const std::vector<uint8_t>& groupID = {});
    void editVipGroups(Otc::GroupsEditInfoType_t action, uint8_t groupId, std::string_view groupName);
    // fight modes related
    void setChaseMode(Otc::ChaseModes chaseMode);
    void setFightMode(Otc::FightModes fightMode);
    void setSafeFight(bool on);
    void setPVPMode(Otc::PVPModes pvpMode);
    Otc::ChaseModes getChaseMode() { return m_chaseMode; }
    Otc::FightModes getFightMode() { return m_fightMode; }
    bool isSafeFight() { return m_safeFight; }
    Otc::PVPModes getPVPMode() { return m_pvpMode; }

    // pvp related
    void setUnjustifiedPoints(UnjustifiedPoints unjustifiedPoints);
    UnjustifiedPoints getUnjustifiedPoints() { return m_unjustifiedPoints; };
    void setOpenPvpSituations(uint8_t openPvpSituations);
    int getOpenPvpSituations() { return m_openPvpSituations; }

    // npc trade related
    void inspectNpcTrade(const ItemPtr& item);
    void buyItem(const ItemPtr& item, uint16_t amount, bool ignoreCapacity, bool buyWithBackpack);
    void sellItem(const ItemPtr& item, uint16_t amount, bool ignoreEquipped);
    void closeNpcTrade();

    // player trade related
    void requestTrade(const ItemPtr& item, const CreaturePtr& creature);
    void inspectTrade(bool counterOffer, uint8_t index);
    void acceptTrade();
    void rejectTrade();

    // house window and editable items related
    void editText(uint32_t id, std::string_view text);
    void editList(uint32_t id, uint8_t doorId, std::string_view text);

    // rule violations (only gms)
    void openRuleViolation(std::string_view reporter);
    void closeRuleViolation(std::string_view reporter);
    void cancelRuleViolation();

    // reports
    void reportBug(std::string_view comment);
    void reportRuleViolation(std::string_view target, uint8_t reason, uint8_t action, std::string_view comment, std::string_view statement, uint16_t statementId, bool ipBanishment);
    void debugReport(std::string_view a, std::string_view b, std::string_view c, std::string_view d);

    // questlog related
    void requestQuestLog();
    void requestQuestLine(uint16_t questId);

    // 870 only
    void equipItem(const ItemPtr& item);
    void equipItemId(const uint16_t itemId, const uint8_t tier);
    void mount(bool mount);

    // 910 only
    void requestItemInfo(const ItemPtr& item, uint8_t index);

    // >= 970 modal dialog
    void answerModalDialog(uint32_t dialog, uint8_t button, uint8_t choice);

    // >= 984 browse field
    void browseField(const Position& position);
    void seekInContainer(uint8_t containerId, uint16_t index);

    // >= 1080 ingame store
    void buyStoreOffer(const uint32_t offerId, const uint8_t action, const std::string_view& name, const uint8_t type, const std::string_view& location);
    void requestTransactionHistory(uint32_t page, uint32_t entriesPerPage);
    void requestStoreOffers(const std::string_view categoryName, const std::string_view subCategory, const uint8_t sortOrder, const uint8_t serviceType);
    void sendRequestStoreHome();
    void sendRequestStorePremiumBoost();
    void sendRequestUsefulThings(const uint8_t serviceType);
    void sendRequestStoreOfferById(const uint32_t offerId, const uint8_t sortOrder, const uint8_t serviceType);
    void sendRequestStoreSearch(const std::string_view searchText, const uint8_t sortOrder, const uint8_t serviceType);
    void openStore(uint8_t serviceType = 0, std::string_view category = "");
    void transferCoins(std::string_view recipient, uint16_t amount);
    void openTransactionHistory(uint8_t entriesPerPage);

    //void reportRuleViolation2();
    void ping();
    void setPingDelay(const int delay) { m_pingDelay = delay; }

    // otclient only
    void changeMapAwareRange(uint8_t xrange, uint8_t yrange);

    // dynamic support for game features
    void enableFeature(const Otc::GameFeature feature) { m_features.set(feature, true); }
    void disableFeature(const Otc::GameFeature feature) { m_features.set(feature, false); }
    void setFeature(const Otc::GameFeature feature, const bool enabled) { m_features.set(feature, enabled); }
    bool getFeature(const Otc::GameFeature feature) { return m_features.test(feature); }

    void setProtocolVersion(uint16_t version);
    int getProtocolVersion() { return m_protocolVersion; }

    bool isUsingProtobuf() { return getProtocolVersion() >= 1281 && !getFeature(Otc::GameLoadSprInsteadProtobuf); }

    void setClientVersion(uint16_t version);
    int getClientVersion() { return m_clientVersion; }

    void setCustomOs(const Otc::OperatingSystem_t os) { m_clientCustomOs = os; }
    Otc::OperatingSystem_t getOs();

    bool canPerformGameAction() const;

    bool isOnline() { return m_online; }
    bool isLogging() { return !m_online && m_protocolGame; }
    bool isDead() { return m_dead; }
    bool isAttacking();
    bool isFollowing();
    bool isConnectionOk();
    auto mapUpdatedAt() const { return m_mapUpdatedAt; }
    void resetMapUpdatedAt() { m_mapUpdatedAt = 0; }

    int getPing() { return m_ping; }
    int getRecivedPacketsCount() { return m_protocolGame ? m_protocolGame->getRecivedPacketsCount() : 0; }
    int getRecivedPacketsSize() { return m_protocolGame ? m_protocolGame->getRecivedPacketsSize() : 0; }
    ContainerPtr getContainer(const int index) { return m_containers[index]; }
    stdext::map<int, ContainerPtr> getContainers() { return m_containers; }
    stdext::map<int, Vip> getVips() { return m_vips; }
    CreaturePtr getAttackingCreature() { return m_attackingCreature; }
    CreaturePtr getFollowingCreature() { return m_followingCreature; }
    void setServerBeat(const int beat) { m_serverBeat = beat; }
    int getServerBeat() { return m_serverBeat; }
    void setCanReportBugs(const bool enable) { m_canReportBugs = enable; }
    bool canReportBugs() { return m_canReportBugs; }
    void setExpertPvpMode(const bool enable) { m_expertPvpMode = enable; }
    bool getExpertPvpMode() { return m_expertPvpMode; }
    LocalPlayerPtr getLocalPlayer() { return m_localPlayer; }
    ProtocolGamePtr getProtocolGame() { return m_protocolGame; }
    std::string getCharacterName() { return m_characterName; }
    std::string getWorldName() { return m_worldName; }
    std::vector<uint8_t > getGMActions() { return m_gmActions; }
    bool isGM() { return !m_gmActions.empty(); }

    std::string formatCreatureName(std::string_view name);
    int findEmptyContainerId();

    // market related
    void leaveMarket();
    void browseMarket(uint8_t browseId, uint16_t browseType, uint8_t tier = 0);
    void createMarketOffer(uint8_t type, uint16_t itemId, uint8_t itemTier, uint16_t amount, uint64_t price, uint8_t anonymous);
    void cancelMarketOffer(uint32_t timestamp, uint16_t counter);
    void acceptMarketOffer(uint32_t timestamp, uint16_t counter, uint16_t amount);

    // prey related
    void preyAction(uint8_t slot, uint8_t actionType, uint16_t index);
    void preyRequest();

    // forge related
    void openPortableForgeRequest();
    void forgeRequest(Otc::ForgeAction_t actionType, bool convergence = false, uint16_t firstItemid = 0, uint8_t firstItemTier = 0, uint16_t secondItemId = 0, bool improveChance = false, bool tierLoss = false);
    void sendForgeBrowseHistoryRequest(uint16_t page);

    // imbuing related
    void applyImbuement(uint8_t slot, uint32_t imbuementId, bool protectionCharm);
    void clearImbuement(uint8_t slot);
    void closeImbuingWindow();
    void imbuementDurations(bool isOpen = false);
    void selectImbuementItem(uint16_t itemId, const Position& pos, uint8_t stackpos);
    void selectImbuementScroll();
    
    void enableTileThingLuaCallback(const bool value) { m_tileThingsLuaCallback = value; }
    bool isTileThingLuaCallbackEnabled() { return m_tileThingsLuaCallback; }

    void stashWithdraw(uint16_t itemId, uint32_t count, uint8_t stackpos);

    void stashStowItem(const Position& position, const uint16_t itemId, const uint32_t count, const uint8_t stackpos, const uint8_t action);

    // highscore related
    void requestHighscore(uint8_t action, uint8_t category, uint32_t vocation, std::string_view world, uint8_t worldType, uint8_t battlEye, uint16_t page, uint8_t totalPages);
    void processHighscore(std::string_view serverName, std::string_view world, uint8_t worldType, uint8_t battlEye,
                          const std::vector<std::tuple<uint32_t, std::string>>& vocations,
                          const std::vector<std::tuple<uint8_t, std::string>>& categories,
                          uint16_t page, uint16_t totalPages,
                          const std::vector<std::tuple<uint32_t, std::string, std::string, uint8_t, std::string, uint16_t, uint8_t, uint64_t>>& highscores, uint32_t entriesTs);

    void requestBless();

    // quickLoot related
    void sendQuickLoot(const uint8_t variant, const ItemPtr& item);
    void requestQuickLootBlackWhiteList(uint8_t filter, uint16_t size, const std::vector<uint16_t>& listedItems);
    void openContainerQuickLoot(uint8_t action, uint8_t category, const Position& pos, uint16_t itemId, uint8_t stackpos, bool useMainAsFallback);

    void sendGmTeleport(const Position& pos);

    // cyclopedia related
    void inspectionNormalObject(const Position& position);
    void inspectionObject(Otc::InspectObjectTypes inspectionType, uint16_t itemId, uint8_t itemCount);
    void requestBestiary();
    void requestBestiaryOverview(std::string_view catName, bool search = false, std::vector<uint16_t> raceIds = {});
    void requestBestiarySearch(uint16_t raceId);
    void requestSendBuyCharmRune(uint8_t runeId, uint8_t action, uint16_t raceId);
    void requestSendCharacterInfo(uint32_t playerId, Otc::CyclopediaCharacterInfoType_t characterInfoType, uint16_t entriesPerPage = 0, uint16_t page = 0);
    void requestSendCyclopediaHouseAuction(Otc::CyclopediaHouseAuctionType_t type, uint32_t houseId, uint32_t timestamp = 0, uint64_t bidValue = 0, std::string_view name = "");
    void requestBosstiaryInfo();
    void requestBossSlootInfo();
    void requestBossSlotAction(uint8_t action, uint32_t raceId);
    void sendStatusTrackerBestiary(uint16_t raceId, bool status);
    void sendOpenRewardWall();
    void requestOpenRewardHistory();
    void requestGetRewardDaily(const uint8_t bonusShrine, const std::map<uint16_t, uint8_t>& items);
    void sendRequestTrackerQuestLog(const std::map<uint16_t, std::string>& quests);
    void processCyclopediaCharacterOffenceStats(const CyclopediaCharacterOffenceStats& data);
    void processCyclopediaCharacterDefenceStats(const CyclopediaCharacterDefenceStats& data);
    void processCyclopediaCharacterMiscStats(const CyclopediaCharacterMiscStats& data);

    //whell of destiny 
    void openWheel(uint32_t playerId);
    void sendApplyWheelPoints(const std::vector<uint16_t>& slotPoints,uint16_t greenGem,uint16_t redGem,uint16_t acquaGem,uint16_t purpleGem);
    void gemAction(uint8_t actionType, uint8_t param, uint8_t pos);
    void openWheelOfDestiny(uint32_t playerId);
    void applyWheelOfDestiny(const std::vector<uint16_t>& wheelPointsVec, const std::vector<uint16_t>& activeGemsVec);

    void updateMapLatency() {
        if (!m_mapUpdateTimer.first) {
            m_mapUpdatedAt = m_mapUpdateTimer.second.ticksElapsed();
            m_mapUpdateTimer.first = true;
        }
    }

    auto getWalkMaxSteps() { return m_walkMaxSteps; }
    void setWalkMaxSteps(uint8_t v) { m_walkMaxSteps = v; }

private:
    void setAttackingCreature(const CreaturePtr& creature);
    void setFollowingCreature(const CreaturePtr& creature);

    LocalPlayerPtr m_localPlayer;
    CreaturePtr m_attackingCreature;
    CreaturePtr m_followingCreature;
    ProtocolGamePtr m_protocolGame;
    Timer m_dashTimer;
    Otc::FightModes m_fightMode{ Otc::FightBalanced };
    Otc::ChaseModes m_chaseMode{ Otc::DontChase };
    Otc::PVPModes m_pvpMode{ Otc::WhiteDove };
    Otc::OperatingSystem_t m_clientCustomOs{ Otc::CLIENTOS_NONE };
    UnjustifiedPoints m_unjustifiedPoints;
    ScheduledEventPtr m_pingEvent;
    ScheduledEventPtr m_checkConnectionEvent;

    bool m_tileThingsLuaCallback{ false };
    bool m_online{ false };
    bool m_dead{ false };
    bool m_expertPvpMode{ false };
    bool m_connectionFailWarned{ false };
    bool m_scheduleLastWalk{ false };
    bool m_safeFight{ true };
    bool m_canReportBugs{ false };

    uint16_t m_mapUpdatedAt{ 0 };
    std::pair<uint16_t, Timer> m_mapUpdateTimer = { true, Timer{} };

    uint8_t m_walkMaxSteps{ 1 };
    uint8_t m_openPvpSituations{ 0 };
    uint16_t m_serverBeat{ 50 };
    uint16_t m_pingDelay{ 1000 };
    uint16_t m_protocolVersion{ 0 };
    uint16_t m_clientVersion{ 0 };
    uint32_t m_pingSent{ 0 };
    uint32_t m_pingReceived{ 0 };
    uint32_t m_seq{ 0 };

    std::string m_characterName;
    std::string m_worldName;
    std::string m_clientSignature;
    std::vector<uint8_t > m_gmActions;
    std::bitset<Otc::LastGameFeature> m_features;

    stdext::map<int, ContainerPtr> m_containers;
    stdext::map<int, Vip> m_vips;
    stdext::timer m_pingTimer;

    ticks_t m_ping{ -1 };
};

extern Game g_game;
