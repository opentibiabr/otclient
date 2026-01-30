local options = dofile("data_options")
panels = {
    generalPanel = nil,
    graphicsPanel = nil,
    soundPanel = nil,
    gameMapPanel = nil,
    graphicsEffectsPanel = nil,
    interfaceHUD = nil,
    interface = nil,
    misc = nil,
    miscHelp = nil,
    keybindsPanel = nil
}

-- Hook into application exit to ensure settings are saved
local function onAppExit()
    g_settings.save()
end

-- Register the exit hook when the module is loaded
connect(g_app, { onExit = onAppExit })

-- LuaFormatter off
local buttons = { {

    text = "Controls",
    icon = "/images/icons/icon_controls",
    open = "generalPanel",
    subCategories = { {
        text = "General Hotkeys",
        open = "keybindsPanel"
    } }
}, {
    text = "Interface",
    icon = "/images/icons/icon_interface",
    open = "interface",
    subCategories = { {
        text = "HUD",
        open = "interfaceHUD"
    }, {
        text = "Console",
        open = "interfaceConsole"
    }, {
        text = "Action Bars",
        open = "actionbars"
    } }
}, {
    text = "Graphics",
    icon = "/images/icons/icon_graphics",
    open = "graphicsPanel",
    subCategories = { {
        text = "Effects",
        open = "graphicsEffectsPanel"
    } }
}, {
    text = "Sound",
    icon = "/images/icons/icon_sound",
    open = "soundPanel"
    --[[     subCategories = {{
        text = "Battle Sounds",
        open = "Battle_Sounds"
    }, {
        text = "UI Sounds",
        open = "UI_Sounds"
    }} ]]
}, {
    text = "Misc.",
    icon = "/images/icons/icon_misc",
    open = "misc",
    subCategories = { --[[ {
        text = "GamePlay",
        open = "GamePlay"
    },  {
        text = "Screenshots",
        open = "Screenshots"
    }, ]] {
        text = "Help",
        open = "miscHelp"
    } }
} }

-- LuaFormatter on
local extraWidgets = {
    audioButton = nil,
    optionsButton = nil,
    logoutButton = nil,
    optionsButtons = nil
}

local function toggleDisplays()
    if options['displayNames'].value and options['displayHealth'].value and options['displayMana'].value and options['displayHarmony'].value then
        setOption('displayNames', false)
    elseif options['displayHealth'].value then
        setOption('displayHealth', false)
        setOption('displayMana', false)
        setOption('displayHarmony', false)
    else
        if not options['displayNames'].value and not options['displayHealth'].value then
            setOption('displayNames', true)
        else
            setOption('displayHealth', true)
            setOption('displayMana', true)
            setOption('displayHarmony', true)
        end
    end
end

local function toggleOption(key)
    setOption(key, not getOption(key))
end

