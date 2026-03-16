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

#include <framework/ui/uiwidget.h>

#include "framework/core/declarations.h"

class UIProgressRect final : public UIWidget
{
public:
    ~UIProgressRect() override;

    void drawSelf(DrawPoolType drawPane) override;

    void setPercent(float percent);
    float getPercent() { return m_percent; }

    void stop();
    void setDuration(uint32_t duration);
    void start();
    void showTime(bool showTime);
    void showProgress(bool showProgress);
    uint32_t getTimeElapsed();
    uint32_t getDuration() { return m_duration; }

protected:
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;

private:
    void scheduleNextUpdate();
    void updateProgress();
    void updateText(uint32_t remainingTimeMs);

    float m_percent{ 0 };
    ScheduledEventPtr m_updateEvent{ nullptr };
    uint32_t m_duration{ 0 };
    uint32_t m_timeElapsed{ 0 };
    ticks_t m_startTime{ 0 };
    bool m_showTime{ true };
    bool m_showProgress{ true };
    bool m_running{ false };
};
