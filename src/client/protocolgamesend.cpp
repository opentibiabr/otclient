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

#include "game.h"
#include "item.h"
#include "protocolgame.h"
#include "framework/net/outputmessage.h"
#include "protocolcodes.h"
#include "thingtypemanager.h"
#include "thingtype.h"
#include "framework/util/crypt.h"

void ProtocolGame::onSend() {}
void ProtocolGame::sendExtendedOpcode(const uint8_t opcode, const std::string& buffer)
{
    if (m_enableSendExtendedOpcode) {
        const auto& msg = std::make_shared<OutputMessage>();
        msg->addU8(Proto::ClientExtendedOpcode);
        msg->addU8(opcode);
        msg->addString(buffer);
        send(msg);
    } else {
        g_logger.error("Unable to send extended opcode {}, extended opcodes are not enabled", opcode);
    }
}

void ProtocolGame::sendLoginPacket(const uint32_t challengeTimestamp, const uint8_t challengeRandom)
{
    const auto& msg = std::make_shared<OutputMessage>();

    msg->addU8(Proto::ClientPendingGame);
    msg->addU16(g_game.getOs());
    msg->addU16(g_game.getProtocolVersion());

    if (g_game.getFeature(Otc::GameClientVersion))
        msg->addU32(g_game.getClientVersion());

    if (g_game.getClientVersion() >= 1281) {
        msg->addString(std::to_string(g_game.getClientVersion()));
    }

    if (g_game.getClientVersion() >= 1334) {
        msg->addString("appearancesHash");
    } else if (g_game.getFeature(Otc::GameContentRevision)) {
        msg->addU16(g_things.getContentRevision());
    }

    if (g_game.getFeature(Otc::GamePreviewState))
        msg->addU8(0);

    const int offset = msg->getMessageSize();

    if (g_game.getFeature(Otc::GameLoginPacketEncryption)) {
        // first RSA byte must be 0
        msg->addU8(0);
        // xtea key
        generateXteaKey();
        msg->addU32(m_xteaKey[0]);
        msg->addU32(m_xteaKey[1]);
        msg->addU32(m_xteaKey[2]);
        msg->addU32(m_xteaKey[3]);
    }

    msg->addU8(0); // is gm set?

    if (g_game.getFeature(Otc::GameSessionKey)) {
        msg->addString(m_sessionKey);
        msg->addString(m_characterName);

    } else {
        if (g_game.getFeature(Otc::GameAccountNames))
            msg->addString(m_accountName);
        else
            msg->addU32(stdext::from_string<uint32_t>(m_accountName));

        msg->addString(m_characterName);
        msg->addString(m_accountPassword);

        if (g_game.getFeature(Otc::GameAuthenticator))
            msg->addString(m_authenticatorToken);
    }

    if (g_game.getFeature(Otc::GameChallengeOnLogin)) {
        msg->addU32(challengeTimestamp);
        msg->addU8(challengeRandom);
    }

    const auto& extended = callLuaField<std::string>("getLoginExtendedData");
    if (!extended.empty())
        msg->addString(extended);

    // complete the bytes for rsa encryption with zeros
    const int paddingBytes = g_crypt.rsaGetSize() - (msg->getMessageSize() - offset);
    assert(paddingBytes >= 0);
    msg->addPaddingBytes(paddingBytes);

    // encrypt with RSA
    if (g_game.getFeature(Otc::GameLoginPacketEncryption))
        msg->encryptRsa();

    if (g_game.getFeature(Otc::GameProtocolChecksum))
        enableChecksum();

    send(msg);

    if (g_game.getFeature(Otc::GameLoginPacketEncryption))
        enableXteaEncryption();

    if (g_game.getFeature(Otc::GameSequencedPackets))
        enabledSequencedPackets();
}

void ProtocolGame::sendEnterGame()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEnterGame);
    send(msg);
}

void ProtocolGame::sendLogout()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLeaveGame);
    send(msg);
}

void ProtocolGame::sendPing()
{
    if (g_game.getFeature(Otc::GameExtendedClientPing))
        sendExtendedOpcode(2, "");
    else {
        const auto& msg = std::make_shared<OutputMessage>();
        msg->addU8(Proto::ClientPing);
        Protocol::send(msg);
    }
}

void ProtocolGame::sendPingBack()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPingBack);
    send(msg);
}

void ProtocolGame::sendAutoWalk(const std::vector<Otc::Direction>& path)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientAutoWalk);
    msg->addU8(path.size());
    for (const Otc::Direction dir : path) {
        uint8_t byte;
        switch (dir) {
            case Otc::East:
                byte = 1;
                break;
            case Otc::NorthEast:
                byte = 2;
                break;
            case Otc::North:
                byte = 3;
                break;
            case Otc::NorthWest:
                byte = 4;
                break;
            case Otc::West:
                byte = 5;
                break;
            case Otc::SouthWest:
                byte = 6;
                break;
            case Otc::South:
                byte = 7;
                break;
            case Otc::SouthEast:
                byte = 8;
                break;
            default:
                byte = 0;
                break;
        }
        msg->addU8(byte);
    }
    send(msg);
}

void ProtocolGame::sendWalkNorth()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkNorth);
    send(msg);
}

void ProtocolGame::sendWalkEast()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkEast);
    send(msg);
}

void ProtocolGame::sendWalkSouth()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkSouth);
    send(msg);
}

void ProtocolGame::sendWalkWest()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkWest);
    send(msg);
}

void ProtocolGame::sendStop()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientStop);
    send(msg);
}

void ProtocolGame::sendWalkNorthEast()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkNorthEast);
    send(msg);
}

