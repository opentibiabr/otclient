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

class AtlasRegion
{
public:
    uint32_t textureID;
    int16_t x;
    int16_t y;
    int8_t layer;
    int16_t width;
    int16_t height;
    uint16_t transformMatrixId;
    Texture* atlas;
    std::atomic_bool enabled;

    bool isEnabled() const {
        return enabled.load(std::memory_order_relaxed);
    }

    AtlasRegion(uint32_t tid, int16_t x, int16_t y, int8_t layer,
                int16_t width, int16_t height, uint16_t transformId, Texture* atlas)
        : textureID(tid), x(x), y(y), layer(layer),
        width(width), height(height), transformMatrixId(transformId), atlas(atlas) {
    }
};

struct FreeRegion
{
    int x, y, width, height, layer;

    bool operator<(const FreeRegion& other) const {
        if (layer != other.layer) return layer < other.layer;
        if (width * height != other.width * other.height)
            return (width * height) < (other.width * other.height);
        return (y != other.y) ? (y < other.y) : (x < other.x);
    }

    bool canFit(int texWidth, int texHeight) const {
        return width >= texWidth && height >= texHeight;
    }
};

struct PairHash
{
    template <typename T1, typename T2>
    std::size_t operator()(const std::pair<T1, T2>& pair) const {
        auto hash = stdext::hash_int(pair.first);
        stdext::hash_combine(hash, stdext::hash_int(pair.second));
        return hash;
    }
};

enum AtlasFilter
{
    ATLAS_FILTER_NEAREST,
    ATLAS_FILTER_LINEAR,
    ATLAS_FILTER_COUNT
};

class TextureAtlas
{
public:
    TextureAtlas(Fw::TextureAtlasType type, int size, bool smoothSupport = false);

    void addTexture(const TexturePtr& texture);
    void removeTexture(uint32_t id, bool smooth);
    bool canAdd(const TexturePtr& texture) const;

    Size getSize() const { return m_size; }
    std::string getStats() const;

    void flush();

    auto getType() const { return m_type; }

private:
    struct Layer
    {
        std::unique_ptr<FrameBuffer> framebuffer;
        std::vector<AtlasRegion*> textures;
    };
    void createNewLayer(bool smooth);

    std::optional<FreeRegion> findBestRegion(int width, int height, bool smooth) {
        auto sizeIt = m_filterGroups[smooth].freeRegionsBySize.lower_bound(width * height);
        while (sizeIt != m_filterGroups[smooth].freeRegionsBySize.end()) {
            for (const auto& region : sizeIt->second) {
                if (region.canFit(width, height)) {
                    return region;
                }
            }
            ++sizeIt;
        }
        return std::nullopt;
    }

    void splitRegion(const FreeRegion& region, int width, int height, bool smooth) {
        m_filterGroups[smooth].freeRegions.erase(region);
        m_filterGroups[smooth].freeRegionsBySize[region.width * region.height].erase(region);

        auto insertRegion = [&](int x, int y, int w, int h) {
            if (w > 0 && h > 0) {
                FreeRegion r = { x, y, w, h, region.layer };
                m_filterGroups[smooth].freeRegions.insert(r);
                m_filterGroups[smooth].freeRegionsBySize[w * h].insert(r);
            }
        };

        insertRegion(region.x + width, region.y, region.width - width, height);
        insertRegion(region.x, region.y + height, width, region.height - height);
        insertRegion(region.x + width, region.y + height, region.width - width, region.height - height);
    }

    Fw::TextureAtlasType m_type;
    Size m_size;

    struct
    {
        std::vector<Layer> layers;
        std::set<FreeRegion> freeRegions;
        std::map<int, std::set<FreeRegion>> freeRegionsBySize;
        phmap::flat_hash_map<std::pair<int, int>, std::vector<std::unique_ptr<AtlasRegion>>, PairHash> inactiveTextures;
    } m_filterGroups[AtlasFilter::ATLAS_FILTER_COUNT];

    phmap::flat_hash_map<uint32_t, std::unique_ptr<AtlasRegion>> m_texturesCached;
};
