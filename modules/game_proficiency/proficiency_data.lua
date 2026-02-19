-- Proficiency Data Handler
-- Handles loading and processing of proficiency JSON data

if not ProficiencyData then
    ProficiencyData = {}
    ProficiencyData.__index = ProficiencyData
    ProficiencyData.content = {}
    ProficiencyData.nameIndex = {} -- Index by normalized name for quick lookup
end

-- Item tier patterns for matching item names to proficiency entries
-- Order matters - more specific patterns first
local TIER_PATTERNS = {
    -- Inferniarch variants (most specific first)
    { pattern = "siphoning inferniarch", tier = "Siphoning Inferniarch" },
    { pattern = "draining inferniarch", tier = "Draining Inferniarch" },
    { pattern = "rending inferniarch", tier = "Rending Inferniarch" },
    { pattern = "inferniarch", tier = "Inferniarch" },
    -- Eldritch variants
    { pattern = "gilded eldritch", tier = "Gilded Eldritch" },
    { pattern = "eldritch", tier = "Eldritch" },
    -- Umbral variants
    { pattern = "master umbral", tier = "Master Umbral" },
    { pattern = "crude umbral", tier = "Crude Umbral" },
    { pattern = "umbral", tier = "Umbral" },
    -- Sanguine variants
    { pattern = "grand sanguine", tier = "Grand Sanguine" },
    { pattern = "sanguine", tier = "Sanguine" },
    -- Other tiers
    { pattern = "amber", tier = "Amber" },
    { pattern = "soul", tier = "Soul" },
    { pattern = "cobra", tier = "Cobra" },
    { pattern = "falcon", tier = "Falcon" },
    { pattern = "naga", tier = "Naga" },
    { pattern = "lion", tier = "Lion" },
    { pattern = "jungle", tier = "Jungle" },
    { pattern = "glooth", tier = "Glooth" },
    { pattern = "destruction", tier = "Destruction" },
}

-- Weapon type keywords
local WEAPON_KEYWORDS = {
    sword = { "sword", "blade", "sabre", "dagger", "knife", "slayer", "chopper" },
    axe = { "axe", "hatchet", "cleaver" },
    club = { "club", "hammer", "mace", "staff", "cudgel", "flail", "morningstar", "sceptre" },
    bow = { "bow", "crossbow", "arbalest" },
    throw = { "star", "spear", "javelin", "throwing" },
    fist = { "fist", "brass knuckles", "gloves" },
    wand = { "wand" },
    rod = { "rod" },
}

-- Load proficiency data from JSON file
function ProficiencyData:loadProficiencyJson()
    self.content = {}
    self.nameIndex = {}
    
    local file = "/json/proficiencies.json"
    if not g_resources.fileExists(file) then
        return false
    end
    
    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)
    
    if not status then
        return false
    end
    
    for _, data in pairs(result) do
        local ProficiencyId = data["ProficiencyId"]
        local name = data["Name"]
        self.content[ProficiencyId] = data
        
        -- Build name-based index for quick lookup
        if name then
            local lowerName = string.lower(name)
            self.nameIndex[lowerName] = ProficiencyId
        end
    end
    
    
    if WeaponProficiency then
        WeaponProficiency:createItemCache()
    end
    
    return true
end

