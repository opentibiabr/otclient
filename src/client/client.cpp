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

#include "client.h"

#include "game.h"
#include "gameconfig.h"
#include "map.h"
#include "mapview.h"
#include "minimap.h"
#include "spriteappearances.h"
#include "spritemanager.h"
#include "thingtypemanager.h"
#include "uimap.h"
#include "framework/core/eventdispatcher.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/shadermanager.h"
#include "framework/ui/uimanager.h"
#ifdef FRAMEWORK_EDITOR
#include "creatures.h"
#endif
#include "paperdollmanager.h"

Client g_client;

void Client::init(std::vector<std::string>& /*args*/)
{
    // register needed lua functions
    registerLuaFunctions();

    g_gameConfig.init();
    g_map.init();
    g_minimap.init();
    g_game.init();
    g_shaders.init();
    g_sprites.init();
    g_spriteAppearances.init();
    g_things.init();
}

void Client::terminate()
{
    m_mapWidget = nullptr;

#ifdef FRAMEWORK_EDITOR
    g_creatures.terminate();
    g_map.setTerminating(true);
    g_map.terminateMapGenerator();
#endif
    g_game.terminate();
    g_map.terminate();
    g_minimap.terminate();
    g_things.terminate();
    g_sprites.terminate();
    g_spriteAppearances.terminate();
    g_shaders.terminate();
    g_paperdolls.clear();
    g_gameConfig.terminate();
}

void Client::preLoad() {
    if (m_mapWidget) {
        if (m_mapWidget->isDestroyed())
            m_mapWidget = nullptr;
        else {
            m_mapWidget->updateMapRect();
            m_mapWidget->getMapView()->preLoad();
        }
    }
}

void Client::draw(const DrawPoolType type)
{
    if (type == DrawPoolType::FOREGROUND) {
        g_ui.render(DrawPoolType::FOREGROUND);
        if (!g_game.isOnline() && !g_map.isOfflinePreview())
            m_mapWidget = nullptr;
        return;
    }

    if (!g_game.isOnline() && !g_map.isOfflinePreview()) {
        m_mapWidget = nullptr;
        return;
    }

    if (m_mapWidget && m_mapWidget->isDestroyed())
        m_mapWidget = nullptr;
    if (type == DrawPoolType::MAP && !m_mapWidget)
        m_mapWidget = g_ui.getRootWidget()->recursiveGetChildById("gameMapPanel")->static_self_cast<UIMap>();

    if (!m_mapWidget)
        return;

    if (type == DrawPoolType::FOREGROUND_MAP) {
        g_textDispatcher.poll();
        m_mapWidget->draw(DrawPoolType::CREATURE_INFORMATION);
    }

    m_mapWidget->draw(type);
}

bool Client::canDraw(const DrawPoolType type) const
{
    switch (type) {
        case DrawPoolType::MAP:
            return g_game.isOnline() || g_map.isOfflinePreview();

        case DrawPoolType::FOREGROUND:
            return g_drawPool.get(type)->canRepaint();

        case DrawPoolType::CREATURE_INFORMATION:
        case DrawPoolType::FOREGROUND_MAP:
            return g_game.isOnline() && g_drawPool.get(type)->canRepaint();

        case DrawPoolType::LIGHT:
            return g_game.isOnline() && m_mapWidget && m_mapWidget->isDrawingLights();

        default:
            return false;
    }
}

bool Client::isLoadingAsyncTexture()
{
    return g_game.isUsingProtobuf();
}

bool Client::isUsingProtobuf()
{
    return g_game.isUsingProtobuf();
}

void Client::onLoadingAsyncTextureChanged(bool /*loadingAsync*/)
{
    g_sprites.reload();
}

void Client::doMapScreenshot(std::string file)
{
    if (!m_mapWidget)
        return;

    if (file.empty()) {
        file = "screenshot_map.png";
    }

    g_drawPool.get(DrawPoolType::MAP)->getFrameBuffer()->doScreenshot(file, g_gameConfig.getSpriteSize() * 3, g_gameConfig.getSpriteSize() * 3);
}
