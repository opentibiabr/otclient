return function(context)
  local scrollApi = {
    window = nil,
    itemId = 51442,
    confirmWindow = nil,
    availableImbuements = {},
    needItems = {}
  }

  scrollApi.__index = scrollApi

  local self = scrollApi
function scrollApi.setup(availableImbuements, needItems)
    self.availableImbuements = availableImbuements or {}
    self.needItems = needItems or {}
    self.window = context.imbuement.scrollImbue

    local itemWidget = self.window:recursiveGetChildById("itemScroll")
    if itemWidget then
        itemWidget:setItemId(self.itemId)
        itemWidget:setImageSmooth(true)
        itemWidget:setItemCount(1)
    end

    self.onSelectSlotImbue()
end

function scrollApi:shutdown()
    if self.confirmWindow then
        self.confirmWindow:destroy()
    end

    self.window = nil
    self.confirmWindow = nil
    self.lastselectedwidget = nil
    self.availableImbuements = {}
    self.needItems = {}
end

function scrollApi.onSelectSlotImbue()
    self.selectBaseType('powerfullButton')
    self.window:recursiveGetChildById('imbuementsDetails'):setVisible(false)
end

function scrollApi.selectBaseType(selectedButtonId)
    local qualityAndImbuementContent = self.window:recursiveGetChildById("qualityAndImbuementContent")
    if not qualityAndImbuementContent then
        return
    end

    local intricateButton = qualityAndImbuementContent.intricateButton
    local powerfullButton = qualityAndImbuementContent.powerfullButton

    local selectedBaseType = 1
    for _, button in pairs({intricateButton, powerfullButton}) do
        button:setOn(button:getId() == selectedButtonId)
        if button:getId() == selectedButtonId then
            selectedBaseType = button.baseImbuement or 1
        end
    end

    local imbuementsList = self.window:recursiveGetChildById("imbuementsList")
    imbuementsList:destroyChildren()

    local imbuementsDetails = self.window:recursiveGetChildById("imbuementsDetails")
    imbuementsDetails:setVisible(false)

    local selected = false
    local matchedCount = 0

    for id, imbuement in ipairs(self.availableImbuements) do
        local imbuementType = imbuement.type
        if imbuementType == nil and imbuement.group then
            if imbuement.group == 'Basic' then imbuementType = 0
            elseif imbuement.group == 'Intricate' then imbuementType = 1
            elseif imbuement.group == 'Powerful' then imbuementType = 2
            end
        end
                
        if imbuementType == selectedBaseType then
            matchedCount = matchedCount + 1
            local widget = g_ui.createWidget("SlotImbuing", imbuementsList)
            widget:setId(tostring(id))
            widget.resource:setImageSource("//images/game/imbuing/icons//" .. imbuement.imageId)

            if not selected then
                scrollApi.selectImbuementWidget(widget, imbuement)
                selected = true
            end

            widget.onClick = function()
                scrollApi.selectImbuementWidget(widget, imbuement)
            end

        end
    end
    
end

function scrollApi.selectImbuementWidget(widget, imbuement)
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
        for i = 1, 4 do
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
        costPanel.cost:setText(context.commaValue(cost))
        local balance = context.getPlayerBalance()

        if balance < cost then
            hasRequiredItems = false
        end

        costPanel.cost:setColor(balance < cost and "#C04040" or "#C0C0C0")
    end

    local imbuescrollApply = self.window:recursiveGetChildById("imbuescrollApply")
    if imbuescrollApply then
        imbuescrollApply:setEnabled(hasRequiredItems)
        if not hasRequiredItems then
           imbuescrollApply:setImageSource("/game_imbuing/images/imbue_empty")
           imbuescrollApply:setImageClip("0 0 128 66")
        else
            imbuescrollApply:setImageSource("/game_imbuing/images/imbue_green")
        end

        imbuescrollApply.onHoverChange = function(widget, hovered, itemName, hasItem)
            local itensDetails = self.window:recursiveGetChildById("itensDetails")
            if hovered then
                itensDetails:setText(tr("Apply the selected imbuement. This will consume the required astral sources and gold."))
            else
                if itensDetails then
                    itensDetails:setText("")
                end
            end
        end

        imbuescrollApply.onClick = function()
            if self.confirmWindow then
                self.confirmWindow:destroy()
                self.confirmWindow = nil
            end

            context.imbuement.hide()

            local function confirm()
                g_game.applyImbuement(0, imbuement.id)
                self.confirmWindow:destroy()
                self.confirmWindow = nil

                context.imbuement.show()
            end

            local function cancelFunc()
                if self.confirmWindow then
                    self.confirmWindow:destroy()
                    self.confirmWindow = nil
                end

                context.imbuement.show()
            end

            self.confirmWindow = displayGeneralBox(tr('Confirm Imbuing'), tr("You are about to imbue your item with \"%s\". This will consume the required astral sources and %s\ngold coins. Do you wish to proceed?", context.capitalize(imbuement.name), context.commaValue(imbuement.cost)),
            { { text=tr('Yes'), callback=confirm },
                { text=tr('No'), callback=cancelFunc },
            }, confirm, cancelFunc)
        end
    end
end

function scrollApi.onSelectImbuement(widget)
    local imbuementId = tonumber(widget:getId())
    local imbuement = self.availableImbuements[imbuementId]
    if not imbuement then
        return
    end


    local imbuementReqPanel = self.window:recursiveGetChildById("imbuementReqPanel")
    if imbuementReqPanel then
        imbuementReqPanel.title:setText(string.format('Imbue Blank Scroll with "%s"', imbuement.name))
    end
    local itensDetails = self.window:recursiveGetChildById("itensDetails")
    if itensDetails then
        itensDetails:setText("")
    end
end

  return scrollApi
end
