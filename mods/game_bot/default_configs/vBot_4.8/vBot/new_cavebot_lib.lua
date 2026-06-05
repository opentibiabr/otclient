CaveBot = {} -- global namespace

-------------------------------------------------------------------
-- CaveBot lib 1.0
-- Contains a universal set of functions to be used in CaveBot

----------------------[[ basic assumption ]]-----------------------
-- in general, functions cannot be slowed from within, only externally, by event calls, delays etc.
-- considering that and the fact that there is no while loop, every function return action
-- thus, functions will need to be verified outside themselfs or by another function
-- overall tips to creating extension:
--   - functions return action(nil) or true(done)
--   - extensions are controlled by retries var
-------------------------------------------------------------------

-- local variables, constants and functions, used by global functions
local LOCKERS_LIST = {3497, 3498, 3499, 3500}
local LOCKER_ACCESSTILE_MODIFIERS = {
    [3497] = {0,-1},
    [3498] = {1,0},
    [3499] = {0,1},
    [3500] = {-1,0}
}

local function CaveBotConfigParse()
	local name = storage["_configs"]["targetbot_configs"]["selected"]
    if not name then
        return warn("[vBot] Please create a new TargetBot config and reset bot")
    end
	local file = configDir .. "/targetbot_configs/" .. name .. ".json"
	local data = g_resources.readFileContents(file)
	return Config.parse(data)['looting']
end

local function getNearTiles(pos)
    if type(pos) ~= "table" then
        pos = pos:getPosition()
    end

    local tiles = {}
    local dirs = {
        {-1, 1},
        {0, 1},
        {1, 1},
        {-1, 0},
        {1, 0},
        {-1, -1},
        {0, -1},
        {1, -1}
    }
    for i = 1, #dirs do
        local tile =
            g_map.getTile(
            {
                x = pos.x - dirs[i][1],
                y = pos.y - dirs[i][2],
                z = pos.z
            }
        )
        if tile then
            table.insert(tiles, tile)
        end
    end

    return tiles
end

-- ##################### --
-- [[ Information class ]] --
-- ##################### --

--- global variable to reflect current CaveBot status
CaveBot.Status = "waiting"

--- Parses config and extracts loot list.
-- @return table
function CaveBot.GetLootItems()
    local t = CaveBotConfigParse() and CaveBotConfigParse()["items"] or nil

    local returnTable = {}
    if type(t) == "table" then
        for i, item in pairs(t) do
            table.insert(returnTable, item["id"])
        end
    end

    return returnTable
end

--- Checks whether player has any visible items to be stashed
-- @return boolean
function CaveBot.HasLootItems()
    for _, container in pairs(getContainers()) do
        local name = container:getName():lower()
        if not name:find("depot") and not name:find("your inbox") then
            for _, item in pairs(container:getItems()) do
                local id = item:getId()
                if table.find(CaveBot.GetLootItems(), id) then
                    return true
                end
            end
        end
    end
end

--- Parses config and extracts loot containers.
-- @return table
function CaveBot.GetLootContainers()
    local t = CaveBotConfigParse() and CaveBotConfigParse()["containers"] or nil

    local returnTable = {}
    if type(t) == "table" then
        for i, container in pairs(t) do
            table.insert(returnTable, container["id"])
        end
    end

    return returnTable
end

--- Information about open containers.
-- @param amount is boolean
-- @return table or integer
function CaveBot.GetOpenedLootContainers(containerTable)
    local containers = CaveBot.GetLootContainers()

    local t = {}
    for i, container in pairs(getContainers()) do
        local containerId = container:getContainerItem():getId()
        if table.find(containers, containerId) then
            table.insert(t, container)
        end
    end

    return containerTable and t or #t
end

--- Some actions needs to be additionally slowed down in case of high ping.
-- Maximum at 2000ms in case of lag spike.
-- @param multiplayer is integer
-- @return void
function CaveBot.PingDelay(multiplayer)
    multiplayer = multiplayer or 1
    if ping() and ping() > 150 then -- in most cases ping above 150 affects CaveBot
        local value = math.min(ping() * multiplayer, 2000)
        return delay(value)
    end
end

-- ##################### --
-- [[ Container class ]] --
-- ##################### --

--- Closes any loot container that is open.
-- @return void or boolean
function CaveBot.CloseLootContainer()
    local containers = CaveBot.GetLootContainers()

    for i, container in pairs(getContainers()) do
        local containerId = container:getContainerItem():getId()
        if table.find(containers, containerId) then
            return g_game.close(container)
        end
    end

    return true
end

function CaveBot.CloseAllLootContainers()
    local containers = CaveBot.GetLootContainers()

    for i, container in pairs(getContainers()) do
        local containerId = container:getContainerItem():getId()
        if table.find(containers, containerId) then
            g_game.close(container)
        end
    end

    return true
