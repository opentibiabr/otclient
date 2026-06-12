function Player.sendExtendedJSONOpcode(self, opcode, buffer)
    if not self:isUsingOtClient() then
        return false
    end

    local networkMessage = NetworkMessage()
    networkMessage:addByte(0x32)
    networkMessage:addByte(opcode)
    networkMessage:addString(json.encode(buffer))
    networkMessage:sendToPlayer(self)
    networkMessage:delete()
    return true
end