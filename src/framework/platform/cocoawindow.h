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
    /**
     * Creates a new Cocoa window instance.
     * Initializes member variables and key mappings for macOS input handling.
     */
    CocoaWindow();

    /**
     * Destroys the Cocoa window and releases all associated resources.
     */
    ~CocoaWindow();

    /**
     * Initializes the window and OpenGL context.
     * Creates the native NSWindow, OpenGL view, and event handlers.
     */
    void init() override;

    /**
     * Terminates the window and releases all resources.
     * Destroys the NSWindow, OpenGL context, and event handlers.
     */
    void terminate() override;

    /**
     * Moves the window to the specified position.
     * @param pos The new top-left position of the window.
     */
    void move(const Point& pos) override;

    /**
     * Resizes the window to the specified size.
     * @param size The new size of the window.
     */
    void resize(const Size& size) override;

    /** Makes the window visible on screen. */
    void show() override;

    /** Hides the window from screen. */
    void hide() override;

    /** Maximizes the window to fill the screen. */
    void maximize() override;

    /**
     * Processes pending window events.
     * Pumps the event loop and dispatches pending events.
     */
    void poll() override;

    /** Swaps the OpenGL front and back buffers. */
    void swapBuffers() override;

    /** Shows the mouse cursor. */
    void showMouse() override;

    /** Hides the mouse cursor. */
    void hideMouse() override;

    /**
     * Sets the mouse cursor to a predefined style.
     * @param cursorId The cursor style identifier.
     */
    void setMouseCursor(int cursorId) override;

    /** Restores the default mouse cursor. */
    void restoreMouseCursor() override;

    /**
     * Sets the window title.
     * @param title The title string to display.
     */
    void setTitle(std::string_view title) override;

    /**
     * Sets the minimum window size.
     * @param minimumSize The minimum allowed window dimensions.
     */
    void setMinimumSize(const Size& minimumSize) override;

    /**
     * Toggles fullscreen mode.
     * @param fullscreen True to enter fullscreen, false to exit.
     */
    void setFullscreen(bool fullscreen) override;

    /**
     * Enables or disables vertical sync.
     * @param enable True to enable v-sync, false to disable.
     */
    void setVerticalSync(bool enable) override;

    /**
     * Sets the window icon from an image file.
     * @param file Path to the icon image file.
     */
    void setIcon(const std::string& file) override;

    /**
     * Copies text to the system clipboard.
     * @param text The text to copy to the clipboard.
     */
    void setClipboardText(std::string_view text) override;

    /**
     * Gets the primary display size.
     * @return The dimensions of the main display in pixels.
     */
    Size getDisplaySize() override;

    /**
     * Retrieves text from the system clipboard.
     * @return The clipboard text content, or empty string if unavailable.
     */
    std::string getClipboardText() override;

    /**
     * Returns a string identifying the platform type.
     * @return Platform identifier string.
     */
    std::string getPlatformType() override;

    /**
     * Handles key down events from the native event loop.
     * @param keyCode The macOS virtual key code.
     * @param modifiers The current modifier flags.
     * @param characters The character string for this key event.
     */
    void handleKeyDown(unsigned short keyCode, unsigned int modifiers, const std::string& characters);

    /**
     * Handles key up events from the native event loop.
     * @param keyCode The macOS virtual key code.
     * @param modifiers The current modifier flags.
     */
    void handleKeyUp(unsigned short keyCode, unsigned int modifiers);

    /** Handles changes to modifier key states. */
    void handleFlagsChanged(unsigned int modifiers);

    /**
     * Handles mouse button events.
     * @param button The mouse button identifier.
     * @param pressed True if button was pressed, false if released.
     * @param position The mouse position in window coordinates.
     */
    void handleMouseButton(Fw::MouseButton button, bool pressed, const Point& position);

    /**
     * Handles mouse movement events.
     * @param position The new mouse position in window coordinates.
     */
    void handleMouseMove(const Point& position);

    /**
     * Handles mouse scroll wheel events.
     * @param deltaX Horizontal scroll delta.
     * @param deltaY Vertical scroll delta.
     */
    void handleMouseScroll(int deltaX, int deltaY);

    /**
     * Handles window resize events.
     * @param width The new window width.
     * @param height The new window height.
     */
    void handleResize(int width, int height);

    /**
     * Handles window move events.
     * @param x The new x position.
     * @param y The new y position.
     */
    void handleMove(int x, int y);

    /** Handles window close requests. */
    void handleClose();

    /**
     * Handles focus change events.
     * @param focused True if window gained focus, false if lost.
     */
    void handleFocusChange(bool focused);

    /**
     * Handles text input events for character composition.
     * @param text The input text string.
     */
    void handleTextInput(const std::string& text);

    /**
     * Translates a macOS virtual key code to the framework key enum.
     * @param keyCode The macOS virtual key code.
     * @return The corresponding framework key identifier.
     */
    Fw::Key translateKeyCode(unsigned short keyCode);

    /**
     * Checks if a key is a special function key.
     * @param key The key to check.
     * @return True if the key is a special key (function keys, etc.).
     */
    bool isSpecialKey(Fw::Key key);

protected:
    /**
     * Loads a custom mouse cursor from an image.
     * @param image The image to create the cursor from.
     * @param hotSpot The hotspot point for the cursor.
     * @return The cursor ID on success, -1 on failure.
     */
    int internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot) override;

private:
    /**
     * Creates the native NSWindow and initializes all UI components.
     */
    void internalCreateWindow();

    /**
     * Creates the OpenGL context and configures it for rendering.
     */
    void internalCreateGLContext();

    /**
     * Initializes the key code mapping table for macOS key codes.
     */
    void internalInitKeyMap();

    /**
     * Updates the current modifier key state.
     * @param modifiers The new modifier flags.
     */
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
