TutorialController = Controller:new()

local INFO_HEIGHT = 227
local ANIM_DURATION = 600
local START_BUTTON_IMAGE = "/game_tutorial/assets/images/button_startplaying_idle"

TutorialController.vocations = TutorialVocations or {
    --[[
    {
        {
            id: string,
            vocationId: number,
            name: string,
            role: string,
            specialties: string,
            spells: number[],
            gear: number[]
        },
        ...
    }
]]
}

TutorialController.selectedVocation = nil
--[[
    {
        id: string,
        vocationId: number,
        name: string,
        ...
    }
]]

TutorialController.vocationWidgets = {
    --[["VocationName": {
        "card": [UIWidget],
        "info": [UIWidget],
        "startButton": [UIWidget],
        "confirmPanel": [UIWidget],
        "highlight": [UIWidget] 
]]
}
TutorialController.animTokens = {
    --[[
    {
        "WidgetId": table (unique_token)
    }
]]
}

TutorialController.tutorialStep = 2 -- default step
-- /*=============================================
-- =            Local Functions                  =
-- =============================================*/

local function findVocation(vocationId)
    for _, vocation in ipairs(TutorialController.vocations) do
        if vocation.id == vocationId then
            return vocation
        end
    end
    return nil
end

local function resetCard(w)
    if w.startButton then
        w.startButton:show()
        w.startButton:setImageSource(START_BUTTON_IMAGE)
    end
    if w.selectButton then
        w.selectButton:setChecked(false)
    end
    if w.confirmPanel then
        w.confirmPanel:hide()
    end
    if w.highlight then
        w.highlight:hide()
    end
    if w.info then
        w.info:setMarginTop(INFO_HEIGHT)
    end
end

local function resetAllCards(self)
    self.selectedVocation = nil
    for _, widgets in pairs(self.vocationWidgets) do
        resetCard(widgets)
    end
end

local function animateInfo(self, info, toMargin)
    if not info or info:isDestroyed() then
        return
    end
    local id = info:getId()
    local token = {}
    self.animTokens[id] = token
    local fromMargin = info:getMarginTop()
    if fromMargin == toMargin then
        return
    end
    local startTime = g_clock.millis()

    local function step()
        if self.animTokens[id] ~= token or not info or info:isDestroyed() then
            return
        end
        local t = math.min((g_clock.millis() - startTime) / ANIM_DURATION, 1)
        local eased = 1 - math.pow(1 - t, 3)
        info:setMarginTop(math.floor(fromMargin + (toMargin - fromMargin) * eased))
        if t < 1 then
            self:scheduleEvent(step, 16)
        end
    end

    step()
end

local function bindCardHover(self, vocationId, w)
    if not w.card or not w.info then
        return
    end
    local function onHover()
        self:scheduleEvent(function()
            if not self.ui then
                return
            end
            local hovered = w.card:isHovered() or w.card:isChildHovered()
            animateInfo(self, w.info, hovered and 0 or INFO_HEIGHT)
            if w.highlight then
                if hovered then
                    w.highlight:show()
                else
                    w.highlight:hide()
                end
            end
        end, 30, "hover_" .. vocationId)
    end
    w.card.onHoverChange = onHover
    if w.startButton then
        w.startButton.onHoverChange = onHover
    end
    if w.selectButton then
        w.selectButton.onHoverChange = onHover
    end
    if w.confirmPanel then
        w.confirmPanel.onHoverChange = onHover
    end
    if w.confirmButton then
        w.confirmButton.onHoverChange = onHover
    end
end

local function setupCards(self)
    if not self.ui then
        return false
    end
    local cards = self:findWidgets(".vocationSelectionCard") or {}
    if #cards == 0 then
        return false
    end
    self.vocationWidgets = {}
    for index, card in ipairs(cards) do
        local vocation = card.vocation or self.vocations[index]
        if vocation and vocation.id then
            local startButton = card:querySelector(".selectionActionButtonContainer")
            local confirmPanel = card:querySelector(".confirmationButtonContainer")
            local widgets = {
                card = card,
                info = card:querySelector(".vocationDetailsContent"),
                startButton = startButton,
                selectButton = startButton and startButton:querySelector(".actionButton"),
                confirmPanel = confirmPanel,
                confirmButton = confirmPanel and confirmPanel:querySelector(".actionButton"),
                highlight = card:querySelector(".vocationSelectionHighlight")
            }

            self.vocationWidgets[vocation.id] = widgets
            bindCardHover(self, vocation.id, widgets)
        end
    end
    return true
end

local function applyVocationKeybinds(vocationName)
    if not Keybind or not Keybind.selectPreset then
        return
    end
    Keybind.selectPreset(vocationName)
    local actionbar = modules.game_actionbar
    if actionbar and actionbar.selectHotkeySet then
        if not actionbar.selectHotkeySet(vocationName) then
            g_logger.warning(string.format("[game_tutorial] Failed to sync action bar hotkey set '%s'.", vocationName))
        end
    end
end

local function applyVocationUI(self)
    self:scheduleEvent(function()
        local healthCircle = modules.game_healthcircle
        if healthCircle and healthCircle.checkMonkVocation then
            healthCircle.checkMonkVocation()
        end
    end, 500)
end

-- /*=============================================
-- =           Controller Methods                =
-- =============================================*/

function TutorialController:onGameStart()
    if g_game:getClientVersion() > 1520 then
        self:registerEvents(g_game, {
            onTutorialHint = function(...)
                self:onTutorialHint(...)
            end
        })
    else
        self:scheduleEvent(function()
            g_modules.getModule("game_tutorial"):unload()
        end, 100)
    end
end

function TutorialController:onTerminate()
    self:hide()
end

function TutorialController:onGameEnd()
    self:hide()
end

-- /*=============================================
-- =            Packet Handlers                  =
-- =============================================*/

function TutorialController:onTutorialHint(id)
    if id and id == tutorialStep.chooseVocation then
        self:setTutorialStep(id)
        self:show()
    else
        print("[game_tutorial] unexpected tutorial hint: " .. id)
    end
end

-- /*=============================================
-- =            UI Methods                  =
-- =============================================*/

function TutorialController:show()
    if self.ui then
        self.ui:raise()
        self.ui:focus()
        return
    end
    self:loadHtml("template/html/tutorial.html")
    if not self.ui then
        g_logger.error("[game_tutorial] failed to load tutorial.html")
        return
    end
end

function TutorialController:hide()
    self.selectedVocation = nil
    self.animTokens = {}
    self.vocationWidgets = {}

    if self.ui then
        self:unloadHtml()
    end
end

-- /*=============================================
-- =      HTML-bound methods  Callbacks          =
-- =============================================*/

function TutorialController:onVocationCardsRendered()
    if not setupCards(self) then
        return
    end
    resetAllCards(self)
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
end

function TutorialController:getSpellIconSource()
    local settings = SpelllistSettings and SpelllistSettings["Default"]
    return settings and settings.iconFile or ""
end

function TutorialController:getSpellImageClip(clientId)
    if not Spells or not Spells.getImageClip then
        return ""
    end
    return Spells.getImageClip(clientId, "Default")
end

function TutorialController:selectVocation(vocationId)
    local vocation = findVocation(vocationId)
    if not vocation then
        g_logger.error("[game_tutorial] unknown vocation: " .. tostring(vocationId))
        return
    end

    if self.selectedVocation and self.selectedVocation.id ~= vocation.id then
        local prev = self.vocationWidgets[self.selectedVocation.id]
        if prev then
            resetCard(prev)
        end
    end
    self.selectedVocation = vocation
    local w = self.vocationWidgets[vocation.id]
    if not w then
        return
    end
    if w.startButton then
        w.startButton:setImageSource("")
    end
    if w.selectButton then
        w.selectButton:setChecked(true)
    end
    if w.confirmPanel then
        w.confirmPanel:show()
        w.confirmPanel:raise()
    end
end

function TutorialController:confirmVocation()
    local vocation = self.selectedVocation
    if not vocation then
        return
    end
    g_game.sendTutorialChangeVocation(vocation.vocationId)
    applyVocationKeybinds(vocation.name)
    applyVocationUI(self)
    self:hide()
end

function TutorialController:setTutorialStep(step)
    self.tutorialStep = step
end
