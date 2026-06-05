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

class UIMinimap final : public UIWidget
{
public:
    void drawSelf(DrawPoolType drawPane) override;

    bool zoomIn() { return setZoom(m_zoom + 1); }
    bool zoomOut() { return setZoom(m_zoom - 1); }

    bool setZoom(int8_t zoom);
    void setMinZoom(const int8_t minZoom) { m_minZoom = minZoom; }
    void setMaxZoom(const int8_t maxZoom) { m_maxZoom = maxZoom; }
    void setCameraPosition(const Position& pos);
    bool floorUp();
    bool floorDown();

    Point getTilePoint(const Position& pos);
    Rect getTileRect(const Position& pos);
    Position getTilePosition(const Point& mousePos);

    Position getCameraPosition() { return m_cameraPosition; }
    int8_t getZoom() { return m_zoom; }
    int8_t getMinZoom() { return m_minZoom; }
    int8_t getMaxZoom() { return m_maxZoom; }
    float getScale() { return m_scale; }

    void anchorPosition(const UIWidgetPtr& anchoredWidget, Fw::AnchorEdge anchoredEdge, const Position& hookedPosition, Fw::AnchorEdge hookedEdge);
    void fillPosition(const UIWidgetPtr& anchoredWidget, const Position& hookedPosition);
    void centerInPosition(const UIWidgetPtr& anchoredWidget, const Position& hookedPosition);

protected:
    virtual void onZoomChange(int zoom, int oldZoom);
    virtual void onCameraPositionChange(const Position& position, const Position& oldPosition);
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;

private:
    Rect m_mapArea;
    Position m_cameraPosition;
    float m_scale{ 1.f };
    int8_t m_zoom{ 0 };
    int8_t m_minZoom{ -5 };
    int8_t m_maxZoom{ 5 };
};
