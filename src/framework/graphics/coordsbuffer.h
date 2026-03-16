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

#include "vertexarray.h"

class CoordsBuffer
{
public:

    CoordsBuffer(const size_t size = 64) : m_vertexArray(size), m_textureCoordArray(size) {}

    void clear()
    {
        m_textureCoordArray.clear();
        m_vertexArray.clear();
    }

    void addTriangle(const Point& a, const Point& b, const Point& c)
    {
        m_vertexArray.addTriangle(a, b, c);
    }
    void addRect(const Rect& dest)
    {
        m_vertexArray.addRect(dest);
    }
    void addRect(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addRect(dest);
        if (src.isValid())
            m_textureCoordArray.addRect(src);
    }

    void addRect(const RectF& dest, const RectF& src)
    {
        m_vertexArray.addRect(dest);
        m_textureCoordArray.addRect(src);
    }

    void addQuad(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addQuad(dest);
        m_textureCoordArray.addQuad(src);
    }
    void addUpsideDownQuad(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addUpsideDownQuad(dest);
        m_textureCoordArray.addQuad(src);
    }

    void addHorizontallyFlippedQuad(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addQuad(dest);
        m_textureCoordArray.addHorizontallyFlippedQuad(src);
    }

    void addVerticallyFlippedQuad(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addQuad(dest);
        m_textureCoordArray.addVerticallyFlippedQuad(src);
    }

    void addUpsideDownRect(const Rect& dest, const Rect& src)
    {
        m_vertexArray.addUpsideDownRect(dest);
        m_textureCoordArray.addRect(src);
    }

    void addBoudingRect(const Rect& dest, int innerLineWidth);
    void addRepeatedRects(const Rect& dest, const Rect& src);

    void append(const CoordsBuffer* buffer)
    {
        m_vertexArray.append(&buffer->m_vertexArray);
        m_textureCoordArray.append(&buffer->m_textureCoordArray);
    }

    const float* getVertexArray() const { return m_vertexArray.vertices(); }
    const float* getTextureCoordArray() const { return m_textureCoordArray.vertices(); }
    int getVertexCount() const { return m_vertexArray.vertexCount(); }
    int getTextureCoordCount() const { return m_textureCoordArray.vertexCount(); }

    size_t size() const {
        return  std::max<size_t>(m_vertexArray.size(), m_textureCoordArray.size());
    }

private:
    VertexArray m_vertexArray;
    VertexArray m_textureCoordArray;
};
