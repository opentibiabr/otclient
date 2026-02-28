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

#include "soundeffect.h"
#include "soundmanager.h"

#include <framework/core/logger.h>

#include <AL/al.h>
#include <AL/alc.h>
#include <AL/efx-presets.h>
#include <AL/efx.h>

 /* Effect object functions */
static LPALGENEFFECTS alGenEffects;
static LPALDELETEEFFECTS alDeleteEffects;
static LPALISEFFECT alIsEffect;
static LPALEFFECTI alEffecti;
static LPALEFFECTIV alEffectiv;
static LPALEFFECTF alEffectf;
static LPALEFFECTFV alEffectfv;
static LPALGETEFFECTI alGetEffecti;
static LPALGETEFFECTIV alGetEffectiv;
static LPALGETEFFECTF alGetEffectf;
static LPALGETEFFECTFV alGetEffectfv;

/* Auxiliary Effect Slot object functions */
static LPALGENAUXILIARYEFFECTSLOTS alGenAuxiliaryEffectSlots;
static LPALDELETEAUXILIARYEFFECTSLOTS alDeleteAuxiliaryEffectSlots;
static LPALISAUXILIARYEFFECTSLOT alIsAuxiliaryEffectSlot;
static LPALAUXILIARYEFFECTSLOTI alAuxiliaryEffectSloti;
static LPALAUXILIARYEFFECTSLOTIV alAuxiliaryEffectSlotiv;
static LPALAUXILIARYEFFECTSLOTF alAuxiliaryEffectSlotf;
static LPALAUXILIARYEFFECTSLOTFV alAuxiliaryEffectSlotfv;
static LPALGETAUXILIARYEFFECTSLOTI alGetAuxiliaryEffectSloti;
static LPALGETAUXILIARYEFFECTSLOTIV alGetAuxiliaryEffectSlotiv;
static LPALGETAUXILIARYEFFECTSLOTF alGetAuxiliaryEffectSlotf;
static LPALGETAUXILIARYEFFECTSLOTFV alGetAuxiliaryEffectSlotfv;

