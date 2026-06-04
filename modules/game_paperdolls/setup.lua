controller = Controller:new()

function controller:onGameStart()
    -- g_game.getLocalPlayer():attachPaperdoll(g_paperdolls.getById(1))
    -- g_game.getLocalPlayer():attachPaperdoll(g_paperdolls.getById(2))
    -- g_game.getLocalPlayer():attachPaperdoll(g_paperdolls.getById(3))
    -- g_game.getLocalPlayer():attachPaperdoll(g_paperdolls.getById(4))
end

function controller:onGameEnd()
    -- g_game.getLocalPlayer():clearPaperdolls()
end

function controller:onTerminate()
    g_paperdolls.clear()
end

local function onAttach(paperdoll, owner)
    local outfitType = owner:getOutfit().type
    local config = PaperdollManager.getConfig(paperdoll:getId(), outfitType)

    if config.isThingConfig then
        PaperdollManager.executeThingConfig(paperdoll, outfitType)
    end

    if config.onAttach then
        config.onAttach(paperdoll, owner, config.__onAttach)
    end
end

local function onDetach(paperdoll, oldOwner)
    local config = PaperdollManager.getConfig(paperdoll:getId(), oldOwner:getOutfit().type)

    if config.onDetach then
        config.onDetach(paperdoll, oldOwner, config.__onDetach)
    end
end

local function onOutfitChange(creature, outfit, oldOutfit)
    for _i, paperdoll in pairs(creature:getPaperdolls()) do
        PaperdollManager.executeThingConfig(paperdoll, outfit.type)
    end
end

controller:registerEvents(LocalPlayer, {
    onOutfitChange = onOutfitChange
})
controller:registerEvents(Creature, {
    onOutfitChange = onOutfitChange
})
controller:registerEvents(Paperdoll, {
    onAttach = onAttach,
    onDetach = onDetach
})
