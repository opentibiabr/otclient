Imbuing = {}
local imbuingWindow
local bankGold = 0
local inventoryGold = 0
local itemImbuements = {}
local emptyImbue
local groupsCombo
local imbueLevelsCombo
local protectionBtn
local clearImbue
local selectedImbue
local imbueItems = {}
local protection = false
local clearConfirmWindow
local imbueConfirmWindow
local infoPanel

local function getCorrectIconId(id)
    local iconId = id
    if iconId >= 16 then iconId = iconId + 3 end -- pula 16, 17, 18
    if iconId >= 22 then iconId = iconId + 3 end -- pula 22, 23, 24
    if iconId >= 43 then iconId = iconId + 3 end -- pula 43, 44, 45
    if iconId >= 61 then iconId = iconId + 3 end -- pula 61, 62, 63
    if iconId >= 79 then iconId = iconId + 3 end -- pula 79, 80, 81
    return iconId
end

function init()
    connect(g_game, {
        onGameEnd = hide,
        onResourcesBalanceChange = Imbuing.onResourcesBalanceChange,
        onImbuementWindow = Imbuing.onImbuementWindow,
        onCloseImbuementWindow = Imbuing.onCloseImbuementWindow
    })

    imbuingWindow = g_ui.displayUI('imbuing')
    emptyImbue = imbuingWindow.emptyImbue
    groupsCombo = emptyImbue.groups
    imbueLevelsCombo = emptyImbue.imbuement
    protectionBtn = emptyImbue.protection
    clearImbue = imbuingWindow.clearImbue
    infoPanel = imbuingWindow.infoPanel
    imbuingWindow:hide()
    local player = g_game.getLocalPlayer()
    if player then
        bankGold = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
        inventoryGold = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
        imbuingWindow.balance:setText(tr(comma_value (player:getTotalMoney())))
    end

    groupsCombo.onOptionChange = function(widget)
        imbueLevelsCombo:clearOptions()
        if itemImbuements ~= nil then
            local selectedGroup = groupsCombo:getCurrentOption().text
            for _, imbuement in ipairs(itemImbuements) do
                if imbuement['group'] == selectedGroup then
                    emptyImbue.imbuement:addOption(imbuement['name'])
                end
            end
            imbueLevelsCombo.onOptionChange(imbueLevelsCombo) -- update options
        end
    end

    imbueLevelsCombo.onOptionChange = function(widget)
        setProtection(false)
        local selectedGroup = groupsCombo:getCurrentOption().text
        for _, imbuement in ipairs(itemImbuements) do
            if imbuement['group'] == selectedGroup then
                if #imbuement['sources'] == widget.currentIndex then
                    selectedImbue = imbuement
                    local hasAllItems = true
                    
                    for i, source in ipairs(imbuement['sources']) do
                        local itemFound = false
                        for _, item in ipairs(imbueItems) do
                            if item:getId() == source['item']:getId() then
                                itemFound = true
                                if item:getCount() >= source['item']:getCount() then
                                    emptyImbue.requiredItems:getChildByIndex(i).count:setColor('white')
                                else
                                    hasAllItems = false
                                    emptyImbue.requiredItems:getChildByIndex(i).count:setColor('red')
                                end
                                emptyImbue.requiredItems:getChildByIndex(i).count:setText(item:getCount() .. '/' .. source['item']:getCount())
                            end
                        end
                        if not itemFound then
                            hasAllItems = false
                            emptyImbue.requiredItems:getChildByIndex(i).count:setText('0/' .. source['item']:getCount())
                            emptyImbue.requiredItems:getChildByIndex(i).count:setColor('red')
                        end
                        emptyImbue.requiredItems:getChildByIndex(i).item:setItemId(source['item']:getId())
                        emptyImbue.requiredItems:getChildByIndex(i).item:setTooltip('The imbuement requires ' .. source['description'] .. '.')
                    end
                    
                    for i = 3, widget.currentIndex + 1, -1 do
                        emptyImbue.requiredItems:getChildByIndex(i).count:setText('')
                        emptyImbue.requiredItems:getChildByIndex(i).item:setItemId(0)
                        emptyImbue.requiredItems:getChildByIndex(i).item:setTooltip('')
                    end
                    emptyImbue.protectionCost:setText((comma_value(imbuement['protectionCost'])))
                    emptyImbue.cost:setText(comma_value(imbuement['cost']))
                    
                    -- Verificar se tem todos os itens e gold suficiente
                    local hasEnoughGold = false
                    if not protection then
                        hasEnoughGold = (bankGold + inventoryGold) >= imbuement['cost']
                        if not hasEnoughGold then
                            emptyImbue.cost:setColor('red')
                        else
                            emptyImbue.cost:setColor('white')
                        end
                    else
                        hasEnoughGold = (bankGold + inventoryGold) >= (imbuement['cost'] + imbuement['protectionCost'])
                        if not hasEnoughGold then
                            emptyImbue.cost:setColor('red')
                        else
                            emptyImbue.cost:setColor('white')
                        end
                    end
                    
                    -- Habilitar/desabilitar botão de imbue baseado em itens E gold
                    if hasAllItems and hasEnoughGold then
                        emptyImbue.imbue:setEnabled(true)
                        emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_green')
                    else
                        emptyImbue.imbue:setEnabled(false)
                        emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_empty')
                    end
                    
                    -- Verificar se o botão de proteção deve ser desabilitado
                    if (bankGold + inventoryGold) < imbuement['protectionCost'] then
                        protectionBtn:setEnabled(false)
                        emptyImbue.protection:setImageSource('/images/game/imbuing/useprotection-disabled')
                        emptyImbue.protectionCost:setColor('red')
                    else
                        protectionBtn:setEnabled(true)
                        emptyImbue.protection:setImageSource('/images/game/imbuing/100percent')
                        emptyImbue.protectionCost:setColor('white')
                    end
                    emptyImbue.successRate:setText(imbuement['successRate'] .. '%')
                    if selectedImbue['successRate'] > 50 then
                        emptyImbue.successRate:setColor('white')
                    else
                        emptyImbue.successRate:setColor('red')
                    end
                    emptyImbue.description:setText(imbuement['description'])
                end
            end
        end
    end

    protectionBtn.onClick = function()
        setProtection(not protection)
    end

    -- Configurar hover events para exibir tooltips no painel
    setupTooltipEvents()