-- Try to find an item-specific proficiency entry
-- JSON has entries like "Throw - Assassin Star", "Sword 1H Assassin Dagger", etc.
function ProficiencyData:findItemSpecificProficiency(itemName, weaponType, isTwoHanded)
    if not itemName then return nil end
    local lowerName = string.lower(itemName)
    
    -- Build possible JSON entry names based on weapon type
    local handedness = isTwoHanded and "2H" or "1H"
    local possibleNames = {}
    
    -- Determine weapon category prefix
    local prefix = nil
    if weaponType == 8 or weaponType == "throw" then
        -- Throwing weapons use "Throw - {ItemName}" format
        table.insert(possibleNames, "throw - " .. lowerName)
    else
        -- Map weapon types to prefixes used in JSON
        local prefixMap = {
            [3] = "Sword",    -- WEAPON_SWORD
            [2] = "Axe",      -- WEAPON_AXE  
            [1] = "Club",     -- WEAPON_CLUB
            [6] = "Distance", -- WEAPON_BOW
            [7] = "Distance", -- WEAPON_BOW (alt)
            [9] = "Distance", -- WEAPON_CROSSBOW
            [0] = "Fist",     -- WEAPON_FIST
            [4] = nil,        -- WEAPON_WANDROD - handled separately
        }
        prefix = prefixMap[weaponType]
        
        -- For wands/rods, check item name
        if weaponType == 4 then
            if string.find(lowerName, "rod", 1, true) then
                prefix = "Rod"
            else
                prefix = "Wand"
            end
        end
        
        if prefix then
            -- Try "{WeaponType} {1H/2H} {ItemName}" format
            table.insert(possibleNames, string.lower(prefix .. " " .. handedness .. " " .. itemName))
            -- Also try without handedness for some items
            table.insert(possibleNames, string.lower(prefix .. " " .. itemName))
        end
        
        -- Also try "Caster" prefix for wands/rods/staffs
        if prefix == "Wand" or prefix == "Rod" or string.find(lowerName, "staff", 1, true) then
            table.insert(possibleNames, string.lower("Caster " .. handedness .. " " .. itemName))
            table.insert(possibleNames, string.lower("Caster " .. itemName))
        end
    end
    
    -- Check each possible name in the index
    for _, searchName in ipairs(possibleNames) do
        local profId = self.nameIndex[searchName]
        if profId and self:isValidProficiencyId(profId) then
            return profId
        end
    end
    
    -- Also do a partial match search for item name in all entries
    -- Only match if the JSON name contains the item name as a suffix (after " - " or at the end)
    -- AND the weapon type matches (to avoid Club matching for Wand items)
    local weaponPrefix = nil
    if weaponType then
        if weaponType == 3 then weaponPrefix = "sword"
        elseif weaponType == 2 then weaponPrefix = "axe"
        elseif weaponType == 1 then weaponPrefix = "club"
        elseif weaponType == 4 then weaponPrefix = "wand"  -- Also matches "rod"
        elseif weaponType == 6 or weaponType == 7 or weaponType == 8 or weaponType == 9 then weaponPrefix = "bow"
        elseif weaponType == 0 then weaponPrefix = "fist"
        end
    end
    
    for jsonName, profId in pairs(self.nameIndex) do
        -- Check formats like "Throw - Assassin Star" or "Sword 1H Assassin Dagger"
        -- The item name should appear after " - " or as the last words
        
        -- Check for " - itemname" at the end
        local dashSuffix = " - " .. lowerName
        if #jsonName >= #dashSuffix and string.sub(jsonName, -#dashSuffix) == dashSuffix then
            -- Verify weapon type matches if we have one
            if weaponPrefix then
                local firstWord = string.match(jsonName, "^(%w+)")
                if firstWord and string.lower(firstWord) == weaponPrefix then
                    return profId
                elseif weaponPrefix == "wand" and firstWord and (string.lower(firstWord) == "wand" or string.lower(firstWord) == "rod" or string.lower(firstWord) == "caster") then
                    return profId
                end
                -- If weapon type doesn't match, skip this entry
            else
                return profId
            end
        end
        
        -- Check for " itemname" at the end (space + item name)
        local spaceSuffix = " " .. lowerName
        if #jsonName >= #spaceSuffix and string.sub(jsonName, -#spaceSuffix) == spaceSuffix then
            -- Verify weapon type matches if we have one
            if weaponPrefix then
                local firstWord = string.match(jsonName, "^(%w+)")
                if firstWord and string.lower(firstWord) == weaponPrefix then
                    return profId
                elseif weaponPrefix == "wand" and firstWord and (string.lower(firstWord) == "wand" or string.lower(firstWord) == "rod" or string.lower(firstWord) == "caster") then
                    return profId
                end
                -- If weapon type doesn't match, skip this entry
            else
                return profId
            end
        end
    end
    
    return nil