void ProtocolGame::sendWalkSouthEast()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkSouthEast);
    send(msg);
}

void ProtocolGame::sendWalkSouthWest()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkSouthWest);
    send(msg);
}

void ProtocolGame::sendWalkNorthWest()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWalkNorthWest);
    send(msg);
}

void ProtocolGame::sendTurnNorth()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTurnNorth);
    send(msg);
}

void ProtocolGame::sendTurnEast()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTurnEast);
    send(msg);
}

void ProtocolGame::sendTurnSouth()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTurnSouth);
    send(msg);
}

void ProtocolGame::sendTurnWest()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTurnWest);
    send(msg);
}

void ProtocolGame::sendGmTeleport(const Position& pos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientGmTeleport);
    addPosition(msg, pos);
    send(msg);
}

void ProtocolGame::sendEquipItemWithTier(const uint16_t itemId, const uint8_t tier)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEquipItem);
    msg->addU16(itemId);
    msg->addU8(tier);
    send(msg);
}

void ProtocolGame::sendEquipItemWithCountOrSubType(const uint16_t itemId, const uint16_t countOrSubType)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEquipItem);
    msg->addU16(itemId);
    if (g_game.getFeature(Otc::GameCountU16)) {
        msg->addU16(countOrSubType);
    } else {
        msg->addU8(static_cast<uint8_t>(countOrSubType));
    }
    send(msg);
}

void ProtocolGame::sendMove(const Position& fromPos, const uint16_t thingId, const uint8_t stackpos, const Position& toPos, const uint16_t count)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMove);
    addPosition(msg, fromPos);
    msg->addU16(thingId);
    msg->addU8(stackpos);
    addPosition(msg, toPos);
    if (g_game.getFeature(Otc::GameCountU16))
        msg->addU16(count);
    else
        msg->addU8(static_cast<uint8_t>(count));
    send(msg);
}

void ProtocolGame::sendInspectNpcTrade(const uint16_t itemId, const uint16_t count)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInspectNpcTrade);
    msg->addU16(itemId);
    if (g_game.getFeature(Otc::GameCountU16))
        msg->addU16(count);
    else
        msg->addU8(static_cast<uint8_t>(count));
    send(msg);
}

void ProtocolGame::sendBuyItem(const uint16_t itemId, const uint8_t subType, const uint16_t amount, const bool ignoreCapacity, const bool buyWithBackpack)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBuyItem);
    msg->addU16(itemId);
    msg->addU8(subType);
    if (g_game.getFeature(Otc::GameDoubleShopSellAmount))
        msg->addU16(amount);
    else
        msg->addU8(static_cast<uint8_t>(amount));
    msg->addU8(ignoreCapacity);
    msg->addU8(buyWithBackpack);
    send(msg);
}

void ProtocolGame::sendSellItem(const uint16_t itemId, const uint8_t subType, const uint16_t amount, const bool ignoreEquipped)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientSellItem);
    msg->addU16(itemId);
    msg->addU8(subType);
    if (g_game.getFeature(Otc::GameDoubleShopSellAmount))
        msg->addU16(amount);
    else
        msg->addU8(static_cast<uint8_t>(amount));
    msg->addU8(ignoreEquipped);
    send(msg);
}

void ProtocolGame::sendCloseNpcTrade()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCloseNpcTrade);
    send(msg);
}

void ProtocolGame::sendRequestTrade(const Position& pos, const uint16_t thingId, const uint8_t stackpos, const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestTrade);
    addPosition(msg, pos);
    msg->addU16(thingId);
    msg->addU8(stackpos);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendInspectTrade(const bool counterOffer, const uint8_t index)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInspectTrade);
    msg->addU8(counterOffer);
    msg->addU8(index);
    send(msg);
}

void ProtocolGame::sendAcceptTrade()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientAcceptTrade);
    send(msg);
}

void ProtocolGame::sendRejectTrade()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRejectTrade);
    send(msg);
}

void ProtocolGame::sendUseItem(const Position& position, const uint16_t itemId, const uint8_t stackpos, const uint8_t index)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUseItem);
    addPosition(msg, position);
    msg->addU16(itemId);
    msg->addU8(stackpos);
    msg->addU8(index);
    send(msg);
}

void ProtocolGame::sendUseItemWith(const Position& fromPos, const uint16_t itemId, const uint8_t fromStackPos, const Position& toPos, const uint16_t toThingId, const uint8_t toStackPos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUseItemWith);
    addPosition(msg, fromPos);
    msg->addU16(itemId);
    msg->addU8(fromStackPos);
    addPosition(msg, toPos);
    msg->addU16(toThingId);
    msg->addU8(toStackPos);
    send(msg);
}

void ProtocolGame::sendUseOnCreature(const Position& pos, const uint16_t thingId, const uint8_t stackpos, const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUseOnCreature);
    addPosition(msg, pos);
    msg->addU16(thingId);
    msg->addU8(stackpos);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendRotateItem(const Position& pos, const uint16_t thingId, const uint8_t stackpos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRotateItem);
    addPosition(msg, pos);
    msg->addU16(thingId);
    msg->addU8(stackpos);
    send(msg);
}

void ProtocolGame::sendOnWrapItem(const Position& pos, const uint16_t thingId, const uint8_t stackpos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOnWrapItem);
    addPosition(msg, pos);
    msg->addU16(thingId);
    msg->addU8(stackpos);
    send(msg);
}

void ProtocolGame::sendCloseContainer(const uint8_t containerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCloseContainer);
    msg->addU8(containerId);
    send(msg);
}

void ProtocolGame::sendUpContainer(const uint8_t containerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUpContainer);
    msg->addU8(containerId);
    send(msg);
}

