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

#include "uisprite.h"
#include <client/spritemanager.h>
#include "framework/graphics/drawpoolmanager.h"
#include "framework/otml/otmlnode.h"

void UISprite::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    // draw style components in order
    if (m_backgroundColor.aF() > Fw::MIN_ALPHA) {
        Rect backgroundDestRect = m_rect;
        backgroundDestRect.expand(-m_borderWidth.top, -m_borderWidth.right, -m_borderWidth.bottom, -m_borderWidth.left);
        drawBackground(m_rect);
    }

    drawImage(m_rect);

    if (m_spriteVisible && m_sprite) {
        g_drawPool.addTexturedRect(getPaddingRect(), m_sprite, m_spriteColor);
    }

    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UISprite::setSpriteId(const int id)
{
    if (!g_sprites.isLoaded())
        return;

    m_spriteId = id;
    if (id == 0) {
        m_sprite = nullptr;
        return;
    }

    m_sprite = nullptr;
    if (const auto& image = g_sprites.getSpriteImage(id)) {
        m_sprite = std::make_shared<Texture>(image);
        m_sprite->allowAtlasCache();
    }
}

void UISprite::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for (const auto& node : styleNode->children()) {
        if (node->tag() == "sprite-id")
            setSpriteId(node->value<int>());
        else if (node->tag() == "sprite-visible")
            setSpriteVisible(node->value<bool>());
        else if (node->tag() == "sprite-color")
            setSpriteColor(node->value<Color>());
    }
}