-- @docclass
UIHTML = extends(UIWidget, 'UIHTML')

-- public functions
function UIHTML.create()
    local scrollarea = UIHTML.internalCreate()
    scrollarea.inverted = false
    scrollarea.alwaysScrollMaximum = false
    return scrollarea
end

local function includeRectBounds(bounds, rect)
    if not rect or rect.width <= 0 or rect.height <= 0 then
        return bounds
    end

    local left = rect.x
    local top = rect.y
    local right = rect.x + rect.width
    local bottom = rect.y + rect.height

    if not bounds then
        return { left = left, top = top, right = right, bottom = bottom }
    end

    if left < bounds.left then bounds.left = left end
    if top < bounds.top then bounds.top = top end
    if right > bounds.right then bounds.right = right end
    if bottom > bounds.bottom then bounds.bottom = bottom end
    return bounds
end

local function intersectRects(a, b)
    if not a then
        return b
    end
    if not b then
        return a
    end

    local left = math.max(a.x, b.x)
    local top = math.max(a.y, b.y)
    local right = math.min(a.x + a.width, b.x + b.width)
    local bottom = math.min(a.y + a.height, b.y + b.height)
    if right <= left or bottom <= top then
        return nil
    end

    return { x = left, y = top, width = right - left, height = bottom - top }
end

local DISPLAY_NONE = 0 -- DisplayType::None

local function collectContentBounds(widget, bounds, clipRect)
    for _, child in pairs(widget:getChildren()) do
        if child and not child:isDestroyed() and child:isExplicitlyVisible() and child:getDisplay() ~= DISPLAY_NONE then
            local visibleRect = child:getMarginRect()
            if clipRect then
                visibleRect = intersectRects(visibleRect, clipRect)
            end

            bounds = includeRectBounds(bounds, visibleRect)

            local nextClip = clipRect
            if child:isClipping() then
                local childClip = child:getPaddingRect()
                nextClip = nextClip and intersectRects(nextClip, childClip) or childClip
            end

            if nextClip or not clipRect then
                bounds = collectContentBounds(child, bounds, nextClip)
            end
        end
    end

    return bounds
end

local function computeContentExtent(widget)
    local paddingRect = widget:getPaddingRect()
    local bounds = collectContentBounds(widget, nil, nil)
    local virtualOffset = widget:getVirtualOffset()

    if not bounds then
        return paddingRect.width, paddingRect.height
    end

    local paddingLeft = paddingRect.x
    local paddingTop = paddingRect.y
    local width = math.max((bounds.right + virtualOffset.x) - paddingLeft, paddingRect.width)
    local height = math.max((bounds.bottom + virtualOffset.y) - paddingTop, paddingRect.height)
    return width, height
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

    local paddingRect = self:getPaddingRect()
    local contentWidth, contentHeight = computeContentExtent(self)
    local scrollWidth = math.max(contentWidth - paddingRect.width, 0)
    local scrollHeight = math.max(contentHeight - paddingRect.height, 0)

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
