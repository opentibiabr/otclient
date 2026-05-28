-- @docclass
UIResizeBorder = extends(UIWidget, 'UIResizeBorder')

function UIResizeBorder.create()
    local resizeborder = UIResizeBorder.internalCreate()
    resizeborder:setFocusable(false)
    resizeborder.minimum = 0
    resizeborder.maximum = 1000
    return resizeborder
end

function UIResizeBorder:onSetup()
    if self:getWidth() > self:getHeight() then
        self.vertical = true
    else
        self.vertical = false
    end
end

function UIResizeBorder:onDestroy()
    if self.hovering then
        -- Restore cursor when widget is destroyed while hovering
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor(self.cursortype)
        end
    end
end

function UIResizeBorder:onHoverChange(hovered)
    if hovered then
        local nativeCursor = modules.client_options and modules.client_options.getOption('nativeCursor')
        
        -- Check isCursorChanged only when NOT using native cursor
        if not nativeCursor and (g_mouse.isCursorChanged() or g_mouse.isPressed()) then
            return
        end
        
        if self:getWidth() > self:getHeight() then
            self.vertical = true
            self.cursortype = 'vertical'
        else
            self.vertical = false
            self.cursortype = 'horizontal'
        end
        
        -- Use native cursor when enabled, otherwise use custom cursor
        if nativeCursor then
            g_window.setSystemCursor(self.cursortype)
        else
            g_mouse.pushCursor(self.cursortype)
        end
        
        self.hovering = true
        if not self:isPressed() then
            g_effects.fadeIn(self)
        end
    else
        if not self:isPressed() and self.hovering then
            -- Restore cursor when hovering ends
            if modules.client_options and modules.client_options.getOption('nativeCursor') then
                g_window.restoreMouseCursor()
            else
                g_mouse.popCursor(self.cursortype)
            end
            g_effects.fadeOut(self)
            self.hovering = false
        end
    end
end

function UIResizeBorder:onMouseMove(mousePos, mouseMoved)
    if self:isPressed() then
        local parent = self:getParent()
        local newSize = 0
        if self.vertical then
            local delta = mousePos.y - self:getY() - self:getHeight() / 2
            newSize = math.min(math.max(parent:getHeight() + delta, self.minimum), self.maximum)
            if self:getAnchorType(AnchorBottom) ~= AnchorNone then
              newSize = math.min(math.max(parent:getHeight() + delta, self.minimum), self.maximum)
            elseif self:getAnchorType(AnchorTop) ~= AnchorNone then
              newSize = math.min(math.max(parent:getHeight() - delta, self.minimum), self.maximum)
            end
            parent:setHeight(newSize)
        else
            local delta = mousePos.x - self:getX() - self:getWidth() / 2
            newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
            if self:getAnchorType(AnchorRight) ~= AnchorNone then
              newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
            elseif self:getAnchorType(AnchorLeft) ~= AnchorNone then
              newSize = math.min(math.max(parent:getWidth() - delta, self.minimum), self.maximum)
            end
            parent:setWidth(newSize)
        end

        self:checkBoundary(newSize)
        return true
    end
end

function UIResizeBorder:onMouseRelease(mousePos, mouseButton)
    if not self:isHovered() then
        -- Restore cursor when mouse is released outside the border
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor(self.cursortype)
        end
        g_effects.fadeOut(self)
        self.hovering = false
    end
end

function UIResizeBorder:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'maximum' then
            self:setMaximum(tonumber(value))
        elseif name == 'minimum' then
            self:setMinimum(tonumber(value))
        end
    end
end

function UIResizeBorder:onVisibilityChange(visible)
    if visible and self.maximum == self.minimum then
        self:hide()
    end
end

function UIResizeBorder:setMaximum(maximum)
    self.maximum = maximum
    self:checkBoundary()
end

function UIResizeBorder:setMinimum(minimum)
    self.minimum = minimum
    self:checkBoundary()
end

function UIResizeBorder:getMaximum()
    return self.maximum
end
function UIResizeBorder:getMinimum()
    return self.minimum
end

function UIResizeBorder:setParentSize(size)
    local parent = self:getParent()
    if self.vertical then
        parent:setHeight(size)
    else
        parent:setWidth(size)
    end
    self:checkBoundary(size)
end

function UIResizeBorder:getParentSize()
    local parent = self:getParent()
    if self.vertical then
        return parent:getHeight()
    else
        return parent:getWidth()
    end
end

function UIResizeBorder:checkBoundary(size)
    size = size or self:getParentSize()
    if self.maximum == self.minimum and size == self.maximum then
        self:hide()
    else
        self:show()
    end
end