local function setupComboBox()
    local crosshairCombo = panels.interface:recursiveGetChildById('crosshair')
    local antialiasingModeCombobox = panels.graphicsPanel:recursiveGetChildById('antialiasingMode')
    local floorViewModeCombobox = panels.graphicsEffectsPanel:recursiveGetChildById('floorViewMode')
    local framesRarityCombobox = panels.interface:recursiveGetChildById('frames')
    local vocationPresetsCombobox = panels.keybindsPanel:recursiveGetChildById('list')
    local listKeybindsPanel = panels.keybindsPanel:recursiveGetChildById('list')
    local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
    local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')

    for k, v in pairs({ { 'Disabled', 'disabled' }, { 'Default', 'default' }, { 'Full', 'full' } }) do
        crosshairCombo:addOption(v[1], v[2])
    end

    crosshairCombo.onOptionChange = function(comboBox, option)
        setOption('crosshair', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox:addOption('Regular Controls', 0)
    mouseControlModeCombobox:addOption('Classic Controls', 1)
    mouseControlModeCombobox:addOption('Left Smart-Click', 2)

    lootControlModeCombobox:addOption('Loot: Right', 0)
    lootControlModeCombobox:addOption('Loot: SHIFT+Right', 1)
    lootControlModeCombobox:addOption('Loot: Left', 2)
    
    lootControlModeCombobox.onOptionChange = function(comboBox, option)
        setOption('lootControlMode', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox.onOptionChange = function(comboBox, option)
        local selectedOption = comboBox:getCurrentOption().data
        setOption('mouseControlMode', selectedOption)
        
        -- The mouseControlMode action handler will take care of updating
        -- classicControl and smartLeftClick, and their UI visibility
    end

    for k, t in pairs({ 'None', 'Antialiasing', 'Smooth Retro' }) do
        antialiasingModeCombobox:addOption(t, k - 1)
    end

    antialiasingModeCombobox.onOptionChange = function(comboBox, option)
        setOption('antialiasingMode', comboBox:getCurrentOption().data)
    end


    for k, t in pairs({ 'Normal', 'Fade', 'Locked', 'Always', 'Always with transparency' }) do
        floorViewModeCombobox:addOption(t, k - 1)
    end

    floorViewModeCombobox.onOptionChange = function(comboBox, option)
        setOption('floorViewMode', comboBox:getCurrentOption().data)
    end

    for k, v in pairs({ { 'None', 'none' }, { 'Frames', 'frames' }, { 'Corners', 'corners' } }) do
        framesRarityCombobox:addOption(v[1], v[2])
    end

    framesRarityCombobox.onOptionChange = function(comboBox, option)
        setOption('framesRarity', comboBox:getCurrentOption().data)
    end

    local profileCombobox = panels.misc:recursiveGetChildById('profile')

    for i = 1, 10 do
        profileCombobox:addOption(tostring(i), i)
    end

    profileCombobox.onOptionChange = function(comboBox, option)
        setOption('profile', comboBox:getCurrentOption().data)
    end

    for _, preset in ipairs(Keybind.presets) do
        listKeybindsPanel:addOption(preset)
    end
    listKeybindsPanel.onOptionChange = function(comboBox, option)
        setOption('listKeybindsPanel', option)
    end
    panels.keybindsPanel.presets.list:setCurrentOption(Keybind.currentPreset)
end

local function setup()
    panels.gameMapPanel = modules.game_interface.getMapPanel()

    setupComboBox()

    -- load options
    for k, obj in pairs(options) do
        local v = obj.value

        if type(v) == 'boolean' then
            local value = g_settings.getBoolean(k)
            setOption(k, value, true)
        elseif type(v) == 'number' then
            local value = g_settings.getNumber(k)
            setOption(k, value, true)
        elseif type(v) == 'string' then
            local value = g_settings.getString(k)
            setOption(k, value, true)
        end
    end
    
    -- Special handling for mouseControlMode to ensure it's in sync with the underlying options
    local mouseControlMode = g_settings.getNumber('mouseControlMode')
    if mouseControlMode ~= nil then
        setOption('mouseControlMode', mouseControlMode, true)
    else
        -- Derive from classicControl and smartLeftClick if mouseControlMode isn't set
        local classicControl = g_settings.getBoolean('classicControl')
        local smartLeftClick = g_settings.getBoolean('smartLeftClick')
        
        if classicControl then
            setOption('mouseControlMode', 1, true)
        elseif smartLeftClick then
            setOption('mouseControlMode', 2, true)
        else
            setOption('mouseControlMode', 0, true)
        end
    end
    
    -- Schedule combobox updates to ensure they happen after UI setup is complete
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        -- Update loot control mode visibility
        if lootControlModeCombobox and mouseControlModeCombobox then
            if options.mouseControlMode.value == 1 then
                lootControlModeCombobox:setVisible(true)
            else
                lootControlModeCombobox:setVisible(false)
            end
        end
    end, 100)
end


controller = Controller:new()
controller:setUI('options')

function controller:onInit()
    for k, obj in pairs(options) do
        if type(obj) ~= "table" then
            obj = { value = obj }
            options[k] = obj
        end
        g_settings.setDefault(k, obj.value)
    end

    extraWidgets.audioButton = modules.client_topmenu.addTopRightToggleButton('audioButton', tr('Audio'),
        '/images/topbuttons/button_mute_up', function() toggleOption('enableAudio') end)

    extraWidgets.optionsButton = modules.client_topmenu.addTopRightToggleButton('optionsButton', tr('Options'),
        '/images/topbuttons/button_options', toggle)

    extraWidgets.logoutButton = modules.client_topmenu.addTopRightToggleButton('logoutButton', tr('Exit'),
        '/images/topbuttons/logout', toggle)

    panels.generalPanel = g_ui.loadUI('styles/controls/general', controller.ui.optionsTabContent)
    panels.keybindsPanel = g_ui.loadUI('styles/controls/keybinds', controller.ui.optionsTabContent)

    panels.graphicsPanel = g_ui.loadUI('styles/graphics/graphics', controller.ui.optionsTabContent)
    panels.graphicsEffectsPanel = g_ui.loadUI('styles/graphics/effects', controller.ui.optionsTabContent)

    panels.interface = g_ui.loadUI('styles/interface/interface', controller.ui.optionsTabContent)
    panels.interfaceConsole = g_ui.loadUI('styles/interface/console', controller.ui.optionsTabContent)
    panels.interfaceHUD = g_ui.loadUI('styles/interface/HUD', controller.ui.optionsTabContent)
    panels.actionbars = g_ui.loadUI('styles/interface/actionbars', controller.ui.optionsTabContent)

    panels.soundPanel = g_ui.loadUI('styles/sound/audio', controller.ui.optionsTabContent)

    panels.misc = g_ui.loadUI('styles/misc/misc', controller.ui.optionsTabContent)
    panels.miscHelp = g_ui.loadUI('styles/misc/help', controller.ui.optionsTabContent)

    self.ui:hide()

    configureCharacterCategories()
    addEvent(setup)
    
    -- Add a special delayed event to update comboboxes after everything is loaded
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
    end, 1000)  -- 1 second delay to make sure everything is loaded
    
    init_binds()

    Keybind.new("UI", "Toggle Fullscreen", "Ctrl+Shift+F", "")
    Keybind.bind("UI", "Toggle Fullscreen", {
        {
            type = KEY_DOWN,
            callback = function() toggleOption('fullscreen') end,
        }
    })
    Keybind.new("UI", "Show/hide FPS / lag indicator", "", "")
    Keybind.bind("UI", "Show/hide FPS / lag indicator", { {
        type = KEY_DOWN,
        callback = function()
            toggleOption('showPing')
            toggleOption('showFps')
        end
    } })

    Keybind.new("UI", "Show/hide Creature Names and Bars", "Ctrl+N", "")
    Keybind.bind("UI", "Show/hide Creature Names and Bars", {
        {
            type = KEY_DOWN,
            callback = toggleDisplays,
        }
    })

    Keybind.new("Sound", "Mute/unmute", "", "")
    Keybind.bind("Sound", "Mute/unmute", {
        {
            type = KEY_DOWN,
            callback = function() toggleOption('enableAudio') end,
        }
    })
