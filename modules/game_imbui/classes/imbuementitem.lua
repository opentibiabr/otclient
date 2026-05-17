if not ImbuementItem then
  ImbuementItem = {
    window = nil,
    confirmWindow = nil,
    lastselectedwidget = nil,
    selectedSlot = 0,
    itemId = 0,
    tier = 0,
    slots = 0,
    activeSlots = {},
    availableImbuements = {},
    needItems = {},
  }
end

ImbuementItem.__index = ImbuementItem

local self = ImbuementItem
function ImbuementItem.setup(itemId, tier, slots, activeSlots, availableImbuements, needItems)
    self.itemId = itemId
    self.tier = tier
    self.slots = slots

    self.activeSlots = {}
    for i = 0, slots - 1 do
        self.activeSlots["slot"..i] = activeSlots[i] or {}
    end
    self.availableImbuements = availableImbuements or {}
    self.needItems = needItems or {}

    for i = 0, 2 do
        Imbuement.clearImbue:recursiveGetChildById("slot"..i):setBorderWidth(0)
        Imbuement.selectImbue:recursiveGetChildById("slot"..i):setBorderWidth(0)
    end

    self.selectedSlot = 0
    self.onSelectImbuementSlot(self.selectedSlot)

    -- Verificar se o slot 0 tem um imbuement ativo e passar para updateWindowState
    local imbuement = self.activeSlots["slot0"]
    self.updateWindowState(imbuement)

    self.configureWindow(Imbuement.selectImbue)
    self.configureWindow(Imbuement.clearImbue)
end

function ImbuementItem.configureWindow(window)
    local slots = window:recursiveGetChildById("slots")
    for i = 1, 3 do
        local slotWidget = slots:getChildById("slot"..i - 1)
        if slotWidget then
            slotWidget.resource:setImageSource("/images/game/imbuing/icons/0")
            if i <= self.slots then
                slotWidget:setVisible(true)
                local imbuement = self.activeSlots["slot"..i - 1]
                if imbuement and imbuement[1] then
                    if imbuement[1].id and imbuement[1].id ~= 0 then
                        slotWidget.resource:setImageSource("/images/game/imbuing/icons/" .. imbuement[1]["imageId"])
                    end
                end
            else
                slotWidget:setVisible(false)
            end
        end
    end
    
    local itemName = getItemNameById(self.itemId)
    local itemWidget = window:recursiveGetChildById("item")
    if itemWidget then
        itemWidget:setItemId(self.itemId)
        itemWidget:setImageSmooth(true)
        itemWidget:setItemCount(1)
    end

    local itemInformation = window:recursiveGetChildById("titleInformation")
    if itemInformation then
        itemInformation:setText(string.capitalize(itemName))
    end
end

function ImbuementItem.onSelectSlot(widget)
    local slot = widget:getId()
    ImbuementItem.onSelectImbuementSlot(widget.slot)
    local imbuement = self.activeSlots[slot]
    self.updateWindowState(imbuement)
end

function ImbuementItem.updateWindowState(imbuement)
    if imbuement and imbuement[1] and imbuement[1].id ~= 0 then
        Imbuement:toggleMenu("clearImbue")
        self.window = Imbuement.clearImbue
        self.onSelectSlotClear(imbuement)
    else
        Imbuement:toggleMenu("selectImbue")
        self.window = Imbuement.selectImbue
        self.onSelectSlotImbue()
    end
end

function ImbuementItem.onSelectImbuementSlot(slot)
    Imbuement.clearImbue:recursiveGetChildById("slot"..self.selectedSlot):setBorderWidth(0)
    Imbuement.selectImbue:recursiveGetChildById("slot"..self.selectedSlot):setBorderWidth(0)

    self.selectedSlot = slot
    Imbuement.clearImbue:recursiveGetChildById("slot"..slot):setBorderWidth(1)
    Imbuement.clearImbue:recursiveGetChildById("slot"..slot):setBorderColor("white")
    Imbuement.selectImbue:recursiveGetChildById("slot"..slot):setBorderWidth(1)
    Imbuement.selectImbue:recursiveGetChildById("slot"..slot):setBorderColor("white")
