local MODERN_IMBUEMENT_VERSION = 1510

local activeDesign
local activeDesignName

local function isModernImbuementWindow()
    return g_game.getClientVersion() >= MODERN_IMBUEMENT_VERSION
end

local function terminateActiveDesign()
    if activeDesign and activeDesign.terminate then
        activeDesign.terminate()
    end

    activeDesign = nil
    activeDesignName = nil
end

local function activateDesign(name)
    if activeDesignName == name and activeDesign then
        return activeDesign
    end

    terminateActiveDesign()

    if name == 'new' then
        activeDesign = dofile('new_design/main')
    elseif name == 'old' then
        activeDesign = dofile('old_design/imbuing')
    else
        error('Unknown imbuing design: ' .. tostring(name))
    end

    if type(activeDesign) ~= 'table' then
        error('Imbuing design "' .. tostring(name) .. '" did not return a valid API table')
    end

    activeDesignName = name
    if activeDesign.init then
        activeDesign.init()
    end

    return activeDesign
end

local function callActive(method, ...)
    if activeDesign and activeDesign[method] then
        return activeDesign[method](...)
    end
end

local function callNew(method, ...)
    return activateDesign('new')[method](...)
end

local function callOld(method, ...)
    return activateDesign('old')[method](...)
end

local function onGameStart()
    terminateActiveDesign()
end

local function onGameEnd()
    terminateActiveDesign()
end

local function onOpenImbuementWindow(...)
    return callNew('onOpenImbuementWindow', ...)
end

local function onImbuementItem(...)
    if isModernImbuementWindow() then
        return callNew('onImbuementItem', ...)
    else
        return callOld('onImbuementItem', ...)
    end
end

local function onImbuementScroll(...)
    return callNew('onImbuementScroll', ...)
end

local function onResourcesBalanceChange(...)
    if activeDesignName == 'old' and not isModernImbuementWindow() then
        return callActive('onResourcesBalanceChange', ...)
    end
end

local function onCloseImbuementWindow()
    terminateActiveDesign()
end

local function onMessageDialog(...)
    if activeDesignName == 'new' then
        return callActive('onMessageDialog', ...)
    end
end

function hide()
    return callActive('hide')
end

function close()
    return callActive('close')
end

function onSelectItem()
    return callActive('onSelectItem')
end

function onSelectScroll()
    return callActive('onSelectScroll')
end

function onItemSlot(widget)
    return callActive('onItemSlot', widget)
end

function onItemBaseType(selectedButtonId)
    return callActive('onItemBaseType', selectedButtonId)
end

function onScrollBaseType(selectedButtonId)
    return callActive('onScrollBaseType', selectedButtonId)
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onOpenImbuementWindow = onOpenImbuementWindow,
        onImbuementItem = onImbuementItem,
        onImbuementScroll = onImbuementScroll,
        onResourcesBalanceChange = onResourcesBalanceChange,
        onCloseImbuementWindow = onCloseImbuementWindow,
        onMessageDialog = onMessageDialog
    })

    if g_game.isOnline() then
        addEvent(onGameStart)
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onOpenImbuementWindow = onOpenImbuementWindow,
        onImbuementItem = onImbuementItem,
        onImbuementScroll = onImbuementScroll,
        onResourcesBalanceChange = onResourcesBalanceChange,
        onCloseImbuementWindow = onCloseImbuementWindow,
        onMessageDialog = onMessageDialog
    })

    terminateActiveDesign()
end
