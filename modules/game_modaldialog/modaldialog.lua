controllerModal = Controller:new()

local MINIMUM_WIDTH_QT = 380
local MINIMUM_WIDTH_OLD = 245
local MAXIMUM_WIDTH = 600
local MINIMUM_CHOICES = 4
local MAXIMUM_CHOICES = 10
local BASE_HEIGHT = 40
local MAX_CHOICE_TEXT = 28

local function destroyWindow()
    local ui = controllerModal.ui
    if ui then
        controllerModal:unloadHtml()
    end
end

function controllerModal:onInit()
    controllerModal:registerEvents(g_game, {
        onModalDialog = onModalDialog
    })
end

function controllerModal:onTerminate()
end

function controllerModal:onGameEnd()
    destroyWindow()
end

local function createButtonHandler(id, buttonId, choiceList)
    return function()
        local focusedChoice = choiceList and choiceList:getFocusedChild()
        local choice = (choiceList and choiceList.selectedChoice) or (focusedChoice and focusedChoice.choiceId) or 0xFF
        g_game.answerModalDialog(id, buttonId, choice)
        destroyWindow()
    end
end

local function selectChoiceWidget(choiceList, choiceWidget, reason)
    if not choiceList or not choiceWidget then
        return
    end

    choiceList.selectedChoice = choiceWidget.choiceId
    choiceList.selectedChoiceIndex = choiceWidget.choiceIndex
    choiceList:focusChild(choiceWidget, reason or ActiveFocusReason)
    choiceList:ensureChildVisible(choiceWidget)
end

local function shortText(text, maxLen)
    return #text <= maxLen and text or text:sub(1, maxLen)
end

