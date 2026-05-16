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
#include <limits>
#include <unordered_set>

#include "soundchannel.h"
#include "soundsource.h"
#include "client/game.h"
#include "client/localplayer.h"
#include "client/map.h"
#include "client/tile.h"

void SoundManager::stopItemAmbienceSource(const uint32_t effectId)
{
    const auto it = m_activeItemAmbientSources.find(effectId);
    if (it == m_activeItemAmbientSources.end())
        return;

    if (it->second.source)
        it->second.source->stop();

    m_activeItemAmbientSources.erase(it);
}

void SoundManager::stopItemAmbience()
{
    for (const auto& entry : m_activeItemAmbientSources) {
        const auto& activeSource = entry.second;
        if (activeSource.source)
            activeSource.source->stop();
    }

    m_activeItemAmbientSources.clear();
}

void SoundManager::resetItemAmbience()
{
    stopItemAmbience();
    clearTrackedItemAmbience();
    m_itemAmbienceDirty = false;
    m_itemAmbienceTilesDirty = false;
    m_pendingDirtyTiles.clear();
}

uint32_t SoundManager::resolveItemAmbientAudioFileId(const ClientItemAmbient& ambientEffect, const uint32_t itemCount) const
{
    uint32_t selectedAudioFileId = 0;
    uint32_t selectedRequiredCount = 0;

    for (const auto& [audioFileId, requiredCount] : ambientEffect.itemCountSoundEffects) {
        if (itemCount >= requiredCount && requiredCount >= selectedRequiredCount) {
            selectedAudioFileId = audioFileId;
            selectedRequiredCount = requiredCount;
        }
    }

    return selectedAudioFileId;
}

uint32_t SoundManager::getItemAmbienceScanDistance() const
{
    return std::max<uint32_t>(m_maxItemAmbientDistance, ITEM_AMBIENCE_DEFAULT_MAX_DISTANCE);
}

bool SoundManager::isWithinItemAmbienceRange(const Position& listenerPos, const Position& tilePos) const
{
    return listenerPos.isMapPosition() &&
        tilePos.isMapPosition() &&
        listenerPos.z == tilePos.z &&
        listenerPos.distance(tilePos) <= static_cast<double>(getItemAmbienceScanDistance());
}

bool SoundManager::shouldRescanTrackedAmbientTile(const TrackedAmbientTile& tileState, const double previousDistance, const double newDistance) const
{
    if (!tileState.hasAmbientItems || tileState.minEffectDistance == std::numeric_limits<uint32_t>::max())
        return false;

    if (previousDistance <= static_cast<double>(tileState.minEffectDistance) &&
        newDistance <= static_cast<double>(tileState.minEffectDistance)) {
        return false;
    }

    if (previousDistance > static_cast<double>(tileState.maxEffectDistance) &&
        newDistance > static_cast<double>(tileState.maxEffectDistance)) {
        return false;
    }

    return true;
}

void SoundManager::clearTrackedItemAmbience()
{
    m_trackedAmbientTiles.clear();
    m_effectTiles.clear();
    m_ambientEffectStates.clear();
    m_itemAmbienceListenerPos = {};
    m_itemAmbienceListenerTracked = false;
}

SoundManager::TrackedAmbientTile SoundManager::scanTrackedAmbientTile(const Position& tilePos) const
{
    TrackedAmbientTile tileState;
    if (!m_itemAmbienceListenerTracked || !isWithinItemAmbienceRange(m_itemAmbienceListenerPos, tilePos))
        return tileState;

    const auto& tile = g_map.getTile(tilePos);
    if (!tile)
        return tileState;

    const auto distance = m_itemAmbienceListenerPos.distance(tilePos);
    for (const auto& thing : tile->getThings()) {
        if (!thing || !thing->isItem())
            continue;

        const auto itemEffectsIt = m_itemAmbientEffectsByClientId.find(thing->getId());
        if (itemEffectsIt == m_itemAmbientEffectsByClientId.end())
            continue;

        tileState.hasAmbientItems = true;
        for (const uint32_t effectId : itemEffectsIt->second) {
            const auto ambientIt = m_clientItemAmbientEffects.find(effectId);
            if (ambientIt == m_clientItemAmbientEffects.end())
                continue;

            const auto maxDistance = ambientIt->second.maxSoundDistance > 0 ? ambientIt->second.maxSoundDistance : ITEM_AMBIENCE_DEFAULT_MAX_DISTANCE;
            tileState.minEffectDistance = std::min(tileState.minEffectDistance, maxDistance);
            tileState.maxEffectDistance = std::max(tileState.maxEffectDistance, maxDistance);
            if (distance > maxDistance)
                continue;

            ++tileState.activeEffects[effectId];
        }
    }

    return tileState;
}

