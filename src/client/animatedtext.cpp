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

#include "animatedtext.h"

#include "game.h"
#include "gameconfig.h"
#include "map.h"
#include "framework/core/eventdispatcher.h"
#include "framework/core/graphicalapplication.h"

AnimatedText::AnimatedText()
{
    m_cachedText.setFont(g_gameConfig.getAnimatedTextFont());
    m_cachedText.setAlign(Fw::AlignLeft);
}

void AnimatedText::drawText(const Point& dest, const Rect& visibleRect)
{
    const float tf = g_gameConfig.getAnimatedTextDuration(),
        tftf = g_gameConfig.getAnimatedTextDuration() * g_gameConfig.getAnimatedTextDuration();

    const auto& textSize = m_cachedText.getTextSize();
    const float t = m_animationTimer.ticksElapsed();

    Point p = dest;
    p.x += (24.f / g_app.getAnimatedTextScale() - (textSize.width() / 2.f));
    if (g_game.getFeature(Otc::GameDiagonalAnimatedText)) {
        p.x -= (4 * g_app.getAnimatedTextScale() * t / tf) + (8 * g_app.getAnimatedTextScale() * t * t / tftf);
    }

    p.y += ((8.f / g_app.getAnimatedTextScale()) + ((-48.f * g_app.getAnimatedTextScale() * t) / tf));
    p += m_offset;

    if (!visibleRect.contains({ p, textSize }))
        return;

    p.scale(g_app.getAnimatedTextScale());

    const Rect& rect{ p, textSize };
    const float t0 = tf / 1.2;

    Color color = m_color;
    if (t > t0) {
        color.setAlpha(1 - (t - t0) / (tf - t0));
    }

    m_cachedText.draw(rect, color);
}

void AnimatedText::onAppear()
{
    m_animationTimer.restart();

    uint16_t textDuration = g_gameConfig.getAnimatedTextDuration();
    if (g_app.mustOptimize())
        textDuration /= 2;

    // schedule removal
    g_textDispatcher.scheduleEvent([self = asAnimatedText()] { g_map.removeAnimatedText(self); }, textDuration);
}

bool AnimatedText::merge(const AnimatedTextPtr& other)
{
    if (other->getColor() != m_color)
        return false;

    if (other->getCachedText().getFont() != m_cachedText.getFont())
        return false;

    if (m_animationTimer.ticksElapsed() > g_gameConfig.getAnimatedTextDuration() / 2.5)
        return false;

    try {
        const int number = stdext::safe_cast<int>(m_cachedText.getText());
        const int otherNumber = stdext::safe_cast<int>(other->getCachedText().getText());
        m_cachedText.setText(fmt::format("{}", number + otherNumber));
        return true;
    } catch (...) {
        return false;
    }
}