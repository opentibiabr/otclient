-- @docclass Creature
-- @docconsts @{
NpcIconNone = 0
NpcIconChat = 1
NpcIconTrade = 2
NpcIconQuest = 3
NpcIconTradeQuest = 4

CreatureTypePlayer = 0
CreatureTypeMonster = 1
CreatureTypeNpc = 2
CreatureTypeSummonOwn = 3
CreatureTypeSummonOther = 4
CreatureTypeHidden = 5

VocationsServer = {
    None = 0,
    Sorcerer = 1,
    Druid = 2,
    Paladin = 3,
    Knight = 4,
    MasterSorcerer = 5,
    ElderDruid = 6,
    RoyalPaladin = 7,
    EliteKnight = 8,
    Monk = 9,
    ExaltedMonk = 10,
}

VocationsClient = {
    None = 0,
    Knight = 1,
    Paladin = 2,
    Sorcerer = 3,
    Druid = 4,
    Monk = 5,

    EliteKnight = 11,
    RoyalPaladin = 12,
    MasterSorcerer = 13,
    ElderDruid = 14,
    ExaltedMonk = 15,
}
-- @}

function getNextSkullId(skullId)
    if skullId == SkullRed or skullId == SkullBlack then
        return SkullBlack
    end
    return SkullRed
end

function getSkullImagePath(skullId)
    local path
    if skullId == SkullYellow then
        path = '/images/game/skulls/skull_yellow'
    elseif skullId == SkullGreen then
        path = '/images/game/skulls/skull_green'
    elseif skullId == SkullWhite then
        path = '/images/game/skulls/skull_white'
    elseif skullId == SkullRed then
        path = '/images/game/skulls/skull_red'
    elseif skullId == SkullBlack then
        path = '/images/game/skulls/skull_black'
    elseif skullId == SkullOrange then
        path = '/images/game/skulls/skull_orange'
    end
    return path
end

function getShieldImagePathAndBlink(shieldId)
    local path, blink
    if shieldId == ShieldWhiteYellow then
        path, blink = '/images/game/shields/shield_yellow_white', false
    elseif shieldId == ShieldWhiteBlue then
        path, blink = '/images/game/shields/shield_blue_white', false
    elseif shieldId == ShieldBlue then
        path, blink = '/images/game/shields/shield_blue', false
    elseif shieldId == ShieldYellow then
        path, blink = '/images/game/shields/shield_yellow', false
    elseif shieldId == ShieldBlueSharedExp then
        path, blink = '/images/game/shields/shield_blue_shared', false
    elseif shieldId == ShieldYellowSharedExp then
        path, blink = '/images/game/shields/shield_yellow_shared', false
    elseif shieldId == ShieldBlueNoSharedExpBlink then
        path, blink = '/images/game/shields/shield_blue_not_shared', true
    elseif shieldId == ShieldYellowNoSharedExpBlink then
        path, blink = '/images/game/shields/shield_yellow_not_shared', true
    elseif shieldId == ShieldBlueNoSharedExp then
        path, blink = '/images/game/shields/shield_blue_not_shared', false
    elseif shieldId == ShieldYellowNoSharedExp then
        path, blink = '/images/game/shields/shield_yellow_not_shared', false
    elseif shieldId == ShieldGray then
        path, blink = '/images/game/shields/shield_gray', false
    end
    return path, blink
end

function getEmblemImagePath(emblemId)
    local path
    if emblemId == EmblemGreen then
        path = '/images/game/emblems/emblem_green'
    elseif emblemId == EmblemRed then
        path = '/images/game/emblems/emblem_red'
    elseif emblemId == EmblemBlue then
        path = '/images/game/emblems/emblem_blue'
    elseif emblemId == EmblemMember then
        path = '/images/game/emblems/emblem_member'
    elseif emblemId == EmblemOther then
        path = '/images/game/emblems/emblem_other'
    end
    return path
end

function getTypeImagePath(creatureType)
    local path
    if creatureType == CreatureTypeSummonOwn then
        path = '/images/game/creaturetype/summon_own'
    elseif creatureType == CreatureTypeSummonOther then
        path = '/images/game/creaturetype/summon_other'
    end
    return path
end

function getIconImagePath(iconId)
    local path
    if iconId == NpcIconChat then
        path = '/images/game/npcicons/icon_chat'
    elseif iconId == NpcIconTrade then
        path = '/images/game/npcicons/icon_trade'
    elseif iconId == NpcIconQuest then
        path = '/images/game/npcicons/icon_quest'
    elseif iconId == NpcIconTradeQuest then
        path = '/images/game/npcicons/icon_tradequest'
    end
    return path
end

function getIconsImagePath(category)
    if category == 1 then
        return '/images/game/creatureicons/monsterIcons'
    end
    return '/images/game/creatureicons/CreatureIcons'
end

function Creature:onIconsChange(icon, category, count)
    local imagePath = getIconsImagePath(category)
    if imagePath then
        local clipX = (icon - 1) * 11
        self:setIconsTexture(imagePath, torect(clipX .. ' 0 11 11'), count)
    end
    -- Apply fiendish text shader only to monsters and only when the icon matches
    if type(self.isMonster) ~= 'function' or not self:isMonster() then
        return
    end
    if category == 1 and icon == 5 then
        self:setNameShader('Text - Gold Outline')
    elseif self.getNameShader and self:getNameShader() == 'Text - Gold Outline' then
        -- Reset only if we previously applied the fiendish shader
        self:setNameShader('Text - Default')
    end
end

function Creature:onSkullChange(skullId)
    local imagePath = getSkullImagePath(skullId)
    if imagePath then
        self:setSkullTexture(imagePath)
    end
end

function Creature:onShieldChange(shieldId)
    local imagePath, blink = getShieldImagePathAndBlink(shieldId)
    if imagePath then
        self:setShieldTexture(imagePath, blink)
    end
end

function Creature:onEmblemChange(emblemId)
    local imagePath = getEmblemImagePath(emblemId)
    if imagePath then
        self:setEmblemTexture(imagePath)
    end
end

function Creature:onTypeChange(typeId)
    local imagePath = getTypeImagePath(typeId)
    if imagePath then
        self:setTypeTexture(imagePath)
    end
end

function Creature:onIconChange(iconId)
    local imagePath = getIconImagePath(iconId)
    if imagePath then
        self:setIconTexture(imagePath)
    end
end

function Creature.isDruid(self)
    local vocation = self:getVocation()
    return vocation == VocationsClient.Druid or vocation == VocationsClient.ElderDruid
end

function Creature.isSorcerer(self)
    local vocation = self:getVocation()
    return vocation == VocationsClient.Sorcerer or vocation == VocationsClient.MasterSorcerer
end

function Creature.isPaladin(self)
    local vocation = self:getVocation()
    return vocation == VocationsClient.Paladin or vocation == VocationsClient.RoyalPaladin
end

function Creature.isKnight(self)
    local vocation = self:getVocation()
    return vocation == VocationsClient.Knight or vocation == VocationsClient.EliteKnight
end

function Creature.isMonk(self)
    local vocation = self:getVocation()
    return vocation == VocationsClient.Monk  or vocation == VocationsClient.ExaltedMonk
end
