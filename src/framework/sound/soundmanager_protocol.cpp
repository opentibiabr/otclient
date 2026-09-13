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

#include "soundmanager.h"

#include <algorithm>
#include <cctype>

#include "soundsource.h"
#include "client/game.h"
#include "client/localplayer.h"
#include "framework/core/clock.h"
#include "framework/core/configmanager.h"

const ClientSoundEffect* SoundManager::getClientSoundEffect(const uint32_t id) const
{
    const auto it = m_clientSoundEffects.find(id);
    return it != m_clientSoundEffects.end() ? &it->second : nullptr;
}

ClientSoundType SoundManager::getSoundEffectType(uint32_t id)
{
    if (const auto* soundEffect = getClientSoundEffect(id))
        return soundEffect->type;
    return NUMERIC_SOUND_TYPE_UNKNOWN;
}

std::string SoundManager::getSettingValue(const std::string& key)
{
    const auto& settings = g_configs.getSettings();
    if (!settings)
        return {};

    return settings->getValue(key);
}

bool SoundManager::getBooleanSetting(const std::string& key, const bool defaultValue)
{
    auto value = getSettingValue(key);
    if (value.empty())
        return defaultValue;

    value.erase(value.begin(), std::find_if(value.begin(), value.end(), [](unsigned char c) { return !std::isspace(c); }));
    value.erase(std::find_if(value.rbegin(), value.rend(), [](unsigned char c) { return !std::isspace(c); }).base(), value.end());

    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (value == "true" || value == "1")
        return true;
    if (value == "false" || value == "0")
        return false;

    return defaultValue;
}

int SoundManager::getIntSetting(const std::string& key, const int defaultValue)
{
    auto value = getSettingValue(key);
    if (value.empty())
        return defaultValue;

    value.erase(value.begin(), std::find_if(value.begin(), value.end(), [](unsigned char c) { return !std::isspace(c); }));
    value.erase(std::find_if(value.rbegin(), value.rend(), [](unsigned char c) { return !std::isspace(c); }).base(), value.end());

    try {
        return std::stoi(value);
    } catch (...) {
        return defaultValue;
    }
}

int SoundManager::getProtocolVolumeSetting(const uint8_t soundSource, const ClientSoundType soundType)
{
    switch (soundType) {
        case NUMERIC_SOUND_TYPE_FOOD_AND_DRINK:
        case NUMERIC_SOUND_TYPE_ITEM_MOVEMENT:
            return m_protocolSoundSettings.itemsVolume;
        case NUMERIC_SOUND_TYPE_EVENT:
            return m_protocolSoundSettings.eventVolume;
        case NUMERIC_SOUND_TYPE_AMBIENCE_STREAM:
            return m_protocolSoundSettings.ambienceVolume;
        case NUMERIC_SOUND_TYPE_UI:
        case NUMERIC_SOUND_TYPE_WHISPER_WITHOUT_OPEN_CHAT:
        case NUMERIC_SOUND_TYPE_CHAT_MESSAGE:
        case NUMERIC_SOUND_TYPE_PARTY:
        case NUMERIC_SOUND_TYPE_VIP_LIST:
        case NUMERIC_SOUND_TYPE_RAID_ANNOUNCEMENT:
        case NUMERIC_SOUND_TYPE_SERVER_MESSAGE:
            return m_protocolSoundSettings.uiVolume;
        default:
            break;
    }

    switch (soundSource) {
        case 0:
        case 1:
            return m_protocolSoundSettings.ownBattleVolume;
        case 2:
            return m_protocolSoundSettings.otherPlayersVolume;
        case 3:
            return m_protocolSoundSettings.creatureVolume;
        default:
            return 100;
    }
}

