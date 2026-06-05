local voc = player:getVocation()
if voc == 1 or voc == 11 or voc == 5 or voc == 15 then
    setDefaultTab("Cave")
    UI.Separator()
    local m = macro(100000, "Exeta when low hp", function() end)
    local lastCast = now
    onCreatureHealthPercentChange(function(creature, healthPercent)
        if m.isOff() then return end
        if healthPercent > 15 then return end
        if CaveBot.isOff() or TargetBot.isOff() then return end
        if modules.game_cooldown.isGroupCooldownIconActive(3) then return end
        if creature:getPosition() and getDistanceBetween(pos(),creature:getPosition()) > 1 then return end
        if canCast("exeta res") and now - lastCast > 6000 then
            say("exeta res")
            lastCast = now
        end
    end)

    macro(500, "ExetaIfPlayer", function()
        if CaveBot.isOff() then return end
    	if getMonsters(1) >= 1 and getPlayers(6) > 0 then
    		say("exeta res")
    		delay(6000)
    	end
    end)
    UI.Separator()
end
