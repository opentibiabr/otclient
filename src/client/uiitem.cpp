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

#include "uiitem.h"

#include "framework/graphics/drawpoolmanager.h"
#include "framework/otml/otmlnode.h"
#include "gameconfig.h"
#include "item.h"

UIItem::UIItem() { setProp(PropDraggable, true, false); }

void UIItem::drawSelf(const DrawPoolType drawPane)
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

    if (m_itemVisible && m_item) {
        if (m_item->getClientId() != m_itemId) {
            m_item->setId(m_itemId);
        }

        const int exactSize = std::max<int>(g_gameConfig.getSpriteSize(), m_item->getExactSize());

        g_drawPool.bindFrameBuffer(exactSize);
        m_item->setColor(m_color);
        m_item->draw(Point(exactSize - g_gameConfig.getSpriteSize()) + m_item->getDisplacement());
        g_drawPool.releaseFrameBuffer(getPaddingRect(), m_flipDirection);

        if (m_font && (m_alwaysShowCount && (m_item->isStackable() || m_item->isChargeable())) && m_item->getCountOrSubType() > 1) {
            static constexpr Color STACK_COLOR(231, 231, 231);
            const auto& count = m_item->getCountOrSubType();
            const auto& countText = count < 1000 ? std::to_string(count) : fmt::format("{}k", count / 1000.f);
            m_font->drawText(countText, Rect(m_rect.topLeft(), m_rect.bottomRight() - Point(3, 0)), STACK_COLOR, Fw::AlignBottomRight);
        }

#ifdef FRAMEWORK_EDITOR
        if (m_showId)
            m_font->drawText(std::to_string(m_item->getServerId()), m_rect, Fw::AlignBottomRight);
#endif
    }

    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UIItem::setItemId(const int id)
{
    m_itemId = id;

    if (id == 0)
        m_item = nullptr;
    else if (m_item)
        m_item->setId(id);
    else
        m_item = Item::create(id);

    if (m_item)
        m_item->setShader(m_shaderName);

    callLuaField("onItemChange");
}

void UIItem::setItemCount(const int count)
{
    if (m_item) m_item->setCount(count);

    callLuaField("onItemChange");
}

void UIItem::setItemSubType(const int subType)
{
    if (m_item) m_item->setSubType(subType);

    callLuaField("onItemChange");
}

void UIItem::setItem(const ItemPtr& item)
{
    m_item = item;
    if (item)
        m_itemId = item->getClientId();

    callLuaField("onItemChange");
}

void UIItem::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "item-id")
            setItemId(node->value<int>());
        else if (node->tag() == "item-count")
            setItemCount(node->value<int>());
        else if (node->tag() == "item-visible")
            setItemVisible(node->value<bool>());
        else if (node->tag() == "virtual")
            setVirtual(node->value<bool>());
        else if (node->tag() == "show-id")
            m_showId = node->value<bool>();
        else if (node->tag() == "always-show-count")
            m_alwaysShowCount = node->value<bool>();
        else if (node->tag() == "flip-direction")
            setFlipDirection(node->value<uint8_t>());
    }

    UIWidget::onStyleApply(styleName, styleNode);
}

int UIItem::getItemId() { return m_item ? m_item->getId() : 0; }
int UIItem::getItemCount() { return m_item ? m_item->getCount() : 0; }
int UIItem::getItemSubType() { return m_item ? m_item->getSubType() : 0; }
int UIItem::getItemCountOrSubType() { return m_item ? m_item->getCountOrSubType() : 0; }

void UIItem::setShader(std::string_view name) {
    m_shaderName = name;
    if (getItem()) getItem()->setShader(name);
}

bool UIItem::hasShader() { return getItem() ? getItem()->getShader() != nullptr : false; }