end

function controller:onTerminate()
    -- Make sure all settings are saved before terminating
    g_settings.save()
    
    -- Disconnect from app exit
    disconnect(g_app, { onExit = onAppExit })
    
    extraWidgets.optionsButton:destroy()
    extraWidgets.audioButton:destroy()
    panels = {}
    extraWidgets = {}
    buttons = {}
    Keybind.delete("UI", "Toggle Fullscreen")
    Keybind.delete("UI", "Show/hide Creature Names and Bars")
    Keybind.delete("UI", "Show/hide FPS / lag indicator")
    Keybind.delete("Sound", "Mute/unmute")

    terminate_binds()
end

function controller:onGameStart()
    if g_settings.getBoolean("autoSwitchPreset") then
        local name = g_game.getCharacterName()
        if Keybind.selectPreset(name) then
            panels.keybindsPanel.presets.list:setCurrentOption(name, true)
            updateKeybinds()
        end
    end
end

function setOption(key, value, force)
    if not modules.game_interface then
        return
    end

    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to set unknown option: '%s'", key))
        return
    end
    
    if not force and option.value == value then
        return
    end

    if option.action then
        option.action(value, options, controller, panels, extraWidgets)
    end


    -- change value for keybind updates
    for _, panel in pairs(panels) do
        local widget = panel:recursiveGetChildById(key)
        if widget then
            if widget:getStyle().__class == 'UICheckBox' then
                widget:setChecked(value)
            elseif widget:getStyle().__class == 'UIScrollBar' then
                widget:setValue(value)
            elseif widget:recursiveGetChildById('valueBar') then
                widget:recursiveGetChildById('valueBar'):setValue(value)
            end
            break
        end
    end

    option.value = value
    g_settings.set(key, value)
end

function setupOptionsMainButton()
    if extraWidgets.optionsButtons then
        return
    end

    extraWidgets.optionsButtons = modules.game_mainpanel.addSpecialToggleButton('optionsMainButton', tr('Options'),
        '/images/options/button_options', toggle, true)
end

