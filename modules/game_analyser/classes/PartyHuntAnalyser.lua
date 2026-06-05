
-- Missing utility functions
local function formatMoney(value, separator)
    return comma_value(tostring(value))
end

-- Helper function to append colored text to a string
local function setStringColor(textString, text, color)
    return textString .. "[color=" .. color .. "]" .. text .. "[/color]"
end

-- Helper function to get table size
local function table_size(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

if not PartyHuntAnalyser then
	PartyHuntAnalyser = {
		launchTime = 0,
		session = 0,
		lootType = 0,
		leaderID = 0,

		--
		loot = 0,
		supplies = 0,
		balance = 0,

		membersData = {},
		membersName = {},

		-- private
		window = nil,
		event = nil,
		leader = false,
		
		-- Track when we're expecting a reset response
		expectingResetResponse = false,
		lastResetTime = 0,
		
		-- Track if we had party data recently (for detecting server resets)
		hadRecentPartyData = false,
		lastDataReceiveTime = 0
	}
	PartyHuntAnalyser.__index = PartyHuntAnalyser
end

function PartyHuntAnalyser.create()
	PartyHuntAnalyser.launchTime = g_clock.millis()
	PartyHuntAnalyser.session = os.time()

	PartyHuntAnalyser.lootType = PriceTypeEnum.Leader
	PartyHuntAnalyser.leaderID = 0
	PartyHuntAnalyser.leader = false

	--
	PartyHuntAnalyser.loot = 0
	PartyHuntAnalyser.supplies = 0
	PartyHuntAnalyser.balance = 0
	PartyHuntAnalyser.event = nil

	PartyHuntAnalyser.membersData = {}
	PartyHuntAnalyser.membersName = {}
	PartyHuntAnalyser.window = openedWindows['partyButton']
	
	if not PartyHuntAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = PartyHuntAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = PartyHuntAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = PartyHuntAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = PartyHuntAnalyser.window:recursiveGetChildById('minimizeButton')
	
	if contextMenuButton and minimizeButton then
		contextMenuButton:setVisible(true)
		contextMenuButton:breakAnchors()
		contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
		contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
		contextMenuButton:setMarginRight(7)  -- Same margin as toggleFilterButton had
		contextMenuButton:setMarginTop(0)
		
		-- Set up contextMenuButton click handler to show our menu
		contextMenuButton.onClick = function(widget, mousePos)
			local pos = mousePos or g_window.getMousePosition()
			return onPartyHuntExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = PartyHuntAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end
end

function PartyHuntAnalyser:startEvent()
	PartyHuntAnalyser.session = os.time()
	if PartyHuntAnalyser.event then PartyHuntAnalyser.event:cancel() end
end

function PartyHuntAnalyser:reset()
	PartyHuntAnalyser.launchTime = g_clock.millis()
	PartyHuntAnalyser.session = os.time()

	PartyHuntAnalyser.lootType = PriceTypeEnum.Market
	PartyHuntAnalyser.leaderID = 0
	PartyHuntAnalyser.leader = false

	--
	PartyHuntAnalyser.loot = 0
	PartyHuntAnalyser.supplies = 0
	PartyHuntAnalyser.balance = 0

	PartyHuntAnalyser.membersData = {}
	PartyHuntAnalyser.membersName = {}

	-- Clear reset expectation flags
	PartyHuntAnalyser.expectingResetResponse = false
	PartyHuntAnalyser.lastResetTime = 0
	
	-- Clear data tracking flags
	PartyHuntAnalyser.hadRecentPartyData = false
	PartyHuntAnalyser.lastDataReceiveTime = 0

	if PartyHuntAnalyser.event then PartyHuntAnalyser.event:cancel() end

	local contentsPanel = PartyHuntAnalyser.window:getChildById('contentsPanel')
	contentsPanel.party:destroyChildren()
	PartyHuntAnalyser:updateWindow(true, true)
end

function PartyHuntAnalyser:updateWindow(updateMembers, ignoreVisible)
	if not PartyHuntAnalyser.window:isVisible() and not ignoreVisible then
		return
	end
	local contentsPanel = PartyHuntAnalyser.window.contentsPanel

    contentsPanel.lootType:setText(PartyHuntAnalyser.lootType == PriceTypeEnum.Market and "Market" or "Leader")

	local session = PartyHuntAnalyser.session
	if session == 0 then
		contentsPanel.session:setText("00:00h")
	else
		local duration = math.max(1, os.time() - session)
		local hours = math.floor(duration / 3600)
		local minutes = math.floor((duration % 3600) / 60)
		contentsPanel.session:setText(string.format("%02d:%02dh", hours, minutes))
	end

	if not updateMembers then
		return
	end

	local lootTotal = 0
	local supplyTotal = 0

	local c = 0
	for id, data in pairs(PartyHuntAnalyser.membersData) do
		local widget = contentsPanel.party:getChildById(id)
		
		-- Check if this member is the leader - either by stored leaderID or by current shield color
		local isLeader = (id == PartyHuntAnalyser.leaderID)
		
		-- Also check if this player is visible and has a leader shield (for real-time detection)
		if not isLeader then
			local localPlayer = g_game.getLocalPlayer()
			if localPlayer then
				local spectators = g_map.getSpectators(localPlayer:getPosition(), false)
				for _, creature in ipairs(spectators) do
					if creature:isPlayer() and creature:getId() == id then
						local shield = creature:getShield()
						local hasLeaderShield = (shield == ShieldYellow or shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExpBlink)
						if hasLeaderShield then
							isLeader = true
							-- Update stored leaderID for consistency
							PartyHuntAnalyser.leaderID = id
						end
						break
					end
				end
				
				-- Also check if the local player is the leader
				if id == localPlayer:getId() then
					local localShield = localPlayer:getShield()
					local localHasLeaderShield = (localShield == ShieldYellow or localShield == ShieldYellowSharedExp or localShield == ShieldYellowNoSharedExpBlink)
					if localHasLeaderShield then
						isLeader = true
						PartyHuntAnalyser.leaderID = id
					end
				end
			end
		end
		
		-- Check if widget exists and is the correct type
		if not widget then
			-- Create new widget
			if isLeader then
				widget = g_ui.createWidget('LeaderInfo', contentsPanel.party)
			else
				widget = g_ui.createWidget('Info', contentsPanel.party)
			end
		else
			-- Widget exists - check if we need to change the type
			local widgetType = widget:getStyleName()
			local expectedType = isLeader and 'LeaderInfo' or 'Info'
			
			if widgetType ~= expectedType then
				-- Wrong widget type - destroy and recreate
				widget:destroy()
				if isLeader then
					widget = g_ui.createWidget('LeaderInfo', contentsPanel.party)
				else
					widget = g_ui.createWidget('Info', contentsPanel.party)
				end
			end
		end

		c = c + 1

		lootTotal = lootTotal + data[3]
		supplyTotal = supplyTotal + data[4]
		local playerBalance = data[3] - data[4]  -- loot - supplies
		local playerName = PartyHuntAnalyser.membersName[id] or "Unknown"
		widget.name:setText(playerName)
		if not data[5] then
			widget.name:setColor("#707070")
		end
		widget.balance:setText(comma_value(playerBalance))
		widget.balance:setColor(playerBalance >= 0 and "#44ad25" or "#ff9854")
		widget.damage:setText(comma_value(data[5]))
		widget.healing:setText(comma_value(data[6]))
		widget:setId(id)

		local tooltipMessage = ""
		tooltipMessage = setStringColor(tooltipMessage, tr("Loot: %s ", comma_value(data[3])), "#3f3f3f")
		tooltipMessage = setStringColor(tooltipMessage, "$\n", "yellow")
		tooltipMessage = setStringColor(tooltipMessage, tr("Supplies: %s ", comma_value(data[4])), "#3f3f3f")
		tooltipMessage = setStringColor(tooltipMessage, "$\n", "yellow")
		tooltipMessage = setStringColor(tooltipMessage, tr("Balance: %s ", comma_value(playerBalance)), "#3f3f3f")
		tooltipMessage = setStringColor(tooltipMessage, "$", "yellow")
		widget.balance.parseColoreDisplay = tooltipMessage
	end

	contentsPanel.party:setHeight(40 + (c * 61))

	local balance = lootTotal - supplyTotal

	PartyHuntAnalyser.loot = lootTotal
	PartyHuntAnalyser.supplies = supplyTotal
	PartyHuntAnalyser.balance = balance

	contentsPanel.loot:setText(formatMoney(lootTotal, ","))
	contentsPanel.supplies:setText(formatMoney(supplyTotal, ","))
	contentsPanel.balance:setText(comma_value(balance))
	contentsPanel.balance:setColor(balance >= 0 and '#00EB00' or '#f36500')

end

function PartyHuntAnalyser:onPartyAnalyzer(startTime, leaderID, lootType, membersData, membersName)

	-- Check if this looks like a reset response (all important data is zeros)
	local isResetData = false
	if membersData and next(membersData) then
		isResetData = true
		for id, data in pairs(membersData) do
			-- Check if all the important values are zero (loot[3], supplies[4], damage[5], healing[6])
			if data[3] ~= 0 or data[4] ~= 0 or data[5] ~= 0 or data[6] ~= 0 then
				isResetData = false
				break
			end
		end
		if isResetData then
			-- When server sends reset data, reset our local session but keep member tracking
			PartyHuntAnalyser.session = os.time() - startTime
			-- Don't reset membersData and membersName here - let the server data override them below
		end
	end
	
	-- Don't immediately reset on empty data - server might be sending incomplete data during party changes
	-- EXCEPT when we're expecting a reset response OR when we detect server-initiated reset
	if not membersData or not next(membersData) or not membersName or #membersName == 0 then
		local localPlayer = g_game.getLocalPlayer()
		if localPlayer then
			local localShield = localPlayer:getShield()
			local localIsInParty = (localShield == ShieldYellow or localShield == ShieldYellowSharedExp or 
			                       localShield == ShieldYellowNoSharedExpBlink or localShield == ShieldYellowNoSharedExp or 
			                       localShield == ShieldBlue or localShield == ShieldBlueSharedExp or 
			                       localShield == ShieldBlueNoSharedExpBlink or localShield == ShieldBlueNoSharedExp)
			
			-- Check if we're expecting a reset response (within 5 seconds of sending reset command)
			local timeSinceReset = g_clock.millis() - PartyHuntAnalyser.lastResetTime
			local isLocalResetResponse = PartyHuntAnalyser.expectingResetResponse and (timeSinceReset < 5000)
			
			-- Also check if we previously had party data but now getting empty data while still in party
			-- This indicates a server-initiated reset (leader clicked reset)
			local timeSinceLastData = g_clock.millis() - PartyHuntAnalyser.lastDataReceiveTime
			local hadRecentData = PartyHuntAnalyser.hadRecentPartyData and (timeSinceLastData < 10000) -- within 10 seconds
			local isServerReset = localIsInParty and hadRecentData
			
			if isLocalResetResponse then
				PartyHuntAnalyser.expectingResetResponse = false
				PartyHuntAnalyser:reset()
				return
			elseif isServerReset then
				PartyHuntAnalyser:reset()
				return
			elseif not localIsInParty then
				PartyHuntAnalyser:reset()
				return
			else
				return  -- Ignore empty data when player is still in party
			end
		else
			-- No local player - can't verify, so reset to be safe
			PartyHuntAnalyser:reset()
			return
		end
	end
	
	-- startTime appears to be the session duration in seconds, not actual start time
	-- So we calculate the actual session start time
	PartyHuntAnalyser.session = os.time() - startTime
	PartyHuntAnalyser.leaderID = leaderID
	PartyHuntAnalyser.lootType = lootType
	
	-- Clear the reset expectation flag since we received valid data
	PartyHuntAnalyser.expectingResetResponse = false
	
	-- Track that we received party data (for detecting future server resets)
	PartyHuntAnalyser.hadRecentPartyData = true
	PartyHuntAnalyser.lastDataReceiveTime = g_clock.millis()
	
	-- If membersData keys are player IDs, use them directly
	-- If they are positions (1,2,3...), we need to map them to the actual player IDs
	-- Server data is authoritative, so we can safely replace our data with server data
	local newMembersData = membersData
	
	-- Convert membersName from array format to lookup table format
	local newMembersName = {}
	if membersName then
		for i, memberInfo in ipairs(membersName) do
			if type(memberInfo) == "table" then
				local memberId = memberInfo.memberID  -- Use struct field
				local memberName = memberInfo.memberName  -- Use struct field
				newMembersName[memberId] = memberName
			end
		end
	end
	
	-- If membersData uses position keys (1,2,3...) but membersName uses player IDs,
	-- we need to remap the membersData to use player IDs as keys
	if membersName and type(newMembersData) == "table" then
		local remappedData = {}
		local memberIndex = 1
		
		-- Try to match positions in membersData with IDs from membersName
		for i, memberInfo in ipairs(membersName) do
			if type(memberInfo) == "table" then
				local playerId = memberInfo.memberID  -- Use struct field
				local memberData = newMembersData[memberIndex]
				if memberData then
					remappedData[playerId] = memberData
					memberIndex = memberIndex + 1
				end
			end
		end
		
		-- Only use remapped data if we successfully mapped something
		if next(remappedData) then
			newMembersData = remappedData
		end
	end
	
	-- Server data is authoritative - replace our data with server data
	-- This ensures that if a player left the party, they are removed from our tracking
	local serverMemberIds = {}
	for playerId, serverData in pairs(newMembersData) do
		serverMemberIds[playerId] = true
		
		-- Convert struct format to expected array format if needed
		local convertedData = serverData
		if type(serverData) == "table" and serverData.memberID then
			-- This is a PartyMemberData struct, convert to array format
			convertedData = {
				serverData.memberID,    -- [1] = memberID
				serverData.highlight,   -- [2] = highlight
				serverData.loot,        -- [3] = loot
				serverData.supply,      -- [4] = supply (supplies)
				serverData.damage,      -- [5] = damage
				serverData.healing      -- [6] = healing
			}
		end
		
		PartyHuntAnalyser.membersData[playerId] = convertedData
		if newMembersName[playerId] then
			PartyHuntAnalyser.membersName[playerId] = newMembersName[playerId]
		end
	end
	
	-- Remove any members we have locally but server doesn't (they left the party)
	local membersToRemove = {}
	for playerId, existingData in pairs(PartyHuntAnalyser.membersData) do
		if not serverMemberIds[playerId] then
			table.insert(membersToRemove, playerId)
		end
	end
	
	-- Remove members that are no longer in the party according to server
	for _, playerId in ipairs(membersToRemove) do
		local playerName = PartyHuntAnalyser.membersName[playerId] or "Unknown"
		
		PartyHuntAnalyser.membersData[playerId] = nil
		PartyHuntAnalyser.membersName[playerId] = nil
		
		-- Remove widget from UI
		local contentsPanel = PartyHuntAnalyser.window.contentsPanel
		if contentsPanel and contentsPanel.party then
			local widget = contentsPanel.party:getChildById(playerId)
			if widget then
				widget:destroy()
			end
		end
	end

	if PartyHuntAnalyser.event then PartyHuntAnalyser.event:cancel() end
	PartyHuntAnalyser.event = cycleEvent(function()
		if not g_game.isOnline() then return end
		-- Update the window to show current time
		PartyHuntAnalyser:updateWindow(false)
	end, 1000)

	PartyHuntAnalyser:updateWindow(true)
	PartyHuntAnalyser.leader = g_game.getLocalPlayer():getId() == leaderID
end

function getLeaderLootType()
	return PartyHuntAnalyser.lootType
end

function isLeaderParty()
	local player = g_game.getLocalPlayer()
	return table.contains({ShieldYellow, ShieldYellowSharedExp, ShieldYellowNoSharedExpBlink}, player:getShield())
end

function onPartyHuntExtra(mousePosition)
	if cancelNextRelease then
		cancelNextRelease = false
		return false
	end

	local player = g_game.getLocalPlayer()
	if not player then return false end

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)

	local playerShield = player:getShield()
	local isLeaderShield = table.contains({ShieldYellow, ShieldYellowSharedExp, ShieldYellowNoSharedExpBlink}, playerShield)

	if isLeaderShield then
		local lootType = PartyHuntAnalyser.lootType == PriceTypeEnum.Market and "Leader" or "Market"
		menu:addOption(tr('Reset Data of Current Party Session'), function() 
			PartyHuntAnalyser.expectingResetResponse = true
			PartyHuntAnalyser.lastResetTime = g_clock.millis()
			g_game.sendPartyAnalyzerReset() 
		return end)
		menu:addOption(tr('Use %s Prices', lootType), function()
			g_game.sendPartyAnalyzerPriceType()
		return end)
		menu:addSeparator()
	end

	menu:addOption(tr('Copy to Clipboard'), function() PartyHuntAnalyser:clipboardData() return end)
	
	-- Only add loot splitter option if the module is available
	if modules.game_lootsplitter then
		menu:addOption(tr('Copy to LootSplitter'), function() PartyHuntAnalyser:lootSplitter() return end)
	end

	menu:display(mousePosition)
  return true
