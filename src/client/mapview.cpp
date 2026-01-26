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

#include "mapview.h"

#include <framework/graphics/drawpoolmanager.h>

#include "animatedtext.h"
#include "creature.h"
#include "gameconfig.h"
#include "lightview.h"
#include "map.h"
#include "missile.h"
#include "tile.h"
#include "item.h"
#include <framework/input/mouse.h>
#include "framework/core/asyncdispatcher.h"
#include "framework/core/eventdispatcher.h"
#include <framework/core/graphicalapplication.h>
#include "framework/graphics/graphics.h"
#include "framework/graphics/painter.h"
#include "framework/graphics/shadermanager.h"
#include "framework/graphics/texturemanager.h"
#include <framework/platform/platformwindow.h>

MapView::MapView() : m_lightView(std::make_unique<LightView>(Size())), m_pool(g_drawPool.get(DrawPoolType::MAP))
{
    m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    m_floorThreads.resize(g_asyncDispatcher.get_thread_count());
    for (auto& thread : m_floorThreads)
        thread.resize(m_floors.size());

    setVisibleDimension(Size(15, 11));
}

MapView::~MapView()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
}

void MapView::registerEvents() {
    g_drawPool.addAction([this, camera = m_posInfo.camera, srcRect = m_posInfo.srcRect] {
        m_pool->onBeforeDraw([=, this] {
            float fadeOpacity = 1.f;
            if (!m_shaderSwitchDone && m_fadeOutTime > 0) {
                fadeOpacity = 1.f - (m_fadeTimer.timeElapsed() / m_fadeOutTime);
                if (fadeOpacity < 0.f) {
                    m_shader = m_nextShader;
                    m_nextShader = nullptr;
                    m_shaderSwitchDone = true;
                    m_fadeTimer.restart();
                }
            }

            if (m_shaderSwitchDone && m_shader && m_fadeInTime > 0)
                fadeOpacity = std::min<float>(m_fadeTimer.timeElapsed() / m_fadeInTime, 1.f);

            if (m_shader) {
                const auto& center = srcRect.center();
                const auto& globalCoord = Point(camera.x - m_drawDimension.width() / 2, -(camera.y - m_drawDimension.height() / 2)) * m_tileSize;

                m_shader->bind();
                m_shader->setUniformValue(ShaderManager::MAP_CENTER_COORD, center.x / static_cast<float>(m_rectDimension.width()), 1.f - center.y / static_cast<float>(m_rectDimension.height()));
                m_shader->setUniformValue(ShaderManager::MAP_GLOBAL_COORD, globalCoord.x / static_cast<float>(m_rectDimension.height()), globalCoord.y / static_cast<float>(m_rectDimension.height()));
                m_shader->setUniformValue(ShaderManager::MAP_ZOOM, m_pool->getScaleFactor());

                Point last = transformPositionTo2D(camera, m_shaderPosition);
                //Reverse vertical axis.
                last.y = -last.y;

                m_shader->setUniformValue(ShaderManager::MAP_WALKOFFSET, last.x / static_cast<float>(m_rectDimension.width()), last.y / static_cast<float>(m_rectDimension.height()));

                g_painter->setShaderProgram(m_shader);
            }

            g_painter->setOpacity(fadeOpacity);
        });

        m_pool->onAfterDraw([] {
            g_painter->resetShaderProgram();
            g_painter->resetOpacity();
        });
    });
}

void MapView::preLoad() {
    // update visible tiles cache when needed
    if (m_updateVisibleTiles)
        updateVisibleTiles();

    if (canFloorFade()) {
        const float fadeLevel = getFadeLevel(m_cachedFirstVisibleFloor);
        if (!m_fadeFinish && fadeLevel == 1.f) {
            onFadeInFinished();
            m_fadeFinish = true;
        }
    }

    g_map.updateAttachedWidgets(static_self_cast<MapView>());
}

