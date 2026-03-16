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
#include <framework/luaengine/luaobject.h>
#include <framework/util/point.h>

struct PHYSFS_File;

// @bindclass
class FileStream : public std::enable_shared_from_this<FileStream>
{
public:
    FileStream(std::string name, PHYSFS_File* fileHandle, bool writeable);
    FileStream(std::string name, std::string_view buffer);
    ~FileStream();

    void cache(bool useEnc = false);
    void close();
    void flush();
    void write(const void* buffer, uint32_t count);
    int read(void* buffer, uint32_t size, uint32_t nmemb = 1);
    void seek(uint32_t pos);
    void skip(uint32_t len);
    uint32_t size() const;
    uint32_t tell() const;
    bool eof() const;
    std::string name() { return m_name; }

    uint8_t getU8();
    uint16_t getU16();
    uint32_t getU32();
    uint64_t getU64();
    int8_t get8();
    int16_t get16();
    int32_t get32();
    int64_t get64();
    std::string getString();
    BinaryTreePtr getBinaryTree();

    void startNode(uint8_t n);
    void endNode();
    void addU8(uint8_t v);
    void addU16(uint16_t v);
    void addU32(uint32_t v);
    void addU64(uint64_t v);
    void add8(int8_t v);
    void add16(int16_t v);
    void add32(int32_t v);
    void add64(int64_t v);
    void addString(std::string_view v);
    void addPos(const uint16_t x, const uint16_t y, const uint8_t z) { addU16(x); addU16(y); addU8(z); }
    void addPoint(const Point& p) { addU8(p.x); addU8(p.y); }

    std::vector<uint8_t> m_data;

private:
    void throwError(std::string_view message, bool physfsError = false) const;

    std::string m_name;
    PHYSFS_File* m_fileHandle;
    uint32_t m_pos;
    bool m_writeable;
    bool m_caching;
};
