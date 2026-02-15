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

#include "uitextedit.h"

#include "uitranslator.h"
#include "framework/core/clock.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/fontmanager.h"
#include "framework/graphics/textureatlas.h"
#include "framework/input/mouse.h"
#include "framework/otml/otmlnode.h"

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif
#include <framework/platform/platformwindow.h>
#ifdef ANDROID
#include <framework/platform/androidmanager.h>
#endif

UITextEdit::UITextEdit()
{
    setProp(PropCursorInRange, true);
    setProp(PropCursorVisible, true);
    setProp(PropEditable, true);
    setProp(PropChangeCursorImage, true);
    setProp(PropUpdatesEnabled, true);
    setProp(PropAutoScroll, true);
    setProp(PropSelectable, true);
    setProp(PropGlyphsMustRecache, true);

    m_textAlign = Fw::AlignTopLeft;
    m_placeholder = "";
    m_placeholderColor = Color::gray;
    m_placeholderFont = g_fonts.getDefaultFont();
    m_placeholderAlign = Fw::AlignLeftCenter;
    // Always use 1.0 to prevent distortion with TTF fonts
    m_fontScale = 1.0f;	
    blinkCursor();
}

void UITextEdit::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    drawBackground(m_rect);
    drawBorder(m_rect);
    drawImage(m_rect);
    drawIcon(m_rect);

    const auto& texture = m_font->getTexture();
    if (!texture)
        return;

    const bool glyphsMustRecache = getProp(PropGlyphsMustRecache);
    if (glyphsMustRecache)
        setProp(PropGlyphsMustRecache, false);

    if (m_font->getAtlasRegion() != m_atlasRegion) {
        m_atlasRegion = m_font->getAtlasRegion();
        update(false, true);
    }

    const int textLength = std::min<int>(m_glyphsCoords.size(), static_cast<int>(m_displayedText.length()));
    if (textLength == 0) {
        if (m_placeholderColor != Color::alpha && !m_placeholder.empty())
            m_placeholderFont->drawText(m_placeholder, m_drawArea, m_placeholderColor, m_placeholderAlign);
    }
	
    // This ensures TTF font offsets are always correctly applied
    if (m_color != Color::alpha) {
        for (int i = 0; i < textLength; ++i) {
            const auto& [dest, src] = m_glyphsCoords[i];
            if (dest.isValid() && src.isValid()) {
                // Apply text colors if available
                Color glyphColor = m_color;
                if (!m_drawTextColors.empty()) {
                    // Find the color for this glyph
                    for (size_t colorIdx = 0; colorIdx < m_drawTextColors.size(); ++colorIdx) {
                        if (i >= m_drawTextColors[colorIdx].first) {
                            if (colorIdx + 1 < m_drawTextColors.size()) {
                                if (i < m_drawTextColors[colorIdx + 1].first) {
                                    glyphColor = m_drawTextColors[colorIdx].second;
                                    break;
                                }
                            } else {
                                glyphColor = m_drawTextColors[colorIdx].second;
                                break;
                            }
                        }
                    }
                }
                g_drawPool.addTexturedRect(dest, texture, src, glyphColor);
            }
        }
    }

    if (m_textUnderline && m_textUnderline->getVertexCount() > 0)
        g_drawPool.addTexturedCoordsBuffer(nullptr, m_textUnderline, m_color);

    if (hasSelection()) {
        const int textLengthSel = std::min<int>(m_glyphsCoords.size(), static_cast<int>(m_displayedText.length()));

        int a = std::clamp(m_selectionStart, 0, static_cast<int>(m_text.length()));
        int b = std::clamp(m_selectionEnd, 0, static_cast<int>(m_text.length()));
        if (a > b) std::swap(a, b);

        const int visStart = m_srcToVis.empty() ? a : std::clamp(m_srcToVis[a], 0, textLengthSel);
        const int visEnd = m_srcToVis.empty() ? b : std::clamp(m_srcToVis[b], 0, textLengthSel);

        if (glyphsMustRecache) {
            m_glyphsSelectRectCache.clear();
            m_glyphsSelectBgRectCache.clear();

            const Point textScreenOffset = m_drawArea.topLeft() - m_textVirtualOffset;
            const int lineHeight = m_font->getGlyphHeight();
            const Size* glyphsSize = m_font->getGlyphsSize();
            const Point* glyphsOffset = m_font->getGlyphsOffset();

            for (int i = visStart; i < visEnd; ++i) {
                // Determine source for text drawing
                const auto& dest = m_glyphsCoords[i].first;
                const auto& src = m_glyphsCoords[i].second;
                if (dest.isValid()) m_glyphsSelectRectCache.emplace_back(dest, src);

                if (i >= static_cast<int>(m_glyphsPositionsCache.size())) continue;
                uint8_t glyph = static_cast<uint8_t>(m_displayedText[i]);
                Point baselinePos = textScreenOffset + m_glyphsPositionsCache[i];
                Point pos(baselinePos.x + glyphsOffset[glyph].x, baselinePos.y);
                int width = 0;

                if (i + 1 < static_cast<int>(m_glyphsPositionsCache.size()) && i + 1 < static_cast<int>(m_displayedText.length())) {
                    uint8_t nextGlyph = static_cast<uint8_t>(m_displayedText[i + 1]);
                    Point nextBaselinePos = textScreenOffset + m_glyphsPositionsCache[i + 1];
                    Point nextPos(nextBaselinePos.x + glyphsOffset[nextGlyph].x, nextBaselinePos.y);
                    if (nextPos.y == pos.y) {
                        width = nextPos.x - pos.x;
                    }
                }

                if (width == 0) {
                    if (glyph >= 32) {
                        int advanceGuess = glyphsOffset[glyph].x + glyphsSize[glyph].width();
                        if (dest.isValid()) {
                            advanceGuess = std::max(advanceGuess, dest.right() - pos.x);
                        }
                        if (glyph == ' ' && width == 0) advanceGuess = std::max(advanceGuess, lineHeight / 4);
                        width = advanceGuess;
                    } else if (glyph == '\n') {
                        width = lineHeight / 4;
                    }
                }

                if (width > 0)
                    m_glyphsSelectBgRectCache.emplace_back(Rect(pos.x, pos.y, width, lineHeight));
            }
        }

        for (const auto& rect : m_glyphsSelectBgRectCache)
            g_drawPool.addFilledRect(rect, m_selectionBackgroundColor);

        for (const auto& it : m_glyphsSelectRectCache)
            g_drawPool.addTexturedRect(it.first, texture, it.second, m_selectionColor);
    }

    if (isExplicitlyEnabled() && getProp(PropCursorVisible) && getProp(PropCursorInRange) && isActive() && m_cursorPos >= 0) {
        const int cursorVis = m_srcToVis.empty()
            ? std::clamp(m_cursorPos, 0, textLength)
            : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, static_cast<int>(m_text.length()))], 0, textLength);

        constexpr int delay = 333;
        const ticks_t elapsed = g_clock.millis() - m_cursorTicks;
        if (elapsed <= delay) {
            Rect cursorRect;

            struct LineInfo
            {
                int visStart = 0;
                int visEnd = 0;
                int top = std::numeric_limits<int>::min();
                int bottom = std::numeric_limits<int>::min();
                int left = std::numeric_limits<int>::max();
                int right = std::numeric_limits<int>::min();
                bool hasGlyphs = false;

                LineInfo() = default;
                LineInfo(int s, int e)
                    : visStart(s), visEnd(e) {}
            };

            std::vector<LineInfo> lines;
            {
                int start = 0;
                const int n = static_cast<int>(m_displayedText.size());
                for (int i = 0; i <= n; ++i) {
                    const bool br = (i == n) || (m_displayedText[i] == '\n');
                    if (!br) continue;
                    lines.emplace_back(start, i);
                    start = i + 1;
                }
                if (lines.empty()) lines.emplace_back(0, n);
            }

            const int visLen = std::min<int>(m_glyphsCoords.size(), static_cast<int>(m_displayedText.length()));
            const Point* glyphsOffset = m_font->getGlyphsOffset();
            const int lineH = m_font->getGlyphHeight();

            for (auto& li : lines) {
                for (int v = li.visStart; v < li.visEnd && v < visLen; ++v) {
                    const Rect& r = m_glyphsCoords[v].first;
                    if (!r.isValid()) continue;
                    li.hasGlyphs = true;

                    uint8_t g = static_cast<uint8_t>(m_displayedText[v]);
                    int calculatedTop = r.top() - glyphsOffset[g].y;

                    li.top = (li.top == std::numeric_limits<int>::min()) ? calculatedTop : std::min(li.top, calculatedTop);
                    li.bottom = (li.bottom == std::numeric_limits<int>::min()) ? (calculatedTop + lineH) : std::max(li.bottom, calculatedTop + lineH);
                    li.left = std::min(li.left, r.left());
                    li.right = std::max(li.right, r.right());
                }
            }

            const int lineDy = m_font->getGlyphSpacing().height();
            int yCursor = m_drawArea.top();
            for (size_t i = 0; i < lines.size(); ++i) {
                auto& li = lines[i];
                if (li.hasGlyphs) {
                    if (li.top == std::numeric_limits<int>::min() || li.bottom == std::numeric_limits<int>::min()) {
                        li.top = yCursor;
                        li.bottom = li.top + lineH;
                    }
                    yCursor = li.bottom;
                } else {
                    if (i > 0) {
                        const auto& prev = lines[i - 1];
                        const int base = (prev.top != std::numeric_limits<int>::min()) ? prev.bottom : yCursor;
                        li.top = base + lineDy;
                        li.bottom = li.top + lineH;
                    } else {
                        int nextTop = std::numeric_limits<int>::min();
                        for (size_t k = i + 1; k < lines.size(); ++k) {
                            if (lines[k].hasGlyphs) { nextTop = lines[k].top; break; }
                        }
                        if (nextTop != std::numeric_limits<int>::min()) {
                            li.bottom = nextTop - lineDy;
                            li.top = li.bottom - lineH;
                        } else {
                            li.top = yCursor;
                            li.bottom = li.top + lineH;
                        }
                    }
                }
                if (li.left == std::numeric_limits<int>::max())
                    li.left = m_rect.left() + m_padding.left;
                if (li.right == std::numeric_limits<int>::min())
                    li.right = li.left;
            }

            int lineIdx = (int)lines.size() - 1;
            for (int i = 0; i < (int)lines.size(); ++i) {
                const auto& li = lines[i];
                if (cursorVis >= li.visStart && cursorVis <= li.visEnd) { lineIdx = i; break; }
            }
            const auto& L = lines[lineIdx];

            int caretX = L.left;
            if (L.hasGlyphs) {
                if (cursorVis < visLen && m_glyphsCoords[cursorVis].first.isValid()) {
                    caretX = m_glyphsCoords[cursorVis].first.left();
                } else if (cursorVis > 0 && cursorVis - 1 < visLen && m_glyphsCoords[cursorVis - 1].first.isValid()) {
                    caretX = m_glyphsCoords[cursorVis - 1].first.right();
                } else {
                    caretX = L.left;
                }
            }

            cursorRect = Rect(caretX, L.top, 1, m_font->getGlyphHeight());

            const bool useSelectionColor = hasSelection() && m_cursorPos >= m_selectionStart && m_cursorPos <= m_selectionEnd;
            const auto& color = useSelectionColor ? m_selectionColor : m_color;
            g_drawPool.addFilledRect(cursorRect, color);
        } else if (elapsed >= 2 * delay) {
            m_cursorTicks = g_clock.millis();
        }
    }
}