void MapView::drawFloor()
{
    const auto& cameraPosition = m_posInfo.camera;

    const uint32_t flags = Otc::DrawThings;

    for (int_fast8_t z = m_floorMax; z >= m_floorMin; --z) {
        const float fadeLevel = getFadeLevel(z);
        if (fadeLevel == 0.f) break;
        if (fadeLevel < .99f)
            g_drawPool.setOpacity(fadeLevel);

        Position _camera = cameraPosition;
        const bool alwaysTransparent = m_floorViewMode == Otc::ALWAYS_WITH_TRANSPARENCY && z < m_cachedFirstVisibleFloor && _camera.coveredUp(cameraPosition.z - z);

        const auto& map = m_floors[z].cachedVisibleTiles;

        for (const auto& tile : map.tiles) {
            uint32_t tileFlags = flags;

            if (!m_drawViewportEdge && !tile->canRender(tileFlags, cameraPosition, m_viewport))
                continue;

            if (alwaysTransparent) {
                const bool inRange = tile->getPosition().isInRange(_camera, g_gameConfig.getTileTransparentFloorViewRange(), g_gameConfig.getTileTransparentFloorViewRange(), true);
                g_drawPool.setOpacity(inRange ? .16 : .7);
            }

            tile->draw(transformPositionTo2D(tile->getPosition()), tileFlags);

            if (alwaysTransparent)
                g_drawPool.resetOpacity();
        }

        for (const auto& missile : g_map.getFloorMissiles(z))
            missile->draw(transformPositionTo2D(missile->getPosition()), true);

        if (m_shadowFloorIntensity > 0 && z == cameraPosition.z + 1) {
            g_drawPool.setOpacity(m_shadowFloorIntensity, true);
            g_drawPool.setDrawOrder(DrawOrder::FIFTH);
            g_drawPool.addFilledRect(m_rectDimension, Color::black);
            g_drawPool.resetDrawOrder();
        }

        if (canFloorFade())
            g_drawPool.resetOpacity();

        g_drawPool.flush();
    }

    if (m_posInfo.rect.contains(g_window.getMousePosition() * g_window.getDisplayDensity())) {
        if (m_crosshairTexture && m_mousePosition.isValid()) {
            const auto& point = transformPositionTo2D(m_mousePosition);
            const auto& crosshairRect = Rect(point, m_tileSize, m_tileSize);
            g_drawPool.addTexturedRect(crosshairRect, m_crosshairTexture);
        }
    } else if (m_lastHighlightTile) {
        m_mousePosition = {}; // Invalidate mousePosition
        destroyHighlightTile();
    }
}

void MapView::drawLights() {
    const auto& cameraPosition = m_posInfo.camera;

    for (int_fast8_t z = m_floorMax; z >= m_floorMin; --z) {
        const float fadeLevel = getFadeLevel(z);
        if (fadeLevel == 0.f) break;

        Position _camera = cameraPosition;
        const bool alwaysTransparent = m_floorViewMode == Otc::ALWAYS_WITH_TRANSPARENCY && z < m_cachedFirstVisibleFloor && _camera.coveredUp(cameraPosition.z - z);

        const auto& map = m_floors[z].cachedVisibleTiles;

        if (m_fadeType != FadeType::FADE_OUT || fadeLevel == 1.f) {
            for (const auto& tile : map.shades) {
                if (alwaysTransparent && tile->getPosition().isInRange(_camera, g_gameConfig.getTileTransparentFloorViewRange(), g_gameConfig.getTileTransparentFloorViewRange(), true))
                    continue;

                m_lightView->resetShade(transformPositionTo2D(tile->getPosition()));
            }
        }

        for (const auto& tile : map.tiles)
            tile->drawLight(transformPositionTo2D(tile->getPosition()), m_lightView.get());

        for (const auto& missile : g_map.getFloorMissiles(z))
            missile->draw(transformPositionTo2D(missile->getPosition()), false, m_lightView.get());
    }
}

void MapView::drawCreatureInformation() {
    g_drawPool.scale(g_app.getCreatureInformationScale());

    uint32_t flags = Otc::DrawThings;
    if (m_drawNames) { flags |= Otc::DrawNames; }
    if (m_drawHealthBars) { flags |= Otc::DrawBars; }
    if (m_drawManaBar) { flags |= Otc::DrawManaBar; }
    if (m_drawHarmony) { flags |= Otc::DrawHarmony; }

    Position _camera = m_posInfo.camera;
    const bool alwaysTransparent = m_floorViewMode == Otc::ALWAYS_WITH_TRANSPARENCY && _camera.coveredUp(m_posInfo.camera.z - m_floorMin);
    for (const auto& [uid, creature] : g_map.getCreatures()) {
        const auto& tile = creature->getTile();
        if (!tile || !m_posInfo.isInRange(creature->getPosition()))
            continue;

        bool isCovered = tile->isCovered(alwaysTransparent ? m_floorMin : m_cachedFirstVisibleFloor);
        if (alwaysTransparent && isCovered) {
            const bool inRange = creature->getPosition().isInRange(m_posInfo.camera, g_gameConfig.getTileTransparentFloorViewRange(), g_gameConfig.getTileTransparentFloorViewRange(), true);
            isCovered = !inRange;
        }

        creature->setCovered(isCovered);

        creature->drawInformation(m_posInfo, transformPositionTo2D(creature->getPosition()), flags);
    }
}

