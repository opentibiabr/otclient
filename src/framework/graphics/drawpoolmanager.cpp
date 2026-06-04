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

#include "drawpoolmanager.h"

#include "graphics.h"
#include "painter.h"
#include "textureatlas.h"
#include <framework/core/configmanager.h>

thread_local static uint8_t CURRENT_POOL = static_cast<uint8_t>(DrawPoolType::LAST);

void resetSelectedPool() {
    CURRENT_POOL = static_cast<uint8_t>(DrawPoolType::LAST);
}

DrawPoolManager g_drawPool;

void DrawPoolManager::init(const uint16_t spriteSize)
{
    if (spriteSize != 0)
        m_spriteSize = spriteSize;

    auto mapAtlasSize = g_configs.getPublicConfig().graphics.mapAtlasSize;
    auto foregroundAtlasSize = g_configs.getPublicConfig().graphics.foregroundAtlasSize;

    if (mapAtlasSize == 0)
        mapAtlasSize = g_graphics.getMaxTextureSize();

    if (foregroundAtlasSize == 0)
        foregroundAtlasSize = g_graphics.getMaxTextureSize();

    auto atlasMap = mapAtlasSize > 0 ? std::make_shared<TextureAtlas>(Fw::TextureAtlasType::MAP, mapAtlasSize) : nullptr;
    auto atlasForeground = foregroundAtlasSize > 0 ? std::make_shared<TextureAtlas>(Fw::TextureAtlasType::FOREGROUND, foregroundAtlasSize, true) : nullptr;

    // Create Pools
    for (int8_t i = -1; ++i < static_cast<uint8_t>(DrawPoolType::LAST);) {
        auto pool = m_pools[i] = DrawPool::create(static_cast<DrawPoolType>(i));

        switch (static_cast<DrawPoolType>(i)) {
            case DrawPoolType::MAP:
                pool->m_atlas = atlasMap;
                break;

            case DrawPoolType::FOREGROUND:
            case DrawPoolType::FOREGROUND_MAP:
            case DrawPoolType::CREATURE_INFORMATION:
                pool->m_atlas = atlasForeground;
                break;

            default: break;
        }
    }
}

void DrawPoolManager::terminate() const
{
    // Destroy Pools
    for (int_fast8_t i = -1; ++i < static_cast<uint8_t>(DrawPoolType::LAST);) {
        delete m_pools[i];
    }
}

DrawPoolType DrawPoolManager::getCurrentType() const { return static_cast<DrawPoolType>(CURRENT_POOL); }
bool DrawPoolManager::isValid() const { return CURRENT_POOL < static_cast<uint8_t>(DrawPoolType::LAST); }
DrawPool* DrawPoolManager::getCurrentPool() const { return m_pools[CURRENT_POOL]; }
void DrawPoolManager::select(DrawPoolType type) { CURRENT_POOL = static_cast<uint8_t>(type); }
bool DrawPoolManager::isPreDrawing() const { return CURRENT_POOL != static_cast<uint8_t>(DrawPoolType::LAST); }
bool DrawPoolManager::shaderNeedFramebuffer() const { return getCurrentPool()->getCurrentState().shaderProgram && getCurrentPool()->getCurrentState().shaderProgram->useFramebuffer(); }

void DrawPoolManager::draw()
{
    if (m_size != g_graphics.getViewportSize()) {
        m_size = g_graphics.getViewportSize();
        m_transformMatrix = g_painter->getTransformMatrix(m_size);
        g_painter->setResolution(m_size, m_transformMatrix);
    }

    for (int8_t i = -1; ++i < static_cast<uint8_t>(DrawPoolType::LAST);) {
        drawPool(static_cast<DrawPoolType>(i));
    }
}

void DrawPoolManager::drawObject(DrawPool* pool, const DrawPool::DrawObject& obj)
{
    if (obj.action) {
        obj.action();
    } else if (obj.coords) {
        obj.state.execute(pool);
        g_painter->drawCoords(*obj.coords, DrawMode::TRIANGLES);
    }
}

void DrawPoolManager::addTexturedCoordsBuffer(const TexturePtr& texture, const CoordsBufferPtr& coords, const Color& color) const
{
    getCurrentPool()->add(color, texture, DrawPool::DrawMethod{}, coords);
}

void DrawPoolManager::addTexturedRect(const Rect& dest, const TexturePtr& texture, const Rect& src, const Color& color) const
{
    if (dest.isEmpty() || src.isEmpty()) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, texture, DrawPool::DrawMethod{
        .type = DrawPool::DrawMethodType::RECT,
        .dest = dest, .src = src
    });
}