// Remove duplicates from the EffectPresets map
const std::unordered_map<std::string, EFXEAXREVERBPROPERTIES> EffectPresets{
    // Basic Standard Presets
    {"generic", EFX_REVERB_PRESET_GENERIC},
    {"paddedCell", EFX_REVERB_PRESET_PADDEDCELL},
    {"room", EFX_REVERB_PRESET_ROOM},
    {"bathroom", EFX_REVERB_PRESET_BATHROOM},
    {"livingRoom", EFX_REVERB_PRESET_LIVINGROOM},
    {"stoneRoom", EFX_REVERB_PRESET_STONEROOM},
    {"auditorium", EFX_REVERB_PRESET_AUDITORIUM},
    {"concertHall", EFX_REVERB_PRESET_CONCERTHALL},
    {"cave", EFX_REVERB_PRESET_CAVE},
    {"arena", EFX_REVERB_PRESET_ARENA},
    {"hangar", EFX_REVERB_PRESET_HANGAR},
    {"carpetedHallway", EFX_REVERB_PRESET_CARPETEDHALLWAY},
    {"hallway", EFX_REVERB_PRESET_HALLWAY},
    {"stoneCorridor", EFX_REVERB_PRESET_STONECORRIDOR},
    {"alley", EFX_REVERB_PRESET_ALLEY},
    {"forest", EFX_REVERB_PRESET_FOREST},
    {"city", EFX_REVERB_PRESET_CITY},
    {"mountains", EFX_REVERB_PRESET_MOUNTAINS},
    {"quarry", EFX_REVERB_PRESET_QUARRY},
    {"plain", EFX_REVERB_PRESET_PLAIN},
    {"parkingLot", EFX_REVERB_PRESET_PARKINGLOT},
    {"sewerPipe", EFX_REVERB_PRESET_SEWERPIPE},
    {"underWater", EFX_REVERB_PRESET_UNDERWATER},
    {"drugged", EFX_REVERB_PRESET_DRUGGED},
    {"dizzy", EFX_REVERB_PRESET_DIZZY},
    {"psychotic", EFX_REVERB_PRESET_PSYCHOTIC},

    // Castle
    {"castleSmallRoom", EFX_REVERB_PRESET_CASTLE_SMALLROOM},
    {"castleMediumRoom", EFX_REVERB_PRESET_CASTLE_MEDIUMROOM},
    {"castleLargeRoom", EFX_REVERB_PRESET_CASTLE_LARGEROOM},
    {"castleHall", EFX_REVERB_PRESET_CASTLE_HALL},
    {"castleCupboard", EFX_REVERB_PRESET_CASTLE_CUPBOARD},
    {"castleCourtyard", EFX_REVERB_PRESET_CASTLE_COURTYARD},
    {"castleAlcove", EFX_REVERB_PRESET_CASTLE_ALCOVE},

    // Factory
    {"factoryHall", EFX_REVERB_PRESET_FACTORY_HALL},
    {"factoryShortPassage", EFX_REVERB_PRESET_FACTORY_SHORTPASSAGE},
    {"factoryLongPassage", EFX_REVERB_PRESET_FACTORY_LONGPASSAGE},
    {"factorySmallRoom", EFX_REVERB_PRESET_FACTORY_SMALLROOM},
    {"factoryMediumRoom", EFX_REVERB_PRESET_FACTORY_MEDIUMROOM},
    {"factoryLargeRoom", EFX_REVERB_PRESET_FACTORY_LARGEROOM},

    // Ice Palace
    {"icePalaceAlcove", EFX_REVERB_PRESET_ICEPALACE_ALCOVE},
    {"icePalaceHall", EFX_REVERB_PRESET_ICEPALACE_HALL},
    {"icePalaceLargeRoom", EFX_REVERB_PRESET_ICEPALACE_LARGEROOM},
    {"icePalaceMediumRoom", EFX_REVERB_PRESET_ICEPALACE_MEDIUMROOM},
    {"icePalaceSmallRoom", EFX_REVERB_PRESET_ICEPALACE_SMALLROOM},

    // Space Station
    {"spaceStationSmallRoom", EFX_REVERB_PRESET_SPACESTATION_SMALLROOM},
    {"spaceStationMediumRoom", EFX_REVERB_PRESET_SPACESTATION_MEDIUMROOM},
    {"spaceStationLargeRoom", EFX_REVERB_PRESET_SPACESTATION_LARGEROOM},
    {"spaceStationHall", EFX_REVERB_PRESET_SPACESTATION_HALL},
    {"spaceStationCupboard", EFX_REVERB_PRESET_SPACESTATION_CUPBOARD},
    {"spaceStationAlcove", EFX_REVERB_PRESET_SPACESTATION_ALCOVE},

    // Wooden
    {"woodenAlcove", EFX_REVERB_PRESET_WOODEN_ALCOVE},
    {"woodenHall", EFX_REVERB_PRESET_WOODEN_HALL},
    {"woodenCupboard", EFX_REVERB_PRESET_WOODEN_CUPBOARD},
    {"woodenSmallRoom", EFX_REVERB_PRESET_WOODEN_SMALLROOM},
    {"woodenMediumRoom", EFX_REVERB_PRESET_WOODEN_MEDIUMROOM},
    {"woodenLargeRoom", EFX_REVERB_PRESET_WOODEN_LARGEROOM},

    // Sports
    {"sportsEmptyStadium", EFX_REVERB_PRESET_SPORT_EMPTYSTADIUM},
    {"sportsSquashCourt", EFX_REVERB_PRESET_SPORT_SQUASHCOURT},
    {"sportsSmallSwimmingPool", EFX_REVERB_PRESET_SPORT_SMALLSWIMMINGPOOL},
    {"sportsLargeSwimmingPool", EFX_REVERB_PRESET_SPORT_LARGESWIMMINGPOOL},
    {"sportsGymnasium", EFX_REVERB_PRESET_SPORT_GYMNASIUM},
    {"sportsFullStadium", EFX_REVERB_PRESET_SPORT_FULLSTADIUM},
    {"sportsStadiumTannoy", EFX_REVERB_PRESET_SPORT_STADIUMTANNOY},

    // Prefabs
    {"prefabWorkshop", EFX_REVERB_PRESET_PREFAB_WORKSHOP},
    {"prefabSchoolroom", EFX_REVERB_PRESET_PREFAB_SCHOOLROOM},
    {"prefabOutHouse", EFX_REVERB_PRESET_PREFAB_OUTHOUSE},
    {"prefabCaravan", EFX_REVERB_PRESET_PREFAB_CARAVAN},
    {"prefabPractiseRoom", EFX_REVERB_PRESET_PREFAB_PRACTISEROOM},

    // Dome and Pipes
    {"domeTomb", EFX_REVERB_PRESET_DOME_TOMB},
    {"pipeSmall", EFX_REVERB_PRESET_PIPE_SMALL},
    {"domedSaintPauls", EFX_REVERB_PRESET_DOME_SAINTPAULS},
    {"pipeLongThin", EFX_REVERB_PRESET_PIPE_LONGTHIN},
    {"pipeLarge", EFX_REVERB_PRESET_PIPE_LARGE},
    {"pipeResonant", EFX_REVERB_PRESET_PIPE_RESONANT},

    // Outdoors
    {"outdoorsBackyard", EFX_REVERB_PRESET_OUTDOORS_BACKYARD},
    {"outdoorsRollingPlains", EFX_REVERB_PRESET_OUTDOORS_ROLLINGPLAINS},
    {"outdoorsDeepCanyon", EFX_REVERB_PRESET_OUTDOORS_DEEPCANYON},
    {"outdoorsCreek", EFX_REVERB_PRESET_OUTDOORS_CREEK},
    {"outdoorsValley", EFX_REVERB_PRESET_OUTDOORS_VALLEY},

    // Mood
    {"moodHeaven", EFX_REVERB_PRESET_MOOD_HEAVEN},
    {"moodHell", EFX_REVERB_PRESET_MOOD_HELL},
    {"moodMemory", EFX_REVERB_PRESET_MOOD_MEMORY},

    // Driving
    {"drivingCommentator", EFX_REVERB_PRESET_DRIVING_COMMENTATOR},
    {"drivingPitGarage", EFX_REVERB_PRESET_DRIVING_PITGARAGE},
    {"drivingFullGrandstand", EFX_REVERB_PRESET_DRIVING_FULLGRANDSTAND},
    {"drivingEmptyGrandstand", EFX_REVERB_PRESET_DRIVING_EMPTYGRANDSTAND},
    {"drivingTunnel", EFX_REVERB_PRESET_DRIVING_TUNNEL},

    // City
    {"cityStreets", EFX_REVERB_PRESET_CITY_STREETS},
    {"citySubway", EFX_REVERB_PRESET_CITY_SUBWAY},
    {"cityMuseum", EFX_REVERB_PRESET_CITY_MUSEUM},
    {"cityLibrary", EFX_REVERB_PRESET_CITY_LIBRARY},
    {"cityUnderpass", EFX_REVERB_PRESET_CITY_UNDERPASS},

    // Misc
    {"dustyRoom", EFX_REVERB_PRESET_DUSTYROOM},
    {"chapel", EFX_REVERB_PRESET_CHAPEL},
    {"smallWaterRoom", EFX_REVERB_PRESET_SMALLWATERROOM},
};

