-- @docclass
UISplitter = extends(UIWidget, 'UISplitter')

function UISplitter.create()
    local splitter = UISplitter.internalCreate()
    splitter:setFocusable(false)
    splitter.relativeMargin = 'bottom'
    return splitter
end

function UISplitter:onHoverChange(hovered)
    -- Check if margin can be changed
    local margin = (self.vertical and self:getMarginBottom() or self:getMarginRight())
    if hovered and (self:canUpdateMargin(margin + 1) ~= margin or self:canUpdateMargin(margin - 1) ~= margin) then
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
        self.hovering = true
        
        -- Use native cursor when enabled, otherwise use custom cursor
        if nativeCursor then
            g_window.setSystemCursor(self.cursortype)
        else
            g_mouse.pushCursor(self.cursortype)
        end
    else
        if not self:isPressed() and self.hovering then
            -- Restore cursor when hovering ends
            if modules.client_options and modules.client_options.getOption('nativeCursor') then
                g_window.restoreMouseCursor()
            else
                g_mouse.popCursor(self.cursortype)
            end
            self.hovering = false
        end
    end
end

function UISplitter:onMouseMove(mousePos, mouseMoved)
    if self:isPressed() then
        -- local currentmargin, newmargin, delta
        if self.vertical then
            local delta = mousePos.y - self:getY() - self:getHeight() / 2
            local newMargin = self:canUpdateMargin(self:getMarginBottom() - delta)
            local currentMargin = self:getMarginBottom()
            if newMargin ~= currentMargin then
                self.newMargin = newMargin
                if not self.event or self.event:isExecuted() then
                    self.event = addEvent(function()
                        self:setMarginBottom(self.newMargin)
                    end)
                end
            end
        else
            local delta = mousePos.x - self:getX() - self:getWidth() / 2
            local newMargin = self:canUpdateMargin(self:getMarginRight() - delta)
            local currentMargin = self:getMarginRight()
            if newMargin ~= currentMargin then
                self.newMargin = newMargin
                if not self.event or self.event:isExecuted() then
                    self.event = addEvent(function()
                        self:setMarginRight(self.newMargin)
                    end)
                end
            end
        end
        return true
    end
end

function UISplitter:onMouseRelease(mousePos, mouseButton)
    if not self:isHovered() then
        -- Restore cursor when mouse is released outside the splitter
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor(self.cursortype)
        end
        self.hovering = false
    end
end

function UISplitter:onStyleApply(styleName, styleNode)
    if styleNode['relative-margin'] then
        self.relativeMargin = styleNode['relative-margin']
    end
end

function UISplitter:canUpdateMargin(newMargin)
    return newMargin
end
