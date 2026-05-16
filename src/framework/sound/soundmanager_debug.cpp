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
#include <array>
#include <limits>
#include <unordered_map>
#include <unordered_set>

#include "soundchannel.h"
#include "soundsource.h"
#include "client/map.h"
#include "client/tile.h"
#include "client/thing.h"
#include "framework/core/clock.h"

namespace
{
    float getDebugActivity(const float gain)
    {
        return std::clamp(gain, 0.0f, 1.0f);
    }

    std::string classifySourceKind(const SoundDebugSourceState& state, const bool isAmbientSource)
    {
        if (isAmbientSource)
            return "item-ambient";

        switch (state.channelId) {
            case 1:
                return "music";
            case 2:
                return "ambient";
            case 3:
                return "protocol-main";
            case 10:
                return "ui";
            case 12:
                return "protocol-secondary";
            default:
                return state.channelId == 0 ? "direct" : "channel";
        }
    }
}

std::string SoundManager::getDebugChannelName(const int channelId)
{
    switch (channelId) {
        case 1:
            return "Music";
        case 2:
            return "Ambient";
        case 3:
            return "Effect";
        case 4:
            return "Spells";
        case 5:
            return "Item";
        case 6:
            return "Event";
        case 7:
            return "Own";
        case 8:
            return "Others";
        case 9:
            return "Creature";
        case 10:
            return "UI";
        case 11:
            return "Bot";
        case 12:
            return "Secondary";
        default:
            return "Direct";
    }
}

void SoundManager::cleanupProtocolDebugEvents(const uint64_t now)
{
    while (!m_recentProtocolDebugEvents.empty()) {
        const auto& event = m_recentProtocolDebugEvents.front();
        if (now - event.timestamp <= SOUND_DEBUG_EVENT_TTL_MS && m_recentProtocolDebugEvents.size() <= SOUND_DEBUG_EVENT_LIMIT)
            break;
        m_recentProtocolDebugEvents.pop_front();
    }
}

void SoundManager::recordProtocolDebugEvent(const uint8_t soundSource, const uint16_t soundEffectId, const uint32_t audioFileId, const Position& pos, const int channelId, const float gain, const float distance, const bool secondary)
{
    if (!pos.isMapPosition())
        return;

    const auto now = static_cast<uint64_t>(g_clock.millis());
    cleanupProtocolDebugEvents(now);

    SoundDebugEventState event;
    event.soundEffectId = soundEffectId;
    event.audioFileId = audioFileId;
    event.soundSource = soundSource;
    event.channelId = channelId;
    event.gain = std::max(0.0f, gain);
    event.distance = distance;
    event.timestamp = now;
    event.secondary = secondary;
    event.position = pos;
    event.fileName = getAudioFileNameById(static_cast<int32_t>(audioFileId));
    m_recentProtocolDebugEvents.emplace_back(std::move(event));

    while (m_recentProtocolDebugEvents.size() > SOUND_DEBUG_EVENT_LIMIT)
        m_recentProtocolDebugEvents.pop_front();
}

SoundDebugItemState SoundManager::buildDebugItemState(const uint32_t effectId, const AmbientEffectState& state) const
{
    SoundDebugItemState itemState;
    itemState.effectId = effectId;
    itemState.itemCount = state.itemCount;
    itemState.position = state.nearestPosition;
    itemState.distance = state.nearestDistance == std::numeric_limits<double>::max() ? 0.0f : static_cast<float>(state.nearestDistance);

    const auto ambientIt = m_clientItemAmbientEffects.find(effectId);
    if (ambientIt == m_clientItemAmbientEffects.end())
        return itemState;

    itemState.audioFileId = resolveItemAmbientAudioFileId(ambientIt->second, state.itemCount);
    if (itemState.audioFileId != 0)
        itemState.fileName = getAudioFileNameById(static_cast<int32_t>(itemState.audioFileId));

    const auto& tile = g_map.getTile(state.nearestPosition);
    if (!tile)
        return itemState;

    for (const auto& thing : tile->getThings()) {
        if (!thing || !thing->isItem())
            continue;

        const auto itemEffectsIt = m_itemAmbientEffectsByClientId.find(thing->getId());
        if (itemEffectsIt == m_itemAmbientEffectsByClientId.end())
            continue;

        if (std::find(itemEffectsIt->second.begin(), itemEffectsIt->second.end(), effectId) == itemEffectsIt->second.end())
            continue;

        itemState.itemId = static_cast<uint16_t>(thing->getId());
        break;
    }

    return itemState;
}

