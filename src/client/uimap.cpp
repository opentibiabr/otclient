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

#include "uimap.h"

#include "lightview.h"
#include "map.h"
#include "mapview.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/otml/otmlnode.h"
#include <framework/platform/platformwindow.h>
#include <framework/input/mouse.h>

UIMap::UIMap()
{
    setProp(PropDraggable, true, false);
    m_keepAspectRatio = true;
    m_limitVisibleRange = false;
    m_maxZoomIn = 3;
    m_maxZoomOut = 513;
    m_mapView = std::make_shared<MapView>();
    m_zoom = m_mapView->getVisibleDimension().height();
    m_aspectRatio = m_mapView->getVisibleDimension().ratio();

    m_mapRect.resize(1, 1);
    g_map.addMapView(m_mapView);
}

UIMap::~UIMap()
{
    g_map.removeMapView(m_mapView);
}

void UIMap::draw(const DrawPoolType drawPane) {
    if (drawPane == DrawPoolType::MAP) {
        g_drawPool.preDraw(drawPane, [this] {
            m_mapView->drawFloor();
        }, [this] {
            m_mapView->registerEvents();
        }, m_mapView->m_posInfo.rect, m_mapView->m_posInfo.srcRect, Color::black);
    } else if (drawPane == DrawPoolType::LIGHT) {
        g_drawPool.preDraw(drawPane, [this] {
            m_mapView->m_lightView->clear();
            m_mapView->drawLights();
            m_mapView->m_lightView->draw(m_mapView->m_posInfo.rect, m_mapView->m_posInfo.srcRect);
        });
    } else if (drawPane == DrawPoolType::CREATURE_INFORMATION) {
        g_drawPool.preDraw(drawPane, [this] {
            m_mapView->drawCreatureInformation();
        });
    } else if (drawPane == DrawPoolType::FOREGROUND_MAP) {
        g_drawPool.preDraw(drawPane, [this] {
            m_mapView->drawForeground(m_mapviewRect);
        });
    }
}

void UIMap::drawSelf(const DrawPoolType drawPane)
{
    UIWidget::drawSelf(drawPane);

    if (drawPane == DrawPoolType::FOREGROUND) {
        g_drawPool.addBoundingRect(m_mapRect.expanded(1), Color::black);
        g_drawPool.addAction([] {glDisable(GL_BLEND); });
        g_drawPool.addFilledRect(m_mapRect, Color::alpha);
        g_drawPool.addAction([] {glEnable(GL_BLEND); });
    }
}

void UIMap::updateMapRect() {
    m_mapView->updateRect(m_mapviewRect);
}

// ----------------- moved from header: bodies that access m_mapView -----------------

void UIMap::movePixels(int x, int y) { m_mapView->move(x, y); }

void UIMap::followCreature(const CreaturePtr& creature) { m_mapView->followCreature(creature); }

void UIMap::setCameraPosition(const Position& pos) { m_mapView->setCameraPosition(pos); }

void UIMap::lockVisibleFloor(int floor) { m_mapView->lockFirstVisibleFloor(floor); }

void UIMap::unlockVisibleFloor() { m_mapView->unlockFirstVisibleFloor(); }

void UIMap::setFloorViewMode(const Otc::FloorViewMode viewMode) { m_mapView->setFloorViewMode(viewMode); }

void UIMap::setDrawNames(const bool enable) { m_mapView->setDrawNames(enable); }

void UIMap::setDrawHealthBars(const bool enable) { m_mapView->setDrawHealthBars(enable); }

void UIMap::setDrawLights(const bool enable) { m_mapView->setDrawLights(enable); }

void UIMap::setLimitVisibleDimension(const bool enable) { m_mapView->setLimitVisibleDimension(enable); updateVisibleDimension(); }

void UIMap::setDrawManaBar(const bool enable) { m_mapView->setDrawManaBar(enable); }

void UIMap::setDrawHarmony(const bool enable) { m_mapView->setDrawHarmony(enable); }

void UIMap::setShader(std::string_view name, float fadein, float fadeout) { m_mapView->setShader(name, fadein, fadeout); }

void UIMap::setMinimumAmbientLight(const float intensity) { m_mapView->setMinimumAmbientLight(intensity); }

void UIMap::setDrawViewportEdge(const bool force) { m_mapView->m_forceDrawViewportEdge = force; m_mapView->m_visibleDimension = {}; updateVisibleDimension(); }

bool UIMap::isDrawingNames() { return m_mapView->isDrawingNames(); }

bool UIMap::isDrawingHealthBars() { return m_mapView->isDrawingHealthBars(); }

bool UIMap::isDrawingLights() { return m_mapView->isDrawingLights(); }

bool UIMap::isLimitedVisibleDimension() { return m_mapView->isLimitedVisibleDimension(); }

bool UIMap::isDrawingManaBar() { return m_mapView->isDrawingManaBar(); }

bool UIMap::isSwitchingShader() { return m_mapView->isSwitchingShader(); }

void UIMap::setShadowFloorIntensity(const float intensity) { m_mapView->setShadowFloorIntensity(intensity); }

std::vector<CreaturePtr> UIMap::getSpectators(const bool multiFloor) { return m_mapView->getSpectators(multiFloor); }

std::vector<CreaturePtr> UIMap::getSightSpectators(const bool multiFloor) { return m_mapView->getSightSpectators(multiFloor); }

bool UIMap::isInRange(const Position& pos) { return m_mapView->isInRange(pos); }

PainterShaderProgramPtr UIMap::getShader() { return m_mapView->getShader(); }

PainterShaderProgramPtr UIMap::getNextShader() { return m_mapView->getNextShader(); }

Otc::FloorViewMode UIMap::getFloorViewMode() { return m_mapView->getFloorViewMode(); }

