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

#include "uimissile.h"

#include "gameconfig.h"
#include "missile.h"
#include "lightview.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/otml/otmlnode.h"

UIMissile::UIMissile() { setProp(PropDraggable, true, false); }

void UIMissile::drawSelf(const DrawPoolType drawPane)
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

    if (m_missileVisible && m_missile) {
        const int exactSize = std::max<int>(g_gameConfig.getSpriteSize(), m_missile->getExactSize());

        g_drawPool.bindFrameBuffer(exactSize);
        m_missile->draw(Point(exactSize - g_gameConfig.getSpriteSize()) + m_missile->getDisplacement());
        g_drawPool.releaseFrameBuffer(getPaddingRect());
    }

    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UIMissile::setMissileId(const int id)
{
    if (id == 0)
        m_missile = nullptr;
    else {
        if (!m_missile)
            m_missile = std::make_shared<Missile>();
        m_missile->setId(id);
        m_missile->setDirection(Otc::South);

        if (m_missile)
            m_missile->setShader(m_shaderName);
    }
}

int UIMissile::getMissileId() { return m_missile ? m_missile->getId() : 0; }
Otc::Direction UIMissile::getDirection() { return m_missile ? m_missile->getDirection() : Otc::Direction::InvalidDirection; }
void UIMissile::setDirection(const Otc::Direction dir) { if (m_missile) m_missile->setDirection(dir); }

void UIMissile::setMissile(const MissilePtr& e)
{
    m_missile = e;
}

void UIMissile::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "missile-id")
            setMissileId(node->value<int>());
        else if (node->tag() == "missile-visible")
            setMissileVisible(node->value<bool>());
        else if (node->tag() == "virtual")
            setVirtual(node->value<bool>());
        else if (node->tag() == "show-id")
            m_showId = node->value<bool>();
        else if (node->tag() == "direction")
            setDirection(static_cast<Otc::Direction>(node->value<int>()));
    }
    UIWidget::onStyleApply(styleName, styleNode);
}

void UIMissile::setShader(std::string_view name) {
    m_shaderName = name;
    if (getMissile()) getMissile()->setShader(name);
}

bool UIMissile::hasShader() { return getMissile() ? getMissile()->getShader() != nullptr : false; }