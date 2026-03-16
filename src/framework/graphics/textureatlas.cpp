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

#include "framebuffer.h"
#include "textureatlas.h"

#include "painter.h"
#include <framework/core/configmanager.h>

 // Extra padding around smooth textures to avoid sampling artifacts (in pixels)
static constexpr uint8_t SMOOTH_PADDING = 2;

// Limit texture size based on atlas size (Default: 35%)
static constexpr float MAX_ATLAS_TEXTURE_COVERAGE = 0.35f;

// Minimum texture size (including padding) to be cached in the atlas
// With SMOOTH_PADDING = 2 this results in 8 (4 + 2*2)
static constexpr int MIN_PADDED_ATLAS_TEXTURE_SIZE = 4 + SMOOTH_PADDING * 2;

TextureAtlas::TextureAtlas(Fw::TextureAtlasType type, int size, bool smoothSupport) :
    m_type(type),
    m_size({ std::min<int>(size, g_configs.getPublicConfig().graphics.maxAtlasSize) }) {
    createNewLayer(false);
    if (smoothSupport)
        createNewLayer(true);
}

void TextureAtlas::removeTexture(uint32_t id, bool smooth) {
    auto it = m_texturesCached.find(id);
    if (it == m_texturesCached.end()) {
        return;
    }

    it->second->enabled = false;

    auto sizeKey = std::make_pair(it->second->width, it->second->height);
    m_filterGroups[smooth].inactiveTextures.try_emplace(sizeKey, std::vector<std::unique_ptr<AtlasRegion>>())
        .first->second.emplace_back(std::move(it->second));
    m_texturesCached.erase(it);
}

bool TextureAtlas::canAdd(const TexturePtr& texture) const {
    const auto textureWidth = texture->getWidth();
    const auto textureHeight = texture->getHeight();

    const int padding = texture->isSmooth() ? SMOOTH_PADDING : 0;
    const int paddedWidth = textureWidth + padding * 2;
    const int paddedHeight = textureHeight + padding * 2;

    if (paddedWidth <= 0 || paddedHeight <= 0 ||
        paddedWidth > m_size.width() || paddedHeight > m_size.height()) {
        return false; // don't cache
    }

    if (paddedWidth < MIN_PADDED_ATLAS_TEXTURE_SIZE ||
        paddedHeight < MIN_PADDED_ATLAS_TEXTURE_SIZE) {
        return false; // too small for atlas
    }

    const int64_t atlasPixelArea = static_cast<int64_t>(m_size.width()) * m_size.height();
    const int64_t maxTextureArea = static_cast<int64_t>(atlasPixelArea * MAX_ATLAS_TEXTURE_COVERAGE);

    // Maximum texture area relative to the atlas
    return static_cast<int64_t>(paddedWidth) * paddedHeight <= maxTextureArea;
}

void TextureAtlas::addTexture(const TexturePtr& texture) {
    if (!canAdd(texture))
        return;

    const auto textureId = texture->getId();
    const auto textureWidth = texture->getWidth();
    const auto textureHeight = texture->getHeight();

    auto& filterGroup = m_filterGroups[texture->isSmooth()];

    const auto sizeKey = std::make_pair(textureWidth, textureHeight);
    if (auto it = filterGroup.inactiveTextures.find(sizeKey);
        it != filterGroup.inactiveTextures.end()) {
        auto& pool = it->second;
        if (!pool.empty()) {
            auto regionInfo = std::move(pool.back());
            pool.pop_back();

            regionInfo->textureID = textureId;
            regionInfo->transformMatrixId = texture->getTransformMatrixId();
            texture->m_atlas[m_type] = regionInfo.get();

            filterGroup.layers[regionInfo->layer].textures.emplace_back(regionInfo.get());
            m_texturesCached.emplace(textureId, std::move(regionInfo));
            return;
        }
    }

    const int padding = texture->isSmooth() ? SMOOTH_PADDING : 0;
    const int paddedWidth = textureWidth + padding * 2;
    const int paddedHeight = textureHeight + padding * 2;

    auto bestRegion = findBestRegion(paddedWidth, paddedHeight, texture->isSmooth());
    if (!bestRegion) {
        createNewLayer(texture->isSmooth());
        return addTexture(texture);
    }

    FreeRegion region = *bestRegion;
    splitRegion(region, paddedWidth, paddedHeight, texture->isSmooth());

    auto regionInfo = std::make_unique<AtlasRegion>(
        textureId,
        region.x + padding,
        region.y + padding,
        region.layer,
        static_cast<int16_t>(textureWidth),
        static_cast<int16_t>(textureHeight),
        texture->getTransformMatrixId(),
        m_filterGroups[texture->isSmooth()].layers[region.layer].framebuffer->getTexture().get()
    );

    texture->m_atlas[m_type] = regionInfo.get();
    filterGroup.layers[region.layer].textures.emplace_back(regionInfo.get());
    m_texturesCached.emplace(textureId, std::move(regionInfo));
}