end

--- Opens any loot container that isn't already opened.
-- @return void or boolean
function CaveBot.OpenLootContainer()
    local containers = CaveBot.GetLootContainers()

    local t = {}
    for i, container in pairs(getContainers()) do
        local containerId = container:getContainerItem():getId()
        table.insert(t, containerId)
    end

    for _, container in pairs(getContainers()) do
        for _, item in pairs(container:getItems()) do
            local id = item:getId()
            if table.find(containers, id) and not table.find(t, id) then
                return g_game.open(item)
            end
        end
    end

    return true
end

-- ##################### --
-- [[[ Position class ]] --
-- ##################### --

--- Compares distance between player position and given pos.
-- @param position is table
-- @param distance is integer
-- @return boolean
function CaveBot.MatchPosition(position, distance)
    local pPos = player:getPosition()
    distance = distance or 1
    return getDistanceBetween(pPos, position) <= distance
end

--- Stripped down to take less space.
-- Use only to safe position, like pz movement or reaching npc.
-- Needs to be called between 200-500ms to achieve fluid movement.
-- @param position is table
-- @param distance is integer
-- @return void
function CaveBot.GoTo(position, precision)
    if not precision then
        precision = 3
    end
    return CaveBot.walkTo(position, 20, {ignoreCreatures = true, precision = precision})
end

--- Finds position of npc by name and reaches its position.
-- @return void(acion) or boolean
function CaveBot.ReachNPC(name)
    name = name:lower()

    local npc = nil
    for i, spec in pairs(getSpectators()) do
        if spec:isNpc() and spec:getName():lower() == name then
            npc = spec
        end
    end

    if not CaveBot.MatchPosition(npc:getPosition(), 3) then
        CaveBot.GoTo(npc:getPosition())
    else
        return true
    end
end

-- ##################### --
-- [[[[ Depot class ]]]] --
-- ##################### --

--- Reaches closest locker.
-- @return void(acion) or boolean

local depositerLockerTarget = nil
local depositerLockerReachRetries = 0
function CaveBot.ReachDepot()
    local pPos = player:getPosition()
    local tiles = getNearTiles(player:getPosition())

    for i, tile in pairs(tiles) do
        for i, item in pairs(tile:getItems()) do
            if table.find(LOCKERS_LIST, item:getId()) then
                depositerLockerTarget = nil
                depositerLockerReachRetries = 0
                return true -- if near locker already then return function
            end
        end
    end

    if depositerLockerReachRetries > 20 then
        depositerLockerTarget = nil
        depositerLockerReachRetries = 0
    end

    local candidates = {}

    if not depositerLockerTarget or distanceFromPlayer(depositerLockerTarget, pPos) > 12 then
        for i, tile in pairs(g_map.getTiles(posz())) do
            local tPos = tile:getPosition()
            for i, item in pairs(tile:getItems()) do
                if table.find(LOCKERS_LIST, item:getId()) then
                    local lockerTilePos = tile:getPosition()
                          lockerTilePos.x = lockerTilePos.x + LOCKER_ACCESSTILE_MODIFIERS[item:getId()][1]
                          lockerTilePos.y = lockerTilePos.y + LOCKER_ACCESSTILE_MODIFIERS[item:getId()][2]
                    local lockerTile = g_map.getTile(lockerTilePos)
                    if not lockerTile:hasCreatures() then
                        if findPath(pos(), tPos, 20, {ignoreNonPathable = false, precision = 1, ignoreCreatures = true}) then
                            local distance = getDistanceBetween(tPos, pPos)
                            table.insert(candidates, {pos=tPos, dist=distance})
                        end
                    end
                end
            end
        end

        if #candidates > 1 then
            table.sort(candidates, function(a,b) return a.dist < b.dist end)
        end
    end

    depositerLockerTarget = depositerLockerTarget or candidates[1].pos

    if depositerLockerTarget then
        if not CaveBot.MatchPosition(depositerLockerTarget) then
            depositerLockerReachRetries = depositerLockerReachRetries + 1
            return CaveBot.GoTo(depositerLockerTarget, 1)
        else
            depositerLockerReachRetries = 0
            depositerLockerTarget = nil
            return true
        end
    end
end

--- Opens locker item.
-- @return void(acion) or boolean
function CaveBot.OpenLocker()
    local pPos = player:getPosition()
    local tiles = getNearTiles(player:getPosition())

    local locker = getContainerByName("Locker")
    if not locker then
        for i, tile in pairs(tiles) do
            for i, item in pairs(tile:getItems()) do
                if table.find(LOCKERS_LIST, item:getId()) then
                    local topThing = tile:getTopUseThing()
                    if not topThing:isNotMoveable() then
                        g_game.move(topThing, pPos, topThing:getCount())
                    else
                        return g_game.open(item)
                    end
                end
            end
        end
    else
        return true
    end
end

--- Opens depot chest.
-- @return void(acion) or boolean
function CaveBot.OpenDepotChest()
    local depot = getContainerByName("Depot chest")
    if not depot then
        local locker = getContainerByName("Locker")
        if not locker then
            return CaveBot.OpenLocker()
        end
        for i, item in pairs(locker:getItems()) do
            if item:getId() == 3502 then
                return g_game.open(item, locker)
            end
        end
    else
        return true
    end
end

--- Opens inbox inside locker.
-- @return void(acion) or boolean
function CaveBot.OpenInbox()
    local inbox = getContainerByName("Your inbox")
    if not inbox then
        local locker = getContainerByName("Locker")
        if not locker then
            return CaveBot.OpenLocker()
        end
        for i, item in pairs(locker:getItems()) do
            if item:getId() == 12902 then
                return g_game.open(item)
            end
        end
    else
        return true
    end
end

--- Opens depot box of given number.
-- @param index is integer
-- @return void or boolean
function CaveBot.OpenDepotBox(index)
    local depot = getContainerByName("Depot chest")
    if not depot then
        return CaveBot.ReachAndOpenDepot()
    end

    local foundParent = false
    for i, container in pairs(getContainers()) do
        if container:getName():lower():find("depot box") then
            foundParent = container
            break
        end
    end
    if foundParent then return true end

    for i, container in pairs(depot:getItems()) do
        if i == index then
            return g_game.open(container)
        end
    end
end

--- Reaches and opens depot.
-- Combined for shorthand usage.
-- @return boolean whether succeed to reach and open depot
function CaveBot.ReachAndOpenDepot()
    if CaveBot.ReachDepot() and CaveBot.OpenDepotChest() then
        return true
    end
    return false
end

--- Reaches and opens imbox.
-- Combined for shorthand usage.
-- @return boolean whether succeed to reach and open depot
function CaveBot.ReachAndOpenInbox()
    if CaveBot.ReachDepot() and CaveBot.OpenInbox() then
        return true
    end
    return false
end

--- Stripped down function to stash item.
-- @param item is object
-- @param index is integer
-- @param destination is object
-- @return void
function CaveBot.StashItem(item, index, destination)
    destination = destination or getContainerByName("Depot chest")
    if not destination then return false end

    return g_game.move(item, destination:getSlotPosition(index), item:getCount())
end

--- Withdraws item from depot chest or mail inbox.
-- main function for depositer/withdrawer
-- @param id is integer
-- @param amount is integer
-- @param fromDepot is boolean or integer
-- @param destination is object
-- @return void
function CaveBot.WithdrawItem(id, amount, fromDepot, destination)
    if destination and type(destination) == "string" then
        destination = getContainerByName(destination)
    end
    local itemCount = itemAmount(id)
    local depot
    for i, container in pairs(getContainers()) do
        if container:getName():lower():find("depot box") or container:getName():lower():find("your inbox") then
            depot = container
            break
        end
    end
    if not depot then
        if fromDepot then
            if not CaveBot.OpenDepotBox(fromDepot) then return end
        else
            return CaveBot.ReachAndOpenInbox()
        end
        return
    end
    if not destination then
        for i, container in pairs(getContainers()) do
            if container:getCapacity() > #container:getItems() and not string.find(container:getName():lower(), "quiver") and not string.find(container:getName():lower(), "depot") and not string.find(container:getName():lower(), "loot") and not string.find(container:getName():lower(), "inbox") then
                destination = container
            end
        end
    end

    if itemCount >= amount then
        return true
    end

    local toMove = amount - itemCount
    for i, item in pairs(depot:getItems()) do
        if item:getId() == id then
            return g_game.move(item, destination:getSlotPosition(destination:getItemsCount()), math.min(toMove, item:getCount()))
        end
    end
end

-- ##################### --
-- [[[[[ Talk class ]]]] --
-- ##################### --

--- Controlled by event caller.
-- Simple way to build npc conversations instead of multiline overcopied code.
-- @return void
function CaveBot.Conversation(...)
    local expressions = {...}
    local delay = storage.extras.talkDelay or 1000

    local talkDelay = 0
    for i, expr in ipairs(expressions) do
        schedule(talkDelay, function() NPC.say(expr) end)
        talkDelay = talkDelay + delay
    end
end

--- Says hi trade to NPC.
-- Used as shorthand to open NPC trade window.
-- @return void
function CaveBot.OpenNpcTrade()
    return CaveBot.Conversation("hi", "trade")
end

--- Says hi destination yes to NPC.
-- Used as shorthand to travel.
-- @param destination is string
-- @return void
function CaveBot.Travel(destination)
    return CaveBot.Conversation("hi", destination, "yes")
end
