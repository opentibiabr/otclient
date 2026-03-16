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
#include <nlohmann/json.hpp>
#ifdef FRAMEWORK_PROTOBUF
#include <sounds.pb.h>
#endif

#include "soundbuffer.h"
#include "soundchannel.h"
#include "soundeffect.h"
#include "soundfile.h"
#include "soundsource.h"
#include "streamsoundsource.h"
#include "combinedsoundsource.h"
#include "client/game.h"
#include "framework/core/asyncdispatcher.h"
#include "framework/core/clock.h"
#include "framework/core/garbagecollection.h"
#include "framework/core/resourcemanager.h"
#include "framework/util/stats.h"

#ifdef FRAMEWORK_PROTOBUF
using namespace otclient::protobuf;
#endif

using json = nlohmann::json;

SoundManager g_sounds;

void SoundManager::init()
{
#ifdef ANDROID
    // The alcOpenDevice call needs to be executed on Android main thread
    g_androidManager.attachToAppMainThread();
#endif

    m_device = alcOpenDevice(nullptr);
    if (!m_device) {
        g_logger.error("unable to open audio device");
        return;
    }

    m_context = alcCreateContext(m_device, nullptr);
    if (!m_context) {
        g_logger.error(fmt::format("unable to create audio context: {}", alcGetString(m_device, alcGetError(m_device))));
        return;
    }

    if (alcMakeContextCurrent(m_context) != ALC_TRUE) {
        g_logger.error(fmt::format("unable to make context current: {}", alcGetString(m_device, alcGetError(m_device))));
    }
}

void SoundManager::terminate()
{
    ensureContext();

    for (auto& streamFile : m_streamFiles) {
        auto& future = streamFile.second;
        future.wait();
    }
    m_streamFiles.clear();

    m_sources.clear();
    m_buffers.clear();
    m_channels.clear();

    m_audioEnabled = false;

    alcMakeContextCurrent(nullptr);

    if (m_context) {
        alcDestroyContext(m_context);
        m_context = nullptr;
    }

    if (m_device) {
        alcCloseDevice(m_device);
        m_device = nullptr;
    }
}

void SoundManager::poll()
{
    AutoStat s(STATS_MAIN, "PollSounds");
    static ticks_t lastUpdate = 0;
    static uint_fast8_t soundsErased = 0;

    const ticks_t now = g_clock.millis();

    if (now - lastUpdate < POLL_DELAY)
        return;

    lastUpdate = now;

    ensureContext();

    for (auto it = m_streamFiles.begin(); it != m_streamFiles.end();) {
        const auto& source = it->first;
        const auto& future = it->second;

        if (future.wait_for(std::chrono::seconds(0)) == std::future_status::ready) {
            const auto& sound = future.get();
            if (sound)
                source->setSoundFile(sound);
            else
                source->stop();

            it = m_streamFiles.erase(it);
        } else {
            ++it;
        }
    }

    for (auto it = m_sources.begin(); it != m_sources.end();) {
        const auto& source = *it;

        source->update();

        if (!source->isPlaying()) {
            ++soundsErased;
            it = m_sources.erase(it);
        } else
            ++it;
    }

    for (const auto& it : m_channels) {
        it.second->update();
    }

    if (m_context) {
        alcProcessContext(m_context);
    }

    // temp fix for memory leak
    if (soundsErased > 25) {
        soundsErased = 0;
        GarbageCollection::lua();
    }
}

void SoundManager::setAudioEnabled(const bool enable)
{
    if (m_audioEnabled == enable)
        return;

    m_audioEnabled = enable;
    if (!enable) {
        ensureContext();
        for (const auto& source : m_sources) {
            source->stop();
        }
    }
}

void SoundManager::preload(std::string filename)
{
    filename = resolveSoundFile(filename);

    const auto it = m_buffers.find(filename);
    if (it != m_buffers.end())
        return;

    ensureContext();
    const auto& soundFile = SoundFile::loadSoundFile(filename);

    // only keep small files
    if (!soundFile || soundFile->getSize() > MAX_CACHE_SIZE)
        return;

    const auto& buffer = std::make_shared<SoundBuffer>();
    if (buffer->fillBuffer(soundFile))
        m_buffers[filename] = buffer;
}

