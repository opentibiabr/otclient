local statesOutft = {
    available = 0,
    store = 1,
    goldenOutfitTooltip = 2
}

local window = nil
local appearanceGroup = nil
local colorModeGroup = nil
local colorBoxGroup = nil

local floor = nil
local movementCheck = nil
local showFloorCheck = nil
local showOutfitCheck = nil
local showMountCheck = nil
local showWingsCheck = nil
local showAuraCheck = nil
local showShaderCheck = nil
local showBarsCheck = nil
local showTitleCheck = nil
local showEffectsCheck = nil
local showFamiliarCheck = nil
local colorBoxes = {}
local currentColorBox = nil

local previewCreature = nil
local previewFamiliar = nil

ignoreNextOutfitWindow = 0
local floorTiles = 7
local settingsFile = "/settings/outfit.json"
local settings = {}

local tempOutfit = {}
local ServerData = {
    currentOutfit = {},
    outfits = {},
    mounts = {},
    familiars = {},
    wings = {},
    auras = {},
    shaders = {},
    healthBars = {},
    effects = {},
    title = {}
}

local lastSelectAura = "None"
local lastSelectWings = "None"
local lastSelectEffects = 0
local lastSelectShader = "Outfit - Default"
local lastSelectTitle = "None"

local function checkPresetsValidity(presets)
    for i, preset in ipairs(presets) do
        if type(preset) == "number" and preset > 0 then
            return true
        end
    end
    return false
end

local function attachEffectIfValid(UICreature, value)
    local creature = UICreature:getCreature()
    if checkPresetsValidity({ value }) then
        if creature then
            creature:attachEffect(g_attachedEffects.getById(value))
        end
    end
end

local function attachOrDetachEffect(Id, attach)
    local creature = previewCreature:getCreature()
    if checkPresetsValidity({ Id }) then
        if creature then
            if attach then
                if not creature:getAttachedEffectById(Id) then
                    local effect = g_attachedEffects.getById(Id)
                    if effect then
                        creature:attachEffect(effect)
                    end
                end
            else
                creature:detachEffectById(Id)
            end
        end
    end
end

local function showSelectionList(data, tempValue, tempField, onSelectCallback)
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil
    do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId("0")

        button.name:setText("None")
        if tempValue == 0 then
            focused = 0
        end
    end
    if data and #data > 0 then
        for _, itemData in ipairs(data) do
            local button = g_ui.createWidget("SelectionButton", window.selectionList)
            button:setId(tostring(itemData[1]))

            local Category = modules.game_attachedeffects.getCategory(itemData[1])
            if Category == 1 then
                button.outfit:setOutfit({
                    type = modules.game_attachedeffects.thingId(itemData[1])
                })

                button.outfit:setMarginBottom(15)
                button.outfit:setCenter(true)
            elseif Category == 2 then
                button.outfit:setOutfit(previewCreature:getCreature():getOutfit())
                button.outfit:getCreature():attachEffect(g_attachedEffects.getById(itemData[1]))
            elseif Category == 5 then
                button.outfit:setImageSource(modules.game_attachedeffects.getTexture(itemData[1]))
            end

            button.name:setText(modules.game_attachedeffects.getName(itemData[1]))
            if tempValue == itemData[1] then
                focused = (itemData[1])
            end
        end
    end
    if focused ~= nil then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onSelectCallback
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

local AppearanceData = { "preset", "outfit", "mount", "familiar", "wings", "aura", "effects", "shader", "healthBar",
    "title" }

function init()
    connect(g_game, {
        onOpenOutfitWindow = create,
        onGameEnd = destroy
    })
end

function terminate()
    disconnect(g_game, {
        onOpenOutfitWindow = create,
        onGameEnd = destroy
    })
    destroy()
end

function onOutfitChange(creature, outfit, oldOutfit)
    -- Dummy function to handle engine callbacks
    -- This prevents the "luaCallLuaField(onOutfitChange) is being called outside the context of the lua call" warnings
end

function onMovementChange(checkBox, checked)
    local walkingSpeed = checked and 1000 or 0

    local mainCreature = previewCreature:getCreature()
    if mainCreature then
        mainCreature:setStaticWalking(walkingSpeed)
    end

    if g_game.getFeature(GamePlayerFamiliars) then
        local familiarCreature = previewFamiliar:getCreature()
        if familiarCreature then
            familiarCreature:setStaticWalking(walkingSpeed)
        end
    end

    settings.movement = checked
end

function onShowFloorChange(checkBox, checked)
    if checked then
        floor:show()

        -- Magic!
        local delay = 50
        periodicalEvent(function()
            if movementCheck:isChecked() then
                local direction = previewCreature:getDirection()
                if direction == Directions.North then
                    local newMargin = floor:getMarginTop() + 8
                    floor:setMarginTop(newMargin)
                    if newMargin >= 96 then
                        for i = 1, floorTiles do
                            floor:moveChildToIndex(floor:getChildByIndex(floorTiles * floorTiles), 1)
                        end
                        floor:setMarginTop(32)
                    end
                elseif direction == Directions.South then
                    local newMargin = floor:getMarginBottom() + 8
                    floor:setMarginBottom(newMargin)
                    if newMargin >= 64 then
                        for i = 1, floorTiles do
                            floor:moveChildToIndex(floor:getChildByIndex(1), floorTiles * floorTiles)
                        end
                        floor:setMarginBottom(0)
                    end
                elseif direction == Directions.East then
                    local newMargin = floor:getMarginRight() + 8
                    floor:setMarginRight(newMargin)
                    if newMargin >= 64 then
                        floor:setMarginRight(0)
                    end
                elseif direction == Directions.West then
                    local newMargin = floor:getMarginLeft() + 8
                    floor:setMarginLeft(newMargin)
                    if newMargin >= 64 then
                        floor:setMarginLeft(0)
                    end
                end
            else
                floor:setMargin(0)
            end
        end, function()
            return window and floor and showFloorCheck:isChecked()
        end, delay, delay)
    else
        floor:hide()
    end

    settings.showFloor = checked
end

function onShowMountChange(checkBox, checked)
    settings.showMount = checked
    updatePreview()
end

function onShowFamiliarChange(checkBox, checked)
    settings.showFamiliar = checked
    updatePreview()
end

function onShowOutfitChange(checkBox, checked)
    settings.showOutfit = checked
    showMountCheck:setEnabled(settings.showOutfit)
    showFamiliarCheck:setEnabled(settings.showOutfit)
    showWingsCheck:setEnabled(settings.showOutfit)
    showAuraCheck:setEnabled(settings.showOutfit)
    showShaderCheck:setEnabled(settings.showOutfit)
    showBarsCheck:setEnabled(settings.showOutfit)
    showEffectsCheck:setEnabled(settings.showEffects)
    updatePreview()
