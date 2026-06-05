EventController = {
    events = nil,
    connected = false
}

function EventController:new(actor, events)
    if actor == nil then
        error('Actor is null.')
        return
    end

    if events == nil then
        error('Events is null.')
        return
    end

    local obj = {
        actor = actor,
        events = events,
        connected = false
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function EventController:connect()
    if self.connected then
        return
    end
    self.connected = true

    connect(self.actor, self.events)
end

function EventController:disconnect()
    if not self.connected then
        return
    end
    self.connected = false
    disconnect(self.actor, self.events)
end

function EventController:destroy()
    self:disconnect()
    self.actor = nil
    self.events = nil
end

function EventController:isWidget()
    return self.actor and self.actor.addChild ~= nil
end

function EventController:actorIsDestroyed()
    return self:isWidget() and self.actor:isDestroyed()
end

function EventController:isDestroyed()
    return self.actor == nil
end

function EventController:getActor()
    return self.actor
end

function EventController:execute(name, ...)
    if name == nil then
        for name, act in pairs(self.events) do
            act()
        end
        return
    end

    self.events[name](...)
end