void MapView::drawForeground(const Rect& rect)
{
    g_drawPool.scale(g_app.getStaticTextScale());
    for (const auto& staticText : g_map.getStaticTexts()) {
        if (staticText->getMessageMode() == Otc::MessageNone)
            continue;

        const auto& pos = staticText->getPosition();
        if (pos.z != m_posInfo.camera.z && staticText->getMessageMode() == Otc::MessageNone)
            continue;

        Point p = transformPositionTo2D(pos) - m_posInfo.drawOffset;
        p.x *= m_posInfo.horizontalStretchFactor;
        p.y *= m_posInfo.verticalStretchFactor;
        p += rect.topLeft();
        staticText->drawText(p.scale(g_app.getStaticTextScale()), rect);
    }

    g_drawPool.scale(g_app.getAnimatedTextScale());
    for (const auto& animatedText : g_map.getAnimatedTexts()) {
        const auto& pos = animatedText->getPosition();

        if (pos.z != m_posInfo.camera.z)
            continue;

        auto p = transformPositionTo2D(pos) - m_posInfo.drawOffset;
        p.x *= m_posInfo.horizontalStretchFactor;
        p.y *= m_posInfo.verticalStretchFactor;
        p += rect.topLeft();
        animatedText->drawText(p, rect);
    }

    g_drawPool.scale(1.f);
    for (const auto& tile : m_foregroundTiles) {
        const auto& dest = transformPositionTo2D(tile->getPosition());

        Point p = dest - m_posInfo.drawOffset;
        p.x *= m_posInfo.horizontalStretchFactor;
        p.y *= m_posInfo.verticalStretchFactor;
        p += rect.topLeft();
        p.y += 5;

        tile->drawTexts(p);
    }
}

void MapView::updateVisibleTiles()
{
    // there is no tile to render on invalid positions
    if (!m_posInfo.camera.isValid())
        return;

    // clear current visible tiles cache
    do {
        m_floors[m_floorMin].cachedVisibleTiles.clear();
    } while (++m_floorMin <= m_floorMax);

    m_lockedFirstVisibleFloor = m_floorViewMode == Otc::LOCKED ? m_posInfo.camera.z : -1;

    const auto prevFirstVisibleFloor = m_cachedFirstVisibleFloor;

    if (m_lastCameraPosition != m_posInfo.camera) {
        if (m_lastCameraPosition.z != m_posInfo.camera.z) {
            onFloorChange(m_posInfo.camera.z, m_lastCameraPosition.z);
        }

        const auto cachedFirstVisibleFloor = calcFirstVisibleFloor(m_floorViewMode != Otc::ALWAYS);
        m_cachedFirstVisibleFloor = cachedFirstVisibleFloor;
        m_cachedLastVisibleFloor = std::max<uint8_t>(cachedFirstVisibleFloor, calcLastVisibleFloor());

        m_floorMin = m_floorMax = m_posInfo.camera.z;
    }

    auto cachedFirstVisibleFloor = m_cachedFirstVisibleFloor;
    if (m_floorViewMode == Otc::ALWAYS_WITH_TRANSPARENCY || canFloorFade()) {
        cachedFirstVisibleFloor = calcFirstVisibleFloor(false);
    }

    // Fading System by Kondra https://github.com/OTCv8/otclientv8
    if (!m_lastCameraPosition.isValid() || m_lastCameraPosition.z != m_posInfo.camera.z || m_lastCameraPosition.distance(m_posInfo.camera) >= 3) {
        m_fadeType = FadeType::NONE;
        for (int iz = m_cachedLastVisibleFloor; iz >= cachedFirstVisibleFloor; --iz) {
            m_floors[iz].fadingTimers.restart(m_floorFading);
        }
    } else if (prevFirstVisibleFloor < m_cachedFirstVisibleFloor) { // hiding new floor
        m_fadeType = FadeType::FADE_OUT;
        for (int iz = prevFirstVisibleFloor; iz < m_cachedFirstVisibleFloor; ++iz) {
            const int shift = std::max<int>(0, m_floorFading - m_floors[iz].fadingTimers.ticksElapsed());
            m_floors[iz].fadingTimers.restart(shift);
        }
    } else if (prevFirstVisibleFloor > m_cachedFirstVisibleFloor) { // showing floor
        m_fadeType = FadeType::FADE_IN;
        m_fadeFinish = false;
        for (int iz = m_cachedFirstVisibleFloor; iz < prevFirstVisibleFloor; ++iz) {
            const int shift = std::max<int>(0, m_floorFading - m_floors[iz].fadingTimers.ticksElapsed());
            m_floors[iz].fadingTimers.restart(shift);
        }
    }

    m_lastCameraPosition = m_posInfo.camera;
    destroyHighlightTile();

    const bool checkIsCovered = !m_drawCoveredThings && getFadeLevel(m_cachedFirstVisibleFloor) == 1.f;

    // cache visible tiles in draw order
    // draw from last floor (the lower) to first floor (the higher)
    const uint32_t numDiagonals = m_drawDimension.width() + m_drawDimension.height() - 1;

    auto processDiagonalRange = [&](std::vector<FloorData>& floors, uint32_t start, uint32_t end) {
        for (int_fast32_t iz = m_cachedLastVisibleFloor; iz >= cachedFirstVisibleFloor; --iz) {
            auto& floor = floors[iz].cachedVisibleTiles;

            for (uint_fast32_t diagonal = start; diagonal < end; ++diagonal) {
                const auto advance = (static_cast<size_t>(diagonal) >= static_cast<size_t>(m_drawDimension.height())) ? diagonal - static_cast<size_t>(m_drawDimension.height()) : 0;
                for (int iy = diagonal - advance, ix = advance; iy >= 0 && ix < m_drawDimension.width(); --iy, ++ix) {
                    auto tilePos = m_posInfo.camera.translated(ix - m_virtualCenterOffset.x, iy - m_virtualCenterOffset.y);
                    tilePos.coveredUp(m_posInfo.camera.z - iz);

                    if (const auto& tile = g_map.getTile(tilePos)) {
                        if (!tile->isDrawable()) continue;

                        bool addTile = true;

                        if (checkIsCovered && tile->isCompletelyCovered(m_cachedFirstVisibleFloor, m_resetCoveredCache)) {
                            if (m_floorViewMode != Otc::ALWAYS_WITH_TRANSPARENCY || (tilePos.z < m_posInfo.camera.z && tile->isCovered(m_cachedFirstVisibleFloor))) {
                                addTile = false;
                            }
                        }

                        if (addTile) {
                            floor.tiles.emplace_back(tile);
                            tile->onAddInMapView();
                        }

                        if (isDrawingLights() && tile->canShade()) {
                            floor.shades.emplace_back(tile);
                        }

                        if (addTile || !floor.shades.empty()) {
                            if (iz < m_floorMin)
                                m_floorMin = iz;
                            else if (iz > m_floorMax)
                                m_floorMax = iz;
                        }
                    }
                }
            }
        }
    };

    if (m_multithreading) {
        static const int numThreads = g_asyncDispatcher.get_thread_count();
        static BS::multi_future<void> tasks(numThreads);
        tasks.clear();

        const auto chunkSize = (numDiagonals + numThreads - 1) / numThreads;

        for (auto i = 0; i < numThreads; ++i) {
            const auto start = i * chunkSize;
            const auto end = start + chunkSize;

            for (auto& floor : m_floorThreads[i])
                floor.cachedVisibleTiles.clear();

            tasks.emplace_back(g_asyncDispatcher.submit_task([=, this] {
                processDiagonalRange(m_floorThreads[i], start, end);
            }));
        }

        tasks.wait();

        for (int fi = 0, s = m_floors.size(); fi < s; ++fi) {
            auto& floor = m_floors[fi];
            floor.cachedVisibleTiles.clear();

            for (auto i = 0; i < numThreads; ++i) {
                auto& floorThread = m_floorThreads[i][fi];
                floor.cachedVisibleTiles.tiles.insert(floor.cachedVisibleTiles.tiles.end(), std::make_move_iterator(floorThread.cachedVisibleTiles.tiles.begin()), std::make_move_iterator(floorThread.cachedVisibleTiles.tiles.end()));
                floor.cachedVisibleTiles.shades.insert(floor.cachedVisibleTiles.shades.end(), std::make_move_iterator(floorThread.cachedVisibleTiles.shades.begin()), std::make_move_iterator(floorThread.cachedVisibleTiles.shades.end()));
            }
        }
    } else {
        processDiagonalRange(m_floors, 0, numDiagonals);
    }

    m_updateVisibleTiles = false;
    m_resetCoveredCache = false;
    updateHighlightTile(m_mousePosition);
}