end

function onShowAuraChange(checkBox, checked)
    settings.showAura = checked
    updatePreview()
end

function onShowWingsChange(checkBox, checked)
    settings.showWings = checked
    updatePreview()
end

function onShowShaderChange(checkBox, checked)
    settings.showShader = checked
    updatePreview()
end

function onShowTitleChange(checkBox, checked)
    settings.showTitle = checked
    updatePreview()
end

function onShowBarsChange(checkBox, checked)
    settings.showBars = checked
    updatePreview()
end

function onShowEffectsChange(checkBox, checked)
    settings.showEffects = checked
    updatePreview()
end

local PreviewOptions = {
    ["showFloor"] = onShowFloorChange,
    ["showOutfit"] = onShowOutfitChange,
    ["showMount"] = onShowMountChange,
    ["showFamiliar"] = onShowFamiliarChange,
    ["showWings"] = onShowWingsChange,
    ["showAura"] = onShowAuraChange,
    ["showShader"] = onShowShaderChange,
    ["showBars"] = onShowBarsChange,
    ["showTitle"] = onShowTitleChange,
    ["showEffects"] = onShowEffectsChange
}

function create(player, outfitList, creatureMount, mountList, familiarList, wingsList, auraList, effectsList, shaderList)
    if ignoreNextOutfitWindow and g_clock.millis() < ignoreNextOutfitWindow + 1000 then
        return
    end
    local currentOutfit = player:getOutfit()
    if window then
        destroy()
    end

    if currentOutfit.shader == "" then
        currentOutfit.shader = "Outfit - Default"
    end

    loadSettings()
    ServerData = {
        currentOutfit = currentOutfit,
        outfits = outfitList,
        mounts = mountList,
        familiars = familiarList,
        wings = wingsList,
        auras = auraList,
        effects = effectsList,
        shaders = shaderList
        --[[
        healthBars = barsList,
        title = titleList]]

    }

    window = g_ui.displayUI("outfitwindow")

    floor = window.preview.panel.floor
    for i = 1, floorTiles * floorTiles do
        g_ui.createWidget("FloorTile", floor)
    end
    floor:hide()

    for _, appKey in ipairs(AppearanceData) do
        updateAppearanceText(appKey, "None")
    end

    previewCreature = window.preview.panel.creature
    previewCreature:setCreatureSize(128)
    previewCreature:setCenter(true)

    previewFamiliar = window.preview.panel.UIfamiliar
    previewFamiliar:setCreatureSize(128)
    previewFamiliar:setCenter(true)
    -- previewCreature:setBorderColor('red')
    -- previewCreature:setBorderWidth(2)

    if settings.currentPreset == nil then
        loadDefaultSettings()
        print("game_outfit error funtion loadSettings()")
    end
    if settings.currentPreset > 0 then
        local preset = settings.presets[settings.currentPreset]
        tempOutfit = table.copy(preset.outfit)

        updateAppearanceText("preset", preset.title)
    else
        tempOutfit = currentOutfit
    end

    updatePreview()

    updateAppearanceTexts(currentOutfit)

    if g_game.getFeature(GamePlayerMounts) then
        local isMount = g_game.getLocalPlayer():isMounted()
        if isMount then
            window.configure.mount.check:setEnabled(true)
            window.configure.mount.check:setChecked(true)
        else
            window.configure.mount.check:setEnabled(currentOutfit.mount > 0)
            window.configure.mount.check:setChecked(isMount and currentOutfit.mount > 0)
        end
    end

    if currentOutfit.addons == 3 then
        window.configure.addon1.check:setChecked(true)
        window.configure.addon2.check:setChecked(true)
    elseif currentOutfit.addons == 2 then
        window.configure.addon1.check:setChecked(false)
        window.configure.addon2.check:setChecked(true)
    elseif currentOutfit.addons == 1 then
        window.configure.addon1.check:setChecked(true)
        window.configure.addon2.check:setChecked(false)
    end
    window.configure.addon1.check.onCheckChange = onAddonChange
    window.configure.addon2.check.onCheckChange = onAddonChange

    configureAddons(currentOutfit.addons)

    movementCheck = window.preview.panel.movement
    showFloorCheck = window.preview.options.showFloor.check
    showOutfitCheck = window.preview.options.showOutfit.check
    showMountCheck = window.preview.options.showMount.check
    showFamiliarCheck = window.preview.options.showFamiliar.check
    showWingsCheck = window.preview.options.showWings.check
    showAuraCheck = window.preview.options.showAura.check
    showShaderCheck = window.preview.options.showShader.check
    showBarsCheck = window.preview.options.showBars.check
    showEffectsCheck = window.preview.options.showEffects.check
    showTitleCheck = window.preview.options.showTitle.check

    movementCheck.onCheckChange = onMovementChange
    for _, option in ipairs(window.preview.options:getChildren()) do
        option.check.onCheckChange = PreviewOptions[option:getId()]
    end

    movementCheck:setChecked(settings.movement)
    showFloorCheck:setChecked(settings.showFloor)

    if not settings.showOutfit then
        showMountCheck:setEnabled(false)
        showFamiliarCheck:setEnabled(false)
        showWingsCheck:setEnabled(false)
        showAuraCheck:setEnabled(false)
        showShaderCheck:setEnabled(false)
        showBarsCheck:setEnabled(false)
        showTitleCheck:setEnabled(false)
        showEffectsCheck:setEnabled(false)
    end

    showOutfitCheck:setChecked(settings.showOutfit)
    showMountCheck:setChecked(settings.showMount)
    showFamiliarCheck:setChecked(settings.showFamiliar)
    showWingsCheck:setChecked(settings.showWings)
    showAuraCheck:setChecked(settings.showAura)
    showShaderCheck:setChecked(settings.showShader)
    showBarsCheck:setChecked(settings.showBars)
    showEffectsCheck:setChecked(settings.showEffects)
    showTitleCheck:setChecked(settings.showTitle)

    colorBoxGroup = UIRadioGroup.create()
    for j = 0, 6 do
        for i = 0, 18 do
            local colorBox = g_ui.createWidget("ColorBox", window.appearance.colorBoxPanel)
            local outfitColor = getOutfitColor(j * 19 + i)
            colorBox:setBackgroundColor(outfitColor)
            colorBox:setId("colorBox" .. j * 19 + i)
            colorBox.colorId = j * 19 + i

            if colorBox.colorId == currentOutfit.head then
                currentColorBox = colorBox
                colorBox:setChecked(true)
            end
            colorBoxGroup:addWidget(colorBox)
        end
    end

    colorBoxGroup.onSelectionChange = onColorCheckChange

    appearanceGroup = UIRadioGroup.create()
    appearanceGroup:addWidget(window.appearance.settings.preset.check)
    appearanceGroup:addWidget(window.appearance.settings.outfit.check)
    appearanceGroup:addWidget(window.appearance.settings.mount.check)
    appearanceGroup:addWidget(window.appearance.settings.familiar.check)
    appearanceGroup:addWidget(window.appearance.settings.aura.check)
    appearanceGroup:addWidget(window.appearance.settings.wings.check)
    appearanceGroup:addWidget(window.appearance.settings.shader.check)
    appearanceGroup:addWidget(window.appearance.settings.healthBar.check)
    appearanceGroup:addWidget(window.appearance.settings.effects.check)
    appearanceGroup:addWidget(window.appearance.settings.title.check)
    appearanceGroup.onSelectionChange = onAppearanceChange
    appearanceGroup:selectWidget(window.appearance.settings.preset.check)

    colorModeGroup = UIRadioGroup.create()
    colorModeGroup:addWidget(window.appearance.colorMode.head)
    colorModeGroup:addWidget(window.appearance.colorMode.primary)
    colorModeGroup:addWidget(window.appearance.colorMode.secondary)
    colorModeGroup:addWidget(window.appearance.colorMode.detail)

    colorModeGroup.onSelectionChange = onColorModeChange
    colorModeGroup:selectWidget(window.appearance.colorMode.head)

    window.preview.options.showMount:setVisible(g_game.getFeature(GamePlayerMounts))
    window.configure.mount:setVisible(g_game.getFeature(GamePlayerMounts))
    window.appearance.settings.mount:setVisible(g_game.getFeature(GamePlayerMounts))

    window.preview.options.showFamiliar:setVisible(g_game.getFeature(GamePlayerFamiliars))
    window.appearance.settings.familiar:setVisible(g_game.getFeature(GamePlayerFamiliars))

    local checks = {
        { window.preview.options.showWings,     ServerData.wings },
        { window.preview.options.showAura,      ServerData.auras },
        { window.preview.options.showShader,    ServerData.shaders },
        { window.preview.options.showBars,      ServerData.healthBars },
        { window.preview.options.showEffects,   ServerData.effects },
        { window.preview.options.showTitle,     ServerData.title },
        { window.preview.options.showFamiliar,  ServerData.familiars },
        { window.appearance.settings.familiar,  ServerData.familiars },
        { window.appearance.settings.wings,     ServerData.wings },
        { window.appearance.settings.aura,      ServerData.auras },
        { window.appearance.settings.shader,    ServerData.shaders },
        { window.appearance.settings.healthBar, ServerData.healthBars },
        { window.appearance.settings.effects,   ServerData.effects },
        { window.appearance.settings.title,     ServerData.title },
    }

    for _, check in ipairs(checks) do
        local widget, data = check[1], check[2]
        if not table.empty(data) then
            widget:setVisible(true)
        else
            widget:setVisible(false)
        end
    end
    previewCreature:getCreature():setDirection(2)
    window.listSearch.search.onKeyPress = onFilterSearch
    window.listSearch.onlyMine.onCheckChange = onFilterOnlyMine
