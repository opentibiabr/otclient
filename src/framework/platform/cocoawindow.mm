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

#ifdef __APPLE__

#define GLEW_STATIC
#define GLEW_NO_GLU
#include <GL/glew.h>

#define Point MacPoint
#define Size MacSize
#define Rect MacRect

#define GL_SILENCE_DEPRECATION
#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <QuartzCore/CVDisplayLink.h>

#undef Point
#undef Size
#undef Rect

#include "cocoawindow.h"
#include "cocoaview.h"
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/image.h>

CocoaWindow::CocoaWindow()
{
    m_window = nil;
    m_glView = nil;
    m_delegate = nil;
    m_glContext = nil;
    m_currentCursor = nil;
    m_defaultCursor = nil;
    m_cursorHidden = false;
    m_cursorInWindow = false;
    m_lastModifiers = 0;
    m_minimumSize = Size(600, 480);
    m_size = Size(600, 480);

    internalInitKeyMap();
}

CocoaWindow::~CocoaWindow()
{
    terminate();
}

void CocoaWindow::internalInitKeyMap()
{
    m_keyMap[kVK_Escape] = Fw::KeyEscape;
    m_keyMap[kVK_Tab] = Fw::KeyTab;
    m_keyMap[kVK_Return] = Fw::KeyEnter;
    m_keyMap[kVK_Delete] = Fw::KeyBackspace;
    m_keyMap[kVK_Space] = Fw::KeySpace;

    m_keyMap[kVK_PageUp] = Fw::KeyPageUp;
    m_keyMap[kVK_PageDown] = Fw::KeyPageDown;
    m_keyMap[kVK_Home] = Fw::KeyHome;
    m_keyMap[kVK_End] = Fw::KeyEnd;
    m_keyMap[kVK_ForwardDelete] = Fw::KeyDelete;

    m_keyMap[kVK_UpArrow] = Fw::KeyUp;
    m_keyMap[kVK_DownArrow] = Fw::KeyDown;
    m_keyMap[kVK_LeftArrow] = Fw::KeyLeft;
    m_keyMap[kVK_RightArrow] = Fw::KeyRight;

    m_keyMap[kVK_CapsLock] = Fw::KeyCapsLock;

    m_keyMap[kVK_Control] = Fw::KeyCtrl;
    m_keyMap[kVK_RightControl] = Fw::KeyCtrl;
    m_keyMap[kVK_Shift] = Fw::KeyShift;
    m_keyMap[kVK_RightShift] = Fw::KeyShift;
    m_keyMap[kVK_Option] = Fw::KeyAlt;
    m_keyMap[kVK_RightOption] = Fw::KeyAlt;
    m_keyMap[kVK_Command] = Fw::KeyMeta;
    m_keyMap[kVK_RightCommand] = Fw::KeyMeta;

    m_keyMap[kVK_ANSI_A] = Fw::KeyA;
    m_keyMap[kVK_ANSI_B] = Fw::KeyB;
    m_keyMap[kVK_ANSI_C] = Fw::KeyC;
    m_keyMap[kVK_ANSI_D] = Fw::KeyD;
    m_keyMap[kVK_ANSI_E] = Fw::KeyE;
    m_keyMap[kVK_ANSI_F] = Fw::KeyF;
    m_keyMap[kVK_ANSI_G] = Fw::KeyG;
    m_keyMap[kVK_ANSI_H] = Fw::KeyH;
    m_keyMap[kVK_ANSI_I] = Fw::KeyI;
    m_keyMap[kVK_ANSI_J] = Fw::KeyJ;
    m_keyMap[kVK_ANSI_K] = Fw::KeyK;
    m_keyMap[kVK_ANSI_L] = Fw::KeyL;
    m_keyMap[kVK_ANSI_M] = Fw::KeyM;
    m_keyMap[kVK_ANSI_N] = Fw::KeyN;
    m_keyMap[kVK_ANSI_O] = Fw::KeyO;
    m_keyMap[kVK_ANSI_P] = Fw::KeyP;
    m_keyMap[kVK_ANSI_Q] = Fw::KeyQ;
    m_keyMap[kVK_ANSI_R] = Fw::KeyR;
    m_keyMap[kVK_ANSI_S] = Fw::KeyS;
    m_keyMap[kVK_ANSI_T] = Fw::KeyT;
    m_keyMap[kVK_ANSI_U] = Fw::KeyU;
    m_keyMap[kVK_ANSI_V] = Fw::KeyV;
    m_keyMap[kVK_ANSI_W] = Fw::KeyW;
    m_keyMap[kVK_ANSI_X] = Fw::KeyX;
    m_keyMap[kVK_ANSI_Y] = Fw::KeyY;
    m_keyMap[kVK_ANSI_Z] = Fw::KeyZ;

    m_keyMap[kVK_ANSI_0] = Fw::Key0;
    m_keyMap[kVK_ANSI_1] = Fw::Key1;
    m_keyMap[kVK_ANSI_2] = Fw::Key2;
    m_keyMap[kVK_ANSI_3] = Fw::Key3;
    m_keyMap[kVK_ANSI_4] = Fw::Key4;
    m_keyMap[kVK_ANSI_5] = Fw::Key5;
    m_keyMap[kVK_ANSI_6] = Fw::Key6;
    m_keyMap[kVK_ANSI_7] = Fw::Key7;
    m_keyMap[kVK_ANSI_8] = Fw::Key8;
    m_keyMap[kVK_ANSI_9] = Fw::Key9;

    m_keyMap[kVK_ANSI_Minus] = Fw::KeyMinus;
    m_keyMap[kVK_ANSI_Equal] = Fw::KeyEqual;
    m_keyMap[kVK_ANSI_LeftBracket] = Fw::KeyLeftBracket;
    m_keyMap[kVK_ANSI_RightBracket] = Fw::KeyRightBracket;
    m_keyMap[kVK_ANSI_Backslash] = Fw::KeyBackslash;
    m_keyMap[kVK_ANSI_Semicolon] = Fw::KeySemicolon;
    m_keyMap[kVK_ANSI_Quote] = Fw::KeyApostrophe;
    m_keyMap[kVK_ANSI_Comma] = Fw::KeyComma;
    m_keyMap[kVK_ANSI_Period] = Fw::KeyPeriod;
    m_keyMap[kVK_ANSI_Slash] = Fw::KeySlash;
    m_keyMap[kVK_ANSI_Grave] = Fw::KeyGrave;

    m_keyMap[kVK_F1] = Fw::KeyF1;
    m_keyMap[kVK_F2] = Fw::KeyF2;
    m_keyMap[kVK_F3] = Fw::KeyF3;
    m_keyMap[kVK_F4] = Fw::KeyF4;
    m_keyMap[kVK_F5] = Fw::KeyF5;
    m_keyMap[kVK_F6] = Fw::KeyF6;
    m_keyMap[kVK_F7] = Fw::KeyF7;
    m_keyMap[kVK_F8] = Fw::KeyF8;
    m_keyMap[kVK_F9] = Fw::KeyF9;
    m_keyMap[kVK_F10] = Fw::KeyF10;
    m_keyMap[kVK_F11] = Fw::KeyF11;
    m_keyMap[kVK_F12] = Fw::KeyF12;

    m_keyMap[kVK_ANSI_Keypad0] = Fw::KeyNumpad0;
    m_keyMap[kVK_ANSI_Keypad1] = Fw::KeyNumpad1;
    m_keyMap[kVK_ANSI_Keypad2] = Fw::KeyNumpad2;
    m_keyMap[kVK_ANSI_Keypad3] = Fw::KeyNumpad3;
    m_keyMap[kVK_ANSI_Keypad4] = Fw::KeyNumpad4;
    m_keyMap[kVK_ANSI_Keypad5] = Fw::KeyNumpad5;
    m_keyMap[kVK_ANSI_Keypad6] = Fw::KeyNumpad6;
    m_keyMap[kVK_ANSI_Keypad7] = Fw::KeyNumpad7;
    m_keyMap[kVK_ANSI_Keypad8] = Fw::KeyNumpad8;
    m_keyMap[kVK_ANSI_Keypad9] = Fw::KeyNumpad9;
    m_keyMap[kVK_ANSI_KeypadEnter] = Fw::KeyEnter;
}