end

function ImbuementItem:shutdown()
    self.window = nil
    self.itemId = 0
    self.tier = 0
    self.slots = 0
    self.activeSlots = {}
    self.availableImbuements = {}
    self.needItems = {}
    if self.confirmWindow then
        self.confirmWindow:destroy()
    end

    if self.lastselectedwidget then
        self.lastselectedwidget:destroy()
        self.lastselectedwidget = nil
    end
    self.confirmWindow = nil
end

function ImbuementItem.onSelectSlotClear(imbuement)
    local title = self.window.cleanImbuePanel:getChildById("title")
    if title then
        title:setText(string.format('Clear Imbuement "%s"', imbuement[1].name))
    end

    local cleanImbuementsDetails = self.window:recursiveGetChildById("cleanImbuementsDetails")
    if cleanImbuementsDetails then
        cleanImbuementsDetails:setText('')
    end

    local timeRemaining = self.window:recursiveGetChildById("timeRemaining")
    if timeRemaining then
        local time = imbuement[1].duration or 0
        timeRemaining:setMinimum(0)
        timeRemaining:setMaximum(time)
        timeRemaining:setValue(imbuement[2], 0, time)
    end

    local imbuementReqContent = self.window:recursiveGetChildById("imbuementReqContent")
    if imbuementReqContent then
        local hours = string.format("%02.f", math.floor(imbuement[2]/3600))
        local mins = string.format("%02.f", math.floor(imbuement[2]/60 - (hours*60)))

        imbuementReqContent.time.textLabel:setText(string.format("%dh %dmin", hours, mins))
        imbuementReqContent.time.onHoverChange = function(widget, hovered, itemName, hasItem)
            if hovered then
                cleanImbuementsDetails:setText(tr("Show the time the imbuement is still active for."))
            else
                cleanImbuementsDetails:setText("")
            end
        end
    end

    local clearImbuementsList = self.window:recursiveGetChildById("clearImbuementsList")
    clearImbuementsList:destroyChildren()

    local widget = g_ui.createWidget("SlotImbuing", clearImbuementsList)
    widget.resource:setImageSource("/images/game/imbuing/icons/" .. imbuement[1]["imageId"])
    widget:setBorderWidth(1)
    widget:setBorderColor("white")

    local selectedImbuementContent = self.window:recursiveGetChildById("selectedImbuementContent")
    if selectedImbuementContent then
        local imbuementsDetails = selectedImbuementContent:recursiveGetChildById("imbuementsDetails")
        if imbuementsDetails then
            imbuementsDetails:setText(imbuement[1].description or "")
        end
    end

    local balance = getPlayerBalance()
    local clearButton = self.window:recursiveGetChildById("clear")
    if clearButton then
        clearButton:setEnabled(balance >= imbuement[3])
        clearButton.onClick = function()
            if self.confirmWindow then
                self.confirmWindow:destroy()
                self.confirmWindow = nil
            end

            Imbuement.hide()

            local function confirm()
                g_game.clearImbuement(self.selectedSlot)
                self.confirmWindow:destroy()
                self.confirmWindow = nil

                Imbuement.show()
            end

            local function cancelFunc()
                if self.confirmWindow then
                    self.confirmWindow:destroy()
                    self.confirmWindow = nil
                end

                Imbuement.show()
            end

            self.confirmWindow = displayGeneralBox(tr('Confirm Clearing'), tr("Do you wish to spend %s gold coins to clear the imbuement \"%s\" from your item?", comma_value(imbuement[3]), string.capitalize(imbuement[1].name)),
            { { text=tr('Yes'), callback=confirm },
                { text=tr('No'), callback=cancelFunc },
            }, confirm, cancelFunc)
        end

        if balance >= imbuement[3] then
            clearButton:setImageSource("/images/game/imbuing/clear")
            clearButton:setImageClip("0 0 128 66")
        else
            clearButton:setImageSource("/images/game/imbuing/imbue_empty")
        end

        clearButton.onHoverChange = function(widget, hovered, itemName, hasItem)
            if hovered then
                cleanImbuementsDetails:setText(tr("Your needs have changed? Click here to clear the imbuement from your item for a fee."))
            else
                cleanImbuementsDetails:setText("")
            end
        end
    end

    local costPanel = self.window:recursiveGetChildById("costPanel")
    if costPanel then
        costPanel.cost:setText(comma_value(imbuement[3]))
        costPanel.cost:setColor(balance < imbuement[3] and "#C04040" or "#C0C0C0")
    end
