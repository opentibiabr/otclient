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

#include "statictext.h"

#include "gameconfig.h"
#include "map.h"
#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"
#include "framework/core/graphicalapplication.h"
#include "framework/graphics/fontmanager.h"

StaticText::StaticText()
{
    m_cachedText.setFont(g_gameConfig.getStaticTextFont());
    m_cachedText.setAlign(Fw::AlignCenter);
}

void StaticText::drawText(const Point& dest, const Rect& parentRect)
{
    const auto& textSize = m_cachedText.getTextSize();

    auto rect = Rect(dest - Point(textSize.width() / 2, textSize.height()) + (Point(20, 5) / g_app.getStaticTextScale()), textSize);
    if (g_app.getStaticTextScale() == DEFAULT_DISPLAY_DENSITY)
        rect.bind(parentRect);

    // draw only if the real center is not too far from the parent center, or its a yell
    //if(g_map.isAwareOfPosition(m_position) || isYell()) {
    m_cachedText.draw(rect, m_color);
    //}
}

void StaticText::setText(const std::string_view text) { m_cachedText.setText(text); }
void StaticText::setFont(const std::string_view fontName) { m_cachedText.setFont(g_fonts.getFont(fontName)); }

bool StaticText::addMessage(const std::string_view name, const Otc::MessageMode mode, const std::string_view text)
{
    //TODO: this could be moved to lua
    // first message
    if (m_messages.empty()) {
        m_name = name;
        m_mode = mode;
    }
    // check if we can really own the message
    else if (m_name != name || m_mode != mode) {
        return false;
    }

    // too many messages
    else if (m_messages.size() > 10) {
        m_messages.pop_front();
        m_updateEvent->cancel();
        m_updateEvent = nullptr;
    }

    int delay = std::max<int>(g_gameConfig.getStaticDurationPerCharacter() * text.length(), g_gameConfig.getMinStatictextDuration());
    if (isYell())
        delay *= 2;

    if (g_app.mustOptimize())
        delay /= 2;

    m_messages.emplace_back(text, g_clock.millis() + delay);
    compose();

    if (!m_updateEvent)
        scheduleUpdate();

    return true;
}

void StaticText::update()
{
    m_messages.pop_front();
    if (m_messages.empty()) {
        // schedule removal
        g_textDispatcher.addEvent([self = asStaticText()] { g_map.removeStaticText(self); });
    } else {
        compose();
        scheduleUpdate();
    }
}

void StaticText::scheduleUpdate()
{
    const int delay = std::max<int>(m_messages.front().second - g_clock.millis(), 0);
    m_updateEvent = g_dispatcher.scheduleEvent([self = asStaticText()] {
        self->m_updateEvent = nullptr;
        self->update();
    }, delay);
}

void StaticText::compose()
{
    static constexpr Color
        MESSAGE_COLOR1(239, 239, 0),
        MESSAGE_COLOR2(254, 101, 0),
        MESSAGE_COLOR3(95, 247, 247);

    //TODO: this could be moved to lua
    std::string text;

    if (m_mode == Otc::MessageSay) {
        text += m_name;
        text += " says:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageWhisper) {
        text += m_name;
        text += " whispers:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageYell) {
        text += m_name;
        text += " yells:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageMonsterSay || m_mode == Otc::MessageMonsterYell || m_mode == Otc::MessageSpell
               || m_mode == Otc::MessageBarkLow || m_mode == Otc::MessageBarkLoud) {
        m_color = MESSAGE_COLOR2;
    } else if (m_mode == Otc::MessageNpcFrom || m_mode == Otc::MessageNpcFromStartBlock) {
        text += m_name;
        text += " says:\n";
        m_color = MESSAGE_COLOR3;
    } else {
        g_logger.warning("Unknown speak type: {}", static_cast<uint8_t>(m_mode));
    }

    for (uint32_t i = 0; i < m_messages.size(); ++i) {
        text += m_messages[i].first;

        if (i < m_messages.size() - 1)
            text += "\n";
    }

    m_cachedText.setText(text);
    m_cachedText.wrapText(275);
}