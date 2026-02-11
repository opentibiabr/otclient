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
#include "framework/net/protocol.h"
#include "staticdata.h"

class ProtocolGame final : public Protocol
{
public:
    void login(std::string_view accountName, std::string_view accountPassword, std::string_view host, uint16_t port, std::string_view characterName, std::string_view authenticatorToken, std::string_view sessionKey);

    void sendExtendedOpcode(uint8_t opcode, const std::string& buffer);
    void sendLoginPacket(uint32_t challengeTimestamp, uint8_t challengeRandom);
    void sendEnterGame();
    void sendLogout();
    void sendPing();
    void sendPingBack();
    void sendAutoWalk(const std::vector<Otc::Direction>& path);
    void sendWalkNorth();
    void sendWalkEast();
    void sendWalkSouth();
    void sendWalkWest();
    void sendStop();
    void sendWalkNorthEast();
    void sendWalkSouthEast();
    void sendWalkSouthWest();
    void sendWalkNorthWest();
    void sendTurnNorth();
    void sendTurnEast();
    void sendTurnSouth();
    void sendTurnWest();
    void sendGmTeleport(const Position& pos);
    void sendEquipItemWithTier(uint16_t itemId, uint8_t tierOrFluid);
    void sendEquipItemWithCountOrSubType(uint16_t itemId, uint16_t tierOrFluid);
    void sendMove(const Position& fromPos, uint16_t thingId, uint8_t stackpos, const Position& toPos, uint16_t count);
    void sendInspectNpcTrade(uint16_t itemId, uint16_t count);
    void sendBuyItem(uint16_t itemId, uint8_t subType, uint16_t amount, bool ignoreCapacity, bool buyWithBackpack);
    void sendSellItem(uint16_t itemId, uint8_t subType, uint16_t amount, bool ignoreEquipped);
    void sendCloseNpcTrade();
    void sendRequestTrade(const Position& pos, uint16_t thingId, uint8_t stackpos, uint32_t creatureId);
    void sendInspectTrade(bool counterOffer, uint8_t index);
    void sendAcceptTrade();
    void sendRejectTrade();
    void sendUseItem(const Position& position, uint16_t itemId, uint8_t stackpos, uint8_t index);
    void sendUseItemWith(const Position& fromPos, uint16_t itemId, uint8_t fromStackPos, const Position& toPos, uint16_t toThingId, uint8_t toStackPos);
    void sendUseOnCreature(const Position& pos, uint16_t thingId, uint8_t stackpos, uint32_t creatureId);
    void sendRotateItem(const Position& pos, uint16_t thingId, uint8_t stackpos);
    void sendOnWrapItem(const Position& pos, uint16_t thingId, uint8_t stackpos);
    void sendCloseContainer(uint8_t containerId);
    void sendUpContainer(uint8_t containerId);
    void sendEditText(uint32_t id, std::string_view text);
    void sendEditList(uint32_t id, uint8_t doorId, std::string_view text);
    void sendLook(const Position& position, uint16_t itemId, uint8_t stackpos);
    void sendLookCreature(uint32_t creatureId);
    void sendTalk(Otc::MessageMode mode, uint16_t channelId, std::string_view receiver, std::string_view message);
    void sendRequestChannels();
    void sendJoinChannel(uint16_t channelId);
    void sendLeaveChannel(uint16_t channelId);
    void sendOpenPrivateChannel(std::string_view receiver);
    void sendOpenRuleViolation(std::string_view reporter);
    void sendCloseRuleViolation(std::string_view reporter);
    void sendCancelRuleViolation();
    void sendCloseNpcChannel();
    void sendChangeFightModes(Otc::FightModes fightMode, Otc::ChaseModes chaseMode, bool safeFight, Otc::PVPModes pvpMode);
    void sendAttack(uint32_t creatureId, uint32_t seq);
    void sendFollow(uint32_t creatureId, uint32_t seq);
    void sendInviteToParty(uint32_t creatureId);
    void sendJoinParty(uint32_t creatureId);
    void sendRevokeInvitation(uint32_t creatureId);
    void sendPassLeadership(uint32_t creatureId);
    void sendLeaveParty();
    void sendShareExperience(bool active);
    void sendPartyAnalyzerAction(uint8_t action, const std::vector<std::tuple<uint16_t, uint64_t>>& items = {});
    void sendOpenOwnChannel();
    void sendInviteToOwnChannel(std::string_view name);
    void sendExcludeFromOwnChannel(std::string_view name);
    void sendCancelAttackAndFollow();
    void sendRefreshContainer(uint8_t containerId);
    void sendRequestBless();
    void sendRequestTrackerQuestLog(const std::map<uint16_t, std::string>& quests);
    void sendRequestOutfit();
    void sendTyping(bool typing);
    void sendChangeOutfit(const Outfit& outfit);
    void sendMountStatus(bool mount);
    void sendAddVip(std::string_view name);
    void sendRemoveVip(uint32_t playerId);
    void sendEditVip(uint32_t playerId, std::string_view description, uint32_t iconId, bool notifyLogin, const std::vector<uint8_t>& groupIDs = {});
    void sendEditVipGroups(Otc::GroupsEditInfoType_t action, uint8_t groupId, std::string_view groupName);
    void sendBugReport(std::string_view comment);
    void sendRuleViolation(std::string_view target, uint8_t reason, uint8_t action, std::string_view comment, std::string_view statement, uint16_t statementId, bool ipBanishment);
    void sendDebugReport(std::string_view a, std::string_view b, std::string_view c, std::string_view d);
    void sendRequestQuestLog();
    void sendRequestQuestLine(uint16_t questId);
    void sendNewNewRuleViolation(uint8_t reason, uint8_t action, std::string_view characterName, std::string_view comment, std::string_view translation);
    void sendRequestItemInfo(uint16_t itemId, uint8_t subType, uint8_t index);
    void sendAnswerModalDialog(uint32_t dialog, uint8_t button, uint8_t choice);
    void sendBrowseField(const Position& position);
    void sendSeekInContainer(uint8_t containerId, uint16_t index);
    void sendBuyStoreOffer(const uint32_t offerId, const uint8_t action, const std::string_view& name, const uint8_t type, const std::string_view& location);
    void sendRequestTransactionHistory(uint32_t page, uint32_t entriesPerPage);
    void sendRequestStoreOffers(const std::string_view categoryName, const std::string_view subCategory, const uint8_t sortOrder = 0, const uint8_t serviceType = 0);
    void sendRequestStoreHome();
    void sendRequestStorePremiumBoost();
    void sendRequestUsefulThings(const uint8_t offerId);
    void sendRequestStoreOfferById(uint32_t offerId, uint8_t sortOrder = 0, uint8_t serviceType = 0);
    void sendRequestStoreSearch(const std::string_view searchText, uint8_t sortOrder = 0, uint8_t serviceType = 0);
    void sendOpenStore(uint8_t serviceType, std::string_view category);
    void sendTransferCoins(std::string_view recipient, uint16_t amount);
    void sendOpenTransactionHistory(uint8_t entriesPerPage);
    void sendMarketLeave();
    void sendMarketBrowse(uint8_t browseId, uint16_t browseType, uint8_t tier = 0);
    void sendMarketCreateOffer(uint8_t type, uint16_t itemId, uint8_t itemTier, uint16_t amount, uint64_t price, uint8_t anonymous);
    void sendMarketCancelOffer(uint32_t timestamp, uint16_t counter);
    void sendMarketAcceptOffer(uint32_t timestamp, uint16_t counter, uint16_t amount);
    void sendPreyAction(uint8_t slot, uint8_t actionType, uint16_t index);
    void sendPreyRequest();
    void sendOpenPortableForge();
    void sendForgeRequest(Otc::ForgeAction_t actionType, bool convergence = false, uint16_t firstItemid = 0, uint8_t firstItemTier = 0, uint16_t secondItemId = 0, bool improveChance = false, bool tierLoss = false);
    void sendForgeBrowseHistoryRequest(uint16_t page);
    void sendApplyImbuement(uint8_t slot, uint32_t imbuementId, bool protectionCharm);
    void sendClearImbuement(uint8_t slot);
    void sendCloseImbuingWindow();
    void sendOpenRewardWall();
    void sendOpenRewardHistory();
    void sendGetRewardDaily(const uint8_t bonusShrine, const std::map<uint16_t, uint8_t>& items);
    void sendStashWithdraw(uint16_t itemId, uint32_t count, uint8_t stackpos);
    void sendStashStow(const Position& position, const uint16_t itemId, const uint32_t count, const uint8_t stackpos, const uint8_t action);
    void sendHighscoreInfo(uint8_t action, uint8_t category, uint32_t vocation, std::string_view world, uint8_t worldType, uint8_t battlEye, uint16_t page, uint8_t totalPages);
    void sendImbuementDurations(bool isOpen = false);
    void sendWeaponProficiencyAction(uint8_t actionType, uint16_t itemId = 0);
    void sendWeaponProficiencyApply(uint16_t itemId, const std::vector<std::pair<uint8_t, uint8_t>>& perks);
    void sendRequestBestiary();
    void sendRequestBestiaryOverview(std::string_view catName, bool search = false, std::vector<uint16_t> raceIds = {});
    void sendRequestBestiarySearch(uint16_t raceId);
    void sendBuyCharmRune(uint8_t runeId, uint8_t action, uint16_t raceId);
    void sendCyclopediaRequestCharacterInfo(uint32_t playerId, Otc::CyclopediaCharacterInfoType_t characterInfoType, uint16_t entriesPerPage, uint16_t page);
    void sendCyclopediaHouseAuction(Otc::CyclopediaHouseAuctionType_t type, uint32_t houseId, uint32_t timestamp, uint64_t bidValue, std::string_view name);
    void sendRequestBosstiaryInfo();
    void sendRequestBossSlootInfo();
    void sendRequestBossSlotAction(uint8_t action, uint32_t raceId);
    void sendStatusTrackerBestiary(uint16_t raceId, bool status);
    void sendQuickLoot(const uint8_t variant, const Position& pos, const uint16_t itemId, const uint8_t stackpos);
    void requestQuickLootBlackWhiteList(uint8_t filter, uint16_t size, const std::vector<uint16_t>& listedItems);
    void openContainerQuickLoot(uint8_t action, uint8_t category, const Position& pos, uint16_t itemId, uint8_t stackpos, bool useMainAsFallback);
    void sendInspectionNormalObject(const Position& position);
    void sendInspectionObject(Otc::InspectObjectTypes inspectionType, uint16_t itemId, uint8_t itemCount);

