--[[
    registerThingConfig(thingId, thingType)
    set(paperdollId, config)
]]
--
local c = PaperdollManager.registerThingConfig(35)

c:set(1, {
    sizeFactor = 1.7,
    dirOffset = {
        [North] = { 0, 0 },
        [East] = { 0, 5 },
        [South] = { 5, 0 },
        [West] = { 10, 5 }
    }
})

c:set(2, {
    sizeFactor = 1.7,
    dirOffset = {
        [North] = { 0, 20, false },
        [East] = { -15, 5 },
        [South] = { 5, -15 },
        [West] = { 5, -15 }
    }
})

c:set(3, {
    sizeFactor = 1.7,
    dirOffset = {
        [North] = { 0, -10 },
        [East] = { -15, -3 },
        [South] = { 0, -10 },
        [West] = { -10, -5 }
    }
})