void ProtocolGame::sendEditText(const uint32_t id, const std::string_view text)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEditText);
    msg->addU32(id);
    msg->addString(text);
    send(msg);
}

void ProtocolGame::sendEditList(const uint32_t id, const uint8_t doorId, const std::string_view text)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEditList);
    msg->addU8(doorId);
    msg->addU32(id);
    msg->addString(text);
    send(msg);
}

void ProtocolGame::sendLook(const Position& position, const uint16_t itemId, const uint8_t stackpos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLook);
    addPosition(msg, position);
    msg->addU16(itemId);
    msg->addU8(stackpos);
    send(msg);
}

void ProtocolGame::sendLookCreature(const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLookCreature);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendTalk(const Otc::MessageMode mode, const uint16_t channelId, const std::string_view receiver, const std::string_view message)
{
    if (message.empty())
        return;

    if (message.length() > UINT8_MAX) {
        g_logger.traceError("message too large");
        return;
    }

    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTalk);
    msg->addU8(Proto::translateMessageModeToServer(mode));

    switch (mode) {
        case Otc::MessagePrivateTo:
        case Otc::MessageGamemasterPrivateTo:
        case Otc::MessageRVRAnswer:
            msg->addString(receiver);
            break;
        case Otc::MessageChannel:
        case Otc::MessageChannelHighlight:
        case Otc::MessageChannelManagement:
        case Otc::MessageGamemasterChannel:
            msg->addU16(channelId);
            break;
        default:
            break;
    }

    msg->addString(message);
    send(msg);
}

void ProtocolGame::sendRequestChannels()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestChannels);
    send(msg);
}

void ProtocolGame::sendJoinChannel(const uint16_t channelId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientJoinChannel);
    msg->addU16(channelId);
    send(msg);
}

void ProtocolGame::sendLeaveChannel(const uint16_t channelId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLeaveChannel);
    msg->addU16(channelId);
    send(msg);
}

void ProtocolGame::sendOpenPrivateChannel(const std::string_view receiver)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenPrivateChannel);
    msg->addString(receiver);
    send(msg);
}

void ProtocolGame::sendOpenRuleViolation(const std::string_view reporter)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenRuleViolation);
    msg->addString(reporter);
    send(msg);
}

void ProtocolGame::sendCloseRuleViolation(const std::string_view reporter)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCloseRuleViolation);
    msg->addString(reporter);
    send(msg);
}

void ProtocolGame::sendCancelRuleViolation()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCancelRuleViolation);
    send(msg);
}

void ProtocolGame::sendCloseNpcChannel()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCloseNpcChannel);
    send(msg);
}

void ProtocolGame::sendChangeFightModes(const Otc::FightModes fightMode, const Otc::ChaseModes chaseMode, const bool safeFight, const Otc::PVPModes pvpMode)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientChangeFightModes);
    msg->addU8(fightMode);
    msg->addU8(chaseMode);
    msg->addU8(safeFight);
    if (g_game.getFeature(Otc::GamePVPMode))
        msg->addU8(pvpMode);
    send(msg);
}

void ProtocolGame::sendAttack(const uint32_t creatureId, const uint32_t seq)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientAttack);
    msg->addU32(creatureId);
    if (g_game.getFeature(Otc::GameAttackSeq))
        msg->addU32(seq);
    send(msg);
}

void ProtocolGame::sendFollow(const uint32_t creatureId, const uint32_t seq)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientFollow);
    msg->addU32(creatureId);
    if (g_game.getFeature(Otc::GameAttackSeq))
        msg->addU32(seq);
    send(msg);
}

void ProtocolGame::sendInviteToParty(const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInviteToParty);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendJoinParty(const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientJoinParty);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendRevokeInvitation(const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRevokeInvitation);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendPassLeadership(const uint32_t creatureId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPassLeadership);
    msg->addU32(creatureId);
    send(msg);
}

void ProtocolGame::sendLeaveParty()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLeaveParty);
    send(msg);
}

void ProtocolGame::sendShareExperience(const bool active)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientShareExperience);
    msg->addU8(active);
    if (g_game.getClientVersion() < 910)
        msg->addU8(0);
    send(msg);
}

void ProtocolGame::sendPartyAnalyzerAction(const uint8_t action, const std::vector<std::tuple<uint16_t, uint64_t>>& items)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPartyAnalyzerAction); // 43
    msg->addU8(action);

    // Only add items data for PARTYANALYZERACTION_PRICEVALUE (action 3)
    if (action == 3) { // PARTYANALYZERACTION_PRICEVALUE
        msg->addU16(static_cast<uint16_t>(items.size()));
        for (const auto& [itemId, price] : items) {
            msg->addU16(itemId);
            msg->addU64(price);
        }
    }

    send(msg);
}

void ProtocolGame::sendOpenOwnChannel()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenOwnChannel);
    send(msg);
}

void ProtocolGame::sendInviteToOwnChannel(const std::string_view name)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInviteToOwnChannel);
    msg->addString(name);
    send(msg);
}

void ProtocolGame::sendExcludeFromOwnChannel(const std::string_view name)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientExcludeFromOwnChannel);
    msg->addString(name);
    send(msg);
}

void ProtocolGame::sendCancelAttackAndFollow()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCancelAttackAndFollow);
    send(msg);
}

void ProtocolGame::sendRefreshContainer(const uint8_t containerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRefreshContainer);
    msg->addU8(containerId);
    send(msg);
}

void ProtocolGame::sendRequestBless()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestBless);
    send(msg);
}