void UITextEdit::update(const bool focusCursor, bool disableAreaUpdate)
{
    if (!getProp(PropUpdatesEnabled))
        return;
    if (m_rect.isEmpty())
        return;

    recacheGlyphs();

    m_drawText = getDisplayedText();
    if ((hasEventListener(EVENT_TEXT_CLICK) || hasEventListener(EVENT_TEXT_HOVER)) && m_textEvents.empty())
        processCodeTags();
    const int textLength = static_cast<int>(m_drawText.length());

    Size textBoxSize;
    m_font->calculateGlyphsPositions(m_drawText, m_textAlign, m_glyphsPositionsCache, &textBoxSize);
    const Rect* glyphsTextureCoords = m_font->getGlyphsTextureCoords();
    const Point* glyphsOffset = m_font->getGlyphsOffset();  // Get glyph offsets for TTF fonts	
    const Size* glyphsSize = m_font->getGlyphsSize();

    if (!m_rect.isValid() || hasProp(PropTextHorizontalAutoResize) || hasProp(PropTextVerticalAutoResize)) {
        textBoxSize += Size(m_padding.left + m_padding.right, m_padding.top + m_padding.bottom) + m_textOffset.toSize();
        Size size = getSize();
        if (size.width() <= 0 || (hasProp(PropTextHorizontalAutoResize) && !isTextWrap()))
            size.setWidth(textBoxSize.width());
        if (size.height() <= 0 || hasProp(PropTextVerticalAutoResize))
            size.setHeight(textBoxSize.height());
        setSize(size);
    }

    if (textLength > static_cast<int>(m_glyphsCoords.size()))
        m_glyphsCoords.resize(textLength);

    const Point oldTextAreaOffset = m_textVirtualOffset;

    if (textBoxSize.width() <= getPaddingRect().width())
        m_textVirtualOffset.x = 0;
    if (textBoxSize.height() <= getPaddingRect().height())
        m_textVirtualOffset.y = 0;

    setProp(PropCursorInRange, false);
    if (focusCursor && getProp(PropAutoScroll)) {
        const int visLen = std::min<int>(static_cast<int>(m_glyphsPositionsCache.size()), static_cast<int>(m_drawText.size()));
        const int srcLen = static_cast<int>(m_text.length());
        const int cursorVis = m_srcToVis.empty()
            ? std::clamp(m_cursorPos, 0, visLen)
            : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);

        struct LineInfo { int visStart, visEnd; int top, bottom, left, right; bool hasGlyphs; };
        std::vector<LineInfo> lines;
        {
            int start = 0;
            const int n = static_cast<int>(m_drawText.size());
            for (int i = 0; i <= n; ++i) {
                const bool br = (i == n) || (m_drawText[i] == '\n');
                if (!br) continue;
                lines.push_back({ start, i, std::numeric_limits<int>::min(), std::numeric_limits<int>::min(),
                                  std::numeric_limits<int>::max(), std::numeric_limits<int>::min(), false });
                start = i + 1;
            }
            if (lines.empty()) lines.push_back({ 0, n, 0, 0, 0, 0, false });
        }

        const int lineH = m_font->getGlyphHeight();
        const int lineDy = m_font->getGlyphSpacing().height();

        for (auto& li : lines) {
            for (int v = li.visStart; v < li.visEnd && v < visLen; ++v) {
                uint8_t g = static_cast<uint8_t>(m_drawText[v]);
                if (g < 32) continue;
                const Point& p = m_glyphsPositionsCache[v];
                const Rect r(p, glyphsSize[g]);
                li.hasGlyphs = true;
                li.top = (li.top == std::numeric_limits<int>::min()) ? r.top() : std::min(li.top, r.top());
                li.bottom = (li.bottom == std::numeric_limits<int>::min()) ? r.bottom() : std::max(li.bottom, r.bottom());
                li.left = std::min(li.left, r.left());
                li.right = std::max(li.right, r.right());
            }
        }

        int yCursor = 0;
        for (size_t i = 0; i < lines.size(); ++i) {
            auto& li = lines[i];
            if (li.hasGlyphs) {
                if (li.top == std::numeric_limits<int>::min()) li.top = yCursor;
                if (li.bottom == std::numeric_limits<int>::min()) li.bottom = li.top + lineH;
                yCursor = li.bottom;
            } else {
                if (i > 0) {
                    const auto& prev = lines[i - 1];
                    const int base = (prev.top != std::numeric_limits<int>::min()) ? prev.bottom : yCursor;
                    li.top = base + lineDy;
                    li.bottom = li.top + lineH;
                } else {
                    li.top = 0;
                    li.bottom = li.top + lineH;
                }
                if (li.left == std::numeric_limits<int>::max()) li.left = 0;
                if (li.right == std::numeric_limits<int>::min()) li.right = li.left;
            }
        }

        int lineIdx = (int)lines.size() - 1;
        for (int i = 0; i < (int)lines.size(); ++i) {
            if (cursorVis >= lines[i].visStart && cursorVis <= lines[i].visEnd) { lineIdx = i; break; }
        }
        const auto& L = lines[lineIdx];

        int caretX = L.left;
        if (L.hasGlyphs) {
            if (cursorVis < visLen) {
                uint8_t g = static_cast<uint8_t>(m_drawText[std::max(0, cursorVis)]);
                if (g >= 32) caretX = m_glyphsPositionsCache[cursorVis].x;
                else if (cursorVis > 0) {
                    int pv = cursorVis - 1;
                    while (pv >= L.visStart && static_cast<uint8_t>(m_drawText[pv]) < 32) --pv;
                    if (pv >= L.visStart) caretX = m_glyphsPositionsCache[pv].x + glyphsSize[static_cast<uint8_t>(m_drawText[pv])].width();
                    else caretX = L.left;
                } else caretX = L.left;
            } else if (visLen > 0) {
                int pv = visLen - 1;
                while (pv >= L.visStart && static_cast<uint8_t>(m_drawText[pv]) < 32) --pv;
                caretX = (pv >= L.visStart)
                    ? m_glyphsPositionsCache[pv].x + glyphsSize[static_cast<uint8_t>(m_drawText[pv])].width()
                    : L.left;
            }
        }

        Rect caretRect(caretX, L.top, 1, lineH);

        const Rect viewport(m_textVirtualOffset, m_rect.size() - Size(m_padding.left + m_padding.right, 0));
        const int vpad = 0;
        const int hpad = 0;

        const int topDelta = caretRect.top() - (viewport.top() + vpad);
        const int bottomDelta = caretRect.bottom() - (viewport.bottom() - vpad);
        const int leftDelta = caretRect.left() - (viewport.left() + hpad);
        const int rightDelta = caretRect.right() - (viewport.right() - hpad);

        if (topDelta < 0) {
            m_textVirtualOffset.y = std::max(0, m_textVirtualOffset.y + topDelta);
        } else if (bottomDelta > 0) {
            m_textVirtualOffset.y += bottomDelta;
        }

        if (leftDelta < 0) {
            m_textVirtualOffset.x = std::max(0, m_textVirtualOffset.x + leftDelta);
        } else if (rightDelta > 0) {
            m_textVirtualOffset.x += rightDelta;
        }

        setProp(PropCursorInRange, true);
    } else {
        const int visLen = std::min<int>(static_cast<int>(m_glyphsPositionsCache.size()), static_cast<int>(m_drawText.size()));
        const int srcLen = static_cast<int>(m_text.length());
        const int cursorVis = m_srcToVis.empty()
            ? std::clamp(m_cursorPos, 0, visLen)
            : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);

        struct LineInfo { int visStart, visEnd; int top, bottom, left, right; bool hasGlyphs; };
        std::vector<LineInfo> lines;
        {
            int start = 0;
            const int n = static_cast<int>(m_drawText.size());
            for (int i = 0; i <= n; ++i) {
                const bool br = (i == n) || (m_drawText[i] == '\n');
                if (!br) continue;
                lines.push_back({ start, i, std::numeric_limits<int>::min(), std::numeric_limits<int>::min(),
                                  std::numeric_limits<int>::max(), std::numeric_limits<int>::min(), false });
                start = i + 1;
            }
            if (lines.empty()) lines.push_back({ 0, n, 0, 0, 0, 0, false });
        }

        const int lineH = m_font->getGlyphHeight();
        const int lineDy = m_font->getGlyphSpacing().height();

        for (auto& li : lines) {
            for (int v = li.visStart; v < li.visEnd && v < visLen; ++v) {
                uint8_t g = static_cast<uint8_t>(m_drawText[v]);
                if (g < 32) continue;
                const Point& p = m_glyphsPositionsCache[v];
                const Rect r(p, glyphsSize[g]);
                li.hasGlyphs = true;
                li.top = (li.top == std::numeric_limits<int>::min()) ? r.top() : std::min(li.top, r.top());
                li.bottom = (li.bottom == std::numeric_limits<int>::min()) ? r.bottom() : std::max(li.bottom, r.bottom());
                li.left = std::min(li.left, r.left());
                li.right = std::max(li.right, r.right());
            }
        }

        int yCursor = 0;
        for (size_t i = 0; i < lines.size(); ++i) {
            auto& li = lines[i];
            if (li.hasGlyphs) {
                if (li.top == std::numeric_limits<int>::min()) li.top = yCursor;
                if (li.bottom == std::numeric_limits<int>::min()) li.bottom = li.top + lineH;
                yCursor = li.bottom;
            } else {
                if (i > 0) {
                    const auto& prev = lines[i - 1];
                    const int base = (prev.top != std::numeric_limits<int>::min()) ? prev.bottom : yCursor;
                    li.top = base + lineDy;
                    li.bottom = li.top + lineH;
                } else {
                    li.top = 0;
                    li.bottom = li.top + lineH;
                }
                if (li.left == std::numeric_limits<int>::max()) li.left = 0;
                if (li.right == std::numeric_limits<int>::min()) li.right = li.left;
            }
        }

        int lineIdx = (int)lines.size() - 1;
        for (int i = 0; i < (int)lines.size(); ++i) {
            if (cursorVis >= lines[i].visStart && cursorVis <= lines[i].visEnd) { lineIdx = i; break; }
        }
        const auto& L = lines[lineIdx];

        int caretX = L.left;
        if (L.hasGlyphs) {
            if (cursorVis < visLen) {
                uint8_t g = static_cast<uint8_t>(m_drawText[std::max(0, cursorVis)]);
                if (g >= 32) caretX = m_glyphsPositionsCache[cursorVis].x;
                else if (cursorVis > 0) {
                    int pv = cursorVis - 1;
                    while (pv >= L.visStart && static_cast<uint8_t>(m_drawText[pv]) < 32) --pv;
                    if (pv >= L.visStart) caretX = m_glyphsPositionsCache[pv].x + glyphsSize[static_cast<uint8_t>(m_drawText[pv])].width();
                    else caretX = L.left;
                }
            } else if (visLen > 0) {
                int pv = visLen - 1;
                while (pv >= L.visStart && static_cast<uint8_t>(m_drawText[pv]) < 32) --pv;
                caretX = (pv >= L.visStart)
                    ? m_glyphsPositionsCache[pv].x + glyphsSize[static_cast<uint8_t>(m_drawText[pv])].width()
                    : L.left;
            }
        }

        Rect caretRect(caretX, L.top, 1, lineH);
        const Rect viewport(m_textVirtualOffset, m_rect.size() - Size(m_padding.left + m_padding.right, 0));
        setProp(PropCursorInRange, viewport.intersects(caretRect));
    }

    bool fireAreaUpdate = (oldTextAreaOffset != m_textVirtualOffset);

    Rect textScreenCoords = m_rect;
    textScreenCoords.expandLeft(-m_padding.left);
    textScreenCoords.expandRight(-m_padding.right);
    textScreenCoords.expandBottom(-m_padding.bottom);
    textScreenCoords.expandTop(-m_padding.top);
    m_drawArea = textScreenCoords;

    if (textScreenCoords.size() != m_textVirtualSize) {
        m_textVirtualSize = textScreenCoords.size();
        fireAreaUpdate = true;
    }

    Size totalSize = textBoxSize;
    if (totalSize.width() < m_textVirtualSize.width())
        totalSize.setWidth(m_textVirtualSize.height());
    if (totalSize.height() < m_textVirtualSize.height())
        totalSize.setHeight(m_textVirtualSize.height());
    if (m_textTotalSize != totalSize) {
        m_textTotalSize = totalSize;
        fireAreaUpdate = true;
    }

    if (m_textAlign & Fw::AlignBottom) {
        m_drawArea.translate(0, textScreenCoords.height() - textBoxSize.height());
    } else if (m_textAlign & Fw::AlignVerticalCenter) {
        m_drawArea.translate(0, (textScreenCoords.height() - textBoxSize.height()) / 2);
    }

    if (m_textAlign & Fw::AlignRight) {
        m_drawArea.translate(textScreenCoords.width() - textBoxSize.width(), 0);
    } else if (m_textAlign & Fw::AlignHorizontalCenter) {
        m_drawArea.translate((textScreenCoords.width() - textBoxSize.width()) / 2, 0);
    }

    std::map<uint32_t, CoordsBufferPtr> colorCoordsMap;
    uint32_t curColorRgba = 0;
    int32_t nextColorIndex = 0;
    int32_t colorIndex = -1;
    CoordsBufferPtr coords;

    const int textColorsSize = static_cast<int>(m_drawTextColors.size());
    m_colorCoordsBuffer.clear();
    m_coordsBuffer->clear();

    for (int i = 0; i < textLength; ++i) {
        if (i >= nextColorIndex) {
            colorIndex = colorIndex + 1;
            if (colorIndex < textColorsSize)
                curColorRgba = m_drawTextColors[colorIndex].second.rgba();
            if (colorIndex + 1 < textColorsSize)
                nextColorIndex = m_drawTextColors[colorIndex + 1].first;
            else
                nextColorIndex = textLength;

            if (!colorCoordsMap.contains(curColorRgba))
                colorCoordsMap.insert(std::make_pair(curColorRgba, std::make_shared<CoordsBuffer>()));
            coords = colorCoordsMap[curColorRgba];
        }

        const uint8_t glyph = static_cast<uint8_t>(m_drawText[i]);
        m_glyphsCoords[i].first.clear();
        if (glyph < 32)
            continue;

        // Add glyph offset for proper TTF font rendering (same as BitmapFont::fillTextCoords)
        Rect glyphScreenCoords(m_glyphsPositionsCache[i] + glyphsOffset[glyph], glyphsSize[glyph]);
        Rect glyphTextureCoords = glyphsTextureCoords[glyph];

        if (m_textAlign & Fw::AlignBottom) {
            glyphScreenCoords.translate(0, textScreenCoords.height() - textBoxSize.height());
        } else if (m_textAlign & Fw::AlignVerticalCenter) {
            glyphScreenCoords.translate(0, (textScreenCoords.height() - textBoxSize.height()) / 2);
        }
        if (m_textAlign & Fw::AlignRight) {
            glyphScreenCoords.translate(textScreenCoords.width() - textBoxSize.width(), 0);
        } else if (m_textAlign & Fw::AlignHorizontalCenter) {
            glyphScreenCoords.translate((textScreenCoords.width() - textBoxSize.width()) / 2, 0);
        }

        if (glyphScreenCoords.bottom() < m_textVirtualOffset.y || glyphScreenCoords.right() < m_textVirtualOffset.x)
            continue;

        if (glyphScreenCoords.top() < m_textVirtualOffset.y) {
            glyphTextureCoords.setTop(glyphTextureCoords.top() + (m_textVirtualOffset.y - glyphScreenCoords.top()));
            glyphScreenCoords.setTop(m_textVirtualOffset.y);
        }
        if (glyphScreenCoords.left() < m_textVirtualOffset.x) {
            glyphTextureCoords.setLeft(glyphTextureCoords.left() + (m_textVirtualOffset.x - glyphScreenCoords.left()));
            glyphScreenCoords.setLeft(m_textVirtualOffset.x);
        }

        glyphScreenCoords.translate(-m_textVirtualOffset);
        glyphScreenCoords.translate(textScreenCoords.topLeft());

        if (!textScreenCoords.intersects(glyphScreenCoords))
            continue;

        if (glyphScreenCoords.bottom() > textScreenCoords.bottom()) {
            glyphTextureCoords.setBottom(glyphTextureCoords.bottom() + (textScreenCoords.bottom() - glyphScreenCoords.bottom()));
            glyphScreenCoords.setBottom(textScreenCoords.bottom());
        }
        if (glyphScreenCoords.right() > textScreenCoords.right()) {
            glyphTextureCoords.setRight(glyphTextureCoords.right() + (textScreenCoords.right() - glyphScreenCoords.right()));
            glyphScreenCoords.setRight(textScreenCoords.right());
        }

        m_glyphsCoords[i].first = glyphScreenCoords;
        m_glyphsCoords[i].second = glyphTextureCoords;

        if (m_atlasRegion)
            glyphTextureCoords.translate(m_atlasRegion->x, m_atlasRegion->y);

        if (textColorsSize > 0) {
            coords->addRect(glyphScreenCoords, glyphTextureCoords);
        } else {
            m_coordsBuffer->addRect(glyphScreenCoords, glyphTextureCoords);
        }
    }

    for (auto& [rgba, crds] : colorCoordsMap)
        m_colorCoordsBuffer.emplace_back(Color(rgba), crds);

    std::vector<Rect> glyphRects;
    glyphRects.reserve(m_glyphsCoords.size());
    for (const auto& pair : m_glyphsCoords) {
        glyphRects.push_back(pair.first);
    }

    if (hasEventListener(EVENT_TEXT_CLICK) || hasEventListener(EVENT_TEXT_HOVER))
        updateRectToWord(glyphRects);

    if (!disableAreaUpdate && fireAreaUpdate)
        onTextAreaUpdate(m_textVirtualOffset, m_textVirtualSize, m_textTotalSize);

    repaint();
}

