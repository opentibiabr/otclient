--[[
    register(id, name, thingId, config)
    config = {
        drawOnUI, priority, onlyAddon, addon,
        shader, sizeFactor,
        color, headColor, bodyColor, legsColor, feetColor,
        useMountPattern, showOnMount
        offset{x, y, onTop}, dirOffset[dir]{x, y, onTop},
        mountOffset{x, y, onTop}, mountDirOffset[dir]{x, y, onTop},
        onAttach, onDetach
    }
]]
--

PaperdollManager.register(1, 'Armadura', 512, {
    priority = 1,
    addon = 1,
    onlyAddon = true,
    onAttach = function(paperdoll, creature)
        print('onAttach: ', paperdoll:getId(), creature:getName())
    end,
    onDetach = function(paperdoll, creature)
        print('onDetach: ', paperdoll:getId(), creature:getName())
    end
})

PaperdollManager.register(2, 'Weapons/shield', 512, {
    priority = 2,
    addon = 2,
    onlyAddon = true
})

PaperdollManager.register(3, 'Peitoral', 367, {
    priority = 3,
    addon = 1,
    onlyAddon = true
})

PaperdollManager.register(4, 'Akuma Aura', 664, {
    priority = 4,
    addon = 1,
    onlyAddon = true
})

PaperdollManager.register(5, 'Mochila', 136, {
    priority = 5,
    addon = 1,
    color = 77,
    onlyAddon = true
})
