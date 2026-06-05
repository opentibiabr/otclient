CaveBot.Extensions.StandLure = {}
local enable = nil

local function modPos(dir)
    local y = 0
    local x = 0

    if dir == 0 then
        y = -1
    elseif dir == 1 then
        x = 1
    elseif dir == 2 then
        y = 1
    elseif dir == 3 then
        x = -1
    elseif dir == 4 then
        y = -1
        x = 1
    elseif dir == 5 then
        y = 1
        x = 1
    elseif dir == 6 then
        y = 1
        x = -1
    elseif dir == 7 then
        y = -1
        x = -1
    end

    return {x, y}
end
local function reset(delay)
    if type(Supplies.hasEnough()) == 'table' then
        return
    end
    delay = delay or 0
    CaveBot.delay(delay)
    if delay == nil then
        enable = nil
    end
end

local resetRetries = false
CaveBot.Extensions.StandLure.setup = function()
    CaveBot.registerAction(
        "rushlure",
        "#FF0090",
        function(value, retries)
            local nextPos = nil
            local data = string.split(value, ",")
            if not data[1] then
                warn("Invalid cavebot lure action value. It should be position (x,y,z), delay(ms) is: " .. value)
                return false
            end

            if type(Supplies.hasEnough()) == 'table' then -- do not execute if no supplies
                return false
            end

            local pos = {x = tonumber(data[1]), y = tonumber(data[2]), z = tonumber(data[3])}

            local delayTime = data[4] and tonumber(data[4]) or 1000
            if not data[5] then
                enable = nil
            elseif data[5] == "yes" then
                enable = true
            else
                enable = false
            end

            delay(100)

            if retries > 50 and not resetRetries then
                reset()
                warn("[Rush Lure] Too many tries, can't reach position")
                return false  -- can't stand on tile
            end

            if resetRetries then
                resetRetries = false
            end

            if distanceFromPlayer(pos) > 30 then
                reset()
                return false -- not reachable
            end

            local playerPos = player:getPosition()
            local pathWithoutMonsters = findPath(playerPos, pos, 30, { ignoreFields = true, ignoreNonPathable = true, ignoreCreatures = true, precision = 0})
            local pathWithMonsters = findPath(playerPos, pos, maxDist, { ignoreFields = true, ignoreNonPathable = true, ignoreCreatures = false, precision = 0 })

            if not pathWithoutMonsters then
                reset()
                warn("[Rush Lure] No possible path to reach position, skipping.")
                return false -- spot is unreachable
            elseif pathWithoutMonsters and not pathWithMonsters then
              local foundMonster = false
              for i, dir in ipairs(pathWithoutMonsters) do
                local dirs = modPos(dir)
                nextPos = nextPos or playerPos
                nextPos.x = nextPos.x + dirs[1]
                nextPos.y = nextPos.y + dirs[2]


                local tile = g_map.getTile(nextPos)
                if tile then
                    if tile:hasCreatures() then
                        local creature = tile:getCreatures()[1]
                        local hppc = creature:getHealthPercent()
                        if creature:isMonster() and (hppc and hppc > 0) and (oldTibia or creature:getType() < 3) then
                            -- real blocking creature can not meet those conditions - ie. it could be player, so just in case check if the next creature is reachable
                            local path = findPath(playerPos, creature:getPosition(), 7, { ignoreNonPathable = true, precision = 1 })
                            if path then
                                creature:setMarked('#00FF00')
                                if g_game.getAttackingCreature() ~= creature then
                                  attack(creature)
                                end
                                g_game.setChaseMode(1)
                                resetRetries = true -- reset retries, we are trying to unclog the cavebot
                                delay(100)
                                return "retry"
                            end
                        end
                    end
                end
              end

              if not g_game.getAttackingCreature() then
                reset()
                warn("[Rush Lure] No path, no blocking monster, skipping.")
                return false -- no other way
              end
            end

            -- reaching position, delay targetbot in process
            if not CaveBot.MatchPosition(pos, 0) then
                TargetBot.delay(300)
                CaveBot.walkTo(pos, 30, { ignoreCreatures = false, ignoreFields = true, ignoreNonPathable = true, precision = 0})
                delay(100)
                resetRetries = true
                return "retry"
            end

            TargetBot.setOn()
            reset(delayTime)
            return true
        end
    )

    CaveBot.Editor.registerAction(
        "rushlure",
        "rush lure",
        {
            value = function()
                return posx() .. "," .. posy() .. "," .. posz() .. ",1000"
            end,
            title = "Stand Lure",
            description = "Run to position(x,y,z), delay(ms), targetbot on/off (yes/no)",
            multiline = false,
            validation = [[\d{1,5},\d{1,5},\d{1,2},\d{1,5}(?:,(yes|no)$|$)]]
        }
    )
end

local next = false
schedule(5, function() -- delay because cavebot.lua is loaded after this file
    modules.game_bot.connect(CaveBotList(), {
        onChildFocusChange = function(widget, newChild, oldChild)

        if oldChild and oldChild.action == "rushlure" then
            next = true
            return
        end

        if next then
            if enable then
                TargetBot.setOn()
            elseif enable == false then
                TargetBot.setOff()
            end

            enable = nil -- reset
            next = false
        end
    end})
end)