void MapView::updateRect(const Rect& rect) {
    if (m_posInfo.camera != getCameraPosition()) {
        m_posInfo.camera = getCameraPosition();
        requestUpdateVisibleTiles();
        requestUpdateMapPosInfo();
    }

    if (m_posInfo.rect != rect || m_updateMapPosInfo) {
        m_updateMapPosInfo = false;

        m_posInfo.rect = rect;
        m_posInfo.srcRect = calcFramebufferSource(rect.size());
        m_posInfo.drawOffset = m_posInfo.srcRect.topLeft();
        m_posInfo.horizontalStretchFactor = rect.width() / static_cast<float>(m_posInfo.srcRect.width());
        m_posInfo.verticalStretchFactor = rect.height() / static_cast<float>(m_posInfo.srcRect.height());

        auto mousePoint = g_window.getMousePosition();
        if (g_app.getHUDScale() != DEFAULT_DISPLAY_DENSITY) {
            mousePoint.scale(g_app.getHUDScale());
        }

        const auto& mousePos = getPosition(mousePoint * g_window.getDisplayDensity());
        if (mousePos != m_mousePosition)
            onMouseMove(m_mousePosition = mousePos, true);
    }
}

void MapView::updateGeometry(const Size& visibleDimension)
{
    float scaleFactor = m_antiAliasingMode == Otc::ANTIALIASING_SMOOTH_RETRO ? 2.f : 1.f;

    auto maxAwareRange = std::max<size_t>(visibleDimension.width(), visibleDimension.height());

    const auto optimize = maxAwareRange > 115;

    m_pool->agroup(optimize);
    m_drawCoveredThings = !optimize;
    m_multithreading = optimize;
    while (maxAwareRange > 100) {
        maxAwareRange /= 2;
        scaleFactor /= 2;
    }

    m_pool->setScaleFactor(scaleFactor);

    m_posInfo.scaleFactor = scaleFactor;

    const uint16_t tileSize = g_gameConfig.getSpriteSize() * m_pool->getScaleFactor();
    const auto& drawDimension = visibleDimension + 3;
    const auto& bufferSize = drawDimension * tileSize;

    if (bufferSize.width() > g_graphics.getMaxTextureSize() || bufferSize.height() > g_graphics.getMaxTextureSize()) {
        g_logger.traceError("reached max zoom out");
        return;
    }

    m_visibleDimension = visibleDimension;
    m_drawDimension = drawDimension;
    m_tileSize = tileSize;
    m_virtualCenterOffset = (drawDimension / 2 - Size(1)).toPoint();
    m_rectDimension = { 0, 0, bufferSize };

    if (m_lightView->isEnabled()) {
        Size lightSize = g_map.getAwareRange().dimension();
        if (drawDimension > lightSize)
            lightSize = drawDimension;

        m_lightView->resize(lightSize, tileSize);
    }

    g_mainDispatcher.addEvent([this, bufferSize] {
        m_pool->getFrameBuffer()->resize(bufferSize);
    });

    const uint8_t left = std::min<uint8_t>(g_map.getAwareRange().left, (m_drawDimension.width() / 2) - 1);
    const uint8_t top = std::min<uint8_t>(g_map.getAwareRange().top, (m_drawDimension.height() / 2) - 1);
    const auto right = static_cast<uint8_t>(left + 1);
    const auto bottom = static_cast<uint8_t>(top + 1);

    m_posInfo.awareRange = { .left = left, .top = top, .right = right, .bottom = bottom };

    updateViewportDirectionCache();
    updateViewport();

    requestUpdateVisibleTiles();
    requestUpdateMapPosInfo();
}