end

function destroy()
    if window then
        floor = nil
        movementCheck = nil
        showFloorCheck = nil
        showOutfitCheck = nil
        showMountCheck = nil
        showFamiliarCheck = nil
        showWingsCheck = nil
        showAuraCheck = nil
        showShaderCheck = nil
        showBarsCheck = nil
        showEffectsCheck = nil
        showTitleCheck = nil
        colorBoxes = {}
        currentColorBox = nil
        previewCreature:destroy()
        previewCreature = nil
        if previewFamiliar then
            previewFamiliar:destroy()
            previewFamiliar = nil
        end
        if appearanceGroup then
            appearanceGroup:destroy()
            appearanceGroup = nil
        end
        colorModeGroup:destroy()
        colorModeGroup = nil
        colorBoxGroup:destroy()
        colorBoxGroup = nil

        ServerData = {
            currentOutfit = {},
            outfits = {},
            mounts = {},
            familiars = {},
            wings = {},
            auras = {},
            shaders = {},
            healthBars = {},
            effects = {},
            title = {}
        }

        saveSettings()
        settings = {}
        window:destroy()
        window = nil
        lastSelectAura = "None"
        lastSelectWings = "None"
        lastSelectEffects = 0
        lastSelectShader = "Outfit - Default"
    end
end

function configureAddons(addons)
    local hasAddon1 = addons == 1 or addons == 3
    local hasAddon2 = addons == 2 or addons == 3
    window.configure.addon1.check:setEnabled(hasAddon1)
    window.configure.addon2.check:setEnabled(hasAddon2)

    window.configure.addon1.check.onCheckChange = nil
    window.configure.addon2.check.onCheckChange = nil
    window.configure.addon1.check:setChecked(false)
    window.configure.addon2.check:setChecked(false)
    if tempOutfit.addons == 3 then
        window.configure.addon1.check:setChecked(true)
        window.configure.addon2.check:setChecked(true)
    elseif tempOutfit.addons == 2 then
        window.configure.addon1.check:setChecked(false)
        window.configure.addon2.check:setChecked(true)
    elseif tempOutfit.addons == 1 then
        window.configure.addon1.check:setChecked(true)
        window.configure.addon2.check:setChecked(false)
    end
    window.configure.addon1.check.onCheckChange = onAddonChange
    window.configure.addon2.check.onCheckChange = onAddonChange
end

function newPreset()
    if not settings.presets then
        settings.presets = {}
    end

    local presetWidget = g_ui.createWidget("PresetButton", window.presetsList)
    local presetId = #settings.presets + 1
    presetWidget:setId(presetId)
    presetWidget.title:setText("New Preset")
    local outfitCopy = table.copy(tempOutfit)
    presetWidget.creature:setOutfit(outfitCopy)
    --  presetWidget.creature:setCenter(true)

    settings.presets[presetId] = {
        title = "New Preset",
        outfit = outfitCopy,
        aura = "None",
        effects = 0,
        wings = "None",
        shader = "None",
        mounted = window.configure.mount.check:isChecked(),
        familiar = "None"
    }

    presetWidget:focus()
    window.presetsList:ensureChildVisible(presetWidget, {
        x = 0,
        y = 196
    })

    lastSelectAura = "None"
    lastSelectWings = "None"
    lastSelectEffects = 0
    lastSelectShader = "Outfit - Default"
    lastSelectTitle = "None"
