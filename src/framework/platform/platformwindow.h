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

#include <framework/core/inputevent.h>
#include <framework/core/timer.h>
#include <framework/global.h>
#include <framework/graphics/declarations.h>

 // Forward declaration
class Color;

//@bindsingleton g_window
class PlatformWindow
{
    enum
    {
        KEY_PRESS_REPEAT_INTERVAL = 30,
    };

    struct KeyInfo
    {
        ticks_t firstTicks = 0;
        ticks_t lastTicks = 0;
        bool state = false;
        uint8_t delay = KEY_PRESS_REPEAT_INTERVAL;
    };

    using OnResizeCallback = std::function<void(const Size&)>;
    using OnInputEventCallback = std::function<void(const InputEvent&)>;

public:
    virtual void init() = 0;
    virtual void terminate() = 0;

    virtual void move(const Point& pos) = 0;
    virtual void resize(const Size& size) = 0;
    virtual void show() = 0;
    virtual void hide() = 0;
    virtual void maximize() = 0;
    virtual void poll() = 0;
    virtual void swapBuffers() = 0;
    virtual void showMouse() = 0;
    virtual void hideMouse() = 0;
    virtual void displayFatalError(const std::string_view /*message*/) {}

    virtual int loadMouseCursor(const std::string& file, const Point& hotSpot);
    virtual void setMouseCursor(int cursorId) = 0;
    virtual void restoreMouseCursor() = 0;
    virtual void setSystemCursor(const std::string& cursorName) {}

    virtual void setTitle(std::string_view title) = 0;
    virtual void setMinimumSize(const Size& minimumSize) = 0;
    virtual void setFullscreen(bool fullscreen) = 0;
    virtual void setVerticalSync(bool enable) = 0;
    virtual void setIcon(const std::string& iconFile) = 0;
    virtual void setClipboardText(std::string_view text) = 0;

    // This method is intentionally left empty because title bar color customization
    // is only supported on Windows 10/11 via the DWM API. On other platforms,
    // or when not implemented in the derived class, this method does nothing.
    // Derived classes should override this method to provide platform-specific behavior.
    virtual void setTitleBarColor(const Color& /*color*/) {}

    // Convenience methods for setting title bar color
    // Usage examples:
    //   g_window.setTitleBarColor(255, 0, 0);           // Red (RGB 0-255)
    //   g_window.setTitleBarColor(1.0f, 0.0f, 0.0f);    // Red (float 0.0-1.0)
    //   g_window.setTitleBarColorRGB(0, 128, 255);       // Blue
    //   g_window.setTitleBarColor(Color::darkBlue);      // Using predefined color
    void setTitleBarColor(int r, int g, int b);
    void setTitleBarColor(float r, float g, float b);
    void setTitleBarColorRGB(uint8_t r, uint8_t g, uint8_t b);

    virtual Size getDisplaySize() = 0;
    virtual std::string getClipboardText() = 0;
    virtual std::string getPlatformType() = 0;

    int getDisplayWidth() { return getDisplaySize().width(); }
    int getDisplayHeight() { return getDisplaySize().height(); }
    float getDisplayDensity() { return m_displayDensity; }
    void setDisplayDensity(const float v) { 
        if (m_displayDensity == v) {
            return;
        }
        m_displayDensity = v; 
        onDisplayDensityChanged(v);
    }

    Size getUnmaximizedSize() { return m_unmaximizedSize; }
    Size getSize() { return m_size; }
    Size getMinimumSize() { return m_minimumSize; }
    int getWidth() { return m_size.width(); }
    int getHeight() { return m_size.height(); }
    Point getUnmaximizedPos() { return m_unmaximizedPos; }
    Point getPosition() { return m_position; }
    int getX() { return m_position.x; }
    int getY() { return m_position.y; }
    Point getMousePosition() { return m_inputEvent.mousePos; }
    int getKeyboardModifiers() { return m_inputEvent.keyboardModifiers; }

    bool isKeyPressed(const Fw::Key keyCode) { return m_keyInfo[keyCode].state; }
    bool isMouseButtonPressed(const Fw::MouseButton mouseButton)
    { if (mouseButton == Fw::MouseNoButton) return m_mouseButtonStates != 0; return (m_mouseButtonStates & (1u << mouseButton)) == (1u << mouseButton); }
    bool isVisible() { return m_visible; }
    bool isMaximized() { return m_maximized; }
    bool isFullscreen() { return m_fullscreen; }
    bool hasFocus() { return m_focused; }

    bool vsyncEnabled() const { return m_vsync; }

    void setOnClose(const std::function<void()>& onClose) { m_onClose = onClose; }
    void setOnResize(const OnResizeCallback& onResize) { m_onResize = onResize; }
    void setOnInputEvent(const OnInputEventCallback& onInputEvent) { m_onInputEvent = onInputEvent; }

    void addKeyListener(std::function<void(const InputEvent&)> listener) { m_keyListeners.push_back(listener); }

    void setKeyDelay(const Fw::Key key, const uint8_t delay) { if (key < Fw::KeyLast) m_keyInfo[key].delay = delay; }

protected:

    virtual int internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot) = 0;

    virtual void onDisplayDensityChanged(float /*newDensity*/) {}

    void updateUnmaximizedCoords();

    void processKeyDown(Fw::Key keyCode);
    void processKeyUp(Fw::Key keyCode);
    void releaseAllKeys();
    void fireKeysPress();

    stdext::map<int, Fw::Key> m_keyMap;
    std::array<KeyInfo, Fw::KeyLast> m_keyInfo = {};
    Timer m_keyPressTimer;

    Size m_size;
    Size m_minimumSize;
    Point m_position;
    Size m_unmaximizedSize;
    Point m_unmaximizedPos;
    InputEvent m_inputEvent;

    uint32_t m_mouseButtonStates{ 0 };

    bool m_created{ false };
    bool m_visible{ false };
    bool m_focused{ false };
    bool m_fullscreen{ false };
    bool m_maximized{ false };
    bool m_vsync{ false };
    float m_displayDensity{ DEFAULT_DISPLAY_DENSITY };

    std::function<void()> m_onClose;
    OnResizeCallback m_onResize;
    OnInputEventCallback m_onInputEvent;

    std::vector<std::function<void(const InputEvent&)>> m_keyListeners;
};

extern PlatformWindow& g_window;