end

function setProtection(value)
    protection = value
    if protection then
        if not selectedImbue then
            protection = false
            return
        end
        emptyImbue.cost:setText(comma_value(selectedImbue['cost'] + selectedImbue['protectionCost']))
        emptyImbue.successRate:setText('100%')
        emptyImbue.successRate:setColor('green')
        protectionBtn:setImageClip(torect('66 0 66 66'))
        
        -- Verificar se há gold suficiente para o custo total com proteção
        if (bankGold + inventoryGold) < (selectedImbue['cost'] + selectedImbue['protectionCost']) then
            emptyImbue.cost:setColor('red')
        else
            emptyImbue.cost:setColor('white')
        end
    else
        if selectedImbue then
            emptyImbue.cost:setText(comma_value(selectedImbue['cost']))
            emptyImbue.successRate:setText(selectedImbue['successRate'] .. '%')
            if selectedImbue['successRate'] > 50 then
                emptyImbue.successRate:setColor('white')
            else
                emptyImbue.successRate:setColor('red')
            end
            
            -- Verificar se há gold suficiente para o custo sem proteção
            if (bankGold + inventoryGold) < selectedImbue['cost'] then
                emptyImbue.cost:setColor('red')
            else
                emptyImbue.cost:setColor('white')
            end
            protectionBtn:setImageClip(torect('0 0 66 66'))
        end
    end
    
    -- Re-verificar o estado do botão de imbue quando a proteção mudar
    if selectedImbue then
        local hasAllItems = true
        for i, source in ipairs(selectedImbue['sources']) do
            local itemFound = false
            for _, item in ipairs(imbueItems) do
                if item:getId() == source['item']:getId() then
                    itemFound = true
                    if item:getCount() < source['item']:getCount() then
                        hasAllItems = false
                        break
                    end
                end
            end
            if not itemFound then
                hasAllItems = false
                break
            end
        end
        
        local hasEnoughGold = false
        if protection then
            hasEnoughGold = (bankGold + inventoryGold) >= (selectedImbue['cost'] + selectedImbue['protectionCost'])
        else
            hasEnoughGold = (bankGold + inventoryGold) >= selectedImbue['cost']
        end
        
        -- Habilitar/desabilitar botão de imbue baseado em itens E gold
        if hasAllItems and hasEnoughGold then
            emptyImbue.imbue:setEnabled(true)
            emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_green')
        else
            emptyImbue.imbue:setEnabled(false)
            emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_empty')
        end
    end
