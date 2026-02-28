local showHighlightedUnderline = false
local function getHighlightedText(text, color, highlightColor)
    color = color or "white"
    highlightColor = highlightColor or "#1f9ffe"
    local firstBrace = text:find("{", 1, true)
    if not firstBrace then
        return string.format("{%s, %s}", text, color)
    end
    local parts = {}
    local lastPos = 1
    if firstBrace > 1 then
        parts[#parts + 1] = string.format("{%s, %s}", text:sub(1, firstBrace - 1), color)
    end
    for startPos, content, endPos in text:gmatch("()%{([^}]*)%}()") do
        local textPart = content:match("([^,]+)") or content
        local trimmed = textPart
        local highlighted = trimmed
        if showHighlightedUnderline then
            highlighted = string.format("[text-event]%s[/text-event]", trimmed)
        else
            highlighted = string.format("[text-event]%s%s[/text-event]", string.char(1), trimmed)
        end
        parts[#parts + 1] = string.format("{%s, %s}", highlighted, highlightColor)
        local nextBrace = text:find("{", endPos, true)
        local afterText = text:sub(endPos, (nextBrace or 0) - 1)
        if afterText ~= "" then
            parts[#parts + 1] = string.format("{%s, %s}", afterText, color)
        end
        lastPos = endPos
    end
    return table.concat(parts)
end

function controllerNpcTrader:onConsoleTextClicked(widget, text)
    if type(widget) == "string" and not text then
        text = widget
        widget = nil
    end

    if not text or text == "" then
        return
    end

    local npcTab = modules.game_console.consoleTabBar:getTab("NPCs")
    if npcTab then
        modules.game_console.sendMessage(text, npcTab)
        onNpcTalk(g_game.getCharacterName(), 0, MessageModes.NpcTo, text)
    end
    if text == "bye" then
        controllerNpcTrader:onCloseNpcTrade()
    end
end

function controllerNpcTrader:cloneConsoleMessages()
    local consoleBuffer = self:findWidget("#consoleBuffer")
    local consoleModule = modules.game_console

    if consoleBuffer and consoleModule then
        local childCount = consoleBuffer:getChildCount()

        if childCount == 0 then
            consoleBuffer:destroyChildren()
            local npcTab = consoleModule.getTab("NPCs")
            if not npcTab then
                npcTab = consoleModule.getTab("NPC")
            end
            if npcTab and consoleModule.consoleTabBar then
                local panel = consoleModule.consoleTabBar:getTabPanel(npcTab)
                if panel then
                    local tabBuffer = panel:getChildById('consoleBuffer')
                    if tabBuffer then
                        for _, child in pairs(tabBuffer:getChildren()) do
                            local label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
                            label:setId(child:getId())
                            if child.coloredData then
                                label:setColoredText(child.coloredData)
                            else
                                label:setText(child:getText())
                            end
                            label:setColor(child:getColor())
                            if not label:hasEventListener(EVENT_TEXT_CLICK) then
                                label:setEventListener(EVENT_TEXT_CLICK)
                                connect(label, {
                                    onTextClick = function(w, t)
                                        controllerNpcTrader:onConsoleTextClicked(w, t)
                                    end
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

function controllerNpcTrader:initNpcWindow(creature, buttons)
    if not g_game.getFeature(GameNpcWindowRedesign) then
        return
    end
    self.widthConsole = self.DEFAULT_CONSOLE_WIDTH
    self.isTradeOpen = false
    if creature then
        self.creatureName = creature:getName() or "Unknown"
        self.outfit = creature:getOutfit()
    else
        self.creatureName = "Unknown"
        self.outfit = "/game_npctrader/assets/images/icon-npcdialog-multiplenpcs"
    end
    self.buttons = buttons or self.buttons or self.buttonsDefault
    self:updateChatButton()
    if not self.ui or not self.ui:isVisible() then
        self:loadHtml('templates/game_npctrader.html')
    end
    local creatureOutfit = self:findWidget("#creatureOutfit")
    if creatureOutfit then
        if type(self.outfit) == "string" then
            creatureOutfit:setImageSource(self.outfit)
        else
            creatureOutfit:setOutfit(self.outfit)
        end
    end
    self:cloneConsoleMessages()
end

function onNpcChatWindow(data)
    if not g_game.getFeature(GameNpcWindowRedesign) then
        controllerNpcTrader:legacy_show()
        return
    end
    local creature = g_map.getCreatureById(data.npcIds[1])
    controllerNpcTrader:initNpcWindow(creature, data.buttons)
end

function controllerNpcTrader:onConsoleKeyPress(event)
    if event.value == KeyEnter then
        local input = controllerNpcTrader:findWidget(".inputConsole")
        if input then
            local text = input:getText()
            if text and #text > 0 then
                controllerNpcTrader:onConsoleTextClicked(nil, text)
                input:clearText()
            end
        end
    end
end

function onNpcTalk(name, level, mode, text, channelId, creaturePos)
    if not controllerNpcTrader.ui or not controllerNpcTrader.ui:isVisible() then
        return
    end

    if mode == MessageModes.NpcTo or mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
        local consoleBuffer = controllerNpcTrader:findWidget("#consoleBuffer")
        if consoleBuffer then
            local consoleModule = modules.game_console
            local label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
            label:setId("consoleLabel" .. consoleBuffer:getChildCount())
            local SpeakTypes = consoleModule and consoleModule.SpeakTypes or {}
            local color = '#5FF7F7'
            if SpeakTypes[mode] and SpeakTypes[mode].color then
                color = SpeakTypes[mode].color
            end
            local fullText = text
            if mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
                fullText = name .. " says: " .. text
            elseif mode == MessageModes.NpcTo then
                fullText = name .. ": " .. text
            end
            if getHighlightedText then
                local highlightData = getHighlightedText(fullText, color, "#1f9ffe")
                label:setColoredText(highlightData)
            else
                label:setText(fullText)
            end
            label:setColor(color)
            if not label:hasEventListener(EVENT_TEXT_CLICK) then
                label:setEventListener(EVENT_TEXT_CLICK)
                connect(label, {
                    onTextClick = function(w, t)
                        controllerNpcTrader:onConsoleTextClicked(w, t)
                    end
                })
            end
        end
    end
end

function controllerNpcTrader:updateChatButton()
    local isChatEnabled = modules.game_console.isChatEnabled()
    self.chatMode = isChatEnabled and tr('Chat On') or tr('Chat Off')
    local inputConsole = self:findWidget(".inputConsole")
    if inputConsole then
        inputConsole:setEnabled(isChatEnabled)
    end
end

function controllerNpcTrader:toggleChatMode()
    modules.game_console.toggleChat()
    self:updateChatButton()
end
