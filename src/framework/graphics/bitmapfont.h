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
#include "bitmapfontwrapoptions.h"

#include <framework/otml/declarations.h>

#include <utility>

class BitmapFont
{
	
    friend class TTFLoader;

	
public:
    BitmapFont(const std::string_view name) : m_name(name) {}

    /// Load font from otml node
    void load(const OTMLNodePtr& fontNode);

    /// Simple text render starting at startPos
    void drawText(std::string_view text, const Point& startPos, const Color& color = Color::white);

    /// Advanced text render delimited by a screen region and alignment
    void drawText(std::string_view text, const Rect& screenCoords, const Color& color = Color::white, Fw::AlignmentFlag align = Fw::AlignTopLeft);

    std::vector<std::pair<Rect, Rect>> getDrawTextCoords(std::string_view text,
                                                         const Size& textBoxSize,
                                                         Fw::AlignmentFlag align,
                                                         const Rect& screenCoords,
                                                         const std::vector<Point>& glyphsPositions) const noexcept;

    void fillTextCoords(const CoordsBufferPtr& coords, std::string_view text,
                        const Size& textBoxSize, Fw::AlignmentFlag align,
                        const Rect& screenCoords, const std::vector<Point>& glyphsPositions) const noexcept;

    void fillTextColorCoords(std::vector<std::pair<Color, CoordsBufferPtr>>& colorCoords, std::string_view text,
                             std::vector<std::pair<int, Color>> textColors,
                             const Size& textBoxSize, Fw::AlignmentFlag align,
                             const Rect& screenCoords, const std::vector<Point>& glyphsPositions) const noexcept;

    /// Calculate glyphs positions to use on render, also calculates textBoxSize if wanted
    void calculateGlyphsPositions(std::string_view text,
                                  Fw::AlignmentFlag align,
                                  std::vector<Point>& glyphsPositions,
                                  Size* textBoxSize = nullptr) const noexcept;

    /// Simulate render and calculate text size
    Size calculateTextRectSize(std::string_view text);

    std::string wrapText(std::string_view text, int maxWidth, const WrapOptions& options = WrapOptions{}, std::vector<std::pair<int, Color>>* colors = nullptr);

    const std::string& getName() const noexcept { return m_name; }
    int getGlyphHeight() const noexcept { return m_glyphHeight; }
    const Rect* getGlyphsTextureCoords() const noexcept { return m_glyphsTextureCoords; }
    const Size* getGlyphsSize() const noexcept { return m_glyphsSize; }
    const Point* getGlyphsOffset() const noexcept { return m_glyphsOffset; }
    const int* getGlyphsAdvance() const noexcept { return m_glyphsAdvance; }
    const TexturePtr& getTexture() const noexcept { return m_texture; }
    int getYOffset() const noexcept { return m_yOffset; }
    Size getGlyphSpacing() const noexcept { return m_glyphSpacing; }
    const AtlasRegion* getAtlasRegion() const noexcept;

private:
    /// Calculates each font character by inspecting font bitmap
    void calculateGlyphsWidthsAutomatically(const ImagePtr& image, const Size& glyphSize);
    bool clipAndTranslateGlyph(Rect& glyphScreenCoords, Rect& glyphTextureCoords, const Rect& screenCoords) const noexcept;
    void updateColors(std::vector<std::pair<int, Color>>* colors, int pos, int newTextLen) noexcept;

    std::string m_name;
    int m_glyphHeight{ 0 };
    int m_firstGlyph{ 0 };
    int m_yOffset{ 0 };
    Size m_glyphSpacing;
    TexturePtr m_texture;
    Rect m_glyphsTextureCoords[256];
    Size m_glyphsSize[256];
    Point m_glyphsOffset[256];      // Offset de cada glyph (bearing X, Y ajustado)
    int m_glyphsAdvance[256]{ };    // Avanço horizontal de cada glyph
};
