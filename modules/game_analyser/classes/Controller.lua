if not ControllerAnalyser then
    ControllerAnalyser = {
        name = "ControllerAnalyser",
        class = "ControllerAnalyser",
        window = nil,
        session = nil,
        event250 = nil,
        event1000 = nil,
        event2000 = nil,
        eventGraph = nil,
        data = {}
    }
    ControllerAnalyser.__index = ControllerAnalyser
end


function ControllerAnalyser:startEvent()
	if HuntingAnalyser then
		HuntingAnalyser.session = os.time()
	end
    if LootAnalyser then
		LootAnalyser.session = os.time()
	end
    if SupplyAnalyser then
		SupplyAnalyser.session = os.time()
	end
    if ImpactAnalyser then
		ImpactAnalyser.session = os.time()
	end
    if InputAnalyser then
		InputAnalyser.session = os.time()
	end
    if XPAnalyser then
		XPAnalyser.session = os.time()
	end
    if DropTrackerAnalyser then
		DropTrackerAnalyser.session = os.time()
	end
    if PartyHuntAnalyser then
		PartyHuntAnalyser.session = os.time()
	end

	if ControllerAnalyser.eventGraph then ControllerAnalyser.eventGraph:cancel() end
	if ControllerAnalyser.event250 then ControllerAnalyser.event250:cancel() end
	if ControllerAnalyser.event1000 then ControllerAnalyser.event1000:cancel() end
	if ControllerAnalyser.event2000 then ControllerAnalyser.event2000:cancel() end

    ControllerAnalyser.event250 = cycleEvent(function()
        if g_game.isOnline() then
            if BossCooldown then
				BossCooldown:checkTicks()
			end
        end
	end, 250)

    ControllerAnalyser.event1000 = cycleEvent(function()
        if g_game.isOnline() then
            if HuntingAnalyser then
                HuntingAnalyser:updateWindow()
            end
            if LootAnalyser then
                LootAnalyser:checkBalance()
                LootAnalyser:checkLootHour()
            end
            if ImpactAnalyser then
                ImpactAnalyser:updateWindow()
            end
            if InputAnalyser then
                InputAnalyser:checkDPS()
            end
            if XPAnalyser then
                XPAnalyser:checkExpHour()
            end
            if DropTrackerAnalyser then
                DropTrackerAnalyser:checkTracker()
            end
            if SupplyAnalyser then
                SupplyAnalyser:checkSupplyHour()
            end
        end
	end, 1000)
	ControllerAnalyser.event2000 = cycleEvent(function()
        if g_game.isOnline() then
            if InputAnalyser then
                InputAnalyser:updateWindow()
            end
            if SupplyAnalyser then
                SupplyAnalyser:checkBalance()
            end
        end
	end, 2000)
	ControllerAnalyser.eventGraph = cycleEvent(function()
        if g_game.isOnline() then
            if LootAnalyser then
                LootAnalyser:updateGraphics()
            end
            if SupplyAnalyser then
                SupplyAnalyser:updateGraphics()
            end
            if XPAnalyser then
                XPAnalyser:updateWindow()
            end
        end
	end, 60*1000)


    if ImpactAnalyser then
        ImpactAnalyser:checkAnchos()
    end
    if InputAnalyser then
        InputAnalyser:checkAnchos()
    end
end