void MapView::onCameraMove(const Point& /*offset*/)
{
    requestUpdateMapPosInfo();
    if (isFollowingCreature()) {
        updateViewport(m_followingCreature->isWalking() ? m_followingCreature->getDirection() : Otc::InvalidDirection);
    }
}

void MapView::onFloorChange(const uint8_t /*floor*/, const uint8_t /*previousFloor*/)
{
    updateLight();
}

void MapView::onGlobalLightChange(const Light&)
{
    updateLight();
}

void MapView::updateLight()
{
    Light ambientLight = getCameraPosition().z > g_gameConfig.getMapSeaFloor() ? Light() : g_map.getLight();
    ambientLight.intensity = std::max<uint8_t >(m_minimumAmbientLight * 255, ambientLight.intensity);
    m_lightView->setGlobalLight(ambientLight);
    m_lightView->setEnabled(isDrawingLights());
}

void MapView::onTileUpdate(const Position& pos, const ThingPtr& thing, const Otc::Operation op)
{
    if (thing && thing->isOpaque() && op == Otc::OPERATION_REMOVE)
        m_resetCoveredCache = true;

    if (op == Otc::OPERATION_CLEAN) {
        if (m_lastHighlightTile && m_lastHighlightTile->getPosition() == pos)
            m_lastHighlightTile = nullptr;

        requestUpdateVisibleTiles();
    }
}

void MapView::onFadeInFinished()
{
    requestUpdateVisibleTiles();
}

// isVirtualMove is when the mouse is stopped, but the camera moves,
// so the onMouseMove event is triggered by sending the new tile position that the mouse is in.
void MapView::onMouseMove(const Position& mousePos, const bool /*isVirtualMove*/)
{
    { // Highlight Target System
        destroyHighlightTile();
        updateHighlightTile(mousePos);
    }

    if (!g_mouse.isCursorChanged()) {
        bool cursorSet = false;
        if (m_cursorAnimations) {
            if (const auto& tile = getTopTile(mousePos)) {
                if (const auto& creature = tile->getTopCreature()) {
                    if (creature->isMonster()) {
                        int id = g_mouse.getCursorId("attack");
                        if (id != -1) {
                            g_window.setMouseCursor(id);
                            cursorSet = true;
                        }
                    } else if (creature->isNpc()) {
                        int id = g_mouse.getCursorId("talk");
                        if (id != -1) {
                            g_window.setMouseCursor(id);
                            cursorSet = true;
                        }
                    }
                }
                
                if (!cursorSet) {
                    if (const auto& thing = tile->getTopUseThing()) {
                        if (thing->isContainer()) {
                            int id = g_mouse.getCursorId("containercursor");
                            if (id != -1) {
                                g_window.setMouseCursor(id);
                                cursorSet = true;
                            }
                        }
                    }
                }

                if (!cursorSet) {
                    if (const auto& thing = tile->getTopUseThing()) {
                        if (thing->isUsable()) {
                            int id = g_mouse.getCursorId("pointinghand");
                            if (id != -1) {
                                g_window.setMouseCursor(id);
                                cursorSet = true;
                            }
                        }
                    }
                }

                if (!cursorSet && tile->isWalkable()) {
                    int id = g_mouse.getCursorId("walk");
                    if (id != -1) {
                        g_window.setMouseCursor(id);
                        cursorSet = true;
                    }
                }
            }
        }

        if (!cursorSet) {
            int id = g_mouse.getCursorId("default");
            if (id != -1)
                g_window.setMouseCursor(id);
            else
                g_window.restoreMouseCursor();
        }
    }
}