void UITextEdit::setCursorPos(int pos, bool focusCursor)
{
    setCursorPosEx(pos, false, focusCursor);
}

void UITextEdit::setCursorPosEx(int pos, bool preservePreferredX, bool focusCursor)
{
    if (pos < 0)
        pos = m_text.length();

    if (pos == m_cursorPos)
        return;

    if (pos < 0)
        m_cursorPos = 0;
    else if (static_cast<size_t>(pos) >= m_text.length())
        m_cursorPos = m_text.length();
    else
        m_cursorPos = pos;

    if (!preservePreferredX)
        m_cursorPreferredX = -1;

    update(focusCursor);
}

void UITextEdit::setSelection(int start, int end)
{
    if (start == m_selectionStart && end == m_selectionEnd)
        return;

    if (start > end)
        std::swap(start, end);

    if (end == -1)
        end = m_text.length();

    m_selectionStart = std::clamp<int>(start, 0, static_cast<int>(m_text.length()));
    m_selectionEnd = std::clamp<int>(end, 0, static_cast<int>(m_text.length()));
    recacheGlyphs();

    repaint();
}

void UITextEdit::setTextHidden(const bool hidden)
{
    if (getProp(PropTextHidden) == hidden)
        return;

    setProp(PropTextHidden, hidden);
    updateText();
}

