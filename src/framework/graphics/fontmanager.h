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

#include "bitmapfont.h"

 //@bindsingleton g_fonts
class FontManager
{
public:
    void init(); 
    void terminate();
    void clearFonts();

    bool importFont(const std::string& file);
    bool importFont(const std::string& file, int fontSize);
    std::string importTTF(const std::string& file, int fontSize = 12, int strokeWidth = 0, const Color& strokeColor = Color::black);

    bool fontExists(std::string_view fontName);
    BitmapFontPtr getFont(std::string_view fontName);

    BitmapFontPtr getDefaultFont() const { return m_defaultFont; }
    BitmapFontPtr getDefaultWidgetFont() const { return m_defaultWidgetFont; }

    void setDefaultFont(const BitmapFontPtr& font) { m_defaultFont = font; }
    void setDefaultWidgetFont(const BitmapFontPtr& font) { m_defaultWidgetFont = font; }

private:
    std::vector<BitmapFontPtr> m_fonts;
    BitmapFontPtr m_defaultFont;
    BitmapFontPtr m_defaultWidgetFont;
};

extern FontManager g_fonts;
