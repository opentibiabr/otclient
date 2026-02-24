-- @docclass
UIButton = extends(UIWidget, 'UIButton')

function UIButton.create()
    local button = UIButton.internalCreate()
    button:setFocusable(false)
    return button
end

function UIButton:onMouseRelease(pos, button)
    return self:isPressed()
end

function UIButton:onHoverChange(hovered)
    if not modules.client_options then
        return
    end
    
    local nativeCursor = modules.client_options.getOption('nativeCursor')
    local animatedCursor = modules.client_options.getOption('showAnimatedCursor')
    
    -- Native cursor takes priority - don't change cursor when using native Windows cursor
    if nativeCursor then
        return
    end
    
    -- Animated cursor mode - show pointer button on hover
    if animatedCursor then
        if hovered then
            g_mouse.pushCursor('pointerbutton')
        else
            g_mouse.popCursor('pointerbutton')
        end
    end
    -- When both are disabled, use default Tibia cursors (no animation)
    -- The cursor is already set to default, so we don't need to change it
end