void UITextEdit::setTextVirtualOffset(const Point& offset)
{
    m_textVirtualOffset = offset;
    update();
}

void UITextEdit::appendText(const std::string_view txt)
{
    std::string text{ txt.data() };

    if (hasSelection())
        del();

    if (m_cursorPos >= 0) {
        // replace characters that are now allowed
        if (!getProp(PropMultiline))
            stdext::replace_all(text, "\n", " ");
        stdext::replace_all(text, "\r", "");
        stdext::replace_all(text, "\t", "    ");

        if (text.length() > 0) {
            // only add text if textedit can add it
            if (m_maxLength > 0 && m_text.length() + text.length() > m_maxLength)
                return;

            // only ignore text append if it contains invalid characters
            if (!m_validCharacters.empty()) {
                for (const char i : text) {
                    if (m_validCharacters.find(i) == std::string::npos)
                        return;
                }
            }

            std::string tmp = m_text;
            tmp.insert(m_cursorPos, text);
            m_cursorPos += text.length();
            setText(tmp);
        }
    }
}

void UITextEdit::appendCharacter(const char c)
{
    if ((c == '\n' && !getProp(PropMultiline)) || c == '\r')
        return;

    if (hasSelection())
        del();

    if (m_cursorPos == 0)
        return;

    if (m_maxLength > 0 && m_text.length() + 1 > m_maxLength)
        return;

    if (!m_validCharacters.empty() && m_validCharacters.find(c) == std::string::npos)
        return;

    std::string tmp;
    tmp = c;
    std::string tmp2 = m_text;
    tmp2.insert(m_cursorPos, tmp);
    ++m_cursorPos;
    setText(tmp2);
}

void UITextEdit::removeCharacter(const bool right)
{
    std::string tmp = m_text;
    if (static_cast<size_t>(m_cursorPos) >= 0 && tmp.length() > 0) {
        if (static_cast<size_t>(m_cursorPos) >= tmp.length()) {
            tmp.erase(tmp.begin() + (--m_cursorPos));
        } else if (right)
            tmp.erase(tmp.begin() + m_cursorPos);
        else if (m_cursorPos > 0)
            tmp.erase(tmp.begin() + --m_cursorPos);
        setText(tmp);
    }
}

void UITextEdit::blinkCursor()
{
    m_cursorTicks = g_clock.millis();
    repaint();
}

void UITextEdit::deleteSelection()
{
    if (!hasSelection()) {
        return;
    }

    std::string tmp = m_text;
    tmp.erase(m_selectionStart, m_selectionEnd - m_selectionStart);

    setCursorPos(m_selectionStart);
    clearSelection();
    setText(tmp);
}

void UITextEdit::del(const bool right)
{
    if (hasSelection()) {
        deleteSelection();
    } else
        removeCharacter(right);
}

void UITextEdit::paste(const std::string_view text)
{
    if (hasSelection())
        del();

    appendText(text);
}