end

function deletePreset()
    local presetId = settings.currentPreset
    if presetId == 0 then
        local focused = window.presetsList:getFocusedChild()
        if focused then
            presetId = tonumber(focused:getId())
        end
    end

    if not presetId or presetId == 0 then
        return
    end

    table.remove(settings.presets, presetId)
    window.presetsList[presetId]:destroy()
    settings.currentPreset = 0
    local newId = 1
    for _, child in ipairs(window.presetsList:getChildren()) do
        child:setId(newId)
        newId = newId + 1
    end

    if previewCreature then
        local creature = previewCreature:getCreature()
        if creature then
            creature:clearAttachedEffects()
            creature:setShader("Outfit - Default")
        end
    end
    updateAppearanceText("preset", "None")
    updateAppearanceText("shader", "Outfit - Default")
    updateAppearanceText("aura", "None")
    updateAppearanceText("wings", "None")
    updateAppearanceText("effects", "None")
end

function savePreset()
    local presetId = settings.currentPreset
    if presetId == 0 then
        local focused = window.presetsList:getFocusedChild()
        if focused then
            presetId = tonumber(focused:getId())
        end
    end

    if not presetId or presetId == 0 then
        return
    end

    window.presetsList[presetId].creature:getCreature():clearAttachedEffects()
    local outfitCopy = table.copy(tempOutfit)

    window.presetsList[presetId].creature:setOutfit(outfitCopy)

    settings.presets[presetId].outfit = outfitCopy
    settings.presets[presetId].mounted = window.configure.mount.check:isChecked()
    settings.presets[presetId].familiar = tempOutfit.familiar or 0
    settings.presets[presetId].shader = "Outfit - Default"
    settings.presets[presetId].auras = lastSelectAura or "None"
    settings.presets[presetId].effects = lastSelectEffects or 0
    settings.presets[presetId].wings = lastSelectWings or "None"
    settings.presets[presetId].shaders = lastSelectShader or "None"

    settings.currentPreset = presetId

    attachEffectIfValid(window.presetsList[presetId].creature, lastSelectAura)
    attachEffectIfValid(window.presetsList[presetId].creature, lastSelectEffects)
    attachEffectIfValid(window.presetsList[presetId].creature, lastSelectWings)
    local presets = { lastSelectAura, lastSelectEffects, lastSelectWings }
    local hasValidAE = checkPresetsValidity(presets)
    local thingType = g_things.getThingType(tempOutfit.type, ThingCategoryCreature)

    if (hasValidAE and window.presetsList[presetId].creature:getCreatureSize() == 0) then
        -- TODO: Try changing square clipping size from Mehah PR
        window.presetsList[presetId].creature:setCreatureSize(thingType:getRealSize())
        window.presetsList[presetId].creature:setCenter(true)
    elseif not g_game.getFeature(GameWingsAurasEffectsShader) then
        window.presetsList[presetId].creature:setCreatureSize(thingType:getRealSize() + 32)
        window.presetsList[presetId].creature:setCenter(true)
    else
        window.presetsList[presetId].creature:setCreatureSize(thingType:getRealSize())
        window.presetsList[presetId].creature:setCenter(true)
    end



    if lastSelectShader ~= "None" and lastSelectShader ~= nil then
        if window.presetsList[presetId].creature then
            local creature = window.presetsList[presetId].creature:getCreature()
            if creature then
                creature:setShader(lastSelectShader)
            end
        end
    end

    --[[     if lastSelectTitle ~= "None" then
        window.presetsList[presetId].creature:getCreature():setTitle(lastSelectTitle, "verdana-11px-rounded", "#0000ff")
    end ]]
    -- @
end

function renamePreset()
    local presetId = settings.currentPreset
    if presetId == 0 then
        local focused = window.presetsList:getFocusedChild()
        if focused then
            presetId = tonumber(focused:getId())
        end
    end

    if not presetId or presetId == 0 then
        return
    end

    local presetWidget = window.presetsList[presetId]
    presetWidget.title:hide()
    presetWidget.rename.input:setText("")
    presetWidget.rename.save.onClick = function()
        saveRename(presetId)
    end
    presetWidget.rename:show()
end

function saveRename(presetId)
    local presetWidget = window.presetsList[presetId]
    if not presetWidget then
        return
    end

    local newTitle = presetWidget.rename.input:getText():trim()
    presetWidget.rename.input:setText("")
    presetWidget.rename:hide()
    presetWidget.title:setText(newTitle)
    presetWidget.title:show()
    settings.presets[presetId].title = newTitle

    if presetId == settings.currentPreset then
        updateAppearanceText("preset", newTitle)
    end
end

function onAppearanceChange(widget, selectedWidget)
    local id = selectedWidget:getParent():getId()
    if id == "preset" then
        showPresets()
    elseif id == "outfit" then
        showOutfits()
    elseif id == "mount" then
        showMounts()
    elseif id == "familiar" then
        showFamiliars()
    elseif id == "aura" then
        showSelectionList(ServerData.auras, tempOutfit.auras, "aura", onAuraSelect)
    elseif id == "wings" then
        showSelectionList(ServerData.wings, tempOutfit.wings, "wings", onWingsSelect)
    elseif id == "effects" then
        showSelectionList(ServerData.effects, tempOutfit.effects, "effects", onEffectBarSelect)
        -- strings
    elseif id == "shader" then
        showShaders()
    elseif id == "healthBar" then
        showHealthBars()
    elseif id == "title" then
        showTitle()
    end
end

