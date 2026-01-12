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
#include <framework/ui/uiwidget.h>

class UIItem final : public UIWidget
{
public:
    UIItem();
    void drawSelf(DrawPoolType drawPane) override;

    void setItemId(int id);
    void setItemCount(int count);
    void setItemSubType(int subType);
    void setItemVisible(const bool visible) { m_itemVisible = visible; }
    void setItem(const ItemPtr& item);
    void setShowCount(const bool value) { m_alwaysShowCount = value; }
    void setVirtual(const bool virt) { m_virtual = virt; }
    void setFlipDirection(const uint8_t direction) { m_flipDirection = direction; repaint(); }
    void clearItem() { setItemId(0); }

    int getItemId();
    int getItemCount();
    int getItemSubType();
    int getItemCountOrSubType();
    ItemPtr getItem() { return m_item; }
    bool isVirtual() { return m_virtual; }
    bool isItemVisible() { return m_itemVisible; }
    uint8_t getFlipDirection() { return m_flipDirection; }

    void setShader(std::string_view name) override;
    bool hasShader() override;

protected:
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;

    std::string m_shaderName;
    ItemPtr m_item;
    uint32_t m_itemId{ 0 };
    bool m_virtual{ false };
    bool m_showId{ false };
    bool m_itemVisible{ true };
    bool m_alwaysShowCount{ true };
    uint8_t m_flipDirection{ 0 }; // 0 = none, 1 = horizontal, 2 = vertical
};