Fw::Key CocoaWindow::translateKeyCode(unsigned short keyCode)
{
    auto it = m_keyMap.find(keyCode);
    if (it != m_keyMap.end())
        return it->second;
    return Fw::KeyUnknown;
}

bool CocoaWindow::isSpecialKey(Fw::Key key)
{
    return key == Fw::KeyTab || key == Fw::KeyEnter || key == Fw::KeyEscape ||
           key == Fw::KeyBackspace || key == Fw::KeyDelete ||
           key == Fw::KeyUp || key == Fw::KeyDown || key == Fw::KeyLeft || key == Fw::KeyRight ||
           key == Fw::KeyHome || key == Fw::KeyEnd || key == Fw::KeyPageUp || key == Fw::KeyPageDown ||
           (key >= Fw::KeyF1 && key <= Fw::KeyF12);
}

void CocoaWindow::init()
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];

        internalCreateWindow();
        internalCreateGLContext();

        glewExperimental = GL_TRUE;

        m_defaultCursor = [NSCursor arrowCursor];
        m_currentCursor = m_defaultCursor;

        m_created = true;
    }
}

void CocoaWindow::internalCreateWindow()
{
    NSRect frame = NSMakeRect(0, 0, m_size.width(), m_size.height());
    NSUInteger styleMask = NSWindowStyleMaskTitled |
                           NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable |
                           NSWindowStyleMaskResizable;

    m_window = [[NSWindow alloc] initWithContentRect:frame
                                           styleMask:styleMask
                                             backing:NSBackingStoreBuffered
                                               defer:NO];

    [m_window setTitle:@"OTClient"];
    [m_window center];
    [m_window setMinSize:NSMakeSize(m_minimumSize.width(), m_minimumSize.height())];

    m_delegate = [[OTWindowDelegate alloc] init];
    [m_delegate setPlatformWindow:this];
    [m_window setDelegate:m_delegate];

    NSRect contentRect = [[m_window contentView] frame];
    m_size = Size(static_cast<int>(contentRect.size.width),
                  static_cast<int>(contentRect.size.height));

    NSRect windowFrame = [m_window frame];
    NSScreen* screen = [m_window screen];
    if (screen) {
        NSRect screenFrame = [screen frame];
        m_position = Point(static_cast<int>(windowFrame.origin.x),
                           static_cast<int>(screenFrame.size.height - windowFrame.origin.y - windowFrame.size.height));
    }
}