std::string UITextEdit::copy()
{
    std::string text;
    if (hasSelection()) {
        text = getSelection();
        g_window.setClipboardText(text);
    }
    return text;
}

std::string UITextEdit::cut()
{
    std::string text = copy();
    del();
    return text;
}

void UITextEdit::wrapText()
{
    setText(m_font->wrapText(m_text, getPaddingRect().width() - m_textOffset.x, getTextWrapOptions()));
}

void UITextEdit::moveCursorHorizontally(const bool right)
{
    if (right) {
        if (static_cast<size_t>(m_cursorPos) + 1 <= m_text.length())
            ++m_cursorPos;
        else
            m_cursorPos = 0;
    } else if (m_cursorPos - 1 >= 0)
        --m_cursorPos;
    else
        m_cursorPos = m_text.length();

    m_cursorPreferredX = -1;
    blinkCursor();
    update(true);
}

void UITextEdit::moveCursorVertically(bool up)
{
    const int visLen = std::min<int>(m_glyphsCoords.size(), static_cast<int>(m_displayedText.length()));
    const int srcLen = static_cast<int>(m_text.length());
    if (visLen < 0) return;

    const int curVis = m_srcToVis.empty()
        ? std::clamp(m_cursorPos, 0, visLen)
        : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);

    int desiredX = m_cursorPreferredX;
    if (desiredX < 0) {
        if (curVis < visLen && m_glyphsCoords[curVis].first.isValid())
            desiredX = m_glyphsCoords[curVis].first.left();
        else if (curVis > 0 && curVis - 1 < visLen && m_glyphsCoords[curVis - 1].first.isValid())
            desiredX = m_glyphsCoords[curVis - 1].first.right();
        else
            desiredX = m_rect.left() + m_padding.left;
        m_cursorPreferredX = desiredX;
    }

    struct LineInfo { int visStart, visEnd; int top, bottom, left, right; bool hasGlyphs; };
    std::vector<LineInfo> lines;
    {
        int start = 0;
        const int n = static_cast<int>(m_displayedText.size());
        for (int i = 0; i <= n; ++i) {
            const bool br = (i == n) || (m_displayedText[i] == '\n');
            if (!br) continue;
            lines.push_back({ start, i, 0, 0, 0, 0, false });
            start = i + 1;
        }
        if (lines.empty()) lines.push_back({ 0, n, 0, 0, 0, 0, false });
    }

    const int glyphH = m_font->getGlyphHeight();
    const int lineDy = m_font->getGlyphSpacing().height();
    const int areaTop = m_drawArea.top();
    const int areaLeft = m_drawArea.left();
    const int y0 = areaTop - m_textVirtualOffset.y;

    std::vector<int> visToLine(visLen + 1, 0);
    for (size_t k = 0; k < lines.size(); ++k)
        for (int v = lines[k].visStart; v <= lines[k].visEnd; ++v)
            visToLine[std::clamp(v, 0, visLen)] = static_cast<int>(k);

    for (size_t k = 0; k < lines.size(); ++k) {
        auto& L = lines[k];
        int top = std::numeric_limits<int>::max();
        int bottom = std::numeric_limits<int>::min();
        int left = std::numeric_limits<int>::max();
        int right = std::numeric_limits<int>::min();

        const int visEndClamp = std::min(L.visEnd, visLen);
        for (int i = L.visStart; i < visEndClamp; ++i) {
            const Rect& r = m_glyphsCoords[i].first;
            if (!r.isValid()) continue;
            L.hasGlyphs = true;
            top = std::min(top, r.top());
            bottom = std::max(bottom, r.bottom());
            left = std::min(left, r.left());
            right = std::max(right, r.right());
        }

        if (!L.hasGlyphs) {
            const int lineIdx = static_cast<int>(k);
            const int baseTop = y0 + lineIdx * (glyphH + lineDy);
            L.top = baseTop;
            L.bottom = baseTop + glyphH;
            L.left = areaLeft;
            L.right = areaLeft;
        } else {
            L.top = (top == std::numeric_limits<int>::max()) ? (y0 + (int)k * (glyphH + lineDy)) : top;
            L.bottom = (bottom == std::numeric_limits<int>::min()) ? (L.top + glyphH) : bottom;
            L.left = (left == std::numeric_limits<int>::max()) ? areaLeft : left;
            L.right = (right == std::numeric_limits<int>::min()) ? areaLeft : right;
        }
    }

    int curLine = 0;
    for (int ln = 0; ln < (int)lines.size(); ++ln) {
        if (curVis >= lines[ln].visStart && curVis <= lines[ln].visEnd) { curLine = ln; break; }
    }

    const int targetLine = up ? curLine - 1 : curLine + 1;
    if (targetLine < 0) { setCursorPosEx(0, true, true); return; }
    if (targetLine >= (int)lines.size()) { setCursorPosEx(srcLen, true, true); return; }

    const auto& L = lines[targetLine];

    int xStart = L.left;
    std::vector<int> boundariesX;
    boundariesX.reserve(std::max(1, L.visEnd - L.visStart) + 1);
    boundariesX.push_back(xStart);

    if (L.hasGlyphs) {
        for (int k = L.visStart; k < std::min(L.visEnd, visLen); ++k) {
            const Rect& r = m_glyphsCoords[k].first;
            if (!r.isValid()) continue;
            boundariesX.push_back(r.right());
        }
    }

    int bestB = 0;
    int bestDist = std::numeric_limits<int>::max();
    const int lastB = (int)boundariesX.size() - 1;

    if (!boundariesX.empty()) {
        if (desiredX >= boundariesX[lastB]) {
            bestB = std::max(0, lastB - 1);
        } else {
            for (int b = 0; b < (int)boundariesX.size(); ++b) {
                const int d = std::abs(boundariesX[b] - desiredX);
                if (d < bestDist) { bestDist = d; bestB = b; }
                if (desiredX < boundariesX[b]) break;
            }
            if (bestB >= lastB) bestB = std::max(0, lastB - 1);
        }
    }

    const int targetVis = std::clamp(L.visStart + bestB, 0, visLen);
    const int visIdx = std::clamp(targetVis, 0, (int)m_visToSrc.size() - 1);
    const int targetSrc = m_visToSrc.empty() ? std::clamp(targetVis, 0, srcLen) : std::clamp(m_visToSrc[visIdx], 0, srcLen);

    setCursorPosEx(targetSrc, true, true);
}