SoundDebugSnapshot SoundManager::getDebugSnapshot()
{
    SoundDebugSnapshot snapshot;
    snapshot.audioEnabled = isAudioEnabled();
    snapshot.debugMode = isDebugMode();
    snapshot.masterVolume = std::clamp(getIntSetting("soundMaster", 100), 0, 100);

    const auto now = static_cast<uint64_t>(g_clock.millis());
    cleanupProtocolDebugEvents(now);

    static constexpr std::array<int, 12> channelOrder{
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    };

    std::unordered_map<int, size_t> channelIndex;
    channelIndex.reserve(channelOrder.size());
    snapshot.channels.reserve(channelOrder.size());
    for (const int channelId : channelOrder) {
        SoundDebugChannelState channelState;
        channelState.id = channelId;
        channelState.name = getDebugChannelName(channelId);

        const auto channelIt = m_channels.find(channelId);
        if (channelIt != m_channels.end() && channelIt->second) {
            channelState.gain = channelIt->second->getGain();
            channelState.enabled = channelIt->second->isEnabled();
        }

        channelIndex[channelId] = snapshot.channels.size();
        snapshot.channels.emplace_back(std::move(channelState));
    }

    std::unordered_set<const SoundSource*> ambientSources;
    ambientSources.reserve(m_activeItemAmbientSources.size());
    for (const auto& [_, activeSource] : m_activeItemAmbientSources) {
        if (activeSource.source && activeSource.source->isPlaying())
            ambientSources.insert(activeSource.source.get());
    }

    snapshot.sources.reserve(m_sources.size());
    float totalActivity = 0.0f;
    for (const auto& source : m_sources) {
        if (!source || !source->isPlaying())
            continue;

        SoundDebugSourceState sourceState;
        sourceState.name = source->getName();
        sourceState.channelId = source->getChannel();
        sourceState.channelName = getDebugChannelName(sourceState.channelId);
        sourceState.gain = std::max(0.0f, source->getGain());
        sourceState.position = source->getPosition();
        sourceState.relative = source->isRelative();
        sourceState.looping = source->isLooping();
        sourceState.streaming = source->getSourceKind() == SoundSource::KindStreaming;
        sourceState.combined = source->getSourceKind() == SoundSource::KindCombined;
        sourceState.kind = classifySourceKind(sourceState, ambientSources.contains(source.get()));

        const float activity = getDebugActivity(sourceState.gain);
        totalActivity += activity;

        if (const auto it = channelIndex.find(sourceState.channelId); it != channelIndex.end()) {
            auto& channelState = snapshot.channels[it->second];
            ++channelState.activeSources;
            channelState.activity = std::min(1.0f, channelState.activity + activity);
        }

        snapshot.sources.emplace_back(std::move(sourceState));
    }

    std::sort(snapshot.sources.begin(), snapshot.sources.end(), [](const SoundDebugSourceState& left, const SoundDebugSourceState& right) {
        if (left.gain != right.gain)
            return left.gain > right.gain;
        if (left.channelId != right.channelId)
            return left.channelId < right.channelId;
        return left.name < right.name;
    });

    snapshot.totalSources = static_cast<uint32_t>(snapshot.sources.size());
    snapshot.masterActivity = std::min(1.0f, totalActivity);

    snapshot.items.reserve(m_ambientEffectStates.size());
    for (const auto& [effectId, state] : m_ambientEffectStates) {
        if (state.itemCount == 0 || !state.nearestPosition.isMapPosition())
            continue;

        snapshot.items.emplace_back(buildDebugItemState(effectId, state));
    }

    std::sort(snapshot.items.begin(), snapshot.items.end(), [](const SoundDebugItemState& left, const SoundDebugItemState& right) {
        if (left.distance != right.distance)
            return left.distance < right.distance;
        return left.itemCount > right.itemCount;
    });

    snapshot.events.reserve(m_recentProtocolDebugEvents.size());
    for (auto it = m_recentProtocolDebugEvents.rbegin(); it != m_recentProtocolDebugEvents.rend(); ++it) {
        auto event = *it;
        event.ageMs = now > event.timestamp ? static_cast<uint32_t>(now - event.timestamp) : 0;
        snapshot.events.emplace_back(std::move(event));
    }

    return snapshot;
}