void CocoaWindow::internalCreateGLContext()
{
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        0
    };

    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    if (!pixelFormat) {
        g_logger.fatal("Failed to create OpenGL pixel format");
        return;
    }

    int width = m_size.width();
    int height = m_size.height();
    NSRect viewFrame = NSMakeRect(0, 0, width, height);

    g_logger.info("Creating GL view with frame: {}x{}", width, height);

    m_glView = [[OTOpenGLView alloc] initWithFrame:viewFrame pixelFormat:pixelFormat];
    [m_glView setPlatformWindow:this];
    [m_glView setWantsBestResolutionOpenGLSurface:NO];
    [m_glView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    m_glContext = [m_glView openGLContext];
    [m_glContext makeCurrentContext];

    [m_window setContentSize:NSMakeSize(width, height)];
    [m_window setContentView:m_glView];
    [m_window makeFirstResponder:m_glView];

    GLint swapInterval = 1;
    [m_glContext setValues:&swapInterval forParameter:NSOpenGLContextParameterSwapInterval];
    m_vsync = true;

    NSRect newFrame = [[m_window contentView] frame];
    g_logger.info("GL context created, content view frame: {}x{}", (int)newFrame.size.width, (int)newFrame.size.height);
}

void CocoaWindow::terminate()
{
    @autoreleasepool {
        if (m_glContext) {
            [NSOpenGLContext clearCurrentContext];
            m_glContext = nil;
        }

        if (m_glView) {
            [m_glView setPlatformWindow:nullptr];
            m_glView = nil;
        }

        if (m_delegate) {
            [m_delegate setPlatformWindow:nullptr];
            m_delegate = nil;
        }

        if (m_window) {
            [m_window close];
            m_window = nil;
        }

        m_cursors.clear();
        m_created = false;
    }
}

void CocoaWindow::move(const Point& pos)
{
    @autoreleasepool {
        if (!m_window) return;

        NSScreen* screen = [m_window screen];
        if (!screen) screen = [NSScreen mainScreen];
        NSRect screenFrame = [screen frame];

        NSRect frame = [m_window frame];
        frame.origin.x = pos.x;
        frame.origin.y = screenFrame.size.height - pos.y - frame.size.height;

        [m_window setFrame:frame display:YES];
    }
}