SoundSourcePtr SoundManager::play(const std::string& fn, const float fadetime, float gain, float pitch)
{
    if (!m_audioEnabled)
        return nullptr;

    ensureContext();

    if (gain == 0)
        gain = 1.0f;

    if (pitch == 0)
        pitch = 1.0f;

    const std::string& filename = resolveSoundFile(fn);
    const auto& soundSource = createSoundSource(filename);
    if (!soundSource) {
        g_logger.error("unable to play '{}'", filename);
        return nullptr;
    }

    soundSource->setName(filename);
    soundSource->setRelative(true);
    soundSource->setGain(gain);
    soundSource->setPitch(pitch);

    if (fadetime > 0)
        soundSource->setFading(StreamSoundSource::FadingOn, fadetime);

    soundSource->play();

    m_sources.emplace_back(soundSource);

    return soundSource;
}

SoundChannelPtr SoundManager::getChannel(int channel)
{
    ensureContext();
    if (!m_channels[channel])
        m_channels[channel] = std::make_shared<SoundChannel>(channel);
    return m_channels[channel];
}

void SoundManager::stopAll()
{
    ensureContext();
    for (const auto& source : m_sources) {
        source->stop();
    }

    for (const auto& it : m_channels) {
        it.second->stop();
    }
}

SoundSourcePtr SoundManager::createSoundSource(const std::string& name)
{
    SoundSourcePtr source;

    try {
        const std::string& filename = resolveSoundFile(name);
        const auto it = m_buffers.find(filename);
        if (it != m_buffers.end()) {
            source = std::make_shared<SoundSource>();
            source->setBuffer(it->second);
        } else {
#if defined __linux && !defined OPENGL_ES
            // due to OpenAL implementation bug, stereo buffers are always downmixed to mono on linux systems
            // this is hack to work around the issue
            // solution taken from http://opensource.creative.com/pipermail/openal/2007-April/010355.html
            const auto& combinedSource = std::make_shared<CombinedSoundSource>();
            StreamSoundSourcePtr streamSource;

            streamSource = std::make_shared<StreamSoundSource>();
            streamSource->downMix(StreamSoundSource::DownMixLeft);
            streamSource->setRelative(true);
            streamSource->setPosition(Point(-128, 0));
            combinedSource->addSource(streamSource);
            m_streamFiles[streamSource] = g_asyncDispatcher.submit_task([=]() -> SoundFilePtr {
                stdext::timer a;
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch (std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });

            streamSource = std::make_shared<StreamSoundSource>();
            streamSource->downMix(StreamSoundSource::DownMixRight);
            streamSource->setRelative(true);
            streamSource->setPosition(Point(128, 0));
            combinedSource->addSource(streamSource);
            m_streamFiles[streamSource] = g_asyncDispatcher.submit_task([=]() -> SoundFilePtr {
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch (std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });

            source = combinedSource;
#else
            const auto& streamSource = std::make_shared<StreamSoundSource>();
            m_streamFiles[streamSource] = g_asyncDispatcher.submit_task([=]() -> SoundFilePtr {
                try {
                    return SoundFile::loadSoundFile(filename);
                } catch (std::exception& e) {
                    g_logger.error(e.what());
                    return nullptr;
                }
            });
            source = streamSource;
#endif
        }
    } catch (std::exception& e) {
        g_logger.error("failed to load sound source: '{}'", e.what());
        return nullptr;
    }

    return source;
}

std::string SoundManager::resolveSoundFile(const std::string& file)
{
    std::string _file = g_resources.guessFilePath(file, "ogg");
    _file = g_resources.resolvePath(_file);
    return _file;
}

void SoundManager::ensureContext() const
{
    if (m_context)
        alcMakeContextCurrent(m_context);
}

void SoundManager::setPosition(const Point& pos)
{
    alListener3f(AL_POSITION, pos.x, pos.y, 0);
}

SoundEffectPtr SoundManager::createSoundEffect()
{
    auto soundEffect = std::make_shared<SoundEffect>(m_device);
    return soundEffect;
}

bool SoundManager::isEaxEnabled()
{
    if (alGetEnumValue("AL_EFFECT_EAXREVERB") != 0) {
        return true;
    }
    return false;
}

#ifdef FRAMEWORK_PROTOBUF
using ProtobufSoundFiles = google::protobuf::RepeatedPtrField<sounds::Sound>;
using ProtobufSoundEffects = google::protobuf::RepeatedPtrField<sounds::NumericSoundEffect>;
using ProtobufLocationAmbiences = google::protobuf::RepeatedPtrField<sounds::AmbienceStream>;
using ProtobufItemAmbiences = google::protobuf::RepeatedPtrField<sounds::AmbienceObjectStream>;
using ProtobufMusicTracks = google::protobuf::RepeatedPtrField<sounds::MusicTemplate>;
#endif

bool SoundManager::loadFromProtobuf(const std::string& directory, const std::string& fileName)
{
#ifdef FRAMEWORK_PROTOBUF
    /*
        * file structure
        <struct> Sounds
        |
        |
        | * audio file id -> audio file name (ogg)
        |-+- <vector> (Sound) sound
        | |----> (u32) id
        | |----> (string) filename (sound-abcd.ogg)
        | |----> (string) original_filename (unused)
        | |----> (bool) is_stream
        |
        |
        | * sound effect
        |-+- <vector> (NumericSoundEffect) numeric_sound_effect
        | |----> (u32) id (the id you request in sound effect packet)
        | |----> (enum - ENumericSoundType) numeric_sound_type
        | |-+--> (MinMaxFloat) random_pitch
        | | |------> (float) min
        | | |------> (float) max
        | |
        | |-+--> (MinMaxFloat) random_volume
        | | |------> (float) min
        | | |------> (float) max
        | |
        | |-+--> (SimpleSoundEffect) simple_sound_effect
        | | |------> (u32) sound_id (audio file id)
        | |
        | |-+--> (RandomSoundEffect) random_sound_effect
        |   |------> <vector> (u32) random_sound_id (audio file id)
        |
        |
        | * ambient sound for location (needs to be triggered with a packet)
        |-+- <vector> (AmbienceStream) ambience_stream
        | |----> (u32) id
        | |----> (u32) looping_sound_id (audio file id)
        | |-+--> <vector> (DelayedSoundEffect) delayed_effects
        |   |------> (u32) numeric_sound_effect_id (sound effect id)
        |   |------> (u32) delay_seconds
        |
        |
        | * sound of items placed on the map
        |-+- <vector> (AmbienceObjectStream) ambience_object_stream
        | |----> (u32) id (ID OF THIS EFFECT, NOT ITEM ID!)
        | |----> <vector> (u32) counted_appearance_types (ITEM CLIENT IDS that will have this sound, eg. waterfall or campfire)
        | |-+--> <vector> (AppearanceTypesCountSoundEffect) sound_effects
        | | |------> (u32) count (how many on the screen are required to trigger, eg. 3 are required for the swamp tiles to play sound)
        | | |------> (u32) looping_sound_id (audio file id)
        | |----> (u32) max_sound_distance (how far can it be heard)
        |
        |
        | * music for location (needs to be triggered with a packet)
        |-+- <vector> (MusicTemplate) music_template
          |----> (u32) id
          |----> (u32) sound_id (audio file id)
          |----> (enum - EMusicType) music_type
    */

    // create the sound bank from protobuf file
    try {
        std::stringstream fileInputStream;
        g_resources.readFileStream(g_resources.resolvePath(fmt::format("{}{}", directory, fileName)), fileInputStream);

        // read the soundbank
        auto protobufSounds = sounds::Sounds();
        if (!protobufSounds.ParseFromIstream(&fileInputStream)) {
            throw stdext::exception("Couldn't parse appearances lib.");
        }

        // deserialize audio files
        for (const auto& protobufAudioFile : protobufSounds.sound()) {
            m_clientSoundFiles[protobufAudioFile.id()] = protobufAudioFile.filename();
        }

        // deserialize sound effects
        for (const auto& protobufSoundEffect : protobufSounds.numeric_sound_effect()) {
            const auto& pitch = protobufSoundEffect.random_pitch();
            const auto& volume = protobufSoundEffect.random_volume();
            std::vector<uint32_t> randomSounds = {};
            if (protobufSoundEffect.has_random_sound_effect()) {
                for (const uint32_t& audioFileId : protobufSoundEffect.random_sound_effect().random_sound_id()) {
                    randomSounds.push_back(audioFileId);
                }
            }

            uint32_t effectId = protobufSoundEffect.id();
            m_clientSoundEffects.emplace(effectId, ClientSoundEffect{
                effectId,
                static_cast<ClientSoundType>(protobufSoundEffect.numeric_sound_type()),
                pitch.min_value(),
                pitch.max_value(),
                volume.max_value(),
                volume.max_value(),
                protobufSoundEffect.has_simple_sound_effect() ? protobufSoundEffect.simple_sound_effect().sound_id() : 0,
                std::move(randomSounds)
            });
        }

        // deserialize location ambients
        for (const auto& protobufLocationAmbient : protobufSounds.ambience_stream()) {
            uint32_t effectId = protobufLocationAmbient.id();
            DelayedSoundEffects effects = {};
            for (const auto& delayedEffect : protobufLocationAmbient.delayed_effects()) {
                effects.push_back({ delayedEffect.numeric_sound_effect_id(), delayedEffect.delay_seconds() });
            }

            m_clientAmbientEffects.emplace(effectId, ClientLocationAmbient{
                effectId,
                protobufLocationAmbient.looping_sound_id(),
                std::move(effects)
            });
        }

        // deserialize item ambients
        for (const auto& protobufItemAmbient : protobufSounds.ambience_object_stream()) {
            std::vector<uint32_t> itemClientIds = {};
            for (const auto& itemId : protobufItemAmbient.counted_appearance_types()) {
                itemClientIds.push_back(itemId);
            }

            ItemCountSoundEffects soundEffects = {};
            for (const auto& soundEffect : protobufItemAmbient.sound_effects()) {
                soundEffects.push_back({ soundEffect.looping_sound_id(), soundEffect.count() });
            }

            uint32_t effectId = protobufItemAmbient.id();
            m_clientItemAmbientEffects.emplace(effectId, ClientItemAmbient{
                effectId,
                std::move(itemClientIds),
                std::move(soundEffects)
            });
        }

        // deserialize music
        for (const auto& protobufMusicTemplate : protobufSounds.music_template()) {
            uint32_t effectId = protobufMusicTemplate.id();
            m_clientMusic.emplace(effectId, ClientMusic{
                effectId,
                protobufMusicTemplate.sound_id(),
                static_cast<ClientMusicType>(protobufMusicTemplate.music_type())
            });
        }

        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to load soundbank '{}': {}", fileName, e.what());
        return false;
    }
#else
    g_logger.error("Protobuf not supported in this build. Enable FRAMEWORK_PROTOBUF");
    return false;
#endif
}

bool SoundManager::loadClientFiles(const std::string& directory)
{
    // find catalog from json file
    try {
        json document = json::parse(g_resources.readFileContents(g_resources.resolvePath(g_resources.guessFilePath(directory + "catalog-sound", "json"))));
        for (const auto& obj : document) {
            const auto& type = obj["type"];
            if (type == "sounds") {
                // dat file encoded with protobuf
                loadFromProtobuf(directory, obj["file"]);
            }
        }

        return true;
    } catch (const std::exception& e) {
        if (g_game.getClientVersion() >= 1300) {
            g_logger.warning("Failed to load '{}' (Sounds): {}", directory, e.what());
        }

        return false;
    }
}

std::string SoundManager::getAudioFileNameById(int32_t audioFileId)
{
    if (m_clientSoundFiles.contains(audioFileId)) {
        return m_clientSoundFiles[audioFileId];
    }

    return "";
}