void SoundManager::refreshProtocolSoundSettings()
{
    m_protocolSoundSettings.ownBattleVolume = getIntSetting("battleSoundOwnBattle", 100);
    m_protocolSoundSettings.otherPlayersVolume = getIntSetting("battleSoundOtherPlayers", 100);
    m_protocolSoundSettings.creatureVolume = getIntSetting("battleSoundCreature", 100);
    m_protocolSoundSettings.itemsVolume = getIntSetting("soundItems", 100);
    m_protocolSoundSettings.eventVolume = getIntSetting("soundEventVolume", 100);
    m_protocolSoundSettings.uiVolume = getIntSetting("soundUI", 100);
    m_protocolSoundSettings.ambienceVolume = getIntSetting("soundAmbience", 100);

    m_protocolSoundSettings.ownAttack = getBooleanSetting("battleSoundOwnBattleSubChannelsAttack", true);
    m_protocolSoundSettings.ownHealing = getBooleanSetting("battleSoundOwnBattleSoundSubChannelsHealing", true);
    m_protocolSoundSettings.ownSupport = getBooleanSetting("battleSoundOwnBattleSoundSubChannelsSupport", true);
    m_protocolSoundSettings.ownWeapons = getBooleanSetting("battleSoundOwnBattleSoundSubChannelsWeapons", true);
    m_protocolSoundSettings.othersAttack = getBooleanSetting("battleSoundOtherPlayersSubChannelsAttack", true);
    m_protocolSoundSettings.othersHealing = getBooleanSetting("battleSoundOtherPlayersSubChannelsHealing", true);
    m_protocolSoundSettings.othersSupport = getBooleanSetting("battleSoundOtherPlayersSubChannelsSupport", true);
    m_protocolSoundSettings.othersWeapons = getBooleanSetting("battleSoundOtherPlayersSubChannelsWeapons", true);
    m_protocolSoundSettings.creatureNoises = getBooleanSetting("battleSoundCreatureSubChannelsNoises", true);
    m_protocolSoundSettings.creatureNoisesDeath = getBooleanSetting("battleSoundCreatureSubChannelsNoisesDeath", true);
    m_protocolSoundSettings.creatureAttacksAndSpells = getBooleanSetting("battleSoundCreatureSubChannelsAttacksAndSpells", true);

    m_protocolSoundSettings.foodAndBeverages = getBooleanSetting("soundFoodAndBeverages", true);
    m_protocolSoundSettings.moveItem = getBooleanSetting("soundMoveItem", true);

    m_protocolSoundSettings.uiInteractions = getBooleanSetting("soundUIsubChannelsInteractions", true);
    m_protocolSoundSettings.uiJoinLeaveParty = getBooleanSetting("soundUIsubChannelsJoinLeaveParty", true);
    m_protocolSoundSettings.uiVipLoginLogout = getBooleanSetting("soundUIsubChannelsVipLoginLogout", true);

    m_protocolSoundSettings.notificationInteractions = getBooleanSetting("soundNotificationConsoleMessages", getBooleanSetting("soundNotificationUIInteractions", true));
    m_protocolSoundSettings.notificationParty = getBooleanSetting("soundNotificationsubChannelsParty", true);
    m_protocolSoundSettings.notificationGuild = getBooleanSetting("soundNotificationsubChannelsGuild", true);
    m_protocolSoundSettings.notificationLocalChat = getBooleanSetting("soundNotificationsubChannelsLocalChat", true);
    m_protocolSoundSettings.notificationPrivateMessages = getBooleanSetting("soundNotificationsubChannelsPrivateMessages", true);
    m_protocolSoundSettings.notificationNpc = getBooleanSetting("soundNotificationsubChannelsNPC", true);
    m_protocolSoundSettings.notificationGlobal = getBooleanSetting("soundNotificationsubChannelsGlobal", true);
    m_protocolSoundSettings.notificationTeamFinder = getBooleanSetting("soundNotificationsubChannelsTeamFinder", true);
    m_protocolSoundSettings.notificationRaidAnnouncements = getBooleanSetting("soundNotificationsubChannelsRaidAnnouncements", true);
    m_protocolSoundSettings.notificationSystemAnnouncements = getBooleanSetting("soundNotificationsubChannelsSystemAnnouncements", true);
}

