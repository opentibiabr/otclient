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

int SoundManager::getProtocolVolumeSetting(const uint8_t soundSource)
{
    switch (soundSource) {
        case 0:
        case 1:
            return m_protocolSoundSettings.ownBattleVolume;
        case 2:
            return m_protocolSoundSettings.otherPlayersVolume;
        case 3:
            return m_protocolSoundSettings.creatureVolume;
        default:
            return 0;
    }
}

void SoundManager::refreshProtocolSoundSettings()
{
    m_protocolSoundSettings.ownBattleVolume = getIntSetting("battleSoundOwnBattle", 100);
    m_protocolSoundSettings.otherPlayersVolume = getIntSetting("battleSoundOtherPlayers", 100);
    m_protocolSoundSettings.creatureVolume = getIntSetting("battleSoundCreature", 100);
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
}

bool SoundManager::isProtocolSubChannelEnabled(const uint8_t soundSource, const ClientSoundType soundType)
{
    switch (soundSource) {
        case 1: // own
            switch (soundType) {
                case NUMERIC_SOUND_TYPE_SPELL_ATTACK:
                    return m_protocolSoundSettings.ownAttack;
                case NUMERIC_SOUND_TYPE_SPELL_HEALING:
                    return m_protocolSoundSettings.ownHealing;
                case NUMERIC_SOUND_TYPE_SPELL_SUPPORT:
                    return m_protocolSoundSettings.ownSupport;
                case NUMERIC_SOUND_TYPE_WEAPON_ATTACK:
                    return m_protocolSoundSettings.ownWeapons;
                default:
                    return false;
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
                    return m_protocolSoundSettings.othersWeapons;
                case NUMERIC_SOUND_TYPE_CREATURE_NOISE:
                    return m_protocolSoundSettings.creatureNoises;
                default:
                    return false;
            }
        case 3: // creatures
            switch (soundType) {
                case NUMERIC_SOUND_TYPE_CREATURE_NOISE:
                    return m_protocolSoundSettings.creatureNoises;
                case NUMERIC_SOUND_TYPE_CREATURE_DEATH:
                    return m_protocolSoundSettings.creatureNoisesDeath;
                case NUMERIC_SOUND_TYPE_CREATURE_ATTACK:
                case NUMERIC_SOUND_TYPE_SPELL_ATTACK:
                case NUMERIC_SOUND_TYPE_WEAPON_ATTACK:
                    return m_protocolSoundSettings.creatureAttacksAndSpells;
                default:
                    return false;
            }
        default:
            return false;
    }
}

bool SoundManager::shouldPlayProtocolSound(const uint8_t soundSource, const uint16_t soundEffectId)
{
    if (!isAudioEnabled())
        return false;

    const auto volume = getProtocolVolumeSetting(soundSource);
    if (volume <= 1)
        return false;

    if (soundSource >= 1) {
        return isProtocolSubChannelEnabled(soundSource, getSoundEffectType(soundEffectId));
    }

    return soundSource == 0;
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

bool SoundManager::playProtocolAudioFileId(const uint32_t audioFileId, const Position& pos, const int channelId)
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

    const float gain = 1.0f - (distance / PROTOCOL_MAX_DISTANCE);
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

    if (!playProtocolAudioFileId(*audioFileId, pos, CHANNEL_EFFECT_MAIN))
        return;

    const auto& localPlayer = g_game.getLocalPlayer();
    if (localPlayer && localPlayer->getPosition().isMapPosition() && pos.isMapPosition()) {
        const float distance = static_cast<float>(localPlayer->getPosition().distance(pos));
        const float gain = 1.0f - (distance / PROTOCOL_MAX_DISTANCE);
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

    if (!playProtocolAudioFileId(*audioFileId, pos, CHANNEL_EFFECT_SECONDARY))
        return;

    const auto& localPlayer = g_game.getLocalPlayer();
    if (localPlayer && localPlayer->getPosition().isMapPosition() && pos.isMapPosition()) {
        const float distance = static_cast<float>(localPlayer->getPosition().distance(pos));
        const float gain = 1.0f - (distance / PROTOCOL_MAX_DISTANCE);
        recordProtocolDebugEvent(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_SECONDARY, gain, distance, true);
        if (m_debugProtocolSounds) {
            logProtocolDebug(soundSource, soundEffectId, *audioFileId, pos, CHANNEL_EFFECT_SECONDARY, gain);
        }
    }
}