end

function PartyHuntAnalyser:clipboardData()

	local session = PartyHuntAnalyser.session
	local final = ""
	if session == 0 then
		final = "Session: 00:00h"
	else
		local duration = math.max(1, os.time() - session)
		local hours = math.floor(duration / 3600)
		local minutes = math.floor((duration % 3600) / 60)
		
		final = "Session data: From " .. os.date('%Y-%m-%d, %H:%M:%S', session) .." to ".. os.date('%Y-%m-%d, %H:%M:%S') .. "\n"
		final = final .. "Session: " .. string.format("%02d:%02dh", hours, minutes)
	end
	final = final .. "\nLoot Type: " .. (PartyHuntAnalyser.lootType ~= PriceTypeEnum.Market and "Leader" or "Market")
	final = final .. "\nLoot: " .. comma_value(PartyHuntAnalyser.loot)
	final = final .. "\nSupplies: " .. comma_value(PartyHuntAnalyser.supplies)
	final = final .. "\nBalance: " .. comma_value(PartyHuntAnalyser.balance)

	--user data now
	for id, data in pairs(PartyHuntAnalyser.membersData) do
		local playerName = PartyHuntAnalyser.membersName[id] or "Unknown"
		final = final.. "\n".. playerName .. (id == PartyHuntAnalyser.leaderID and ' (Leader)' or '')
		final = final.. "\n\tLoot: ".. comma_value(data[3])
		final = final.. "\n\tSupplies: "..comma_value(data[4])
		final = final.. "\n\tBalance: "..comma_value(data[3] - data[4])
		final = final.. "\n\tDamage: "..comma_value(data[5])
		final = final.. "\n\tHealing: "..comma_value(data[6])
	end

	g_window.setClipboardText(final)
