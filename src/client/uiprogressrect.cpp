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

#include "uiprogressrect.h"

#include "framework/graphics/drawpoolmanager.h"
#include <framework/core/clock.h>
#include <framework/core/eventdispatcher.h>

#include "framework/otml/otmlnode.h"

namespace
{
    constexpr int PROGRESS_UPDATE_INTERVAL = 100; // milliseconds
}

UIProgressRect::~UIProgressRect()
{
    stop();
}

void UIProgressRect::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    // todo: check +1 to right/bottom
    // todo: add smooth
    const auto& drawRect = getPaddingRect();

    if (m_showProgress) {
        // 0% - 12.5% (12.5)
        // triangle from top center, to top right (var x)
        if (m_percent < 12.5) {
            const auto& var = Point(std::max<int>(m_percent - 0.0, 0.0) * (drawRect.right() - drawRect.horizontalCenter()) / 12.5, 0);
            g_drawPool.addFilledTriangle(drawRect.center(), drawRect.topRight() + Point(1, 0), drawRect.topCenter() + var, m_backgroundColor);
        }

        // 12.5% - 37.5% (25)
        // triangle from top right to bottom right (var y)
        if (m_percent < 37.5) {
            const auto& var = Point(0, std::max<int>(m_percent - 12.5, 0.0) * (drawRect.bottom() - drawRect.top()) / 25.0);
            g_drawPool.addFilledTriangle(drawRect.center(), drawRect.bottomRight() + Point(1), drawRect.topRight() + var + Point(1, 0), m_backgroundColor);
        }

        // 37.5% - 62.5% (25)
        // triangle from bottom right to bottom left (var x)
        if (m_percent < 62.5) {
            const auto& var = Point(std::max<int>(m_percent - 37.5, 0.0) * (drawRect.right() - drawRect.left()) / 25.0, 0);
            g_drawPool.addFilledTriangle(drawRect.center(), drawRect.bottomLeft() + Point(0, 1), drawRect.bottomRight() - var + Point(1), m_backgroundColor);
        }

        // 62.5% - 87.5% (25)
        // triangle from bottom left to top left
        if (m_percent < 87.5) {
            const auto& var = Point(0, std::max<int>(m_percent - 62.5, 0.0) * (drawRect.bottom() - drawRect.top()) / 25.0);
            g_drawPool.addFilledTriangle(drawRect.center(), drawRect.topLeft(), drawRect.bottomLeft() - var + Point(0, 1), m_backgroundColor);
        }

        // 87.5% - 100% (12.5)
        // triangle from top left to top center
        if (m_percent < 100) {
            const auto& var = Point(std::max<int>(m_percent - 87.5, 0.0) * (drawRect.horizontalCenter() - drawRect.left()) / 12.5, 0);
            g_drawPool.addFilledTriangle(drawRect.center(), drawRect.topCenter(), drawRect.topLeft() + var, m_backgroundColor);
        }
    }

    drawImage(m_rect);
    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UIProgressRect::setPercent(float percent)
{
    percent = std::clamp<float>(percent, 0.f, 100.f);
    if (m_percent == percent)
        return;

    m_percent = percent;
    repaint();
}

void UIProgressRect::stop()
{
    if (m_updateEvent) {
        m_updateEvent->cancel();
        m_updateEvent = nullptr;
    }

    if (m_running) {
        m_timeElapsed = std::min<uint32_t>(m_timeElapsed, m_duration);
        m_running = false;
    }
}

void UIProgressRect::setDuration(uint32_t duration)
{
    m_duration = duration;
}

void UIProgressRect::start()
{
    stop();

    if (m_duration == 0) {
        setPercent(100);
        if (m_showTime)
            setText("");
        callLuaField("onProgressUpdate", m_percent, 0, 0);
        callLuaField("onProgressFinish");
        return;
    }

    m_running = true;
    m_startTime = g_clock.millis();
    m_timeElapsed = 0;

    setPercent(0);

    if (m_showTime)
        setText("");

    updateProgress();
}

void UIProgressRect::showTime(const bool showTime)
{
    if (m_showTime == showTime)
        return;

    m_showTime = showTime;
    if (!m_showTime)
        setText("");
    else if (m_running)
        updateText(std::max<int32_t>(static_cast<int32_t>(m_duration) - static_cast<int32_t>(m_timeElapsed), 0));
}

void UIProgressRect::showProgress(const bool showProgress)
{
    if (m_showProgress == showProgress)
        return;

    m_showProgress = showProgress;
    repaint();
}

uint32_t UIProgressRect::getTimeElapsed()
{
    if (m_running)
        return std::min<uint32_t>(static_cast<uint32_t>(std::max<int64_t>(g_clock.millis() - m_startTime, 0)), m_duration);

    return (std::min)(m_timeElapsed, m_duration);
}

void UIProgressRect::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for (const auto& node : styleNode->children()) {
        if (node->tag() == "percent")
            setPercent(node->value<float>());
        else if (node->tag() == "duration")
            setDuration(node->value<int>());
        else if (node->tag() == "show-time")
            showTime(node->value<bool>());
        else if (node->tag() == "show-progress")
            showProgress(node->value<bool>());
    }
}

void UIProgressRect::scheduleNextUpdate()
{
    auto self = static_self_cast<UIProgressRect>();
    m_updateEvent = g_dispatcher.scheduleEvent([self] {
        self->m_updateEvent = nullptr;
        self->updateProgress();
    }, PROGRESS_UPDATE_INTERVAL);
}

void UIProgressRect::updateProgress()
{
    if (!m_running)
        return;

    const auto now = g_clock.millis();
    m_timeElapsed = std::min<uint32_t>(static_cast<uint32_t>(std::max<int64_t>(now - m_startTime, 0)), m_duration);

    const float percent = m_duration > 0 ? (static_cast<float>(m_timeElapsed) * 100.f) / m_duration : 100.f;
    setPercent(percent);

    const int32_t remainingMs = std::max<int32_t>(static_cast<int32_t>(m_duration) - static_cast<int32_t>(m_timeElapsed), 0);
    if (m_showTime)
        updateText(static_cast<uint32_t>(remainingMs));

    callLuaField("onProgressUpdate", m_percent, (std::max)(remainingMs, 0), m_timeElapsed);

    if (m_timeElapsed >= m_duration) {
        stop();
        callLuaField("onProgressFinish");
        return;
    }

    scheduleNextUpdate();
}

void UIProgressRect::updateText(const uint32_t remainingTimeMs)
{
    if (!m_showTime)
        return;

    if (remainingTimeMs == 0) {
        setText("");
        return;
    }

    const float seconds = std::round(static_cast<float>(remainingTimeMs)) / 1000.f;
    if (seconds >= 10.f)
        setText(fmt::format("{:.0f}s", seconds));
    else if (seconds >= 1.f)
        setText(fmt::format("{:.1f}s", seconds));
    else
        setText(fmt::format("{:.2f}s", seconds));
}