bool SoundManager::isProtocolSubChannelEnabled(const uint8_t soundSource, const ClientSoundType soundType)
{
    // Item / consumable sounds
    if (soundType == NUMERIC_SOUND_TYPE_FOOD_AND_DRINK)
        return m_protocolSoundSettings.foodAndBeverages;

    if (soundType == NUMERIC_SOUND_TYPE_ITEM_MOVEMENT)
        return m_protocolSoundSettings.moveItem;

    // UI & Notification sounds
    if (soundType == NUMERIC_SOUND_TYPE_UI)
        return m_protocolSoundSettings.uiInteractions;

    if (soundType == NUMERIC_SOUND_TYPE_PARTY)
        return m_protocolSoundSettings.notificationParty && m_protocolSoundSettings.notificationInteractions;

    if (soundType == NUMERIC_SOUND_TYPE_VIP_LIST)
        return m_protocolSoundSettings.uiVipLoginLogout;

    if (soundType == NUMERIC_SOUND_TYPE_RAID_ANNOUNCEMENT)
        return m_protocolSoundSettings.notificationRaidAnnouncements && m_protocolSoundSettings.notificationInteractions;

    if (soundType == NUMERIC_SOUND_TYPE_SERVER_MESSAGE)
        return m_protocolSoundSettings.notificationSystemAnnouncements && m_protocolSoundSettings.notificationInteractions;

    if (soundType == NUMERIC_SOUND_TYPE_CHAT_MESSAGE)
        return m_protocolSoundSettings.notificationLocalChat && m_protocolSoundSettings.notificationInteractions;

    if (soundType == NUMERIC_SOUND_TYPE_WHISPER_WITHOUT_OPEN_CHAT)
        return m_protocolSoundSettings.notificationPrivateMessages && m_protocolSoundSettings.notificationInteractions;

    // Events and ambience
    if (soundType == NUMERIC_SOUND_TYPE_EVENT || soundType == NUMERIC_SOUND_TYPE_AMBIENCE_STREAM)
        return true;

    // Unknown or generic spells fallback
    if (soundType == NUMERIC_SOUND_TYPE_UNKNOWN || soundType == NUMERIC_SOUND_TYPE_SPELL_GENERIC)
        return true;

    // Battle / creature sub-channels
    switch (soundSource) {
        case 0: // global
            return true;
        case 1: // own
            switch (soundType) {
                case NUMERIC_SOUND_TYPE_SPELL_ATTACK:
                    return m_protocolSoundSettings.ownAttack;
                case NUMERIC_SOUND_TYPE_SPELL_HEALING:
                    return m_protocolSoundSettings.ownHealing;
                case NUMERIC_SOUND_TYPE_SPELL_SUPPORT:
                    return m_protocolSoundSettings.ownSupport;
                case NUMERIC_SOUND_TYPE_WEAPON_ATTACK:
                case NUMERIC_SOUND_TYPE_CREATURE_ATTACK:
                    return m_protocolSoundSettings.ownWeapons;
                case NUMERIC_SOUND_TYPE_CREATURE_NOISE:
                case NUMERIC_SOUND_TYPE_CREATURE_DEATH:
                    return true;
                default:
                    return true;
            }
        case 2: // others
            switch (soundType) {
                case NUMERIC_SOUND_TYPE_SPELL_ATTACK:
                    return m_protocolSoundSettings.othersAttack;
                case NUMERIC_SOUND_TYPE_SPELL_HEALING:
                    return m_protocolSoundSettings.othersHealing;
                case NUMERIC_SOUND_TYPE_SPELL_SUPPORT:
                    return m_protocolSoundSettings.othersSupport;
                case NUMERIC_SOUND_TYPE_WEAPON_ATTACK:
                case NUMERIC_SOUND_TYPE_CREATURE_ATTACK:
                    return m_protocolSoundSettings.othersWeapons;
                case NUMERIC_SOUND_TYPE_CREATURE_NOISE:
                    return m_protocolSoundSettings.creatureNoises;
                case NUMERIC_SOUND_TYPE_CREATURE_DEATH:
                    return m_protocolSoundSettings.creatureNoisesDeath;
                default:
                    return true;
            }
        case 3: // creatures
            switch (soundType) {
                case NUMERIC_SOUND_TYPE_CREATURE_NOISE:
                    return m_protocolSoundSettings.creatureNoises;
                case NUMERIC_SOUND_TYPE_CREATURE_DEATH:
                    return m_protocolSoundSettings.creatureNoisesDeath;
                case NUMERIC_SOUND_TYPE_CREATURE_ATTACK:
                case NUMERIC_SOUND_TYPE_SPELL_ATTACK:
                case NUMERIC_SOUND_TYPE_SPELL_HEALING:
                case NUMERIC_SOUND_TYPE_SPELL_SUPPORT:
                case NUMERIC_SOUND_TYPE_WEAPON_ATTACK:
                    return m_protocolSoundSettings.creatureAttacksAndSpells;
                default:
                    return true;
            }
        default:
            return true;
    }
}