end

function PartyHuntAnalyser:lootSplitter()

	local session = PartyHuntAnalyser.session
	local final = ""
	if session == 0 then
		final = "Session: 00:00h"
	else
		local duration = math.max(1, os.time() - session)
		local hours = math.floor(duration / 3600)
		local minutes = math.floor((duration % 3600) / 60)
		
		final = "Session data: From " .. os.date('%Y-%m-%d, %H:%M:%S', session) .." to ".. os.date('%Y-%m-%d, %H:%M:%S') .. "\n"
		final = final .. "Session: " .. string.format("%02d:%02dh", hours, minutes)
	end
	final = final .. "\nLoot Type: " .. (PartyHuntAnalyser.lootType ~= PriceTypeEnum.Market and "Leader" or "Market")
	final = final .. "\nLoot: " .. comma_value(PartyHuntAnalyser.loot)
	final = final .. "\nSupplies: " .. comma_value(PartyHuntAnalyser.supplies)
	final = final .. "\nBalance: " .. comma_value(PartyHuntAnalyser.balance)

	--user data now
	for id, data in pairs(PartyHuntAnalyser.membersData) do
		local playerName = PartyHuntAnalyser.membersName[id] or "Unknown"
		final = final.. "\n".. playerName .. (id == PartyHuntAnalyser.leaderID and ' (Leader)' or '')
		final = final.. "\n\tLoot: ".. comma_value(data[3])
		final = final.. "\n\tSupplies: "..comma_value(data[4])
		final = final.. "\n\tBalance: "..comma_value(data[3] - data[4])
		final = final.. "\n\tDamage: "..comma_value(data[5])
		final = final.. "\n\tHealing: "..comma_value(data[6])
	end

	-- Check if game_lootsplitter module is available
	if modules.game_lootsplitter and modules.game_lootsplitter.lootsplitter then
		local huntLogContent = modules.game_lootsplitter.lootsplitter.contentPanel:getChildById('huntLogContent')
		if huntLogContent then
			huntLogContent:setText(final)
			modules.game_lootsplitter.onGenerateButtonClick()
			modules.game_lootsplitter.show(true)
		end
	end
