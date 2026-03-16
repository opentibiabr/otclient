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

class BinaryTree
{
public:
    enum class Node
    {
        ESCAPE_CHAR = 0xFD,
        START = 0xFE,
        END = 0xFF
    };

    explicit BinaryTree(const FileStreamPtr& fin);

    void seek(uint32_t pos);
    void skip(uint32_t len);
    uint32_t tell() const { return m_pos; }
    uint32_t size() { unserialize(); return m_buffer.size(); }

    uint8_t getU8();
    uint16_t getU16();
    uint32_t getU32();
    uint64_t getU64();
    std::string getString(uint16_t len = 0);
    Point getPoint();

    BinaryTreeVec getChildren();
    bool canRead() { unserialize(); return m_pos < m_buffer.size(); }

private:
    void unserialize();
    void skipNodes();

    FileStreamPtr m_fin;
    std::vector<uint8_t> m_buffer;
    uint32_t m_pos;
    uint32_t m_startPos;
};

class OutputBinaryTree
{
public:
    OutputBinaryTree(FileStreamPtr fin);

    void addU8(uint8_t v);
    void addU16(uint16_t v);
    void addU32(uint32_t v);
    void addString(std::string_view v);
    void addPos(uint16_t x, uint16_t y, uint8_t z);
    void addPoint(const Point& point);

    void startNode(uint8_t node);
    void endNode() const;

private:
    FileStreamPtr m_fin;

protected:
    void write(const uint8_t* data, size_t size) const;
};