end

function terminate()
    disconnect(g_game, {
        onGameEnd = hide,
        onResourcesBalanceChange = Imbuing.onResourcesBalanceChange,
        onImbuementWindow = Imbuing.onImbuementWindow,
        onCloseImbuementWindow = Imbuing.onCloseImbuementWindow
    })

    imbuingWindow:destroy()
end

function resetSlots()
    emptyImbue:setVisible(false)
    clearImbue:setVisible(false)
    if infoPanel then 
        local tooltipContent = infoPanel:recursiveGetChildById('tooltipContent')
        if tooltipContent then tooltipContent:setText('') end
    end
    for i = 1, 3 do
        local slot = imbuingWindow.itemInfo.slots:getChildByIndex(i)
        slot:setText('Slot ' .. i)
        slot:getChildById('icon'):setVisible(false)
        slot:setEnabled(false)
        slot:setTooltip(
            'Items can have up to three imbuements slots. This slot is not available for this item.')
        slot.onClick = nil
    end
end

function selectSlot(widget, slotId, activeSlot)
    local slotIcon = widget:getChildById('icon')

    if activeSlot then
        emptyImbue:setVisible(false)
        widget:setText('')
        slotIcon:setVisible(true)
        local id = activeSlot[1]['id'] or 1
        slotIcon:setImageSource('/images/game/imbuing/icons/' .. getCorrectIconId(id))
        slotIcon:setImageClip(torect('0 0 64 64'))
        clearImbue.title:setText('Clear Imbuement "' .. activeSlot[1]['name'] .. '"')
        clearImbue.groups:clearOptions()
        clearImbue.groups:addOption(activeSlot[1]['group'])
        clearImbue.imbuement:clearOptions()
        clearImbue.imbuement:addOption(activeSlot[1]['name'])
        clearImbue.description:setText(activeSlot[1]['description'])

        local hours = string.format('%02.f', math.floor(activeSlot[2] / 3600))
        local mins = string.format('%02.f', math.floor(activeSlot[2] / 60 - (hours * 60)))
        
        local totalTime = activeSlot[1].duration or 72000
        local timeRemaining = clearImbue.time.timerContainer.timeRemaining
        
        if timeRemaining then
            timeRemaining:setMinimum(0)
            timeRemaining:setMaximum(totalTime)
            timeRemaining:setValue(activeSlot[2], 0, totalTime)
        end

        clearImbue.time.timerContainer.timeRemaining.text:setText(hours .. ':' .. mins .. 'h')
        clearImbue.cost:setText(comma_value(activeSlot[3]))
        if (bankGold + inventoryGold) < activeSlot[3] then
            clearImbue.clear:setEnabled(false)
            clearImbue.clear:setImageSource('/images/game/imbuing/imbue_empty')
            clearImbue.cost:setColor('red')
        end

        local yesCallback = function()
            g_game.clearImbuement(slotId)
            widget:setText('Slot ' .. (slotId + 1))
            slotIcon:setVisible(true)
            if clearConfirmWindow then
                clearConfirmWindow:destroy()
                clearConfirmWindow = nil
            end
        end
        local noCallback = function()
            imbuingWindow:show()
            if clearConfirmWindow then
                clearConfirmWindow:destroy()
                clearConfirmWindow = nil
            end
        end

        clearImbue.clear.onClick = function()
            imbuingWindow:hide()
            clearConfirmWindow = displayGeneralBox(tr('Confirm Clearing'),
                                                   tr(
                                                       'Do you wish to spend ' .. activeSlot[3] ..
                                                           ' gold coins to clear the imbuement "' ..
                                                           activeSlot[1]['name'] .. '" from your item?'), {
                {
                    text = tr('Yes'),
                    callback = yesCallback
                },
                {
                    text = tr('No'),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)
        end

        clearImbue:setVisible(true)
    else
        emptyImbue:setVisible(true)
        clearImbue:setVisible(false)

        local yesCallback = function()
            g_game.applyImbuement(slotId, selectedImbue['id'], protection)
            if clearConfirmWindow then
                clearConfirmWindow:destroy()
                clearConfirmWindow = nil
            end
            slotIcon:setVisible(true)
            local id = selectedImbue['id'] or 1
            slotIcon:setImageSource('/images/game/imbuing/icons/' .. getCorrectIconId(id))
            imbuingWindow:show()
        end
        local noCallback = function()
            imbuingWindow:show()
            if clearConfirmWindow then
                clearConfirmWindow:destroy()
                clearConfirmWindow = nil
            end
        end

        emptyImbue.imbue.onClick = function()
            imbuingWindow:hide()
            local cost = selectedImbue['cost']
            local successRate = selectedImbue['successRate']
            if protection then
                cost = cost + selectedImbue['protectionCost']
                successRate = '100'
            end
            clearConfirmWindow = displayGeneralBox(tr('Confirm Imbuing Attempt'),
                                                   'You are about to imbue your item with "' .. selectedImbue['name'] ..
                                                       '".\nYour chance to succeed is ' .. successRate ..
                                                       '%. It will consume the required astral sources and ' .. cost ..
                                                       ' gold coins.\nDo you wish to proceed?', {
                {
                    text = tr('Yes'),
                    callback = yesCallback
                },
                {
                    text = tr('No'),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)
        end
    end
end

function Imbuing.onImbuementWindow(itemId, slots, activeSlots, imbuements, needItems)
    if not itemId then
        return
    end
    resetSlots()
    imbueItems = table.copy(needItems)
    imbuingWindow.itemInfo.item:setItemId(itemId)

    for i = 1, slots do
        local slot = imbuingWindow.itemInfo.slots:getChildByIndex(i)
        slot.onClick = function(widget)
            selectSlot(widget, i - 1)
        end
        slot:setTooltip(
            'Use this slot to imbue your item. Depending on the item you can have up to three different imbuements.')
        slot:setEnabled(true)

        if slot:getId() == 'slot0' then
            selectSlot(slot, i - 1)
        end
    end

    for i, slot in pairs(activeSlots) do
        local activeSlotBtn = imbuingWindow.itemInfo.slots:getChildById('slot' .. i)
        activeSlotBtn.onClick = function(widget)
            selectSlot(widget, i, slot)
        end

        -- Atualiza o ícone de todos os slots ativos imediatamente
        local slotIcon = activeSlotBtn:getChildById('icon')
        activeSlotBtn:setText('')
        slotIcon:setVisible(true)
        local id = slot[1]['id'] or 1
        slotIcon:setImageSource('/images/game/imbuing/icons/' .. getCorrectIconId(id))

        if activeSlotBtn:getId() == 'slot0' then
            selectSlot(activeSlotBtn, i, slot)
        end
    end

    if imbuements ~= nil then
        groupsCombo:clearOptions()
        imbueLevelsCombo:clearOptions()
        itemImbuements = table.copy(imbuements)
        for _, imbuement in ipairs(itemImbuements) do
            if not groupsCombo:isOption(imbuement['group']) then
                groupsCombo:addOption(imbuement['group'])
            end
        end
    end
    
    -- Reconfigurar eventos de hover após carregar os slots
    setupTooltipEvents()
    show()
end

function Imbuing.onResourcesBalanceChange(balance, oldBalance, type)
    if type == ResourceTypes.BANK_BALANCE then
        bankGold = balance
    elseif type == ResourceTypes.GOLD_EQUIPPED then
        inventoryGold = balance
    end
    local player = g_game.getLocalPlayer()
    if player then
        if type == ResourceTypes.BANK_BALANCE or type == ResourceTypes.GOLD_EQUIPPED then
            imbuingWindow.balance:setText(tr(comma_value (player:getTotalMoney())))
            
            -- Re-verificar o estado dos botões quando o saldo mudar
            if selectedImbue and emptyImbue:isVisible() then
                -- Verificar botão de proteção
                if (bankGold + inventoryGold) < selectedImbue['protectionCost'] then
                    protectionBtn:setEnabled(false)
                    emptyImbue.protection:setImageSource('/images/game/imbuing/useprotection-disabled')
                    emptyImbue.protectionCost:setColor('red')
                else
                    protectionBtn:setEnabled(true)
                    emptyImbue.protection:setImageSource('/images/game/imbuing/100percent')
                    emptyImbue.protectionCost:setColor('white')
                end
                
                -- Verificar se tem todos os itens
                local hasAllItems = true
                for i, source in ipairs(selectedImbue['sources']) do
                    local itemFound = false
                    for _, item in ipairs(imbueItems) do
                        if item:getId() == source['item']:getId() then
                            itemFound = true
                            if item:getCount() < source['item']:getCount() then
                                hasAllItems = false
                                break
                            end
                        end
                    end
                    if not itemFound then
                        hasAllItems = false
                        break
                    end
                end
                
                -- Verificar gold suficiente
                local hasEnoughGold = false
                if protection then
                    hasEnoughGold = (bankGold + inventoryGold) >= (selectedImbue['cost'] + selectedImbue['protectionCost'])
                    if not hasEnoughGold then
                        emptyImbue.cost:setColor('red')
                    else
                        emptyImbue.cost:setColor('white')
                    end
                else
                    hasEnoughGold = (bankGold + inventoryGold) >= selectedImbue['cost']
                    if not hasEnoughGold then
                        emptyImbue.cost:setColor('red')
                    else
                        emptyImbue.cost:setColor('white')
                    end
                end
                
                -- Habilitar/desabilitar botão de imbue baseado em itens E gold
                if hasAllItems and hasEnoughGold then
                    emptyImbue.imbue:setEnabled(true)
                    emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_green')
                else
                    emptyImbue.imbue:setEnabled(false)
                    emptyImbue.imbue:setImageSource('/images/game/imbuing/imbue_empty')
                end
            end
        end
    end
end

function Imbuing.onCloseImbuementWindow()
    resetSlots()
end

function hide()
    g_game.closeImbuingWindow()
    imbuingWindow:hide()
end

function show()
    imbuingWindow:show()
    imbuingWindow:raise()
    imbuingWindow:focus()
end

function toggle()
    if imbuingWindow:isVisible() then
        return hide()
    end
    show()
end

-- Função para formatar texto com quebra de linha automática
function formatTooltipText(text)
    if not text then return '' end
    
    -- Definir largura máxima aproximada (em caracteres)
    local maxWidth = 240
    
    local formattedText = ''
    local currentLine = ''
    
    -- Dividir o texto em palavras
    for word in text:gmatch("%S+") do
        -- Se adicionar a palavra exceder a largura máxima
        if #currentLine + #word + 1 > maxWidth and #currentLine > 0 then
            formattedText = formattedText .. currentLine .. '\n'
            currentLine = word
        else
            if #currentLine > 0 then
                currentLine = currentLine .. ' ' .. word
            else
                currentLine = word
            end
        end
    end
    
    -- Adicionar a última linha
    if #currentLine > 0 then
        formattedText = formattedText .. currentLine
    end
    
    return formattedText
end

-- Função para configurar eventos de hover em elementos com tooltip
function setupTooltipEvents()
    if not infoPanel then return end
    
    local tooltipContent = infoPanel:recursiveGetChildById('tooltipContent')
    if not tooltipContent then return end
    
    -- Função para adicionar hover a um widget
    local function addHoverToWidget(widget)
        if not widget or not widget.getTooltip then return end
        
        widget.onHoverChange = function(self, hovered)
            if hovered then
                local tooltip = self:getTooltip()
                if tooltip and tooltip ~= '' then
                    -- Adicionar quebras de linha para textos longos
                    local formattedText = formatTooltipText(tooltip)
                    tooltipContent:setText(formattedText)
                else
                    tooltipContent:setText('')
                end
            else
                tooltipContent:setText('')
            end
        end
    end
    
    -- Adicionar hover aos botões principais
    if emptyImbue.imbue then addHoverToWidget(emptyImbue.imbue) end
    if emptyImbue.protection then addHoverToWidget(emptyImbue.protection) end
    if clearImbue.clear then addHoverToWidget(clearImbue.clear) end
    
    -- Adicionar hover aos itens requeridos
    if emptyImbue.requiredItems then
        for i = 1, 3 do
            local item = emptyImbue.requiredItems:getChildByIndex(i).item
            if item then addHoverToWidget(item) end
        end
    end
    
    -- Adicionar hover aos slots
    if imbuingWindow.itemInfo and imbuingWindow.itemInfo.slots then
        for i = 1, 3 do
            local slot = imbuingWindow.itemInfo.slots:getChildByIndex(i)
            if slot then addHoverToWidget(slot) end
        end
    end
end
