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

    static std::vector<size_t> buildSrcPosToDrawPosMap(std::string_view src, std::string_view draw) {
        std::vector<size_t> map;
        map.assign(src.size() + 1, 0);

        size_t i = 0;
        size_t j = 0;
        while (i < src.size() || j < draw.size()) {
            if (i <= src.size())
                map[i] = j;

            if (i < src.size() && j < draw.size() && src[i] == draw[j]) {
                ++i;
                ++j;
                continue;
            }

            if (j < draw.size() && (draw[j] == '\n' || draw[j] == '-') && (i >= src.size() || src[i] != draw[j])) {
                ++j;
                continue;
            }

            if (i < src.size() && src[i] == ' ' && (j >= draw.size() || draw[j] != ' ')) {
                ++i;
                continue;
            }

            if (i < src.size() && j < draw.size()) {
                ++i;
                ++j;
                continue;
            }
            if (i < src.size()) {
                ++i;
                continue;
            }
            if (j < draw.size()) {
                ++j;
                continue;
            }
        }

        map[src.size()] = j;
        return map;
    }
}

void UIWidget::initText()
{
    m_font = g_fonts.getDefaultWidgetFont();
    m_ttfFontPath.clear();
    m_ttfBaseName.clear();
    m_ttfFontSize = 0;
    m_textAlign = Fw::AlignCenter;
    m_coordsBuffer = std::make_shared<CoordsBuffer>();
    m_textOverflowLength = 0;
    m_textOverflowCharacter = "...";
    m_baseTextColor = m_color;
}

