/*
 * Copyright (c) 2010-2025 OTClient <https://github.com/edubart/otclient>
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

#include "uiwidget.h"
#include "uitranslator.h"

#include <framework/graphics/drawpoolmanager.h>
#include <framework/graphics/fontmanager.h>
#include <framework/html/htmlnode.h>

#include "framework/otml/otmlnode.h"
#include <sstream>
#include <iomanip>
#include <regex>

namespace {
    WordBreakMode parseWordBreakMode(const std::string& v) {
        if (v == "break-all") return WordBreakMode::BreakAll;
        if (v == "keep-all")  return WordBreakMode::KeepAll;
        return WordBreakMode::Normal;
    }

    OverflowWrapMode parseOverflowWrapMode(const std::string& v) {
        if (v == "anywhere")   return OverflowWrapMode::Anywhere;
        if (v == "break-word") return OverflowWrapMode::BreakWord;
        return OverflowWrapMode::Normal;
    }

    HyphenationMode parseHyphenationMode(const std::string& v) {
        if (v == "none")   return HyphenationMode::None;
        if (v == "auto")   return HyphenationMode::Auto;
        return HyphenationMode::Manual;
    }

    void stripPreStartNewline(std::string& s) {
        if (s.size() >= 2 && s[0] == '\r' && s[1] == '\n') {
            s.erase(0, 2);
        } else if (!s.empty() && s[0] == '\n') {
            s.erase(0, 1);
        }
    }

    void normalizeWhiteSpace(std::string& s, bool collapseSpaces, bool keepNewlines) {
        std::string out;
        out.reserve(s.size());
        bool lastWasSpace = false;

        auto flush_space = [&](bool asSpace) {
            if (!collapseSpaces) {
                if (asSpace) out.push_back(' ');
                return;
            }
            if (asSpace) {
                if (!lastWasSpace) {
                    out.push_back(' ');
                    lastWasSpace = true;
                }
            } else {
                lastWasSpace = false;
            }
        };

        for (char c : s) {
            if (c == '\r' || c == '\t' || c == '\f' || c == '\v')
                c = ' ';

            if (c == '\n') {
                if (keepNewlines) {
                    lastWasSpace = false;
                    out.push_back('\n');
                } else {
                    flush_space(true);
                }
                continue;
            }

            if (c == ' ') {
                flush_space(true);
            } else {
                flush_space(false);
                out.push_back(c);
            }
        }

        auto l = out.find_first_not_of(keepNewlines ? " \t\r\f\v" : " \t\r\n\f\v");
        auto r = out.find_last_not_of(keepNewlines ? " \t\r\f\v" : " \t\r\n\f\v");
        if (l == std::string::npos) {
            s.clear();
        } else {
            s.assign(out, l, r - l + 1);
        }
    }
}

void UIWidget::initText()
{
    m_font = g_fonts.getDefaultWidgetFont();
    m_textAlign = Fw::AlignCenter;
    m_coordsBuffer = std::make_shared<CoordsBuffer>();
    m_textUnderline = std::make_shared<CoordsBuffer>();
}

void UIWidget::updateText()
{
    if (isTextWrap() && m_rect.isValid()) {
        m_drawTextColors = m_textColors;
        m_drawText = m_font->wrapText(m_text, getWidth() - m_textOffset.x, getTextWrapOptions());
    } else {
        m_drawText = m_text;
        m_drawTextColors = m_textColors;
    }

    if (m_font)
        m_font->calculateGlyphsPositions(m_drawText, m_textAlign, m_glyphsPositionsCache, &m_textSize);

    // update rect size
    if (!m_rect.isValid() || hasProp(PropTextHorizontalAutoResize) || hasProp(PropTextVerticalAutoResize)) {
        Size textBoxSize = m_textSize;
        textBoxSize += Size(m_padding.left + m_padding.right, m_padding.top + m_padding.bottom) + m_textOffset.toSize();
        textBoxSize *= std::max<float>(m_fontScale, 1.f);

        Size size = getSize();
        if (size.width() <= 0 || (hasProp(PropTextHorizontalAutoResize) && !isTextWrap()))
            size.setWidth(textBoxSize.width());
        if (size.height() <= 0 || hasProp(PropTextVerticalAutoResize))
            size.setHeight(textBoxSize.height());

        setSize(size);
    }

    m_textCachedScreenCoords = {};
    repaint();
}

void UIWidget::resizeToText()
{
    auto textSize = getTextSize();
    textSize += Size(m_padding.left + m_padding.right, m_padding.top + m_padding.bottom);
    textSize += m_textOffset.toSize();
    setSize(textSize * std::max<float>(m_fontScale, 1.f));
}

void UIWidget::parseTextStyle(const OTMLNodePtr& styleNode)
{

    int ttfFontSize = 12; //default
    int ttfStrokeWidth = 0;
    Color ttfStrokeColor = Color::black;	
    std::string ttfFontName;
    
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "ttf-font-size")
            ttfFontSize = node->value<int>();
        else if (node->tag() == "ttf-font")
            ttfFontName = node->value();
        else if (node->tag() == "ttf-stroke") {

            std::string strokeValue = node->value();
            std::istringstream iss(strokeValue);
            iss >> ttfStrokeWidth;
            std::string colorStr;
            if (iss >> colorStr) {
                ttfStrokeColor = Color(colorStr);
            }
        }
        else if (node->tag() == "ttf-stroke-width")
            ttfStrokeWidth = node->value<int>();
        else if (node->tag() == "ttf-stroke-color")
            ttfStrokeColor = Color(node->value());
        else if (node->tag() == "stroke") {

            std::string strokeValue = node->value();
            std::istringstream iss(strokeValue);
            iss >> ttfStrokeWidth;
            std::string colorStr;
            if (iss >> colorStr) {
                ttfStrokeColor = Color(colorStr);
            }
        }		
    }

    if (!ttfFontName.empty()) {
        g_logger.debug("parseTextStyle: setting TTF font '{}' size {} stroke {} rgba({},{},{},{})", 
                      ttfFontName, ttfFontSize, ttfStrokeWidth, 
                      ttfStrokeColor.r(), ttfStrokeColor.g(), ttfStrokeColor.b(), ttfStrokeColor.a());
        setTTFFont(ttfFontName, ttfFontSize, ttfStrokeWidth, ttfStrokeColor);
    }


    for (const auto& node : styleNode->children()) {
        const std::string tag = node->tag();

        if (tag == "text")
            setText(node->value());
        else if (tag == "text-align")
            setTextAlign(Fw::translateAlignment(node->value()));
        else if (tag == "text-offset")
            setTextOffset(node->value<Point>());
        else if (tag == "text-wrap")
            setTextWrap(node->value<bool>());
        else if (tag == "text-auto-resize")
            setTextAutoResize(node->value<bool>());
        else if (tag == "text-horizontal-auto-resize")
            setTextHorizontalAutoResize(node->value<bool>());
        else if (tag == "text-vertical-auto-resize")
            setTextVerticalAutoResize(node->value<bool>());
        else if (tag == "text-only-upper-case")
            setTextOnlyUpperCase(node->value<bool>());
        else if (node->tag() == "font") {
            if (ttfFontName.empty())
                setFont(node->value());
        }
        else if (tag == "font-scale")
            setFontScale(node->value<float>());
        else if (tag == "font-size")
            setFontScale(node->value<int>() / 10.f);
        else if (tag == "word-break")
            m_textWrapOptions.wordBreakMode = parseWordBreakMode(node->value());
        else if (tag == "overflow-wrap")
            m_textWrapOptions.overflowWrapMode = parseOverflowWrapMode(node->value());
        else if (tag == "hyphens")
            m_textWrapOptions.hyphenationMode = parseHyphenationMode(node->value());
        else if (tag == "text-lang")
            m_textWrapOptions.language = node->value();
    }
}

void UIWidget::drawText(const Rect& screenCoords)
{
    if (m_drawText.empty() || m_color.aF() == 0.f || !m_font)
        return;

    // Hack to fix font rendering in atlas
    if (m_font->getAtlasRegion() != m_atlasRegion) {
        m_atlasRegion = m_font->getAtlasRegion();
        updateText();
    }

    if (screenCoords != m_textCachedScreenCoords) {
        m_textCachedScreenCoords = screenCoords;

        auto textOffset = m_textOffset;
        textOffset.scale(m_fontScale);

        auto coords = Rect(screenCoords.topLeft().scale(m_fontScale), screenCoords.bottomRight().scale(m_fontScale));
        coords.translate(textOffset);

        if (m_drawTextColors.empty())
            m_font->fillTextCoords(m_coordsBuffer, m_drawText, m_textSize, m_textAlign, coords, m_glyphsPositionsCache);
        else
            m_font->fillTextColorCoords(m_colorCoordsBuffer, m_drawText, m_drawTextColors, m_textSize, m_textAlign, coords, m_glyphsPositionsCache);
    }

    g_drawPool.scale(m_fontScale);
    g_drawPool.setDrawOrder(m_textDrawOrder);
    if (m_drawTextColors.empty() || m_colorCoordsBuffer.empty()) {
        g_drawPool.addTexturedCoordsBuffer(m_font->getTexture(), m_coordsBuffer, m_color);
    } else {
        const auto& texture = m_font->getTexture();
        for (const auto& [color, coordsBuffer] : m_colorCoordsBuffer) {
            g_drawPool.addTexturedCoordsBuffer(texture, coordsBuffer, color);
        }
    }
    g_drawPool.resetDrawOrder();
    g_drawPool.scale(1.f); // reset scale
}

void UIWidget::onTextChange(const std::string_view text, const std::string_view oldText)
{
    callLuaField("onTextChange", text, oldText);
}

void UIWidget::onFontChange(const std::string_view font) { callLuaField("onFontChange", font); }

void UIWidget::setText(const std::string_view text, const bool dontFireLuaCall)
{
    std::string _text{ text.data() };
    if (hasProp(PropTextOnlyUpperCase))
        stdext::toupper(_text);

    if (m_text == _text && m_textColors.empty())
        return;

    m_textColors.clear();
    m_drawTextColors.clear();
    m_colorCoordsBuffer.clear();

    const std::string oldText = m_text;
    m_text = _text;

    if (isOnHtml() && !isTextEdit()) {
        applyWhiteSpace();
        scheduleHtmlTask(PropUpdateSize);
        refreshHtml(true);
    } else {
        updateText();
    }

    if (!dontFireLuaCall) {
        onTextChange(m_text, oldText);
    }
}

void UIWidget::setColoredText(const std::string_view coloredText, bool dontFireLuaCall)
{
    m_textColors.clear();
    m_drawTextColors.clear();
    m_colorCoordsBuffer.clear();
    m_coordsBuffer->clear();

    std::regex exp(R"(\{([^\}]+),[ ]*([^\}]+)\})");

    std::string _text{ coloredText.data() };

    Color baseColor = Color::white;
    std::smatch res;
    std::string text = "";
    while (std::regex_search(_text, res, exp)) {
        std::string prefix = res.prefix().str();
        if (prefix.size() > 0) {
            m_textColors.emplace_back(text.size(), baseColor);
            text = text + prefix;
        }
        auto color = Color(res[2].str());
        m_textColors.emplace_back(text.size(), color);
        text = text + res[1].str();
        _text = res.suffix();
    }

    if (_text.size() > 0) {
        m_textColors.emplace_back(text.size(), baseColor);
        text = text + _text;
    }

    if (hasProp(PropTextOnlyUpperCase))
        stdext::toupper(text);

    std::string oldText = m_text;
    m_text = text;
    updateText();

    if (!dontFireLuaCall) {
        onTextChange(text, oldText);
    }
}

std::string UIWidget::getFont() { return m_font->getName(); }

void UIWidget::setFont(const std::string_view fontName)
{
    m_font = g_fonts.getFont(fontName);
    computeHtmlTextIntrinsicSize();
    updateText();
    onFontChange(fontName);
    scheduleHtmlTask(PropUpdateSize);
    refreshHtml(true);
}

void UIWidget::setTTFFont(const std::string_view fontName, int fontSize, int strokeWidth, const Color& strokeColor)
{

    m_strokeWidth = strokeWidth;
    m_strokeColor = strokeColor;

    std::string baseName = std::string(fontName);
    
    size_t lastDot = baseName.find_last_of('.');
    if (lastDot != std::string::npos) {
        baseName = baseName.substr(0, lastDot);
    }
    

    size_t lastSlash = baseName.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        baseName = baseName.substr(lastSlash + 1);
    }
    

    std::string uniqueFontName = baseName + "_" + std::to_string(fontSize);
	
    if (strokeWidth > 0) {

        std::ostringstream colorStream;
        colorStream << std::hex << std::setfill('0') 
                    << std::setw(2) << (int)strokeColor.r()
                    << std::setw(2) << (int)strokeColor.g()
                    << std::setw(2) << (int)strokeColor.b()
                    << std::setw(2) << (int)strokeColor.a();
        uniqueFontName += "_s" + std::to_string(strokeWidth) + "_" + colorStream.str();
    }	
    
    if (!g_fonts.fontExists(uniqueFontName)) {
		
        if (g_fonts.importTTF(std::string(fontName), fontSize, strokeWidth, strokeColor).empty()) {
            g_logger.error("Failed to load TTF font: {}", fontName);
            return;
        }
    }
    
    m_font = g_fonts.getFont(uniqueFontName);
    computeHtmlTextIntrinsicSize();
    updateText();
    onFontChange(fontName);
    scheduleHtmlTask(PropUpdateSize);
    refreshHtml(true);
}

void UIWidget::setStroke(int strokeWidth, const Color& strokeColor)
{

    if (m_font) {
        std::string fontName = m_font->getName();
        

        size_t underscorePos = fontName.find('_');
        if (underscorePos != std::string::npos) {
            fontName = fontName.substr(0, underscorePos);
        }
        

        int fontSize = 12;
        std::string currentName = m_font->getName();
        size_t sizePos = currentName.find('_');
        if (sizePos != std::string::npos) {
            std::string sizeStr = currentName.substr(sizePos + 1);
            size_t nextUnderscore = sizeStr.find('_');
            if (nextUnderscore != std::string::npos) {
                sizeStr = sizeStr.substr(0, nextUnderscore);
            }
            try {
                fontSize = std::stoi(sizeStr);
            } catch (...) {
                fontSize = 12;
            }
        }
        

        setTTFFont(fontName, fontSize, strokeWidth, strokeColor);
    } else {

        m_strokeWidth = strokeWidth;
        m_strokeColor = strokeColor;
    }
}

void UIWidget::computeHtmlTextIntrinsicSize() {
    if (!isOnHtml())return;

    static std::vector<Point> glyphsPositions;
    m_font->calculateGlyphsPositions(m_text, Fw::AlignTopLeft, glyphsPositions, &m_realTextSize);
}

const WrapOptions& UIWidget::getTextWrapOptions() {
    if (m_parent && m_htmlNode && m_htmlNode->getType() == NodeType::Text)
        return m_parent->m_textWrapOptions;
    return m_textWrapOptions;
}

void UIWidget::applyWhiteSpace() {
    auto whiteSpace = m_htmlNode->getStyle("white-space");
    if (whiteSpace.empty())
        whiteSpace = "normal";

    setProp(PropTextHorizontalAutoResize, false);
    setProp(PropTextVerticalAutoResize, false);

    if (whiteSpace == "normal") {
        setProp(PropTextWrap, true);
        normalizeWhiteSpace(m_text, true, false);
    } else if (whiteSpace == "nowrap") {
        setProp(PropTextWrap, false);
        setProp(PropTextHorizontalAutoResize, true);
        setProp(PropTextVerticalAutoResize, true);
        normalizeWhiteSpace(m_text, true, false);
    } else if (whiteSpace == "pre") {
        stripPreStartNewline(m_text);
        setProp(PropTextWrap, false);
        setProp(PropTextHorizontalAutoResize, true);
        setProp(PropTextVerticalAutoResize, true);
    } else if (whiteSpace == "pre-wrap") {
        stripPreStartNewline(m_text);
        setProp(PropTextWrap, true);
    } else if (whiteSpace == "pre-line") {
        stripPreStartNewline(m_text);
        setProp(PropTextWrap, true);
        normalizeWhiteSpace(m_text, true, true);
    } else {
        setProp(PropTextWrap, true);
        normalizeWhiteSpace(m_text, true, false);
    }
    computeHtmlTextIntrinsicSize();
}

void UIWidget::processCodeTags() {
    std::string tempText = m_text;
    m_text.clear();
    m_textEvents.clear();

    std::regex regex(R"(\[text-event\](.*?)\[/text-event\])");
    std::smatch match;

    while (std::regex_search(tempText, match, regex)) {
        m_text += tempText.substr(0, match.position());

        std::string word = match[1];
        size_t startPos = m_text.length();
        size_t endPos = startPos + word.length();

        // detect special marker prefix (\x01) which indicates "no underline"
        bool noUnderline = false;
        if (!word.empty() && word[0] == '\x01') {
            noUnderline = true;
            word = word.substr(1);
        }

        m_textEvents.push_back({ word, startPos, endPos, noUnderline });
        m_text += word;
        tempText = tempText.substr(match.position() + match.length());
    }

    m_text += tempText;
}

static void buildTextUnderline(Rect& wordRect, CoordsBuffer& textUnderlineCoords) {
    int currentX = wordRect.x();
    int y = wordRect.y() + wordRect.height() - 2;
    while (currentX < wordRect.x() + wordRect.width()) {
        textUnderlineCoords.addRect(Rect(currentX, y, 2, 2));
        currentX += 4;
    }

    if (currentX < wordRect.width()) {
        textUnderlineCoords.addRect(Rect(currentX, y, std::min<int>(2, wordRect.width() - currentX), 2));
    }
}

void UIWidget::updateRectToWord(const std::vector<Rect>& glypsCoords)
{
    m_rectToWord.clear();
    m_textUnderline->clear();

    if (glypsCoords.empty() || m_textEvents.empty())
        return;

    const size_t glyphCount = glypsCoords.size();

    for (const auto& textEvent : m_textEvents) {
        const size_t start = std::min<int>(textEvent.startPos, glyphCount);
        const size_t end = std::min<int>(textEvent.endPos, glyphCount);
        if (start >= end)
            continue;

        Rect wordRect;
        bool inNewLine = false;

        for (size_t i = start; i < end; ++i) {
            if (m_drawText[i] == '\n') {
                if (wordRect.isValid()) {
                    m_rectToWord.push_back({ wordRect, textEvent.word });
                    if (!textEvent.noUnderline)
                        buildTextUnderline(wordRect, *m_textUnderline);
                }
                inNewLine = true;
                continue;
            }

            if (i == start || inNewLine) {
                wordRect = glypsCoords[i];
                inNewLine = false;
            } else
                wordRect.expand(0, glypsCoords[i].width(), 0, 0);
        }

        if (wordRect.isValid()) {
            m_rectToWord.push_back({ wordRect, textEvent.word });
            if (!textEvent.noUnderline)
                buildTextUnderline(wordRect, *m_textUnderline);
        }
    }
}