local function resolveModalButtons(buttons, enterButton, escapeButton)
    if not buttons or #buttons == 0 then
        return enterButton, escapeButton
    end

    local buttonExistsById = {}
    for i = 1, #buttons do
        local buttonId = buttons[i][1]
        buttonExistsById[buttonId] = true
    end

    local firstButtonId = buttons[1][1]
    local lastButtonId = buttons[#buttons][1]

    if not buttonExistsById[enterButton] then
        enterButton = firstButtonId
    end

    if not buttonExistsById[escapeButton] then
        escapeButton = #buttons > 1 and lastButtonId or enterButton
    end

    if enterButton == escapeButton and #buttons > 1 then
        for i = #buttons, 1, -1 do
            local candidateId = buttons[i][1]
            if candidateId ~= enterButton then
                escapeButton = candidateId
                break
            end
        end
    end

    return enterButton, escapeButton
end

local function calculateAndSetWidth(ui, messageLabel, buttonsWidth, message)
    local horizontalPadding = ui:getPaddingLeft() + ui:getPaddingRight()
    local totalButtonsWidth = buttonsWidth + horizontalPadding
    local calculatedWidth = math.max(totalButtonsWidth, g_game.getFeature(GameEnterGameShowAppearance) and
        MINIMUM_WIDTH_OLD or MINIMUM_WIDTH_QT)
    if calculatedWidth > MAXIMUM_WIDTH then
        calculatedWidth = MAXIMUM_WIDTH
    end
    local contentWidth = calculatedWidth - horizontalPadding
    ui:setWidth(contentWidth)
    messageLabel:setWidth(contentWidth)
    messageLabel:setTextWrap(true)
    return calculatedWidth
end

local function calculateChoicesHeight(choiceList, choices, labelHeight)
    if #choices == 0 or not labelHeight then
        return 0
    end
    local visibleChoices = math.min(MAXIMUM_CHOICES, math.max(MINIMUM_CHOICES, #choices))
    local additionalHeight = visibleChoices * labelHeight + choiceList:getPaddingTop() + choiceList:getPaddingBottom()
    choiceList:setHeight(additionalHeight)
    return additionalHeight
end

local function applyFinalHeight(ui, messageLabel, additionalHeight)
    local finalHeight = BASE_HEIGHT + additionalHeight + messageLabel:getHeight()
    ui:setHeight(finalHeight)
    controllerModal:findWidget('#choiceList'):setWidth(ui:getWidth() * 0.9) -- html not work "Width:100%"
end

function onModalDialog(id, title, message, buttons, enterButton, escapeButton, choices, priority)
    destroyWindow()

    -- C++ parse currently uses clientVersion for enter/escape byte order.
    local protocolVersion = g_game.getProtocolVersion()
    local clientVersion = g_game.getClientVersion()
    local protocolAfter970 = protocolVersion > 970
    local clientAfter970 = clientVersion > 970
    if protocolAfter970 ~= clientAfter970 then
        enterButton, escapeButton = escapeButton, enterButton
    end
    enterButton, escapeButton = resolveModalButtons(buttons, enterButton, escapeButton)
    local MINIMUM_WIDTH = g_game.getFeature(GameEnterGameShowAppearance) and MINIMUM_WIDTH_OLD or MINIMUM_WIDTH_QT
    controllerModal:loadHtml('modaldialog.html')
    local ui = controllerModal.ui
    ui:hide()
    ui:grabKeyboard()
    local messageLabel = controllerModal:findWidget('#messageLabel')
    local choiceList = controllerModal:findWidget('#choiceList')
    local buttonsPanel = controllerModal:findWidget('#buttonsPanel')
    local enterFunc = createButtonHandler(id, enterButton, choiceList)
    local escapeFunc = createButtonHandler(id, escapeButton, choiceList)
    local confirmKeysEnabledAt = g_clock.millis() + 180
    local firstChoiceWidget = nil
    ui:setTitle(title)
    messageLabel:html(message)
    local labelHeight = nil
    local buttonsWidth = 0
    local choicesCount = #choices
    if choicesCount > 0 then
        choiceList:setVisible(true)
        for i = 1, choicesCount do
            local choiceId = choices[i][1]
            local choiceName = choices[i][2]
            local displayName = shortText(choiceName, MAX_CHOICE_TEXT)
            local choiceHtml = string.format('<div class="choice-item" style="width: %d;" data-choice-id="%d">%s</div>',
                MINIMUM_WIDTH, choiceId, displayName)
            local choiceWidget = controllerModal:createWidgetFromHTML(choiceHtml, choiceList)
            if choiceWidget then
                choiceWidget.choiceId = choiceId
                choiceWidget.choiceIndex = i
                if #choiceName > MAX_CHOICE_TEXT then
                    choiceWidget:setTooltip(choiceName)
                end
                if not labelHeight then
                    labelHeight = choiceWidget:getHeight()
                end
                choiceWidget.onClick = function()
                    selectChoiceWidget(choiceList, choiceWidget, MouseFocusReason)
                end
                choiceWidget.onDoubleClick = enterFunc
                if not firstChoiceWidget then
                    firstChoiceWidget = choiceWidget
                end
            end
        end
    else
        choiceList:setVisible(false)
    end
    for i = #buttons, 1, -1 do
        local buttonId = buttons[i][1]
        local buttonText = buttons[i][2]
        local buttonHtml = string.format('<button class="modal-button">%s</button>', buttonText)
        local button = controllerModal:createWidgetFromHTML(buttonHtml, buttonsPanel)

        if button then
            button.onClick = createButtonHandler(id, buttonId, choiceList)
            buttonsWidth = buttonsWidth + button:getWidth() + button:getMarginLeft() + button:getMarginRight()
        end
    end
    ui.onKeyDown = function(_, keyCode, keyboardModifiers)
        if keyboardModifiers ~= KeyboardNoModifier then
            return false
        end

        if keyCode == KeyEscape then
            if not ui:isVisible() or g_clock.millis() < confirmKeysEnabledAt then
                return true
            end
            escapeFunc()
            return true
        end

        if keyCode == KeyEnter then
            if not ui:isVisible() or g_clock.millis() < confirmKeysEnabledAt then
                return true
            end
            enterFunc()
            return true
        end

        if keyCode == KeyUp and choiceList and choiceList:isVisible() then
            choiceList:focusPreviousChild(KeyboardFocusReason)
            selectChoiceWidget(choiceList, choiceList:getFocusedChild(), KeyboardFocusReason)
            return true
        end

        if keyCode == KeyDown and choiceList and choiceList:isVisible() then
            choiceList:focusNextChild(KeyboardFocusReason)
            selectChoiceWidget(choiceList, choiceList:getFocusedChild(), KeyboardFocusReason)
            return true
        end

        return false
    end
    calculateAndSetWidth(ui, messageLabel, buttonsWidth, message)
    local additionalHeight = calculateChoicesHeight(choiceList, choices, labelHeight)
    controllerModal:scheduleEvent(function()
        applyFinalHeight(ui, messageLabel, additionalHeight)
        ui:show()
        ui:raise()
        ui:focus()
        ui:grabKeyboard()
        confirmKeysEnabledAt = g_clock.millis() + 180
        if firstChoiceWidget then
            selectChoiceWidget(choiceList, firstChoiceWidget, KeyboardFocusReason)
        end
    end, 222, "lazyHeightHtml")
end
