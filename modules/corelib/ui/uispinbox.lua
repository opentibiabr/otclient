-- @docclass
UISpinBox = extends(UITextEdit, 'UISpinBox')

function UISpinBox.create()
    local spinbox = UISpinBox.internalCreate()
    spinbox:setFocusable(false)
    spinbox:setValidCharacters('0123456789,')
    spinbox.displayButtons = true
    spinbox.minimum = 0
    spinbox.maximum = 1
    spinbox.value = 0
    spinbox.step = 1
    spinbox.firstchange = true
    spinbox.mouseScroll = true
    spinbox:setText('1')
    spinbox:setValue(1)
    return spinbox
end

function UISpinBox:onSetup()
    g_mouse.bindAutoPress(self:getChildById('up'), function()
        self:upSpin()
    end, 300)
    g_mouse.bindAutoPress(self:getChildById('down'), function()
        self:downSpin()
    end, 300)
end

function UISpinBox:onMouseWheel(mousePos, direction)
    if not self.mouseScroll then
        return false
    end
    if direction == MouseWheelUp then
        self:upSpin()
    elseif direction == MouseWheelDown then
        self:downSpin()
    end
    return true
end

function UISpinBox:onKeyPress()
    if self.firstchange then
        self.firstchange = false
        self:setText('')
    end
    return false
end

function UISpinBox:onTextChange(text, oldText)
    if self.formattedMode then
        local cursorPos = self:getCursorPos()
        local cleanText = text:gsub(",", "")

        if cleanText:len() == 0 then
            self:setValue(self.minimum)
            return
        end

        local number = tonumber(cleanText)
        if not number then
            self:setText(oldText or "")
            self:setCursorPos(cursorPos)
            return
        else
            if number < self.minimum then
                local formattedText = comma_value(self.minimum)
                self:setText(formattedText)
                self.value = self.minimum
                self:setCursorPos(formattedText:len())
                return
            elseif number > self.maximum then
                local formattedText = comma_value(self.maximum)
                self:setText(formattedText)
                self.value = self.maximum
                self:setCursorPos(formattedText:len())
                return
            end
        end

        local formattedText = comma_value(number)
        self:setText(formattedText)
        self.value = number
        self.originalValue = number

        local commasBefore = 0
        local cleanPos = 0
        for i = 1, cursorPos do
            if string.sub(text, i, i) ~= "," then
                cleanPos = cleanPos + 1
            end
        end

        local formattedPos = 0
        local cleanCount = 0
        for i = 1, formattedText:len() do
            if string.sub(formattedText, i, i) ~= "," then
                cleanCount = cleanCount + 1
                if cleanCount <= cleanPos then
                    formattedPos = i
                end
            end
        end

        self:setCursorPos(formattedPos)
        signalcall(self.onValueChange, self, number)
    else
        if text:len() == 0 then
            self:setValue(self.minimum)
            return
        end

        local number = tonumber(text)
        if not number then
            self:setText(number)
            return
        else
            if number < self.minimum then
                self:setText(self.minimum)
                return
            elseif number > self.maximum then
                self:setText(self.maximum)
                return
            end
        end

        self:setValue(number)
    end
end

function UISpinBox:onValueChange(value)
    -- nothing to do
end

function UISpinBox:onFocusChange(focused)
    if not focused then
        if self:getText():len() == 0 then
            self:setText(self.minimum)
        end
    end
end

function UISpinBox:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'maximum' then
            self.maximum = value
            addEvent(function()
                self:setMaximum(value)
            end)
        elseif name == 'minimum' then
            self.minimum = value
            addEvent(function()
                self:setMinimum(value)
            end)
        elseif name == 'mouse-scroll' then
            addEvent(function()
                self:setMouseScroll(value)
            end)
        elseif name == 'buttons' then
            addEvent(function()
                if value then
                    self:showButtons()
                else
                    self:hideButtons()
                end
            end)
        end
    end
end

function UISpinBox:showButtons()
    self:getChildById('up'):show()
    self:getChildById('down'):show()
    self.displayButtons = true
end

function UISpinBox:hideButtons()
    self:getChildById('up'):hide()
    self:getChildById('down'):hide()
    self.displayButtons = false
end

function UISpinBox:up()
    self:setValue(self.value + self.step)
end

function UISpinBox:down()
    self:setValue(self.value - self.step)
end

function UISpinBox:setValue(value, dontSignal)
    value = value or 0
    value = math.max(math.min(self.maximum, value), self.minimum)

    if value == self.value then
        return
    end

    self.value = value
    if self:getText():len() > 0 then
        self:setText(value)
    end

    local upButton = self:getChildById('up')
    local downButton = self:getChildById('down')
    if upButton then
        upButton:setEnabled(self.maximum ~= self.minimum and self.value ~= self.maximum)
    end
    if downButton then
        downButton:setEnabled(self.maximum ~= self.minimum and self.value ~= self.minimum)
    end

    if not dontSignal then
        signalcall(self.onValueChange, self, value)
    end
end

function UISpinBox:getValue()
    return self.value
end

function UISpinBox:setMinimum(minimum)
    minimum = minimum or -9223372036854775808
    self.minimum = minimum
    if self.minimum > self.maximum then
        self.maximum = self.minimum
    end
    if self.value < minimum then
        self:setValue(minimum)
    end
end

function UISpinBox:getMinimum()
    return self.minimum
end

function UISpinBox:setMaximum(maximum)
    maximum = maximum or 9223372036854775807
    self.maximum = maximum
    if self.value > maximum then
        self:setValue(maximum)
    end
end

function UISpinBox:getMaximum()
    return self.maximum
end

function UISpinBox:setStep(step)
    self.step = step or 1
end

function UISpinBox:setMouseScroll(mouseScroll)
    self.mouseScroll = mouseScroll
end

function UISpinBox:getMouseScroll()
    return self.mouseScroll
end

function UISpinBox:upSpin()
    self:setValue(self.value + self.step)
end

function UISpinBox:downSpin()
    self:setValue(self.value - self.step)
end

function UISpinBox:setFormattedValue(value)  
    self.originalValue = value  
    self:setText(comma_value(value))  
    self.value = value  
end  
  
function UISpinBox:getFormattedValue()  
    if self.originalValue then  
        return self.originalValue  
    end  
    local text = self:getText() or ""  
    text = text:gsub(",", "")  
    return tonumber(text) or 0  
end  
  
function UISpinBox:setFormattedMode(enabled)  
    self.formattedMode = enabled  
    if enabled then  
        self:setValidCharacters('0123456789,')  
    else  
        self:setValidCharacters('0123456789')  
    end  
end