int UITextEdit::getTextPos(const Point& pos)
{
    const int srcLen = static_cast<int>(m_text.length());
    const int visLen = static_cast<int>(m_displayedText.length());
    if (visLen <= 0) return 0;

    struct VLine { int visStart; int visEnd; int top, bottom; int left, right; bool hasGlyphs; };
    std::vector<VLine> lines;
    lines.reserve(64);

    int lineStart = 0;
    for (int j = 0; j <= visLen; ++j) {
        const bool br = (j == visLen) || (m_displayedText[j] == '\n');
        if (!br) continue;
        lines.push_back({ lineStart, j, 0, 0, 0, 0, false });
        lineStart = j + 1;
    }
    if (lines.empty()) lines.push_back({ 0, visLen, 0, 0, 0, 0, false });

    const int glyphH = m_font->getGlyphHeight();
    const int lineDy = m_font->getGlyphSpacing().height();
    const int areaTop = m_drawArea.top();
    const int areaLeft = m_drawArea.left();
    const int y0 = areaTop - m_textVirtualOffset.y;

    std::vector<int> visToLine(visLen + 1, 0);
    for (size_t k = 0; k < lines.size(); ++k)
        for (int v = lines[k].visStart; v <= lines[k].visEnd; ++v)
            visToLine[std::clamp(v, 0, visLen)] = static_cast<int>(k);

    const int vmax = std::min(visLen, (int)m_glyphsCoords.size());
    for (size_t k = 0; k < lines.size(); ++k) {
        auto& L = lines[k];
        int top = std::numeric_limits<int>::max();
        int bottom = std::numeric_limits<int>::min();
        int left = std::numeric_limits<int>::max();
        int right = std::numeric_limits<int>::min();

        for (int i = 0; i < vmax; ++i) {
            const int ln = visToLine[std::clamp(i, 0, visLen)];
            if (ln != (int)k) continue;
            const Rect& r = m_glyphsCoords[i].first;
            if (!r.isValid()) continue;
            L.hasGlyphs = true;
            top = std::min(top, r.top());
            bottom = std::max(bottom, r.bottom());
            left = std::min(left, r.left());
            right = std::max(right, r.right());
        }

        if (!L.hasGlyphs) {
            if (k > 0) {
                const auto& P = lines[k - 1];
                const int base = (P.bottom > 0 ? P.bottom : (y0 + (int)(k - 1) * (glyphH + lineDy)));
                L.top = base + lineDy;
                L.bottom = L.top + glyphH;
            } else {
                int nextTop = std::numeric_limits<int>::min();
                for (size_t j = k + 1; j < lines.size(); ++j) {
                    if (lines[j].hasGlyphs) { nextTop = lines[j].top; break; }
                }
                if (nextTop != std::numeric_limits<int>::min()) {
                    L.bottom = nextTop - lineDy;
                    L.top = L.bottom - glyphH;
                } else {
                    L.top = y0;
                    L.bottom = L.top + glyphH;
                }
            }
            L.left = areaLeft;
            L.right = areaLeft;
        } else {
            L.top = (top == std::numeric_limits<int>::max()) ? (y0 + (int)k * (glyphH + lineDy)) : top;
            L.bottom = (bottom == std::numeric_limits<int>::min()) ? (L.top + glyphH) : bottom;
            L.left = (left == std::numeric_limits<int>::max()) ? areaLeft : left;
            L.right = (right == std::numeric_limits<int>::min()) ? areaLeft : right;
        }
    }

    if (pos.y < lines.front().top)   return 0;
    if (pos.y > lines.back().bottom) return srcLen;

    int clickedLine = -1;
    for (size_t k = 0; k < lines.size(); ++k) {
        if (pos.y >= lines[k].top && pos.y <= lines[k].bottom) { clickedLine = (int)k; break; }
        if (k + 1 < lines.size() && pos.y > lines[k].bottom && pos.y < lines[k + 1].top) {
            clickedLine = (pos.y - lines[k].bottom <= lines[k + 1].top - pos.y) ? (int)k : (int)k + 1;
            break;
        }
    }
    if (clickedLine < 0) clickedLine = (int)lines.size() - 1;

    const auto& L = lines[clickedLine];

    if (!L.hasGlyphs || pos.x <= L.left) {
        const int visIdx = std::clamp(L.visStart, 0, (int)m_visToSrc.size() - 1);
        return std::clamp(m_visToSrc.empty() ? L.visStart : m_visToSrc[visIdx], 0, srcLen);
    }

    if (pos.x >= L.right) {
        const bool isLastVisualLine = (clickedLine == (int)lines.size() - 1);
        if (isLastVisualLine && L.visEnd == visLen) {
            return srcLen;
        }

        const bool hasVisualNewline = (L.visEnd < visLen) && (m_displayedText[L.visEnd] == '\n');
        if (!m_visToSrc.empty() && hasVisualNewline) {
            const int vPrev = std::max(L.visEnd - 1, L.visStart);
            const int sEnd = std::clamp(m_visToSrc[std::clamp(L.visEnd, 0, (int)m_visToSrc.size() - 1)], 0, srcLen);
            const int sPrev = std::clamp(m_visToSrc[std::clamp(vPrev, 0, (int)m_visToSrc.size() - 1)], 0, srcLen);
            const bool isRealBreak = (sEnd > sPrev);

            if (isRealBreak) {
                int bestSrc = sPrev;
                if (!m_srcToVis.empty()) {
                    const int svMax = (int)m_srcToVis.size();
                    for (int s = sPrev; s <= sEnd && s < svMax; ++s) {
                        if (m_srcToVis[s] <= L.visEnd) bestSrc = s;
                        else break;
                    }
                } else bestSrc = sEnd;
                return std::clamp(bestSrc, 0, srcLen);
            }
        }

        const int vTarget = std::max(L.visEnd, L.visStart); // <-- ajuste (antes era L.visEnd - 1)
        const int sLineStart = m_visToSrc.empty() ? 0 :
            std::clamp(m_visToSrc[std::clamp(L.visStart, 0, (int)m_visToSrc.size() - 1)], 0, srcLen);
        const int sLineEnd = m_visToSrc.empty() ? srcLen :
            std::clamp(m_visToSrc[std::clamp(L.visEnd, 0, (int)m_visToSrc.size() - 1)], 0, srcLen);

        int bestSrc = sLineStart;
        if (!m_srcToVis.empty()) {
            const int svMax = (int)m_srcToVis.size();
            for (int s = sLineStart; s <= sLineEnd && s < svMax; ++s) {
                if (m_srcToVis[s] <= vTarget) bestSrc = s;
                else break;
            }
        } else bestSrc = sLineEnd;

        return std::clamp(bestSrc, 0, srcLen);
    }

    int bestVis = L.visStart;
    for (int j = L.visStart; j < L.visEnd; ++j) {
        const Rect& r = m_glyphsCoords[j].first;
        if (!r.isValid()) continue;
        if (pos.x < r.right()) { bestVis = j; break; }
        bestVis = j;
    }
    const int visIdx = std::clamp(bestVis, 0, (int)m_visToSrc.size() - 1);
    return std::clamp(m_visToSrc.empty() ? bestVis : m_visToSrc[visIdx], 0, srcLen);
}

void UITextEdit::updateDisplayedText()
{
    std::string src = getProp(PropTextHidden) ? std::string(m_text.length(), '*') : m_text;
    const auto& srcColors = m_textColors;

    std::string vis = src;
    if (isTextWrap() && m_rect.isValid()) {
        vis = m_font->wrapText(vis, getPaddingRect().width() - m_textOffset.x, getTextWrapOptions());
    }
    m_displayedText = vis;

    m_srcToVis.assign(src.size() + 1, 0);
    m_visToSrc.assign(vis.size() + 1, 0);

    if (src.empty() && vis.empty()) {
        m_srcToVis[0] = 0;
        m_visToSrc[0] = 0;
        return;
    }

    size_t i = 0, j = 0;
    while (i < src.size() || j < vis.size()) {
        if (i <= src.size()) m_srcToVis[i] = static_cast<int>(j);
        if (j <= vis.size()) m_visToSrc[j] = static_cast<int>(i);

        if (i < src.size() && j < vis.size() && src[i] == vis[j]) { ++i; ++j; continue; }
        if (j < vis.size() && (vis[j] == '\n' || vis[j] == '-')) { ++j; continue; }
        if (i < src.size() && src[i] == ' ' && (j >= vis.size() || vis[j] != ' ')) { ++i; continue; }

        if (i < src.size() && j < vis.size()) { ++i; ++j; continue; }
        if (i < src.size()) { ++i; continue; }
        if (j < vis.size()) { ++j; continue; }
    }

    m_srcToVis[src.size()] = static_cast<int>(j);
    m_visToSrc[vis.size()] = static_cast<int>(i);

    m_drawTextColors.clear();
    m_drawTextColors.reserve(srcColors.size());

    const int visSize = static_cast<int>(vis.size());
    const int srcSize = static_cast<int>(src.size());

    for (const auto& [srcPosRaw, color] : srcColors) {
        const int srcPos = std::clamp(srcPosRaw, 0, srcSize);
        const int visPos = m_srcToVis.empty() ? srcPos : std::clamp(m_srcToVis[srcPos], 0, visSize);

        if (!m_drawTextColors.empty() && m_drawTextColors.back().first == visPos) {
            m_drawTextColors.back().second = color;
        } else {
            m_drawTextColors.emplace_back(visPos, color);
        }
    }
}

std::string UITextEdit::getSelection()
{
    if (!hasSelection())
        return {};
    return m_text.substr(m_selectionStart, m_selectionEnd - m_selectionStart);
}

void UITextEdit::updateText()
{
    if (m_cursorPos > static_cast<int>(m_text.length()))
        m_cursorPos = m_text.length();

    if (getProp(PropSelectable)) {
        m_selectionEnd = 0;
        m_selectionStart = 0;
    }

    blinkCursor();
    updateDisplayedText();
    update(true);
}

void UITextEdit::onHoverChange(const bool hovered)
{
    if (getProp(PropChangeCursorImage)) {
        if (hovered && !g_mouse.isCursorChanged())
            g_mouse.pushCursor("text");
        else
            g_mouse.popCursor("text");
    }
}

