-- Offline Training Dialog (15.24). Opened by server packet onMultiOfflineTrainingDialog.
-- NOTE: The packet's magic-skill id is 5 — this collides with Skill.Shielding in the
-- Skill enum but the server treats 5 as "magic level" for offline training only.
local offlineTrainingDefs = {
    {
        valueId = 'magicValue',
        barId = 'magicBar',
        getLevel = function(p) return p:getMagicLevel() end,
        getBaseLevel = function(p) return p:getBaseMagicLevel() end,
        getPercent = function(p) return p:getMagicLevelPercent() end
    },
    {
        valueId = 'fistValue',
        barId = 'fistBar',
        getLevel = function(p) return p:getSkillLevel(Skill.Fist) end,
        getBaseLevel = function(p) return p:getSkillBaseLevel(Skill.Fist) end,
        getPercent = function(p) return p:getSkillLevelPercent(Skill.Fist) end
    },
    {
        valueId = 'clubValue',
        barId = 'clubBar',
        getLevel = function(p) return p:getSkillLevel(Skill.Club) end,
        getBaseLevel = function(p) return p:getSkillBaseLevel(Skill.Club) end,
        getPercent = function(p) return p:getSkillLevelPercent(Skill.Club) end
    },
    {
        valueId = 'swordValue',
        barId = 'swordBar',
        getLevel = function(p) return p:getSkillLevel(Skill.Sword) end,
        getBaseLevel = function(p) return p:getSkillBaseLevel(Skill.Sword) end,
        getPercent = function(p) return p:getSkillLevelPercent(Skill.Sword) end
    },
    {
        valueId = 'axeValue',
        barId = 'axeBar',
        getLevel = function(p) return p:getSkillLevel(Skill.Axe) end,
        getBaseLevel = function(p) return p:getSkillBaseLevel(Skill.Axe) end,
        getPercent = function(p) return p:getSkillLevelPercent(Skill.Axe) end
    },
    {
        valueId = 'distanceValue',
        barId = 'distanceBar',
        getLevel = function(p) return p:getSkillLevel(Skill.Distance) end,
        getBaseLevel = function(p) return p:getSkillBaseLevel(Skill.Distance) end,
        getPercent = function(p) return p:getSkillLevelPercent(Skill.Distance) end
    }
}

local function refresh()
    skillController:refreshOfflineTrainingDialog()
end

local offlineTrainingEvents = {
    onMagicLevelChange = refresh,
    onBaseMagicLevelChange = refresh,
    onSkillChange = refresh,
    onBaseSkillChange = refresh
}

local function clampPercent(percent)
    percent = math.floor(tonumber(percent) or 0)
    return math.max(0, math.min(100, percent))
end

local function applyBaseState(widget, value, baseValue)
    if not widget then
        return
    end

    if baseValue <= 0 or value < 0 then
        widget:setColor('#bbbbbb')
        widget:removeTooltip()
        return
    end

    if value > baseValue then
        widget:setColor('#008b00')
        widget:setTooltip(baseValue .. ' +' .. (value - baseValue))
    elseif value < baseValue then
        widget:setColor('#b22222')
        widget:setTooltip(baseValue .. ' ' .. (value - baseValue))
    else
        widget:setColor('#bbbbbb')
        widget:removeTooltip()
    end
end

function skillController:cacheOfflineTrainingWidgets()
    local modal = self.offlineTrainingModal
    if not modal or not modal.ui then
        return
    end

    local cache = {}
    for i, def in ipairs(offlineTrainingDefs) do
        cache[i] = {
            value = modal.ui:querySelector('#' .. def.valueId),
            bar = modal.ui:querySelector('#' .. def.barId)
        }
    end
    self.offlineTrainingWidgetCache = cache
end

function skillController:bindOfflineTrainingEvents()
    if self.offlineTrainingEventsConnected then
        return
    end

    connect(LocalPlayer, offlineTrainingEvents)
    self.offlineTrainingEventsConnected = true
end

function skillController:unbindOfflineTrainingEvents()
    if not self.offlineTrainingEventsConnected then
        return
    end

    disconnect(LocalPlayer, offlineTrainingEvents)
    self.offlineTrainingEventsConnected = false
end

function skillController:refreshOfflineTrainingDialog()
    local modal = self.offlineTrainingModal
    local cache = self.offlineTrainingWidgetCache
    local player = g_game.getLocalPlayer()
    if not modal or not modal.ui or not cache or not player then
        return
    end

    for i, def in ipairs(offlineTrainingDefs) do
        local entry = cache[i]
        local level = def.getLevel(player) or 0
        local baseLevel = def.getBaseLevel(player) or 0
        local percent = clampPercent(def.getPercent(player))

        if entry.value then
            entry.value:setText(tostring(level))
            applyBaseState(entry.value, level, baseLevel)
        end
        if entry.bar then
            entry.bar:setPercent(percent)
            entry.bar:setTooltip(tr('You have %s percent to go', 100 - percent))
        end
    end
end

function skillController:showOfflineTrainingDialog()
    local modal = self.offlineTrainingModal
    if modal and modal.ui and not modal.ui:isDestroyed() then
        self:refreshOfflineTrainingDialog()
        return
    end

    self.offlineTrainingModal = self:openModal('offlinetraining1524.html')
    if self.offlineTrainingModal and self.offlineTrainingModal.ui then
        -- Widget is created from our HTML, so overwriting onDestroy is safe here.
        self.offlineTrainingModal.ui.onDestroy = function()
            self:onOfflineTrainingModalDestroy()
        end
    end

    self:bindOfflineTrainingEvents()
    self:cacheOfflineTrainingWidgets()
    self:refreshOfflineTrainingDialog()
end

function skillController:hideOfflineTrainingDialog()
    local modal = self.offlineTrainingModal
    if not modal then
        return
    end

    self.offlineTrainingModal = nil
    self.offlineTrainingWidgetCache = nil
    self:unbindOfflineTrainingEvents()
    self:closeModal(modal)
end

function skillController:onOfflineTrainingModalDestroy()
    local modal = self.offlineTrainingModal
    if modal then
        self:closeModal(modal)
        modal.htmlId = nil
        modal.ui = nil
    end

    self.offlineTrainingModal = nil
    self.offlineTrainingWidgetCache = nil
    self:unbindOfflineTrainingEvents()
end

function onMultiOfflineTrainingDialog()
    skillController:showOfflineTrainingDialog()
end

function skillController:sendStartOfflineTraining(skillType)
    g_game.sendStartOfflineTraining(skillType)
    self:hideOfflineTrainingDialog()
end
