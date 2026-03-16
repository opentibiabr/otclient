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

#include <framework/ui/uiwidget.h>

struct Graph
{
    std::vector<Point> points;
    std::deque<int> values;
    Point infoLine[2];
    Rect originalInfoRect;
    Rect infoRect;
    Rect infoRectBg;
    Rect infoRectIcon;
    Rect infoIndicator;
    Rect infoIndicatorBg;
    std::string infoValue;
    std::string infoText;
    Color infoLineColor;
    Color infoTextBg;
    Color lineColor;
    int width;
    int infoIndex;
    bool visible;
};

class UIGraph final : public UIWidget
{
public:
    UIGraph() = default;

    void drawSelf(DrawPoolType drawPane) override;

    void clear();
    size_t createGraph();
    size_t getGraphsCount() { return m_graphs.size(); }
    void addValue(size_t index, int value, bool ignoreSmallValues = false);

    void setCapacity(const int capacity) {
        m_capacity = capacity;
        m_needsUpdate = true;
    }
    void setTitle(const std::string& title) { m_title = title; }
    void setShowLabels(const bool value) { m_showLabes = value; }
    void setShowInfo(const bool value) { m_showInfo = value; }

    void setLineWidth(size_t index, int width);
    void setLineColor(size_t index, const Color& color);
    void setInfoText(size_t index, const std::string& text);
    void setInfoLineColor(size_t index, const Color& color);
    void setTextBackground(size_t index, const Color& color);
    void setGraphVisible(size_t index, bool visible);

protected:
    void onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode);
    void onGeometryChange(const Rect& oldRect, const Rect& newRect) override;
    void onLayoutUpdate() override;
    void onVisibilityChange(bool visible) override;

    void cacheGraphs();
    void updateGraph(Graph& graph, bool& updated);
    void updateInfoBoxes();
    std::string formatNumber(int value);

private:
    // cache
    std::string m_minValue;
    std::string m_maxValue;
    std::string m_lastValue;
    std::string m_avgValue;
    std::string m_title;

    bool m_showLabes{ true };
    bool m_showInfo{ true };
    bool m_needsUpdate{ false };

    size_t m_capacity = 100;
    size_t m_ignores = 0;

    std::vector<Graph> m_graphs;
};