end

-- Detect item tier from name
function ProficiencyData:detectItemTier(itemName)
    if not itemName then return "Sanguine" end
    local lowerName = string.lower(itemName)
    
    for _, tierInfo in ipairs(TIER_PATTERNS) do
        if string.find(lowerName, tierInfo.pattern, 1, true) then
            return tierInfo.tier
        end
    end
    
    return "Sanguine" -- Default tier
end

-- Detect weapon type from item name
function ProficiencyData:detectWeaponTypeFromName(itemName)
    if not itemName then return nil end
    local lowerName = string.lower(itemName)
    
    -- Check each weapon type's keywords
    for weaponType, keywords in pairs(WEAPON_KEYWORDS) do
        for _, keyword in ipairs(keywords) do
            if string.find(lowerName, keyword, 1, true) then
                return weaponType
            end
        end
    end
    
    return nil
end

-- Get proficiency ID by matching item name to JSON entry
function ProficiencyData:getProficiencyIdByItemName(itemName, weaponType, isTwoHanded)
    if not itemName then return nil end
    
    local tier = self:detectItemTier(itemName)
    local handedness = isTwoHanded and "2H" or "1H"
    
    -- Determine weapon category name for JSON lookup
    local weaponCategoryName = nil
    if weaponType then
        if weaponType == 3 or weaponType == "sword" then -- WEAPON_SWORD
            weaponCategoryName = "Sword"
        elseif weaponType == 2 or weaponType == "axe" then -- WEAPON_AXE
            weaponCategoryName = "Axe"
        elseif weaponType == 1 or weaponType == "club" then -- WEAPON_CLUB
            weaponCategoryName = "Club"
        elseif weaponType == 6 or weaponType == 7 or weaponType == 8 or weaponType == 9 or weaponType == "bow" or weaponType == "throw" then
            weaponCategoryName = "Bow"
            handedness = "2H" -- Distance is always 2H in JSON
        elseif weaponType == 0 or weaponType == "fist" then -- WEAPON_FIST
            weaponCategoryName = "Fist"
            handedness = "2H" -- Fist is 2H in JSON
        elseif weaponType == 4 or weaponType == "wand" then -- WEAPON_WANDROD
            -- Detect if it's a wand or rod from name
            local lowerName = string.lower(itemName)
            if string.find(lowerName, "rod", 1, true) then
                weaponCategoryName = "Rod"
            else
                weaponCategoryName = "Wand"
            end
            handedness = "1H"
        elseif weaponType == "rod" then
            weaponCategoryName = "Rod"
            handedness = "1H"
        end
    else
        -- Try to detect from item name
        local detectedType = self:detectWeaponTypeFromName(itemName)
        if detectedType == "sword" then weaponCategoryName = "Sword"
        elseif detectedType == "axe" then weaponCategoryName = "Axe"
        elseif detectedType == "club" then weaponCategoryName = "Club"
        elseif detectedType == "bow" or detectedType == "throw" then 
            weaponCategoryName = "Bow"
            handedness = "2H"
        elseif detectedType == "fist" then 
            weaponCategoryName = "Fist"
            handedness = "2H"
        elseif detectedType == "wand" then 
            weaponCategoryName = "Wand"
            handedness = "1H"
        elseif detectedType == "rod" then 
            weaponCategoryName = "Rod"
            handedness = "1H"
        end
    end
    
    if not weaponCategoryName then
        return nil
    end
    
    -- Build the expected JSON entry name
    -- Format: "Tier HandH WeaponType" e.g. "Grand Sanguine 2H Bow"
    -- Special case for Inferniarch Distance
    local jsonName
    if tier == "Inferniarch" and weaponCategoryName == "Bow" then
        jsonName = string.format("%s %s Distance", tier, handedness)
    else
        jsonName = string.format("%s %s %s", tier, handedness, weaponCategoryName)
    end
    
    local lowerJsonName = string.lower(jsonName)
    local profId = self.nameIndex[lowerJsonName]
    
    if profId then
        return profId
    end
    
    return nil