void CocoaWindow::resize(const Size& size)
{
    @autoreleasepool {
        if (!m_window) return;

        NSRect frame = [m_window frame];
        NSRect contentRect = [m_window contentRectForFrameRect:frame];
        CGFloat titleBarHeight = frame.size.height - contentRect.size.height;

        frame.size.width = size.width();
        frame.size.height = size.height() + titleBarHeight;

        [m_window setFrame:frame display:YES];
    }
}

void CocoaWindow::show()
{
    @autoreleasepool {
        if (!m_window) {
            g_logger.info("CocoaWindow::show() - m_window is nil!");
            return;
        }

        g_logger.info("CocoaWindow::show() - making window visible");

        [m_window setIsVisible:YES];
        [m_window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        [m_glView setNeedsDisplay:YES];
        [NSApp updateWindows];

        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                          untilDate:[NSDate distantPast]
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES])) {
            [NSApp sendEvent:event];
        }

        m_visible = true;
        g_logger.info("CocoaWindow::show() - done, visible={}", m_visible);
    }
}

void CocoaWindow::hide()
{
    @autoreleasepool {
        if (!m_window) return;
        [m_window orderOut:nil];
        m_visible = false;
    }
}

void CocoaWindow::maximize()
{
    @autoreleasepool {
        if (!m_window) return;

        if (!m_maximized) {
            updateUnmaximizedCoords();
            [m_window zoom:nil];
            m_maximized = true;
        }
    }
}

void CocoaWindow::poll()
{
    @autoreleasepool {
        fireKeysPress();

        NSEvent* event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                          untilDate:nil
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES])) {
            [NSApp sendEvent:event];
        }
    }
}

void CocoaWindow::swapBuffers()
{
    @autoreleasepool {
        if (m_glContext) {
            [m_glContext flushBuffer];
        }
    }
}

void CocoaWindow::showMouse()
{
    @autoreleasepool {
        if (m_cursorHidden) {
            [NSCursor unhide];
            m_cursorHidden = false;
        }
    }
}

void CocoaWindow::hideMouse()
{
    @autoreleasepool {
        if (!m_cursorHidden) {
            [NSCursor hide];
            m_cursorHidden = true;
        }
    }
}

void CocoaWindow::setMouseCursor(int cursorId)
{
    @autoreleasepool {
        if (cursorId >= 0 && cursorId < static_cast<int>(m_cursors.size())) {
            m_currentCursor = m_cursors[cursorId];
            [m_currentCursor set];
        }
    }
}

void CocoaWindow::restoreMouseCursor()
{
    @autoreleasepool {
        m_currentCursor = m_defaultCursor;
        [m_currentCursor set];
    }
}

void CocoaWindow::setTitle(std::string_view title)
{
    @autoreleasepool {
        if (!m_window) return;
        NSString* nsTitle = [[NSString alloc] initWithBytes:title.data()
                                                     length:title.size()
                                                   encoding:NSUTF8StringEncoding];
        [m_window setTitle:nsTitle];
    }
}

void CocoaWindow::setMinimumSize(const Size& minimumSize)
{
    @autoreleasepool {
        m_minimumSize = minimumSize;
        if (m_window) {
            [m_window setMinSize:NSMakeSize(minimumSize.width(), minimumSize.height())];
        }
    }
}

void CocoaWindow::setFullscreen(bool fullscreen)
{
    @autoreleasepool {
        if (!m_window) return;

        if (fullscreen != m_fullscreen) {
            if (fullscreen) {
                updateUnmaximizedCoords();
            }
            [m_window toggleFullScreen:nil];
            m_fullscreen = fullscreen;
        }
    }
}

void CocoaWindow::setVerticalSync(bool enable)
{
    @autoreleasepool {
        if (m_glContext) {
            GLint swapInterval = enable ? 1 : 0;
            [m_glContext setValues:&swapInterval forParameter:NSOpenGLContextParameterSwapInterval];
            m_vsync = enable;
        }
    }
}

void CocoaWindow::setIcon(const std::string& file)
{
    @autoreleasepool {
        auto image = Image::load(file);
        if (!image) {
            g_logger.traceError("unable to load icon {}", file);
            return;
        }

        int width = image->getWidth();
        int height = image->getHeight();
        const uint8_t* pixels = image->getPixelData();

        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:nullptr
                          pixelsWide:width
                          pixelsHigh:height
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSDeviceRGBColorSpace
                         bytesPerRow:width * 4
                        bitsPerPixel:32];

        memcpy([rep bitmapData], pixels, width * height * 4);

        CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
        NSSize sizeInPoints = NSMakeSize(width / scale, height / scale);
        [rep setSize:sizeInPoints];

        NSImage* nsImage = [[NSImage alloc] initWithSize:sizeInPoints];
        [nsImage addRepresentation:rep];
        [NSApp setApplicationIconImage:nsImage];
    }
}

