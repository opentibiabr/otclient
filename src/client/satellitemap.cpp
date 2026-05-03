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

#include "satellitemap.h"

#include "gameconfig.h"
#include <framework/core/logger.h>
#include <framework/core/resourcemanager.h>
#include <framework/graphics/drawpoolmanager.h>
#include <framework/graphics/image.h>
#include <framework/graphics/texture.h>

#include <lzma.h>

SatelliteMap g_satelliteMap;

static constexpr std::string_view PREFIX_SATELLITE = "satellite";
static constexpr std::string_view PREFIX_MINIMAP   = "minimap";
static constexpr int SURFACE_FLOOR = 7;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

int SatelliteMap::loadDirectory(const std::string& dir)
{
    clear();
    return loadFloors(dir, 0, 15);
}

int SatelliteMap::loadFloors(const std::string& dir, const int floorMin, const int floorMax)
{
    // Clear stale chunk data whenever the source directory changes.
    if (dir != m_fileCacheDir) {
        m_chunks.clear();
        m_index.clear();
        m_mmChunks.clear();
        m_mmIndex.clear();
    }

    // Build the file list exactly once per directory — reused on every subsequent call.
    buildFileCache(dir);

    int count = 0;
    for (const auto& sf : m_fileCache) {
        if (sf.key.floor < floorMin || sf.key.floor > floorMax)
            continue;

        if (sf.isSatellite) {
            if (m_chunks.count(sf.key))
                continue;
            m_chunks[sf.key] = ChunkInfo{ sf.path, nullptr };
            m_index[sf.key.floor * 100 + sf.key.lod].push_back(sf.key);
        } else {
            if (m_mmChunks.count(sf.key))
                continue;
            m_mmChunks[sf.key] = ChunkInfo{ sf.path, nullptr };
            m_mmIndex[sf.key.floor * 100 + sf.key.lod].push_back(sf.key);
        }
        ++count;
    }

    if (count > 0)
        g_logger.debug("SatelliteMap: indexed {} chunks (floors {}-{}) from '{}'", count, floorMin, floorMax, dir);

    return count;
}

void SatelliteMap::buildFileCache(const std::string& dir)
{
    if (dir == m_fileCacheDir)
        return; // already scanned

    m_fileCache.clear();
    m_fileCacheDir = dir;

    const auto files = g_resources.listDirectoryFiles(dir, /*fullPath=*/false);

    for (const auto& name : files) {
        if (name.find(".bmp.lzma") == std::string::npos)
            continue;

        char prefix[16]{};
        int lod = 0, posX = 0, posY = 0, floor = 0;

        // Expected format: {prefix}-{lod}-{posX}-{posY}-{floor}-{hash}.bmp.lzma
        if (std::sscanf(name.c_str(), "%15[a-z]-%d-%d-%d-%d-", prefix, &lod, &posX, &posY, &floor) != 5)
            continue;

        const std::string_view p{ prefix };
        if (p != PREFIX_SATELLITE && p != PREFIX_MINIMAP)
            continue;

        if (lod != 16 && lod != 32 && lod != 64)
            continue;

        if (floor < 0 || floor > 15)
            continue;

        m_fileCache.push_back({ { lod, posX, posY, floor }, dir + "/" + name, p == PREFIX_SATELLITE });
    }

    g_logger.debug("SatelliteMap: scanned {} chunk files from '{}'", m_fileCache.size(), dir);
}

void SatelliteMap::clear()
{
    m_chunks.clear();
    m_index.clear();
    m_mmChunks.clear();
    m_mmIndex.clear();
    m_fileCache.clear();
    m_fileCacheDir.clear();
}