    // Wheel of Destiny
    void sendOpenWheel(uint32_t playerId);
    void sendApplyWheelPoints(const std::vector<uint16_t>& slotPoints,uint16_t greenGem,uint16_t redGem,uint16_t acquaGem,uint16_t purpleGem);
    void sendWheelGemAction(const uint8_t actionType, const uint8_t param, const uint8_t pos);
    void sendOpenWheelOfDestiny(uint32_t playerId);
    void sendApplyWheelOfDestiny(const std::vector<uint16_t>& wheelPointsVec, const std::vector<uint16_t>& activeGemsVec);

    // otclient only
    void sendChangeMapAwareRange(uint8_t xrange, uint8_t yrange);

protected:
    void onConnect() override;
    void onRecv(const InputMessagePtr& inputMessage) override;
    void onError(const std::error_code& error) override;
    void onSend() override;

    friend class Game;

public:
    void addPosition(const OutputMessagePtr& msg, const Position& position);

    int getRecivedPacketsCount() { return m_recivedPackeds; }
    int getRecivedPacketsSize() { return m_recivedPackedsSize; }

private:
    void parseStoreButtonIndicators(const InputMessagePtr& msg);
    void parseSetStoreDeepLink(const InputMessagePtr& msg);
    void parseStore(const InputMessagePtr& msg) const;
    void parseStoreError(const InputMessagePtr& msg) const;
    void parseStoreTransactionHistory(const InputMessagePtr& msg) const;
    void parseStoreOffers(const InputMessagePtr& msg);
    void parseCompleteStorePurchase(const InputMessagePtr& msg) const;
    void parseRequestPurchaseData(const InputMessagePtr& msg);
    void parseResourceBalance(const InputMessagePtr& msg) const;
    void parseWorldTime(const InputMessagePtr& msg);
    void parseCoinBalance(const InputMessagePtr& msg) const;
    void parseCoinBalanceUpdating(const InputMessagePtr& msg);
    void parseBlessings(const InputMessagePtr& msg) const;
    void parseUnjustifiedStats(const InputMessagePtr& msg);
    void parsePvpSituations(const InputMessagePtr& msg);
    void parsePreset(const InputMessagePtr& msg);
    void parseCreatureType(const InputMessagePtr& msg);
    void parsePlayerHelpers(const InputMessagePtr& msg) const;
    void parseMessage(const InputMessagePtr& msg);
    void parseBugReport(const InputMessagePtr& msg);
    void parsePendingGame(const InputMessagePtr& msg);
    void parseEnterGame(const InputMessagePtr& msg);
    void parseLogin(const InputMessagePtr& msg) const;
    void parseGMActions(const InputMessagePtr& msg);
    void parseUpdateNeeded(const InputMessagePtr& msg);
    void parseLoginError(const InputMessagePtr& msg);
    void parseLoginAdvice(const InputMessagePtr& msg);
    void parseLoginWait(const InputMessagePtr& msg);
    void parseSessionEnd(const InputMessagePtr& msg);
    void parsePing(const InputMessagePtr& msg);
    void parsePingBack(const InputMessagePtr& msg);
    void parseLoginChallenge(const InputMessagePtr& msg);
    void parseDeath(const InputMessagePtr& msg);
    void parseFloorDescription(const InputMessagePtr& msg);
    void parseMapDescription(const InputMessagePtr& msg);
    void parseCreatureTyping(const InputMessagePtr& msg);
    void parseFeatures(const InputMessagePtr& msg);
    void parseMapMoveNorth(const InputMessagePtr& msg);
    void parseMapMoveEast(const InputMessagePtr& msg);
    void parseMapMoveSouth(const InputMessagePtr& msg);
    void parseMapMoveWest(const InputMessagePtr& msg);
    void parseUpdateTile(const InputMessagePtr& msg);
    void parseTileAddThing(const InputMessagePtr& msg);
    void parseTileTransformThing(const InputMessagePtr& msg);
    void parseTileRemoveThing(const InputMessagePtr& msg) const;
    void parseCreatureMove(const InputMessagePtr& msg);
    void parseOpenContainer(const InputMessagePtr& msg);
    void parseCloseContainer(const InputMessagePtr& msg);
    void parseContainerAddItem(const InputMessagePtr& msg);
    void parseContainerUpdateItem(const InputMessagePtr& msg);
    void parseContainerRemoveItem(const InputMessagePtr& msg);
    void parseBosstiaryInfo(const InputMessagePtr& msg);
    void parseTakeScreenshot(const InputMessagePtr& msg);
    void parseCyclopediaItemDetail(const InputMessagePtr& msg);
    void parseAddInventoryItem(const InputMessagePtr& msg);
    void parseRemoveInventoryItem(const InputMessagePtr& msg);
    void parseOpenNpcTrade(const InputMessagePtr& msg);
    void parsePlayerGoods(const InputMessagePtr& msg) const;
    void parseCloseNpcTrade(const InputMessagePtr&);
    void parseWorldLight(const InputMessagePtr& msg);
    void parseMagicEffect(const InputMessagePtr& msg);
    void parseRemoveMagicEffect(const InputMessagePtr& msg);
    void parseAnimatedText(const InputMessagePtr& msg);
    void parseDistanceMissile(const InputMessagePtr& msg);
    void parseAnthem(const InputMessagePtr& msg);
    void parseItemClasses(const InputMessagePtr& msg);
    void parseForgeResult(const InputMessagePtr& msg);
    void parseCreatureMark(const InputMessagePtr& msg);
    void parseTrappers(const InputMessagePtr& msg);
    void parseOpenForge(const InputMessagePtr& msg);
    void setCreatureVocation(const InputMessagePtr& msg, const uint32_t creatureId) const;
    void addCreatureIcon(const InputMessagePtr& msg, const uint32_t creatureId) const;
    void parseBrowseForgeHistory(const InputMessagePtr& msg);
    void parseCloseForgeWindow(const InputMessagePtr& msg);
    void parseCreatureData(const InputMessagePtr& msg);
    void parseCreatureHealth(const InputMessagePtr& msg);
    void parseCreatureLight(const InputMessagePtr& msg);
    void parseCreatureOutfit(const InputMessagePtr& msg) const;
    void parseCreatureSpeed(const InputMessagePtr& msg);
    void parseCreatureSkulls(const InputMessagePtr& msg);
    void parseCreatureShields(const InputMessagePtr& msg);
    void parseCreatureUnpass(const InputMessagePtr& msg);
    void parseEditText(const InputMessagePtr& msg);
    void parseEditList(const InputMessagePtr& msg);
    void parsePremiumTrigger(const InputMessagePtr& msg);
    void parsePlayerInfo(const InputMessagePtr& msg) const;
    void parsePlayerStats(const InputMessagePtr& msg) const;
    void parsePlayerSkills(const InputMessagePtr& msg) const;
    void parsePlayerState(const InputMessagePtr& msg) const;
    void parsePlayerCancelAttack(const InputMessagePtr& msg);
    void parsePlayerModes(const InputMessagePtr& msg);
    void parseSpellCooldown(const InputMessagePtr& msg);
    void parseSpellGroupCooldown(const InputMessagePtr& msg);
    void parseMultiUseCooldown(const InputMessagePtr& msg);
    void parseTalk(const InputMessagePtr& msg);
    void parseChannelList(const InputMessagePtr& msg);
    void parseOpenChannel(const InputMessagePtr& msg);
    void parseOpenPrivateChannel(const InputMessagePtr& msg);
    void parseOpenOwnPrivateChannel(const InputMessagePtr& msg);
    void parseCloseChannel(const InputMessagePtr& msg);
    void parseRuleViolationChannel(const InputMessagePtr& msg);
    void parseRuleViolationRemove(const InputMessagePtr& msg);
    void parseRuleViolationCancel(const InputMessagePtr& msg);
    void parseRuleViolationLock(const InputMessagePtr& msg);
    void parseOwnTrade(const InputMessagePtr& msg);
    void parseCounterTrade(const InputMessagePtr& msg);
    void parseCloseTrade(const InputMessagePtr&);
    void parseTextMessage(const InputMessagePtr& msg);
    void parseCancelWalk(const InputMessagePtr& msg);
    void parseWalkWait(const InputMessagePtr& msg) const;
    void parseFloorChangeUp(const InputMessagePtr& msg);
    void parseFloorChangeDown(const InputMessagePtr& msg);
    void parseQuestTracker(const InputMessagePtr& msg);
    void parseKillTracker(const InputMessagePtr& msg);
    void parseOpenOutfitWindow(const InputMessagePtr& msg) const;
    void parseVipAdd(const InputMessagePtr& msg);
    void parseVipState(const InputMessagePtr& msg);
    void parseVipLogout(const InputMessagePtr& msg);
    void parseTutorialHint(const InputMessagePtr& msg);
    void parseAutomapFlag(const InputMessagePtr& msg);
    void parseQuestLog(const InputMessagePtr& msg);
    void parseQuestLine(const InputMessagePtr& msg);
    void parseChannelEvent(const InputMessagePtr& msg);
    void parseItemInfo(const InputMessagePtr& msg) const;
    void parsePlayerInventory(const InputMessagePtr& msg);
    void parseModalDialog(const InputMessagePtr& msg);
    void parseExtendedOpcode(const InputMessagePtr& msg);
    void parseChangeMapAwareRange(const InputMessagePtr& msg);
    void parseCreaturesMark(const InputMessagePtr& msg);
    // 12x
    void parseShowDescription(const InputMessagePtr& msg);
    void parseBestiaryTracker(const InputMessagePtr& msg);
    void parseTaskHuntingBasicData(const InputMessagePtr& msg);
    void parseTaskHuntingData(const InputMessagePtr& msg);
    void parseExperienceTracker(const InputMessagePtr& msg);
    void parseLootContainers(const InputMessagePtr& msg);
    void parseMonkData(const InputMessagePtr& msg);
    void parseCyclopediaHouseAuctionMessage(const InputMessagePtr& msg);
    void parseCyclopediaHousesInfo(const InputMessagePtr& msg);
    void parseCyclopediaHouseList(const InputMessagePtr& msg);

