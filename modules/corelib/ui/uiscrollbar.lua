-- @docclass
UIScrollBar = extends(UIWidget, 'UIScrollBar')

-- private functions
local function calcValues(self)
    local slider = self:getChildById('sliderButton')
    local decrementButton = self:getChildById('decrementButton')
    local incrementButton = self:getChildById('incrementButton')

    local pxrange, center

    if self.orientation == 'vertical' then
        pxrange = self:getHeight() - decrementButton:getHeight() - decrementButton:getMarginTop() -
                      decrementButton:getMarginBottom() - incrementButton:getHeight() - incrementButton:getMarginTop() -
                      incrementButton:getMarginBottom()
        center = self:getY() + math.floor(self:getHeight() / 2)
    else
        pxrange = self:getWidth() - decrementButton:getWidth() - decrementButton:getMarginLeft() -
                      decrementButton:getMarginRight() - incrementButton:getWidth() - incrementButton:getMarginLeft() -
                      incrementButton:getMarginRight()
        center = self:getX() + math.floor(self:getWidth() / 2)
    end

    local range = self.maximum - self.minimum + 1

    local proportion
    if self.virtualChilds > 0 and self.visibleItems then
        proportion = math.min(1.0, self.visibleItems / self.virtualChilds)
    else
        if self.pixelsScroll then
            proportion = pxrange / (range + pxrange)
        else
            proportion = math.min(math.max(self.step, 1), range) / range
        end
    end

    -- For horizontal scrollbars, use a larger minimum size for better usability
    local minSize = (self.orientation == 'horizontal') and 40 or 12
    local px = math.max(proportion * pxrange, minSize)

    px = px - (px % 2) + 1

    if self.defaultSlider then
        px = 13
    end

    local offset = 0
    if range == 0 or self.value == self.minimum then
        if self.orientation == 'vertical' then
            offset = -math.floor((self:getHeight() - px) / 2) + decrementButton:getMarginRect().height
        else
            offset = -math.floor((self:getWidth() - px) / 2) + decrementButton:getMarginRect().width
        end
    elseif range > 1 and self.value == self.maximum then
        if self.orientation == 'vertical' then
            offset = math.ceil((self:getHeight() - px) / 2) - incrementButton:getMarginRect().height
        else
            offset = math.ceil((self:getWidth() - px) / 2) - incrementButton:getMarginRect().width
        end
    elseif range > 1 then
        offset = (((self.value - self.minimum) / (range - 1)) - 0.5) * (pxrange - px)
    end

    return range, pxrange, px, offset, center
end

local function updateValueDisplay(widget)
    if widget == nil then
        return
    end

    if widget:getShowValue() then
        widget:setText(widget:getValue() .. (widget:getSymbol() or ''))
    end
end

local function updateSlider(self)
    local slider = self:getChildById('sliderButton')
    if slider == nil then
        return
    end

    local range, pxrange, px, offset, center = calcValues(self)
    if self.orientation == 'vertical' then
        slider:setHeight(px)
        slider:setMarginTop(offset)
    else -- horizontal
        slider:setWidth(px)
        slider:setMarginLeft(offset)
    end
    updateValueDisplay(self)

    local status = true

    self:setOn(status)
    for _i, child in pairs(self:getChildren()) do
        child:setEnabled(status)
    end
end

local function parseSliderPos(self, slider, pos, move, useStep)
    if useStep == nil then
        useStep = true
    end
    local delta, hotDistance
    if self.orientation == 'vertical' then
        delta = move.y
        hotDistance = pos.y - slider:getY()
    else
        delta = move.x
        hotDistance = pos.x - slider:getX()
    end

    if (delta > 0 and hotDistance + delta > self.hotDistance) or (delta < 0 and hotDistance + delta < self.hotDistance) then
        local range, pxrange, px, offset, center = calcValues(self)
        local denom = (pxrange - px)
        if denom == 0 then
            -- nothing to move (slider covers full range); keep current value
            return
        end

        local newvalue = self.value + delta * (range / denom)

        -- protect against invalid numerical results
        if not (newvalue == newvalue) or newvalue == math.huge or newvalue == -math.huge then
            if delta > 0 then
                newvalue = self.maximum
            else
                newvalue = self.minimum
            end
        end

        if useStep and self.step and self.step > 0 then
            local step = self.step
            -- snap to nearest step for smoother, predictable behaviour
            newvalue = math.floor((newvalue + step / 2) / step) * step
        end

        -- ensure final value is numeric and clamped
        if type(newvalue) ~= 'number' then newvalue = self.value end
        self:setValue(newvalue)
    end
end

local function parseSliderPress(self, slider, pos, button)
    if self.orientation == 'vertical' then
        self.hotDistance = pos.y - slider:getY()
    else
        self.hotDistance = pos.x - slider:getX()
    end
