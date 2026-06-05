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

#include "uigraph.h"
#include <framework/graphics/drawpoolmanager.h>

#include "framework/graphics/bitmapfont.h"
#include "framework/graphics/painter.h"
#include "framework/otml/otmlnode.h"
#include <framework/platform/platformwindow.h>

void UIGraph::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    if (m_backgroundColor.aF() > Fw::MIN_ALPHA) {
        Rect backgroundDestRect = m_rect;
        backgroundDestRect.expand(-m_borderWidth.top, -m_borderWidth.right, -m_borderWidth.bottom, -m_borderWidth.left);
        drawBackground(m_rect);
    }

    drawImage(m_rect);

    if (m_needsUpdate) {
        cacheGraphs();
    }

    if (!m_graphs.empty()) {
        const Rect dest = getPaddingRect();

        // draw graph first
        for (auto& graph : m_graphs) {
            if (!graph.visible) continue;

            g_drawPool.addAction([points = graph.points, width = graph.width, color = graph.lineColor] {
                static std::vector<float> vertices;
                vertices.resize(points.size() * 2);
                int i = 0;
                for (const auto& point : points) {
                    vertices[i++] = static_cast<float>(point.x);
                    vertices[i++] = static_cast<float>(point.y);
                }
                g_painter->setColor(color);
                g_painter->drawLine(vertices, points.size(), width);
            });
        }

        // then update if needed and draw vertical line if hovered
        bool updated = false;
        for (auto& graph : m_graphs) {
            if (!graph.visible) continue;

            if (m_showInfo && isHovered()) {
                updateGraph(graph, updated);
                g_drawPool.addAction([line = graph.infoLine, color = graph.infoLineColor] {
                    g_painter->setColor(color);
                    const std::vector vertices = {
                        static_cast<float>(line[0].x), static_cast<float>(line[0].y),
                        static_cast<float>(line[1].x), static_cast<float>(line[1].y)
                    };
                    g_painter->drawLine(vertices, vertices.size() / 2, 1);
                });
            }
        }

        // reposition intersecting rects and keep them within rect bounds
        if (updated) {
            updateInfoBoxes();
        }

        // now we draw indicators on the graph lines
        for (auto& graph : m_graphs) {
            if (!graph.visible) continue;

            if (m_showInfo && isHovered()) {
                g_drawPool.addFilledRect(graph.infoIndicatorBg, Color::white);
                g_drawPool.addFilledRect(graph.infoIndicator, graph.lineColor);
            }
        }

        // lastly we can draw info boxes with value
        for (auto& graph : m_graphs) {
            if (!graph.visible) continue;

            if (m_showInfo && isHovered()) {
                g_drawPool.addFilledRect(graph.infoRectBg, graph.infoTextBg);
                g_drawPool.addFilledRect(graph.infoRectIcon, graph.lineColor);
                m_font->drawText(graph.infoValue, graph.infoRect, Color::lightGray, Fw::AlignLeftCenter);
            }
        }

        if (!m_title.empty())
            m_font->drawText(m_title, dest, Color::lightGray, Fw::AlignTopCenter);
        if (m_showLabes) {
            const float rotationAngle = -1.5707963267948966f;

            g_drawPool.pushTransformMatrix();
            Point maxPoint(dest.left() - 10, dest.top() + 0);
            g_drawPool.rotate(maxPoint, rotationAngle);
            Rect maxRect(maxPoint.x - 50, maxPoint.y - 8, 100, 16);
            m_font->drawText(m_maxValue, Rect(maxRect.x() - 1, maxRect.y() - 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x() + 1, maxRect.y() - 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x() - 1, maxRect.y() + 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x() + 1, maxRect.y() + 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x(), maxRect.y() - 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x(), maxRect.y() + 1, maxRect.width(), maxRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x() - 1, maxRect.y(), maxRect.width(), maxRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_maxValue, Rect(maxRect.x() + 1, maxRect.y(), maxRect.width(), maxRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_maxValue, maxRect, Color::lightGray, Fw::AlignCenter);
            g_drawPool.popTransformMatrix();

            g_drawPool.pushTransformMatrix();
            Point minPoint(dest.left() - 10, dest.bottom() - 0);
            g_drawPool.rotate(minPoint, rotationAngle);
            Rect minRect(minPoint.x - 50, minPoint.y - 8, 100, 16);
            m_font->drawText(m_minValue, Rect(minRect.x() - 1, minRect.y() - 1, minRect.width(), minRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x() + 1, minRect.y() - 1, minRect.width(), minRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x() - 1, minRect.y() + 1, minRect.width(), minRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x() + 1, minRect.y() + 1, minRect.width(), minRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x(), minRect.y() - 1, minRect.width(), minRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x(), minRect.y() + 1, minRect.width(), minRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x() - 1, minRect.y(), minRect.width(), minRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_minValue, Rect(minRect.x() + 1, minRect.y(), minRect.width(), minRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_minValue, minRect, Color::lightGray, Fw::AlignCenter);
            g_drawPool.popTransformMatrix();

            g_drawPool.pushTransformMatrix();
            Point avgPoint(dest.left() - 10, dest.verticalCenter());
            g_drawPool.rotate(avgPoint, rotationAngle);
            Rect avgRect(avgPoint.x - 50, avgPoint.y - 8, 100, 16);
            m_font->drawText(m_avgValue, Rect(avgRect.x() - 1, avgRect.y() - 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x() + 1, avgRect.y() - 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x() - 1, avgRect.y() + 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x() + 1, avgRect.y() + 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 200), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x(), avgRect.y() - 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x(), avgRect.y() + 1, avgRect.width(), avgRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x() - 1, avgRect.y(), avgRect.width(), avgRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_avgValue, Rect(avgRect.x() + 1, avgRect.y(), avgRect.width(), avgRect.height()), Color(0, 0, 0, 150), Fw::AlignCenter);
            m_font->drawText(m_avgValue, avgRect, Color::lightGray, Fw::AlignCenter);
            g_drawPool.popTransformMatrix();
        }
    }

    drawBorder(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
}

void UIGraph::clear()
{
    m_graphs.clear();
    m_needsUpdate = true;
}

void UIGraph::setLineWidth(const size_t index, const int width) {
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setLineWidth ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.width = width;
    m_needsUpdate = true;
}

size_t UIGraph::createGraph()
{
    auto graph = Graph();

    graph.points = {};
    graph.values = {};

    graph.infoLine[0] = Point();
    graph.infoLine[1] = Point();

    graph.originalInfoRect = Rect();
    graph.infoRect = Rect();
    graph.infoRectBg = Rect();
    graph.infoRectIcon = Rect(0, 0, 10, 10);
    graph.infoIndicator = Rect(0, 0, 5, 5);
    graph.infoIndicatorBg = Rect(0, 0, 7, 7);

    graph.infoText = "Value: ";

    graph.infoLineColor = Color::white;
    graph.infoTextBg = Color(0, 0, 0, 100);
    graph.lineColor = Color::white;

    graph.width = 1;
    graph.infoIndex = -1;

    graph.visible = true;

    m_graphs.push_back(graph);
    return m_graphs.size();
}

void UIGraph::addValue(const size_t index, const int value, const bool ignoreSmallValues)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning(
            "[UIGraph::addValue ({})] Graph of index {} out of bounds. Use:\n"
            "    if graph:getGraphsCount() == 0 then\n"
            "        graph:createGraph()\n"
            "        graph:setLineWidth(1, 1)\n"
            "        graph:setLineColor(1, \"#FF0000\")\n"
            "    end\n"
            "    graph:addValue(1,value)",
            getId(), index
        );

        return;
    }

    auto& graph = m_graphs[index - 1];

    if (ignoreSmallValues) {
        if (!graph.values.empty() && graph.values.back() <= 2 && value <= 2 && ++m_ignores <= 10)
            return;
        m_ignores = 0;
    }

    graph.values.push_back(value);
    while (graph.values.size() > m_capacity)
        graph.values.pop_front();

    m_needsUpdate = true;
}

void UIGraph::setLineColor(const size_t index, const Color& color)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setLineColor ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.lineColor = color;
}

void UIGraph::setInfoText(const size_t index, const std::string& text)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setInfoText ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.infoText = text;
}