void UIWidget::updateText()
{
    if ((hasEventListener(EVENT_TEXT_CLICK) || hasEventListener(EVENT_TEXT_HOVER)) && m_textEvents.empty())
        processCodeTags();

    if (isTextWrap() && m_rect.isValid()) {
        m_drawTextColors = m_textColors;
        if (m_textOverflowLength > 0 && m_text.length() > m_textOverflowLength)
            m_drawText = m_font->wrapText(m_text.substr(0, m_textOverflowLength - m_textOverflowCharacter.length()) + m_textOverflowCharacter, getWidth() - m_textOffset.x, WrapOptions{}, &m_drawTextColors);
        else
            m_drawText = m_font->wrapText(m_text, getWidth() - m_textOffset.x, WrapOptions{}, &m_drawTextColors);
    } else {
        if (m_textOverflowLength > 0 && m_text.length() > m_textOverflowLength)
            m_drawText = m_text.substr(0, m_textOverflowLength - m_textOverflowCharacter.length()) + m_textOverflowCharacter;
        else
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
        else if (node->tag() == "text-overflow-length")
            setTextOverflowLength(node->value<uint16_t>());
        else if (node->tag() == "text-overflow-character")
            setTextOverflowCharacter(node->value<std::string>());
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

        if (hasEventListener(EVENT_TEXT_CLICK) || hasEventListener(EVENT_TEXT_HOVER))
            cacheRectToWord();

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
    if (m_textUnderline && m_textUnderline->getVertexCount() > 0)
        g_drawPool.addTexturedCoordsBuffer(nullptr, m_textUnderline, m_color);
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
    m_textEvents.clear();

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
    m_textEvents.clear();

    static const std::regex expColor(R"(\{([^\}]+),[ ]*([^\}]+)\})");
    static const std::regex expEvent(R"(\[text-event\](.*?)\[/text-event\])");

    std::string _text{ coloredText.data() };
    std::string text;
    text.reserve(coloredText.size());

    Color baseColor = m_color;
    m_baseTextColor = baseColor;
    std::smatch res;
    text.clear();
    auto processTextEvents = [&](const std::string& fragment, size_t basePosition) -> std::string {
        if (fragment.find("[text-event]") == std::string::npos) {
            return fragment;
        }

        std::string tempText = fragment;
        std::vector<std::tuple<size_t, size_t, std::string, bool>> foundEvents;

        foundEvents.reserve(5);

        std::smatch eventMatch;
        size_t eventAdjustment = 0;

        while (std::regex_search(tempText, eventMatch, expEvent)) {
            std::string fullMatch = eventMatch[0].str();
            std::string eventContent = eventMatch[1].str();

            // detect special marker prefix (\x01) which indicates "no underline"
            bool noUnderline = false;
            if (!eventContent.empty() && eventContent[0] == '\x01') {
                noUnderline = true;
                eventContent = eventContent.substr(1);
            }

            size_t pos = eventMatch.position(0);
            size_t realPos = pos + basePosition - eventAdjustment;

            foundEvents.emplace_back(
                realPos,
                realPos + eventContent.length(),
                eventContent,
                noUnderline
            );

            tempText = eventMatch.suffix().str();
            eventAdjustment += fullMatch.length() - (eventContent.length() + (noUnderline ? 1u : 0u));
        }

        m_textEvents.reserve(m_textEvents.size() + foundEvents.size());

        for (const auto& [startPos, endPos, word, noUnderline] : foundEvents) {
            TextEvent event;
            event.word = word;
            event.startPos = startPos;
            event.endPos = endPos;
            event.noUnderline = noUnderline;
            m_textEvents.push_back(event);
        }
        std::string result = fragment;
        size_t pos = 0;

        while ((pos = result.find("[text-event]", pos)) != std::string::npos) {
            size_t endPos = result.find("[/text-event]", pos);
            if (endPos != std::string::npos) {
                size_t contentLength = endPos - pos - 12;
                std::string eventContent = result.substr(pos + 12, contentLength);
                if (!eventContent.empty() && eventContent[0] == '\x01')
                    eventContent = eventContent.substr(1);
                result.replace(pos, contentLength + 25, eventContent);
            } else {
                break;
            }
        }

        return result;
    };

    m_textColors.reserve(coloredText.size() / 20 + 5);

    while (std::regex_search(_text, res, expColor)) {
        std::string prefix = res.prefix().str();
        if (!prefix.empty()) {
            std::string processedPrefix = processTextEvents(prefix, text.size());
            m_textColors.emplace_back(text.size(), baseColor);
            text.append(processedPrefix);
        }
        auto color = Color(res[2].str());
        std::string colorContent = res[1].str();
        std::string processedColorContent = processTextEvents(colorContent, text.size());
        m_textColors.emplace_back(text.size(), color);
        text.append(processedColorContent);
        _text = res.suffix().str();
    }

    if (!_text.empty()) {
        std::string processedRemaining = processTextEvents(_text, text.size());
        m_textColors.emplace_back(text.size(), baseColor);
        text.append(processedRemaining);
    }

    if (hasProp(PropTextOnlyUpperCase))
        stdext::toupper(text);

    std::string oldText = m_text;
    m_text = std::move(text);
    updateText();

    if (!dontFireLuaCall) {
        onTextChange(m_text, oldText);
    }
}

std::string UIWidget::getFont() { return m_font->getName(); }

void UIWidget::setFont(const std::string_view fontName)
{
    m_font = g_fonts.getFont(fontName);
    m_ttfFontPath.clear();
    m_ttfBaseName.clear();
    m_ttfFontSize = 0;
    computeHtmlTextIntrinsicSize();
    updateText();
    onFontChange(fontName);
    scheduleHtmlTask(PropUpdateSize);
    refreshHtml(true);
}

void UIWidget::setTTFFont(const std::string_view fontName, int fontSize, int strokeWidth, const Color& strokeColor)
{
    const std::string fontPath(fontName);
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
        if (g_fonts.importTTF(fontPath, fontSize, strokeWidth, strokeColor).empty()) {
            g_logger.error("Failed to load TTF font: {}", fontName);
            return;
        }
    }
    
    m_strokeWidth = strokeWidth;
    m_strokeColor = strokeColor;
    m_ttfFontPath = fontPath;
    m_ttfBaseName = baseName;
    m_ttfFontSize = fontSize;

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
        // Prefer the originally requested TTF path/size.
        if (!m_ttfFontPath.empty() && m_ttfFontSize > 0) {
            setTTFFont(m_ttfFontPath, m_ttfFontSize, strokeWidth, strokeColor);
            return;
        }

        // Fallback: best-effort parse from the current font name.
        // NOTE: this remains potentially ambiguous which is why we prefer
        // m_ttfBaseName/m_ttfFontSize when available.
        std::string currentName = m_font->getName();
        int fontSize = 12;
        std::string baseName;

        // Strip optional stroke suffix: <base>_<size>_s<width>_<rgba>
        const size_t strokePos = currentName.find("_s");
        const std::string baseAndSize = (strokePos == std::string::npos) ? currentName : currentName.substr(0, strokePos);

        const size_t sizeSep = baseAndSize.find_last_of('_');
        if (sizeSep != std::string::npos && sizeSep + 1 < baseAndSize.size()) {
            const std::string sizeStr = baseAndSize.substr(sizeSep + 1);
            try {
                fontSize = std::stoi(sizeStr);
                baseName = baseAndSize.substr(0, sizeSep);
            } catch (...) {
                // keep defaults
            }
        }

        if (baseName.empty()) {
            m_strokeWidth = strokeWidth;
            m_strokeColor = strokeColor;
            return;
        }

        setTTFFont(baseName, fontSize, strokeWidth, strokeColor);
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
        // CSS white-space: normal collapses/trims spaces, but must preserve a single
        // boundary space between adjacent inline elements (e.g. text before/after <a>).
        // Record whether the raw text had leading/trailing whitespace before normalising.
        const bool hadLeadingSpace  = !m_text.empty() && static_cast<unsigned char>(m_text.front()) <= ' ';
        const bool hadTrailingSpace = !m_text.empty() && static_cast<unsigned char>(m_text.back())  <= ' ';
        normalizeWhiteSpace(m_text, true, false);
        if (!m_text.empty()) {
            // Re-add a single space at boundaries that touch an inline element sibling.
            if (hadLeadingSpace) {
                if (auto prevNode = m_htmlNode->getPrev(); prevNode && prevNode->getType() == NodeType::Element)
                    m_text.insert(m_text.begin(), ' ');
            }
            if (hadTrailingSpace) {
                if (auto nextNode = m_htmlNode->getNext(); nextNode && nextNode->getType() == NodeType::Element)
                    m_text.push_back(' ');
            }
        }
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
    if (m_textUnderline)
        m_textUnderline->clear();

    if (glypsCoords.empty() || m_textEvents.empty())
        return;

    if (!m_textUnderline)
        m_textUnderline = std::make_shared<CoordsBuffer>();

    const size_t glyphCount = glypsCoords.size();

    std::vector<TextEvent> drawEvents;
    drawEvents.reserve(m_textEvents.size());
    if (isTextWrap() && m_rect.isValid() && m_drawText != m_text) {
        const auto srcPosToDrawPos = buildSrcPosToDrawPosMap(m_text, m_drawText);

        for (const auto& ev : m_textEvents) {
            TextEvent mapped = ev;
            const size_t srcLen = m_text.size();
            const size_t start = std::min(mapped.startPos, srcLen);
            const size_t end = std::min(mapped.endPos, srcLen);
            if (start >= end) {
                mapped.startPos = 0;
                mapped.endPos = 0;
                drawEvents.push_back(std::move(mapped));
                continue;
            }

            const size_t dStart = srcPosToDrawPos[start];
            const size_t dEnd = srcPosToDrawPos[end];
            mapped.startPos = std::min(dStart, m_drawText.size());
            mapped.endPos = std::min(dEnd, m_drawText.size());
            drawEvents.push_back(std::move(mapped));
        }
    } else {
        drawEvents = m_textEvents;
    }

    for (const auto& textEvent : drawEvents) {
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
