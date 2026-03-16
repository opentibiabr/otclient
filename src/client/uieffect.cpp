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

#include "uieffect.h"

#include "effect.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/otml/otmlnode.h"
#include "gameconfig.h"

UIEffect::UIEffect() { setProp(PropDraggable, true, false); }

void UIEffect::drawSelf(const DrawPoolType drawPane)
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

    if (m_effectVisible && m_effect) {
        const int exactSize = std::max<int>(g_gameConfig.getSpriteSize(), m_effect->getExactSize());

        g_drawPool.bindFrameBuffer(exactSize);
        m_effect->draw(Point(exactSize - g_gameConfig.getSpriteSize()) + m_effect->getDisplacement());
        g_drawPool.releaseFrameBuffer(getPaddingRect());
    }

    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UIEffect::setEffectId(const int id)
{
    if (id == 0)
        m_effect = nullptr;
    else {
        if (!m_effect)
            m_effect = std::make_shared<Effect>();
        m_effect->setId(id);
        if (m_effect)
            m_effect->setShader(m_shaderName);
    }
}

void UIEffect::setEffect(const EffectPtr& e)
{
    m_effect = e;
}

void UIEffect::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "effect-id")
            setEffectId(node->value<int>());
        else if (node->tag() == "effect-visible")
            setEffectVisible(node->value<bool>());
        else if (node->tag() == "virtual")
            setVirtual(node->value<bool>());
        else if (node->tag() == "show-id")
            m_showId = node->value<bool>();
    }

    UIWidget::onStyleApply(styleName, styleNode);
}

int UIEffect::getEffectId() { return m_effect ? m_effect->getId() : 0; }

void UIEffect::setShader(std::string_view name) {
    m_shaderName = name;
    if (getEffect()) getEffect()->setShader(name);
}

bool UIEffect::hasShader() { return getEffect() ? getEffect()->getShader() != nullptr : false; }