void CocoaWindow::setClipboardText(std::string_view text)
{
    @autoreleasepool {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSString* nsText = [[NSString alloc] initWithBytes:text.data()
                                                    length:text.size()
                                                  encoding:NSUTF8StringEncoding];
        [pasteboard setString:nsText forType:NSPasteboardTypeString];
    }
}

Size CocoaWindow::getDisplaySize()
{
    @autoreleasepool {
        NSScreen* screen = [NSScreen mainScreen];
        NSRect frame = [screen frame];
        return Size(static_cast<int>(frame.size.width), static_cast<int>(frame.size.height));
    }
}

std::string CocoaWindow::getClipboardText()
{
    @autoreleasepool {
        NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
        NSString* text = [pasteboard stringForType:NSPasteboardTypeString];
        if (text) {
            return std::string([text UTF8String]);
        }
        return {};
    }
}

std::string CocoaWindow::getPlatformType()
{
    return "COCOA-MACOS";
}

int CocoaWindow::internalLoadMouseCursor(const ImagePtr& image, const Point& hotSpot)
{
    @autoreleasepool {
        int width = image->getWidth();
        int height = image->getHeight();
        const uint8_t* pixels = image->getPixelData();

        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:nullptr
                          pixelsWide:width
                          pixelsHigh:height
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSDeviceRGBColorSpace
                         bytesPerRow:width * 4
                        bitsPerPixel:32];

        memcpy([rep bitmapData], pixels, width * height * 4);

        NSImage* nsImage = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
        [nsImage addRepresentation:rep];

        NSCursor* cursor = [[NSCursor alloc] initWithImage:nsImage
                                                   hotSpot:NSMakePoint(hotSpot.x, hotSpot.y)];

        m_cursors.push_back(cursor);
        return static_cast<int>(m_cursors.size()) - 1;
    }
}

void CocoaWindow::handleKeyDown(unsigned short keyCode, unsigned int modifiers, const std::string& characters)
{
    (void)characters;
    updateModifiers(modifiers);
    Fw::Key key = translateKeyCode(keyCode);
    if (key >= Fw::KeyLast)
        return;

    const bool cmdPressed = (modifiers & NSEventModifierFlagCommand) != 0;
    const auto keyIndex = static_cast<size_t>(key);
    if (cmdPressed && key != Fw::KeyMeta && key != Fw::KeyCtrl && key != Fw::KeyAlt && key != Fw::KeyShift) {
        m_commandKeyDown[keyIndex] = true;
    }
    processKeyDown(key);
}

void CocoaWindow::handleKeyUp(unsigned short keyCode, unsigned int modifiers)
{
    updateModifiers(modifiers);
    Fw::Key key = translateKeyCode(keyCode);
    if (key < Fw::KeyLast) {
        const auto keyIndex = static_cast<size_t>(key);
        m_commandKeyDown[keyIndex] = false;
    }
    processKeyUp(key);
}

void CocoaWindow::handleFlagsChanged(unsigned int modifiers)
{
    updateModifiers(modifiers);

    bool cmdPressed = (modifiers & NSEventModifierFlagCommand) != 0;
    bool cmdWasPressed = (m_lastModifiers & NSEventModifierFlagCommand) != 0;
    if (cmdPressed != cmdWasPressed) {
        if (cmdPressed)
            processKeyDown(Fw::KeyMeta);
        else
            processKeyUp(Fw::KeyMeta);
        if (!cmdPressed) {
            for (size_t keyIndex = 0; keyIndex < m_commandKeyDown.size(); ++keyIndex) {
                if (!m_commandKeyDown[keyIndex])
                    continue;
                m_commandKeyDown[keyIndex] = false;
                processKeyUp(static_cast<Fw::Key>(keyIndex));
            }
        }
    }

    bool optPressed = (modifiers & NSEventModifierFlagOption) != 0;
    bool optWasPressed = (m_lastModifiers & NSEventModifierFlagOption) != 0;
    if (optPressed != optWasPressed) {
        if (optPressed)
            processKeyDown(Fw::KeyAlt);
        else
            processKeyUp(Fw::KeyAlt);
    }

    bool ctrlPressed = (modifiers & NSEventModifierFlagControl) != 0;
    bool ctrlWasPressed = (m_lastModifiers & NSEventModifierFlagControl) != 0;
    if (ctrlPressed != ctrlWasPressed) {
        if (ctrlPressed)
            processKeyDown(Fw::KeyCtrl);
        else
            processKeyUp(Fw::KeyCtrl);
    }

    bool shiftPressed = (modifiers & NSEventModifierFlagShift) != 0;
    bool shiftWasPressed = (m_lastModifiers & NSEventModifierFlagShift) != 0;
    if (shiftPressed != shiftWasPressed) {
        if (shiftPressed)
            processKeyDown(Fw::KeyShift);
        else
            processKeyUp(Fw::KeyShift);
    }

    m_lastModifiers = modifiers;
}

