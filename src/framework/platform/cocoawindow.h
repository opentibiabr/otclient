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

#pragma once

#include "platformwindow.h"

#include <array>

#ifdef __OBJC__
@class NSWindow;
@class NSOpenGLView;
@class NSOpenGLContext;
@class NSCursor;
@class OTOpenGLView;
@class OTWindowDelegate;
#else
typedef void NSWindow;
typedef void NSOpenGLView;
typedef void NSOpenGLContext;
typedef void NSCursor;
typedef void OTOpenGLView;
typedef void OTWindowDelegate;
#endif

class CocoaWindow : public PlatformWindow
{
public:
    CocoaWindow();
    ~CocoaWindow();

    void init() override;
    void terminate() override;

    void move(const Point& pos) override;
    void resize(const Size& size) override;
    void show() override;
    void hide() override;
    void maximize() override;
    void poll() override;
    void swapBuffers() override;
    void showMouse() override;
    void hideMouse() override;

    void setMouseCursor(int cursorId) override;
    void restoreMouseCursor() override;

    void setTitle(std::string_view title) override;
    void setMinimumSize(const Size& minimumSize) override;
    void setFullscreen(bool fullscreen) override;
    void setVerticalSync(bool enable) override;
    void setIcon(const std::string& file) override;
    void setClipboardText(std::string_view text) override;

    Size getDisplaySize() override;
    std::string getClipboardText() override;
    std::string getPlatformType() override;

    void handleKeyDown(unsigned short keyCode, unsigned int modifiers, const std::string& characters);
    void handleKeyUp(unsigned short keyCode, unsigned int modifiers);
    void handleFlagsChanged(unsigned int modifiers);
    void handleMouseButton(Fw::MouseButton button, bool pressed, const Point& position);
    void handleMouseMove(const Point& position);
    void handleMouseScroll(int deltaX, int deltaY);
    void handleResize(int width, int height);
    void handleMove(int x, int y);
    void handleClose();
    void handleFocusChange(bool focused);
    void handleTextInput(const std::string& text);

    Fw::Key translateKeyCode(unsigned short keyCode);
    bool isSpecialKey(Fw::Key key);

protected:
    int internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot) override;

private:
    void internalCreateWindow();
    void internalCreateGLContext();
    void internalInitKeyMap();
    void updateModifiers(unsigned int modifiers);

    NSWindow* m_window;
    OTOpenGLView* m_glView;
    OTWindowDelegate* m_delegate;
    NSOpenGLContext* m_glContext;

    std::vector<NSCursor*> m_cursors;
    NSCursor* m_currentCursor;
    NSCursor* m_defaultCursor;
    bool m_cursorHidden;
    bool m_cursorInWindow;

    unsigned int m_lastModifiers;
    std::array<bool, Fw::KeyLast> m_commandKeyDown{};
};
