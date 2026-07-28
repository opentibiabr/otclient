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

#if DRAWPOOL_STATS
#include <framework/core/logger.h>
#include <chrono>
#endif

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

#if DRAWPOOL_STATS
    // Atlas diagnostic: a null atlas means no texture batching at all for that pool.
    // maxTextureSize is what sizes the atlases, so a low value here disables them.
    g_logger.info("DrawPoolManager::init() - maxTextureSize: " + std::to_string(g_graphics.getMaxTextureSize()));
    for (int8_t i = -1; ++i < static_cast<uint8_t>(DrawPoolType::LAST);) {
        const auto pool = m_pools[i];
        const auto type = static_cast<DrawPoolType>(i);
        const char* name = getPoolTypeName(type);
        const bool hasAtlas = pool->m_atlas != nullptr;
        g_logger.info(std::string("  Pool ") + name + " (" + std::to_string(i) + "): atlas=" + (hasAtlas ? "yes" : "no"));
    }
#endif
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

#if DRAWPOOL_STATS
    ++m_frameCount;
    logStats();
#endif
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

#if DRAWPOOL_STATS
    const auto poolIndex = static_cast<uint8_t>(pool->getType());
    const size_t drawCount = pool->m_objectsDraw[1].size();
    m_poolStats[poolIndex].drawCalls += drawCount;
    m_poolStats[poolIndex].repaints += shouldRepaint ? 1 : 0;
#endif

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

#if DRAWPOOL_STATS
const char* DrawPoolManager::getPoolTypeName(DrawPoolType type) const
{
    switch (type) {
        case DrawPoolType::MAP: return "MAP";
        case DrawPoolType::CREATURE_INFORMATION: return "CREATURE_INFORMATION";
        case DrawPoolType::LIGHT: return "LIGHT";
        case DrawPoolType::FOREGROUND_MAP: return "FOREGROUND_MAP";
        case DrawPoolType::FOREGROUND: return "FOREGROUND";
        default: return "UNKNOWN";
    }
}

void DrawPoolManager::logStats()
{
    const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();

    if (m_lastLogTime == 0) {
        m_lastLogTime = now;
        return;
    }

    const auto elapsed = now - m_lastLogTime;
    if (elapsed < 1000) {
        return; // log once per second
    }

    // Legend, emitted once so the terse lines below are readable on their own.
    static bool legendShown = false;
    if (!legendShown) {
        g_logger.info("DrawPool stats legend: pool_name=repaints:draw_calls:avg_per_repaint");
        legendShown = true;
    }

    // One line per pool that did anything this period.
    for (int8_t i = -1; ++i < static_cast<uint8_t>(DrawPoolType::LAST);) {
        const auto type = static_cast<DrawPoolType>(i);
        const auto& stats = m_poolStats[i];
        if (stats.drawCalls > 0 || stats.repaints > 0) {
            const char* name = getPoolTypeName(type);
            const uint64_t avg = stats.repaints > 0 ? stats.drawCalls / stats.repaints : 0;
            g_logger.info(std::string("DrawPool ") + name + "=" + std::to_string(stats.repaints) + ":" +
                         std::to_string(stats.drawCalls) + ":" + std::to_string(avg));
        }
    }

    g_logger.info(std::string("DrawPool frames this period: ") + std::to_string(m_frameCount));

    // Reset the counters for the next period.
    for (auto& stats : m_poolStats) {
        stats = PoolStats{};
    }
    m_frameCount = 0;
    m_lastLogTime = now;
}
#endif