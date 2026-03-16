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

#include "combinedsoundsource.h"

CombinedSoundSource::CombinedSoundSource() : SoundSource(0) {}

void CombinedSoundSource::addSource(const SoundSourcePtr& source)
{
    m_sources.emplace_back(source);
}

void CombinedSoundSource::play()
{
    for (const auto& source : m_sources)
        source->play();
}

void CombinedSoundSource::stop()
{
    for (const auto& source : m_sources)
        source->stop();
}

bool CombinedSoundSource::isBuffering()
{
    for (const auto& source : m_sources) {
        if (source->isBuffering())
            return true;
    }
    return false;
}

bool CombinedSoundSource::isPlaying()
{
    for (const auto& source : m_sources) {
        if (source->isPlaying())
            return true;
    }
    return false;
}

void CombinedSoundSource::setLooping(const bool looping)
{
    for (const auto& source : m_sources)
        source->setLooping(looping);
}

void CombinedSoundSource::setRelative(const bool relative)
{
    for (const auto& source : m_sources)
        source->setRelative(relative);
}

void CombinedSoundSource::setReferenceDistance(const float distance)
{
    for (const auto& source : m_sources)
        source->setReferenceDistance(distance);
}

void CombinedSoundSource::setGain(const float gain)
{
    for (const auto& source : m_sources)
        source->setGain(gain);
}

void CombinedSoundSource::setPitch(const float pitch)
{
    for (const auto& source : m_sources)
        source->setPitch(pitch);
}

void CombinedSoundSource::setPosition(const Point& pos)
{
    for (const auto& source : m_sources)
        source->setPosition(pos);
}

void CombinedSoundSource::setVelocity(const Point& velocity)
{
    for (const auto& source : m_sources)
        source->setVelocity(velocity);
}

void CombinedSoundSource::setFading(const FadeState state, const float fadetime)
{
    for (const auto& source : m_sources)
        source->setFading(state, fadetime);
}

void CombinedSoundSource::setEffect(const SoundEffectPtr soundEffect)
{
    for (const SoundSourcePtr& source : m_sources)
        source->setEffect(soundEffect);
}

void CombinedSoundSource::removeEffect()
{
    for (const SoundSourcePtr& source : m_sources)
        source->removeEffect();
}

void CombinedSoundSource::update()
{
    for (const auto& source : m_sources)
        source->update();
}