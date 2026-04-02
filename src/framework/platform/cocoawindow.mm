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

#ifdef __APPLE__

#import "cocoawindow.h"
#include <framework/core/eventdispatcher.h>
#include <framework/graphics/image.h>

#define Size CocoaSize
#define Point CocoaPoint
#define Rect CocoaRect
#define Cursor CocoaCursor
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#undef Size
#undef Point
#undef Rect
#undef Cursor

static Fw::Key translateKey(unsigned short keyCode) {
    switch (keyCode) {
        case 0x35: return Fw::KeyEscape;
        case 0x30: return Fw::KeyTab;
        case 0x33: return Fw::KeyBackspace;
        case 0x24: return Fw::KeyEnter;
        case 0x31: return Fw::KeySpace;
        case 0x38: return Fw::KeyShift;
        case 0x3B: return Fw::KeyCtrl;
        case 0x3A: return Fw::KeyAlt;
        case 0x37: return Fw::KeyMeta;
        case 0x7E: return Fw::KeyUp;
        case 0x7D: return Fw::KeyDown;
        case 0x7B: return Fw::KeyLeft;
        case 0x7C: return Fw::KeyRight;
        case 0x72: return Fw::KeyInsert;
        case 0x75: return Fw::KeyDelete;
        case 0x73: return Fw::KeyHome;
        case 0x77: return Fw::KeyEnd;
        case 0x74: return Fw::KeyPageUp;
        case 0x79: return Fw::KeyPageDown;
        case 0x7A: return Fw::KeyF1;
        case 0x78: return Fw::KeyF2;
        case 0x63: return Fw::KeyF3;
        case 0x76: return Fw::KeyF4;
        case 0x60: return Fw::KeyF5;
        case 0x61: return Fw::KeyF6;
        case 0x62: return Fw::KeyF7;
        case 0x64: return Fw::KeyF8;
        case 0x65: return Fw::KeyF9;
        case 0x6D: return Fw::KeyF10;
        case 0x67: return Fw::KeyF11;
        case 0x6F: return Fw::KeyF12;
        case 0x00: return Fw::KeyA;
        case 0x01: return Fw::KeyS;
        case 0x02: return Fw::KeyD;
        case 0x03: return Fw::KeyF;
        case 0x05: return Fw::KeyG;
        case 0x04: return Fw::KeyH;
        case 0x26: return Fw::KeyJ;
        case 0x28: return Fw::KeyK;
        case 0x25: return Fw::KeyL;
        case 0x2E: return Fw::KeyM;
        case 0x2D: return Fw::KeyN;
        case 0x1F: return Fw::KeyO;
        case 0x23: return Fw::KeyP;
        case 0x0C: return Fw::KeyQ;
        case 0x0F: return Fw::KeyR;
        case 0x0E: return Fw::KeyT;
        case 0x20: return Fw::KeyU;
        case 0x09: return Fw::KeyV;
        case 0x0D: return Fw::KeyW;
        case 0x07: return Fw::KeyX;
        case 0x10: return Fw::KeyY;
        case 0x06: return Fw::KeyZ;
        case 0x1D: return Fw::Key0;
        case 0x12: return Fw::Key1;
        case 0x13: return Fw::Key2;
        case 0x14: return Fw::Key3;
        case 0x15: return Fw::Key4;
        case 0x17: return Fw::Key5;
        case 0x16: return Fw::Key6;
        case 0x1A: return Fw::Key7;
        case 0x1C: return Fw::Key8;
        case 0x19: return Fw::Key9;
        default: return Fw::KeyUnknown;
    }
}

static uint8_t translateModifiers(NSEventModifierFlags flags) {
    uint8_t modifiers = Fw::KeyboardNoModifier;
    if (flags & NSEventModifierFlagShift) modifiers |= Fw::KeyboardShiftModifier;
    if (flags & NSEventModifierFlagControl) modifiers |= Fw::KeyboardCtrlModifier;
    if (flags & NSEventModifierFlagOption) modifiers |= Fw::KeyboardAltModifier;
    // Command is often mapped to Ctrl in OTClient.
    if (flags & NSEventModifierFlagCommand) modifiers |= Fw::KeyboardCtrlModifier; 
    return modifiers;
}

