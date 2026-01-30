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
#include "framework/core/timer.h"

#ifdef OPENGL_ES
#include <EGL/egl.h>
#endif

struct WindowProcProxy;

class WIN32Window : public PlatformWindow
{
    void internalCreateWindow();
    void internalCreateGLContext();
    void internalDestroyGLContext();
    void internalRestoreGLContext() const;

    void* getExtensionProcAddress(const char* ext);
    bool isExtensionSupported(const char* ext);

    LRESULT windowProc(HWND hWnd, uint32_t uMsg, WPARAM wParam, LPARAM lParam);
    friend struct WindowProcProxy;

    Fw::Key retranslateVirtualKey(WPARAM wParam, LPARAM lParam);

public:
    WIN32Window();

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
    void displayFatalError(std::string_view message) override;

    void setMouseCursor(int cursorId) override;
    void restoreMouseCursor() override;

    void setTitle(std::string_view title) override;
    void setMinimumSize(const Size& minimumSize) override;
    void setFullscreen(bool fullscreen) override;
    void setVerticalSync(bool enable) override;
    void setIcon(const std::string& file) override;
    void setClipboardText(std::string_view text) override;
    void setTitleBarColor(const Color& color) override;

    Size getDisplaySize() override;
    std::string getClipboardText() override;
    std::string getPlatformType() override;

protected:
    int internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot) override;

private:
    Rect getClientRect() const;
    Rect getWindowRect();
    Rect adjustWindowRect(const Rect& rect) const;
    void updateCursor();

    struct CursorState {
         std::vector<HCURSOR> cursors;
         std::vector<int> delays;
    };
    std::vector<CursorState> m_cursors;

    HWND m_window;
    HINSTANCE m_instance;
    HDC m_deviceContext;
    HCURSOR m_cursor;
    HCURSOR m_defaultCursor;
    bool m_hidden;

    int m_currentCursorId = -1;
    int m_cursorFrame = 0;
    Timer m_cursorTimer;

#ifdef OPENGL_ES
    EGLConfig m_eglConfig;
    EGLContext m_eglContext;
    EGLDisplay m_eglDisplay;
    EGLSurface m_eglSurface;
#else
    HGLRC m_wglContext;
#endif
};
