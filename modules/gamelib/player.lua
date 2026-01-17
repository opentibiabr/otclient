-- @docclass Player
-- local index = math.log(bit) / math.log(2)
PlayerStates = {
	None = 0,	-- vbot
	Poison = 1,
	Burn = 2,
	Energy = 4,
	Drunk = 8,
	ManaShield = 16,
	Paralyze = 32,
	Haste = 64,
	Swords = 128,
	Drowning = 256,
	Freezing = 512,
	Dazzled = 1024,
	Cursed = 2048,
	PartyBuff = 4096,
	RedSwords = 8192,
	PzBlock = 8192,	-- vbot
	Pz = 16384,	-- vbot
	Pigeon = 16384,
	Bleeding = 32768,
	Hungry = 65536,	-- vbot
	LesserHex = 65536,
	IntenseHex = 131072,
	GreaterHex = 262144,
	Rooted = 524288,
	Feared = 1048576,
	GoshnarTaint1 = 2097152,
	GoshnarTaint2 = 4194304,
	GoshnarTaint3 = 8388608,
	GoshnarTaint4 = 16777216,
	GoshnarTaint5 = 33554432,
	NewManaShield = 67108864,
	Agony = 134217728,
-- force icons
	Rewards = 30
}

Icons = {}
Icons[PlayerStates.Poison] = { clip = 1, tooltip = tr('You are poisoned'),  id = 'condition_poisoned' }
Icons[PlayerStates.Burn] = { clip = 2, tooltip = tr('You are burning'),  id = 'condition_burning' }
Icons[PlayerStates.Energy] = { clip = 3, tooltip = tr('You are electrified'),  id = 'condition_electrified' }
Icons[PlayerStates.Drunk] = { clip = 4, tooltip = tr('You are drunk'),  id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { clip = 5, tooltip = tr('You are protected by a magic shield'),  id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze] = { clip = 6, tooltip = tr('You are paralysed'),  id = 'condition_slowed' }
Icons[PlayerStates.Haste] = { clip = 7, tooltip = tr('You are hasted'),  id = 'condition_haste' }
Icons[PlayerStates.Swords] = { clip = 8, tooltip = tr('You may not logout during a fight'),  id = 'condition_logout_block' }
Icons[PlayerStates.Drowning] = { clip = 9, tooltip = tr('You are drowning'),  id = 'condition_drowning' }
Icons[PlayerStates.Freezing] = { clip = 10, tooltip = tr('You are freezing'),  id = 'condition_freezing' }
Icons[PlayerStates.Dazzled] = { clip = 11, tooltip = tr('You are dazzled'),  id = 'condition_dazzled' }
Icons[PlayerStates.Cursed] = { clip = 12, tooltip = tr('You are cursed'),  id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff] = { clip = 13, tooltip = tr('You are strengthened'),  id = 'condition_strengthened' }
Icons[PlayerStates.RedSwords] = { clip = 14, tooltip = tr('You may not logout or enter a protection zone'),  id = 'condition_RedSwords' }
Icons[PlayerStates.Pigeon] = { clip = 15, tooltip = tr('You are within a protection zone'),  id = 'condition_Pigeon' }
Icons[PlayerStates.Bleeding] = { clip = 16, tooltip = tr('You are Bleeding'),  id = 'condition_Bleeding' }
Icons[PlayerStates.LesserHex] = { clip = 17, tooltip = tr('You are LesserHex'),  id = 'condition_LesserHex' }
Icons[PlayerStates.IntenseHex] = { clip = 18, tooltip = tr('You are IntenseHex'),  id = 'condition_IntenseHex' }
Icons[PlayerStates.GreaterHex] = { clip = 19, tooltip = tr('You are GreaterHex'),  id = 'condition_GreaterHex' }
Icons[PlayerStates.Rooted] = { clip = 20, tooltip = tr('You are Rooted'),  id = 'condition_Rooted' }
Icons[PlayerStates.Feared] = { clip = 21, tooltip = tr('You are Feared'),  id = 'condition_Feared' }
Icons[PlayerStates.GoshnarTaint1] = { clip = 22, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint1' }
Icons[PlayerStates.GoshnarTaint2] = { clip = 23, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint2' }
Icons[PlayerStates.GoshnarTaint3] = { clip = 24, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint3' }
Icons[PlayerStates.GoshnarTaint4] = { clip = 25, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint4' }
Icons[PlayerStates.GoshnarTaint5] = { clip = 26, tooltip = tr('You are GoshnarTaint'),  id = 'condition_GoshnarTaint5' }
Icons[PlayerStates.NewManaShield] = {  clip = 27, tooltip = tr('You are NewManaShield'), id = 'condition_NewManaShield' }
Icons[PlayerStates.Agony] = { clip = 28, tooltip = tr('You are Agony'),  id = 'condition_Agony' }
Icons[PlayerStates.Rewards] = { clip = 30, tooltip = tr('Rewards'),  id = 'condition_Rewards' }
Icons[PlayerStates.Hungry] = { clip = 32, tooltip = tr('You are hungry'),  id = 'condition_hungry' }

local PLAYER_STATE_SEGMENT = 4294967296

local function isStateBitActive(states, mask)
    if not states or mask == 0 then
        return false
    end

    if mask < PLAYER_STATE_SEGMENT then
        local low = states % PLAYER_STATE_SEGMENT
        return math.floor(low / mask) % 2 == 1
    end

    local highMask = math.floor(mask / PLAYER_STATE_SEGMENT)
    local high = math.floor(states / PLAYER_STATE_SEGMENT)
    return highMask > 0 and math.floor(high / highMask) % 2 == 1
end

function Player.iterateChangedStates(now, old, callback)
    if now == old then
        return
    end

    local lowNow = now % PLAYER_STATE_SEGMENT
    local lowOld = old % PLAYER_STATE_SEGMENT
    local maxLow = math.max(lowNow, lowOld)
    local mask = 1

    while mask <= maxLow do
        local nowActive = math.floor(lowNow / mask) % 2 == 1
        local oldActive = math.floor(lowOld / mask) % 2 == 1
        if nowActive ~= oldActive then
            callback(mask)
        end
        mask = mask * 2
    end

    local highNow = math.floor(now / PLAYER_STATE_SEGMENT)
    local highOld = math.floor(old / PLAYER_STATE_SEGMENT)
    local maxHigh = math.max(highNow, highOld)
    mask = 1

    while mask <= maxHigh do
        local nowActive = math.floor(highNow / mask) % 2 == 1
        local oldActive = math.floor(highOld / mask) % 2 == 1
        if nowActive ~= oldActive then
            callback(mask * PLAYER_STATE_SEGMENT)
        end
        mask = mask * 2
    end
end

combatStates= {
	CLIENT_COMBAT_PHYSICAL = 0,
	CLIENT_COMBAT_FIRE = 1,
	CLIENT_COMBAT_EARTH = 2,
	CLIENT_COMBAT_ENERGY = 3,
	CLIENT_COMBAT_ICE = 4,
	CLIENT_COMBAT_HOLY = 5,
	CLIENT_COMBAT_DEATH = 6,
	CLIENT_COMBAT_HEALING = 7,
	CLIENT_COMBAT_DROWN = 8,
	CLIENT_COMBAT_LIFEDRAIN = 9,
	CLIENT_COMBAT_MANADRAIN = 10,
}
clientCombat ={}
clientCombat[combatStates.CLIENT_COMBAT_PHYSICAL] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-physical-resist', id = 'Physical' }
clientCombat[combatStates.CLIENT_COMBAT_FIRE] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-fire-resist', id = 'Fire' }
clientCombat[combatStates.CLIENT_COMBAT_EARTH] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-earth-resist', id = 'Earth' }
clientCombat[combatStates.CLIENT_COMBAT_ENERGY] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-energy-resist', id = 'Energy' }
clientCombat[combatStates.CLIENT_COMBAT_ICE] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-ice-resist', id = 'Ice' }
clientCombat[combatStates.CLIENT_COMBAT_HOLY] = {path = '/game_cyclopedia/images/bestiary/icons/monster-icon-holy-resist', id = 'Holy' }
clientCombat[combatStates.CLIENT_COMBAT_DEATH] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-death-resist', id = 'Death' }
clientCombat[combatStates.CLIENT_COMBAT_HEALING] = { path = '/game_cyclopedia/images/bestiary/icons/monster-icon-healing-resist', id = 'Healing' }
clientCombat[combatStates.CLIENT_COMBAT_DROWN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-drowning-resist', id = 'Drown' }
clientCombat[combatStates.CLIENT_COMBAT_LIFEDRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-lifedrain-resist', id = 'Lifedrain ' }
clientCombat[combatStates.CLIENT_COMBAT_MANADRAIN] = {  path = '/game_cyclopedia/images/bestiary/icons/monster-icon-manadrain-resist', id = 'Manadrain' }

InventorySlotOther = 0
InventorySlotHead = 1
InventorySlotNeck = 2
InventorySlotBack = 3
InventorySlotBody = 4
InventorySlotRight = 5
InventorySlotLeft = 6
InventorySlotLeg = 7
InventorySlotFeet = 8
InventorySlotFinger = 9
InventorySlotAmmo = 10
InventorySlotPurse = 11

InventorySlotFirst = 1
InventorySlotLast = 10

vocationNamesByClientId = {
    [0] = "No Vocation",
    [1] = "Knight",
    [2] = "Paladin",
    [3] = "Sorcerer",
    [4] = "Druid",
    [9] = "Monk",
    [10] = "Exalted Monk",
    [11]= "Elite Knight",
    [12] = "Royal Paladin",
    [13] = "Master Sorcerer",
    [14] = "Elder Druid"
}

function Player:isPartyLeader()
    local shield = self:getShield()
    return (shield == ShieldWhiteYellow or shield == ShieldYellow or shield == ShieldYellowSharedExp or shield ==
               ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp)
end

function Player:isPartyMember()
    local shield = self:getShield()
    return (shield == ShieldWhiteYellow or shield == ShieldYellow or shield == ShieldYellowSharedExp or shield ==
               ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or shield == ShieldBlueSharedExp or
               shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp or shield == ShieldBlue)
end

function Player:isPartySharedExperienceActive()
    local shield = self:getShield()
    return (shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExpBlink or shield ==
               ShieldYellowNoSharedExp or shield == ShieldBlueSharedExp or shield == ShieldBlueNoSharedExpBlink or
               shield == ShieldBlueNoSharedExp)
end

function Player:hasVip(creatureName)
    for id, vip in pairs(g_game.getVips()) do
        if (vip[1] == creatureName) then
            return true
        end
    end
    return false
end

function Player:isMounted()
    local outfit = self:getOutfit()
    return outfit.mount ~= nil and outfit.mount > 0
end

function Player:toggleMount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(not self:isMounted())
    end
end

function Player:mount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(true)
    end
end

function Player:dismount()
    if g_game.getFeature(GamePlayerMounts) then
        g_game.mount(false)
    end
end

function Player:getItem(itemId, subType)
    return g_game.findPlayerItem(itemId, subType or -1)
end

function Player:getItems(itemId, subType)
    local subType = subType or -1

    local items = {}
    for i = InventorySlotFirst, InventorySlotLast do
        local item = self:getInventoryItem(i)
        if item and item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
            table.insert(items, item)
        end
    end

    for i, container in pairs(g_game.getContainers()) do
        for j, item in pairs(container:getItems()) do
            if item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
                item.container = container
                table.insert(items, item)
            end
        end
    end
    return items
end

function Player:getItemsCount(itemId)
    local items, count = self:getItems(itemId), 0
    for i = 1, #items do
        count = count + items[i]:getCount()
    end
    return count
end

function Player:hasState(state, states)
    return isStateBitActive(states or self:getStates(), state)
end

function Player.isStateActive(states, state)
    return isStateBitActive(states, state)
end

function Player:getVocationNameByClientId()
    return vocationNamesByClientId[self:getVocation()] or "Unknown Vocation"
end

if not LoadedPlayer then
  LoadedPlayer = {
    playerId = 0,
    playerName = "",
    playerVocation = 0,
  }
  LoadedPlayer.__index = LoadedPlayer
end

function LoadedPlayer:getId() return self.playerId end
function LoadedPlayer:getName() return self.playerName end
function LoadedPlayer:getVocation() return self.playerVocation end
function LoadedPlayer:isLoaded()
  return self.playerId > 0
end

function LoadedPlayer:setId(playerId)
  self.playerId = playerId
end

function LoadedPlayer:setName(playerName)
  self.playerName = playerName
end

function LoadedPlayer:setVocation(vocationId)
  self.playerVocation = vocationId
end