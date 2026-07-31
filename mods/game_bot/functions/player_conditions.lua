local context = G.botContext

for i, state in ipairs(PlayerStates) do
  context[state] = state
end

context.hasCondition = function(condition) return Bit.band(context.player:getStates(), condition) > 0 end

context.isPoisioned = function() return context.hasCondition(PlayerStates.Poison) end
context.isBurning = function() return context.hasCondition(PlayerStates.Burn) end
context.isEnergized = function() return context.hasCondition(PlayerStates.Energy) end
context.isDrunk = function() return context.hasCondition(PlayerStates.Drunk) end
context.hasManaShield = function() return context.hasCondition(PlayerStates.ManaShield) end
context.hasNewManaShield = function() return context.hasCondition(PlayerStates.NewManaShield) end
context.isParalyzed = function() return context.hasCondition(PlayerStates.Paralyze) end
context.hasHaste = function() return context.hasCondition(PlayerStates.Haste) end
context.hasSwords = function() return context.hasCondition(PlayerStates.Swords) end
context.isInFight = function() return context.hasCondition(PlayerStates.Swords) end
context.canLogout = function() return not context.hasCondition(PlayerStates.Swords) end
context.isDrowning = function() return context.hasCondition(PlayerStates.Drowning) end
context.isFreezing = function() return context.hasCondition(PlayerStates.Freezing) end
context.isDazzled = function() return context.hasCondition(PlayerStates.Dazzled) end
context.isCursed = function() return context.hasCondition(PlayerStates.Cursed) end
context.hasPartyBuff = function() return context.hasCondition(PlayerStates.PartyBuff) end
context.hasPzLock = function() return context.hasCondition(PlayerStates.PzBlock) end
context.hasPzBlock = function() return context.hasCondition(PlayerStates.PzBlock) end
context.isPzLocked = function() return context.hasCondition(PlayerStates.PzBlock) end
context.isPzBlocked = function() return context.hasCondition(PlayerStates.PzBlock) end
context.isInProtectionZone = function() return context.hasCondition(PlayerStates.Pz) end
context.hasPz = function() return context.hasCondition(PlayerStates.Pz) end
context.isInPz = function() return context.hasCondition(PlayerStates.Pz) end
context.isBleeding = function() return context.hasCondition(PlayerStates.Bleeding) end
context.isHungry = function() return context.hasCondition(PlayerStates.Hungry) end