void SatelliteMap::draw(const Rect& screenRect, const Position& cameraPos, float scale, const Color& color, float floorSeparatorOpacity)
{
    if (screenRect.isEmpty() || m_chunks.empty())
        return;

    const auto oldClipRect = g_drawPool.getClipRect();
    g_drawPool.setClipRect(screenRect);
    
    // Water background only for floor 7 (sea floor). All other floors use black.
    g_drawPool.addFilledRect(screenRect, cameraPos.z == g_gameConfig.getMapSeaFloor() ? Color(0xFFA54C27U) : Color::black);

    const Point screenCenter = screenRect.center();

    // Composite floors from the surface (floor 7) down to the target floor.
    // Floor 7 is the solid base; higher floors (lower z) paint structures on top
    // with alpha transparency so the surface remains visible through empty areas.
    // Render the best LOD for the current scale plus one coarser for smooth transitions.
    const int targetFloor = cameraPos.z;
    const int bestLod    = pickLod(scale);
    const int coarserLod = (bestLod == 16) ? 32 : 64;

    for (int floor = SURFACE_FLOOR; floor >= targetFloor; --floor) {
        // Target floor is always fully opaque.
        // Background floors (floor 7 and intermediaries) use floorSeparatorOpacity:
        //   0.0 = hidden → only target floor visible
        //   1.0 = fully opaque → full composite view (target + background)
        const bool isTargetFloor = (floor == targetFloor);
        const bool applyOpacity  = !isTargetFloor;

        if (applyOpacity) {
            if (floorSeparatorOpacity <= 0.0f)
                continue;
            if (floorSeparatorOpacity < 1.0f)
                g_drawPool.setOpacity(floorSeparatorOpacity);
        }

        int seenLod = -1;
        for (const int lod : { coarserLod, bestLod }) {
            if (lod == seenLod) continue;
            seenLod = lod;
            const int indexKey = floor * 100 + lod;
            const auto it = m_index.find(indexKey);
            if (it == m_index.end())
                continue;

            // Tiles covered per chunk: 512 px × (lod/32) tiles/px
            const float chunkTiles = 512.f * (static_cast<float>(lod) / 32.f);

            for (const ChunkKey& key : it->second) {
                // Compute screen rect first — skip off-screen chunks before loading texture.
                const float tileOx = static_cast<float>(key.posX) * 32.f;
                const float tileOy = static_cast<float>(key.posY) * 32.f;

                const float screenLeft = screenCenter.x + (tileOx - cameraPos.x) * scale;
                const float screenTop  = screenCenter.y + (tileOy - cameraPos.y) * scale;
                const float screenW    = chunkTiles * scale;
                const float screenH    = chunkTiles * scale;

                const Rect dest(
                    static_cast<int>(std::floor(screenLeft)),
                    static_cast<int>(std::floor(screenTop)),
                    static_cast<int>(std::ceil(screenW)),
                    static_cast<int>(std::ceil(screenH))
                );

                if (!dest.intersects(screenRect))
                    continue;

                // Lazy-load texture only for visible chunks.
                ChunkInfo& info = m_chunks.at(key);
                if (!info.texture) {
                    if (info.loadFailed)
                        continue;
                    info.texture = loadChunkTexture(info.path);
                    if (!info.texture) {
                        info.loadFailed = true;
                        g_logger.warning("SatelliteMap: failed to load chunk '{}'", info.path);
                        continue;
                    }
                }

                g_drawPool.addTexturedRect(dest, info.texture, Rect(0, 0, 512, 512));
            }
        }

        if (applyOpacity && floorSeparatorOpacity < 1.0f)
            g_drawPool.resetOpacity();
    }
    g_drawPool.setClipRect(oldClipRect);
}