void MapView::onKeyRelease(const InputEvent& inputEvent)
{
    const bool shiftPressed = inputEvent.keyboardModifiers & Fw::KeyboardShiftModifier;
    if (shiftPressed != m_shiftPressed) {
        m_shiftPressed = shiftPressed;
        onMouseMove(m_mousePosition);
    }
}

void MapView::onMapCenterChange(const Position& /*newPos*/, const Position& /*oldPos*/)
{
    requestUpdateVisibleTiles();
}

void MapView::lockFirstVisibleFloor(const uint8_t firstVisibleFloor)
{
    m_lockedFirstVisibleFloor = firstVisibleFloor;
    requestUpdateVisibleTiles();
}

void MapView::unlockFirstVisibleFloor()
{
    m_lockedFirstVisibleFloor = -1;
    requestUpdateVisibleTiles();
}

void MapView::setVisibleDimension(const Size& visibleDimension)
{
    if (visibleDimension == m_visibleDimension)
        return;

    if (visibleDimension.width() % 2 != 1 || visibleDimension.height() % 2 != 1) {
        g_logger.traceError("visible dimension must be odd");
        return;
    }

    if (visibleDimension < 3) {
        g_logger.traceError("reach max zoom in");
        return;
    }

    const auto& awareRangeSize = Size(g_map.getAwareRange().left * 2, g_map.getAwareRange().top * 2);

    m_drawViewportEdge = m_forceDrawViewportEdge;
    if (visibleDimension.width() > awareRangeSize.width() || visibleDimension.height() > awareRangeSize.height()) {
        if (m_limitVisibleDimension)
            return;
        m_drawViewportEdge = true;
    }

    updateGeometry(visibleDimension);
}

void MapView::setFloorViewMode(const Otc::FloorViewMode floorViewMode)
{
    m_floorViewMode = floorViewMode;

    resetLastCamera();
    requestUpdateVisibleTiles();
}

void MapView::setAntiAliasingMode(const Otc::AntialiasingMode mode)
{
    m_antiAliasingMode = mode;

    g_mainDispatcher.addEvent([=, this] {
        m_pool->getFrameBuffer()->setSmooth(mode != Otc::ANTIALIASING_DISABLED);
    });

    updateGeometry(m_visibleDimension);
}

void MapView::followCreature(const CreaturePtr& creature)
{
    if (creature == m_followingCreature)
        return;

    if (!creature) {
        setCameraPosition(m_followingCreature ? m_followingCreature->getPosition() : g_map.getCentralPosition());
        return;
    }

    if (m_followingCreature) m_followingCreature->setCameraFollowing(false);
    m_followingCreature = creature;
    m_followingCreature->setCameraFollowing(true);
    m_lastCameraPosition = {};
    m_follow = true;

    requestUpdateVisibleTiles();
}

void MapView::setCameraPosition(const Position& pos)
{
    if (m_followingCreature)
        m_followingCreature->setCameraFollowing(false);

    m_follow = false;
    m_customCameraPosition = pos;
    m_followingCreature = nullptr;
    requestUpdateVisibleTiles();
}

Position MapView::getPosition(const Point& mousePos)
{
    const auto newMousePos = mousePos * g_window.getDisplayDensity();
    if (!m_posInfo.rect.contains(newMousePos))
        return {};

    const auto& relativeMousePos = newMousePos - m_posInfo.rect.topLeft();
    return getPosition(relativeMousePos, m_posInfo.rect.size());
}

Position MapView::getPosition(const Point& point, const Size& mapSize)
{
    const auto& cameraPosition = getCameraPosition();

    // if we have no camera, its impossible to get the tile
    if (!cameraPosition.isValid())
        return {};

    const auto& srcRect = calcFramebufferSource(mapSize);
    const float sh = srcRect.width() / static_cast<float>(mapSize.width());
    const float sv = srcRect.height() / static_cast<float>(mapSize.height());

    const auto& framebufferPos = Point(point.x * sh, point.y * sv);
    const auto& centerOffset = (framebufferPos + srcRect.topLeft()) / m_tileSize;

    const auto& tilePos2D = m_virtualCenterOffset - m_drawDimension.toPoint() + centerOffset + Point(2);
    if (tilePos2D.x + cameraPosition.x < 0 && tilePos2D.y + cameraPosition.y < 0)
        return {};

    const auto& position = Position(tilePos2D.x, tilePos2D.y, 0) + cameraPosition;

    if (!position.isValid())
        return {};

    return position;
}