void DrawPoolManager::addUpsideDownTexturedRect(const Rect& dest, const TexturePtr& texture, const Rect& src, const Color& color) const
{
    if (dest.isEmpty() || src.isEmpty()) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, texture, DrawPool::DrawMethod{ .type = DrawPool::DrawMethodType::UPSIDEDOWN_RECT, .dest =
                              dest,
                              .src = src
                          });
}

void DrawPoolManager::addTexturedRepeatedRect(const Rect& dest, const TexturePtr& texture, const Rect& src, const Color& color) const
{
    if (dest.isEmpty() || src.isEmpty()) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, texture, DrawPool::DrawMethod{ .type = DrawPool::DrawMethodType::REPEATED_RECT, .dest =
                              dest,
                              .src = src
                          });
}

void DrawPoolManager::addFilledRect(const Rect& dest, const Color& color) const
{
    if (dest.isEmpty()) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, nullptr, DrawPool::DrawMethod{ .type = DrawPool::DrawMethodType::RECT, .dest = dest });
}

void DrawPoolManager::addFilledTriangle(const Point& a, const Point& b, const Point& c, const Color& color) const
{
    if (a == b || a == c || b == c) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, nullptr, DrawPool::DrawMethod{
            .type = DrawPool::DrawMethodType::TRIANGLE,
            .a = a,
            .b = b,
            .c = c
     });
}

void DrawPoolManager::addBoundingRect(const Rect& dest, const Color& color, const uint16_t innerLineWidth) const
{
    if (dest.isEmpty() || innerLineWidth == 0) {
        getCurrentPool()->resetOnlyOnceParameters();
        return;
    }

    getCurrentPool()->add(color, nullptr, DrawPool::DrawMethod{
        .type = DrawPool::DrawMethodType::BOUNDING_RECT,
        .dest = dest,
        .intValue = innerLineWidth
    });
}

void DrawPoolManager::preDraw(const DrawPoolType type, const std::function<void()>& f, const std::function<void()>& beforeRelease, const Rect& dest, const Rect& src, const Color& colorClear)
{
    select(type);
    const auto pool = getCurrentPool();

    pool->resetState();

    if (f) f();

    if (beforeRelease)
        beforeRelease();

    if (pool->hasFrameBuffer()) {
        addAction([pool, dest, src, colorClear] {
            pool->m_framebuffer->prepare(dest, src, colorClear);
        });
    }

    pool->release();

    resetSelectedPool();
}

void DrawPoolManager::drawObjects(DrawPool* pool) {
    const auto hasFramebuffer = pool->hasFrameBuffer();

    const auto shouldRepaint = pool->shouldRepaint();
    if (!shouldRepaint && hasFramebuffer)
        return;

    if (hasFramebuffer)
        pool->m_framebuffer->bind();

    if (shouldRepaint) {
        SpinLock::Guard guard(pool->m_threadLock);
        pool->m_objectsDraw[0].swap(pool->m_objectsDraw[1]);
        pool->m_shouldRepaint.store(false, std::memory_order_relaxed);
    }

    for (auto& obj : pool->m_objectsDraw[1]) {
        drawObject(pool, obj);
    }

    if (hasFramebuffer) {
        pool->m_framebuffer->release();
    }

    if (pool->m_atlas)
        pool->m_atlas->flush();
}

void DrawPoolManager::drawPool(const DrawPoolType type) {
    const auto pool = get(type);

    if (!pool->isEnabled())
        return;

    drawObjects(pool);

    if (pool->hasFrameBuffer()) {
        g_painter->resetState();

        if (pool->m_beforeDraw) pool->m_beforeDraw();
        pool->m_framebuffer->draw();
        if (pool->m_afterDraw) pool->m_afterDraw();
    }
}

void DrawPoolManager::removeTextureFromAtlas(uint32_t id, bool smooth) {
    for (auto pool : m_pools) {
        if (pool->m_atlas)
            pool->m_atlas->removeTexture(id, smooth);
    }
}

std::string DrawPoolManager::getAtlasStats() const
{
    std::stringstream ss;
    const auto* mapAtlas = get(DrawPoolType::MAP)->getAtlas();
    const auto* fgAtlas = get(DrawPoolType::FOREGROUND)->getAtlas();

    ss << "map=" << (mapAtlas ? mapAtlas->getStats() : "disabled");
    ss << " | fg=" << (fgAtlas ? fgAtlas->getStats() : "disabled");
    return ss.str();
}