end

-- Check if proficiency ID is valid
function ProficiencyData:isValidProficiencyId(id)
    return self.content[id] ~= nil
end

-- Get proficiency content by ID
function ProficiencyData:getContentById(id)
    local content = self.content[id]
    return content and content or nil
end

-- Get proficiency ID based on market category
-- Market categories from RTC: Axes=17, Clubs=18, Distance=19, Swords=20, Wands=21, Fist=27
-- Proficiency IDs from JSON (verified):
--   6=Sanguine 1H Sword, 8=Sanguine 1H Axe, 9=Sanguine 1H Club, 10=Sanguine 2H Sword
--   11=Sanguine 2H Axe, 12=Sanguine 2H Club, 13=Sanguine 2H Bow, 14=Sanguine 2H Fist, 15=Sanguine 1H Wand
function ProficiencyData:getProficiencyIdFromCategory(marketCategory, itemName)
    -- MarketCategory enum values from RTC -> Correct Proficiency IDs
    local categoryMap = {
        [17] = 8,   -- MarketCategory.Axes -> Proficiency 8 (Axe)
        [18] = 9,   -- MarketCategory.Clubs -> Proficiency 9 (Club)
        [20] = 6,   -- MarketCategory.Swords -> Proficiency 6 (Sword)
        [21] = 15,  -- MarketCategory.WandsRods -> Proficiency 15 (Wand)
        [27] = 14,  -- MarketCategory.FistWeapons -> Proficiency 14 (Fist)
    }
    
    -- For distance weapons (category 19), all use Bow proficiency (13)
    if marketCategory == 19 then
        return 13  -- Bow proficiency for all distance weapons
    end
    
    return categoryMap[marketCategory]
end

-- Get a default proficiency ID based on weapon type
-- Weapon types: 0=None, 1=Club, 2=Axe, 3=Sword, 4=Wand/Rod, 5=Shield, 6=Bow, 7=Bow, 8=Throwing, 9=Crossbow
-- Proficiency IDs from JSON (verified):
--   6=Sword, 8=Axe, 9=Club, 13=Bow, 14=Fist, 15=Wand
function ProficiencyData:getDefaultProficiencyId(weaponType)
    local defaultMap = {
        [0] = 14,  -- Fist/None -> ID 14 (Fist)
        [1] = 9,   -- WEAPON_CLUB -> Proficiency ID 9 (Club)
        [2] = 8,   -- WEAPON_AXE -> Proficiency ID 8 (Axe)
        [3] = 6,   -- WEAPON_SWORD -> Proficiency ID 6 (Sword)
        [4] = 15,  -- WEAPON_WANDROD -> Proficiency ID 15 (Wand)
        [6] = 13,  -- WEAPON_BOW -> Proficiency ID 13 (Bow)
        [7] = 13,  -- WEAPON_BOW (alt) -> Proficiency ID 13 (Bow)
        [8] = 13,  -- WEAPON_THROW -> Proficiency ID 13 (Bow)
        [9] = 13,  -- WEAPON_CROSSBOW -> Proficiency ID 13 (Bow - same base perks)
    }
    return defaultMap[weaponType] or 6
end