    void parseSupplyStash(const InputMessagePtr& msg);
    void parseSpecialContainer(const InputMessagePtr& msg);
    void parsePartyAnalyzer(const InputMessagePtr& msg);
    void parseImbuementDurations(const InputMessagePtr& msg);
    void parsePassiveCooldown(const InputMessagePtr& msg);
    void parseClientCheck(const InputMessagePtr& msg);
    void parseGameNews(const InputMessagePtr& msg);
    void parseBlessDialog(const InputMessagePtr& msg);
    void parseRestingAreaState(const InputMessagePtr& msg);
    void parseUpdateImpactTracker(const InputMessagePtr& msg);
    void parseItemsPrice(const InputMessagePtr& msg);
    void parseUpdateSupplyTracker(const InputMessagePtr& msg);
    void parseUpdateLootTracker(const InputMessagePtr& msg);
    void parseBestiaryEntryChanged(const InputMessagePtr& msg);
    void parseCyclopediaCharacterInfo(const InputMessagePtr& msg);
    void parseDailyRewardCollectionState(const InputMessagePtr& msg);
    void parseOpenRewardWall(const InputMessagePtr& msg);
    void parseDailyReward(const InputMessagePtr& msg);
    void parseRewardHistory(const InputMessagePtr& msg);
    void parsePreyFreeRerolls(const InputMessagePtr& msg);
    void parsePreyTimeLeft(const InputMessagePtr& msg);
    void parsePreyData(const InputMessagePtr& msg);
    void parsePreyRerollPrice(const InputMessagePtr& msg);
    void parseImbuementWindow(const InputMessagePtr& msg);
    void parseCloseImbuementWindow(const InputMessagePtr& msg);
    void parseError(const InputMessagePtr& msg);
    void parseMarketEnter(const InputMessagePtr& msg);
    void parseMarketEnterOld(const InputMessagePtr& msg);
    void parseMarketDetail(const InputMessagePtr& msg);
    void parseMarketBrowse(const InputMessagePtr& msg);