void ProtocolGame::sendRequestTrackerQuestLog(const std::map<uint16_t, std::string>& quests)
{
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestTrackerQuestLog);
    msg->addU8(static_cast<uint8_t>(quests.size()));
    for (const auto& [questId, questName] : quests) {
        msg->addU16(questId);
        if (g_game.getClientVersion() >= 1410) {
            msg->addString(questName);
        }
    }
    send(msg);
}

void ProtocolGame::sendRequestOutfit()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestOutfit);
    send(msg);
}

void ProtocolGame::sendTyping(const bool typing)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::GameServerCreatureTyping);
    msg->addU8(typing);
    send(msg);
}

void ProtocolGame::sendChangeOutfit(const Outfit& outfit)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientChangeOutfit);

    if (g_game.getClientVersion() >= 1281) {
        msg->addU8(0x00); // normal outfit window
    }

    if (g_game.getFeature(Otc::GameLooktypeU16))
        msg->addU16(outfit.getId());
    else
        msg->addU8(static_cast<uint8_t>(outfit.getId()));

    msg->addU8(outfit.getHead());
    msg->addU8(outfit.getBody());
    msg->addU8(outfit.getLegs());
    msg->addU8(outfit.getFeet());

    if (g_game.getFeature(Otc::GamePlayerAddons))
        msg->addU8(outfit.getAddons());

    if (g_game.getFeature(Otc::GamePlayerMounts)) {
        msg->addU16(outfit.getMount());
        if (g_game.getClientVersion() >= 1281) {
            msg->addU8(0x00);
            msg->addU8(0x00);
            msg->addU8(0x00);
            msg->addU8(0x00);
        }
    }

    if (g_game.getClientVersion() >= 1334) {
        msg->addU8(outfit.hasMount());
    }

    if (g_game.getFeature(Otc::GamePlayerFamiliars)) {
        msg->addU16(outfit.getFamiliar()); //familiars
    }

    if (g_game.getClientVersion() >= 1281) {
        msg->addU8(0x00); //randomizeMount
    }
    if (g_game.getFeature(Otc::GameWingsAurasEffectsShader)) {
        msg->addU16(outfit.getWing());  // wings
        msg->addU16(outfit.getAura());  // auras
        msg->addU16(outfit.getEffect()); // effects
        msg->addString(outfit.getShader()); // shader
    }

    send(msg);
}

void ProtocolGame::sendMountStatus(const bool mount)
{
    if (g_game.getFeature(Otc::GamePlayerMounts)) {
        const auto& msg = std::make_shared<OutputMessage>();
        msg->addU8(Proto::ClientMount);
        msg->addU8(mount);
        send(msg);
    } else {
        g_logger.error("ProtocolGame::sendMountStatus does not support the current protocol.");
    }
}

void ProtocolGame::sendAddVip(const std::string_view name)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientAddVip);
    msg->addString(name);
    send(msg);
}

void ProtocolGame::sendRemoveVip(const uint32_t playerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRemoveVip);
    msg->addU32(playerId);
    send(msg);
}

void ProtocolGame::sendEditVip(const uint32_t playerId, const std::string_view description, const uint32_t iconId, const bool notifyLogin, const std::vector<uint8_t>& groupIDs)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEditVip);
    msg->addU32(playerId);
    msg->addString(description);
    msg->addU32(iconId);
    msg->addU8(notifyLogin);
    if (g_game.getFeature(Otc::GameVipGroups)) {
        msg->addU8(static_cast<uint8_t>(groupIDs.size()));
        for (const uint8_t groupID : groupIDs) {
            msg->addU8(groupID);
        }
    }
    send(msg);
}

void ProtocolGame::sendEditVipGroups(const Otc::GroupsEditInfoType_t action, const uint8_t groupId, const std::string_view groupName)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientEditVipGroups);
    msg->addU8(action);
    switch (action) {
        case Otc::VIP_GROUP_ADD: {
            msg->addString(groupName);
            break;
        }
        case Otc::VIP_GROUP_EDIT: {
            msg->addU8(groupId);
            msg->addString(groupName);
            break;
        }
        case Otc::VIP_GROUP_REMOVE: {
            msg->addU8(groupId);
            break;
        }
        default: {
            return;
        }
    }
    send(msg);
}

void ProtocolGame::sendBugReport(const std::string_view comment)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBugReport);
    if (g_game.getProtocolVersion() > 1000) {
        msg->addU8(3); // category
    }
    msg->addString(comment);
    send(msg);
}

void ProtocolGame::sendRuleViolation(const std::string_view target, const uint8_t reason, const uint8_t action, const std::string_view comment, const std::string_view statement, const uint16_t statementId, const bool ipBanishment)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWheelGemAction); // usado em gemas, desabilitado para ClientRuleViolation
    msg->addString(target);
    msg->addU8(reason);
    msg->addU8(action);
    msg->addString(comment);
    msg->addString(statement);
    msg->addU16(statementId);
    msg->addU8(ipBanishment);
    send(msg);
}

void ProtocolGame::sendWheelGemAction(uint8_t actionType, uint8_t param, uint8_t pos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWheelGemAction); // 0xE7
    msg->addU8(actionType);
    msg->addU8(param);

    // Apenas "ImproveGrade" (actionType == 4) envia o byte extra
    if (actionType == 4)
        msg->addU8(pos);

    send(msg);

    // 🔍 Log de envio bem-sucedido
    g_logger.debug(fmt::format(
        "[Client Gem Action] sendWheelGemAction enviado com sucesso -> actionType={} param={} pos={}",
        static_cast<int>(actionType),
        static_cast<int>(param),
        static_cast<int>(pos)
    ));
}

