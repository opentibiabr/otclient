CaveBot.Extensions.PosCheck = {}

local posCheckRetries = 0
local lastPosCheckValue = nil
CaveBot.Extensions.PosCheck.setup = function()
  CaveBot.registerAction("PosCheck", "#00FFFF", function(value, retries)
    local tilePos
    local data = string.split(value, ",")
    if #data ~= 5 and #data ~= 6 then
     warn("wrong poscheck format, should be: label, distance, x, y, z[, maxRetries]")
     return false
    end

    local tilePos = player:getPosition()

    tilePos.x = tonumber(data[3])
    tilePos.y = tonumber(data[4])
    tilePos.z = tonumber(data[5])

    local maxRetries = 10
    if #data == 6 then
      local maxRetriesArg = data[6] and data[6]:trim()
      if maxRetriesArg and maxRetriesArg:len() > 0 then
        if maxRetriesArg == "inf" or maxRetriesArg == "infinity" or maxRetriesArg == "0" then
          maxRetries = 0
        else
          maxRetries = tonumber(maxRetriesArg)
          if not maxRetries then
            warn("wrong poscheck format, maxRetries should be a number or 'inf', is: " .. maxRetriesArg)
            return false
          end
        end
      end
    end

    if lastPosCheckValue ~= value then
        lastPosCheckValue = value
        posCheckRetries = 0
    end

    if maxRetries > 0 and posCheckRetries > maxRetries then
        posCheckRetries = 0
        print("CaveBot[CheckPos]: waypoints locked, too many tries, unclogging cavebot and proceeding")
        return false
    elseif (tilePos.z == player:getPosition().z) and (getDistanceBetween(player:getPosition(), tilePos) <= tonumber(data[2])) then
        posCheckRetries = 0
        print("CaveBot[CheckPos]: position reached, proceeding")
        return true
    else
        posCheckRetries = posCheckRetries + 1
        if data[1] == "last" then
          CaveBot.gotoFirstPreviousReachableWaypoint()
          print("CaveBot[CheckPos]: position not-reached, going back to first reachable waypoint.")
          return false
        else
          CaveBot.gotoLabel(data[1])
          print("CaveBot[CheckPos]: position not-reached, going back to label: " .. data[1])
          return false
        end
    end
  end)

  CaveBot.Editor.registerAction("poscheck", "pos check", {
    value=function() return "last" .. "," .. "10" .. "," .. posx() .. "," .. posy() .. "," .. posz() .. "," .. "10" end,
    title="Location Check",
    description="label name, accepted dist from coordinates, x, y, z, maxRetries (0/inf=infinite)",
    multiline=false,
})
end