function getOption(key)
    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to get unknown option: '%s'", key))
        return nil
    end
    return option.value
end

function show()
    controller.ui:show()
    controller.ui:raise()
    controller.ui:focus()
end

function hide()
    -- Save all settings when closing the options window
    g_settings.save()
    controller.ui:hide()
end

function saveOptions()
    g_settings.save()
end

function toggle()
    if controller.ui:isVisible() then
        hide()
        return
    end
    if not controller.ui.openedCategory then
        local firstCategory = controller.ui.optionsTabBar:getChildByIndex(1)
        controller.ui.openedCategory = firstCategory
        firstCategory.Button:onClick()
        local panelToShow = panels[firstCategory.open]
        if panelToShow then
            panelToShow:show()
            controller.ui.selectedOption = panelToShow
        end
    end
    show()
    updateKeybinds()
end

function addTab(name, panel, icon)
    print("to prevent the error use Ex = g_ui.loadUI('option_healthcircle',modules.client_options:getPanel()) ")
end

function removeTab(v)
    print("to prevent the error use Ex   modules.client_options.addButton('Interface', 'HP/MP Circle', optionPanel)")
end

local function toggleSubCategories(parent, isOpen)
    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)
        if subWidget then
            subWidget:setVisible(isOpen)
        end
    end
    parent:setHeight(isOpen and parent.openedSize or parent.closedSize)
    parent.opened = isOpen
    parent.Button.Arrow:setVisible(not isOpen)
end

local function close(parent)
    if parent.subCategories then
        toggleSubCategories(parent, false)
    end
end

local function open(parent)
    local oldOpen = controller.ui.openedCategory
    if oldOpen and oldOpen ~= parent then
        close(oldOpen)
    end
    toggleSubCategories(parent, true)
    controller.ui.openedCategory = parent
end

function selectCharacterPage()
    local selectedOption = controller.ui.selectedOption
    if selectedOption then
        selectedOption:hide()
    end
    if controller.ui.InfoBase then
        controller.ui.InfoBase:setVisible(true)
        controller.ui.InfoBase:show()
    end
end

local function createSubWidget(parent, subId, subButton)
    local subWidget = g_ui.createWidget("OptionsCategory", parent)
    subWidget:setId(subId)
    subWidget.Button.Icon:setIcon(subButton.icon)
    subWidget.Button.Title:setText(subButton.text)
    subWidget:setVisible(false)
    subWidget.open = subButton.open
    subWidget.callbackFunc = subButton.callbackFunc

    function subWidget.Button.onClick()
        local selectedOption = controller.ui.selectedOption
        closeCharacterButtons()
        parent.Button:setChecked(false)
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource("")
        subWidget.Button:setChecked(true)
        subWidget.Button.Arrow:setVisible(true)
        subWidget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")

        if selectedOption then
            selectedOption:hide()
        end

        local panelToShow = panels[subWidget.open]
        if panelToShow then
            panelToShow:show()
            panelToShow:setVisible(true)
            controller.ui.selectedOption = panelToShow
        else
            print("Error: panelToShow is nil or does not exist in panels")
        end
        if subWidget.callbackFunc then
            subWidget.callbackFunc()
        end
    end

    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
    if subId == 1 then
        subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
        subWidget:setMarginTop(20)
    else
        subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
        subWidget:setMarginTop(-1)
    end

    return subWidget
end