void ProtocolGame::sendDebugReport(const std::string_view a, const std::string_view b, const std::string_view c, const std::string_view d)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientDebugReport);
    msg->addString(a);
    msg->addString(b);
    msg->addString(c);
    msg->addString(d);
    send(msg);
}

void ProtocolGame::sendRequestQuestLog()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestQuestLog);
    send(msg);
}

void ProtocolGame::sendRequestQuestLine(const uint16_t questId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestQuestLine);
    msg->addU16(questId);
    send(msg);
}

void ProtocolGame::sendNewNewRuleViolation(const uint8_t reason, const uint8_t action, const std::string_view characterName, const std::string_view comment, const std::string_view translation)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientNewRuleViolation);
    msg->addU8(reason);
    msg->addU8(action);
    msg->addString(characterName);
    msg->addString(comment);
    msg->addString(translation);
    send(msg);
}

void ProtocolGame::sendRequestItemInfo(const uint16_t itemId, const uint8_t subType, const uint8_t index)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestItemInfo);
    msg->addU8(subType);
    msg->addU16(itemId);
    msg->addU8(index);
    send(msg);
}

void ProtocolGame::sendAnswerModalDialog(const uint32_t dialog, const uint8_t button, const uint8_t choice)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientAnswerModalDialog);
    msg->addU32(dialog);
    msg->addU8(button);
    msg->addU8(choice);
    send(msg);
}

void ProtocolGame::sendBrowseField(const Position& position)
{
    if (!g_game.getFeature(Otc::GameBrowseField))
        return;

    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBrowseField);
    addPosition(msg, position);
    send(msg);
}

void ProtocolGame::sendSeekInContainer(const uint8_t containerId, const uint16_t index)
{
    if (!g_game.getFeature(Otc::GameContainerPagination))
        return;

    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientSeekInContainer);
    msg->addU8(containerId);
    msg->addU16(index);
    if (g_game.getFeature(Otc::GameContainerFilter)) {
        msg->addU8(0); // Filter
    }
    send(msg);
}

void ProtocolGame::sendInspectionNormalObject(const Position& position)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInspectionObject);
    msg->addU8(Otc::INSPECT_NORMALOBJECT);
    addPosition(msg, position);
    send(msg);
}

void ProtocolGame::sendInspectionObject(const Otc::InspectObjectTypes inspectionType, const uint16_t itemId, const uint8_t itemCount)
{
    if (inspectionType != Otc::INSPECT_NPCTRADE && inspectionType != Otc::INSPECT_CYCLOPEDIA) {
        return;
    }

    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientInspectionObject);
    msg->addU8(inspectionType);
    msg->addU16(itemId);
    msg->addU8(itemCount);
    send(msg);
}

void ProtocolGame::sendRequestBestiary()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBestiaryRequest);
    send(msg);
}

void ProtocolGame::sendRequestBestiaryOverview(const std::string_view catName, bool search, std::vector<uint16_t> raceIds)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBestiaryRequestOverview);
    msg->addU8(search ? 0x01 : 0x00);
    if (search) {
        msg->addU16(static_cast<uint16_t>(raceIds.size()));
        for (const uint16_t raceId : raceIds) {
            msg->addU16(raceId);
        }
    } else {
        msg->addString(catName);
    }
    send(msg);
}

void ProtocolGame::sendRequestBestiarySearch(const uint16_t raceId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBestiaryRequestSearch);
    msg->addU16(raceId);
    send(msg);
}

void ProtocolGame::sendBuyCharmRune(const uint8_t runeId, const uint8_t action, const uint16_t raceId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCyclopediaSendBuyCharmRune);
    msg->addU8(runeId);
    msg->addU8(action);
    msg->addU16(raceId);
    send(msg);
}

void ProtocolGame::sendCyclopediaRequestCharacterInfo(const uint32_t playerId, const Otc::CyclopediaCharacterInfoType_t characterInfoType, const uint16_t entriesPerPage, const uint16_t page)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCyclopediaRequestCharacterInfo);
    msg->addU32(playerId);
    msg->addU8(characterInfoType);

    if (characterInfoType == Otc::CYCLOPEDIA_CHARACTERINFO_RECENTDEATHS || characterInfoType == Otc::CYCLOPEDIA_CHARACTERINFO_RECENTPVPKILLS) {
        msg->addU16(entriesPerPage);
        msg->addU16(page);
    }

    send(msg);
}

void ProtocolGame::sendCyclopediaHouseAuction(const Otc::CyclopediaHouseAuctionType_t type, const uint32_t houseId, const uint32_t timestamp, const uint64_t bidValue, const std::string_view name)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCyclopediaHouseAuction);
    msg->addU8(type);

    switch (type) {
        case Otc::CYCLOPEDIA_HOUSE_TYPE_NONE:
            msg->addString(name); // townName
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_BID:
            msg->addU32(houseId);
            msg->addU64(bidValue);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_MOVEOUT:
            msg->addU32(houseId);
            msg->addU32(timestamp);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_TRANSFER:
            msg->addU32(houseId);
            msg->addU32(timestamp);
            msg->addString(name); // newOwner
            msg->addU64(bidValue);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_CANCEL_MOVEOUT:
            msg->addU32(houseId);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_CANCEL_TRANSFER:
            msg->addU32(houseId);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_ACCEPT_TRANSFER:
            msg->addU32(houseId);
            break;
        case Otc::CYCLOPEDIA_HOUSE_TYPE_REFECT_TRANSFER:
            msg->addU32(houseId);
            break;
    }

    send(msg);
}

void ProtocolGame::sendRequestBosstiaryInfo()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBosstiaryRequestInfo);
    send(msg);
}

void ProtocolGame::sendRequestBossSlootInfo()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBosstiaryRequestSlotInfo);
    send(msg);
}