void UIGraph::setGraphVisible(const size_t index, const bool visible)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setGraphVisible ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.visible = visible;
}

void UIGraph::setInfoLineColor(const size_t index, const Color& color)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setInfoLineColor ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.infoLineColor = color;
}

void UIGraph::setTextBackground(const size_t index, const Color& color)
{
    if (m_graphs.size() <= index - 1) {
        g_logger.warning("[UIGraph::setTextBackground ({})] Graph of index {} out of bounds.", getId(), index);
        return;
    }

    auto& graph = m_graphs[index - 1];
    graph.infoTextBg = color;
}

void UIGraph::cacheGraphs()
{
    if (!m_needsUpdate)
        return;

    if (!m_rect.isEmpty() && m_rect.isValid()) {
        if (!m_graphs.empty()) {
            const Rect rect = getPaddingRect();

            const auto paddingX = static_cast<float>(rect.x());
            const auto paddingY = static_cast<float>(rect.y());
            const auto graphWidth = static_cast<float>(rect.width());
            const auto graphHeight = static_cast<float>(rect.height());

            float minValue = 0.0f;
            float maxValue = 1.0f;
            bool hasValues = false;

            for (auto& graph : m_graphs) {
                if (graph.values.empty())
                    continue;

                graph.points.clear();
                hasValues = true;

                auto [minValueIter, maxValueIter] = std::ranges::minmax_element(graph.values);
                minValue = *minValueIter;
                maxValue = *maxValueIter;
                float range = maxValue - minValue;
                if (range == 0.0f)
                    range = 1.0f;

                const float pointSpacing = graphWidth / std::max<int>(static_cast<int>(graph.values.size()) - 1, 1);
                for (size_t i = 0; i < graph.values.size(); ++i) {
                    const float x = paddingX + i * pointSpacing;
                    const float y = paddingY + graphHeight - ((graph.values[i] - minValue) / range) * graphHeight;
                    graph.points.emplace_back(static_cast<int>(x), static_cast<int>(y));
                }
            }

            if (hasValues) {
                m_minValue = formatNumber(static_cast<int>(minValue));
                m_maxValue = formatNumber(static_cast<int>(maxValue));
            } else {
                m_minValue = "0";
                m_maxValue = "1";
            }
            if (!m_graphs[0].values.empty()) {
                m_lastValue = formatNumber(m_graphs[0].values.back());

                // Calculate average from all values in the first graph
                float sum = 0.0f;
                for (const auto& value : m_graphs[0].values) {
                    sum += value;
                }
                float avgValue = sum / static_cast<float>(m_graphs[0].values.size());
                m_avgValue = formatNumber(static_cast<int>(avgValue));
            } else {
                m_lastValue = "0";
                m_avgValue = "0.5";
            }
        } else {
            // Set default values when no graphs exist
            m_minValue = "0";
            m_maxValue = "1";
            m_lastValue = "0";
            m_avgValue = "0.5";
        }

        m_needsUpdate = false;
    }
}