end

function ImbuementItem.onSelectSlotImbue()
    self.selectBaseType('basicButton')

    self.window:recursiveGetChildById('imbuementsDetails'):setVisible(false)
end

function ImbuementItem.selectBaseType(selectedButtonId)
    self.window:recursiveGetChildById('blockedPanels'):setVisible(true)
    local qualityAndImbuementContent = self.window:recursiveGetChildById("qualityAndImbuementContent")
    if not qualityAndImbuementContent then
        return
    end

    local basicButton = qualityAndImbuementContent.basicButton
    local intricateButton = qualityAndImbuementContent.intricateButton
    local powerfullButton = qualityAndImbuementContent.powerfullButton

    local baseImbuement = 0
    for _, button in pairs({basicButton, intricateButton, powerfullButton}) do
        button:setOn(button:getId() == selectedButtonId)
        if button:getId() == selectedButtonId then
            baseImbuement = button.baseImbuement or 0
        end
    end

    local imbuementsList = self.window:recursiveGetChildById("imbuementsList")
    imbuementsList:setWidth(70)
    imbuementsList:destroyChildren()

    local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")
    imbuementsDetails:setVisible(false)

    local maxWidth = 0
    for id, imbuement in pairs(self.availableImbuements) do
        local imbuementType = imbuement.type
        if imbuementType == nil and imbuement.group then
            if imbuement.group == 'Basic' then imbuementType = 0
            elseif imbuement.group == 'Intricate' then imbuementType = 1
            elseif imbuement.group == 'Powerful' then imbuementType = 2
            end
        end
        if imbuementType == baseImbuement then
            local widget = g_ui.createWidget("SlotImbuing", imbuementsList)
            widget:setId(tostring(id))
            widget.resource:setImageSource("/images/game/imbuing/icons/" .. imbuement.imageId)

            widget.onClick = function()
                ImbuementItem.selectImbuementWidget(widget, imbuement)
            end

            maxWidth = math.min(imbuementsList.maxWidth, maxWidth + imbuementsList.incrementwidth)
        end
    end

    imbuementsList:setWidth(maxWidth)
end

function ImbuementItem.onSelectImbuement(widget)
    local imbuementId = tonumber(widget:getId())
    local imbuement = self.availableImbuements[imbuementId]
    if not imbuement then
        return
    end

    self.window:recursiveGetChildById('blockedPanels'):setVisible(false)

    local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")
    if imbuementReqPanel then
        imbuementReqPanel.title:setText(string.format('Imbue Empty Slot with "%s"', imbuement.name))
    end
    local itensDetails = self.window:recursiveGetChildById("itensDetails")
    if itensDetails then
        itensDetails:setText("")
    end
end