void UITextEdit::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    UIWidget::onStyleApply(styleName, styleNode);
		
    // Force scale to 1.0 to prevent distortion with TTF fonts
    m_fontScale = 1.0f;	

    for (const auto& node : styleNode->children()) {    // Force scale to 1.0 to prevent distortion with TTF fonts
    m_fontScale = 1.0f;	
        if (node->tag() == "ttf-font" || node->tag() == "ttf-font-size" || 
            node->tag() == "ttf-stroke-width" || node->tag() == "ttf-stroke-color" ||
            node->tag() == "stroke" || node->tag() == "font" || node->tag() == "font-scale") {
            continue;
        }		
        if (node->tag() == "text") {
            setText(node->value());
            setCursorPos(m_text.length());
        } else if (node->tag() == "text-hidden")
            setTextHidden(node->value<bool>());
        else if (node->tag() == "shift-navigation")
            setShiftNavigation(node->value<bool>());
        else if (node->tag() == "multiline")
            setMultiline(node->value<bool>());
        else if (node->tag() == "max-length")
            setMaxLength(node->value<int>());
        else if (node->tag() == "editable")
            setEditable(node->value<bool>());
        else if (node->tag() == "selectable")
            setSelectable(node->value<bool>());
        else if (node->tag() == "selection-color")
            setSelectionColor(node->value<Color>());
        else if (node->tag() == "selection-background-color")
            setSelectionBackgroundColor(node->value<Color>());
        else if (node->tag() == "selection") {
            const auto& selectionRange = node->value<Point>();
            setSelection(selectionRange.x, selectionRange.y);
        } else if (node->tag() == "cursor-visible")
            setCursorVisible(node->value<bool>());
        else if (node->tag() == "change-cursor-image")
            setChangeCursorImage(node->value<bool>());
        else if (node->tag() == "auto-scroll")
            setAutoScroll(node->value<bool>());
        else if (node->tag() == "placeholder")
            setPlaceholder(node->value());
        else if (node->tag() == "placeholder-color")
            setPlaceholderColor(node->value<Color>());
        else if (node->tag() == "placeholder-align")
            setPlaceholderAlign(Fw::translateAlignment(node->value()));
        else if (node->tag() == "placeholder-font")
            setPlaceholderFont(node->value());
    }
}

void UITextEdit::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    update(true);
    UIWidget::onGeometryChange(oldRect, newRect);
}

void UITextEdit::onFocusChange(const bool focused, const Fw::FocusReason reason)
{
    if (focused) {
        if (reason == Fw::KeyboardFocusReason)
            setCursorPos(m_text.length());
        else
            blinkCursor();
        update(true);
#ifdef ANDROID
        if (getProp(PropEditable)) {
            g_androidManager.showKeyboardSoft();
            g_androidManager.showInputPreview(getText());
        }
#endif
    } else if (getProp(PropSelectable))
        clearSelection();
#ifdef ANDROID
    if (!focused && getProp(PropEditable))
        g_androidManager.hideInputPreview();
#endif
    UIWidget::onFocusChange(focused, reason);
}

bool UITextEdit::onKeyPress(const uint8_t keyCode, const int keyboardModifiers, const int autoRepeatTicks)
{
    if (UIWidget::onKeyPress(keyCode, keyboardModifiers, autoRepeatTicks))
        return true;

    if (keyboardModifiers == Fw::KeyboardNoModifier) {
        if (keyCode == Fw::KeyDelete && getProp(PropEditable)) {
            if (hasSelection() || !m_text.empty()) {
                del(true);
                return true;
            }
        } else if (keyCode == Fw::KeyBackspace && getProp(PropEditable)) {
            if (hasSelection() || !m_text.empty()) {
                del(false);
                return true;
            }
        } else if (keyCode == Fw::KeyRight && !getProp(PropShiftNavigation)) {
            clearSelection();
            moveCursorHorizontally(true);
            return true;
        } else if (keyCode == Fw::KeyLeft && !getProp(PropShiftNavigation)) {
            clearSelection();
            moveCursorHorizontally(false);
            return true;
        } else if (keyCode == Fw::KeyHome) {
            clearSelection();
            const int srcLen = static_cast<int>(m_text.length());
            const int visLen = static_cast<int>(m_displayedText.length());
            if (visLen <= 0) return true;
            const int curVis = m_srcToVis.empty()
                ? std::clamp(m_cursorPos, 0, visLen)
                : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);
            int lineStart = 0;
            for (int i = curVis - 1; i >= 0; --i) { if (m_displayedText[i] == '\n') { lineStart = i + 1; break; } }
            const int srcTarget = m_visToSrc.empty()
                ? std::clamp(lineStart, 0, srcLen)
                : std::clamp(m_visToSrc[std::clamp(lineStart, 0, visLen)], 0, srcLen);
            setCursorPos(srcTarget);
            return true;
        } else if (keyCode == Fw::KeyEnd) {
            clearSelection();

            const int srcLen = static_cast<int>(m_text.length());
            const int visLen = static_cast<int>(m_displayedText.length());
            if (visLen <= 0) return true;

            const int curVis = m_srcToVis.empty()
                ? std::clamp(m_cursorPos, 0, visLen)
                : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);

            int ls = 0;
            for (int i = curVis - 1; i >= 0; --i) { if (m_displayedText[i] == '\n') { ls = i + 1; break; } }
            int le = visLen;
            for (int i = curVis; i < visLen; ++i) { if (m_displayedText[i] == '\n') { le = i; break; } }

            int srcBegin = m_visToSrc.empty() ? ls : std::clamp(m_visToSrc[std::clamp(ls, 0, visLen)], 0, srcLen);
            int srcEnd = m_visToSrc.empty() ? le : std::clamp(m_visToSrc[std::clamp(le, 0, visLen)], 0, srcLen);

            int bestSrc = srcBegin;
            if (!m_srcToVis.empty()) {
                for (int s = srcBegin; s <= srcEnd && s < (int)m_srcToVis.size(); ++s) {
                    const int v = m_srcToVis[s];
                    if (v <= le) bestSrc = s;
                    else break;
                }
            } else {
                bestSrc = std::clamp(le, 0, srcLen);
            }

            setCursorPos(bestSrc);
            return true;
        } else if (keyCode == Fw::KeyTab && !getProp(PropShiftNavigation)) {
            clearSelection();
            if (const auto& parent = getParent())
                parent->focusNextChild(Fw::KeyboardFocusReason, true);
            return true;
        } else if (keyCode == Fw::KeyEnter && getProp(PropMultiline) && getProp(PropEditable)) {
            appendCharacter('\n');
            return true;
        } else if (keyCode == Fw::KeyUp && !getProp(PropShiftNavigation) && getProp(PropMultiline)) {
            clearSelection();
            moveCursorVertically(true);
            return true;
        } else if (keyCode == Fw::KeyDown && !getProp(PropShiftNavigation) && getProp(PropMultiline)) {
            clearSelection();
            moveCursorVertically(false);
            return true;
        }
    } else if (keyboardModifiers == Fw::KeyboardCtrlModifier) {
        if (keyCode == Fw::KeyV && getProp(PropEditable)) {
            paste(g_window.getClipboardText());
            return true;
        }
        if (keyCode == Fw::KeyX && getProp(PropEditable) && getProp(PropSelectable)) {
            if (hasSelection()) {
                cut();
                return true;
            }
        } else if (keyCode == Fw::KeyC && getProp(PropSelectable)) {
            if (hasSelection()) {
                copy();
                return true;
            }
        } else if (keyCode == Fw::KeyA && getProp(PropSelectable)) {
            if (m_text.length() > 0) {
                selectAll();
                return true;
            }
        } else if (keyCode == Fw::KeyBackspace) {
            if (hasSelection()) {
                deleteSelection();
            } else if (m_text.length() > 0) {
                std::string tmp = m_text;
                if (m_cursorPos == 0) {
                    tmp.erase(tmp.begin());
                } else {
                    int pos = m_cursorPos;
                    while (pos > 0 && tmp[pos - 1] == ' ')
                        --pos;
                    while (pos > 0 && tmp[pos - 1] != ' ')
                        --pos;
                    tmp.erase(tmp.begin() + pos, tmp.begin() + m_cursorPos);
                }
                setText(tmp);
                return true;
            }
        }
    } else if (keyboardModifiers == Fw::KeyboardShiftModifier) {
        if (keyCode == Fw::KeyTab && !getProp(PropShiftNavigation)) {
            if (const auto& parent = getParent())
                parent->focusPreviousChild(Fw::KeyboardFocusReason, true);
            return true;
        }
        if (keyCode == Fw::KeyRight || keyCode == Fw::KeyLeft) {
            const size_t oldCursorPos = m_cursorPos;
            if (keyCode == Fw::KeyRight)
                moveCursorHorizontally(true);
            else if (keyCode == Fw::KeyLeft)
                moveCursorHorizontally(false);
            if (getProp(PropShiftNavigation))
                clearSelection();
            else {
                if (!hasSelection())
                    m_selectionReference = oldCursorPos;
                setSelection(m_selectionReference, m_cursorPos);
            }
            return true;
        }
        if (keyCode == Fw::KeyUp && getProp(PropMultiline)) {
            const int oldPos = m_cursorPos;
            moveCursorVertically(true);
            if (!hasSelection())
                m_selectionReference = oldPos;
            setSelection(m_selectionReference, m_cursorPos);
            return true;
        }
        if (keyCode == Fw::KeyDown && getProp(PropMultiline)) {
            const int oldPos = m_cursorPos;
            moveCursorVertically(false);
            if (!hasSelection())
                m_selectionReference = oldPos;
            setSelection(m_selectionReference, m_cursorPos);
            return true;
        }
        if (keyCode == Fw::KeyHome) {
            const int srcLen = static_cast<int>(m_text.length());
            const int visLen = static_cast<int>(m_displayedText.length());
            if (visLen <= 0) return true;
            const int curVis = m_srcToVis.empty()
                ? std::clamp(m_cursorPos, 0, visLen)
                : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);
            int lineStart = 0;
            for (int i = curVis - 1; i >= 0; --i) { if (m_displayedText[i] == '\n') { lineStart = i + 1; break; } }
            const int srcTarget = m_visToSrc.empty()
                ? std::clamp(lineStart, 0, srcLen)
                : std::clamp(m_visToSrc[std::clamp(lineStart, 0, visLen)], 0, srcLen);

            if (getProp(PropShiftNavigation)) {
                clearSelection();
            } else {
                if (!hasSelection())
                    m_selectionReference = m_cursorPos;
                setSelection(m_selectionReference, srcTarget);
            }
            setCursorPos(srcTarget);
            return true;
        } else if (keyCode == Fw::KeyEnd) {
            const int srcLen = static_cast<int>(m_text.length());
            const int visLen = static_cast<int>(m_displayedText.length());
            if (visLen <= 0) return true;
            const int curVis = m_srcToVis.empty()
                ? std::clamp(m_cursorPos, 0, visLen)
                : std::clamp(m_srcToVis[std::clamp(m_cursorPos, 0, srcLen)], 0, visLen);

            int ls = 0;
            for (int i = curVis - 1; i >= 0; --i) { if (m_displayedText[i] == '\n') { ls = i + 1; break; } }
            int le = visLen;
            for (int i = curVis; i < visLen; ++i) { if (m_displayedText[i] == '\n') { le = i; break; } }

            int srcBegin = m_visToSrc.empty() ? ls : std::clamp(m_visToSrc[std::clamp(ls, 0, visLen)], 0, srcLen);
            int srcEnd = m_visToSrc.empty() ? le : std::clamp(m_visToSrc[std::clamp(le, 0, visLen)], 0, srcLen);

            int bestSrc = srcBegin;
            if (!m_srcToVis.empty()) {
                for (int s = srcBegin; s <= srcEnd && s < (int)m_srcToVis.size(); ++s) {
                    const int v = m_srcToVis[s];
                    if (v <= le) bestSrc = s;
                    else break;
                }
            } else {
                bestSrc = std::clamp(le, 0, srcLen);
            }

            if (getProp(PropShiftNavigation)) {
                clearSelection();
            } else {
                if (!hasSelection())
                    m_selectionReference = m_cursorPos;
                setSelection(m_selectionReference, bestSrc);
            }
            setCursorPos(bestSrc);
            return true;
        }
    }

    return false;
}