function configureCharacterCategories()
    controller.ui.optionsTabBar:destroyChildren()

    for id, button in ipairs(buttons) do
        local widget = g_ui.createWidget("OptionsCategory", controller.ui.optionsTabBar)
        widget:setId(id)
        widget.Button.Icon:setIcon(button.icon)
        widget.Button.Title:setText(button.text)
        widget.open = button.open

        if button.subCategories then
            widget.subCategories = button.subCategories
            widget.subCategoriesSize = #button.subCategories
            widget.Button.Arrow:setVisible(true)

            for subId, subButton in ipairs(button.subCategories) do
                local subWidget = createSubWidget(widget, subId, subButton)
                if button.text == "Controls" then
                    subWidget.Button.Title:setMarginLeft(-5)
                end
            end
        end

        widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
        if id == 1 then
            widget:addAnchor(AnchorTop, "parent", AnchorTop)
            widget:setMarginTop(10)
        else
            widget:addAnchor(AnchorTop, "prev", AnchorBottom)
            widget:setMarginTop(10)
        end

        function widget.Button.onClick()
            local parent = widget
            local oldOpen = controller.ui.openedCategory

            if oldOpen and oldOpen ~= parent then
                if oldOpen.Button then
                    oldOpen.Button:setChecked(false)
                    oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
                end

                close(oldOpen)
            end

            if parent.subCategoriesSize then
                parent.closedSize = parent.closedSize or parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                parent.openedSize = parent.openedSize or parent:getHeight() * (parent.subCategoriesSize + 1) - 6

                if not parent.opened then
                    open(parent)
                end
            end

            widget.Button:setChecked(true)
            widget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
            widget.Button.Arrow:setVisible(true)

            if controller.ui.selectedOption then
                controller.ui.selectedOption:hide()
            end

            local panelToShow = panels[parent.open]
            if panelToShow then
                closeCharacterButtons()
                panelToShow:show()
                panelToShow:setVisible(true)
                controller.ui.selectedOption = panelToShow
            else
                print("Error: panelToShow is nil or does not exist in panels")
            end

            controller.ui.openedCategory = parent
        end
    end
end

function closeCharacterButtons()
    for i = 1, controller.ui.optionsTabBar:getChildCount() do
        local widget = controller.ui.optionsTabBar:getChildByIndex(i)
        if widget and widget.subCategories then
            for subId, _ in ipairs(widget.subCategories) do
                local subWidget = widget:getChildById(subId)
                if subWidget then
                    subWidget.Button:setChecked(false)
                    subWidget.Button.Arrow:setVisible(false)
                end
            end
        end
    end
end

function createCategory(text, icon, openPanel, subCategories)
    local newCategory = {
        text = text,
        icon = icon,
        open = type(openPanel) == "string" and openPanel or getPanelName(openPanel),
        subCategories = subCategories
    }
    table.insert(buttons, newCategory)
    if type(openPanel) ~= "string" then
        panels[getPanelName(openPanel)] = openPanel
    end
    configureCharacterCategories()
end

function removeCategory(categoryText, subcategoryText)
    for i, category in ipairs(buttons) do
        if category.text == categoryText then
            if subcategoryText then
                if category.subCategories then
                    for j, subcategory in ipairs(category.subCategories) do
                        if subcategory.text == subcategoryText then
                            panels[subcategory.open] = nil
                            table.remove(category.subCategories, j)
                            break
                        end
                    end
                end
            else
                panels[category.open] = nil
                if category.subCategories then
                    for _, subcategory in ipairs(category.subCategories) do
                        panels[subcategory.open] = nil
                    end
                end
                table.remove(buttons, i)
            end
            configureCharacterCategories()
            return
        end
    end
end

function removeButton(categoryText, buttonText)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if category.subCategories then
                for i, subcategory in ipairs(category.subCategories) do
                    if subcategory.text == buttonText then
                        panels[subcategory.open] = nil
                        table.remove(category.subCategories, i)
                        configureCharacterCategories()
                        return
                    end
                end
            end
        end
    end
end

function addButton(categoryText, buttonText, openPanel, callback)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if not category.subCategories then
                category.subCategories = {}
            end
            local panelName = type(openPanel) == "string" and openPanel or getPanelName(openPanel)
            table.insert(category.subCategories, {
                text = buttonText,
                open = panelName,
                callbackFunc = callback
            })
            if type(openPanel) ~= "string" then
                panels[panelName] = openPanel
            end
            configureCharacterCategories()
            return
        end
    end
end

function getPanelName(panel)
    for name, p in pairs(panels) do
        if p == panel then
            return name
        end
    end
    return "panel_" .. tostring(panel):match("userdata: 0x(%x+)")
end

function addSubcategoryToCategory(categoryText, newSubcategory)
    addButtonToCategory(categoryText, newSubcategory)
end

function getPanel()
    return controller.ui.optionsTabContent
end

function openOptionsCategory(category, subcategory)
    if not controller.ui:isVisible() then
        show()
    end
    for i = 1, controller.ui.optionsTabBar:getChildCount() do
        local widget = controller.ui.optionsTabBar:getChildByIndex(i)
        if widget and widget.Button.Title:getText() == category then
            widget.Button:onClick()
            if subcategory and widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button.Title:getText() == subcategory then
                        subWidget.Button:onClick()
                        return true
                    end
                end
            end
            return true
        end
    end
    return false
end