void TextureAtlas::createNewLayer(bool smooth) {
    auto fbo = std::make_unique<FrameBuffer>();
    fbo->setAutoClear(false);
    fbo->setAutoResetState(true);
    fbo->setSmooth(smooth);
    fbo->resize(m_size);

    FreeRegion newRegion = { 0, 0, m_size.width(), m_size.height(), static_cast<int>(m_filterGroups[smooth].layers.size()) };

    m_filterGroups[smooth].layers.emplace_back(std::move(fbo));
    m_filterGroups[smooth].freeRegions.insert(newRegion);
    m_filterGroups[smooth].freeRegionsBySize[m_size.width() * m_size.height()].insert(newRegion);
}

void TextureAtlas::flush() {
    static CoordsBuffer buffer;
    for (auto i = -1; ++i < AtlasFilter::ATLAS_FILTER_COUNT;) {
        auto& group = m_filterGroups[i];

        const int pad = i == AtlasFilter::ATLAS_FILTER_LINEAR ? SMOOTH_PADDING : 0;

        for (auto& layer : group.layers) {
            if (!layer.textures.empty()) {
                layer.framebuffer->bind();
                glDisable(GL_BLEND);
                for (const auto& texture : layer.textures) {
                    const int x = texture->x;
                    const int y = texture->y;
                    const int w = texture->width;
                    const int h = texture->height;

                    const Rect dest = { x - pad, y - pad, Size{ w + pad * 2, h + pad * 2 } };

                    g_painter->clearRect(Color::alpha, dest);

                    if (pad > 0) {
                        buffer.clear();
                        buffer.addRect(dest, { -pad, -pad, w + pad * 2, h + pad * 2 });
                        g_painter->setTexture(texture->textureID, texture->transformMatrixId);
                        g_painter->drawCoords(buffer, DrawMode::TRIANGLE_STRIP);
                    }

                    buffer.clear();
                    buffer.addRect({ x, y, Size{ w, h } }, { 0, 0, w, h });
                    g_painter->setTexture(texture->textureID, texture->transformMatrixId);
                    g_painter->drawCoords(buffer, DrawMode::TRIANGLE_STRIP);

                    texture->enabled.store(true, std::memory_order_relaxed);
                }
                glEnable(GL_BLEND);
                layer.textures.clear();
                layer.framebuffer->release();
            }
        }
    }
}

std::string TextureAtlas::getStats() const
{
    std::stringstream ss;
    ss << "size=" << m_size.width() << "x" << m_size.height()
        << " cached=" << m_texturesCached.size();

    for (int i = 0; i < ATLAS_FILTER_COUNT; ++i) {
        const auto& group = m_filterGroups[i];
        size_t textures = 0;
        for (const auto& layer : group.layers) {
            textures += layer.textures.size();
        }
        ss << " | " << (i == ATLAS_FILTER_LINEAR ? "linear" : "nearest")
            << ":layers=" << group.layers.size()
            << " textures=" << textures
            << " free=" << group.freeRegions.size()
            << " inactive=" << group.inactiveTextures.size();
    }

    return ss.str();
}