function showPresets()
    window.listSearch:hide()
    window.selectionList:hide()
    window.selectionScroll:hide()

    local focused = nil
    if window.presetsList:getChildCount() == 0 and settings.presets then
        for presetId, preset in ipairs(settings.presets) do
            local presetWidget = g_ui.createWidget("PresetButton", window.presetsList)
            presetWidget:setId(presetId)
            presetWidget.title:setText(preset.title)
            presetWidget.creature:setOutfit(preset.outfit)

            attachEffectIfValid(presetWidget.creature, preset.auras)
            attachEffectIfValid(presetWidget.creature, preset.effects)
            attachEffectIfValid(presetWidget.creature, preset.wings)

            local presets = { preset.auras, preset.effects, preset.wings }
            local hasValidAE = checkPresetsValidity(presets)
            local thingType = g_things.getThingType(tempOutfit.type, ThingCategoryCreature)

            if (hasValidAE and presetWidget.creature:getCreatureSize() == 0) then
                -- TODO: Try changing square clipping size from Mehah PR
                presetWidget.creature:setCenter(true)
            elseif not g_game.getFeature(GameWingsAurasEffectsShader) then
                presetWidget.creature:setCreatureSize(thingType:getRealSize() + 32)
                presetWidget.creature:setCenter(true)
            else
                presetWidget.creature:setCenter(true)
            end

            if preset.shaders ~= "None" then
                presetWidget.creature:getCreature():setShader(preset.shaders)
                lastSelectShader = preset.shaders
            end

            if presetId == settings.currentPreset then
                focused = presetId
            end
        end
    end

    if focused then
        local w = window.presetsList[focused]

        w:focus()
        window.presetsList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
        onPresetSelect(nil, window.presetsList[focused])
    end

    window.presetsList.onChildFocusChange = onPresetSelect
    window.presetsList:show()
    window.presetsScroll:show()
    window.presetButtons:show()
end

function showOutfits()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil
    for _, outfitData in ipairs(ServerData.outfits) do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId(outfitData[1])

        local outfit = table.copy(previewCreature:getCreature():getOutfit())
        outfit.type = outfitData[1]
        outfit.addons = outfitData[3]
        outfit.mount = 0
        outfit.familiar = 0
        outfit.auras = 0
        outfit.wings = 0
        outfit.shader = "Outfit - Default"
        outfit.healthBar = 0
        outfit.effects = 0
        button.outfit:setOutfit(outfit)

        button.outfit:setCenter(true)

        local state = outfitData[4]
        if state then
            button.state = state
            if state ~= statesOutft.available then
                button:setImageSource("/images/ui/button-blue-qt")
            end
        end

        button.name:setText(outfitData[2])
        if tempOutfit.type == outfitData[1] then
            focused = outfitData[1]
            configureAddons(outfitData[3])
        end
    end

    if focused then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onOutfitSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function showMounts()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil

    local button = g_ui.createWidget("SelectionButton", window.selectionList)
    button:setId(0)
    button.name:setText("None")
    button.state = 0
    focused = 0

    for _, mountData in ipairs(ServerData.mounts) do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId(mountData[1])

        button.outfit:setOutfit({
            type = mountData[1]
        })

        button.outfit:setCenter(true)

        button.name:setText(mountData[2])
        if tempOutfit.mount == mountData[1] then
            focused = mountData[1]
        end

        local state = mountData[3]
        if state then
            button.state = state
            if state ~= statesOutft.available then
                button:setImageSource("/images/ui/button-blue-qt")
            end
        end
    end

    if #ServerData.mounts == 1 then
        window.selectionList:focusChild(nil)
    end

    window.configure.mount.check:setEnabled(focused)
    window.configure.mount.check:setChecked(g_game.getLocalPlayer():isMounted() and focused)

    if focused ~= nil then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onMountSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function showFamiliars()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil

    local button = g_ui.createWidget("SelectionButton", window.selectionList)
    button:setId(0)
    button.name:setText("None")
    focused = 0
    for _, familiarData in ipairs(ServerData.familiars) do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId(familiarData[1])

        button.outfit:setOutfit({
            type = familiarData[1]
        })

        button.name:setText(familiarData[2])

        button.outfit:setCenter(true)

        if tempOutfit.familiar == familiarData[1] then
            focused = familiarData[1]
        end
    end

    if #ServerData.familiars == 1 then
        window.selectionList:focusChild(nil)
    end

    if focused then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onFamiliarSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function showShaders()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil
    do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId("Outfit - Default")

        button.outfit:setOutfit({
            type = tempOutfit.type,
            addons = tempOutfit.addons
        })

        button.outfit:setCenter(true)

        button.outfit:getCreature():setShader("Outfit - Default")
        button.name:setText("Outfit - Default")
        if tempOutfit.shaders == "Outfit - Default" then
            focused = "Outfit - Default"
        end
    end

    if ServerData.shaders and #ServerData.shaders > 0 then
        for _, shaderData in ipairs(ServerData.shaders) do
            local button = g_ui.createWidget("SelectionButton", window.selectionList)
            button:setId(shaderData[2])

            button.outfit:setOutfit({
                type = tempOutfit.type,
                addons = tempOutfit.addons

            })

            button.outfit:setCenter(true)

            button.outfit:getCreature():setShader(shaderData[2])

            button.name:setText(shaderData[2])

            if tempOutfit.shaders == shaderData[2] then
                focused = shaderData[2]
            end
        end
    end
    if focused ~= nil then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onShaderSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function showHealthBars()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil
    do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId("0")

        button.outfit:hide()
        button.name:setText("None")
        if tempOutfit.healthBar == 0 then
            focused = 0
        end
    end
    if ServerData.healthBars and #ServerData.healthBars > 0 then
        for _, barData in ipairs(ServerData.healthBars) do
            local button = g_ui.createWidget("SelectionButton", window.selectionList)
            button:setId(barData)

            local Category = modules.game_attachedeffects.getCategory(barData)
            if Category == 5 then
                button.outfit:setImageSource(modules.game_attachedeffects.getTexture(barData))
                button.outfit:setWidth(64)
                button.outfit:setHeight(32)
            else
                button.outfit:setOutfit(previewCreature:getCreature():getOutfit())
                button.outfit:getCreature():attachEffect(g_attachedEffects.getById(barData))
            end

            button.bar:show()

            button.name:setText(barData)
            if tempOutfit.healthBar == barData then
                focused = barData
            end
        end
    end
    if focused ~= nil then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onHealthBarSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function showTitle()
    window.presetsList:hide()
    window.presetsScroll:hide()
    window.presetButtons:hide()

    window.selectionList.onChildFocusChange = nil
    window.selectionList:destroyChildren()

    local focused = nil
    do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId("0")


        button.name:setText("None")
        if tempOutfit.tile == 0 then
            focused = 0
        end
    end
    if ServerData.title and #ServerData.title > 0 then
        for _, titleData in ipairs(ServerData.title) do
            local button = g_ui.createWidget("SelectionButton", window.selectionList)
            button:setId(tostring(titleData))

            button.outfit:setOutfit(previewCreature:getCreature():getOutfit())
            button.outfit:getCreature():getCreature():setTitle(titleData, "verdana-11px-rounded", "#0000ff")

            button.name:setText(tostring(titleData))
            if tempOutfit.tile == titleData then
                focused = tostring(titleData)
            end
        end
    end
    if focused ~= nil then
        local w = window.selectionList[focused]
        w:focus()
        window.selectionList:ensureChildVisible(w, {
            x = 0,
            y = 196
        })
    end

    window.selectionList.onChildFocusChange = onTitleSelect
    window.selectionList:show()
    window.selectionScroll:show()
    window.listSearch:show()