void UIGraph::updateGraph(Graph& graph, bool& updated)
{
    if (graph.values.empty())
        return;

    const auto dest = getPaddingRect();
    const auto mousePos = g_window.getMousePosition();
    const auto graphWidth = static_cast<float>(dest.width());
    const auto graphHeight = static_cast<float>(dest.height());
    const float pointSpacing = graphWidth / std::max<int>(static_cast<int>(graph.values.size()) - 1, 1);

    int dataIndex = static_cast<int>((mousePos.x - dest.left()) / pointSpacing + 0.5f);
    dataIndex = std::clamp(dataIndex, 0, static_cast<int>(graph.values.size()) - 1);

    if (graph.infoIndex != dataIndex) {
        graph.infoIndex = dataIndex;

        const float snappedX = dest.left() + dataIndex * pointSpacing;
        const int value = graph.values[graph.infoIndex];

        graph.infoLine[0] = Point(snappedX, dest.top());
        graph.infoLine[1] = Point(snappedX, dest.bottom());

        graph.infoValue = fmt::format("{} {}", graph.infoText, formatNumber(value));

        auto [minValueIter, maxValueIter] = std::ranges::minmax_element(graph.values);
        const auto minValue = static_cast<float>(*minValueIter);
        const auto maxValue = static_cast<float>(*maxValueIter);
        float range = maxValue - minValue;
        if (range == 0.0f)
            range = 1.0f;

        const float pointY = dest.top() + graphHeight - ((value - minValue) / range) * graphHeight;

        const auto textSize = m_font->calculateTextRectSize(graph.infoValue);
        graph.infoRectBg.setWidth(textSize.width() + 16);
        graph.infoRectBg.setHeight(textSize.height());
        graph.infoRectBg.expand(4);
        graph.infoRectBg.moveTop(pointY - graph.infoRectBg.height() / 2.0);
        if (snappedX >= dest.horizontalCenter())
            graph.infoRectBg.moveRight(snappedX - 10);
        else
            graph.infoRectBg.moveLeft(snappedX + 10);

        graph.infoRect.setWidth(textSize.width());
        graph.infoRect.setHeight(textSize.height());
        graph.infoRect.moveRight(graph.infoRectBg.right() - 4);
        graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());

        const int iconPadding = graph.infoRectBg.height() - graph.infoRectIcon.width();
        graph.infoRectIcon.moveLeft(graph.infoRectBg.left() + (iconPadding / 2.0));
        graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());

        graph.infoIndicator.moveLeft(snappedX - 3);
        graph.infoIndicator.moveTop(pointY - 3);
        graph.infoIndicatorBg.moveCenter(graph.infoIndicator.center());

        graph.originalInfoRect = graph.infoRectBg;
        updated = true;
    }
}