template <typename T>
T LoadProcAddress(const char* name) {
    const void* addr = alGetProcAddress(name);
    if (!addr) {
        g_logger.error("Failed to Load Proc Address during SoundEffect ctor for preset : {}", name);
    }
    return std::bit_cast<T>(addr); // reinterpret_cast<T>(addr); if it crashes, this is why
}

#define LOAD_PROC(x) x = LoadProcAddress<decltype(x)>(#x)

void SoundEffect::init(ALCdevice* device) {
    m_device = device;

    LOAD_PROC(alGenEffects);
    LOAD_PROC(alDeleteEffects);
    LOAD_PROC(alIsEffect);
    LOAD_PROC(alEffecti);
    LOAD_PROC(alEffectiv);
    LOAD_PROC(alEffectf);
    LOAD_PROC(alEffectfv);
    LOAD_PROC(alGetEffecti);
    LOAD_PROC(alGetEffectiv);
    LOAD_PROC(alGetEffectf);
    LOAD_PROC(alGetEffectfv);

    LOAD_PROC(alGenAuxiliaryEffectSlots);
    LOAD_PROC(alDeleteAuxiliaryEffectSlots);
    LOAD_PROC(alIsAuxiliaryEffectSlot);
    LOAD_PROC(alAuxiliaryEffectSloti);
    LOAD_PROC(alAuxiliaryEffectSlotiv);
    LOAD_PROC(alAuxiliaryEffectSlotf);
    LOAD_PROC(alAuxiliaryEffectSlotfv);
    LOAD_PROC(alGetAuxiliaryEffectSloti);
    LOAD_PROC(alGetAuxiliaryEffectSlotiv);
    LOAD_PROC(alGetAuxiliaryEffectSlotf);
    LOAD_PROC(alGetAuxiliaryEffectSlotfv);
}