    // 13x
    void parseBosstiaryData(const InputMessagePtr& msg);
    void parseBosstiarySlots(const InputMessagePtr& msg);
    void parseBosstiaryCooldownTimer(const InputMessagePtr& msg);
    void parseBosstiaryEntryChanged(const InputMessagePtr& msg);
    void parseBestiaryRaces(const InputMessagePtr& msg);
    void parseBestiaryOverview(const InputMessagePtr& msg);
    void parseBestiaryMonsterData(const InputMessagePtr& msg);
    void parseBestiaryCharmsData(const InputMessagePtr& msg);

    // 15x
    void parseWeaponProficiencyInfo(const InputMessagePtr& msg);

    void parseHighscores(const InputMessagePtr& msg);
    void parseAttachedEffect(const InputMessagePtr& msg);
    void parseDetachEffect(const InputMessagePtr& msg);
    void parseCreatureShader(const InputMessagePtr& msg);
    void parseMapShader(const InputMessagePtr& msg);
    void parseOpenWheelWindow(const InputMessagePtr& msg);

    void parseAttachedPaperdoll(const InputMessagePtr& msg);
    void parseDetachPaperdoll(const InputMessagePtr& msg);

    MarketOffer readMarketOffer(const InputMessagePtr& msg, uint8_t action, uint16_t var);