void SoundManager::recalculateAmbientEffectNearest(const uint32_t effectId)
{
    const auto stateIt = m_ambientEffectStates.find(effectId);
    if (stateIt == m_ambientEffectStates.end())
        return;

    auto& state = stateIt->second;
    state.nearestDistance = std::numeric_limits<double>::max();
    state.nearestPosition = {};

    const auto effectTilesIt = m_effectTiles.find(effectId);
    if (effectTilesIt == m_effectTiles.end())
        return;

    for (const auto& [tilePos, itemCount] : effectTilesIt->second) {
        if (itemCount == 0)
            continue;

        const auto distance = m_itemAmbienceListenerPos.distance(tilePos);
        if (distance < state.nearestDistance) {
            state.nearestDistance = distance;
            state.nearestPosition = tilePos;
        }
    }
}

void SoundManager::applyAmbientEffectTileChange(const uint32_t effectId, const Position& tilePos, const uint32_t oldCount, const uint32_t newCount)
{
    if (oldCount == newCount)
        return;

    auto stateIt = m_ambientEffectStates.find(effectId);
    if (stateIt == m_ambientEffectStates.end() && newCount > 0)
        stateIt = m_ambientEffectStates.emplace(effectId, AmbientEffectState{}).first;

    if (oldCount > 0) {
        auto effectTilesIt = m_effectTiles.find(effectId);
        if (effectTilesIt != m_effectTiles.end()) {
            if (newCount == 0)
                effectTilesIt->second.erase(tilePos);
            else
                effectTilesIt->second[tilePos] = newCount;

            if (effectTilesIt->second.empty())
                m_effectTiles.erase(effectTilesIt);
        }
    }

    if (newCount > 0)
        m_effectTiles[effectId][tilePos] = newCount;

    if (stateIt == m_ambientEffectStates.end())
        return;

    auto& state = stateIt->second;
    if (newCount >= oldCount)
        state.itemCount += newCount - oldCount;
    else
        state.itemCount -= oldCount - newCount;

    if (state.itemCount == 0) {
        m_ambientEffectStates.erase(stateIt);
        return;
    }

    if (newCount > 0) {
        const auto distance = m_itemAmbienceListenerPos.distance(tilePos);
        if (state.nearestDistance == std::numeric_limits<double>::max() || distance < state.nearestDistance || state.nearestPosition == tilePos) {
            state.nearestDistance = distance;
            state.nearestPosition = tilePos;
        }
    } else if (state.nearestPosition == tilePos) {
        recalculateAmbientEffectNearest(effectId);
    }
}

void SoundManager::applyTrackedAmbientTile(const Position& tilePos, const TrackedAmbientTile& tileState)
{
    const auto oldTileIt = m_trackedAmbientTiles.find(tilePos);
    const TileEffectCounts* oldActiveEffects = oldTileIt != m_trackedAmbientTiles.end() ? &oldTileIt->second.activeEffects : nullptr;

    std::unordered_set<uint32_t> processedEffectIds;
    processedEffectIds.reserve((oldActiveEffects ? oldActiveEffects->size() : 0) + tileState.activeEffects.size());

    if (oldActiveEffects) {
        for (const auto& [effectId, oldCount] : *oldActiveEffects) {
            const auto newCountIt = tileState.activeEffects.find(effectId);
            const auto newCount = newCountIt != tileState.activeEffects.end() ? newCountIt->second : 0;
            applyAmbientEffectTileChange(effectId, tilePos, oldCount, newCount);
            processedEffectIds.insert(effectId);
        }
    }

    for (const auto& [effectId, newCount] : tileState.activeEffects) {
        if (processedEffectIds.contains(effectId))
            continue;
        applyAmbientEffectTileChange(effectId, tilePos, 0, newCount);
    }

    if (!tileState.hasAmbientItems) {
        if (oldTileIt != m_trackedAmbientTiles.end())
            m_trackedAmbientTiles.erase(oldTileIt);
        return;
    }

    m_trackedAmbientTiles[tilePos] = tileState;
}

