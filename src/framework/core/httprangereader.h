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

#ifdef __EMSCRIPTEN__

#include <list>
#include <string>
#include <vector>
#include <cstdint>

/**
 * HttpRangeReader - HTTP Range Request backed file reader for Emscripten/WASM builds.
 *
 * WHY SYNCHRONOUS FETCH IS OK HERE:
 * The callers (FileStream::read, driven by SpriteManager) are synchronous, and this
 * only works outside the browser's main thread. This is safe because the build links
 * with -sPROXY_TO_PTHREAD, which runs main() in a worker thread. If that flag is
 * removed, this will freeze the browser tab.
 *
 * WHY SMALL CHUNKS (256KB):
 * Each cache miss triggers a synchronous fetch, which stalls the calling thread.
 * Smaller chunks reduce the stall duration at the cost of more requests for
 * sequential reads. 256KB is a balance between request overhead and stall time.
 */
class HttpRangeReader
{
public:
    static constexpr uint32_t CHUNK_SIZE = 256 * 1024;        // 256KB chunks
    static constexpr uint32_t MAX_CACHED_BYTES = 32 * 1024 * 1024; // 32MB LRU cache

    struct RemoteFileInfo {
        std::string path;    // Virtual path (e.g., /data/things/860/Tibia.spr)
        std::string url;       // URL to fetch from (e.g., /assets/things/860/Tibia.spr)
        uint64_t size;         // File size in bytes
    };

    // Chunk cache entry
    struct CacheEntry {
        uint64_t startOffset;              // Start offset in file
        std::vector<uint8_t> data;         // Chunk data
        std::list<uint64_t>::iterator lruIter; // Iterator into LRU list
    };

    HttpRangeReader(const RemoteFileInfo& info);
    ~HttpRangeReader() = default;

    // Disable copy/move
    HttpRangeReader(const HttpRangeReader&) = delete;
    HttpRangeReader& operator=(const HttpRangeReader&) = delete;

    // File operations
    uint32_t read(void* buffer, uint64_t offset, uint32_t size);
    void seek(uint64_t pos) { m_position = pos; }
    uint64_t tell() const { return m_position; }
    uint64_t size() const { return m_info.size; }
    bool eof() const { return m_position >= m_info.size; }

    const std::string& name() const { return m_info.path; }

private:
    // Fetch a chunk from the remote server via synchronous HTTP range request
    bool fetchChunk(uint64_t chunkStart, std::vector<uint8_t>& outData);
    
    // Get or fetch a chunk, updating LRU
    const std::vector<uint8_t>* getChunk(uint64_t chunkStart);
    
    // Evict oldest entries if cache exceeds MAX_CACHED_BYTES
    void evictIfNeeded(uint32_t neededBytes);

    RemoteFileInfo m_info;
    uint64_t m_position{0};

    // Cache: offset -> entry
    std::unordered_map<uint64_t, CacheEntry> m_cache;
    // LRU list: most recent at front
    std::list<uint64_t> m_lru;
    // Current cached bytes
    uint32_t m_cachedBytes{0};
};

using HttpRangeReaderPtr = std::shared_ptr<HttpRangeReader>;

#endif // __EMSCRIPTEN__
