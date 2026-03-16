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

#include "uiparticles.h"
#include <framework/graphics/drawpoolmanager.h>
#include <framework/graphics/particlemanager.h>

#include "framework/graphics/particleeffect.h"

void UIParticles::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    UIWidget::drawSelf(DrawPoolType::FOREGROUND);

    const auto& oldClipRect = g_drawPool.getClipRect();
    g_drawPool.setClipRect(getPaddingRect());
    g_drawPool.pushTransformMatrix();

    if (m_referencePos.x < 0 && m_referencePos.y < 0)
        g_drawPool.translate(m_rect.center());
    else
        g_drawPool.translate(m_rect.x() + m_referencePos.x * m_rect.width(), m_rect.y() + m_referencePos.y * m_rect.height());

    for (const auto& effect : m_effects)
        effect->render();

    g_drawPool.popTransformMatrix();
    g_drawPool.setClipRect(oldClipRect);
}

void UIParticles::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for (const auto& node : styleNode->children()) {
        if (node->tag() == "effect")
            addEffect(node->value());
        else if (node->tag() == "reference-pos")
            setReferencePos(node->value<PointF>());
    }
}

void UIParticles::addEffect(const std::string_view name)
{
    if (const auto& effect = g_particles.createEffect(name))
        m_effects.emplace_back(effect);
}

void UIParticles::setEffect(const std::string_view name)
{
    clearEffects();
    addEffect(name);
}

void UIParticles::clearEffects()
{
    for (const auto& effect : m_effects) {
        g_particles.removeEffect(effect);
    }
    m_effects.clear();
}