@interface CocoaWindowDelegate : NSObject <NSWindowDelegate>
@property (nonatomic, assign) CocoaWindow* window;
@end

@implementation CocoaWindowDelegate
- (void)windowWillClose:(NSNotification *)notification {
    if (self.window) {
        // Handle window close
    }
}
- (void)windowDidResize:(NSNotification *)notification {
    if (self.window) {
        NSWindow *nsWindow = (NSWindow *)notification.object;
        NSRect contentRect = [nsWindow contentRectForFrameRect:nsWindow.frame];
        CGFloat scale = [nsWindow backingScaleFactor];
        self.window->setDisplayDensity((float)scale);
        self.window->resize(TSize<int>((int)(contentRect.size.width * scale), (int)(contentRect.size.height * scale)));
    }
}
@end

@interface NativeCocoaView : NSView
@property (nonatomic, assign) CocoaWindow* otcWindow;
@end

@implementation NativeCocoaView

- (BOOL)acceptsFirstResponder { return YES; }

- (void)keyDown:(NSEvent *)event {
    if (_otcWindow) {
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::KeyDownInputEvent;
        otEvent.keyCode = translateKey([event keyCode]);
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)keyUp:(NSEvent *)event {
    if (_otcWindow) {
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::KeyUpInputEvent;
        otEvent.keyCode = translateKey([event keyCode]);
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MousePressInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseLeftButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)mouseUp:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MouseReleaseInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseLeftButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MousePressInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseRightButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)rightMouseUp:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MouseReleaseInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseRightButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)mouseDragged:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MouseMoveInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseLeftButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)mouseMoved:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MouseMoveInputEvent;
        otEvent.mouseButton = Fw::MouseButton::MouseNoButton;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

- (void)scrollWheel:(NSEvent *)event {
    if (_otcWindow) {
        NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
        CGFloat scale = [[self window] backingScaleFactor];
        InputEvent otEvent;
        otEvent.type = Fw::InputEventType::MouseWheelInputEvent;
        otEvent.wheelDirection = [event scrollingDeltaY] > 0 ? Fw::MouseWheelUp : Fw::MouseWheelDown;
        otEvent.mousePos = TPoint<int>((int)(location.x * scale), (int)((self.bounds.size.height - location.y) * scale));
        otEvent.keyboardModifiers = translateModifiers([event modifierFlags]);
        _otcWindow->fireInputEvent(otEvent);
    }
}

@end

CocoaWindow::CocoaWindow()
{
    m_window = nullptr;
    m_view = nullptr;
    m_glContext = nullptr;
    m_mouseVisible = true;
    m_size = TSize<int>(800, 600);
}

CocoaWindow::~CocoaWindow()
{
    terminate();
}

void CocoaWindow::init()
{
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSRect frame = NSMakeRect(0, 0, m_size.width(), m_size.height());
    NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:styleMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:@"OTClient"];
    [window center];
    [window makeKeyAndOrderFront:nil];

    NativeCocoaView* view = [[NativeCocoaView alloc] initWithFrame:frame];
    view.otcWindow = this;
    [view setWantsBestResolutionOpenGLSurface:YES];
    [window setContentView:view];
    [window makeFirstResponder:view];

    CocoaWindowDelegate* delegate = [[CocoaWindowDelegate alloc] init];
    delegate.window = this;
    [window setDelegate:delegate];

    m_displayDensity = (float)[window backingScaleFactor];

    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0
    };

    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    NSOpenGLContext* glContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

    [glContext setView:view];
    [glContext makeCurrentContext];

    m_window = (void*)window;
    m_view = (void*)view;
    m_glContext = (void*)glContext;

    m_created = true;
    m_visible = true;
}

void CocoaWindow::terminate()
{
    if (m_glContext) {
        NSOpenGLContext* glContext = (NSOpenGLContext*)m_glContext;
        [glContext clearDrawable];
        m_glContext = nullptr;
    }
    if (m_view) {
        NativeCocoaView* view = (__bridge_transfer NativeCocoaView*)m_view;
        m_view = nullptr;
    }
    if (m_window) {
        NSWindow* window = (__bridge_transfer NSWindow*)m_window;
        [window close];
        m_window = nullptr;
    }
    for (void* cursor : m_cursors) {
        if (cursor) {
            // NSCursor objects are managed by Objective-C runtime, but if we held them
        }
    }
    m_cursors.clear();
}