end

function onPresetSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        local presetId = tonumber(focusedChild:getId())
        local preset = settings.presets[presetId]
        tempOutfit = table.copy(preset.outfit)

        for _, outfitData in ipairs(ServerData.outfits) do
            if tempOutfit.type == outfitData[1] then
                configureAddons(outfitData[3])
                break
            end
        end

        if g_game.getFeature(GamePlayerMounts) then
            window.configure.mount.check:setChecked(preset.mounted and tempOutfit.mount > 0)
        end

        settings.currentPreset = presetId

        updatePreview()

        updateAppearanceTexts(tempOutfit)

        updateAppearanceText("preset", preset.title)
        if g_game.getFeature(GameWingsAurasEffectsShader) then
            updateAppearanceText("aura", modules.game_attachedeffects.getName(preset.auras))
            updateAppearanceText("wings", modules.game_attachedeffects.getName(preset.wings))
            updateAppearanceText("shader", preset.shaders or "Outfit - Default")
            updateAppearanceText("effects", modules.game_attachedeffects.getName(preset.effects))
        end

        previewCreature:getCreature():clearAttachedEffects()

        if settings.showEffects and preset.effects then
            attachEffectIfValid(previewCreature, preset.effects)
        end

        if settings.showWings and preset.wings then
            attachEffectIfValid(previewCreature, preset.wings)
        end

        if settings.showAura and preset.auras then
            attachEffectIfValid(previewCreature, preset.auras)
        end

        if not settings.showShader or preset.shaders == "None" then
            if previewCreature then
                local creature = previewCreature:getCreature()
                if creature then
                    creature:setShader("Outfit - Default")
                end
            end
        else
            if previewCreature then
                local creature = previewCreature:getCreature()
                if creature then
                    creature:setShader(preset.shaders)
                end
            end
        end

        tempOutfit.wings = preset.wings
        tempOutfit.auras = preset.auras
        tempOutfit.shaders = preset.shaders
        tempOutfit.effects = preset.effects
        lastSelectAura = preset.auras
        lastSelectWings = preset.wings
        lastSelectEffects = preset.effects
        lastSelectShader = preset.shaders
    end
end

function onOutfitSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        local outfitType = tonumber(focusedChild:getId())
        local outfit = focusedChild.outfit:getCreature():getOutfit()
        tempOutfit.type = outfit.type
        tempOutfit.addons = outfit.addons

        deselectPreset()

        configureAddons(outfit.addons)

        if showOutfitCheck:isChecked() then
            updatePreview()
        end
        updateAppearanceText("outfit", focusedChild.name:getText())
    end
end

function onMountSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        local mountType = tonumber(focusedChild:getId())
        tempOutfit.mount = mountType

        deselectPreset()

        if showMountCheck:isChecked() then
            updatePreview()
        end

        window.configure.mount.check:setEnabled(tempOutfit.mount > 0)
        window.configure.mount.check:setChecked(g_game.getLocalPlayer():isMounted() and tempOutfit.mount > 0)

        updateAppearanceText("mount", focusedChild.name:getText())
    end
end

function onFamiliarSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        local familiarType = tonumber(focusedChild:getId())

        tempOutfit.familiar = familiarType

        deselectPreset()

        -- Only set outfit if familiarType is valid (not 0/None)
        if familiarType and familiarType > 0 then
            previewFamiliar:setOutfit({
                type = familiarType
            })
        else
            -- Hide/clear the familiar when "None" is selected
            previewFamiliar:setVisible(false)
        end

        updatePreview()

        if settings.showFamiliar and g_game.getFeature(GamePlayerFamiliars) and familiarType ~= nil and familiarType > 0 then
            previewCreature:setMarginRight(50)
            previewFamiliar:setCreatureSize(124)
            previewFamiliar:setCenter(true)
            previewFamiliar:setMarginLeft(70)
        else
            previewCreature:setMarginRight(0)
            previewFamiliar:setMarginLeft(0)
            window.preview.panel.bars:setMarginRight(20)
        end

        updateAppearanceText("familiar", focusedChild.name:getText())
    end
end

function onAuraSelect(list, focusedChild, unfocusedChild, reason)
    local auraName = window.appearance.settings["aura"].name:getText()
    if auraName ~= "None" then
        local auraId = tonumber(lastSelectAura)
        if auraId then
            previewCreature:getCreature():detachEffectById(auraId)
        end
    end
    if focusedChild then
        local auraType = tonumber(focusedChild:getId())

        if checkPresetsValidity({ auraType }) then
            previewCreature:getCreature():attachEffect(g_attachedEffects.getById(auraType))
            lastSelectAura = auraType
            tempOutfit.auras = auraType
            updatePreview()
            deselectPreset()
            updateAppearanceText("aura", modules.game_attachedeffects.getName(auraType))
        else
            lastSelectAura = "None"
            tempOutfit.auras = 0
            updateAppearanceText("aura", "None")
        end
    end
end

function onWingsSelect(list, focusedChild, unfocusedChild, reason)
    local wingsName = window.appearance.settings["wings"].name:getText()
    if wingsName ~= "None" then
        local wingsId = tonumber(lastSelectWings)
        if wingsId then
            previewCreature:getCreature():detachEffectById(wingsId)
        end
    end

    if focusedChild then
        local wingsType = tonumber(focusedChild:getId())

        if checkPresetsValidity({ wingsType }) then
            previewCreature:getCreature():attachEffect(g_attachedEffects.getById(wingsType))
            lastSelectWings = wingsType
            tempOutfit.wings = wingsType
            updatePreview()
            deselectPreset()
            updateAppearanceText("wings", modules.game_attachedeffects.getName(wingsType))
        else
            lastSelectWings = "None"
            tempOutfit.wings = 0
            updateAppearanceText("wings", "None")
        end
    end
end

function onShaderSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        local shaderType = focusedChild:getId()
        if previewCreature then
            local creature = previewCreature:getCreature()
            if creature then
                if shaderType ~= "None" then
                    -- Enable shader display when selecting a shader
                    settings.showShader = true
                    -- Update checkbox without triggering event
                    if showShaderCheck then
                        showShaderCheck.onCheckChange = nil
                        showShaderCheck:setChecked(true)
                        showShaderCheck.onCheckChange = onShowShaderChange
                    end

                    lastSelectShader = shaderType
                    tempOutfit.shaders = shaderType
                    creature:setShader(shaderType)
                else
                    lastSelectShader = "Outfit - Default"
                    tempOutfit.shaders = "Outfit - Default"
                    creature:setShader("Outfit - Default")
                end
            end
        end

        deselectPreset()

        updateAppearanceText("shader", focusedChild.name:getText())
    end