SoundEffect::SoundEffect(ALCdevice* device) : m_device(device) {
    init(device);
    /* Query for Effect Extension */
    if (alcIsExtensionPresent(m_device, "ALC_EXT_EFX") == AL_FALSE) {
        g_logger.error("unable to locate OpenAl EFX extension");
    } else {
        if (!alGenEffects) {
            g_logger.error("unable to load OpenAl EFX extension");
            return;
        }
        const auto effects = std::make_unique<ALuint[]>(1);
        const auto slots = std::make_unique<ALuint[]>(1);
        alGenEffects(1, effects.get());
        alGenAuxiliaryEffectSlots(1, slots.get());
        // Check for errors
        if (alGetError() != AL_NO_ERROR) {
            g_logger.error("Failed to generate effects or slots");
            return;
        }
        m_effectId = effects[0];
        m_effectSlot = slots[0];
    }
    assert(alGetError() == AL_NO_ERROR);
}

SoundEffect::~SoundEffect()
{
    if (m_effectId != 0) {
        alDeleteEffects(1, &m_effectId);
        //alDeleteAuxiliaryEffectSlots(1, &m_effectSlot);
        const auto err = alGetError();
        if (err != AL_NO_ERROR) {
            g_logger.error("error while deleting sound effect: {}", alGetString(err));
        }
    }
    if (m_effectSlot != 0) {
        alDeleteAuxiliaryEffectSlots(1, &m_effectSlot);
        const auto err = alGetError();
        if (err != AL_NO_ERROR) {
            g_logger.error("error while deleting sound aux effect slot: {}", alGetString(err));
        }
    }
}

void SoundEffect::loadPreset(const EFXEAXREVERBPROPERTIES& preset)
{
    if (g_sounds.isEaxEnabled()) {
        g_logger.debug("Using EAX Reverb");

        /* EAX Reverb is available. Set the EAX effect type then load the
        * reverb properties. */
        alEffecti(m_effectId, AL_EFFECT_TYPE, AL_EFFECT_EAXREVERB);

        alEffectf(m_effectId, AL_EAXREVERB_DENSITY, preset.flDensity);
        alEffectf(m_effectId, AL_EAXREVERB_DIFFUSION, preset.flDiffusion);
        alEffectf(m_effectId, AL_EAXREVERB_GAIN, preset.flGain);
        alEffectf(m_effectId, AL_EAXREVERB_GAINHF, preset.flGainHF);
        alEffectf(m_effectId, AL_EAXREVERB_GAINLF, preset.flGainLF);
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_TIME, preset.flDecayTime);
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_HFRATIO, preset.flDecayHFRatio);
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_LFRATIO, preset.flDecayLFRatio);
        alEffectf(m_effectId, AL_EAXREVERB_REFLECTIONS_GAIN, preset.flReflectionsGain);
        alEffectf(m_effectId, AL_EAXREVERB_REFLECTIONS_DELAY, preset.flReflectionsDelay);
        alEffectfv(m_effectId, AL_EAXREVERB_REFLECTIONS_PAN, preset.flReflectionsPan);
        alEffectf(m_effectId, AL_EAXREVERB_LATE_REVERB_GAIN, preset.flLateReverbGain);
        alEffectf(m_effectId, AL_EAXREVERB_LATE_REVERB_DELAY, preset.flLateReverbDelay);
        alEffectfv(m_effectId, AL_EAXREVERB_LATE_REVERB_PAN, preset.flLateReverbPan);
        alEffectf(m_effectId, AL_EAXREVERB_ECHO_TIME, preset.flEchoTime);
        alEffectf(m_effectId, AL_EAXREVERB_ECHO_DEPTH, preset.flEchoDepth);
        alEffectf(m_effectId, AL_EAXREVERB_MODULATION_TIME, preset.flModulationTime);
        alEffectf(m_effectId, AL_EAXREVERB_MODULATION_DEPTH, preset.flModulationDepth);
        alEffectf(m_effectId, AL_EAXREVERB_AIR_ABSORPTION_GAINHF, preset.flAirAbsorptionGainHF);
        alEffectf(m_effectId, AL_EAXREVERB_HFREFERENCE, preset.flHFReference);
        alEffectf(m_effectId, AL_EAXREVERB_LFREFERENCE, preset.flLFReference);
        alEffectf(m_effectId, AL_EAXREVERB_ROOM_ROLLOFF_FACTOR, preset.flRoomRolloffFactor);
        alEffecti(m_effectId, AL_EAXREVERB_DECAY_HFLIMIT, preset.iDecayHFLimit);
    } else {
        g_logger.debug("Using Standard Reverb");

        /* No EAX Reverb. Set the standard reverb effect type then load the
         * available reverb properties. */
        alEffecti(m_effectId, AL_EFFECT_TYPE, AL_EFFECT_REVERB);

        alEffectf(m_effectId, AL_REVERB_DENSITY, preset.flDensity);
        alEffectf(m_effectId, AL_REVERB_DIFFUSION, preset.flDiffusion);
        alEffectf(m_effectId, AL_REVERB_GAIN, preset.flGain);
        alEffectf(m_effectId, AL_REVERB_GAINHF, preset.flGainHF);
        alEffectf(m_effectId, AL_REVERB_DECAY_TIME, preset.flDecayTime);
        alEffectf(m_effectId, AL_REVERB_DECAY_HFRATIO, preset.flDecayHFRatio);
        alEffectf(m_effectId, AL_REVERB_REFLECTIONS_GAIN, preset.flReflectionsGain);
        alEffectf(m_effectId, AL_REVERB_REFLECTIONS_DELAY, preset.flReflectionsDelay);
        alEffectf(m_effectId, AL_REVERB_LATE_REVERB_GAIN, preset.flLateReverbGain);
        alEffectf(m_effectId, AL_REVERB_LATE_REVERB_DELAY, preset.flLateReverbDelay);
        alEffectf(m_effectId, AL_REVERB_AIR_ABSORPTION_GAINHF, preset.flAirAbsorptionGainHF);
        alEffectf(m_effectId, AL_REVERB_ROOM_ROLLOFF_FACTOR, preset.flRoomRolloffFactor);
        alEffecti(m_effectId, AL_REVERB_DECAY_HFLIMIT, preset.iDecayHFLimit);
    }

    /* Update effect slot */
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
    assert(alGetError() == AL_NO_ERROR && "Failed to set effect slot");
}

