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
#include "soundmanager_types.h"

class StreamSoundSource;
class CombinedSoundSource;
class SoundFile;
class SoundBuffer;

// client location ambient parsed from the protobuf file
struct ClientLocationAmbient
{
    uint32_t clientId;
    uint32_t loopedAudioFileId;

    // vector of pairs, where the pair is:
    // < effect clientId, delay in seconds >
    DelayedSoundEffects delayedSoundEffects;
};

// client item ambient parsed from the protobuf file
struct ClientItemAmbient
{
    uint32_t id;
    std::vector<uint32_t> clientIds;
    uint32_t maxSoundDistance;

    // this is a very specific client mechanic
    // depending on how many items are on the game screen
    // a different looped ambient effect will be played
    // for example, configuration like this:
    // 1 -> 630
    // 5 -> 625
    // means that when there is one item on the screen, an audio file number 630 should play
    // once there are 5 of them, the client should play an audio file number 625
    ItemCountSoundEffects itemCountSoundEffects;
};

struct ClientMusic
{
    uint32_t id; // track id
    uint32_t audioFileId; // audio file id
    ClientMusicType musicType;
};

//@bindsingleton g_sounds
class SoundManager
{
    enum
    {
        MAX_CACHE_SIZE = 100000,
        POLL_DELAY = 100
    };
public:
    void init();
    void terminate();
    void poll();

    void setAudioEnabled(bool enable);
    bool isAudioEnabled() { return m_device && m_context && m_audioEnabled; }
    void enableAudio() { setAudioEnabled(true); }
    void disableAudio() { setAudioEnabled(false); }
    void stopAll();
    void setPosition(const Point& pos);
    bool isEaxEnabled();
    bool loadClientFiles(const std::string& directory);
    std::string getAudioFileNameById(int32_t audioFileId) const;
    std::vector<uint32_t> getRandomSoundIds(uint32_t id);
    ClientSoundType getSoundEffectType(uint32_t id);
    SoundDebugSnapshot getDebugSnapshot();
    void refreshProtocolSoundSettings();
    void playProtocolSoundMain(uint8_t soundSource, uint16_t soundEffectId, const Position& pos);
    void playProtocolSoundSecondary(uint8_t soundEnum, uint8_t soundSource, uint16_t soundEffectId, const Position& pos);
    void toggleDebugMode() { m_debugProtocolSounds = !m_debugProtocolSounds; }
    bool isDebugMode() const { return m_debugProtocolSounds; }
    void markItemAmbienceDirty() { m_itemAmbienceDirty = true; }
    void onItemTileChanged(const Position& pos);
    void onListenerPositionChanged(const Position& newPos, const Position& oldPos);
    void stopItemAmbience();
    void resetItemAmbience();
    void stopAllChannelsExcept(int excludedChannel);
    void playUiSoundById(int soundId);

    static constexpr int CHANNEL_MUSIC = 1;
    static constexpr int CHANNEL_AMBIENT = 2;
    static constexpr int CHANNEL_EFFECT_MAIN = 3;
    static constexpr int CHANNEL_UI = 10;
    static constexpr int CHANNEL_EFFECT_SECONDARY = 12;

    void preload(std::string filename);
    SoundSourcePtr play(const std::string& filename, float fadetime = 0, float gain = 0, float pitch = 0);
    SoundSourcePtr playChannelSound(int channelId, const std::string& filename, float fadetime = 0, float gain = 1.0f, float pitch = 1.0f);
    SoundChannelPtr getChannel(int channel);
    void stopChannelSounds(int channelId, const SoundSource* except = nullptr);
    SoundEffectPtr createSoundEffect();

    std::string resolveSoundFile(const std::string& file);
    void ensureContext() const;

private:
    struct ActiveItemAmbientSource
    {
        uint32_t audioFileId{ 0 };
        SoundSourcePtr source;
    };

    struct AmbientEffectState
    {
        uint32_t itemCount{ 0 };
        double nearestDistance{ std::numeric_limits<double>::max() };
        Position nearestPosition;
        bool keepActive{ false };
    };

    using TileEffectCounts = std::unordered_map<uint32_t, uint32_t>;
    using EffectTileCounts = std::unordered_map<Position, uint32_t, Position::Hasher>;

    struct TrackedAmbientTile
    {
        TileEffectCounts activeEffects;
        bool hasAmbientItems{ false };
        uint32_t minEffectDistance{ std::numeric_limits<uint32_t>::max() };
        uint32_t maxEffectDistance{ 0 };
    };

    struct ProtocolSoundSettings
    {
        int ownBattleVolume{ 100 };
        int otherPlayersVolume{ 100 };
        int creatureVolume{ 100 };
        bool ownAttack{ true };
        bool ownHealing{ true };
        bool ownSupport{ true };
        bool ownWeapons{ true };
        bool othersAttack{ true };
        bool othersHealing{ true };
        bool othersSupport{ true };
        bool othersWeapons{ true };
        bool creatureNoises{ true };
        bool creatureNoisesDeath{ true };
        bool creatureAttacksAndSpells{ true };
    };

