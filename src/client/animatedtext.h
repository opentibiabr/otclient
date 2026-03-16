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

#include "declarations.h"

#include "framework/core/timer.h"
#include <framework/graphics/cachedtext.h>
#include <framework/luaengine/luaobject.h>

// @bindclass
class AnimatedText final : public LuaObject
{
public:
    AnimatedText();
    AnimatedText(const std::string_view text, const int color) : AnimatedText() {
        setText(text);
        setColor(color);
    }

    void drawText(const Point& dest, const Rect& visibleRect);

    void onAppear();

    void setColor(const int color) { m_color = Color::from8bit(color); }
    void setText(const std::string_view text) { m_cachedText.setText(text); }
    void setOffset(const Point& offset) { m_offset = offset; }

    Color getColor() { return m_color; }
    const CachedText& getCachedText() const { return m_cachedText; }
    Point getOffset() { return m_offset; }
    Timer getTimer() const { return m_animationTimer; }
    std::string getText() { return m_cachedText.getText(); }

    bool merge(const AnimatedTextPtr& other);
    Position getPosition() const { return m_position; }
    void setPosition(const Position& position) { m_position = position; }

    AnimatedTextPtr asAnimatedText() { return static_self_cast<AnimatedText>(); }

private:
    Color m_color{ Color::white };
    Timer m_animationTimer;
    CachedText m_cachedText;
    Point m_offset;
    Position m_position;
};
