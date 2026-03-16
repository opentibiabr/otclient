Helpers = {}

function Helpers.cloneValue(value)
    if type(value) == 'table' then
        if table and type(table.recursivecopy) == 'function' then
            return table.recursivecopy(value)
        end

        local copy = {}
        for key, child in pairs(value) do
            copy[key] = Helpers.cloneValue(child)
        end
        return copy
    end

    return value
end

function Helpers.normalizeTierPriceEntries(entries)
    local prices = {}
    if type(entries) ~= 'table' then
        return prices
    end

    for _, entry in ipairs(entries) do
        if type(entry) == 'table' then
            local tierId = tonumber(entry.tier) or tonumber(entry.tierId) or tonumber(entry.id)
            local price = tonumber(entry.price) or tonumber(entry.cost) or tonumber(entry.value)
            if tierId then
                prices[tierId + 1] = price or 0
            end
        end
    end

    return prices
end

function Helpers.normalizeClassPriceEntries(entries)
    local pricesByClass = {}
    if type(entries) ~= 'table' then
        return pricesByClass
    end

    for _, classInfo in ipairs(entries) do
        if type(classInfo) == 'table' then
            local classId = tonumber(classInfo.classId)
                or tonumber(classInfo.id)
                or tonumber(classInfo.classification)
            if classId then
                pricesByClass[classId] = Helpers.normalizeTierPriceEntries(classInfo.tiers)
            end
        end
    end

    return pricesByClass
end