bool SoundManager::shouldPlayProtocolSound(const uint8_t soundSource, const uint16_t soundEffectId)
{
    if (!isAudioEnabled())
        return false;

    const auto soundType = getSoundEffectType(soundEffectId);
    const auto volume = getProtocolVolumeSetting(soundSource, soundType);
    if (volume <= 1)
        return false;

    return isProtocolSubChannelEnabled(soundSource, soundType);
}

bool SoundManager::shouldSkipProtocolCooldown(const uint16_t soundEffectId)
{
    const auto now = g_clock.millis();

    if (now - m_lastCooldownCleanup > PROTOCOL_COOLDOWN_CLEANUP_MS) {
        for (auto it = m_protocolLastPlayedAt.begin(); it != m_protocolLastPlayedAt.end();) {
            if (now - it->second > PROTOCOL_COOLDOWN_CLEANUP_MS)
                it = m_protocolLastPlayedAt.erase(it);
            else
                ++it;
        }
        m_lastCooldownCleanup = now;
    }

    const auto it = m_protocolLastPlayedAt.find(soundEffectId);
    if (it != m_protocolLastPlayedAt.end() && now - it->second < PROTOCOL_COOLDOWN_MS)
        return true;

    m_protocolLastPlayedAt[soundEffectId] = now;
    return false;
}

std::optional<uint32_t> SoundManager::chooseProtocolAudioFileId(const uint16_t soundEffectId)
{
    const auto* soundEffect = getClientSoundEffect(soundEffectId);
    if (!soundEffect)
        return std::nullopt;

    if (soundEffect->soundId != 0 && soundEffect->randomSoundId.empty())
        return soundEffect->soundId;

    const auto& soundIds = soundEffect->randomSoundId;
    if (soundIds.empty())
        return std::nullopt;

    if (soundIds.size() == 1)
        return soundIds.front();

    std::uniform_int_distribution<size_t> randomIndex(0, soundIds.size() - 1);
    return soundIds[randomIndex(m_randomEngine)];
}

bool SoundManager::playProtocolAudioFileId(const uint32_t audioFileId, const Position& pos, const int channelId, const float volumeMultiplier)
{
    const auto& localPlayer = g_game.getLocalPlayer();
    if (!localPlayer || !pos.isMapPosition())
        return false;

    const Position playerPos = localPlayer->getPosition();
    if (!playerPos.isMapPosition())
        return false;

    const auto fileName = getAudioFileNameById(static_cast<int32_t>(audioFileId));
    if (fileName.empty())
        return false;

    const float distance = static_cast<float>(playerPos.distance(pos));
    if (distance > PROTOCOL_MAX_DISTANCE)
        return false;

    const float gain = std::max(0.001f, (1.0f - (distance / PROTOCOL_MAX_DISTANCE)) * volumeMultiplier);
    const float stereoBalance = std::clamp(static_cast<float>(pos.x - playerPos.x) / PROTOCOL_MAX_DISTANCE, -1.0f, 1.0f);

    const auto source = playChannelSound(channelId, buildProtocolSoundPath(fileName), 0, gain, 1.0f);
    if (!source)
        return false;

    source->setPosition(Point(stereoBalance, 0));
    return true;
}