-- Get proficiency ID for an item, with fallback to default
-- Can pass either an Item, ThingType, or both via a table {item=..., thingType=...}
-- Also accepts marketData for category-based lookup
function ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    if not displayItem and not thingType and not marketData then
        return 6 -- Default fallback
    end
    
    -- Try to get proficiencyId from item if method exists
    if displayItem and displayItem.getProficiencyId then
        local id = displayItem:getProficiencyId()
        if id and id > 0 and self:isValidProficiencyId(id) then
            return id
        end
    end
    
    -- Get item name and weapon type for name-based lookup
    local itemName = nil
    local weaponType = nil
    local isTwoHanded = false
    
    if marketData then
        itemName = marketData.name
    end
    
    if thingType then
        if not itemName and thingType.getMarketData then
            local md = thingType:getMarketData()
            if md then
                itemName = md.name
            end
        end
        if thingType.getWeaponType then
            weaponType = thingType:getWeaponType()
        end
        if thingType.isTwoHanded then
            isTwoHanded = thingType:isTwoHanded()
        end
    end
    
    -- FORCE FIX: If item is in WandsRods category (21), override weaponType to 4 (Wand)
    -- This fixes items like Ferumbras' staff that have incorrect weaponType in .dat
    local marketCat = nil
    if marketData and marketData.category then
        marketCat = marketData.category
    elseif thingType and thingType.getMarketData then
        local md = thingType:getMarketData()
        if md then marketCat = md.category end
    end
    
    if marketCat == 21 then  -- MarketCategory.WandsRods
        weaponType = 4  -- Force to WEAPON_WANDROD
    end
    
    if displayItem and not itemName then
        if displayItem.getName then
            itemName = displayItem:getName()
        end
        if not weaponType and displayItem.getWeaponType then
            weaponType = displayItem:getWeaponType()
        end
    end
    
    -- Get market category for debugging
    local marketCategory = nil
    if marketData then
        marketCategory = marketData.category
    elseif thingType and thingType.getMarketData then
        local md = thingType:getMarketData()
        if md then marketCategory = md.category end
    end
    
    -- FIRST: Try to find item-specific proficiency entry (e.g., "Throw - Assassin Star")
    if itemName then
        local profId = self:findItemSpecificProficiency(itemName, weaponType, isTwoHanded)
        if profId and self:isValidProficiencyId(profId) then
            return profId
        end
    end
    
    -- SECOND: Try tier-based lookup (for tiered items like "grand sanguine bow")
    if itemName then
        local profId = self:getProficiencyIdByItemName(itemName, weaponType, isTwoHanded)
        if profId and self:isValidProficiencyId(profId) then
            return profId
        end
    end
    
    -- Fallback to category-based lookup
    if marketData and marketData.category then
        local profId = self:getProficiencyIdFromCategory(marketData.category, itemName)
        if profId and self:isValidProficiencyId(profId) then
            return profId
        end
    end
    
    if thingType and thingType.getMarketData then
        local md = thingType:getMarketData()
        if md and md.category then
            local profId = self:getProficiencyIdFromCategory(md.category, md.name)
            if profId and self:isValidProficiencyId(profId) then
                return profId
            end
        end
    end
    
    -- Final fallback: weapon type default
    weaponType = weaponType or 0
    
    if weaponType > 0 then
        local defaultId = self:getDefaultProficiencyId(weaponType)
        if self:isValidProficiencyId(defaultId) then
            return defaultId
        end
    end
    
    -- Last resort: return first available proficiency ID
    for id, _ in pairs(self.content) do
        return id
    end
    
    return 6
end

-- Get number of perk lanes for a proficiency
function ProficiencyData:getPerkLaneCount(id)
    local content = self.content[id]
    if not content then
        return 0
    end
    return table.size(content.Levels or {})
end

-- Format float value for display
function ProficiencyData:formatFloatValue(value, roundFloat, perkType)
    local function isPercentageType(perkType)
        for _, v in ipairs(PercentageTypes) do
            if v == perkType then
                return true
            end
        end
        return false
    end
    
    local isInteger = math.floor(value) == value
    if not isInteger or (isInteger and isPercentageType(perkType)) then
        local percentage = value * 100
        if roundFloat then
            local intPart = math.floor(percentage)
            local decimal1 = math.floor(percentage * 10 + 0.5) / 10
            if percentage == intPart then
                return tostring(intPart)
            elseif percentage == decimal1 then
                return string.format("%.1f", percentage)
            else
                return string.format("%.2f", percentage)
            end
        else
            return string.format("%.2f", percentage)
        end
    else
        return tostring(value)
    end
end

