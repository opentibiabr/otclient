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

#include "lightview.h"

#include "gameconfig.h"
#include "framework/core/eventdispatcher.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/painter.h"

LightView::LightView(const Size& size) : m_pool(g_drawPool.get(DrawPoolType::LIGHT)) {
    g_mainDispatcher.addEvent([this, size] {
        m_texture = std::make_shared<Texture>(size);
        m_texture->setSmooth(true);
    });
}

bool LightView::isEnabled() const { return m_pool->isEnabled(); }
void LightView::setEnabled(const bool v) { m_pool->setEnable(v); }

void LightView::resize(const Size& size, const uint16_t tileSize) {
    if (!m_texture || (m_mapSize == size && m_tileSize == tileSize))
        return;

    m_mapSize = size;
    m_tileSize = tileSize;
    m_pool->setScaleFactor(tileSize / g_gameConfig.getSpriteSize());

    m_lightData.tiles.resize(size.area());
    m_lightData.lights.clear();

    for (auto& pixels : m_pixels)
        pixels.resize(size.area() * 4);

    if (m_texture)
        m_texture->setupSize(m_mapSize);
}

void LightView::addLightSource(const Point& pos, const Light& light, const float brightness)
{
    if (!isDark() || light.intensity == 0) return;

    if (!m_lightData.lights.empty()) {
        auto& prevLight = m_lightData.lights.back();
        if (prevLight.pos == pos && prevLight.color == light.color) {
            prevLight.intensity = std::max<uint8_t>(prevLight.intensity, light.intensity);
            return;
        }
    }

    size_t hash = pos.hash();
    stdext::hash_combine(hash, light.intensity);
    stdext::hash_combine(hash, light.color);

    if (g_drawPool.getOpacity() < 1.f)
        stdext::hash_combine(hash, g_drawPool.getOpacity());

    if (m_pool->getHashController().put(hash)) {
        const float effectiveBrightness = std::min<float>(brightness, g_drawPool.getOpacity());
        m_lightData.lights.emplace_back(pos, light.intensity, light.color, effectiveBrightness);
    }
}

void LightView::resetShade(const Point& pos)
{
    const size_t index = (pos.y / m_tileSize) * m_mapSize.width() + (pos.x / m_tileSize);
    if (index >= m_lightData.tiles.size()) return;
    m_lightData.tiles[index] = m_lightData.lights.size();
}

void LightView::draw(const Rect& dest, const Rect& src)
{
    static std::atomic_bool updatePixel;

    m_pool->getHashController().put(src.hash());
    m_pool->getHashController().put(m_globalLightColor.hash());
    if (m_pool->getHashController().wasModified()) {
        updatePixels();

        SpinLock::Guard guard(m_pool->getThreadLock());
        m_pixels[0].swap(m_pixels[1]);
        updatePixel.store(true, std::memory_order_relaxed);
    }
    m_pool->getHashController().reset();

    g_drawPool.addAction([=, this] {
        if (updatePixel.load(std::memory_order_relaxed)) {
            SpinLock::Guard guard(m_pool->getThreadLock());
            m_texture->updatePixels(m_pixels[1].data());
            updatePixel.store(false, std::memory_order_relaxed);
        }

        updateCoords(dest, src);

        g_painter->setCompositionMode(CompositionMode::MULTIPLY);
        g_painter->resetTransformMatrix();
        g_painter->resetColor();
        g_painter->setTexture(m_texture);
        g_painter->drawCoords(m_coords);
    });
}

void LightView::updateCoords(const Rect& dest, const Rect& src) {
    if (m_dest == dest && m_src == src)
        return;

    const auto& offset = src.topLeft();
    const auto& size = src.size();

    m_dest = dest;
    m_src = src;

    m_coords.clear();
    m_coords.addRect(RectF(m_dest.left(), m_dest.top(), m_dest.width(), m_dest.height()),
               RectF(static_cast<float>(offset.x) / m_tileSize, static_cast<float>(offset.y) / m_tileSize,
                     static_cast<float>(size.width()) / m_tileSize, static_cast<float>(size.height()) / m_tileSize));
}

void LightView::updatePixels()
{
    const auto lightSize = m_lightData.lights.size();
    const auto mapWidth = m_mapSize.width();
    const auto mapHeight = m_mapSize.height();
    const auto tileCenterOffset = m_tileSize / 2;
    const auto invTileSize = 1.0f / m_tileSize;

    auto* pixelData = m_pixels[0].data();

    for (int y = 0; y < mapHeight; ++y) {
        for (int x = 0; x < mapWidth; ++x) {
            const auto centerX = x * m_tileSize + tileCenterOffset;
            const auto centerY = y * m_tileSize + tileCenterOffset;
            const auto index = y * mapWidth + x;

            auto r = m_globalLightColor.r();
            auto g = m_globalLightColor.g();
            auto b = m_globalLightColor.b();

            for (auto i = m_lightData.tiles[index]; i < lightSize; ++i) {
                const auto& light = m_lightData.lights[i];

                const auto dx = centerX - light.pos.x;
                const auto dy = centerY - light.pos.y;
                const auto distanceSq = dx * dx + dy * dy;

                const auto lightRadiusSq = (light.intensity * m_tileSize) * (light.intensity * m_tileSize);
                if (distanceSq > lightRadiusSq) continue;

                const auto distanceNorm = std::sqrt(distanceSq) * invTileSize;
                float intensity = (-distanceNorm + light.intensity) * 0.2f;
                if (intensity < 0.01f) continue;

                intensity = std::min<float>(intensity, 1.0f);

                const auto& lightColor = Color::from8bit(light.color) * intensity;

                r = std::max<int>(r, lightColor.r());
                g = std::max<int>(g, lightColor.g());
                b = std::max<int>(b, lightColor.b());
            }

            const auto colorIndex = index * 4;

            pixelData[colorIndex] = r;
            pixelData[colorIndex + 1] = g;
            pixelData[colorIndex + 2] = b;
            pixelData[colorIndex + 3] = 255;
        }
    }
}