void UIGraph::updateInfoBoxes()
{
    const auto dest = getPaddingRect();
    std::vector<Rect> occupiedSpaces(m_graphs.size());
    for (size_t i = 0; i < m_graphs.size(); ++i) {
        auto& graph = m_graphs[i];

        graph.infoRectBg = graph.originalInfoRect;
        graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());
        graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());

        occupiedSpaces[i] = graph.infoRectBg;

        for (size_t j = 0; j < occupiedSpaces.size(); ++j) {
            if (i == j) continue; // graph's space, ignore

            auto& space = occupiedSpaces[j];
            // first check if this graph occupies another graph's space and move it above the space
            if (space.intersects(graph.infoRectBg)) {
                graph.infoRectBg.moveBottom(space.top() - 2);
                graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());
                graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());
            }

            // lets make sure its within bounds of this widget
            if (graph.infoRectBg.top() < dest.top()) {
                graph.infoRectBg.moveTop(dest.top());
                graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());
                graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());
            }

            // if we just moved due to bounds check, we have to make sure we are not occuping another graph
            // this time move it below the occupied space
            if (space.intersects(graph.infoRectBg)) {
                graph.infoRectBg.moveTop(space.bottom() + 2);
                graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());
                graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());
            }

            // and check again if we are within bounds
            if (graph.infoRectBg.bottom() > dest.bottom()) {
                graph.infoRectBg.moveBottom(dest.bottom());
                graph.infoRect.moveVerticalCenter(graph.infoRectBg.verticalCenter());
                graph.infoRectIcon.moveVerticalCenter(graph.infoRectBg.verticalCenter());
            }
        }

        occupiedSpaces[i] = graph.infoRectBg;
    }
}

void UIGraph::onStyleApply(const std::string& styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);

    for (const OTMLNodePtr& node : styleNode->children()) {
        if (node->tag() == "capacity")
            setCapacity(node->value<int>());
        else if (node->tag() == "title")
            setTitle(node->value());
        else if (node->tag() == "show-labels")
            setShowLabels(node->value<bool>());
        else if (node->tag() == "show-info") // draw info (vertical line, labels with values) on mouse position
            setShowInfo(node->value<bool>());
    }
}

void UIGraph::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    UIWidget::onGeometryChange(oldRect, newRect);
    m_needsUpdate = true;
}

void UIGraph::onLayoutUpdate()
{
    UIWidget::onLayoutUpdate();
    m_needsUpdate = true;
}

void UIGraph::onVisibilityChange(const bool visible)
{
    UIWidget::onVisibilityChange(visible);
    m_needsUpdate = visible;
}

std::string UIGraph::formatNumber(const int value)
{
    const int absValue = std::abs(value);
    const bool isNegative = value < 0;
    const std::string prefix = isNegative ? "-" : "";

    if (absValue >= 1000000) {
        // Values 1,000,000+ use KK notation with max 1 decimal for maximum compactness
        // Example: 1,500,000 = 1.5KK, 5,000,000 = 5KK, 28,424,000 = 28.4KK
        const float kkValue = static_cast<float>(absValue) / 1000000.0f;
        if (kkValue >= 100.0f) {
            return prefix + std::to_string(static_cast<int>(kkValue)) + "KK";
        } else if (kkValue == static_cast<int>(kkValue)) {
            // No decimal needed for whole numbers
            return prefix + std::to_string(static_cast<int>(kkValue)) + "KK";
        } else {
            return prefix + fmt::format("{:.1f}KK", kkValue);
        }
    } else if (absValue >= 1000) {
        // Values 1,000 to 999,999 use K notation with max 1 decimal
        // Example: 1,500 = 1.5K, 15,000 = 15K
        const float kValue = static_cast<float>(absValue) / 1000.0f;
        if (kValue == static_cast<int>(kValue)) {
            // No decimal needed for whole numbers
            return prefix + std::to_string(static_cast<int>(kValue)) + "K";
        } else {
            return prefix + fmt::format("{:.1f}K", kValue);
        }
    } else {
        // Values under 1,000 show as is
        return prefix + std::to_string(absValue);
    }
}