-- Get image source and clip for a perk
function ProficiencyData:getImageSourceAndClip(perkData)
    local perkType = perkData.Type
    local data = PerkVisualData[perkType]
    local source = (data and data.source) or "icons-0"
    local imagePath = string.format("/images/game/proficiency/%s", source)
    
    if not data then
        return imagePath, "0 0"
    end
    
    if perkType == PERK_SPELL_AUGMENT then
        local spellData = SpellAugmentIcons[perkData.SpellId]
        if spellData then
            return imagePath, spellData.imageOffset
        end
        return imagePath, "0 0"
    end
    
    if perkType == PERK_BESTIARY_DAMAGE then
        local bestiaryType = BestiaryCategories[perkData.BestiaryName]
        return imagePath, (bestiaryType and bestiaryType.imageOffset) or "0 0"
    end
    
    if perkType == PERK_MAGIC_BONUS then
        local elementData = MagicBoostMask[perkData.DamageType]
        return imagePath, elementData and elementData.imageOffset or "0 0"
    end
    
    if ElementalCritical_t[perkType] then
        local elementData = ElementalMask[perkData.ElementId]
        return imagePath, (elementData and elementData.imageOffset) or "0 0"
    end
    
    if FlatDamageBonus_t[perkType] then
        local skillData = SkillTypes[perkData.SkillId]
        return imagePath, skillData and skillData.imageOffset or "0 0"
    end
    
    return imagePath, data.offset or "0 0"
end

-- Get bonus name and tooltip for a perk
function ProficiencyData:getBonusNameAndTooltip(perkData)
    local perkType = perkData.Type
    local data = PerkTextData[perkType]
    local value = self:formatFloatValue(perkData.Value, false, perkType)
    local bonusName = data and data.name or "Empty"
    
    if not data then
        return bonusName, "Empty"
    end
    
    if perkType == PERK_SPELL_AUGMENT then
        local spellData = SpellAugmentIcons[perkData.SpellId]
        local augmentData = AugmentPerkIcons[perkData.AugmentType]
        
        if spellData and augmentData then
            value = self:formatFloatValue(perkData.Value, true, perkType)
            if perkData.AugmentType == AUGMENT_COOLDOWN then
                value = value / 100
            end
            
            local description = string.format(augmentData.desc, value, spellData.name)
            return bonusName, description
        end
        return bonusName, "Unknown spell augment"
    end
    
    if perkType == PERK_BESTIARY_DAMAGE then
        local description = string.format(data.desc, value, perkData.BestiaryName or "Unknown")
        return bonusName, description
    end
    
    if perkType == PERK_MAGIC_BONUS then
        local elementData = MagicBoostMask[perkData.DamageType]
        local description = string.format(data.desc, value, elementData and elementData.name or "Unknown")
        return bonusName, description
    end
    
    if perkType == PERK_PERFECT_SHOT then
        local description = string.format(data.desc, value, perkData.Range or 1)
        return bonusName, description
    end
    
    if ElementalCritical_t[perkType] then
        local elementData = ElementalMask[perkData.ElementId]
        local description = string.format(data.desc, value, elementData and elementData.name or "Unknown")
        return bonusName, description
    end
    
    if FlatDamageBonus_t[perkType] then
        local skillData = SkillTypes[perkData.SkillId]
        local description = string.format(data.desc, value, skillData and skillData.name or "Unknown")
        return bonusName, description
    end
    
    return bonusName, string.format(data.desc, value)
end

-- Get augment icon clip
function ProficiencyData:getAugmentIconClip(perkData)
    local augmentData = AugmentPerkIcons[perkData.AugmentType]
    if not augmentData then
        return "0 0"
    end
    return augmentData.imageOffset
end

-- Get current ceil experience for next level
function ProficiencyData:getCurrentCeilExperience(exp, displayItem, thingType)
    local best = nil
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    local lastExp = nil
    local proficiencyId = self:getProficiencyIdForItem(displayItem, thingType)
    local limitIndex = self:getPerkLaneCount(proficiencyId) + 2
    
    for index, stage in ipairs(ExperienceTable) do
        if index > limitIndex then
            break
        end
        
        local stageExp = stage[vocation]
        if stageExp then
            if stageExp > exp then
                if not best or stageExp < best then
                    best = stageExp
                end
            end
            lastExp = stageExp
        end
    end
    
    return best or lastExp or 0