void SatelliteMap::drawStaticMinimap(const Rect& screenRect, const Position& cameraPos, float scale, const Color& color)
{
    if (screenRect.isEmpty() || m_mmChunks.empty())
        return;

    const auto oldClipRect = g_drawPool.getClipRect();
    g_drawPool.setClipRect(screenRect);

    g_drawPool.addFilledRect(screenRect, cameraPos.z == g_gameConfig.getMapSeaFloor() ? Color(0xFFA54C27U) : Color::black);

    const Point screenCenter = screenRect.center();
    const int floor = cameraPos.z;

    // Single-floor rendering — coarser LOD first so finer detail paints on top.
    const int bestLod    = pickLod(scale);
    const int coarserLod = (bestLod == 16) ? 32 : 64;
    int seenLod = -1;
    for (const int lod : { coarserLod, bestLod }) {
        if (lod == seenLod) continue;
        seenLod = lod;
        const int indexKey = floor * 100 + lod;
        const auto it = m_mmIndex.find(indexKey);
        if (it == m_mmIndex.end())
            continue;

        const float chunkTiles = 512.f * (static_cast<float>(lod) / 32.f);

        for (const ChunkKey& key : it->second) {
            const float tileOx = static_cast<float>(key.posX) * 32.f;
            const float tileOy = static_cast<float>(key.posY) * 32.f;

            const float screenLeft = screenCenter.x + (tileOx - cameraPos.x) * scale;
            const float screenTop  = screenCenter.y + (tileOy - cameraPos.y) * scale;
            const float screenW    = chunkTiles * scale;
            const float screenH    = chunkTiles * scale;

            const Rect dest(
                static_cast<int>(std::floor(screenLeft)),
                static_cast<int>(std::floor(screenTop)),
                static_cast<int>(std::ceil(screenW)),
                static_cast<int>(std::ceil(screenH))
            );

            if (!dest.intersects(screenRect))
                continue;

            ChunkInfo& info = m_mmChunks.at(key);
            if (!info.texture) {
                if (info.loadFailed)
                    continue;
                info.texture = loadChunkTexture(info.path);
                if (!info.texture) {
                    info.loadFailed = true;
                    g_logger.warning("SatelliteMap: failed to load minimap chunk '{}'", info.path);
                    continue;
                }
            }

            g_drawPool.addTexturedRect(dest, info.texture, Rect(0, 0, 512, 512));
        }
    }

    g_drawPool.setClipRect(oldClipRect);
}

bool SatelliteMap::hasChunksForFloor(const int floor) const
{
    // Check any LOD
    for (const int lod : { 16, 32, 64 }) {
        if (m_index.count(floor * 100 + lod))
            return true;
    }
    return false;
}

bool SatelliteMap::hasChunksForView(const int floor) const
{
    // Surface view composites floors [floor, SURFACE_FLOOR].
    // Returns true if any floor in that range has satellite chunks.
    if (floor > SURFACE_FLOOR)
        return false;
    for (int f = floor; f <= SURFACE_FLOOR; ++f) {
        if (hasChunksForFloor(f))
            return true;
    }
    return false;
}

