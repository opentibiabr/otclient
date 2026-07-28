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

#include "httprangereader.h"

#ifdef __EMSCRIPTEN__

#include <emscripten/fetch.h>
#include <framework/core/logger.h>
#include <string>

HttpRangeReader::HttpRangeReader(const RemoteFileInfo& info)
    : m_info(info)
{
}

bool HttpRangeReader::fetchChunk(uint64_t chunkStart, std::vector<uint8_t>& outData)
{
    uint64_t chunkEnd = std::min(chunkStart + CHUNK_SIZE, m_info.size) - 1;
    uint32_t chunkLen = static_cast<uint32_t>(chunkEnd - chunkStart + 1);

    // Build Range header
    char rangeHeader[128];
    std::snprintf(rangeHeader, sizeof(rangeHeader), "bytes=%llu-%llu", 
                  static_cast<unsigned long long>(chunkStart),
                  static_cast<unsigned long long>(chunkEnd));

    emscripten_fetch_attr_t attr;
    emscripten_fetch_attr_init(&attr);
    
    // Synchronous fetch - this blocks the calling thread until complete
    // This is safe because we run in a pthread (PROXY_TO_PTHREAD), not main thread
    attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY | EMSCRIPTEN_FETCH_SYNCHRONOUS;
    
    // Set headers
    const char* headers[] = { "Range", rangeHeader, nullptr };
    attr.requestHeaders = headers;
    
    // Make the request
    emscripten_fetch_t* fetch = emscripten_fetch(&attr, m_info.url.c_str());
    
    if (!fetch) {
        g_logger.error("HttpRangeReader: fetch failed for {}", m_info.url);
        return false;
    }
    
    // Check status - 206 Partial Content is expected for range requests
    // 200 OK means the server ignored the Range header (e.g., nginx max_ranges 0)
    if (fetch->status != 206) {
        g_logger.error("HttpRangeReader: HTTP {} for {} (expected 206 Partial Content; server may have disabled byte ranges)", fetch->status, m_info.url);
        emscripten_fetch_close(fetch);
        return false;
    }
    
    // Verify response size matches requested chunk length
    if (fetch->numBytes != chunkLen) {
        g_logger.error("HttpRangeReader: received {} bytes, expected {} for chunk at offset {}", 
                       fetch->numBytes, chunkLen, chunkStart);
        emscripten_fetch_close(fetch);
        return false;
    }
    
    // Copy data
    outData.resize(fetch->numBytes);
    if (fetch->numBytes > 0) {
        std::memcpy(outData.data(), fetch->data, fetch->numBytes);
    }
    
    emscripten_fetch_close(fetch);
    return true;
}

const std::vector<uint8_t>* HttpRangeReader::getChunk(uint64_t chunkStart)
{
    // Check cache first
    auto it = m_cache.find(chunkStart);
    if (it != m_cache.end()) {
        // Move to front of LRU
        m_lru.erase(it->second.lruIter);
        m_lru.push_front(chunkStart);
        it->second.lruIter = m_lru.begin();
        return &it->second.data;
    }
    
    // Fetch from remote
    evictIfNeeded(CHUNK_SIZE);
    
    CacheEntry entry;
    entry.startOffset = chunkStart;
    
    if (!fetchChunk(chunkStart, entry.data)) {
        return nullptr;
    }
    
    // Add to cache
    m_lru.push_front(chunkStart);
    entry.lruIter = m_lru.begin();
    
    auto [insertedIt, _] = m_cache.emplace(chunkStart, std::move(entry));
    m_cachedBytes += static_cast<uint32_t>(insertedIt->second.data.size());
    
    return &insertedIt->second.data;
}

void HttpRangeReader::evictIfNeeded(uint32_t neededBytes)
{
    while (!m_lru.empty() && (m_cachedBytes + neededBytes) > MAX_CACHED_BYTES) {
        uint64_t oldestOffset = m_lru.back();
        auto it = m_cache.find(oldestOffset);
        if (it != m_cache.end()) {
            m_cachedBytes -= static_cast<uint32_t>(it->second.data.size());
            m_cache.erase(it);
        }
        m_lru.pop_back();
    }
}

uint32_t HttpRangeReader::read(void* buffer, uint64_t offset, uint32_t size)
{
    if (offset >= m_info.size) {
        return 0;
    }
    
    // Clamp read to file size
    uint64_t remaining = m_info.size - offset;
    uint32_t toRead = static_cast<uint32_t>(std::min(static_cast<uint64_t>(size), remaining));
    
    uint8_t* out = static_cast<uint8_t*>(buffer);
    uint32_t totalRead = 0;
    
    while (totalRead < toRead) {
        uint64_t chunkStart = (offset + totalRead) / CHUNK_SIZE * CHUNK_SIZE;
        uint32_t chunkOffset = static_cast<uint32_t>((offset + totalRead) - chunkStart);
        
        const std::vector<uint8_t>* chunk = getChunk(chunkStart);
        if (!chunk) {
            break;
        }
        
        // Guard against underflow: if chunk is smaller than expected offset, fail gracefully
        if (chunk->size() <= chunkOffset) {
            g_logger.error("HttpRangeReader: chunk at {} is too small ({} bytes, offset {})", 
                           chunkStart, chunk->size(), chunkOffset);
            break;
        }
        
        uint32_t availableInChunk = static_cast<uint32_t>(chunk->size()) - chunkOffset;
        uint32_t toCopy = std::min(toRead - totalRead, availableInChunk);
        
        // Guard against zero-copy loops (should not happen with size check above, but defensive)
        if (toCopy == 0) {
            break;
        }
        
        std::memcpy(out + totalRead, chunk->data() + chunkOffset, toCopy);
        totalRead += toCopy;
    }
    
    m_position = offset + totalRead;
    return totalRead;
}

#endif // __EMSCRIPTEN__
