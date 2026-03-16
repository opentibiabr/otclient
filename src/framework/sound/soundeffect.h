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
#ifndef SOUNDEFFECT_H
#define SOUNDEFFECT_H

#include <AL/alc.h>
#include <AL/efx-presets.h>
#include <framework/luaengine/luaobject.h>

class SoundEffect final : public LuaObject
{
public:
    explicit SoundEffect(ALCdevice* device);
    ~SoundEffect() override;

    void init(ALCdevice* device);

    void setPreset(const std::string& presetName);
    void setReverbDensity(float density) const;
    void setReverbDiffusion(float diffusion) const;
    void setReverbGain(float gain) const;
    void setReverbGainHF(float gainHF) const;
    void setReverbGainLF(float gainLF) const;
    void setReverbDecayTime(float decayTime) const;
    void setReverbDecayHfRatio(float decayHfRatio) const;
    void setReverbDecayLfRatio(float decayLfRatio) const;
    void setReverbReflectionsGain(float reflectionsGain) const;
    void setReverbReflectionsDelay(float reflectionsDelay) const;

private:

    friend class SoundManager;
    friend class SoundSource;

    void loadPreset(const EFXEAXREVERBPROPERTIES& preset);

    ALCdevice* m_device;

    uint m_effectSlot = 0;
    uint m_effectId = 0;
};

#endif