void ProtocolGame::sendRequestBossSlotAction(const uint8_t action, const uint32_t raceId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBosstiaryRequestSlotAction);
    msg->addU8(action);
    msg->addU32(raceId);
    send(msg);
}

void ProtocolGame::sendStatusTrackerBestiary(const uint16_t raceId, const bool status)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBestiaryTrackerStatus);
    msg->addU16(raceId);
    msg->addU8(status);
    send(msg);
}

void ProtocolGame::sendBuyStoreOffer(const uint32_t offerId, const uint8_t action, const std::string_view& name, const uint8_t type, const std::string_view& location)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientBuyStoreOffer);
    msg->addU32(offerId);
    msg->addU8(action);
    if (action > 0 && action < 6) {
        msg->addString(name);
        if (action == 3 || action == 5) {
            msg->addU8(type);
        }
        if (action == 5) {
            msg->addString(location);
        }
    }
    send(msg);
}

void ProtocolGame::sendRequestTransactionHistory(const uint32_t page, const uint32_t entriesPerPage)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestTransactionHistory);
    if (g_game.getClientVersion() <= 1096) {
        msg->addU16(static_cast<uint16_t>(page));
        msg->addU32(entriesPerPage);
    } else {
        msg->addU32(page);
        msg->addU8(static_cast<uint8_t>(entriesPerPage));
    }

    send(msg);
}

void ProtocolGame::sendRequestStoreOffers(const std::string_view categoryName, const std::string_view subCategory, const uint8_t sortOrder, const uint8_t serviceType)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_CATEGORY);
    msg->addString(categoryName);
    msg->addString(subCategory);
    msg->addU8(sortOrder);
    msg->addU8(serviceType);
    send(msg);
}

void ProtocolGame::sendRequestStoreHome()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_HOME);
    send(msg);
}
void ProtocolGame::sendRequestStorePremiumBoost()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_PREMIUM_BOOST);
    msg->addU8(1);
    send(msg);
}

void ProtocolGame::sendRequestUsefulThings(const uint8_t offerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_USEFUL_THINGS);
    msg->addU8(offerId);
    send(msg);
}

void ProtocolGame::sendRequestStoreOfferById(uint32_t offerId, const uint8_t sortOrder, const uint8_t serviceType)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_OFFER);
    msg->addU32(offerId);
    msg->addU8(sortOrder);
    msg->addU8(serviceType);
    send(msg);
}

void ProtocolGame::sendRequestStoreSearch(const std::string_view searchText, const uint8_t sortOrder, const uint8_t serviceType)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestStoreOffers);
    msg->addU8(Otc::Store_Type_Actions_t::OPEN_SEARCH);
    msg->addString(searchText);
    msg->addU8(sortOrder);
    msg->addU8(serviceType);
    send(msg);
}

void ProtocolGame::sendOpenStore(const uint8_t serviceType, const std::string_view category)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenStore);

    if (g_game.getFeature(Otc::GameIngameStoreServiceType)) {
        msg->addU8(serviceType);
        msg->addString(category);
    }

    send(msg);
}

void ProtocolGame::sendTransferCoins(const std::string_view recipient, const uint16_t amount)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientTransferCoins);
    msg->addString(recipient);
    msg->addU32(amount); // the server receive in unit32
    send(msg);
}

void ProtocolGame::sendOpenTransactionHistory(const uint8_t entriesPerPage)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenTransactionHistory);
    msg->addU8(entriesPerPage);

    send(msg);
}

void ProtocolGame::sendChangeMapAwareRange(const uint8_t xrange, const uint8_t yrange)
{
    if (!g_game.getFeature(Otc::GameChangeMapAwareRange))
        return;

    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientChangeMapAwareRange);
    msg->addU8(xrange);
    msg->addU8(yrange);
    send(msg);
}

void ProtocolGame::addPosition(const OutputMessagePtr& msg, const Position& position)
{
    msg->addU16(position.x);
    msg->addU16(position.y);
    msg->addU8(position.z);
}

void ProtocolGame::sendMarketLeave()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMarketLeave);
    send(msg);
}

void ProtocolGame::sendMarketBrowse(const uint8_t browseId, const uint16_t browseType, const uint8_t tier)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMarketBrowse);
    if (g_game.getClientVersion() >= 1251) {
        msg->addU8(browseId);
        if (browseType > 0) {
            msg->addU16(browseType);
            // If browseId is 3 (browse item), send tier if item has classification
            if (browseId == 3) {
                const auto& thing = g_things.getThingType(browseType, ThingCategoryItem);
                if (thing && thing->getClassification() > 0) {
                    msg->addU8(tier);
                }
            }
        }
    } else {
        msg->addU16(browseType);
    }
    send(msg);
}

void ProtocolGame::sendMarketCreateOffer(const uint8_t type, const uint16_t itemId, const uint8_t itemTier, const uint16_t amount, const uint64_t price, const uint8_t anonymous)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMarketCreate);
    msg->addU8(type);
    msg->addU16(itemId);
    if (const auto& thing = g_things.getThingType(itemId, ThingCategoryItem)) {
        if (thing->getClassification() > 0) {
            msg->addU8(itemTier);
        }
    }
    msg->addU16(amount);
    msg->addU64(price);
    msg->addU8(anonymous);
    send(msg);
}

void ProtocolGame::sendMarketCancelOffer(const uint32_t timestamp, const uint16_t counter)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMarketCancel);
    msg->addU32(timestamp);
    msg->addU16(counter);
    send(msg);
}