void SoundManager::logProtocolDebug(const uint8_t soundSource, const uint16_t soundEffectId, const uint32_t audioFileId, const Position& pos, const int channelId, const float gain) const
{
    if (!m_debugProtocolSounds)
        return;

    const auto& localPlayer = g_game.getLocalPlayer();
    if (!localPlayer)
        return;

    const auto playerPos = localPlayer->getPosition();
    const auto distance = playerPos.distance(pos);
    g_logger.warning("============================");
    g_logger.warning("=== Debug Sound Playback ===");
    g_logger.warning("============================");
    g_logger.warning("soundSource={}, soundEffectId={}, audioFileId={}, channelId={}", soundSource, soundEffectId, audioFileId, channelId);
    g_logger.warning("soundPos=({}, {}, {}), playerPos=({}, {}, {})", pos.x, pos.y, pos.z, playerPos.x, playerPos.y, playerPos.z);
    g_logger.warning("distance={}, gain={}", distance, gain);
}

void SoundManager::playProtocolSoundMain(const uint8_t soundSource, const uint16_t soundEffectId, const Position& pos)
{
    if (!shouldPlayProtocolSound(soundSource, soundEffectId))
        return;

    if (shouldSkipProtocolCooldown(soundEffectId))
        return;

    const auto audioFileId = chooseProtocolAudioFileId(soundEffectId);
    if (!audioFileId)
        return;

    const auto soundType = getSoundEffectType(soundEffectId);
    const auto volume = getProtocolVolumeSetting(soundSource, soundType);
    const float volumeMultiplier = std::clamp(volume / 100.0f, 0.0f, 1.0f);

    if (!playProtocolAudioFileId(*audioFileId, pos, CHANNEL_EFFECT_MAIN, volumeMultiplier))
        return;

    const auto& localPlayer = g_game.getLocalPlayer();
    if (localPlayer && localPlayer->getPosition().isMapPosition() && pos.isMapPosition()) {
        const float distance = static_cast<float>(localPlayer->getPosition().distance(pos));
        const float gain = std::max(0.001f, (1.0f - (distance / PROTOCOL_MAX_DISTANCE)) * volumeMultiplier);
        recordProtocolDebugEvent(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_MAIN, gain, distance, false);
        if (m_debugProtocolSounds) {
            logProtocolDebug(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_MAIN, gain);
        }
    }
}

void SoundManager::playProtocolSoundSecondary(const uint8_t soundEnum, const uint8_t soundSource, const uint16_t soundEffectId, const Position& pos)
{
    (void)soundEnum;

    if (!shouldPlayProtocolSound(soundSource, soundEffectId))
        return;

    if (shouldSkipProtocolCooldown(soundEffectId))
        return;

    const auto audioFileId = chooseProtocolAudioFileId(soundEffectId);
    if (!audioFileId)
        return;

    const auto soundType = getSoundEffectType(soundEffectId);
    const auto volume = getProtocolVolumeSetting(soundSource, soundType);
    const float volumeMultiplier = std::clamp(volume / 100.0f, 0.0f, 1.0f);

    if (!playProtocolAudioFileId(*audioFileId, pos, CHANNEL_EFFECT_SECONDARY, volumeMultiplier))
        return;

    const auto& localPlayer = g_game.getLocalPlayer();
    if (localPlayer && localPlayer->getPosition().isMapPosition() && pos.isMapPosition()) {
        const float distance = static_cast<float>(localPlayer->getPosition().distance(pos));
        const float gain = std::max(0.001f, (1.0f - (distance / PROTOCOL_MAX_DISTANCE)) * volumeMultiplier);
        recordProtocolDebugEvent(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_SECONDARY, gain, distance, true);
        if (m_debugProtocolSounds) {
            logProtocolDebug(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_SECONDARY, gain);
        }
    }
}