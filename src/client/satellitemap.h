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
#include <framework/graphics/declarations.h>
#include <unordered_map>
#include <vector>

// Manages Cyclopedia Map satellite/surface view image chunks.
// Assets are .bmp.lzma files (CIP format): 32-byte proprietary header +
// standard LZMA-alone stream decoding to a 512x512 Windows BMP.
//
// File naming: {prefix}-{lod}-{posX}-{posY}-{floor}-{hash}.bmp.lzma
//   prefix : "satellite" or "minimap"
//   lod    : scale identifier (16, 32 or 64); actual tiles/px = lod/32
//            LOD-16 → 0.5 tiles/px, 256-tile chunks (finest)
//            LOD-32 → 1.0 tiles/px, 512-tile chunks
//            LOD-64 → 2.0 tiles/px, 1024-tile chunks (coarsest)
//   posX   : chunk X origin in map-block units (tile / 32)
//   posY   : chunk Y origin in map-block units (tile / 32)
//   floor  : Tibia floor index (0-15); surface = 7
class SatelliteMap
{
public:
    // Scans dir for satellite-*.bmp.lzma / minimap-*.bmp.lzma files.
    // Stores metadata only — textures are loaded lazily on first draw.
    // Returns the number of chunks indexed.
    int loadDirectory(const std::string& dir);

    // Like loadDirectory but only indexes chunks whose floor is in [floorMin, floorMax].
    // Does NOT call clear() first — safe to call incrementally to add floors on demand.
    // Returns the number of newly indexed chunks.
    int loadFloors(const std::string& dir, int floorMin, int floorMax);

    // Releases all chunk metadata and textures.
    void clear();

    // Draws the satellite layer for cameraPos.z onto screenRect.
    // Automatically selects the best LOD for the current scale.
    // Chunks are loaded from disk on first use and cached.
    // floorSeparatorOpacity: 1.0 = all composite floors fully visible (default),
    //                        0.0 = only the target floor is rendered.
    void draw(const Rect& screenRect, const Position& cameraPos, float scale, const Color& color, float floorSeparatorOpacity = 1.0f);

    // Returns true if at least one satellite chunk exists for the given floor.
    bool hasChunksForFloor(int floor) const;

    // Returns true if the composite surface view (floors [floor, 7]) has any data.
    // Use this to decide whether to enable satellite mode in the minimap widget.
    bool hasChunksForView(int floor) const;

    // Returns true if at least one static-minimap chunk exists for the given floor.
    bool hasMinimapChunksForFloor(int floor) const;

    // Draws the static minimap (Map View) for a single floor onto screenRect.
    // Falls back gracefully when no chunks exist for that floor.
    void drawStaticMinimap(const Rect& screenRect, const Position& cameraPos, float scale, const Color& color);

    Position findRandomValidPosition(int z);

private:
    struct ChunkKey
    {
        int lod, posX, posY, floor;
        bool operator==(const ChunkKey& o) const
        {
            return lod == o.lod && posX == o.posX && posY == o.posY && floor == o.floor;
        }
    };

    struct ChunkKeyHash
    {
        size_t operator()(const ChunkKey& k) const
        {
            // FNV-inspired mixing
            size_t h = static_cast<size_t>(k.lod);
            h ^= static_cast<size_t>(k.posX) + 0x9e3779b9 + (h << 6) + (h >> 2);
            h ^= static_cast<size_t>(k.posY) + 0x9e3779b9 + (h << 6) + (h >> 2);
            h ^= static_cast<size_t>(k.floor) + 0x9e3779b9 + (h << 6) + (h >> 2);
            return h;
        }
    };

    struct ChunkInfo
    {
        std::string path;
        TexturePtr  texture;    // nullptr until first successful load
        bool        loadFailed{ false }; // set on first load failure; skips retries
    };

    // Selects the best LOD for a given scale (pixels per tile).
    static int pickLod(float scale);

    // Loads and decompresses a single chunk file, returning its texture.
    // Returns nullptr on failure (file missing, corrupt, etc.).
    static TexturePtr loadChunkTexture(const std::string& path);

    // Decompresses a CIP LZMA file: skip 32-byte header, patch size field,
    // then run standard LZMA-alone decoder.
    static std::vector<uint8_t> decompressLzma(const std::string& fileData);

    // Parses a Windows BMP (24 or 32 bpp) from raw bytes into an Image.
    static ImagePtr parseBmp(const std::vector<uint8_t>& data);

    // Scans dir exactly once and populates m_fileCache / m_fileCacheDir.
    // Subsequent calls with the same dir are no-ops.
    void buildFileCache(const std::string& dir);

    // Satellite chunks (satellite-* files): used for Surface View with composite rendering.
    std::unordered_map<ChunkKey, ChunkInfo, ChunkKeyHash> m_chunks;
    std::unordered_map<int, std::vector<ChunkKey>>        m_index;    // key = floor*100 + lod

    // Static-minimap chunks (minimap-* files): used for Map View single-floor rendering.
    std::unordered_map<ChunkKey, ChunkInfo, ChunkKeyHash> m_mmChunks;
    std::unordered_map<int, std::vector<ChunkKey>>        m_mmIndex;  // key = floor*100 + lod

    // File-scan cache: built once per directory, reused by every loadFloors() call.
    // isSatellite=true → satellite-* file; false → minimap-* file.
    struct ScannedFile { ChunkKey key; std::string path; bool isSatellite; };
    std::vector<ScannedFile> m_fileCache;
    std::string              m_fileCacheDir;
};

extern SatelliteMap g_satelliteMap;