    uint32_t resolveItemAmbientAudioFileId(const ClientItemAmbient& ambientEffect, uint32_t itemCount) const;
    uint32_t getItemAmbienceScanDistance() const;
    bool isWithinItemAmbienceRange(const Position& listenerPos, const Position& tilePos) const;
    bool shouldRescanTrackedAmbientTile(const TrackedAmbientTile& tileState, double previousDistance, double newDistance) const;
    void rebuildItemAmbience();
    void clearTrackedItemAmbience();
    TrackedAmbientTile scanTrackedAmbientTile(const Position& tilePos) const;
    void applyTrackedAmbientTile(const Position& tilePos, const TrackedAmbientTile& tileState);
    void applyAmbientEffectTileChange(uint32_t effectId, const Position& tilePos, uint32_t oldCount, uint32_t newCount);
    void updateTrackedAmbientTile(const Position& tilePos);
    void recalculateAmbientEffectNearest(uint32_t effectId);
    void updateAllAmbientNearestStates();
    void updateItemAmbienceSources();
    SoundDebugItemState buildDebugItemState(uint32_t effectId, const AmbientEffectState& state) const;
    static std::string getDebugChannelName(int channelId);
    void cleanupProtocolDebugEvents(uint64_t now);
    void recordProtocolDebugEvent(uint8_t soundSource, uint16_t soundEffectId, uint32_t audioFileId, const Position& pos, int channelId, float gain, float distance, bool secondary);
    std::string buildProtocolSoundPath(const std::string& fileName);
    void updateSoundPathPrefix();
    void stopItemAmbienceSource(uint32_t effectId);
    bool shouldPlayProtocolSound(uint8_t soundSource, uint16_t soundEffectId);
    bool isProtocolSubChannelEnabled(uint8_t soundSource, ClientSoundType soundType);
    int getProtocolVolumeSetting(uint8_t soundSource);
    static std::string getSettingValue(const std::string& key);
    static bool getBooleanSetting(const std::string& key, bool defaultValue);
    static int getIntSetting(const std::string& key, int defaultValue);
    bool shouldSkipProtocolCooldown(uint16_t soundEffectId);
    static constexpr float PROTOCOL_MAX_DISTANCE = 8.0f;
    static constexpr uint32_t PROTOCOL_COOLDOWN_MS = 1000;
    static constexpr uint32_t PROTOCOL_COOLDOWN_CLEANUP_MS = 10000;
    static constexpr uint32_t SOUND_DEBUG_EVENT_TTL_MS = 2500;
    static constexpr size_t SOUND_DEBUG_EVENT_LIMIT = 32;
    static constexpr uint32_t ITEM_AMBIENCE_DEFAULT_MAX_DISTANCE = 8;
    const ClientSoundEffect* getClientSoundEffect(uint32_t id) const;
    std::optional<uint32_t> chooseProtocolAudioFileId(uint16_t soundEffectId);
    bool playProtocolAudioFileId(uint32_t audioFileId, const Position& pos, int channelId);
    void logProtocolDebug(uint8_t soundSource, uint16_t soundEffectId, uint32_t audioFileId, const Position& pos, int channelId, float gain) const;

    SoundSourcePtr createSoundSource(const std::string& name);
    bool loadFromProtobuf(const std::string& directory, const std::string& fileName);

    ALCdevice* m_device{};
    ALCcontext* m_context{};
    ALuint m_effect;
    ALuint m_effectSlot;

    std::unordered_map<StreamSoundSourcePtr, std::shared_future<SoundFilePtr>> m_streamFiles;
    std::unordered_map<std::string, SoundBufferPtr> m_buffers;
    std::unordered_map<int, SoundChannelPtr> m_channels;
    std::unordered_map<std::string, SoundEffectPtr> m_effects;

    // soundbanks for protocol 13 and newer
    std::map<uint32_t, std::string> m_clientSoundFiles;
    std::map<uint32_t, ClientSoundEffect> m_clientSoundEffects;
    std::map<uint32_t, ClientLocationAmbient> m_clientAmbientEffects;
    std::map<uint32_t, ClientItemAmbient> m_clientItemAmbientEffects;
    std::map<uint32_t, ClientMusic> m_clientMusic;
    std::unordered_map<uint32_t, std::vector<uint32_t>> m_itemAmbientEffectsByClientId;
    std::unordered_map<Position, TrackedAmbientTile, Position::Hasher> m_trackedAmbientTiles;
    std::unordered_map<uint32_t, EffectTileCounts> m_effectTiles;
    std::unordered_map<uint32_t, ActiveItemAmbientSource> m_activeItemAmbientSources;
    std::unordered_map<uint32_t, AmbientEffectState> m_ambientEffectStates;
    std::unordered_set<Position, Position::Hasher> m_pendingDirtyTiles;

    std::vector<SoundSourcePtr> m_sources;
    bool m_audioEnabled{ true };
    bool m_itemAmbienceDirty{ false };
    bool m_itemAmbienceTilesDirty{ false };
    bool m_itemAmbienceListenerTracked{ false };
    uint32_t m_maxItemAmbientDistance{ 0 };
    Position m_itemAmbienceListenerPos;
    std::unordered_map<uint16_t, ticks_t> m_protocolLastPlayedAt;
    std::deque<SoundDebugEventState> m_recentProtocolDebugEvents;
    ticks_t m_lastCooldownCleanup{ 0 };
    bool m_debugProtocolSounds{ false };
    ProtocolSoundSettings m_protocolSoundSettings;
    std::string m_soundPathPrefix;
    int m_cachedProtocolVersion{ -1 };
    mutable std::mt19937 m_randomEngine{ std::random_device{}() };
};

extern SoundManager g_sounds;
