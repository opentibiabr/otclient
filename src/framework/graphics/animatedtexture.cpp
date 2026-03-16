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

#include "animatedtexture.h"

#include "drawpoolmanager.h"
#include "framework/core/eventdispatcher.h"

AnimatedTexture::AnimatedTexture(const Size& size, const std::vector<ImagePtr>& frames, std::vector<uint16_t> framesDelay, const uint16_t numPlays, bool buildMipmaps, bool compress)
{
    if (!setupSize(size))
        return;

    for (const auto& frame : frames) {
        m_frames.emplace_back(std::make_shared<Texture>(frame, buildMipmaps, compress));
    }

    setProp(hasMipMaps, buildMipmaps);

    m_framesDelay = std::move(framesDelay);
    m_numPlays = numPlays;
    m_animTimer.restart();
}

void AnimatedTexture::buildHardwareMipmaps()
{
    if (getProp(hasMipMaps)) return;
    setProp(hasMipMaps, true);

    g_mainDispatcher.addEvent([this] {
        for (const auto& frame : m_frames)
            frame->buildHardwareMipmaps();
    });
}

void AnimatedTexture::setSmooth(bool smooth)
{
    setProp(Prop::smooth, smooth);
    g_mainDispatcher.addEvent([this, smooth] {
        for (const auto& frame : m_frames)
            frame->setSmooth(smooth);
    });
}

void AnimatedTexture::setRepeat(bool repeat)
{
    setProp(Prop::repeat, repeat);
    g_mainDispatcher.addEvent([this, repeat] {
        for (const auto& frame : m_frames)
            frame->setRepeat(repeat);
    });
}

TexturePtr AnimatedTexture::get(uint32_t& frame, Timer& timer) {
    if (timer.ticksElapsed() >= m_framesDelay[frame]) {
        timer.restart();

        if (++frame >= m_frames.size()) {
            frame = 0;
        }
    }

    return m_frames[frame];
}

TexturePtr AnimatedTexture::getCurrentFrame() {
    return m_frames[m_currentFrame];
}

void AnimatedTexture::allowAtlasCache() {
    for (const auto& frame : m_frames)
        frame->allowAtlasCache();
}

void AnimatedTexture::create() {
    if (getCurrentFrame()->isEmpty()) {
        for (const auto& frame : m_frames)
            frame->create();
    }
}

void AnimatedTexture::update()
{
    if (!m_animTimer.running())
        return;

    if (!isEmpty()) {
        if (m_animTimer.ticksElapsed() < m_framesDelay[m_currentFrame])
            return;

        m_animTimer.restart(); // it is necessary to restart the animation before stop()

        if (++m_currentFrame >= m_frames.size()) {
            m_currentFrame = 0;
            if (m_numPlays > 0 && ++m_currentPlay == m_numPlays)
                m_animTimer.stop();
        }
    }

    m_id = getCurrentFrame()->getId();

    if (isOnMap())
        g_drawPool.repaint(DrawPoolType::MAP);
    else g_drawPool.repaint(DrawPoolType::FOREGROUND);
}