end

-- Party State Manager - Single source of truth for party tracking
local PartyState = {
    updateScheduled = false,
    lastUpdateTime = 0,
    updateDebounceMs = 500  -- Only update every 500ms max
}

function PartyState:scheduleUpdate()
    if self.updateScheduled then
        return  -- Update already scheduled
    end
    
    local now = g_clock.millis()
    if now - self.lastUpdateTime < self.updateDebounceMs then
        -- Too soon, schedule for later
        self.updateScheduled = true
        scheduleEvent(function()
            self:performUpdate()
        end, self.updateDebounceMs - (now - self.lastUpdateTime))
    else
        -- Update immediately
        self:performUpdate()
    end
end

function PartyState:performUpdate()
    self.updateScheduled = false
    self.lastUpdateTime = g_clock.millis()
    
    local localPlayer = g_game.getLocalPlayer()
    if not localPlayer then return end
    
    local localShield = localPlayer:getShield()
    local localId = localPlayer:getId()
    
    -- Check if local player is in a party
    local localIsInParty = (localShield == ShieldYellow or localShield == ShieldYellowSharedExp or 
                           localShield == ShieldYellowNoSharedExpBlink or localShield == ShieldYellowNoSharedExp or 
                           localShield == ShieldBlue or localShield == ShieldBlueSharedExp or 
                           localShield == ShieldBlueNoSharedExpBlink or localShield == ShieldBlueNoSharedExp)
    
    local localIsLeader = (localShield == ShieldYellow or localShield == ShieldYellowSharedExp or localShield == ShieldYellowNoSharedExpBlink)
    
    -- If LOCAL player left party, reset everything (only for the local player)
    if not localIsInParty and (PartyHuntAnalyser.leader or next(PartyHuntAnalyser.membersData)) then
        PartyHuntAnalyser:reset()
        return
    end
    
    -- If local player is in party, ensure they're tracked
    if localIsInParty then
        -- Set leader status
        PartyHuntAnalyser.leader = localIsLeader
        if localIsLeader then
            PartyHuntAnalyser.leaderID = localId
        end
        
        -- Ensure local player is in tracking
        if not PartyHuntAnalyser.membersData[localId] then
            PartyHuntAnalyser.membersData[localId] = {0, 1, 0, 0, 0, 0}
            PartyHuntAnalyser.membersName[localId] = localPlayer:getName()
        end
        
        -- Get current visible party members
        local spectators = g_map.getSpectators(localPlayer:getPosition(), false)
        local visiblePartyMembers = {}
        local newMembersFound = false
        
        -- Add local player to visible list
        visiblePartyMembers[localId] = localPlayer
        
        -- Check for visible party members and detect leader by shield
        for _, creature in ipairs(spectators) do
            if creature:isPlayer() and creature ~= localPlayer then
                local shield = creature:getShield()
                local isPartyMember = (shield == ShieldYellow or shield == ShieldYellowSharedExp or 
                                     shield == ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or 
                                     shield == ShieldBlue or shield == ShieldBlueSharedExp or 
                                     shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp)
                
                if isPartyMember then
                    local memberId = creature:getId()
                    visiblePartyMembers[memberId] = creature
                    
                    -- Check if this visible member is the party leader (yellow shields)
                    local memberIsLeader = (shield == ShieldYellow or shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExpBlink)
                    if memberIsLeader then
                        PartyHuntAnalyser.leaderID = memberId
                    end
                    
                    if not PartyHuntAnalyser.membersData[memberId] then
                        PartyHuntAnalyser.membersData[memberId] = {0, 1, 0, 0, 0, 0}
                        PartyHuntAnalyser.membersName[memberId] = creature:getName()
                        newMembersFound = true
                    else
                        -- Update name in case it changed
                        PartyHuntAnalyser.membersName[memberId] = creature:getName()
                    end
                end
            end
        end
        
        -- Check if any tracked members are no longer visible AND no longer have party shields
        -- This handles the case where someone left the party while visible
        local membersToRemove = {}
        for memberId, memberData in pairs(PartyHuntAnalyser.membersData) do
            if not visiblePartyMembers[memberId] then
                -- Member is not visible - check if they're still in party by checking spectators
                local memberStillInParty = false
                for _, creature in ipairs(spectators) do
                    if creature:isPlayer() and creature:getId() == memberId then
                        local shield = creature:getShield()
                        local isPartyMember = (shield == ShieldYellow or shield == ShieldYellowSharedExp or 
                                             shield == ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or 
                                             shield == ShieldBlue or shield == ShieldBlueSharedExp or 
                                             shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp)
                        if isPartyMember then
                            memberStillInParty = true
                            break
                        end
                    end
                end
                
                -- If member is visible but no longer has party shield, they left the party
                if not memberStillInParty then
                    -- Check if this member is visible with non-party shield (meaning they left)
                    for _, creature in ipairs(spectators) do
                        if creature:isPlayer() and creature:getId() == memberId then
                            local shield = creature:getShield()
                            local isPartyMember = (shield == ShieldYellow or shield == ShieldYellowSharedExp or 
                                                 shield == ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or 
                                                 shield == ShieldBlue or shield == ShieldBlueSharedExp or 
                                                 shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp)
                            if not isPartyMember and shield ~= ShieldNone then
                                -- Player is visible but not in party anymore - they left
                                table.insert(membersToRemove, memberId)
                                break
                            end
                        end
                    end
                end
            end
        end
        
        -- Remove members who left the party
        for _, memberId in ipairs(membersToRemove) do
            local memberName = PartyHuntAnalyser.membersName[memberId] or "Unknown"
            PartyHuntAnalyser.membersData[memberId] = nil
            PartyHuntAnalyser.membersName[memberId] = nil
            
            -- Remove widget from UI
            local contentsPanel = PartyHuntAnalyser.window.contentsPanel
            if contentsPanel and contentsPanel.party then
                local widget = contentsPanel.party:getChildById(memberId)
                if widget then
                    widget:destroy()
                end
            end
        end
        
        -- Update UI if changes were made
        if newMembersFound or #membersToRemove > 0 then
            PartyHuntAnalyser:updateWindow(true)
        end
    end
