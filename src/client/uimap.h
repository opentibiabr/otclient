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

class UIMap final : public UIWidget
{
public:
    UIMap();
    ~UIMap() override;

    void drawSelf(DrawPoolType drawPane) override;
    void draw(DrawPoolType drawPane);

    void movePixels(int x, int y);
    void followCreature(const CreaturePtr& creature);
    void setCameraPosition(const Position& pos);
    void lockVisibleFloor(int floor);
    void unlockVisibleFloor();
    void setFloorViewMode(Otc::FloorViewMode viewMode);
    void setDrawNames(bool enable);
    void setDrawHealthBars(bool enable);
    void setDrawLights(bool enable);
    void setLimitVisibleDimension(bool enable);
    void setDrawManaBar(bool enable);
    void setDrawHarmony(bool enable);
    void setShader(std::string_view name, float fadein, float fadeout);
    void setMinimumAmbientLight(float intensity);
    void setDrawViewportEdge(bool force);
    bool isDrawingNames();
    bool isDrawingHealthBars();
    bool isDrawingLights();
    bool isLimitedVisibleDimension();
    bool isDrawingManaBar();
    bool isSwitchingShader();
    void setShadowFloorIntensity(float intensity);
    std::vector<CreaturePtr> getSpectators(bool multiFloor = false);
    std::vector<CreaturePtr> getSightSpectators(bool multiFloor = false);
    bool isInRange(const Position& pos);
    PainterShaderProgramPtr getShader();
    PainterShaderProgramPtr getNextShader();
    Otc::FloorViewMode getFloorViewMode();
    CreaturePtr getFollowingCreature();
    Position getCameraPosition();
    Position getPosition(const Point& mousePos);
    TilePtr getTile(const Point& mousePos);
    Size getVisibleDimension();
    float getMinimumAmbientLight();
    void setCrosshairTexture(const std::string& texturePath);
    void setDrawHighlightTarget(bool enable);
    void setCursorAnimations(bool enable);
    void setAntiAliasingMode(Otc::AntialiasingMode mode);
    void setFloorFading(uint16_t v);
    MapViewPtr getMapView() const;
    void clearTiles();

    void setVisibleDimension(const Size& visibleDimension);
    void setKeepAspectRatio(bool enable);

    bool zoomIn();
    bool zoomOut();
    bool setZoom(int zoom);

    void setMaxZoomIn(int maxZoomIn) { m_maxZoomIn = static_cast<uint16_t>(maxZoomIn); }
    void setMaxZoomOut(int maxZoomOut) { m_maxZoomOut = static_cast<uint16_t>(maxZoomOut); }
    void setLimitVisibleRange(bool limitVisibleRange) { m_limitVisibleRange = limitVisibleRange; updateVisibleDimension(); }

    bool isKeepAspectRatioEnabled() { return m_keepAspectRatio; }
    bool isLimitVisibleRangeEnabled() { return m_limitVisibleRange; }

    int getMaxZoomIn() { return m_maxZoomIn; }
    int getMaxZoomOut() { return m_maxZoomOut; }
    int getZoom() { return m_zoom; }

    void updateMapRect();

protected:
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;
    void onGeometryChange(const Rect& oldRect, const Rect& newRect) override;
    void onHoverChange(bool hovered) override;
    bool onMouseMove(const Point& mousePos, const Point& mouseMoved) override;
    bool onMousePress(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseRelease(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseWheel(const Point& mousePos, Fw::MouseWheelDirection direction) override;

private:
    void updateVisibleDimension();
    void updateMapSize();

    MapViewPtr m_mapView;
    Rect m_mapRect;
    Rect m_mapviewRect;

    float m_aspectRatio;

    bool m_keepAspectRatio;
    bool m_limitVisibleRange;

    uint16_t m_maxZoomIn;
    uint16_t m_maxZoomOut;
    uint16_t m_zoom;

    friend class Client;
};
