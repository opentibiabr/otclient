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

#include "cachedtext.h"

#include "bitmapfont.h"
#include "coordsbuffer.h"
#include "drawpoolmanager.h"

CachedText::CachedText() : m_align(Fw::AlignCenter), m_coordsBuffer(std::make_shared<CoordsBuffer>()) {}

void CachedText::draw(const Rect& rect, const Color& color)
{
    if (!m_font)
        return;

    // Hack to fix font rendering in atlas
    if (m_font->getAtlasRegion() != m_atlasRegion) {
        m_atlasRegion = m_font->getAtlasRegion();
        m_textScreenCoords = {};
    }

    if (m_textScreenCoords != rect) {
        m_textScreenCoords = rect;
        m_font->fillTextCoords(m_coordsBuffer, m_text, m_textSize, m_align, rect, m_glyphsPositions);
    }

    g_drawPool.addTexturedCoordsBuffer(m_font->getTexture(), m_coordsBuffer, color);
}

void CachedText::update()
{
    if (m_font) {
        m_font->calculateGlyphsPositions(m_text, m_align, m_glyphsPositions, &m_textSize);
    }

    m_textScreenCoords = {};
}

void CachedText::wrapText(const int maxWidth)
{
    if (!m_font)
        return;

    m_text = m_font->wrapText(m_text, maxWidth);
    update();
}

void CachedText::setFont(const BitmapFontPtr& font)
{
    if (m_font == font)
        return;

    m_font = font;
    update();
}
void CachedText::setText(const std::string_view text)
{
    if (m_text == text)
        return;

    m_text = text;
    update();
}
void CachedText::setAlign(const Fw::AlignmentFlag align)
{
    if (m_align == align)
        return;

    m_align = align;
    update();
}