void SoundManager::updateTrackedAmbientTile(const Position& tilePos)
{
    applyTrackedAmbientTile(tilePos, scanTrackedAmbientTile(tilePos));
}

void SoundManager::updateAllAmbientNearestStates()
{
    for (auto& [effectId, state] : m_ambientEffectStates) {
        state.nearestDistance = std::numeric_limits<double>::max();
        state.nearestPosition = {};
    }

    for (const auto& [effectId, tileCounts] : m_effectTiles) {
        const auto stateIt = m_ambientEffectStates.find(effectId);
        if (stateIt == m_ambientEffectStates.end())
            continue;

        auto& state = stateIt->second;
        for (const auto& [tilePos, itemCount] : tileCounts) {
            if (itemCount == 0)
                continue;

            const auto distance = m_itemAmbienceListenerPos.distance(tilePos);
            if (distance < state.nearestDistance) {
                state.nearestDistance = distance;
                state.nearestPosition = tilePos;
            }
        }
    }
}

void SoundManager::updateItemAmbienceSources()
{
    if (!m_audioEnabled || !m_itemAmbienceListenerTracked) {
        stopItemAmbience();
        return;
    }

    if (!g_game.getLocalPlayer()) {
        stopItemAmbience();
        return;
    }

    if (!m_itemAmbienceListenerPos.isMapPosition()) {
        stopItemAmbience();
        return;
    }

    constexpr int ambientChannelId = CHANNEL_AMBIENT;
    float channelGain = 1.0f;
    if (const auto& ambientChannel = getChannel(ambientChannelId)) {
        if (!ambientChannel->isEnabled()) {
            stopItemAmbience();
            return;
        }

        channelGain = ambientChannel->getGain();
    }

    for (auto& [effectId, state] : m_ambientEffectStates)
        state.keepActive = false;

    for (auto& [effectId, state] : m_ambientEffectStates) {
        if (state.itemCount == 0) {
            stopItemAmbienceSource(effectId);
            continue;
        }

        const auto ambientIt = m_clientItemAmbientEffects.find(effectId);
        if (ambientIt == m_clientItemAmbientEffects.end()) {
            stopItemAmbienceSource(effectId);
            continue;
        }

        const auto& ambientEffect = ambientIt->second;
        const auto audioFileId = resolveItemAmbientAudioFileId(ambientEffect, state.itemCount);
        if (audioFileId == 0) {
            stopItemAmbienceSource(effectId);
            continue;
        }

        const auto fileName = getAudioFileNameById(static_cast<int32_t>(audioFileId));
        if (fileName.empty()) {
            stopItemAmbienceSource(effectId);
            continue;
        }

        const auto maxDistance = static_cast<float>(ambientEffect.maxSoundDistance > 0 ? ambientEffect.maxSoundDistance : ITEM_AMBIENCE_DEFAULT_MAX_DISTANCE);
        const auto gain = std::max(0.1f, 1.0f - static_cast<float>(state.nearestDistance / maxDistance)) * channelGain;
        const auto pan = std::clamp(static_cast<float>(state.nearestPosition.x - m_itemAmbienceListenerPos.x) / maxDistance, -1.0f, 1.0f);

        auto& activeSource = m_activeItemAmbientSources[effectId];
        if (!activeSource.source || !activeSource.source->isPlaying() || activeSource.audioFileId != audioFileId) {
            if (activeSource.source)
                activeSource.source->stop();

            const auto source = play(buildProtocolSoundPath(fileName), 0, gain, 1.0f);
            if (!source) {
                m_activeItemAmbientSources.erase(effectId);
                continue;
            }

            source->setLooping(true);
            source->setRelative(true);
            source->setChannel(static_cast<uint8_t>(ambientChannelId));
            source->setPosition(Point(pan, 0));

            activeSource.audioFileId = audioFileId;
            activeSource.source = source;
        } else {
            activeSource.source->setChannel(static_cast<uint8_t>(ambientChannelId));
            activeSource.source->setGain(gain);
            activeSource.source->setPosition(Point(pan, 0));
        }

        state.keepActive = true;
    }

    for (auto it = m_activeItemAmbientSources.begin(); it != m_activeItemAmbientSources.end();) {
        const auto stateIt = m_ambientEffectStates.find(it->first);
        if (stateIt != m_ambientEffectStates.end() && stateIt->second.keepActive) {
            ++it;
            continue;
        }

        if (it->second.source)
            it->second.source->stop();

        it = m_activeItemAmbientSources.erase(it);
    }
}