void ProtocolGame::sendMarketAcceptOffer(const uint32_t timestamp, const uint16_t counter, const uint16_t amount)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientMarketAccept);
    msg->addU32(timestamp);
    msg->addU16(counter);
    msg->addU16(amount);
    send(msg);
}

void ProtocolGame::sendPreyAction(const uint8_t slot, const uint8_t actionType, const uint16_t index)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPreyAction);
    msg->addU8(slot);
    msg->addU8(actionType);
    if (actionType == 2 || actionType == 5) {
        msg->addU8(static_cast<uint8_t>(index));
    } else if (actionType == 4) {
        msg->addU16(index); // raceid
    }
    send(msg);
}

void ProtocolGame::sendPreyRequest()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPreyRequest);
    send(msg);
}

void ProtocolGame::sendOpenPortableForge() {
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientPreyRequest);
    send(msg);
}

void ProtocolGame::sendForgeRequest(Otc::ForgeAction_t actionType, bool convergence, uint16_t firstItemid, uint8_t firstItemTier, uint16_t secondItemId, bool improveChance, bool tierLoss) {
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientForgeEnter);
    msg->addU8(static_cast<uint8_t>(actionType));

    if (actionType == Otc::ForgeAction_t::FUSION || actionType == Otc::ForgeAction_t::TRANSFER) {
        msg->addU8(static_cast<uint8_t>(convergence));
        msg->addU16(firstItemid);
        msg->addU8(firstItemTier);
        msg->addU16(secondItemId);
        msg->addU8(static_cast<uint8_t>(improveChance));
        msg->addU8(static_cast<uint8_t>(tierLoss));
    }

    send(msg);
}

void ProtocolGame::sendForgeBrowseHistoryRequest(uint16_t page) {
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientForgeBrowseHistory);
    msg->addU8(page);
    send(msg);
}

void ProtocolGame::sendApplyImbuement(const uint8_t slot, const uint32_t imbuementId, const bool protectionCharm)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientApplyImbuement);
    msg->addU8(slot);
    msg->addU32(imbuementId);
    if (g_game.getClientVersion() < 1510) {
        msg->addU8(protectionCharm);
    }
    send(msg);
}

void ProtocolGame::sendClearImbuement(const uint8_t slot)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientClearImbuement);
    msg->addU8(slot);
    send(msg);
}

void ProtocolGame::sendCloseImbuingWindow()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientCloseImbuingWindow);
    send(msg);
}

void ProtocolGame::sendOpenRewardWall()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenRewardWall);
    send(msg);
}

void ProtocolGame::sendOpenRewardHistory()
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenRewardHistory);
    send(msg);
}

void ProtocolGame::sendGetRewardDaily(const uint8_t bonusShrine, const std::map<uint16_t, uint8_t>& items)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::sendGetRewardDaily);
    msg->addU8(bonusShrine);
    msg->addU8(items.size());
    for (const auto& [itemId, count] : items) {
        msg->addU16(itemId);
        msg->addU8(count);
    }
    send(msg);
}

void ProtocolGame::sendStashWithdraw(const uint16_t itemId, const uint32_t count, const uint8_t stackpos)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUseStash);
    msg->addU8(Otc::Supply_Stash_Actions_t::SUPPLY_STASH_ACTION_WITHDRAW);
    msg->addU16(itemId);
    msg->addU32(count);
    msg->addU8(stackpos);
    send(msg);
}

void ProtocolGame::sendStashStow(const Position& position, const uint16_t itemId, const uint32_t count, const uint8_t stackpos, const uint8_t action)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientUseStash);
    msg->addU8(action);
    addPosition(msg, position);
    msg->addU16(itemId);
    msg->addU8(stackpos);

    if (action == Otc::Supply_Stash_Actions_t::SUPPLY_STASH_ACTION_STOW_ITEM) {
        msg->addU32(count);
    }

    send(msg);
}

void ProtocolGame::sendHighscoreInfo(const uint8_t action, const uint8_t category, const uint32_t vocation, const std::string_view world, const uint8_t worldType, const uint8_t battlEye, const uint16_t page, const uint8_t totalPages)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientRequestHighscore);
    msg->addU8(action);
    msg->addU8(category);
    msg->addU32(vocation);
    msg->addString(world);
    msg->addU8(worldType);
    msg->addU8(battlEye);
    msg->addU16(page);
    msg->addU8(totalPages);
    send(msg);
}

void ProtocolGame::sendImbuementDurations(const bool isOpen)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientImbuementDurations);
    msg->addU8(isOpen);
    send(msg);
}

void ProtocolGame::sendOpenWheelOfDestiny(uint32_t playerId)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientOpenWheel);
    msg->addU32(playerId);
    g_logger.info("Sending Wheel of Destiny request for player ID {}", playerId);
    send(msg);
}

void ProtocolGame::sendApplyWheelOfDestiny(const std::vector<uint16_t>& wheelPointsVec, const std::vector<uint16_t>& activeGemsVec)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientSaveWheel);
    for (const uint16_t points : wheelPointsVec) {
        msg->addU16(points);
    }

    for (const uint16_t gem : activeGemsVec) {
        if (gem > 0) {
            msg->addU8(1);
            msg->addU16(gem);

        } else {
            msg->addU8(0);
        }
    }

    send(msg);
}

void ProtocolGame::sendQuickLoot(const uint8_t variant, const Position& pos, const uint16_t itemId, const uint8_t stackpos)
{
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientSendQuickLoot);
    if (g_game.getClientVersion() >= 1332) {
        msg->addU8(variant);
    }
    addPosition(msg, pos);
    if (variant != 2) {
        msg->addU16(itemId);
        msg->addU8(stackpos);
    }
    send(msg);
}