end

function onHealthBarSelect(list, focusedChild, unfocusedChild, reason)
    if window.appearance.settings["healthBar"].name:getText() ~= "None" then
        previewCreature:getCreature():detachEffectById(tonumber(window.appearance.settings["healthBar"].name:getText()))
    end
    if focusedChild then
        local barType = tonumber(focusedChild:getId())
        tempOutfit.healthBar = barType
        updatePreview()
        if barType > 0 then
            previewCreature:getCreature():attachEffect(g_attachedEffects.getById(barType))
        end

        deselectPreset()

        updateAppearanceText("healthBar", focusedChild.name:getText())
    end
end

function onEffectBarSelect(list, focusedChild, unfocusedChild, reason)
    local effectName = window.appearance.settings["effects"].name:getText()
    if effectName ~= "None" then
        local effectId = tonumber(lastSelectEffects)
        if effectId then
            previewCreature:getCreature():detachEffectById(effectId)
        end
    end

    if focusedChild then
        local effect_id = tonumber(focusedChild:getId())

        if checkPresetsValidity({ effect_id }) then
            previewCreature:getCreature():attachEffect(g_attachedEffects.getById(effect_id))
            lastSelectEffects = effect_id
            tempOutfit.effects = effect_id
            updatePreview()
            deselectPreset()
            updateAppearanceText("effects", modules.game_attachedeffects.getName(effect_id))
        else
            lastSelectEffects = 0
            tempOutfit.effects = 0
            updateAppearanceText("effects", "None")
        end
    end
end

function onTitleSelect(list, focusedChild, unfocusedChild, reason)
    if window.appearance.settings["title"].name:getText() ~= "None" then
        previewCreature:getCreature():clearTitle()
    end

    if focusedChild then
        local titleType = tostring(focusedChild:getId())

        if titleType ~= "None" then
            previewCreature:getCreature():setTitle(titleType, "verdana-11px-rounded", "#0000ff")
            lastSelectTitle = titleType
        else
            lastSelectTitle = "None"
            previewCreature:getCreature():clearTitle()
        end

        updatePreview()
        deselectPreset()
        updateAppearanceText("title", focusedChild.name:getText())
    end
end

function updateAppearanceText(widget, text)
    if window.appearance.settings[widget] then
        window.appearance.settings[widget].name:setText(text)
    end
end

function updateAppearanceTexts(outfit)
    for _, appKey in ipairs(AppearanceData) do
        updateAppearanceText(appKey, "None")
    end

    for key, value in pairs(outfit) do
        local newKey = key
        local appKey = key
        if key == "type" then
            newKey = "outfits"
            appKey = "outfit"
        end
        local dataTable = ServerData[newKey]
        if dataTable then
            for _, data in ipairs(dataTable) do
                if outfit[key] == data[1] or outfit[key] == data[2] then
                    if appKey and data[2] then
                        updateAppearanceText(appKey, data[2])
                    end
                end
            end
        end
    end
end

function deselectPreset()
    settings.currentPreset = 0
end

function onAddonChange(widget, checked)
    local addonId = widget:getParent():getId()

    local addons = tempOutfit.addons
    if addonId == "addon1" then
        addons = checked and addons + 1 or addons - 1
    elseif addonId == "addon2" then
        addons = checked and addons + 2 or addons - 2
    end

    settings.currentPreset = 0

    tempOutfit.addons = addons
    updatePreview()
    if appearanceGroup:getSelectedWidget() == window.appearance.settings.outfit.check then
        showOutfits()
    end
end

function onColorModeChange(widget, selectedWidget)
    local colorMode = selectedWidget:getId()
    if colorMode == "head" then
        colorBoxGroup:selectWidget(window.appearance.colorBoxPanel["colorBox" .. tempOutfit.head])
    elseif colorMode == "primary" then
        colorBoxGroup:selectWidget(window.appearance.colorBoxPanel["colorBox" .. tempOutfit.body])
    elseif colorMode == "secondary" then
        colorBoxGroup:selectWidget(window.appearance.colorBoxPanel["colorBox" .. tempOutfit.legs])
    elseif colorMode == "detail" then
        colorBoxGroup:selectWidget(window.appearance.colorBoxPanel["colorBox" .. tempOutfit.feet])
    end
end

function onColorCheckChange(widget, selectedWidget)
    local colorId = selectedWidget.colorId
    local colorMode = colorModeGroup:getSelectedWidget():getId()
    if colorMode == "head" then
        tempOutfit.head = colorId
    elseif colorMode == "primary" then
        tempOutfit.body = colorId
    elseif colorMode == "secondary" then
        tempOutfit.legs = colorId
    elseif colorMode == "detail" then
        tempOutfit.feet = colorId
    end

    updatePreview()

    if appearanceGroup:getSelectedWidget() == window.appearance.settings.outfit.check then
        showOutfits()
    end
end