end

-- public functions
function UIScrollBar.create()
    local scrollbar = UIScrollBar.internalCreate()
    scrollbar:setFocusable(false)
    scrollbar.value = 0
    scrollbar.minimum = -999999
    scrollbar.maximum = 999999
    scrollbar.step = 1
    scrollbar.visibleItems = 0
    scrollbar.virtualChilds = 0
    scrollbar.incrementValue = 1
    scrollbar.orientation = 'vertical'
    scrollbar.pixelsScroll = false
    scrollbar.showValue = false
    scrollbar.symbol = nil
    scrollbar.mouseScroll = true
    scrollbar.defaultSlider = false
    scrollbar.invertedView = true
    scrollbar.shiftIncrement = 10
    scrollbar.ctrlIncrement = 100
    scrollbar.autoPressDelay = 30
    return scrollbar
end

function UIScrollBar:onSetup()
    self.setupDone = true
    local sliderButton = self:getChildById('sliderButton')
    -- If the scrollbar is declared inside an OptionScaleScroll (or similar)
    -- parent widgets may provide instance properties to configure the scrollbar.
    local parent = self:getParent()
    if parent then
        if parent.minimumScrollValue ~= nil then
            local minv = tonumber(parent.minimumScrollValue)
            if minv then self:setMinimum(minv) end
        end
        if parent.maximumScrollValue ~= nil then
            local maxv = tonumber(parent.maximumScrollValue)
            if maxv then self:setMaximum(maxv) end
        end
        if parent.scrollSize ~= nil then
            local stepv = tonumber(parent.scrollSize)
            if stepv then self:setStep(stepv) end
        end
        if parent.defaultScroll ~= nil then
            -- support older naming if used in styles
            if parent.defaultScroll then self:setDefaultScroll() end
        end
    end
    g_mouse.bindAutoPress(self:getChildById('decrementButton'), function()
        self:onDecrement()
    end, 250, nil, self.autoPressDelay)

    g_mouse.bindAutoPress(self:getChildById('incrementButton'), function()
        self:onIncrement()
    end, 250, nil, self.autoPressDelay)

    g_mouse.bindPressMove(sliderButton, function(mousePos, mouseMoved)
        if self.canChangeValue and not signalcall(self.canChangeValue, self) then
            return
        end
        parseSliderPos(self, sliderButton, mousePos, mouseMoved, false)
    end)

    g_mouse.bindPress(sliderButton, function(mousePos, mouseButton)
        if self.canChangeValue and not signalcall(self.canChangeValue, self) then
            return
        end
        parseSliderPress(self, sliderButton, mousePos, mouseButton)
    end)

    self.onClick = function()
        self:onClickSlider()
    end
    updateSlider(self)
end

function UIScrollBar:onClickSlider(slider)
    local mousePos = g_window.getMousePosition()
    local slider = self:getChildById('sliderButton')
    self:setSliderClick(slider, slider:getPosition())
    if self.orientation == 'vertical' then
        self:setSliderPos(slider, slider:getPosition(), {
            y = mousePos.y - slider:getPosition().y,
            x = 0
        })
    else
        self:setSliderPos(slider, slider:getPosition(), {
            x = mousePos.x - slider:getPosition().x,
            y = 0
        })
    end
end

function UIScrollBar:setSliderClick(slider, pos)
    if self.orientation == 'vertical' then
        self.hotDistance = pos.y - slider:getY()
    else
        self.hotDistance = pos.x - slider:getX()
    end
end

function UIScrollBar:setSliderPos(slider, pos, move)
    parseSliderPos(self, slider, pos, move)
end

function UIScrollBar:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'maximum' then
            self:setMaximum(tonumber(value))
        elseif name == 'minimum' then
            self:setMinimum(tonumber(value))
        elseif name == 'step' then
            self:setStep(tonumber(value))
        elseif name == 'orientation' then
            self:setOrientation(value)
        elseif name == 'value' then
            self:setValue(value)
        elseif name == 'pixels-scroll' then
            self.pixelsScroll = true
        elseif name == 'show-value' then
            self.showValue = true
        elseif name == 'symbol' then
            self.symbol = value
        elseif name == 'mouse-scroll' then
            self.mouseScroll = value
        elseif name == 'default-scroll' then
            self.defaultSlider = value
        elseif name == 'increment' then
            self.incrementValue = value
        elseif name == 'inverted-view' then
            self.invertedView = value
        elseif name == 'ctrl-increment' then
            self.ctrlIncrement = value
        elseif name == 'shift-increment' then
            self.shiftIncrement = value
        elseif name == 'auto-press-delay' then
            self.autoPressDelay = value
        end
    end