function Helpers.formatHistoryDate(timestamp)
    if not timestamp then
        return 'Unknown'
    end
    
    -- If already a formatted string (contains "-" or ":"), return it as-is
    if type(timestamp) == 'string' then
        if string.find(timestamp, '-') or string.find(timestamp, ':') then
            return timestamp
        end
        -- Try to convert string to number (in case it's a numeric string)
        timestamp = tonumber(timestamp)
        if not timestamp then
            return 'Unknown'
        end
    end
    
    -- If it's a number (unix timestamp), format it
    if type(timestamp) == 'number' then
        if timestamp == 0 then
            return 'Unknown'
        end
        -- Protect os.date call with pcall in case of invalid timestamp
        local success, result = pcall(os.date, '%Y-%m-%d, %H:%M:%S', timestamp)
        if success then
            return result
        else
            return 'Unknown'
        end
    end
    
    return 'Unknown'
end

Helpers.rightArrow = "/modules/game_forge/images/arrows/icon-arrow-rightlarge.png"
Helpers.filledRightArrow = "/modules/game_forge/images/arrows/icon-arrow-rightlarge-filled.png"

Helpers.baseResult = {
    leftItemId = -1,
    leftTier = 0,
    leftClip = nil,
    rightItemId = -1,
    rightTier = 0,
    rightClip = nil,
    label = "",
    labelResult = "",
    bonusItem = -1,
    bonus = 0,
    bonusTier = 0,
    bonusItemClip = nil,
    bonusLabel = "",
    bonusAction = nil,
    arrows = {
        { arrow = Helpers.rightArrow, },
        { arrow = Helpers.filledRightArrow, },
        { arrow = Helpers.rightArrow, }
    },
    buttonLabel = "Close"
}

Helpers.green = "#44ad25"
Helpers.red = "#d33c3c"
Helpers.grey = "#c0c0c0"

function Helpers.handleDescription(data, currentType)
    if currentType == "convert-dust" then
        data.description =
        "Convert your dust into slivers. Slivers are used to create exalted cores which are useful for fusions and transfers."
        return
    end

    if currentType == "convert-dust-cost" then
        local dusts = data.currentDust or 0
        local necessaryDusts = data.conversion.necessaryDustToSliver or 0
        if dusts < necessaryDusts then
            data.description = "You do not have enough dust to generate a sliver."
        else
            local dustToSliver = data.conversion.dustToSliver or 0
            data.description = string.format("Click here to convert %d dust into %d slivers.",
                necessaryDusts, dustToSliver)
        end
        return
    end

    if currentType == "convert-sliver" then
        data.description = "Convert slivers into exalted cores. Exalted cores are useful for fusions and transfers."
        return
    end

    if currentType == "convert-sliver-cost" then
        local dusts = data.currentDust or 0
        local necessarySliver = data.conversion.sliverToCore or 0
        if dusts < necessarySliver then
            data.description = "You do not have enough dust to generate a sliver."
        else
            data.description = string.format("Click here to convert %d slivers into %d exalted cores.",
                necessarySliver, 1)
        end
        return
    end

    if currentType == "increase-dust-limit" then
        local dustMax = data.conversion.dustMax or 0
        data.description = string.format(
            "Use dust to increase permanently the amount of the dust you can gather (currently %d).", dustMax)
        return
    end

    if currentType == "increase-dust-limit-cost" then
        local dusts = data.currentDust or 0

        if dusts < data.conversion.dustMaxIncreaseCost then
            data.description = "You do not have enough dust to raise the limit."
        else
            local dustMax = data.conversion.dustMax or 0
            data.description = "You do not have enough dust to raise the limit."

            data.description = string.format("Click here to spend %d dust to increase your limit from %d to %d.",
                data.conversion.dustMaxIncreaseCost, dustMax, dustMax + 1)
        end
        return
    end

    if currentType == "transfer-convergence" then
        data.description = "A convergence transfer does not reduce the tier of the consumed item."

        return
    end

    if currentType == "transfer-donors-items" then
        local isConvergence = data.transfer.isConvergence
        if isConvergence then
            data.description =
            "You can transfer the tier of a classification 4 item to another item of the same classification. To do this, you must have at least one tier 1 item that will be consumed during the transfer and additional resources. The other item will receive the tier of the consumed item."
        else
            data.description =
            "You can transfer the tier of an item to another item of the same classification. To do so, you need at least a tier 2 item that will be consumed during the transfer and additional resources. The other item will received the consumed item's tier reduced by one."
        end
        return
    end

    if currentType == "transfer-cost-donor-item" then
        data.description =
        "Select an item whose tier you want to transfer. Warning! This item will be consumed during the transfer."
        return
    end

    if currentType == "transfer-cost-receiver-item" then
        data.description = "Select the item to which you want to transfer the tier."
        return
    end

    if currentType == "transfer-cost-donor-preview" then
        if data.transfer.selected.id == -1 then
            data.description =
            "You do not carry an item whose tier can be transferred. Note that imbued items cannot be used for a transfer."
            return
        end

        data.description = string.format("%s with tier %d will be consumed during the transfer.",
            "Unknown Item", data.transfer.selected.tier or 0)
        return
    end

    if currentType == "transfer-cost-dust" then
        local dusts = data.currentDust or 0
        local necessaryDusts = data.transfer.isConvergence and data.transfer.convergenceDust or data.transfer.dust or 0
        if dusts < necessaryDusts then
            data.description = string.format(
                "A transfer requires %d dust. Unfortunately you do not have the needed amount.", necessaryDusts)
        else
            data.description = string.format("A transfer requires %d dust.",
                necessaryDusts)
        end
        return
    end

    if currentType == "transfer-cost-exalted-core" then
        if data.transfer.selected.id == -1 then
            data.description =
            "Please select an item above to continue."
            return
        end

        local dusts = data.currentExaltedCores or 0
        local necessaryDusts = data.transfer.necessaryExaltedCores or 0
        if dusts < necessaryDusts then
            data.description = string.format(
                "A transfer requires %d exalted cores. Unfortunately you do not have the needed amount.", necessaryDusts)
        else
            data.description = string.format("Click here to spend %d dust to perform the transfer.",
                necessaryDusts)
        end
        return
    end

    if currentType == "transfer-forge-action" then
        if data.transfer.selected.id == -1 or data.transfer.selectedTarget.id == -1 then
            data.description =
            "Please select both the item whose tier you wish to transfer and the item you want to transfer the tier to."
            return
        end

        if not data.transfer.canTransfer then
            data.description = "You do not have all the ingredients you need."
            return
        end

        data.description = "Click here to carry out the transfer. This will consume all required ingredients."
        return
    end

    if currentType == "fusion-select-item" then
        data.description = "Select an item you want to fuse."
        return
    end

    if currentType == "fusion-preview-item" then
        if data.fusion.selected.id == -1 then
            data.description = "Please select an item above to continue."
        else
            data.description =
            "For the fusion a second item of the same type and tier is needed, which will be consumed. Be warned! The item will be consumed even if the fusion fails."
        end
        return
    end

    if currentType == "fusion-cost-dust" then
        local dust = data.currentDust or 0
        local necessaryDust = data.fusion.isConvergence and data.fusion.convergenceDust or data.fusion.dust or 0

        if dust < necessaryDust then
            data.description = string.format(
                "A fusion requires %d dust. Unfortunately you do not have the needed amount.", necessaryDust)
        else
            data.description = string.format(
                "A fusion requires %d dust. Be warned! The dust will be consumed even if the fusion fails.",
                necessaryDust)
            return
        end
    end

    if currentType == "fusion-improve-chance" then
        local baseImproveChance = data.fusion.chanceBase
        local improvedChance = data.fusion.chanceImproved
        local totalImprovedChance = baseImproveChance + improvedChance
        if data.fusion.chanceImprovedChecked then
            data.description =
                string.format(
                    "Click here if you do not want to use the exalted core. This will reduce your chance from %d%% to %d%%.",
                    totalImprovedChance, baseImproveChance)
        else
            data.description =
                string.format(
                    "Improve your chances! Click here to raise your chance for a successful fusion from %d%% to %d%% at the cost of one exalted core.",
                    baseImproveChance, totalImprovedChance)
        end
        return
    end

    if currentType == "fusion-reduce-loss" then
        if data.fusion.reduceTierLossChecked then
            data.description =
            "Click here if you do not want to use the exalted core. Note that you will lose the chance to keep the tier on the second item in case the fusion fails."
        else
            local reduceLoss = data.fusion.reduceTierLoss
            data.description =
                string.format(
                    "Reduce your losses! Click here to pay one exalted core and with that get a %d%% chance of keeping the tier of the second item in case the fusion fails.",
                    reduceLoss)
        end
        return
    end

    if currentType == "fusion-forge-action" then
        local isConvergence = data.fusion.isConvergence

        if not isConvergence then
            if data.fusion.selected.id == -1 then
                data.description = "Please select all required ingredients."
                return
            end
        else
            if data.fusion.selectedTarget.id == -1 then
                data.description = "Please select all required ingredients."
                return
            end
        end

        if not data.fusion.canFusion then
            data.description = "You do not have all the ingredients you need."
            return
        end

        data.description = "Click here to start a fusion attempt. This will consume or alter the required ingredients."
        return
    end
end