void SoundEffect::setPreset(const std::string& presetName)
{
    const auto it = EffectPresets.find(presetName);
    if (it != EffectPresets.end()) {
        loadPreset(it->second);
    } else {
        g_logger.error("Failed to find preset: {}", presetName);
    }
}

void SoundEffect::setReverbDensity(const float density) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_DENSITY, density);
    } else {
        alEffectf(m_effectId, AL_REVERB_DENSITY, density);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbDiffusion(const float diffusion) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_DIFFUSION, diffusion);
    } else {
        alEffectf(m_effectId, AL_REVERB_DIFFUSION, diffusion);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbGain(const float gain) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_GAIN, gain);
    } else {
        alEffectf(m_effectId, AL_REVERB_GAIN, gain);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbGainHF(const float gainHF) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_GAINHF, gainHF);
    } else {
        alEffectf(m_effectId, AL_REVERB_GAINHF, gainHF);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbGainLF(const float gainLF) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_GAINLF, gainLF);
    }
}

void SoundEffect::setReverbDecayTime(const float decayTime) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_TIME, decayTime);
    } else {
        alEffectf(m_effectId, AL_REVERB_DECAY_TIME, decayTime);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbDecayHfRatio(const float decayHfRatio) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_HFRATIO, decayHfRatio);
    } else {
        alEffectf(m_effectId, AL_REVERB_DECAY_HFRATIO, decayHfRatio);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbDecayLfRatio(const float decayLfRatio) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_DECAY_LFRATIO, decayLfRatio);
    }
}

void SoundEffect::setReverbReflectionsGain(const float reflectionsGain) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_REFLECTIONS_GAIN, reflectionsGain);
    } else {
        alEffectf(m_effectId, AL_REVERB_REFLECTIONS_GAIN, reflectionsGain);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}

void SoundEffect::setReverbReflectionsDelay(const float reflectionsDelay) const {
    if (g_sounds.isEaxEnabled()) {
        alEffectf(m_effectId, AL_EAXREVERB_REFLECTIONS_DELAY, reflectionsDelay);
    } else {
        alEffectf(m_effectId, AL_REVERB_REFLECTIONS_DELAY, reflectionsDelay);
    }
    alAuxiliaryEffectSloti(m_effectSlot, AL_EFFECTSLOT_EFFECT, static_cast<ALint>(m_effectId));
}
