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

#include "fontmanager.h"

#include "framework/core/resourcemanager.h"
#include "framework/otml/otmldocument.h"
#include "ttfloader.h"

FontManager g_fonts;

void FontManager::init()
{
    TTFLoader::init();
}

void FontManager::terminate()
{
    clearFonts();
    TTFLoader::terminate();
}

void FontManager::clearFonts() {
    m_fonts.clear();
    m_defaultFont = nullptr;
    m_defaultWidgetFont = nullptr;
}

bool FontManager::importFont(const std::string& file)
{
    return importFont(file, 12);
}

bool FontManager::importFont(const std::string& file, int fontSize)
{

    if ((file.find(".ttf") != std::string::npos || file.find(".otf") != std::string::npos) 
        && file.find(".otfont") == std::string::npos) {
        return !importTTF(file, fontSize).empty();
    }

    const auto& path = g_resources.guessFilePath(file, "otfont");
    try {
        const auto& doc = OTMLDocument::parse(path);
        const auto& fontNode = doc->at("Font");
        const auto& name = fontNode->valueAt("name");

        for (auto it = m_fonts.begin(); it != m_fonts.end(); ++it) {
            if ((*it)->getName() == name) {
                m_fonts.erase(it);
                break;
            }
        }

        const auto& font(std::make_shared<BitmapFont>(name));
        font->load(fontNode);
        m_fonts.emplace_back(font);

        if (!m_defaultFont || fontNode->valueAt<bool>("default", false))
            m_defaultFont = font;
        else if (!m_defaultWidgetFont || fontNode->valueAt<bool>("widget-default", false))
            m_defaultWidgetFont = font;

        return true;
    } catch (const stdext::exception& e) {
        g_logger.error("Unable to load font from file '{}': {}", path, e.what());
        return false;
    }
}

std::string FontManager::importTTF(const std::string& file, int fontSize, int strokeWidth, const Color& strokeColor)
{
    try {
        const auto& font = TTFLoader::load(file, fontSize, strokeWidth, strokeColor);
        
        if (!font) {
            g_logger.error("Failed to load TTF font: {}", file);
            return "";
        }

        const auto& name = font->getName();
        
        for (auto it = m_fonts.begin(); it != m_fonts.end(); ++it) {
            if ((*it)->getName() == name) {
                m_fonts.erase(it);
                break;
            }
        }
        
        m_fonts.emplace_back(font);
        
        if (!m_defaultFont)
            m_defaultFont = font;
        
        return name;
        
    } catch (const stdext::exception& e) {
        g_logger.error("Unable to load TTF font from file '{}': {}", file, e.what());
        return "";
    }
}

bool FontManager::fontExists(const std::string_view fontName)
{
    for (const auto& font : m_fonts) {
        if (font->getName() == fontName)
            return true;
    }
    return false;
}

BitmapFontPtr FontManager::getFont(const std::string_view fontName)
{
    // find font by name
    for (const auto& font : m_fonts) {
        if (font->getName() == fontName)
            return font;
    }

    // when not found, fallback to default font
    g_logger.error("font '{}' not found", fontName);
    return m_defaultFont;
}