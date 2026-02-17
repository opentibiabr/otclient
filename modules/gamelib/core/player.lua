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

function LocalPlayer:hasCondition(condition) return bit.band(self:getStates(), condition) > 0 end

function LocalPlayer:isInProtectionZone() return self:hasCondition(PlayerStates.Pz) end

isInProtectionZone = function()
  local localPlayer = g_game.getLocalPlayer()
  return localPlayer and localPlayer:hasCondition(PlayerStates.Pz) or false
end