function ImbuementItem.selectImbuementWidget(widget, imbuement)
    if self.lastselectedwidget then
        self.lastselectedwidget:setBorderWidth(1)
        self.lastselectedwidget:setBorderColorTop("#797979")
        self.lastselectedwidget:setBorderColorLeft("#797979")
        self.lastselectedwidget:setBorderColorRight("#2e2e2e")
        self.lastselectedwidget:setBorderColorBottom("#2e2e2e")
    end
    self.lastselectedwidget = widget
    widget:setBorderWidth(1)
    widget:setBorderColor("white")

    self.onSelectImbuement(widget)

    local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")
    if imbuementsDetails then
        imbuementsDetails:setVisible(true)
        imbuementsDetails:setText(imbuement.description or "")
    end

    local requiredItems = self.window:recursiveGetChildById("requiredItems")
    local hasRequiredItems = true
    if requiredItems then
        for i = 1, 3 do
            local itemWidget = requiredItems:getChildById("item"..i)
            if itemWidget then
                local source = imbuement.sources[i]
                if source then
                    itemWidget.item:setItemId(source.item:getId())
                    itemWidget:setVisible(true)
                    local itemCount = self.needItems[source.item:getId()] or 0
                    itemWidget.count:setText(itemCount .."/" .. source.item:getCount())
                    if itemCount >= source.item:getCount() then
                        itemWidget.count:setColor("#C0C0C0")
                    else
                        hasRequiredItems = false
                        itemWidget.count:setColor("#C04040")
                    end

                    itemWidget.onHoverChange = function(widget, hovered)
                        local itensDetails = self.window:recursiveGetChildById("itensDetails")
                        if hovered then
                            local itemCount = self.needItems[source.item:getId()] or 0
                            if itemCount >= source.item:getCount() then
                                itensDetails:setText(string.format("The imbuement you have selected requires %s.", source.description))
                            else
                                itensDetails:setText(string.format("The imbuement requires %s. Unfortunately you do not own the needed amount.", source.description))
                            end
                        else
                            if itensDetails then
                                itensDetails:setText("")
                            end
                        end
                    end
                else
                    itemWidget:setVisible(false)
                end
            end
        end
    end

    local costPanel = self.window:recursiveGetChildById("costPanel")
    if costPanel then
        local cost = imbuement.cost or 0
        costPanel.cost:setText(comma_value(cost))
        local balance = getPlayerBalance()

        if balance < cost then
            hasRequiredItems = false
        end

        costPanel.cost:setColor(balance < cost and "#C04040" or "#C0C0C0")
    end

    local imbueApply = self.window:recursiveGetChildById("imbueApply")
    if imbueApply then
        imbueApply:setEnabled(hasRequiredItems)
        if not hasRequiredItems then
           imbueApply:setImageSource("/images/game/imbuing/imbue_empty")
           imbueApply:setImageClip("0 0 128 66")
        else
            imbueApply:setImageSource("/images/game/imbuing/imbue_green")
        end

        imbueApply.onHoverChange = function(widget, hovered, itemName, hasItem)
            local itensDetails = self.window:recursiveGetChildById("itensDetails")
            if hovered then
                itensDetails:setText(tr("Apply the selected imbuement. This will consume the required astral sources and gold."))
            else
                if itensDetails then
                    itensDetails:setText("")
                end
            end
        end

        imbueApply.onClick = function()
            if self.confirmWindow then
                self.confirmWindow:destroy()
                self.confirmWindow = nil
            end

            Imbuement.hide()

            local function confirm()
                g_game.applyImbuement(self.selectedSlot, imbuement.id)
                self.confirmWindow:destroy()
                self.confirmWindow = nil

                Imbuement.show()
            end

            local function cancelFunc()
                if self.confirmWindow then
                    self.confirmWindow:destroy()
                    self.confirmWindow = nil
                end

                Imbuement.show()
            end

            self.confirmWindow = displayGeneralBox(tr('Confirm Imbuing'), tr("You are about to imbue your item with \"%s\". This will consume the required astral sources and %s\ngold coins. Do you wish to proceed?", string.capitalize(imbuement.name), comma_value(imbuement.cost)),
            { { text=tr('Yes'), callback=confirm },
                { text=tr('No'), callback=cancelFunc },
            }, confirm, cancelFunc)
        end
    end
end