local function onAttach(effect, owner)
    local category, thingId = AttachedEffectManager.getDataThing(owner)
    local config = AttachedEffectManager.getConfig(effect:getId(), category, thingId)

    if not config then
        g_logger.debug(string.format("[AttachedEffect] onAttach: No config found for effect ID %d (category: %d, thingId: %d)", effect:getId(), category, thingId))
        return
    end

    if config.isThingConfig then
        AttachedEffectManager.executeThingConfig(effect, category, thingId)
    end

    if config.onAttach then
        config.onAttach(effect, owner, config.__onAttach)
    end
end

local function onDetach(effect, oldOwner)
    local category, thingId = AttachedEffectManager.getDataThing(oldOwner)
    local config = AttachedEffectManager.getConfig(effect:getId(), category, thingId)

    if not config then
        g_logger.debug(string.format("[AttachedEffect] onDetach: No config found for effect ID %d (category: %d, thingId: %d)", effect:getId(), category, thingId))
        return
    end

    if config.onDetach then
        config.onDetach(effect, oldOwner, config.__onDetach)
    end
end

local function onOutfitChange(creature, outfit, oldOutfit)
    for _i, effect in pairs(creature:getAttachedEffects()) do
        AttachedEffectManager.executeThingConfig(effect, ThingCategoryCreature, outfit.type)
    end
end

controller = Controller:new()

function controller:onGameStart()
    controller:registerEvents(LocalPlayer, {
        onOutfitChange = onOutfitChange
    })

    controller:registerEvents(Creature, {
        onOutfitChange = onOutfitChange
    })

    controller:registerEvents(AttachedEffect, {
        onAttach = onAttach,
        onDetach = onDetach
    })

    -- uncomment this line to apply an effect on the local player, just for testing purposes.
    --[[g_game.getLocalPlayer():attachEffect(g_attachedEffects.getById(1))
    g_game.getLocalPlayer():attachEffect(g_attachedEffects.getById(2))
    g_game.getLocalPlayer():attachEffect(g_attachedEffects.getById(3))
    g_game.getLocalPlayer():getTile():attachEffect(g_attachedEffects.getById(1))
    g_game.getLocalPlayer():attachParticleEffect("creature-effect")]]
end

function controller:onGameEnd()
    -- g_game.getLocalPlayer():clearAttachedEffects()
end

function controller:onTerminate()
    g_attachedEffects.clear()
end

function getCategory(id)
    local effect = AttachedEffectManager.get(id)
    if effect then
        return effect.thingCategory
    end
    return nil
end

function getTexture(id)
    local effect = AttachedEffectManager.get(id)
    if effect and effect.thingCategory == 5 then
        return effect.thingId
    end
end

function getName(id)
    if type(id) == "number" then
        local effect = AttachedEffectManager.get(id)
        if effect then
            return effect.name
        else
            return "None"
        end
    else
        return "None"
    end
end

function thingId(id)
    if type(id) == "number" then
        local effect = AttachedEffectManager.get(id)
        if effect then
            return effect.thingId
        else
            return "None"
        end
    else
        return "None"
    end
end