end

function UIScrollBar:onDecrement()
    local count = self.incrementValue
    if g_keyboard.isShiftPressed() and g_keyboard.isCtrlPressed() then
        count = 1000
    elseif g_keyboard.isCtrlPressed() then
        count = self.ctrlIncrement
    elseif g_keyboard.isShiftPressed() then
        count = self.shiftIncrement
    end

    self:decrement(count)
end

function UIScrollBar:onIncrement()
    local count = self.incrementValue
    if g_keyboard.isShiftPressed() and g_keyboard.isCtrlPressed() then
        count = 1000
    elseif g_keyboard.isCtrlPressed() then
        count = self.ctrlIncrement
    elseif g_keyboard.isShiftPressed() then
        count = self.shiftIncrement
    end
    self:increment(count)
end

function UIScrollBar:decrement(count)
    if self.canChangeValue and not signalcall(self.canChangeValue, self) then
        return
    end

    count = count or self.step
    self:setValue(self.value - count)
end

function UIScrollBar:increment(count)
    if self.canChangeValue and not signalcall(self.canChangeValue, self) then
        return
    end

    count = count or self.step
    self:setValue(self.value + count)
end

function UIScrollBar:setMaximum(maximum)
    if maximum == self.maximum then
        return
    end
    self.maximum = maximum
    if self.minimum > maximum then
        self:setMinimum(maximum)
    end
    if self.value > maximum then
        self:setValue(maximum)
    else
        updateSlider(self)
    end
end

function UIScrollBar:setMinimum(minimum)
    if minimum == self.minimum then
        return
    end
    self.minimum = minimum
    if self.maximum < minimum then
        self:setMaximum(minimum)
    end
    if self.value < minimum then
        self:setValue(minimum)
    else
        updateSlider(self)
    end
end

function UIScrollBar:setRange(minimum, maximum)
    self:setMinimum(minimum)
    self:setMaximum(maximum)
end

function UIScrollBar:setValue(value)
    value = math.max(math.min(value, self.maximum), self.minimum)
    if self.value == value then
        return
    end
    local delta = value - self.value
    self.value = value
    updateSlider(self)
    if self.setupDone then
        signalcall(self.onValueChange, self, math.round(value), delta)
    end
end

function UIScrollBar:setMouseScroll(scroll)
    self.mouseScroll = scroll
end

function UIScrollBar:setStep(step)
    self.step = step
end

function UIScrollBar:setOrientation(orientation)
    self.orientation = orientation
end

function UIScrollBar:setText(text)
    local valueLabel = self:getChildById('valueLabel')
    if valueLabel then
        valueLabel:setText(text)
    end
end

function UIScrollBar:onGeometryChange()
    updateSlider(self)
end

function UIScrollBar:onMouseWheel(mousePos, mouseWheel)
    if not self.mouseScroll or not self:isOn() or self.disableScroll then
        return false
    end

    if self.canChangeValue and not signalcall(self.canChangeValue, self) then
        return
    end

    if mouseWheel == MouseWheelUp then
        if self.orientation == 'vertical' then
            if self.value <= self.minimum then
                return false
            end
            self:decrement()
        else
            if self.invertedView then
                if self.value <= self.minimum then
                    return false
                end
                self:decrement()
            else
                if self.value >= self.maximum then
                    return false
                end
                self:increment()
            end
        end
    else
        if self.orientation == 'vertical' then
            if self.value >= self.maximum then
                return false
            end
            self:increment()
        else
            if self.invertedView then
                if self.value >= self.maximum then
                    return false
                end
                self:increment()
            else
                if self.value <= self.minimum then
                    return false
                end
                self:decrement()
            end
        end
    end
    return true
end

function UIScrollBar:getIncrementValue()
    return self.incrementValue
end
function UIScrollBar:setIncrementStep(value)
    self.incrementValue = value
end
function UIScrollBar:setDefaultScroll()
    self.defaultSlider = true
end
function UIScrollBar:getMaximum()
    return self.maximum
end
function UIScrollBar:getMinimum()
    return self.minimum
end
function UIScrollBar:getValue()
    return math.round(self.value)
end
function UIScrollBar:getStep()
    return self.step
end
function UIScrollBar:getOrientation()
    return self.orientation
end
function UIScrollBar:getShowValue()
    return self.showValue
end
function UIScrollBar:getSymbol()
    return self.symbol
end
function UIScrollBar:getMouseScroll()
    return self.mouseScroll
end
function UIScrollBar:setVirtualChilds(value)
    self.virtualChilds = value
    updateSlider(self)
end
function UIScrollBar:setVisibleItems(value)
    self.visibleItems = value
end -- mest be called before setVirtualChilds 