    Imbuement getImbuementInfo(const InputMessagePtr& msg);
    PreyMonster getPreyMonster(const InputMessagePtr& msg) const;
    std::vector<PreyMonster> getPreyMonsters(const InputMessagePtr& msg);

public:
    void setMapDescription(const InputMessagePtr& msg, int x, int y, int z, int width, int height);
    int setFloorDescription(const InputMessagePtr& msg, int x, int y, int z, int width, int height, int offset, int skip);
    int setTileDescription(const InputMessagePtr& msg, Position position);

    Outfit getOutfit(const InputMessagePtr& msg, bool parseMount = true) const;
    ThingPtr getThing(const InputMessagePtr& msg);
    ThingPtr getMappedThing(const InputMessagePtr& msg) const;
    CreaturePtr getCreature(const InputMessagePtr& msg, int type = 0) const;
    ItemPtr getItem(const InputMessagePtr& msg, int id = 0);
    Position getPosition(const InputMessagePtr& msg);

private:
    PaperdollPtr getPaperdoll(const InputMessagePtr& msg) const;

    bool m_enableSendExtendedOpcode{ false };
    bool m_gameInitialized{ false };
    bool m_mapKnown{ false };
    bool m_firstRecv{ true };
    bool m_record{ false };

    ticks_t m_lastPartyAnalyzerCall{ 0 };
    int m_recivedPackeds = 0;
    int m_recivedPackedsSize = 0;

    std::string m_accountName;
    std::string m_accountPassword;
    std::string m_authenticatorToken;
    std::string m_sessionKey;
    std::string m_characterName;
    LocalPlayerPtr m_localPlayer;
};
