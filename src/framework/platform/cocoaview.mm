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

#include "cocoawindow.h"
#include "cocoaview.h"
#include <string>

#define Point MacPoint
#define Size MacSize
#define Rect MacRect

#import <Carbon/Carbon.h>

#undef Point
#undef Size
#undef Rect

@interface OTOpenGLView ()
- (void)dispatchMouseMove:(NSEvent*)event;
- (void)dispatchMouseButton:(Fw::MouseButton)button pressed:(bool)pressed event:(NSEvent*)event;
@end

@implementation OTOpenGLView

- (instancetype)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format {
    self = [super initWithFrame:frameRect pixelFormat:format];
    if (self) {
        _acceptsInput = YES;
        NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited |
                                        NSTrackingMouseMoved |
                                        NSTrackingActiveAlways |
                                        NSTrackingInVisibleRect;
        NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                    options:options
                                                                      owner:self
                                                                   userInfo:nil];
        [self addTrackingArea:trackingArea];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return _acceptsInput;
}

- (BOOL)canBecomeKeyView {
    return _acceptsInput;
}

- (void)keyDown:(NSEvent*)event {
    if (!_platformWindow) return;

    // Skip OS-level key repeats - game handles repeats via fireKeysPress()
    if ([event isARepeat]) {
        if ([event characters] && [[event characters] length] > 0) {
            std::string chars = [[event characters] UTF8String];
            Fw::Key key = _platformWindow->translateKeyCode([event keyCode]);
            bool isSpecial = _platformWindow->isSpecialKey(key);
            unsigned int modifiers = [event modifierFlags];
            if (!isSpecial && !(modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl))) {
                _platformWindow->handleTextInput(chars);
            }
        }
        return;
    }

    unsigned short keyCode = [event keyCode];
    unsigned int modifiers = [event modifierFlags];

    if ((modifiers & NSEventModifierFlagCommand) && keyCode == kVK_ANSI_Q) {
        _platformWindow->handleClose();
        return;
    }

    std::string chars;
    if ([event characters] && [[event characters] length] > 0) {
        chars = [[event characters] UTF8String];
    }

    _platformWindow->handleKeyDown(keyCode, modifiers, chars);

    Fw::Key key = _platformWindow->translateKeyCode(keyCode);
    bool isSpecial = _platformWindow->isSpecialKey(key);

    if (chars.length() > 0 && !isSpecial && !(modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl))) {
        _platformWindow->handleTextInput(chars);
    }
}

- (void)keyUp:(NSEvent*)event {
    if (!_platformWindow) return;
    _platformWindow->handleKeyUp([event keyCode], [event modifierFlags]);
}

- (void)flagsChanged:(NSEvent*)event {
    if (!_platformWindow) return;
    _platformWindow->handleFlagsChanged([event modifierFlags]);
}

- (Point)convertMousePosition:(NSEvent*)event {
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    NSRect bounds = [self bounds];
    return Point(static_cast<int>(loc.x), static_cast<int>(bounds.size.height - loc.y));
}

- (void)dispatchMouseMove:(NSEvent*)event {
    if (!_platformWindow) return;
    _platformWindow->handleMouseMove([self convertMousePosition:event]);
}

- (void)dispatchMouseButton:(Fw::MouseButton)button pressed:(bool)pressed event:(NSEvent*)event {
    if (!_platformWindow) return;
    _platformWindow->handleMouseButton(button, pressed, [self convertMousePosition:event]);
}

- (void)mouseDown:(NSEvent*)event {
    [self dispatchMouseButton:Fw::MouseLeftButton pressed:true event:event];
}

- (void)mouseUp:(NSEvent*)event {
    [self dispatchMouseButton:Fw::MouseLeftButton pressed:false event:event];
}

- (void)rightMouseDown:(NSEvent*)event {
    [self dispatchMouseButton:Fw::MouseRightButton pressed:true event:event];
}

- (void)rightMouseUp:(NSEvent*)event {
    [self dispatchMouseButton:Fw::MouseRightButton pressed:false event:event];
}

- (void)otherMouseDown:(NSEvent*)event {
    if ([event buttonNumber] == 2) {
        [self dispatchMouseButton:Fw::MouseMidButton pressed:true event:event];
    }
}

- (void)otherMouseUp:(NSEvent*)event {
    if ([event buttonNumber] == 2) {
        [self dispatchMouseButton:Fw::MouseMidButton pressed:false event:event];
    }
}

- (void)mouseMoved:(NSEvent*)event {
    [self dispatchMouseMove:event];
}

- (void)mouseDragged:(NSEvent*)event {
    [self dispatchMouseMove:event];
}

- (void)rightMouseDragged:(NSEvent*)event {
    [self dispatchMouseMove:event];
}

- (void)otherMouseDragged:(NSEvent*)event {
    [self dispatchMouseMove:event];
}

- (void)scrollWheel:(NSEvent*)event {
    if (!_platformWindow) return;
    CGFloat deltaX = [event scrollingDeltaX];
    CGFloat deltaY = [event scrollingDeltaY];

    if ([event hasPreciseScrollingDeltas]) {
        deltaX *= 0.1;
        deltaY *= 0.1;
    }

    _platformWindow->handleMouseScroll(static_cast<int>(deltaX), static_cast<int>(deltaY));
}

- (void)mouseEntered:(NSEvent*)event {
    (void)event;
}

- (void)mouseExited:(NSEvent*)event {
    (void)event;
}

@end

@implementation OTWindowDelegate

- (void)windowDidResize:(NSNotification*)notification {
    if (!_platformWindow) return;
    NSWindow* window = [notification object];
    NSRect contentRect = [[window contentView] frame];
    _platformWindow->handleResize(static_cast<int>(contentRect.size.width),
                                   static_cast<int>(contentRect.size.height));
}

- (void)windowDidMove:(NSNotification*)notification {
    if (!_platformWindow) return;
    NSWindow* window = [notification object];
    NSRect frame = [window frame];
    NSScreen* screen = [window screen];
    if (screen) {
        NSRect screenFrame = [screen frame];
        int y = static_cast<int>(screenFrame.size.height - frame.origin.y - frame.size.height);
        _platformWindow->handleMove(static_cast<int>(frame.origin.x), y);
    }
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    (void)notification;
    if (!_platformWindow) return;
    _platformWindow->handleFocusChange(true);
}

- (void)windowDidResignKey:(NSNotification*)notification {
    (void)notification;
    if (!_platformWindow) return;
    _platformWindow->handleFocusChange(false);
}

- (BOOL)windowShouldClose:(NSWindow*)sender {
    (void)sender;
    if (_platformWindow) {
        _platformWindow->handleClose();
    }
    return NO;
}

- (void)windowWillEnterFullScreen:(NSNotification*)notification {
    (void)notification;
}

- (void)windowDidEnterFullScreen:(NSNotification*)notification {
    (void)notification;
}

- (void)windowWillExitFullScreen:(NSNotification*)notification {
    (void)notification;
}

- (void)windowDidExitFullScreen:(NSNotification*)notification {
    (void)notification;
}

@end

#endif
