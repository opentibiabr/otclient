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

using DelayedSoundEffect = std::pair<uint32_t, uint32_t>;
using DelayedSoundEffects = std::vector<DelayedSoundEffect>;
using ItemCountSoundEffect = std::pair<uint32_t, uint32_t>;
using ItemCountSoundEffects = std::vector<ItemCountSoundEffect>;

class StreamSoundSource;
class CombinedSoundSource;
class SoundFile;
class SoundBuffer;

enum ClientSoundType
{
    NUMERIC_SOUND_TYPE_UNKNOWN = 0,
    NUMERIC_SOUND_TYPE_SPELL_ATTACK = 1,
    NUMERIC_SOUND_TYPE_SPELL_HEALING = 2,
    NUMERIC_SOUND_TYPE_SPELL_SUPPORT = 3,
    NUMERIC_SOUND_TYPE_WEAPON_ATTACK = 4,
    NUMERIC_SOUND_TYPE_CREATURE_NOISE = 5,
    NUMERIC_SOUND_TYPE_CREATURE_DEATH = 6,
    NUMERIC_SOUND_TYPE_CREATURE_ATTACK = 7,
    NUMERIC_SOUND_TYPE_AMBIENCE_STREAM = 8,
    NUMERIC_SOUND_TYPE_FOOD_AND_DRINK = 9,
    NUMERIC_SOUND_TYPE_ITEM_MOVEMENT = 10,
    NUMERIC_SOUND_TYPE_EVENT = 11,
    NUMERIC_SOUND_TYPE_UI = 12,
    NUMERIC_SOUND_TYPE_WHISPER_WITHOUT_OPEN_CHAT = 13,
    NUMERIC_SOUND_TYPE_CHAT_MESSAGE = 14,
    NUMERIC_SOUND_TYPE_PARTY = 15,
    NUMERIC_SOUND_TYPE_VIP_LIST = 16,
    NUMERIC_SOUND_TYPE_RAID_ANNOUNCEMENT = 17,
    NUMERIC_SOUND_TYPE_SERVER_MESSAGE = 18,
    NUMERIC_SOUND_TYPE_SPELL_GENERIC = 19
};

enum ClientMusicType
{
    MUSIC_TYPE_UNKNOWN = 0,
    MUSIC_TYPE_MUSIC = 1,
    MUSIC_TYPE_MUSIC_IMMEDIATE = 2,
    MUSIC_TYPE_MUSIC_TITLE = 3,
};

// client sound effect parsed from the protobuf file
struct ClientSoundEffect
{
    uint32_t clientId;
    ClientSoundType type;
    float pitchMin;
    float pitchMax;
    float volumeMin;
    float volumeMax;
    uint32_t soundId = 0;
    std::vector<uint32_t> randomSoundId;
};

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
    std::string getAudioFileNameById(int32_t audioFileId);

    void preload(std::string filename);
    SoundSourcePtr play(const std::string& filename, float fadetime = 0, float gain = 0, float pitch = 0);
    SoundChannelPtr getChannel(int channel);
    SoundEffectPtr createSoundEffect();

    std::string resolveSoundFile(const std::string& file);
    void ensureContext() const;

private:
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

    std::vector<SoundSourcePtr> m_sources;
    bool m_audioEnabled{ true };
};

extern SoundManager g_sounds;