void SoundManager::rebuildItemAmbience()
{
    clearTrackedItemAmbience();

    if (!m_audioEnabled || m_clientItemAmbientEffects.empty() || m_itemAmbientEffectsByClientId.empty()) {
        stopItemAmbience();
        return;
    }

    const auto& localPlayer = g_game.getLocalPlayer();
    if (!localPlayer) {
        stopItemAmbience();
        return;
    }

    const auto listenerPos = localPlayer->getPosition();
    if (!listenerPos.isMapPosition()) {
        stopItemAmbience();
        return;
    }

    m_itemAmbienceListenerPos = listenerPos;
    m_itemAmbienceListenerTracked = true;

    const auto scanDistance = getItemAmbienceScanDistance();
    for (int32_t x = listenerPos.x - static_cast<int32_t>(scanDistance); x <= listenerPos.x + static_cast<int32_t>(scanDistance); ++x) {
        for (int32_t y = listenerPos.y - static_cast<int32_t>(scanDistance); y <= listenerPos.y + static_cast<int32_t>(scanDistance); ++y) {
            const Position tilePos{ x, y, listenerPos.z };
            if (!isWithinItemAmbienceRange(listenerPos, tilePos))
                continue;

            updateTrackedAmbientTile(tilePos);
        }
    }

    updateItemAmbienceSources();
}

void SoundManager::onItemTileChanged(const Position& pos)
{
    if (m_itemAmbienceDirty || !m_itemAmbienceListenerTracked || !m_audioEnabled || !pos.isMapPosition())
        return;

    m_pendingDirtyTiles.insert(pos);
    m_itemAmbienceTilesDirty = true;
}

void SoundManager::onListenerPositionChanged(const Position& newPos, const Position& oldPos)
{
    if (m_itemAmbienceDirty || !m_audioEnabled || m_clientItemAmbientEffects.empty() || m_itemAmbientEffectsByClientId.empty())
        return;

    if (!newPos.isMapPosition()) {
        resetItemAmbience();
        return;
    }

    if (!m_itemAmbienceListenerTracked || !m_itemAmbienceListenerPos.isMapPosition() || m_itemAmbienceListenerPos != oldPos) {
        m_itemAmbienceDirty = true;
        return;
    }

    if (newPos == oldPos)
        return;

    if (newPos.z != oldPos.z || newPos.distance(oldPos) > 1.5) {
        m_itemAmbienceDirty = true;
        return;
    }

    const auto previousListenerPos = m_itemAmbienceListenerPos;
    m_itemAmbienceListenerPos = newPos;

    // Evict tiles that left range. Tiles still in range don't need rescanning —
    // their item counts are already tracked incrementally via onItemTileChanged.
    // Only tiles that may have crossed an effect-specific maxSoundDistance
    // threshold need rescanning inside the tracked range.
    std::vector<Position> trackedPositions;
    trackedPositions.reserve(m_trackedAmbientTiles.size());
    for (const auto& [tilePos, _] : m_trackedAmbientTiles)
        trackedPositions.push_back(tilePos);

    for (const auto& tilePos : trackedPositions) {
        if (!isWithinItemAmbienceRange(newPos, tilePos))
            applyTrackedAmbientTile(tilePos, {});
        else if (const auto trackedTileIt = m_trackedAmbientTiles.find(tilePos); trackedTileIt != m_trackedAmbientTiles.end()) {
            const auto previousDistance = previousListenerPos.distance(tilePos);
            const auto newDistance = newPos.distance(tilePos);
            if (shouldRescanTrackedAmbientTile(trackedTileIt->second, previousDistance, newDistance))
                updateTrackedAmbientTile(tilePos);
        }
    }

    const auto scanDistance = getItemAmbienceScanDistance();
    for (int32_t x = newPos.x - static_cast<int32_t>(scanDistance); x <= newPos.x + static_cast<int32_t>(scanDistance); ++x) {
        for (int32_t y = newPos.y - static_cast<int32_t>(scanDistance); y <= newPos.y + static_cast<int32_t>(scanDistance); ++y) {
            const Position tilePos{ x, y, newPos.z };
            if (!isWithinItemAmbienceRange(newPos, tilePos) || isWithinItemAmbienceRange(previousListenerPos, tilePos))
                continue;

            updateTrackedAmbientTile(tilePos);
        }
    }

    updateAllAmbientNearestStates();
    updateItemAmbienceSources();
}
