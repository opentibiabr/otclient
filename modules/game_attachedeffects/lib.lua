local __EFFECTS = {}
local __THING_CONFIG = {}

local executeConfig = function(attachedEffect, config)
    if not config then
        return
    end

    local x = 0
    local y = 0
    local onTop = config.onTop or false

    if config.speed then
        attachedEffect:setSpeed(config.speed)
    end

    if config.drawOnUI == false then
        attachedEffect:setCanDrawOnUI(false)
    end

    if config.shader then
        attachedEffect:setShader(config.shader)
    end

    if config.opacity ~= nil and config.opacity < 1.0 then
        attachedEffect:setOpacity(config.opacity)
    end

    if config.light then
        attachedEffect:setLight({
            color = config.light.color or 0,
            intensity = config.light.intensity or 0
        })
    end

    if config.followOwner then
        attachedEffect:setFollowOwner(config.followOwner)
    end

    if config.drawOrder then
        attachedEffect:setDrawOrder(config.drawOrder)
    end

    if config.bounce then
        attachedEffect:setBounce(config.bounce[1], config.bounce[2], config.bounce[3] or 1000)
    end

    if config.pulse then
        attachedEffect:setPulse(config.pulse[1], config.pulse[2], config.pulse[3] or 1000)
    end

    if config.fade then
        attachedEffect:setFade(config.fade[1], config.fade[2], config.fade[3] or 1000)
    end

    if config.duration ~= nil and config.duration > 0 then
        attachedEffect:setDuration(config.duration)
    end

    if config.loop ~= nil and config.loop > 0 then
        attachedEffect:setLoop(config.loop)
    end

    attachedEffect:setPermanent(type(config.permanent) ~= "boolean" or config.permanent)

    if config.transform then
        attachedEffect:setTransform(config.transform)
    end

    if config.hideOwner then
        attachedEffect:setHideOwner(config.hideOwner)
    end

    if config.size then
        attachedEffect:setSize({
            width = config.size[1],
            height = config.size[2]
        })
    end

    if config.disableWalkAnimation then
        attachedEffect:setDisableWalkAnimation(config.disableWalkAnimation)
    end

    if config.offset then
        x = config.offset[1] or 0
        y = config.offset[2] or 0
        onTop = config.offset[3] or onTop
    end

    if x ~= 0 or y ~= 0 then
        attachedEffect:setOffset(x, y)
    end

    if onTop then
        attachedEffect:setOnTop(true)
    end

    if config.dirOffset then
        for dir, offset in pairs(config.dirOffset) do
            local _x = offset[1] or x
            local _y = offset[2] or y
            local _onTop = offset[3] or onTop

            if type(x) == 'boolean' then -- onTop Config
                attachedEffect:setOnTopByDir(dir, _x)
            else
                attachedEffect:setDirOffset(dir, _x, _y, _onTop)
            end
        end
    end
end

AttachedEffectManager = {
    get = function(id)
        return __EFFECTS[id]
    end,
    register = function(id, name, thingId, thingCategory, config)
        local attachedEffect = nil
        if thingCategory == ThingExternalTexture then
            attachedEffect = g_attachedEffects.registerByImage(id, name, thingId)
        else
            attachedEffect = g_attachedEffects.registerByThing(id, name, thingId, thingCategory)
        end

        if attachedEffect == nil then
            return
        end

        executeConfig(attachedEffect, config)
        config.isThingConfig = false

        __EFFECTS[id] = {
            id = id,
            name = name,
            thingId = thingId,
            thingCategory = thingCategory,
            config = config
        }
    end,
    registerThingConfig = function(category, thingId)
        if __THING_CONFIG[category] == nil then
            __THING_CONFIG[category] = {}
        end

        if __THING_CONFIG[category][thingId] == nil then
            __THING_CONFIG[category][thingId] = {}
        end

        local thingConfig = __THING_CONFIG[category][thingId]

        local methods = {
            set = function(self, id, config)
                local effect = AttachedEffectManager.get(id)
                if effect == nil then
                    g_logger.error('Invalid Attached Effect ID(' .. id .. ')')
                    return
                end

                local __config = table.recursivecopy(effect.config)
                table.merge(__config, config)

                thingConfig[id] = __config

                __config.isThingConfig = true
                if config.onAttach then
                    __config.__onAttach = effect.config.onAttach
                end

                if config.onDetach then
                    __config.__onDetach = effect.config.onDetach
                end
            end
        }

        return methods
    end,
    getConfig = function(id, category, thingId)
        local config = __THING_CONFIG[category]
        if config then
            config = config[thingId]
            if config then
                config = config[id]
                if config then
                    return config
                end
            end
        end
        local effectConfig = __EFFECTS[id] and __EFFECTS[id].config or nil
        if not effectConfig then
            g_logger.debug(string.format("[AttachedEffect]getConfig: No config registered for effect ID %d", id))
        end
        return effectConfig
    end,
    executeThingConfig = function(effect, category, thingId)
        executeConfig(effect, AttachedEffectManager.getConfig(effect:getId(), category, thingId))
    end,
    getDataThing = function(thing)
        if thing:isCreature() then
            return ThingCategoryCreature, thing:getOutfit().type
        end

        if thing:isItem() then
            return ThingCategoryItem, thing:getId()
        end

        return ThingInvalidCategory, 0
    end
}
