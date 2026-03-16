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

#include "uilayout.h"

 // @bindclass
class UIGridLayout final : public UILayout
{
public:
    UIGridLayout(UIWidgetPtr parentWidget);

    void applyStyle(const OTMLNodePtr& styleNode) override;
    void removeWidget(const UIWidgetPtr& widget) override;
    void addWidget(const UIWidgetPtr& widget) override;

    void setCellSize(const Size& size) { m_cellSize = size; update(); }
    void setCellWidth(const int width) { m_cellSize.setWidth(width); update(); }
    void setCellHeight(const int height) { m_cellSize.setHeight(height); update(); }
    void setCellSpacing(const uint8_t spacing) { m_cellSpacing = spacing; update(); }
    void setNumColumns(const uint8_t columns) { m_numColumns = columns; update(); }
    void setNumLines(const uint16_t lines) { m_numLines = lines; update(); }
    void setAutoSpacing(const bool enable) { m_autoSpacing = enable; update(); }
    void setFitChildren(const bool enable) { m_fitChildren = enable; update(); }
    void setFlow(const bool enable) { m_flow = enable; update(); }

    Size getCellSize() { return m_cellSize; }
    uint8_t getCellSpacing() { return m_cellSpacing; }
    uint8_t getNumColumns() { return m_numColumns; }
    uint16_t getNumLines() { return m_numLines; }

    bool isUIGridLayout() override { return true; }

protected:
    bool internalUpdate() override;

private:
    Size m_cellSize{ 16 };
    uint8_t m_cellSpacing{ 0 };
    uint8_t m_numColumns{ 1 };
    uint16_t m_numLines{ 0 };
    bool m_autoSpacing{ false };
    bool m_fitChildren{ false };
    bool m_flow{ false };
};
