local taskPointStorage = 5151 -- which player storage holds task points.

local configTasks = {
	[1] = { 
	nameOfTheTask = "Rat",  -- same as target name e.g. rat / Rat (doesnt matter, the name will be lowered later anyway)
	looktype = { type = 21 },
	killsRequired = 25,
	rewards = {
		expReward = 1500,
		pointsReward = 0, -- NOT the id, its the amount of points, if no point reward then delete this line/ dont write at all.
	}
	},
	[2] = { 
	nameOfTheTask = "Cave Rat",  -- same as target name e.g. rat / Rat (doesnt matter, the name will be lowered later anyway)
	looktype = { type = 56 },
	killsRequired = 25,
	rewards = {
		expReward = 2000,
		pointsReward = 50, -- NOT the id, its the amount of points, if no point reward then delete this line/ dont write at all.
	}
	},
	[3] = { 
	nameOfTheTask = "Snake", 
	looktype = { type = 28 },
	killsRequired = 25,
	rewards = {
		expReward = 2000,
		-- no functionality: itemRewards = {26447, 26408, 26430}
	}
	},
	[4] = { 
	nameOfTheTask = "Scorpion", 
	looktype = { type = 43 }, 
	killsRequired = 25,
	rewards = {
		expReward = 2000,
		-- no functionality: itemRewards = {26447, 26408, 26430}
	}
	},
	[5] = { 
	nameOfTheTask = "Amazon",
	looktype = { type = 137, feet = 115, addons = 0, legs = 95, auxType = 7399, head = 113, body = 120 },
	killsRequired = 150,
	rewards = {
		expReward = 5000,
		-- no functionality: itemRewards = {26447, 26408, 26430}
	}
	},
	[6] = { 
	nameOfTheTask = "Valkyrie",
	looktype = { type = 139, feet = 96, addons = 0, legs = 76, auxType = 7399, head = 113, body = 38 }, 
	killsRequired = 150,
	rewards = {
		expReward = 8000,
		-- no functionality: itemRewards = {26447, 26408, 26430}
	}
	},
}

TaskSystem = {
    list = {},
    baseStorage = 1500,
    maximumTasks = 100,
    countForParty = true,
    maxDist = 7,
    players = {},
    loadDatabase = function()
        if (#TaskSystem.list > 0) then
            return true
        end
		
		for i = 1, #configTasks do
            table.insert(TaskSystem.list, {
                id = i,
                name = '' ..configTasks[i].nameOfTheTask..'',
                looktype = configTasks[i].looktype,
                kills = configTasks[i].killsRequired,
                exp = configTasks[i].rewards.expReward,
				taskPoints = configTasks[i].rewards.pointsReward,
            })
        end
        return true
    end,
    getCurrentTasks = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            if (player:getStorageValue(TaskSystem.baseStorage + task.id) > 0) then
                local playerTask = task -- deepcopy(task)
                playerTask.left = player:getStorageValue(TaskSystem.baseStorage + task.id)
                playerTask.done = playerTask.kills - (playerTask.left - 1)
                table.insert(tasks, playerTask)
            end
        end

        return tasks
    end,
    getPlayerTaskIds = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            if (player:getStorageValue(TaskSystem.baseStorage + task.id) > 0) then
                table.insert(tasks, task.id)
            end
        end

        return tasks
    end,
    getTaskNames = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            table.insert(tasks, '{' .. task.name:lower() .. '}')
        end

        return table.concat(tasks, ', ')
    end,
    onAction = function(player, data)
        if (data['action'] == 'info') then
            TaskSystem.sendData(player)
            TaskSystem.players[player.uid] = 1
        elseif (data['action'] == 'hide') then
            TaskSystem.players[player.uid] = nil
        elseif (data['action'] == 'start') then
            local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

            if (#playerTaskIds >= TaskSystem.maximumTasks) then
                return player:sendExtendedJSONOpcode(215, {
                    message = "You can't take more tasks.",
                    color = 'red'
                })
            end

            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    if (table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(215, {
                            message = 'You already have this task active.',
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, task.kills + 1)
                    player:sendExtendedJSONOpcode(215, {
                        message = 'Task started.',
                        color = 'green'
                    })

                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedJSONOpcode(215, {
                message = 'Unknown task.',
                color = 'red'
            })
        elseif (data['action'] == 'cancel') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(215, {
                            message = "You don't have this task active.",
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:sendExtendedJSONOpcode(215, {
                        message = 'Task aborted.',
                        color = 'green'
                    })

                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedJSONOpcode(215, {
                message = 'Unknown task.',
                color = 'red'
            })
        elseif (data['action'] == 'finish') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(215, {
                            message = "You don't have this task active.",
                            color = 'red'
                        })
                    end

                    local left = player:getStorageValue(TaskSystem.baseStorage + task.id)

                    if (left > 1) then
                        return player:sendExtendedJSONOpcode(215, {
                            message = "Task isn't completed yet.",
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:addExperience(task.exp)
                    player:setStorageValue(taskPointStorage, (player:getStorageValue(taskPointStorage) + task.taskPoints))
                    player:sendExtendedJSONOpcode(215, {
                        message = 'Task finished.',
                        color = 'green'
                    })

                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedJSONOpcode(215, {
                message = 'Unknown task.',
                color = 'red'
            })
        end
    end,
    killForPlayer = function(player, task)
        local left = player:getStorageValue(TaskSystem.baseStorage + task.id)

        if (left == 1) then
            if (TaskSystem.players[player.uid]) then
                player:sendExtendedJSONOpcode(215, {
                    message = 'Task finished.',
                    color = 'green'
                })
            end

            return true
        end

        player:setStorageValue(TaskSystem.baseStorage + task.id, left - 1)

        if (TaskSystem.players[player.uid]) then
            return TaskSystem.sendData(player)
        end
    end,
    onKill = function(player, target)
        local targetName = target:getName():lower()

        for _, task in ipairs(TaskSystem.list) do
            if (task.name:lower() == targetName) then
                local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                if (not table.contains(playerTaskIds, task.id)) then
                    return true
                end

                local party = player:getParty()
                local tpos = target:getPosition()

                if (TaskSystem.countForParty and party and party:getMembers()) then
                    for i, creature in pairs(party:getMembers()) do
                        local pos = creature:getPosition()

                        if (pos.z == tpos.z and pos:getDistance(tpos) <= TaskSystem.maxDist) then
                            TaskSystem.killForPlayer(creature, task)
                        end
                    end

                    local pos = party:getLeader():getPosition()

                    if (pos.z == tpos.z and pos:getDistance(tpos) <= TaskSystem.maxDist) then
                        TaskSystem.killForPlayer(party:getLeader(), task)
                    end
                else
                    TaskSystem.killForPlayer(player, task)
                end

                return true
            end
        end
    end,
    sendData = function(player)
        local playerTasks = TaskSystem.getCurrentTasks(player)

        local response = {
            allTasks = TaskSystem.list,
            playerTasks = playerTasks
        }

        return player:sendExtendedJSONOpcode(215, response)
    end
}

local events = {}

local globalevent = GlobalEvent('Tasks')
TaskSystem.loadDatabase()

function globalevent.onStartup()
    return TaskSystem.loadDatabase()
end

table.insert(events, globalevent)

local creatureevent = CreatureEvent('TaskKill')

function creatureevent.onKill(creature, target)
    if (not creature:isPlayer() or not Monster(target)) then
        return true
    end

    TaskSystem.onKill(creature, target)

    return true
end

table.insert(events, creatureevent)

for _, event in ipairs(events) do
    event:register()
end
