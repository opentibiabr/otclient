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

#include <framework/global.h>

 /**
  * Class that help counting and limiting frames per second in a application,
  */
class AdaptativeFrameCounter
{
public:
    AdaptativeFrameCounter() : m_interval(stdext::millis()) {}

    void init() { m_timer.restart(); }
    bool update();

    uint16_t getFps() const { return m_fps; }
    uint16_t getMaxFps() const { return m_maxFps; }
    uint16_t getTargetFps() const { return m_targetFps; }

    void setMaxFps(const uint16_t max) { m_maxFps = max; }
    void setTargetFps(const uint16_t target) { if (m_targetFps != target) m_targetFps = target; }

    void resetTargetFps() { m_targetFps = 0; }

    float getPercent() const {
        const float maxFps = std::clamp<uint16_t>(m_targetFps, 1, std::max<uint16_t>(m_maxFps, m_targetFps));
        return ((maxFps - m_fps) / maxFps) * 100.f;
    }

    float getFpsPercent(const float percent) const {
        return getFps() * (percent / 100);
    }

private:
    uint32_t getMaxPeriod(const uint16_t fps) const { return 1000000u / fps; }

    uint16_t m_maxFps{};
    uint16_t m_targetFps{ 60u };

    uint16_t m_fps{};
    uint16_t m_fpsCount{};

    uint32_t m_interval{};

    stdext::timer m_timer;
};