void MapView::move(const int32_t x, const int32_t y)
{
    m_moveOffset.x += x;
    m_moveOffset.y += y;

    int32_t tmp = m_moveOffset.x / g_gameConfig.getSpriteSize();
    bool requestTilesUpdate = false;
    if (tmp != 0) {
        m_customCameraPosition.x += tmp;
        m_moveOffset.x %= g_gameConfig.getSpriteSize();
        requestTilesUpdate = true;
    }

    tmp = m_moveOffset.y / g_gameConfig.getSpriteSize();
    if (tmp != 0) {
        m_customCameraPosition.y += tmp;
        m_moveOffset.y %= g_gameConfig.getSpriteSize();
        requestTilesUpdate = true;
    }

    requestUpdateMapPosInfo();

    if (requestTilesUpdate)
        requestUpdateVisibleTiles();

    onCameraMove(m_moveOffset);
}

Rect MapView::calcFramebufferSource(const Size& destSize)
{
    Point drawOffset = ((m_drawDimension - m_visibleDimension - Size(1)).toPoint() / 2) * m_tileSize;
    if (isFollowingCreature())
        drawOffset += m_followingCreature->getWalkOffset() * m_pool->getScaleFactor();
    else if (!m_moveOffset.isNull())
        drawOffset += m_moveOffset * m_pool->getScaleFactor();

    const auto& srcVisible = m_visibleDimension * m_tileSize;

    Size srcSize = destSize;
    srcSize.scale(srcVisible, Fw::KeepAspectRatio);
    drawOffset.x += (srcVisible.width() - srcSize.width()) / 2;
    drawOffset.y += (srcVisible.height() - srcSize.height()) / 2;

    return Rect(drawOffset, srcSize);
}