end

function onShieldChange(creature, shieldId)
    -- Only react to local player shield changes for party start/end
    if creature == g_game.getLocalPlayer() then
        local wasLeader = PartyHuntAnalyser.leader
        local hasPartyData = next(PartyHuntAnalyser.membersData) ~= nil
        
        local isNowInParty = (shieldId == ShieldYellow or shieldId == ShieldYellowSharedExp or 
                             shieldId == ShieldYellowNoSharedExpBlink or shieldId == ShieldYellowNoSharedExp or 
                             shieldId == ShieldBlue or shieldId == ShieldBlueSharedExp or 
                             shieldId == ShieldBlueNoSharedExpBlink or shieldId == ShieldBlueNoSharedExp)
        
        local isNowLeader = (shieldId == ShieldYellow or shieldId == ShieldYellowSharedExp or shieldId == ShieldYellowNoSharedExpBlink)
        
        -- Only update if there's a significant state change
        if (not hasPartyData and isNowInParty) or (hasPartyData and not isNowInParty) or (wasLeader ~= isNowLeader) then
            PartyState:scheduleUpdate()
        end
    end
    
    -- For other players, detect both joining AND leaving the party
    if creature:isPlayer() and creature ~= g_game.getLocalPlayer() then
        local oldShield = creature.lastKnownShield or ShieldNone
        creature.lastKnownShield = shieldId
        
        local wasPartyMember = (oldShield == ShieldYellow or oldShield == ShieldYellowSharedExp or 
                               oldShield == ShieldYellowNoSharedExpBlink or oldShield == ShieldYellowNoSharedExp or 
                               oldShield == ShieldBlue or oldShield == ShieldBlueSharedExp or 
                               oldShield == ShieldBlueNoSharedExpBlink or oldShield == ShieldBlueNoSharedExp)
        
        local isPartyMember = (shieldId == ShieldYellow or shieldId == ShieldYellowSharedExp or 
                              shieldId == ShieldYellowNoSharedExpBlink or shieldId == ShieldYellowNoSharedExp or 
                              shieldId == ShieldBlue or shieldId == ShieldBlueSharedExp or 
                              shieldId == ShieldBlueNoSharedExpBlink or shieldId == ShieldBlueNoSharedExp)
        
        -- Schedule update if someone joined OR left the party
        if wasPartyMember ~= isPartyMember then
            PartyState:scheduleUpdate()
        end
    end
end

function onPartyMembersChange(self, members)
	-- Simply delegate to the state manager for consistency
	PartyState:scheduleUpdate()
end