function updatePreview()
    local direction = previewCreature:getDirection()
    local previewOutfit = table.copy(tempOutfit)

    if not settings.showOutfit then
        previewCreature:hide()
    else
        previewCreature:show()
    end

    if not settings.showMount then
        previewOutfit.mount = 0
    end

    if not settings.showFamiliar or previewOutfit.familiar == 0 then
        previewOutfit.familiar = 0
        previewCreature:setMarginRight(0)
        previewFamiliar:setMarginLeft(0)
        window.preview.panel.bars:setMarginRight(20)
        previewFamiliar:setVisible(false)
    else
        if previewOutfit.familiar and previewOutfit.familiar > 0 then
            previewFamiliar:setVisible(true)
            previewCreature:setMarginRight(50)
            window.preview.panel.bars:setMarginRight(40)
            previewFamiliar:setCreatureSize(124)
            previewFamiliar:setCenter(true)
            previewFamiliar:setMarginLeft(70)
        end
    end

    if settings.showAura then
        attachOrDetachEffect(lastSelectAura, true)
    else
        attachOrDetachEffect(lastSelectAura, false)
    end

    if settings.showWings then
        attachOrDetachEffect(lastSelectWings, true)
    else
        attachOrDetachEffect(lastSelectWings, false)
    end

    if settings.showEffects then
        attachOrDetachEffect(lastSelectEffects, true)
    else
        attachOrDetachEffect(lastSelectEffects, false)
    end

    if not settings.showShader then
        if previewCreature then
            local creature = previewCreature:getCreature()
            if creature then
                creature:setShader("Outfit - Default")
            end
        end
    else
        if previewCreature and lastSelectShader then
            local creature = previewCreature:getCreature()
            if creature then
                creature:setShader(lastSelectShader)
            end
        end
    end

    if not settings.showBars then
        previewOutfit.healthBar = 0
        window.preview.panel.bars:hide()
    else
        if g_game.getFeature(GamePlayerMounts) and settings.showMount and previewOutfit.mount > 0 then
            window.preview.panel.bars:setMarginTop(-10)
            window.preview.panel.bars:setMarginLeft(60)
        else
            window.preview.panel.bars:setMarginTop(-10)
            window.preview.panel.bars:setMarginLeft(50)
        end
        local name = g_game.getCharacterName()
        window.preview.panel.bars.name:setText(name)
        if name:find("g") or name:find("j") or name:find("p") or name:find("q") or name:find("y") then
            window.preview.panel.bars.name:setHeight(14)
        else
            window.preview.panel.bars.name:setHeight(11)
        end
        window.preview.panel.bars.name:setMarginLeft(-43)

        local healthBar = window.preview.panel.bars.healthBar
        local manaBar = window.preview.panel.bars.manaBar
        manaBar:setMarginTop(0)
        healthBar:setMarginTop(1)
        healthBar.image:setMargin(0)
        healthBar.image:hide()
        manaBar.image:setMargin(0)
        manaBar.image:hide(0)

        window.preview.panel.bars:show()
    end

    previewCreature:setOutfit(previewOutfit)
    previewCreature:getCreature():setDirection(direction)

    for _, paperdoll in ipairs(g_game.getLocalPlayer():getPaperdolls()) do
        if paperdoll:canDrawOnUI() then
            local clone = paperdoll:clone()
            previewCreature:getCreature():attachPaperdoll(clone)
        end
    end
end

function rotate(value)
    if not previewCreature then
        return
    end

    local creature = previewCreature:getCreature()
    if not creature then
        return
    end

    local direction = previewCreature:getDirection()

    direction = direction + value

    if direction > Directions.West then
        direction = Directions.North
    elseif direction < Directions.North then
        direction = Directions.West
    end

    creature:setDirection(direction)
    if g_game.getFeature(GamePlayerFamiliars) and previewFamiliar then
        local familiarCreature = previewFamiliar:getCreature()
        if familiarCreature then
            familiarCreature:setDirection(direction)
        end
    end
    if floor then
        floor:setMargin(0)
    end
end

function onFilterOnlyMine(self, checked)
    addEvent(function()
        local children = window.selectionList:getChildren()
        for _, child in ipairs(children) do
            if checked and (not child.state or child.state ~= 0) then
                window.selectionList:focusChild(nil)
                child:hide()
            else
                child:show()
            end
        end
    end)
end

function onFilterSearch()
    addEvent(function()
        if not window then return end
        local searchText = window.listSearch.search:getText():lower():trim()
        local children = window.selectionList:getChildren()
        if searchText:len() >= 1 then
            for _, child in ipairs(children) do
                local text = child.name:getText():lower()
                if text:find(searchText) then
                    child:show()
                else
                    child:hide()
                end
            end
        else
            for _, child in ipairs(children) do
                child:show()
            end
        end
    end)
end

function saveSettings()
    if not g_resources.fileExists(settingsFile) then
        g_resources.makeDir("/settings")
        -- Safely attempt to write initial file
        local writeStatus, writeError = pcall(function()
            return g_resources.writeFileContents(settingsFile, "[]")
        end)

        if not writeStatus then
            g_logger.debug("Could not create outfit settings file during logout: " .. tostring(writeError))
            return
        end
    end

    local fullSettings = {}
    do
        local json_status, json_data = pcall(function()
            return json.decode(g_resources.readFileContents(settingsFile))
        end)

        if not json_status then
            g_logger.error("[saveSettings] Couldn't load JSON: " .. json_data)
            return
        end
        fullSettings = json_data
    end

    fullSettings[g_game.getCharacterName()] = settings

    local json_status, json_data = pcall(function()
        return json.encode(fullSettings)
    end)

    if not json_status then
        g_logger.error("[saveSettings] Couldn't save JSON: " .. json_data)
        return
    end

    -- Safely attempt to write the settings file
    local writeStatus, writeError = pcall(function()
        return g_resources.writeFileContents(settingsFile, json.encode(fullSettings))
    end)

    if not writeStatus then
        g_logger.debug("Could not save outfit settings during logout: " .. tostring(writeError))
    end
end

function loadSettings()
    if not g_resources.fileExists(settingsFile) then
        g_resources.makeDir("/settings")
    end

    if g_resources.fileExists(settingsFile) then
        local json_status, json_data = pcall(function()
            return json.decode(g_resources.readFileContents(settingsFile))
        end)

        if not json_status then
            g_logger.error("[loadSettings] Couldn't load JSON: " .. json_data)
            return
        end

        settings = json_data[g_game.getCharacterName()]
        if not settings then
            loadDefaultSettings()
        end
    else
        loadDefaultSettings()
    end
end

function loadDefaultSettings()
    settings = {
        movement = true,
        showFloor = true,
        showOutfit = true,
        showMount = true,
        showFamiliar = true,
        showWings = true,
        showAura = true,
        showShader = true,
        showBars = true,
        showTitle = true,
        showEffects = true,
        presets = {},
        currentPreset = 0
    }
    settings.currentPreset = 0
end

function accept()
    if g_game.getFeature(GamePlayerMounts) then
        local player = g_game.getLocalPlayer()
        local isMountedChecked = window.configure.mount.check:isChecked()
        if not player:isMounted() and isMountedChecked then
            player:mount()
        elseif player:isMounted() and not isMountedChecked then
            player:dismount()
        end
        if settings.currentPreset > 0 then
            settings.presets[settings.currentPreset].mounted = isMountedChecked
        end
    end
    if g_game.getFeature(GamePlayerFamiliars) then
        if settings.currentPreset > 0 then
            -- Check if familiar configuration exists before accessing it
            if window.configure.familiar and window.configure.familiar.check then
                settings.presets[settings.currentPreset].familiar = window.configure.familiar.check:isChecked()
            else
                -- Default to false if the familiar check doesn't exist
                settings.presets[settings.currentPreset].familiar = false
            end
        end
    end
    g_game.changeOutfit(tempOutfit)
    destroy()
end