uint8_t MapView::calcFirstVisibleFloor(const bool checkLimitsFloorsView) const
{
    uint8_t z = g_gameConfig.getMapSeaFloor();
    // return forced first visible floor
    if (m_lockedFirstVisibleFloor != -1) {
        z = m_lockedFirstVisibleFloor;
    } else {
        // this could happens if the player is not known yet
        if (m_posInfo.camera.isValid()) {
            // if nothing is limiting the view, the first visible floor is 0
            uint8_t firstFloor = 0;

            // limits to underground floors while under sea level
            if (m_posInfo.camera.z > g_gameConfig.getMapSeaFloor())
                firstFloor = std::max<uint8_t >(m_posInfo.camera.z - g_gameConfig.getMapAwareUndergroundFloorRange(), g_gameConfig.getMapUndergroundFloorRange());

            // loop in 3x3 tiles around the camera
            for (int ix = -1; checkLimitsFloorsView && ix <= 1 && firstFloor < m_posInfo.camera.z; ++ix) {
                for (int iy = -1; iy <= 1 && firstFloor < m_posInfo.camera.z; ++iy) {
                    const auto& pos = m_posInfo.camera.translated(ix, iy);
                    const bool isLookPossible = g_map.isLookPossible(pos);

                    // process tiles that we can look through, e.g. windows, doors
                    if ((ix == 0 && iy == 0) || ((std::abs(ix) != std::abs(iy)) && isLookPossible)) {
                        Position upperPos = pos;
                        Position coveredPos = pos;

                        while (coveredPos.coveredUp() && upperPos.up() && upperPos.z >= firstFloor) {
                            // check tiles physically above
                            if (const TilePtr& tile = g_map.getTile(upperPos)) {
                                if (tile->limitsFloorsView(!isLookPossible)) {
                                    firstFloor = upperPos.z + 1;
                                    break;
                                }
                            }

                            // check tiles geometrically above
                            if (const TilePtr& tile = g_map.getTile(coveredPos)) {
                                if (tile->limitsFloorsView(isLookPossible)) {
                                    firstFloor = coveredPos.z + 1;
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            z = firstFloor;
        }
    }

    // just ensure the that the floor is in the valid range
    z = std::clamp<int>(z, 0, g_gameConfig.getMapMaxZ());
    return z;
}

uint8_t MapView::calcLastVisibleFloor() const
{
    uint8_t z = g_gameConfig.getMapSeaFloor();

    // this could happen if the player is not known yet
    if (m_posInfo.camera.isValid()) {
        // view only underground floors when below sea level
        if (m_posInfo.camera.z > g_gameConfig.getMapSeaFloor())
            z = m_posInfo.camera.z + g_gameConfig.getMapAwareUndergroundFloorRange();
        else
            z = g_gameConfig.getMapSeaFloor();
    }

    if (m_lockedFirstVisibleFloor != -1)
        z = std::max<int>(m_lockedFirstVisibleFloor, z);

    // just ensure the that the floor is in the valid range
    z = std::clamp<int>(z, 0, g_gameConfig.getMapMaxZ());
    return z;
}

TilePtr MapView::getTopTile(Position tilePos) const
{
    if (!tilePos.isValid())
        return nullptr;

    // we must check every floor, from top to bottom to check for a clickable tile
    if (m_floorViewMode == Otc::ALWAYS_WITH_TRANSPARENCY && tilePos.isInRange(m_lastCameraPosition, g_gameConfig.getTileTransparentFloorViewRange(), g_gameConfig.getTileTransparentFloorViewRange()))
        return g_map.getTile(tilePos);

    tilePos.coveredUp(tilePos.z - m_cachedFirstVisibleFloor);
    for (uint8_t i = m_cachedFirstVisibleFloor; i <= m_floorMax; ++i) {
        const auto& tile = g_map.getTile(tilePos);
        if (tile && (tilePos.z == m_lastCameraPosition.z || tile->isClickable()))
            return tile;

        tilePos.coveredDown();
    }

    return nullptr;
}

void MapView::setShader(const std::string_view name, const float fadein, const float fadeout)
{
    const auto& shader = g_shaders.getShader(name);

    if (m_shader == shader)
        return;

    g_mainDispatcher.addEvent([=, this] {
        if (fadeout > 0.0f && m_shader) {
            m_nextShader = shader;
            m_shaderSwitchDone = false;
        } else {
            m_shader = shader;
            m_nextShader = nullptr;
            m_shaderSwitchDone = true;
        }

        m_fadeTimer.restart();
        m_fadeInTime = fadein;
        m_fadeOutTime = fadeout;

        if (shader) m_shaderPosition = getCameraPosition();
    });
}

bool MapView::isDrawingLights() const { return m_drawingLight && m_lightView->isDark(); }
void MapView::setDrawLights(const bool enable)
{
    m_drawingLight = enable;

    if (enable) {
        Size lightSize = g_map.getAwareRange().dimension();
        if (m_drawDimension > lightSize)
            lightSize = m_drawDimension;

        m_lightView->resize(lightSize, m_tileSize);
        requestUpdateVisibleTiles();
    }

    updateLight();
}

void MapView::updateViewportDirectionCache()
{
    for (uint8_t dir = Otc::North; dir <= Otc::InvalidDirection; ++dir) {
        auto& vp = m_viewPortDirection[dir];
        vp.top = m_posInfo.awareRange.top;
        vp.right = m_posInfo.awareRange.right;
        vp.bottom = vp.top;
        vp.left = vp.right;

        switch (dir) {
            case Otc::North:
            case Otc::South:
                vp.top += 1;
                vp.bottom += 1;
                break;

            case Otc::West:
            case Otc::East:
                vp.right += 1;
                vp.left += 1;
                break;

            case Otc::NorthEast:
            case Otc::SouthEast:
            case Otc::NorthWest:
            case Otc::SouthWest:
                vp.left += 1;
                vp.bottom += 1;
                vp.top += 1;
                vp.right += 1;
                break;

            case Otc::InvalidDirection:
                vp.left -= 1;
                vp.right -= 1;
                break;

            default:
                break;
        }
    }
}

Position MapView::getCameraPosition() { return isFollowingCreature() ? m_followingCreature->getPosition() : m_customCameraPosition; }
std::vector<CreaturePtr> MapView::getSightSpectators(const bool multiFloor)
{
    return g_map.getSpectatorsInRangeEx(getCameraPosition(), multiFloor, m_posInfo.awareRange.left - 1, m_posInfo.awareRange.right - 2, m_posInfo.awareRange.top - 1, m_posInfo.awareRange.bottom - 2);
}

std::vector<CreaturePtr> MapView::getSpectators(const bool multiFloor)
{
    return g_map.getSpectatorsInRangeEx(getCameraPosition(), multiFloor, m_posInfo.awareRange.left, m_posInfo.awareRange.right, m_posInfo.awareRange.top, m_posInfo.awareRange.bottom);
}

void MapView::setCrosshairTexture(const std::string& texturePath)
{
    m_crosshairTexture = texturePath.empty() ? nullptr : g_textures.getTexture(texturePath);
}

void MapView::updateHighlightTile(const Position& mousePos) {
    if (m_drawHighlightTarget) {
        if ((m_lastHighlightTile = (m_shiftPressed ? getTopTile(mousePos) : g_map.getTile(mousePos))))
            m_lastHighlightTile->select(m_shiftPressed ? TileSelectType::NO_FILTERED : TileSelectType::FILTERED);
    }
}

void MapView::destroyHighlightTile() {
    if (m_lastHighlightTile) {
        m_lastHighlightTile->unselect();
        m_lastHighlightTile = nullptr;
    }
}

void MapView::addForegroundTile(const TilePtr& tile) {
    if (std::ranges::find(m_foregroundTiles, tile) == m_foregroundTiles.end())
        m_foregroundTiles.emplace_back(tile);
}
void MapView::removeForegroundTile(const TilePtr& tile) {
    const auto it = std::ranges::find(m_foregroundTiles, tile);
    if (it == m_foregroundTiles.end())
        return;

    m_foregroundTiles.erase(it);
}