void ProtocolGame::requestQuickLootBlackWhiteList(const uint8_t filter, const uint16_t size, const std::vector<uint16_t>& listedItems)
{
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientQuickLootBlackWhitelist);
    msg->addU8(filter);
    msg->addU16(size);

    for (const uint16_t item : listedItems) {
        msg->addU16(item);
    }
    send(msg);
}

void ProtocolGame::openContainerQuickLoot(const uint8_t action, const uint8_t category, const Position& pos, const uint16_t itemId, const uint8_t stackpos, const bool useMainAsFallback)
{
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientLootContainer);
    msg->addU8(action);

    if (action == 0 || action == 4) {
        msg->addU8(category);
        addPosition(msg, pos);
        msg->addU16(itemId);
        msg->addU8(stackpos);
    } else if (action == 3) {
        msg->addU8(useMainAsFallback);
    } else if (action == 1 || action == 2 || action == 5 || action == 6) {
        msg->addU8(category);
    }
    send(msg);
}

void ProtocolGame::sendWeaponProficiencyAction(const uint8_t actionType, const uint16_t itemId)
{
    // Opcode 0xB3 (179) - Weapon Proficiency Action
    // actionType: 0 = request item info, 1 = request all items, 2 = reset perks, 3 = apply perks
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWeaponProficiency);
    msg->addU8(actionType);
    if (actionType == 0 || actionType == 2) {
        msg->addU16(itemId);
    }
    send(msg);
}

void ProtocolGame::sendWeaponProficiencyApply(const uint16_t itemId, const std::vector<std::pair<uint8_t, uint8_t>>& perks)
{
    // Opcode 0xB3 (179) - Weapon Proficiency Apply Perks
    // Structure: byte actionType (3), uint16 itemId, uint8 perksCount, [perksCount * {uint8 level, uint8 perkPosition}]
    const auto msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientWeaponProficiency);
    msg->addU8(3); // WEAPON_PROFICIENCY_APPLY_PERKS
    msg->addU16(itemId);
    msg->addU8(static_cast<uint8_t>(perks.size()));
    for (const auto& perk : perks) {
        // Server expects 0-indexed values and adds +1 internally
        // Lua sends 0-indexed values, so we pass them directly
        msg->addU8(perk.first);   // level (0-indexed)
        msg->addU8(perk.second);  // perkPosition (0-indexed)
    }
    send(msg);
}

void ProtocolGame::sendOpenWheel(uint32_t playerId) {  
    const auto& msg = std::make_shared<OutputMessage>();  
    msg->addU8(Proto::ClientOpenWheel); // 0x61  
    msg->addU32(playerId); // Adicionar o ID do jogador  
    send(msg);  
}

void ProtocolGame::sendApplyWheelPoints(const std::vector<uint16_t>& slotPoints,
                                        uint16_t greenGem, uint16_t redGem,
                                        uint16_t acquaGem, uint16_t purpleGem)
{
    const auto& msg = std::make_shared<OutputMessage>();
    msg->addU8(Proto::ClientSaveWheel); // 0x62 (ClientSaveWheel)
    g_logger.debug("[Wheel C++ Send] sendApplyWheelPoints iniciado");


    // Envia pontos por slot (36 slots válidos)
    for (int i = 0; i < 36; ++i) {
        uint16_t value = (i < static_cast<int>(slotPoints.size())) ? slotPoints[i] : 0;
        msg->addU16(value);
        g_logger.debug(fmt::format("  [Slot {:02d}] pontos={}", i, value));
    }

    // Gem Green
    msg->addU8(greenGem != UINT16_MAX ? 1 : 0);
    if (greenGem != UINT16_MAX) msg->addU16(greenGem);
    g_logger.debug(fmt::format("[Gem Green C++] hasGem={} gemId={}", greenGem != UINT16_MAX, greenGem));

    // Gem Red
    msg->addU8(redGem != UINT16_MAX ? 1 : 0);
    if (redGem != UINT16_MAX) msg->addU16(redGem);
    g_logger.debug(fmt::format("[Gem Red C++] hasGem={} gemId={}", redGem != UINT16_MAX, redGem));

    // Gem Acqua
    msg->addU8(acquaGem != UINT16_MAX ? 1 : 0);
    if (acquaGem != UINT16_MAX) msg->addU16(acquaGem);
    g_logger.debug(fmt::format("[Gem Acqua C++] hasGem={} gemId={}", acquaGem != UINT16_MAX, acquaGem));

    // Gem Purple
    msg->addU8(purpleGem != UINT16_MAX ? 1 : 0);
    if (purpleGem != UINT16_MAX) msg->addU16(purpleGem);
    g_logger.debug(fmt::format("[Gem Purple C++] hasGem={} gemId={}", purpleGem != UINT16_MAX, purpleGem));
    
    msg->addU8(0);
    g_logger.debug(fmt::format(
        "[Wheel C++ Send] Enviando apply: {} slots, gems(G={} R={} A={} P={})",
        slotPoints.size(), greenGem, redGem, acquaGem, purpleGem));

    g_logger.debug("[Wheel C++ Send] Enviando pacote de ApplyWheelPoints...");
    std::ostringstream oss;
    const auto& buffer = msg->getBuffer();
    const size_t length = msg->getMessageSize(); // usa o método existente
    for (size_t i = 0; i < length; ++i) {
        oss << fmt::format("{:02X} ", static_cast<uint8_t>(buffer[i]));
    }
    g_logger.debug(fmt::format("[WheelDebugHex] Pacote completo ({} bytes): {}", length, oss.str()));
    send(msg);
    g_logger.debug("[Wheel C++ Send] Pacote enviado com sucesso.");
}