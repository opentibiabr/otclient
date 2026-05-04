-- Shop tab logic — methods added to TaskBoardController
local confirmBox = nil

--  Server data handler 

function TaskBoardController:onShopData(items)
    local parsed = {}
    for _, raw in ipairs(items or {}) do
        table.insert(parsed, self:parseShopItem(raw))
    end
    self.shopItems = parsed
end

function TaskBoardController:onShopResult(itemId, result)
    if result == 0 then
        -- Success — server will send updated shop data
        return
    end
    local errorMessages = {
        [SHOP_ERR_NOT_FOUND] = "Item not found.",
        [SHOP_ERR_ALREADY_BOUGHT] = "Already purchased.",
        [SHOP_ERR_NO_POINTS] = "Not enough Hunting Task Points.",
        [SHOP_ERR_NEED_BASE] = "You need the base outfit first.",
        [SHOP_ERR_STORE_INBOX] = "Store inbox error."
    }
    local msg = errorMessages[result] or ("Purchase failed (code " .. result .. ").")
    local errBox
    local function close()
        if errBox then
            errBox:destroy();
            errBox = nil
        end
    end
    errBox = displayGeneralBox(tr('Purchase Failed'), msg, {{
        text = tr('Ok'),
        callback = close
    }}, close, close)
end

--  Actions 

function TaskBoardController:buyItem(itemId)
    local item = nil
    local itemIndex = nil
    for index, it in ipairs(self.shopItems) do
        if it.id == tonumber(itemId) then
            item = it
            itemIndex = index
            break
        end
    end
    if not item then
        return
    end
    local msg = tr("Do you really want to buy '%s' for %s Hunting Task Points?", item.title, comma_value(item.price))
    local function yes()
        g_game.taskHuntingShopPurchase(item.id)
        if confirmBox then
            confirmBox:destroy();
            confirmBox = nil
        end
    end
    local function cancel()
        if confirmBox then
            confirmBox:destroy();
            confirmBox = nil
        end
    end
    confirmBox = displayGeneralBox(tr('Confirm Purchase'), msg, {{
        text = tr('Yes'),
        callback = yes
    }, {
        text = tr('Cancel'),
        callback = cancel
    }}, yes, cancel)
end

function TaskBoardController:updateShopBalance(balance)
    self.shopBalance = balance
    -- shopItems canAfford field needs to be updated
    for i, item in ipairs(self.shopItems) do
        self.shopItems[i].canAfford = balance >= item.price
    end
    self.shopItems = self.shopItems
end

--  Item parser 

function TaskBoardController:parseShopItem(raw)
    local offerType = tonumber(raw.offerType) or SHOP_OFFER_TYPE_ITEM
    local data = {
        id = tonumber(raw.id) or 0,
        title = raw.title or "",
        description = raw.description or "",
        price = tonumber(raw.price) or 0,
        bought = (tonumber(raw.bought) or 0) == 1,
        offerType = offerType,
        backdrop = SHOP_BACKDROP_IMAGES[offerType] or SHOP_BACKDROP_IMAGES[SHOP_OFFER_TYPE_ITEM],
        canAfford = false,
        lookMount = 0,
        previewType = nil
    }

    if offerType == SHOP_OFFER_TYPE_OUTFIT then
        local parsedLookType = tonumber(raw.lookType) or 0
        if parsedLookType > 0 then
            data.lookType = parsedLookType
        else
            g_logger.warning(string.format("[TaskBoard][Shop] Outfit without lookType (id=%s, title=%s)",
                tostring(data.id), tostring(data.title)))
        end
        data.lookHead = tonumber(raw.lookHead) or 0
        data.lookBody = tonumber(raw.lookBody) or 0
        data.lookLegs = tonumber(raw.lookLegs) or 0
        data.lookFeet = tonumber(raw.lookFeet) or 0
        data.lookAddons = tonumber(raw.lookAddons) or 0
        data.lookMount = 0
        data.isOutfit = parsedLookType > 0
        data.isCreaturePreview = data.isOutfit
        data.previewType = data.isCreaturePreview and 'creature' or nil
    elseif offerType == SHOP_OFFER_TYPE_MOUNT then
        local parsedMountType = tonumber(raw.lookType) or 0
        if parsedMountType > 0 then
            data.lookMount = parsedMountType
        else
            g_logger.warning(string.format("[TaskBoard][Shop] Mount without lookType (id=%s, title=%s)",
                tostring(data.id), tostring(data.title)))
        end
        data.lookType = 128
        data.lookHead = 95
        data.lookBody = 114
        data.lookLegs = 95
        data.lookFeet = 114
        data.lookAddons = 0
        data.isMount = parsedMountType > 0
        data.isCreaturePreview = data.isMount
        data.previewType = data.isCreaturePreview and 'creature' or nil
    elseif offerType == SHOP_OFFER_TYPE_ITEM or offerType == SHOP_OFFER_TYPE_ITEM_DOUBLE then
        data.itemId = tonumber(raw.itemId) or 0
        data.lookMount = 0
        data.isItem = (data.itemId > 0)
        data.previewType = data.isItem and 'item' or nil
    elseif offerType == SHOP_OFFER_TYPE_BONUS_PROMOTION then
        local defaults = SHOP_BONUS_DEFAULTS[SHOP_OFFER_TYPE_BONUS_PROMOTION] or {}
        data.title = defaults.title or data.title
        data.description = defaults.description or data.description
        data.imageSource = defaults.image or ""
        data.maxPurchases = tonumber(raw.maxPurchases) or 0
        data.currentPurchases = tonumber(raw.currentPurchases) or 0
        data.nextCost = tonumber(raw.nextCost) or 0
        data.price = data.nextCost
        data.description = string.format(data.description, data.currentPurchases)
        data.lookMount = 0
        data.isBonus = true
        data.previewType = 'icon'
    end

    local balance = self.shopBalance
    if balance <= 0 then
        local player = g_game.getLocalPlayer()
        balance = player and player:getResourceBalance(ResourceTypes.TASK_HUNTING) or balance
    end

    data.canAfford = balance >= data.price
    data.displayPrice = comma_value(data.price)

    return data
end
