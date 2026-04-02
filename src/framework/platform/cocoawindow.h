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

#include "platformwindow.h"
#include <type_traits>

#ifdef __OBJC__
@class NSWindow;
@class NSOpenGLContext;
#else
typedef void* NSWindow;
typedef void* NSOpenGLContext;
#endif

class CocoaWindow : public PlatformWindow
{
public:
    CocoaWindow();
    virtual ~CocoaWindow();

    void init() override;
    void terminate() override;

    void move(const TPoint<int>& pos) override;
    void resize(const TSize<int>& size) override;
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
    void setMinimumSize(const TSize<int>& minimumSize) override;
    void setFullscreen(bool fullscreen) override;
    void setVerticalSync(bool enable) override;
    void setIcon(const std::string& iconFile) override;
    void setClipboardText(std::string_view text) override;

    TSize<int> getDisplaySize() override;
    std::string getClipboardText() override;
    std::string getPlatformType() override { return "Cocoa"; }

    void fireInputEvent(const InputEvent& event) { if(m_onInputEvent) m_onInputEvent(event); }
    InputEvent& getInputEvent() { return m_inputEvent; }

protected:
    int internalLoadMouseCursor(const ImagePtr& image, const TPoint<int>& hotSpot) override;

private:
    void* m_window;
    void* m_view;
    void* m_glContext;
    bool m_mouseVisible;
    std::vector<void*> m_cursors;
};