bool SatelliteMap::hasMinimapChunksForFloor(const int floor) const
{
    for (const int lod : { 16, 32, 64 }) {
        if (m_mmIndex.count(floor * 100 + lod))
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

int SatelliteMap::pickLod(const float scale)
{
    // scale = screen pixels per tile; tilesPerPixel = 1/scale.
    // Native resolution of each LOD: lod/32 tiles per image pixel.
    //   LOD-16: 0.5 tiles/px  (finest detail, 256-tile chunks)
    //   LOD-32: 1.0 tiles/px  (medium,        512-tile chunks)
    //   LOD-64: 2.0 tiles/px  (coarsest,      1024-tile chunks)
    // Choose the finest LOD whose native resolution is not finer than the screen.
    const float tilesPerPixel = 1.f / scale;
    if (tilesPerPixel <= 0.5f) return 16;
    if (tilesPerPixel <= 1.0f) return 32;
    return 64;
}

TexturePtr SatelliteMap::loadChunkTexture(const std::string& path)
{
    std::string fileData;
    try {
        fileData = g_resources.readFileContents(path);
    } catch (const std::exception& e) {
        g_logger.warning("SatelliteMap: cannot read '{}': {}", path, e.what());
        return nullptr;
    }

    const auto pixels = decompressLzma(fileData);
    if (pixels.empty())
        return nullptr;

    const auto image = parseBmp(pixels);
    if (!image)
        return nullptr;

    if (image->getWidth() != 512 || image->getHeight() != 512) {
        g_logger.error("SatelliteMap: chunk '{}' has unexpected size {}x{} (expected 512x512), skipping",
                       path, image->getWidth(), image->getHeight());
        return nullptr;
    }

    return std::make_shared<Texture>(image);
}

std::vector<uint8_t> SatelliteMap::decompressLzma(const std::string& fileData)
{
    // CIP format: 32-byte proprietary header followed by an LZMA-alone stream
    // whose "uncompressed size" field (bytes 5–12) is set to an invalid value.
    // We override those 8 bytes with 0xFF (= unknown size) before decoding.

    constexpr size_t CIP_HEADER_SIZE = 32;
    constexpr size_t LZMA_PROPS_SIZE = 5;
    constexpr size_t LZMA_SIZE_FIELD = 8; // bytes after props

    if (fileData.size() <= CIP_HEADER_SIZE + LZMA_PROPS_SIZE + LZMA_SIZE_FIELD)
        return {};

    std::vector<uint8_t> lzmaData(
        reinterpret_cast<const uint8_t*>(fileData.data()) + CIP_HEADER_SIZE,
        reinterpret_cast<const uint8_t*>(fileData.data()) + fileData.size()
    );

    // Patch uncompressed-size to "unknown" so liblzma accepts the stream
    std::fill(lzmaData.begin() + LZMA_PROPS_SIZE,
              lzmaData.begin() + LZMA_PROPS_SIZE + LZMA_SIZE_FIELD,
              0xFFu);

    lzma_stream strm = LZMA_STREAM_INIT;
    constexpr size_t LZMA_MEMORY_LIMIT_BYTES = 64ull * 1024 * 1024;
    const lzma_ret initRet = lzma_alone_decoder(&strm, LZMA_MEMORY_LIMIT_BYTES);
    if (initRet != LZMA_OK) {
        if (initRet == LZMA_MEMLIMIT_ERROR)
            g_logger.warning("SatelliteMap: LZMA decoder init failed: memory limit exceeded");
        else
            g_logger.warning("SatelliteMap: failed to init LZMA decoder");
        return {};
    }

    strm.next_in  = lzmaData.data();
    strm.avail_in = lzmaData.size();

    std::vector<uint8_t> output;
    output.reserve(512 * 512 * 4 + 2048); // typical 32-bpp BMP for 512×512

    // Hard cap: parseBmp rejects images wider/taller than 4096 px, so
    // 4096×4096×4 bpp + 2 KB header is the largest valid payload (~67 MB).
    // Abort decompression if output would exceed this to prevent memory exhaustion
    // from malformed/malicious .bmp.lzma files.
    constexpr size_t MAX_DECOMPRESSED = 4096ULL * 4096 * 4 + 2048;

    std::array<uint8_t, 65536> buf{};
    lzma_ret ret = LZMA_OK;

    // Feed all input at once; LZMA_FINISH signals end of input so the decoder
    // can flush the last bytes even when the uncompressed size is unknown.
    while (ret == LZMA_OK || ret == LZMA_STREAM_END) {
        strm.next_out  = buf.data();
        strm.avail_out = buf.size();

        const lzma_action action = (strm.avail_in == 0) ? LZMA_FINISH : LZMA_RUN;
        ret = lzma_code(&strm, action);

        const size_t got = buf.size() - strm.avail_out;

        if (output.size() + got > MAX_DECOMPRESSED) {
            g_logger.warning("SatelliteMap: decompressed size exceeds limit, aborting '{}'", "chunk");
            lzma_end(&strm);
            return {};
        }

        output.insert(output.end(), buf.begin(), buf.begin() + got);

        if (ret == LZMA_STREAM_END)
            break;
    }

    lzma_end(&strm);

    if (ret != LZMA_STREAM_END) {
        g_logger.warning("SatelliteMap: LZMA decompression error ({})", static_cast<int>(ret));
        return {};
    }

    return output;
}

ImagePtr SatelliteMap::parseBmp(const std::vector<uint8_t>& data)
{
    // Minimal Windows BMP parser supporting 24-bpp and 32-bpp BI_RGB/BI_BITFIELDS formats.
    // CIP satellite files use BI_BITFIELDS (compression=3) with standard BGRA masks.
    // Image expects RGBA.

    constexpr size_t BMP_MIN_HEADER = 54; // file header (14) + DIB header (40)

    if (data.size() < BMP_MIN_HEADER)
        return nullptr;

    if (data[0] != 'B' || data[1] != 'M')
        return nullptr;

    // Read fields with explicit byte ordering (little-endian)
    auto readU16 = [&](size_t off) -> uint16_t {
        return static_cast<uint16_t>(data[off]) |
               (static_cast<uint16_t>(data[off + 1]) << 8);
    };
    auto readI32 = [&](size_t off) -> int32_t {
        return static_cast<int32_t>(
            static_cast<uint32_t>(data[off]) |
            (static_cast<uint32_t>(data[off + 1]) << 8) |
            (static_cast<uint32_t>(data[off + 2]) << 16) |
            (static_cast<uint32_t>(data[off + 3]) << 24)
        );
    };
    auto readU32 = [&](size_t off) -> uint32_t {
        return static_cast<uint32_t>(readI32(off));
    };

    const uint32_t pixelOffset = readU32(10);
    const int32_t  width       = readI32(18);
    int32_t        height      = readI32(22);
    const uint16_t bpp         = readU16(28);

    const bool topDown = (height < 0);
    const int64_t mag = topDown ? -(int64_t)height : (int64_t)height;
    if (width <= 0 || width > 4096 || mag == 0 || mag > 4096)
        return nullptr;
    height = static_cast<int32_t>(mag);

    const uint32_t compression = readU32(30);

    // BI_BITFIELDS (3): pixel data is uncompressed; channel layout defined by masks.
    // CIP satellite files use this with 32-bpp and standard BGRA masks.
    const bool isBitfields = (compression == 3);
    if (compression != 0 && !isBitfields) {
        g_logger.warning("SatelliteMap: unsupported BMP compression {}", compression);
        return nullptr;
    }

    if (bpp != 24 && bpp != 32)
        return nullptr;

    if (isBitfields && bpp != 32) {
        g_logger.warning("SatelliteMap: BI_BITFIELDS only supported for 32-bpp");
        return nullptr;
    }

    // For BI_BITFIELDS, read R/G/B masks (3 DWORDs at offsets 54–62).
    // CIP satellite files store alpha in the high byte (0xFF = opaque terrain/structure,
    // 0x00 = transparent sky/empty area), so aMask is inferred as ~(R|G|B).
    // This is valid even for BITMAPINFOHEADER (size=40): the 4th byte acts as alpha.
    uint32_t rMask = 0x00FF0000u, gMask = 0x0000FF00u,
             bMask = 0x000000FFu, aMask = 0xFF000000u;
    if (isBitfields) {
        if (data.size() < 66) // 54-byte base header + 12 bytes for 3 masks
            return nullptr;
        rMask = readU32(54);
        gMask = readU32(58);
        bMask = readU32(62);
        aMask = ~(rMask | gMask | bMask);
    }

    // Bit-shift for each mask = position of its lowest set bit.
    auto maskShift = [](uint32_t m) -> int {
        if (!m) return 0;
        int s = 0;
        while (!(m & 1u)) { m >>= 1; ++s; }
        return s;
    };
    const int rShift = maskShift(rMask);
    const int gShift = maskShift(gMask);
    const int bShift = maskShift(bMask);
    const int aShift = maskShift(aMask);

    const int bytesPerPixel = bpp / 8;
    const int rowStride     = (width * bytesPerPixel + 3) & ~3; // 4-byte aligned

    if (pixelOffset >= data.size())
        return nullptr;

    if (data.size() < pixelOffset + static_cast<size_t>(rowStride) * height)
        return nullptr;

    auto image = std::make_shared<Image>(Size(width, height), /*bpp=*/4);
    const uint8_t* src = data.data() + pixelOffset;

    for (int y = 0; y < height; ++y) {
        const int srcY = topDown ? y : (height - 1 - y);
        const uint8_t* row = src + static_cast<ptrdiff_t>(srcY) * rowStride;

        for (int x = 0; x < width; ++x) {
            const uint8_t* p = row + x * bytesPerPixel;
            uint8_t r, g, b, a;
            if (isBitfields) {
                // Extract channels via masks from a packed 32-bit little-endian pixel
                const uint32_t px = static_cast<uint32_t>(p[0])        |
                                    (static_cast<uint32_t>(p[1]) << 8)  |
                                    (static_cast<uint32_t>(p[2]) << 16) |
                                    (static_cast<uint32_t>(p[3]) << 24);
                r = static_cast<uint8_t>((px & rMask) >> rShift);
                g = static_cast<uint8_t>((px & gMask) >> gShift);
                b = static_cast<uint8_t>((px & bMask) >> bShift);
                a = aMask ? static_cast<uint8_t>((px & aMask) >> aShift) : uint8_t{ 255 };
            } else {
                // BI_RGB: BMP stores BGR(A)
                r = p[2]; g = p[1]; b = p[0];
                a = (bpp == 32) ? p[3] : uint8_t{ 255 };
            }
            const uint8_t rgba[4] = { r, g, b, a };
            image->setPixel(x, y, rgba);
        }
    }

    return image;
}
