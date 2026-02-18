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
    if modules.client_options and modules.client_options.getOption('showAnimatedCursor') then
        if hovered then
            g_window.setMouseCursor(g_mouse.getCursorId('pointerbutton'))
        else
            if not modules.client_options.getOption('nativeCursor') then
                g_window.setMouseCursor(g_mouse.getCursorId('default'))
            else
                g_window.restoreMouseCursor()
            end
        end
    end
end