CreaturePtr UIMap::getFollowingCreature() { return m_mapView->getFollowingCreature(); }

Position UIMap::getCameraPosition() { return m_mapView->getCameraPosition(); }

Position UIMap::getPosition(const Point& mousePos) { return m_mapView->getPosition(mousePos); }

TilePtr UIMap::getTile(const Point& mousePos) { return m_mapView->getTopTile(getPosition(mousePos)); }

Size UIMap::getVisibleDimension() { return m_mapView->getVisibleDimension(); }

float UIMap::getMinimumAmbientLight() { return m_mapView->getMinimumAmbientLight(); }

void UIMap::setCrosshairTexture(const std::string& texturePath) { m_mapView->setCrosshairTexture(texturePath); }

void UIMap::setDrawHighlightTarget(const bool enable) { m_mapView->setDrawHighlightTarget(enable); }

void UIMap::setCursorAnimations(const bool enable) { m_mapView->setCursorAnimations(enable); }

void UIMap::setAntiAliasingMode(const Otc::AntialiasingMode mode) { m_mapView->setAntiAliasingMode(mode); }

void UIMap::setFloorFading(const uint16_t v) { m_mapView->setFloorFading(v); }

MapViewPtr UIMap::getMapView() const { return m_mapView; }

void UIMap::clearTiles() { m_mapView->m_foregroundTiles.clear(); }

// -------------------------------------------------------------------------------

bool UIMap::setZoom(const int zoom)
{
    m_zoom = std::clamp<int>(zoom, m_maxZoomIn, m_maxZoomOut);
    updateVisibleDimension();
    return false;
}

bool UIMap::zoomIn()
{
    int delta = 2;
    if (m_zoom - delta < m_maxZoomIn)
        --delta;

    if (m_zoom - delta < m_maxZoomIn)
        return false;

    const auto oldZoom = m_zoom;

    m_zoom -= delta;
    updateVisibleDimension();

    callLuaField("onZoomChange", m_zoom, oldZoom);

    return true;
}

bool UIMap::zoomOut()
{
    int delta = 2;
    if (m_zoom + delta > m_maxZoomOut)
        --delta;

    if (m_zoom + delta > m_maxZoomOut)
        return false;

    const auto oldZoom = m_zoom;

    m_zoom += 2;
    updateVisibleDimension();

    callLuaField("onZoomChange", m_zoom, oldZoom);

    return true;
}

void UIMap::setVisibleDimension(const Size& visibleDimension)
{
    m_mapView->setVisibleDimension(visibleDimension);
    m_aspectRatio = visibleDimension.ratio();

    if (m_keepAspectRatio)
        updateMapSize();
}

void UIMap::setKeepAspectRatio(const bool enable)
{
    m_keepAspectRatio = enable;
    if (enable)
        m_aspectRatio = getVisibleDimension().ratio();

    updateMapSize();
}

void UIMap::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "draw-lights")
            setDrawLights(node->value<bool>());
    }
}

void UIMap::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    UIWidget::onGeometryChange(oldRect, newRect);
    updateMapSize();
}

void UIMap::onHoverChange(bool hovered)
{
    UIWidget::onHoverChange(hovered);
    if (!hovered && m_mapView->hasCursorAnimations() && !g_mouse.isCursorChanged()) {
        g_window.restoreMouseCursor();
    }
}

bool UIMap::onMouseMove(const Point& mousePos, const Point& mouseMoved)
{
    const auto& pos = getPosition(mousePos);
    if (!pos.isValid())
        return false;

    if (m_mapView->getLastMousePosition() != pos) {
        m_mapView->onMouseMove(pos);
        m_mapView->setLastMousePosition(pos);
    }

    return UIWidget::onMouseMove(mousePos, mouseMoved);
}

bool UIMap::onMousePress(const Point& mousePos, Fw::MouseButton button)
{
    return UIWidget::onMousePress(mousePos, button);
}

bool UIMap::onMouseRelease(const Point& mousePos, Fw::MouseButton button)
{
    return UIWidget::onMouseRelease(mousePos, button);
}

bool UIMap::onMouseWheel(const Point& mousePos, Fw::MouseWheelDirection direction)
{
    return UIWidget::onMouseWheel(mousePos, direction);
}

void UIMap::updateVisibleDimension()
{
    int dimensionHeight = m_zoom;

    float ratio = m_aspectRatio;
    if (!m_limitVisibleRange && !m_mapRect.isEmpty() && !m_keepAspectRatio)
        ratio = m_mapRect.size().ratio();

    if (dimensionHeight % 2 == 0)
        dimensionHeight += 1;
    int dimensionWidth = m_zoom * ratio;
    if (dimensionWidth % 2 == 0)
        dimensionWidth += 1;

    m_mapView->setVisibleDimension(Size(dimensionWidth, dimensionHeight));

    if (m_keepAspectRatio)
        updateMapSize();
}

void UIMap::updateMapSize()
{
    const auto& clippingRect = getPaddingRect();
    Size mapSize;
    if (m_keepAspectRatio) {
        const auto& mapRect = clippingRect.expanded(-1);
        mapSize = { static_cast<int>(m_aspectRatio * m_zoom), m_zoom };
        mapSize.scale(mapRect.size(), Fw::KeepAspectRatio);
    } else {
        mapSize = clippingRect.expanded(-1).size();
    }

    m_mapRect.resize(mapSize);
    m_mapRect.moveCenter(clippingRect.center());

    m_mapviewRect = Rect(m_mapRect.topLeft() * g_window.getDisplayDensity(), m_mapRect.size() * g_window.getDisplayDensity());

    if (!m_keepAspectRatio)
        updateVisibleDimension();
}

/* vim: set ts=4 sw=4 et: */