end

-- Get max experience for a proficiency
function ProficiencyData:getMaxExperience(perkCount, displayItem, thingType)
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    local lastLevel = ExperienceTable[perkCount + 2]
    return (lastLevel and lastLevel[vocation]) or 0
end

-- Get level percent progress
function ProficiencyData:getLevelPercent(currentExperience, level, displayItem, thingType)
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    local prevLevel = math.max(level - 1, 0)
    local xpMin = prevLevel == 0 and 0 or (ExperienceTable[prevLevel] and ExperienceTable[prevLevel][vocation] or 0)
    local xpMax = (ExperienceTable[level] and ExperienceTable[level][vocation]) or xpMin + 1
    
    -- If xpMax is nil or invalid, return 0 to avoid showing 100%
    if not xpMax or xpMax <= xpMin then
        return 0
    end
    
    local progress = math.max(0, math.min(1, (currentExperience - xpMin) / (xpMax - xpMin)))
    local percent = math.floor(progress * 100)
    
    
    return percent
end

-- Get total progress percent
function ProficiencyData:getTotalPercent(currentExperience, perkCount, displayItem, thingType)
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    local maxExperience = (ExperienceTable[perkCount + 2] and ExperienceTable[perkCount + 2][vocation]) or 1
    local progress = math.max(0, math.min(1, currentExperience / maxExperience))
    return math.floor(progress * 100)
end

-- Get max experience by level
function ProficiencyData:getMaxExperienceByLevel(level, displayItem, thingType)
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    return (ExperienceTable[level] and ExperienceTable[level][vocation]) or 0
end

-- Get current level by experience
function ProficiencyData:getCurrentLevelByExp(displayItem, currentExperience, includeMastery, thingType)
    local vocation = self:getWeaponProfessionType(displayItem, thingType)
    local currentLevel = 0
    
    for level, data in pairs(ExperienceTable) do
        local requiredExp = data[vocation]
        if requiredExp and currentExperience >= requiredExp then
            if level > currentLevel then
                currentLevel = level
            end
        end
    end
    
    local level = math.min(7, currentLevel)
    if includeMastery then
        level = currentLevel
    end
    
    return level
end

-- Determine weapon profession type based on vocation and weapon type
function ProficiencyData:getWeaponProfessionType(displayItem, thingType)
    if not displayItem and not thingType then
        return "regular"
    end
    
    -- PRIORITY: Use thingType for market data (more reliable)
    local marketData = nil
    if thingType and thingType.getMarketData then
        marketData = thingType:getMarketData() or {}
    elseif displayItem and displayItem.getMarketData then
        marketData = displayItem:getMarketData() or {}
    else
        marketData = {}
    end
    
    -- Check for knight vocation restriction
    -- restrictVocation can be a number (bitmask) or a table
    if marketData.restrictVocation then
        local restrictVoc = marketData.restrictVocation
        if type(restrictVoc) == "table" then
            for _, vocationId in pairs(restrictVoc) do
                if vocationId == 1 then -- Knight
                    return "knight"
                end
            end
        elseif type(restrictVoc) == "number" then
            -- Check if knight bit is set (assuming knight = vocation 1)
            -- Bitmask: bit 0 = Knight (1), bit 1 = Paladin (2), etc.
            if bit32 then
                if bit32.band(restrictVoc, 1) ~= 0 then
                    return "knight"
                end
            else
                -- Fallback without bit32
                if restrictVoc % 2 == 1 then
                    return "knight"
                end
            end
        end
    end
    
    -- Check for crossbow weapon type (get from thingType first, then item)
    local weaponType = 0
    if thingType and thingType.getWeaponType then
        weaponType = thingType:getWeaponType() or 0
    elseif displayItem and displayItem.getWeaponType then
        weaponType = displayItem:getWeaponType() or 0
    end
    
    -- WEAPON_CROSSBOW = 9 in Tibia
    if weaponType == 9 then
        return "crossbow"
    end
    
    return "regular"
end

