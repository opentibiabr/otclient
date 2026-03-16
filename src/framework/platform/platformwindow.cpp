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

#include "platformwindow.h"

#include "framework/core/clock.h"
#include "framework/graphics/image.h"

#ifdef WIN32
#include "win32window.h"
WIN32Window window;
#elif defined ANDROID
#include "androidwindow.h"
AndroidWindow window;
#elif defined __EMSCRIPTEN__
#include "browserwindow.h"
BrowserWindow window;
#else
#include "x11window.h"
#include <framework/core/clock.h>
X11Window window;
#endif

PlatformWindow& g_window = window;

int PlatformWindow::loadMouseCursor(const std::string& file, const Point& hotSpot)
{
    const auto& image = Image::load(file);
    if (!image) {
        g_logger.traceError("unable to load cursor image file {}", file);
        return -1;
    }

    if (image->getBpp() != 4) {
        g_logger.error("the cursor image must have 4 channels");
        return -1;
    }

    return internalLoadMouseCursor(image, hotSpot);
}

void PlatformWindow::setTitleBarColor(int r, int g, int b)
{
    setTitleBarColor(Color(r, g, b));
}

void PlatformWindow::setTitleBarColor(float r, float g, float b)
{
    setTitleBarColor(Color(r, g, b));
}

void PlatformWindow::setTitleBarColorRGB(uint8_t r, uint8_t g, uint8_t b)
{
    setTitleBarColor(Color(r, g, b));
}

void PlatformWindow::updateUnmaximizedCoords()
{
    if (!isMaximized() && !isFullscreen()) {
        m_unmaximizedPos = m_position;
        m_unmaximizedSize = m_size;
    }
}

void PlatformWindow::processKeyDown(Fw::Key keyCode)
{
    if (keyCode == Fw::KeyUnknown)
        return;

    if (keyCode == Fw::KeyCtrl) {
        m_inputEvent.keyboardModifiers |= Fw::KeyboardCtrlModifier;
        return;
#if defined(__APPLE__)
    } else if (keyCode == Fw::KeyMeta) {
        m_inputEvent.keyboardModifiers |= Fw::KeyboardAltModifier;
        return;
#else
    }
    if (keyCode == Fw::KeyAlt) {
        m_inputEvent.keyboardModifiers |= Fw::KeyboardAltModifier;
        return;
#endif
    }
    if (keyCode == Fw::KeyShift) {
        m_inputEvent.keyboardModifiers |= Fw::KeyboardShiftModifier;
        return;
    }

    if (m_keyInfo[keyCode].state)
        return;

    m_keyInfo[keyCode].state = true;
    m_keyInfo[keyCode].lastTicks = -1;

    m_inputEvent.reset(Fw::KeyDownInputEvent);
    m_inputEvent.type = Fw::KeyDownInputEvent;
    m_inputEvent.keyCode = keyCode;

    if (m_onInputEvent) {
        m_onInputEvent(m_inputEvent);

        m_inputEvent.reset(Fw::KeyPressInputEvent);
        m_inputEvent.keyCode = keyCode;
        m_keyInfo[keyCode].lastTicks = g_clock.millis();
        m_keyInfo[keyCode].firstTicks = g_clock.millis();
        m_onInputEvent(m_inputEvent);
    }
}

void PlatformWindow::processKeyUp(Fw::Key keyCode)
{
    if (keyCode == Fw::KeyUnknown)
        return;

    if (keyCode == Fw::KeyCtrl) {
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardCtrlModifier;
        return;
#if defined(__APPLE__)
    } else if (keyCode == Fw::KeyMeta) {
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardAltModifier;
        return;
#else
    }
    if (keyCode == Fw::KeyAlt) {
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardAltModifier;
        return;
#endif
    }
    if (keyCode == Fw::KeyShift) {
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardShiftModifier;
        return;
    }
    if (keyCode == Fw::KeyNumLock) {
        for (uint8_t k = Fw::KeyNumpad0; k <= Fw::KeyNumpad9; ++k) {
            if (m_keyInfo[static_cast<Fw::Key>(k)].state)
                processKeyUp(static_cast<Fw::Key>(k));
        }
    }

    if (!m_keyInfo[keyCode].state)
        return;

    m_keyInfo[keyCode].state = false;

    if (m_onInputEvent) {
        m_inputEvent.reset(Fw::KeyUpInputEvent);
        m_inputEvent.keyCode = keyCode;
        m_onInputEvent(m_inputEvent);
    }
}

void PlatformWindow::releaseAllKeys()
{
    for (size_t keyCode = 0; keyCode < Fw::KeyLast; ++keyCode) {
        const bool pressed = m_keyInfo[keyCode].state;
        if (!pressed)
            continue;

        processKeyUp(static_cast<Fw::Key>(keyCode));
    }

    m_inputEvent.keyboardModifiers = 0;
    m_mouseButtonStates = 0;
}

void PlatformWindow::fireKeysPress()
{
    // avoid massive checks
    if (m_keyPressTimer.ticksElapsed() < 2)
        return;

    m_keyPressTimer.restart();

    const auto now = g_clock.millis();
    for (size_t keyCode = 0; keyCode < Fw::KeyLast; ++keyCode) {
        auto& keyInfo = m_keyInfo[keyCode];

        const bool pressed = keyInfo.state;

        if (!pressed)
            continue;

        const ticks_t lastPressTicks = keyInfo.lastTicks;
        const ticks_t firstKeyPress = keyInfo.firstTicks;
        if (now - lastPressTicks >= keyInfo.delay) {
            if (m_onInputEvent) {
                m_inputEvent.reset(Fw::KeyPressInputEvent);
                m_inputEvent.keyCode = static_cast<Fw::Key>(keyCode);
                m_inputEvent.autoRepeatTicks = now - firstKeyPress;
                m_onInputEvent(m_inputEvent);
            }
            keyInfo.lastTicks = now;
        }
    }
}