bool UITextEdit::onKeyText(const std::string_view keyText)
{
    // ctrl + backspace inserts a special ASCII character
    if (keyText.length() == 1 && keyText.front() == Fw::KeyDel) {
        return false;
    }

    if (getProp(PropEditable)) {
        appendText(keyText.data());
        return true;
    }
    return false;
}

bool UITextEdit::onMousePress(const Point& mousePos, const Fw::MouseButton button)
{
    if (UIWidget::onMousePress(mousePos, button))
        return true;

    if (button == Fw::MouseLeftButton) {
#ifdef ANDROID
        if (getProp(PropEditable)) {
            g_androidManager.showKeyboardSoft();
            g_androidManager.showInputPreview(getText());
        }
#endif
        const int pos = getTextPos(mousePos);
        if (pos >= 0) {
            const int mods = g_window.getKeyboardModifiers();

            if (getProp(PropSelectable)) {
                if (mods & Fw::KeyboardShiftModifier) {
                    if (!hasSelection())
                        m_selectionReference = m_cursorPos;

                    setCursorPos(pos, false);
                    setSelection(m_selectionReference, pos);
                } else {
                    setCursorPos(pos, false);
                    m_selectionReference = pos;
                    setSelection(pos, pos);
                }
            } else {
                setCursorPos(pos, false);
            }
        }
#ifdef __EMSCRIPTEN__
        if (g_window.isVisible()) {
            MAIN_THREAD_ASYNC_EM_ASM({
                if (navigator && "virtualKeyboard" in navigator) {
                    document.getElementById("title-text").focus();
                    navigator.virtualKeyboard.show();
                }
            });
        }
#endif
        return true;
    }
    return false;
}

bool UITextEdit::onMouseRelease(const Point& mousePos, const Fw::MouseButton button)
{
    return UIWidget::onMouseRelease(mousePos, button);
}

bool UITextEdit::onMouseMove(const Point& mousePos, const Point& mouseMoved)
{
    if (UIWidget::onMouseMove(mousePos, mouseMoved))
        return true;

    if (getProp(PropSelectable) && isPressed()) {
        const int pos = getTextPos(mousePos);
        if (pos >= 0) {
            setSelection(m_selectionReference, pos);
            setCursorPos(pos, false);
        }
        return true;
    }
    return false;
}

bool UITextEdit::onDoubleClick(const Point& mousePos)
{
    if (UIWidget::onDoubleClick(mousePos))
        return true;

    if (!getProp(PropSelectable) || m_text.empty())
        return false;

    int pos = getTextPos(mousePos);
    if (pos < 0) return false;
    if (pos >= static_cast<int>(m_text.size()))
        pos = static_cast<int>(m_text.size()) - 1;

    auto isSpace = [](unsigned char c) -> bool { return std::isspace(c) != 0; };
    auto isWord = [](unsigned char c) -> bool { return std::isalnum(c) != 0 || c == '_' || c >= 128; };

    int start = pos;
    int end = pos + 1;
    const auto ch = static_cast<unsigned char>(m_text[pos]);

    if (isSpace(ch)) {
        while (start > 0 && isSpace(static_cast<unsigned char>(m_text[start - 1]))) --start;
        while (end < static_cast<int>(m_text.size()) && isSpace(static_cast<unsigned char>(m_text[end]))) ++end;
    } else if (isWord(ch)) {
        while (start > 0 && isWord(static_cast<unsigned char>(m_text[start - 1]))) --start;
        while (end < static_cast<int>(m_text.size()) && isWord(static_cast<unsigned char>(m_text[end]))) ++end;
    } else {
        while (start > 0) {
            unsigned char c = static_cast<unsigned char>(m_text[start - 1]);
            if (isWord(c) || isSpace(c)) break;
            --start;
        }
        while (end < static_cast<int>(m_text.size())) {
            unsigned char c = static_cast<unsigned char>(m_text[end]);
            if (isWord(c) || isSpace(c)) break;
            ++end;
        }
    }

    const int mods = g_window.getKeyboardModifiers();
    if (mods & Fw::KeyboardShiftModifier) {
        int anchor = hasSelection() ? m_selectionReference : m_cursorPos;
        const int target = (pos >= anchor) ? end : start;
        setSelection(anchor, target);
        setCursorPos(target, false);
    } else {
        setSelection(start, end);
        setCursorPos(end, false);
        m_selectionReference = start;
    }

    return true;
}

void UITextEdit::onTextChange(const std::string_view text, const std::string_view oldText)
{
    UIWidget::onTextChange(text, oldText);
#ifdef ANDROID
    if (getProp(PropEditable) && isActive())
        g_androidManager.updateInputPreview(std::string(text));
#endif
}

void UITextEdit::onTextAreaUpdate(const Point& offset, const Size& visibleSize, const Size& totalSize)
{
    callLuaField("onTextAreaUpdate", offset, visibleSize, totalSize);
}

void UITextEdit::setPlaceholderFont(const std::string_view fontName)
{
    m_placeholderFont = g_fonts.getFont(fontName);
}