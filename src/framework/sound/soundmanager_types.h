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
#include "client/position.h"

using DelayedSoundEffect = std::pair<uint32_t, uint32_t>;
using DelayedSoundEffects = std::vector<DelayedSoundEffect>;
using ItemCountSoundEffect = std::pair<uint32_t, uint32_t>;
using ItemCountSoundEffects = std::vector<ItemCountSoundEffect>;

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

struct SoundDebugChannelState
{
    int id{ 0 };
    std::string name;
    float gain{ 1.0f };
    bool enabled{ true };
    uint32_t activeSources{ 0 };
    float activity{ 0.0f };
};

struct SoundDebugSourceState
{
    std::string name;
    std::string channelName;
    std::string kind;
    int channelId{ 0 };
    float gain{ 0.0f };
    Point position;
    bool relative{ false };
    bool looping{ false };
    bool streaming{ false };
    bool combined{ false };
};

struct SoundDebugItemState
{
    uint16_t itemId{ 0 };
    uint32_t effectId{ 0 };
    uint32_t audioFileId{ 0 };
    uint32_t itemCount{ 0 };
    float distance{ 0.0f };
    Position position;
    std::string fileName;
};

struct SoundDebugEventState
{
    uint16_t soundEffectId{ 0 };
    uint32_t audioFileId{ 0 };
    uint8_t soundSource{ 0 };
    int channelId{ 0 };
    float gain{ 0.0f };
    float distance{ 0.0f };
    uint64_t timestamp{ 0 };
    uint32_t ageMs{ 0 };
    bool secondary{ false };
    Position position;
    std::string fileName;
};

struct SoundDebugSnapshot
{
    bool audioEnabled{ false };
    bool debugMode{ false };
    int masterVolume{ 100 };
    float masterActivity{ 0.0f };
    uint32_t totalSources{ 0 };
    std::vector<SoundDebugChannelState> channels;
    std::vector<SoundDebugSourceState> sources;
    std::vector<SoundDebugItemState> items;
    std::vector<SoundDebugEventState> events;
};