void CocoaWindow::move(const TPoint<int>& pos)
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    NSRect frame = window.frame;
    frame.origin.x = pos.x;
    frame.origin.y = pos.y; 
    [window setFrame:frame display:YES];
}

void CocoaWindow::resize(const TSize<int>& size)
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    NSRect frame = window.frame;
    frame.size.width = size.width();
    frame.size.height = size.height();
    [window setFrame:frame display:YES];
    m_size = size;
}

void CocoaWindow::show()
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    [window orderFront:nil];
    m_visible = true;
}

void CocoaWindow::hide()
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    [window orderOut:nil];
    m_visible = false;
}

void CocoaWindow::maximize()
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    [window zoom:nil];
}

void CocoaWindow::poll()
{
    NSEvent* event;
    while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                        untilDate:[NSDate distantPast]
                                           inMode:NSDefaultRunLoopMode
                                          dequeue:YES])) {
        [NSApp sendEvent:event];
    }
}

void CocoaWindow::swapBuffers()
{
    NSOpenGLContext* glContext = (__bridge NSOpenGLContext*)m_glContext;
    [glContext flushBuffer];
}

void CocoaWindow::showMouse()
{
    [NSCursor unhide];
    m_mouseVisible = true;
}

void CocoaWindow::hideMouse()
{
    [NSCursor hide];
    m_mouseVisible = false;
}

void CocoaWindow::setMouseCursor(int cursorId)
{
    if (cursorId >= 0 && cursorId < (int)m_cursors.size()) {
        NSCursor* cursor = (__bridge NSCursor*)m_cursors[cursorId];
        [cursor set];
    }
}

void CocoaWindow::restoreMouseCursor()
{
    [NSCursor unhide];
}

void CocoaWindow::setTitle(std::string_view title)
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    [window setTitle:[NSString stringWithUTF8String:title.data()]];
}

void CocoaWindow::setMinimumSize(const TSize<int>& minimumSize)
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    [window setMinSize:NSMakeSize(minimumSize.width(), minimumSize.height())];
}

void CocoaWindow::setFullscreen(bool fullscreen)
{
    NSWindow* window = (__bridge NSWindow*)m_window;
    if (fullscreen != m_fullscreen) {
        [window toggleFullScreen:nil];
        m_fullscreen = fullscreen;
    }
}

void CocoaWindow::setVerticalSync(bool enable)
{
    NSOpenGLContext* glContext = (__bridge NSOpenGLContext*)m_glContext;
    GLint swapInterval = enable ? 1 : 0;
    [glContext setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];
    m_vsync = enable;
}

void CocoaWindow::setIcon(const std::string& iconFile)
{
}

void CocoaWindow::setClipboardText(std::string_view text)
{
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:[NSString stringWithUTF8String:text.data()] forType:NSPasteboardTypeString];
}

TSize<int> CocoaWindow::getDisplaySize()
{
    NSRect screenRect = [[NSScreen mainScreen] frame];
    return TSize<int>((int)screenRect.size.width, (int)screenRect.size.height);
}

std::string CocoaWindow::getClipboardText()
{
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    NSString* string = [pasteboard stringForType:NSPasteboardTypeString];
    if (string) {
        return [string UTF8String];
    }
    return "";
}

int CocoaWindow::internalLoadMouseCursor(const ImagePtr& image, const TPoint<int>& hotSpot)
{
    if (!image) return 0;

    int width = image->getWidth();
    int height = image->getHeight();
    uint8_t* pixels = image->getPixelData();

    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
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

    NSCursor* cursor = [[NSCursor alloc] initWithImage:nsImage hotSpot:NSMakePoint(hotSpot.x, hotSpot.y)];
    
    m_cursors.push_back((__bridge_retained void*)cursor);
    return m_cursors.size() - 1;
}

#endif
