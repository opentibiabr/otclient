function sendMarketAction(action, itemId, tier)
    if action == 3 and itemId then
        g_game.browseMarket(3, itemId, tier or 0)
    elseif action == 2 then
        g_game.browseMarket(2, 0, 0)
    elseif action == 1 then
        g_game.browseMarket(1, 0, 0)
    end
end

function sendMarketLeave()
    g_game.leaveMarket()
end

function sendMarketAcceptOffer(timestamp, counter, amount)
    g_game.acceptMarketOffer(timestamp, counter, amount)
end

function sendMarketCreateOffer(offerType, itemId, tier, amount, price, anonymous)
    g_game.createMarketOffer(offerType, itemId, tier or 0, amount, price, anonymous and 1 or 0)
end

function sendMarketCancelOffer(timestamp, counter)
    g_game.cancelMarketOffer(timestamp, counter)
end

function getTransferableTibiaCoins()
    local player = g_game.getLocalPlayer()
    if not player then
        return 0
    end
    return player:getResourceBalance(91) or 0
end

function convertGold(amount, showSign)
    if not amount then
        return "0"
    end
    
    local sign = ""
    if showSign then
        if amount > 0 then
            sign = "+"
        elseif amount < 0 then
            sign = "-"
            amount = math.abs(amount)
        end
    end
    
    return sign .. comma_value(tostring(amount))
end

function convertLongGold(amount)
    if not amount then
        return "0"
    end
    
    amount = tonumber(amount)
    if not amount then
        return "0"
    end
    
    if amount >= 1000000000 then
        return string.format("%.1fB", amount / 1000000000)
    elseif amount >= 1000000 then
        return string.format("%.1fM", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("%.1fK", amount / 1000)
    else
        return tostring(amount)
    end
end

function getTotalMoney()
    local player = g_game.getLocalPlayer()
    if not player then
        return 0
    end
    
    if player.getTotalMoney then
        return player:getTotalMoney()
    end
    
    local bankBalance = player:getResourceBalance(0) or 0
    local goldEquipped = player:getResourceBalance(1) or 0
    
    return bankBalance + goldEquipped
end

function short_text(text, chars_limit)
    if not text then
        return ""
    end
    
    chars_limit = chars_limit or 20
    
    if string.len(text) <= chars_limit then
        return text
    end
    
    return string.sub(text, 1, chars_limit - 3) .. "..."
end

function matchText(text, search)
    if not text or not search then
        return false
    end
    
    return text:lower():find(search:lower(), 1, true) ~= nil
end

function setStringColor(textStringOrTable, text, color)
    if not textStringOrTable then
        return ""
    end
    
    if type(textStringOrTable) == "table" then
        table.insert(textStringOrTable, "{" .. text .. ", " .. color .. "}")
        return
    end
    
    if not text or not color then
        return textStringOrTable
    end
    
    local startPos, endPos = textStringOrTable:lower():find(text:lower(), 1, true)
    
    if startPos then
        local before = textStringOrTable:sub(1, startPos - 1)
        local match = textStringOrTable:sub(startPos, endPos)
        local after = textStringOrTable:sub(endPos + 1)
        
        return before .. "{" .. color .. "," .. match .. "}" .. after
    end
    
    return textStringOrTable
end

function getCoinStepValue(currentAmount)
    if not currentAmount or currentAmount < 1 then
        return 1
    end
    
    currentAmount = tonumber(currentAmount)
    
    if currentAmount >= 10000000 then
        return 1000000
    elseif currentAmount >= 1000000 then
        return 100000
    elseif currentAmount >= 100000 then
        return 10000
    elseif currentAmount >= 10000 then
        return 1000
    elseif currentAmount >= 1000 then
        return 100
    elseif currentAmount >= 100 then
        return 10
    else
        return 1
    end
end

function translateWheelVocation(vocationId)
    if not vocationId then
        return "None"
    end
    
    local vocationNames = {
        [0] = "None",
        [1] = "Knight",
        [2] = "Paladin",
        [3] = "Sorcerer",
        [4] = "Druid",
        [5] = "Monk",
        [11] = "Elite Knight",
        [12] = "Royal Paladin",
        [13] = "Master Sorcerer",
        [14] = "Elder Druid",
        [15] = "Exalted Monk"
    }
    
    return vocationNames[vocationId] or "Unknown"
end
