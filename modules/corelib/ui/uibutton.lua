-- @docclass
UIButton = extends(UIWidget, 'UIButton')

function UIButton.create()
    local button = UIButton.internalCreate()
    button:setFocusable(false)
    button.cursorPushed = false
    return button
end

function UIButton:onMouseRelease(pos, button)
    return self:isPressed()
end

function UIButton:onDestroy()
    -- Clean up cursor if it was pushed
    if self.cursorPushed then
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor('pointerbutton')
        end
        self.cursorPushed = false
    end
end

function UIButton:onHoverChange(hovered)
    if not modules.client_options then
        return
    end
    
    local nativeCursor = modules.client_options.getOption('nativeCursor')
    local animatedCursor = modules.client_options.getOption('showAnimatedCursor')
    
    -- Animated cursor mode - show pointer button on hover
    if animatedCursor and not nativeCursor then
        if hovered then
            -- Only push if we haven't already
            if not self.cursorPushed then
                g_mouse.pushCursor('pointerbutton')
                self.cursorPushed = true
            end
        else
            -- Only pop if we pushed
            if self.cursorPushed then
                g_mouse.popCursor('pointerbutton')
                self.cursorPushed = false
            end
        end
    elseif nativeCursor then
        -- Native cursor mode - use hand pointer
        if hovered then
            if not self.cursorPushed then
                g_window.setSystemCursor('hand')
                self.cursorPushed = true
            end
        else
            if self.cursorPushed then
                g_window.restoreMouseCursor()
                self.cursorPushed = false
            end
        end
    end
    -- When both are disabled, use default Tibia cursors (no animation)
    -- The cursor is already set to default, so we don't need to change it
end
