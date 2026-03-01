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

#ifdef FRAMEWORK_CLAY

#include "uilayout.h"
#include <memory>

struct ClayData;

// @bindclass
class UIClayLayout : public UILayout
{
public:
    UIClayLayout(UIWidgetPtr parentWidget);
    ~UIClayLayout() override;

    void applyStyle(const OTMLNodePtr& styleNode) override;
    void addWidget(const UIWidgetPtr& /*widget*/) override { update(); }
    void removeWidget(const UIWidgetPtr& /*widget*/) override { update(); }

    void setDirection(int direction);
    int getDirection() const { return m_direction; }

    void setChildGap(int gap);
    int getChildGap() const { return m_childGap; }

    void setPaddingX(int padding);
    void setPaddingY(int padding);

    void setAlignX(int align);
    int getAlignX() const { return m_alignX; }

    void setAlignY(int align);
    int getAlignY() const { return m_alignY; }

    bool isUIClayLayout() override { return true; }

protected:
    bool internalUpdate() override;

private:
    std::unique_ptr<ClayData> m_clay;

    int m_direction{ 1 };   // 0 = LEFT_TO_RIGHT, 1 = TOP_TO_BOTTOM
    int m_childGap{ 0 };
    int m_alignX{ 0 };      // 0=left, 1=center, 2=right
    int m_alignY{ 0 };      // 0=top, 1=center, 2=bottom
};

#endif // FRAMEWORK_CLAY
