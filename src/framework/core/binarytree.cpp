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

#include "binarytree.h"
#include "filestream.h"

BinaryTree::BinaryTree(const FileStreamPtr& fin) :
    m_fin(fin), m_pos(0xFFFFFFFF)
{
    m_startPos = fin->tell();
}

void BinaryTree::skipNodes()
{
    while (true) {
        const uint8_t byte = m_fin->getU8();
        switch (byte) {
            case static_cast<uint8_t>(Node::START): skipNodes(); break;
            case static_cast<uint8_t>(Node::END): return;
            case static_cast<uint8_t>(Node::ESCAPE_CHAR): m_fin->getU8(); break;
            default: break;
        }
    }
}

void BinaryTree::unserialize()
{
    if (m_pos != 0xFFFFFFFF)
        return;
    m_pos = 0;

    m_fin->seek(m_startPos);
    while (true) {
        uint8_t byte = m_fin->getU8();
        switch (byte) {
            case static_cast<uint8_t>(Node::START): skipNodes(); break;
            case static_cast<uint8_t>(Node::END): return;
            case static_cast<uint8_t>(Node::ESCAPE_CHAR): m_buffer.push_back(m_fin->getU8()); break;
            default: m_buffer.push_back(byte); break;
        }
    }
}

BinaryTreeVec BinaryTree::getChildren()
{
    BinaryTreeVec children;
    m_fin->seek(m_startPos);
    while (true) {
        const uint8_t byte = m_fin->getU8();
        switch (byte) {
            case static_cast<uint8_t>(Node::START):
            {
                const auto& node = std::make_shared<BinaryTree>(m_fin);
                children.emplace_back(node);
                node->skipNodes();
                break;
            }

            case static_cast<uint8_t>(Node::END): return children;
            case static_cast<uint8_t>(Node::ESCAPE_CHAR): m_fin->getU8(); break;
            default: break;
        }
    }
}

void BinaryTree::seek(const uint32_t pos)
{
    unserialize();
    if (pos > m_buffer.size())
        throw Exception("BinaryTree: seek failed");
    m_pos = pos;
}

void BinaryTree::skip(const uint32_t len)
{
    unserialize();
    seek(tell() + len);
}

uint8_t BinaryTree::getU8()
{
    unserialize();
    if (m_pos + 1 > m_buffer.size())
        throw Exception("BinaryTree: getU8 failed");
    const uint8_t v = m_buffer[m_pos];
    m_pos += 1;
    return v;
}

uint16_t BinaryTree::getU16()
{
    unserialize();
    if (m_pos + 2 > m_buffer.size())
        throw Exception("BinaryTree: getU16 failed");
    const uint16_t v = stdext::readULE16(&m_buffer[m_pos]);
    m_pos += 2;
    return v;
}

uint32_t BinaryTree::getU32()
{
    unserialize();
    if (m_pos + 4 > m_buffer.size())
        throw Exception("BinaryTree: getU32 failed");
    const uint32_t v = stdext::readULE32(&m_buffer[m_pos]);
    m_pos += 4;
    return v;
}

uint64_t BinaryTree::getU64()
{
    unserialize();
    if (m_pos + 8 > m_buffer.size())
        throw Exception("BinaryTree: getU64 failed");
    const uint64_t v = stdext::readULE64(&m_buffer[m_pos]);
    m_pos += 8;
    return v;
}

std::string BinaryTree::getString(uint16_t len)
{
    unserialize();
    if (len == 0)
        len = getU16();

    if (m_pos + len > m_buffer.size())
        throw Exception("BinaryTree: getString failed: string length exceeded buffer size.");

    std::string ret((char*)&m_buffer[m_pos], len);
    m_pos += len;
    return ret;
}

Point BinaryTree::getPoint()
{
    Point ret;
    ret.x = getU8();
    ret.y = getU8();
    return ret;
}

OutputBinaryTree::OutputBinaryTree(FileStreamPtr fin) : m_fin(std::move(fin))
{
    startNode(0);
}

void OutputBinaryTree::addU8(const uint8_t v)
{
    write(&v, 1);
}

void OutputBinaryTree::addU16(const uint16_t v)
{
    uint8_t data[2];
    stdext::writeULE16(data, v);
    write(data, 2);
}

void OutputBinaryTree::addU32(const uint32_t v)
{
    uint8_t data[4];
    stdext::writeULE32(data, v);
    write(data, 4);
}

void OutputBinaryTree::addString(const std::string_view v)
{
    if (v.size() > 0xFFFF)
        throw Exception("too long string");

    addU16(v.length());
    write((const uint8_t*)v.data(), v.length());
}

void OutputBinaryTree::addPos(const uint16_t x, const uint16_t y, const uint8_t z)
{
    addU16(x);
    addU16(y);
    addU8(z);
}

void OutputBinaryTree::addPoint(const Point& point)
{
    addU8(point.x);
    addU8(point.y);
}

void OutputBinaryTree::startNode(const uint8_t node)
{
    m_fin->addU8(static_cast<uint8_t>(BinaryTree::Node::START));
    write(&node, 1);
}

void OutputBinaryTree::endNode() const
{
    m_fin->addU8(static_cast<uint8_t>(BinaryTree::Node::END));
}

void OutputBinaryTree::write(const uint8_t* data, const size_t size) const
{
    for (size_t i = 0; i < size; ++i) {
        if (const auto v = static_cast<BinaryTree::Node>(data[i]);
            v == BinaryTree::Node::START || v == BinaryTree::Node::END || v == BinaryTree::Node::ESCAPE_CHAR) {
            m_fin->addU8(static_cast<uint8_t>(BinaryTree::Node::ESCAPE_CHAR));
        }

        m_fin->addU8(data[i]);
    }
}