void CocoaWindow::updateModifiers(unsigned int modifiers)
{
    if (modifiers & NSEventModifierFlagCommand)
        m_inputEvent.keyboardModifiers |= Fw::KeyboardPrimaryModifier;
    else
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardPrimaryModifier;

    if (modifiers & NSEventModifierFlagOption)
        m_inputEvent.keyboardModifiers |= Fw::KeyboardAltModifier;
    else
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardAltModifier;

    if (modifiers & NSEventModifierFlagControl)
        m_inputEvent.keyboardModifiers |= Fw::KeyboardCtrlModifier;
    else
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardCtrlModifier;

    if (modifiers & NSEventModifierFlagShift)
        m_inputEvent.keyboardModifiers |= Fw::KeyboardShiftModifier;
    else
        m_inputEvent.keyboardModifiers &= ~Fw::KeyboardShiftModifier;
}

void CocoaWindow::handleMouseButton(Fw::MouseButton button, bool pressed, const Point& position)
{
    m_inputEvent.mousePos = position;

    if (pressed) {
        m_mouseButtonStates |= (1u << button);
        m_inputEvent.reset(Fw::MousePressInputEvent);
        m_inputEvent.mouseButton = button;
    } else {
        m_mouseButtonStates &= ~(1u << button);
        m_inputEvent.reset(Fw::MouseReleaseInputEvent);
        m_inputEvent.mouseButton = button;
    }

    if (m_onInputEvent)
        m_onInputEvent(m_inputEvent);
}

void CocoaWindow::handleMouseMove(const Point& position)
{
    m_inputEvent.reset(Fw::MouseMoveInputEvent);
    m_inputEvent.mousePos = position;

    if (m_onInputEvent)
        m_onInputEvent(m_inputEvent);
}

void CocoaWindow::handleMouseScroll(int deltaX, int deltaY)
{
    (void)deltaX;
    m_inputEvent.reset(Fw::MouseWheelInputEvent);

    if (deltaY != 0) {
        m_inputEvent.wheelDirection = deltaY > 0 ? Fw::MouseWheelUp : Fw::MouseWheelDown;
        if (m_onInputEvent)
            m_onInputEvent(m_inputEvent);
    }
}

void CocoaWindow::handleResize(int width, int height)
{
    m_size = Size(width, height);

    if (m_glContext) {
        [m_glContext update];
    }

    if (m_onResize)
        m_onResize(m_size);
}

void CocoaWindow::handleMove(int x, int y)
{
    m_position = Point(x, y);
    updateUnmaximizedCoords();
}

void CocoaWindow::handleClose()
{
    if (m_onClose)
        m_onClose();
}

void CocoaWindow::handleFocusChange(bool focused)
{
    m_focused = focused;
    if (!focused) {
        releaseAllKeys();
    }
}

void CocoaWindow::handleTextInput(const std::string& text)
{
    if (text.empty()) return;

    for (size_t i = 0; i < text.size(); ) {
        unsigned char c = text[i];
        int charLen = 1;

        if ((c & 0x80) == 0) {
            charLen = 1;
        } else if ((c & 0xE0) == 0xC0) {
            charLen = 2;
        } else if ((c & 0xF0) == 0xE0) {
            charLen = 3;
        } else if ((c & 0xF8) == 0xF0) {
            charLen = 4;
        }

        if (i + charLen <= text.size()) {
            std::string character = text.substr(i, charLen);

            m_inputEvent.reset(Fw::KeyTextInputEvent);
            m_inputEvent.keyText = character;

            if (m_onInputEvent)
                m_onInputEvent(m_inputEvent);
        }

        i += charLen;
    }
}

#endif
