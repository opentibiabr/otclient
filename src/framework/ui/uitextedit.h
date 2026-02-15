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

#include "uiwidget.h"

 // @bindclass
class UITextEdit final : public UIWidget
{
public:
    UITextEdit();

    void drawSelf(DrawPoolType drawPane) override;

private:
    void update(bool focusCursor = false, bool disableAreaUpdate = false);

public:
    void setCursorPos(int pos, bool focusCursor = true);
    void setSelection(int start, int end);
    void setCursorVisible(const bool enable) { setProp(PropCursorVisible, enable); }
    void setChangeCursorImage(const bool enable) { setProp(PropChangeCursorImage, enable); }
    void setTextHidden(bool hidden);
    void setValidCharacters(const std::string_view validCharacters) { m_validCharacters = validCharacters; }
    void setShiftNavigation(const bool enable) { setProp(PropShiftNavigation, enable); }
    void setMultiline(const bool enable) { setProp(PropMultiline, enable); }
    void setMaxLength(const uint32_t maxLength) { m_maxLength = maxLength; }
    void setTextVirtualOffset(const Point& offset);
    void setEditable(const bool editable) { setProp(PropEditable, editable); }
    void setSelectable(const bool selectable) { setProp(PropSelectable, selectable); }
    void setSelectionColor(const Color& color) { m_selectionColor = color; }
    void setSelectionBackgroundColor(const Color& color) { m_selectionBackgroundColor = color; }
    void setAutoScroll(const bool autoScroll) { setProp(PropAutoScroll, autoScroll); }
    void setPlaceholder(std::string placeholder) { m_placeholder = placeholder; }
    void setPlaceholderColor(const Color& color) { m_placeholderColor = color; }
    void setPlaceholderAlign(const Fw::AlignmentFlag align) { m_placeholderAlign = align; }
    void setPlaceholderFont(std::string_view fontName);

    void moveCursorHorizontally(bool right);
    void moveCursorVertically(bool up);
    void appendText(std::string_view text);
    void appendCharacter(char c);
    void removeCharacter(bool right);
    void blinkCursor();

    void deleteSelection();
    void del(bool right = false);
    void paste(std::string_view text);
    std::string copy();
    std::string cut();
    void selectAll() { setSelection(0, m_text.length()); }
    void clearSelection() { setSelection(0, 0); }

    void wrapText();
    std::string getDisplayedText() { return m_displayedText; }
    std::string getSelection();
    int getTextPos(const Point& pos);
    int getCursorPos() { return m_cursorPos; }
    Point getTextVirtualOffset() { return m_textVirtualOffset; }
    Size getTextVirtualSize() { return m_textVirtualSize; }
    Size getTextTotalSize() { return m_textTotalSize; }
    uint32_t getMaxLength() { return m_maxLength; }
    int getSelectionStart() { return m_selectionStart; }
    int getSelectionEnd() { return m_selectionEnd; }
    Color getSelectionColor() { return m_selectionColor; }
    Color getSelectionBackgroundColor() { return m_selectionBackgroundColor; }
    bool hasSelection() { return m_selectionEnd - m_selectionStart > 0; }
    bool isCursorVisible() { return getProp(PropCursorVisible); }
    bool isChangingCursorImage() { return getProp(PropChangeCursorImage); }
    bool isTextHidden() { return getProp(PropTextHidden); }
    bool isShiftNavigation() { return getProp(PropShiftNavigation); }
    bool isMultiline() { return getProp(PropMultiline); }
    bool isEditable() { return getProp(PropEditable); }
    bool isSelectable() { return getProp(PropSelectable); }
    bool isAutoScrolling() { return getProp(PropAutoScroll); }

protected:
    void updateText() override;
    bool isTextEdit() override { return true; }

    void onHoverChange(bool hovered) override;
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;
    void onGeometryChange(const Rect& oldRect, const Rect& newRect) override;
    void onFocusChange(bool focused, Fw::FocusReason reason) override;
    bool onKeyText(std::string_view keyText) override;
    bool onKeyPress(uint8_t keyCode, int keyboardModifiers, int autoRepeatTicks) override;
    bool onMousePress(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseRelease(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseMove(const Point& mousePos, const Point& mouseMoved) override;
    bool onDoubleClick(const Point& mousePos) override;
    void onTextChange(std::string_view text, std::string_view oldText) override;
    virtual void onTextAreaUpdate(const Point& vitualOffset, const Size& visibleSize, const Size& totalSize);

private:
    enum Props
    {
        PropTextHidden = 1 << 0,
        PropShiftNavigation = 1 << 1,
        PropMultiline = 1 << 2,
        PropCursorInRange = 1 << 3,
        PropCursorVisible = 1 << 4,
        PropEditable = 1 << 5,
        PropChangeCursorImage = 1 << 6,
        PropUpdatesEnabled = 1 << 7,
        PropAutoScroll = 1 << 8,
        PropSelectable = 1 << 9,
        PropGlyphsMustRecache = 1 << 10,
    };

    void updateDisplayedText();
    void disableUpdates() { setProp(PropUpdatesEnabled, false); }
    void enableUpdates() { setProp(PropUpdatesEnabled, true); }
    void recacheGlyphs() { setProp(PropGlyphsMustRecache, true); }
    void setCursorPosEx(int pos, bool preservePreferredX, bool focusCursor);

    std::string m_validCharacters;
    uint32_t m_maxLength{ 0 };

    Rect m_drawArea;
    Point m_textVirtualOffset;
    Size m_textVirtualSize;
    Size m_textTotalSize;
    ticks_t m_cursorTicks;

    uint32_t m_props{ 0 };
    void setProp(const Props prop, const bool v) { if (v) m_props |= prop; else m_props &= ~prop; }
    bool getProp(const Props prop) const { return m_props & prop; };

    int m_selectionReference{ 0 };
    int m_selectionStart{ 0 };
    int m_selectionEnd{ 0 };
    int m_cursorPos{ 0 };
    int m_cursorPreferredX{ -1 };

    std::vector<int> m_srcToVis;
    std::vector<int> m_visToSrc;;

    Color m_selectionColor{ Color::white };
    Color m_selectionBackgroundColor{ Color::black };

    std::vector<std::pair<Rect, Rect>> m_glyphsCoords;

    std::vector<std::pair<Rect, Rect>> m_glyphsSelectRectCache;
    std::vector<Rect> m_glyphsSelectBgRectCache;

    std::string m_displayedText;

    std::string m_placeholder;
    Color m_placeholderColor;
    Fw::AlignmentFlag m_placeholderAlign;
    BitmapFontPtr m_placeholderFont;
};
