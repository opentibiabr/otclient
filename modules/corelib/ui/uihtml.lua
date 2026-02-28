-- @docclass
UIHTML = extends(UIWidget, 'UIHTML')

-- public functions
function UIHTML.create()
    local scrollarea = UIHTML.internalCreate()
    scrollarea.inverted = false
    scrollarea.alwaysScrollMaximum = false
    return scrollarea
end

function UIHTML:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'vertical-scrollbar' then
            addEvent(function()
                local parent = self:getParent()
                if parent then
                    self:setVerticalScrollBar(parent:getChildById(value))
                end
            end)
        elseif name == 'horizontal-scrollbar' then
            addEvent(function()
                local parent = self:getParent()
                if parent then
                    self:setHorizontalScrollBar(self:getParent():getChildById(value))
                end
            end)
        elseif name == 'inverted-scroll' then
            self:setInverted(value)
        elseif name == 'always-scroll-maximum' then
            self:setAlwaysScrollMaximum(value)
        end
    end
end

function UIHTML:onVisibilityChange()
    local scrollbar = self.verticalScrollBar
    if scrollbar then
        scrollbar:setDisplay(self:getDisplay())
        scrollbar:setVisible(self:isVisible())
    end
end

function UIHTML:updateScrollBars()
    if not self.verticalScrollBar and not self.horizontalScrollBar then
        return
    end

    local scrollWidth = math.max(self:getChildrenRect().width - self:getPaddingRect().width, 0)
    local scrollHeight = math.max(self:getChildrenRect().height - self:getPaddingRect().height, 0)

    local scrollbar = self.verticalScrollBar
    if scrollbar then
        if self.inverted then
            scrollbar:setMinimum(-scrollHeight)
            scrollbar:setMaximum(0)
        else
            scrollbar:setMinimum(0)
            scrollbar:setMaximum(scrollHeight)
        end
    end

    local scrollbar = self.horizontalScrollBar
    if scrollbar then
        if self.inverted then
            scrollbar:setMinimum(-scrollWidth)
            scrollbar:setMaximum(0)
        else
            scrollbar:setMinimum(0)
            scrollbar:setMaximum(scrollWidth)
        end
    end

    if self.lastScrollWidth ~= scrollWidth then
        self:onScrollWidthChange()
    end
    if self.lastScrollHeight ~= scrollHeight then
        self:onScrollHeightChange()
    end

    self.lastScrollWidth = scrollWidth
    self.lastScrollHeight = scrollHeight
end

function UIHTML:setVerticalScrollBar(scrollbar)
    self.verticalScrollBar = scrollbar
    connect(self.verticalScrollBar, 'onValueChange', function(scrollbar, value)
        local virtualOffset = self:getVirtualOffset()
        virtualOffset.y = value
        self:setVirtualOffset(virtualOffset)
        signalcall(self.onScrollChange, self, virtualOffset)
    end)
    self:updateScrollBars()
end

function UIHTML:setHorizontalScrollBar(scrollbar)
    self.horizontalScrollBar = scrollbar
    connect(self.horizontalScrollBar, 'onValueChange', function(scrollbar, value)
        local virtualOffset = self:getVirtualOffset()
        virtualOffset.x = value
        self:setVirtualOffset(virtualOffset)
        signalcall(self.onScrollChange, self, virtualOffset)
    end)
    self:updateScrollBars()
end

function UIHTML:setInverted(inverted)
    self.inverted = inverted
end

function UIHTML:setAlwaysScrollMaximum(value)
    self.alwaysScrollMaximum = value
end

function UIHTML:onLayoutUpdate()
    self:updateScrollBars()
end

function UIHTML:onMouseWheel(mousePos, mouseWheel)
    if not self.verticalScrollBar or self.horizontalScrollBar then
        return false
    end

    if self.verticalScrollBar then
        if not self.verticalScrollBar:isOn() then
            return false
        end
        if mouseWheel == MouseWheelUp then
            local minimum = self.verticalScrollBar:getMinimum()
            if self.verticalScrollBar:getValue() <= minimum then
                return false
            end
            self.verticalScrollBar:decrement()
        else
            local maximum = self.verticalScrollBar:getMaximum()
            if self.verticalScrollBar:getValue() >= maximum then
                return false
            end
            self.verticalScrollBar:increment()
        end
    elseif self.horizontalScrollBar then
        if not self.horizontalScrollBar:isOn() then
            return false
        end
        if mouseWheel == MouseWheelUp then
            local maximum = self.horizontalScrollBar:getMaximum()
            if self.horizontalScrollBar:getValue() >= maximum then
                return false
            end
            self.horizontalScrollBar:increment()
        else
            local minimum = self.horizontalScrollBar:getMinimum()
            if self.horizontalScrollBar:getValue() <= minimum then
                return false
            end
            self.horizontalScrollBar:decrement()
        end
    end
    return true
end

function UIHTML:ensureChildVisible(child)
    if child then
        local paddingRect = self:getPaddingRect()
        if self.verticalScrollBar then
            local deltaY = paddingRect.y - child:getY()
            if deltaY > 0 then
                self.verticalScrollBar:decrement(deltaY)
            end

            deltaY = (child:getY() + child:getHeight()) - (paddingRect.y + paddingRect.height)
            if deltaY > 0 then
                self.verticalScrollBar:increment(deltaY)
            end
        elseif self.horizontalScrollBar then
            local deltaX = paddingRect.x - child:getX()
            if deltaX > 0 then
                self.horizontalScrollBar:decrement(deltaX)
            end

            deltaX = (child:getX() + child:getWidth()) - (paddingRect.x + paddingRect.width)
            if deltaX > 0 then
                self.horizontalScrollBar:increment(deltaX)
            end
        end
    end
end

function UIHTML:onChildFocusChange(focusedChild, oldFocused, reason)
    if focusedChild and (reason == MouseFocusReason or reason == KeyboardFocusReason) then
        self:ensureChildVisible(focusedChild)
    end
end

function UIHTML:onScrollWidthChange()
    if self.alwaysScrollMaximum and self.horizontalScrollBar then
        self.horizontalScrollBar:setValue(self.horizontalScrollBar:getMaximum())
    end
end

function UIHTML:onScrollHeightChange()
    if self.alwaysScrollMaximum and self.verticalScrollBar then
        self.verticalScrollBar:setValue(self.verticalScrollBar:getMaximum())
    end
end

function UIHTML:setInvertedScroll(inverted)
    -- 01/23/2026 "inverted-scroll: true" not working in css or html
    -- [CSS].panelConsole { --inverted-scroll: true }
    -- or 
    -- [HTML] style="overflow: scroll; inverted-scroll: true"
    -- temp fix in [html]add <div inverted-scroll="true"></div>
    self:setInverted(inverted)
end
