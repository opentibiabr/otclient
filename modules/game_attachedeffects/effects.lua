--[[
    register(id, name, thingId, thingType, config)
    config = {
        speed, disableWalkAnimation, shader, drawOnUI, opacity
        duration, loop, transform, hideOwner, followOwner, size{width, height}
        offset{x, y, onTop}, dirOffset[dir]{x, y, onTop},
        light { color, intensity}, drawOrder(only for tiles),
        bounce{minHeight, height, speed},
        pulse{minHeight, height, speed},
        fade{start, end, speed}

        onAttach, onDetach
    }
]]
--
AttachedEffectManager.register(1, 'Spoke Lighting', 12, ThingCategoryEffect, {
    speed = 0.5,
    onAttach = function(effect, owner)
        print('onAttach: ', effect:getId(), owner:getName())
    end,
    onDetach = function(effect, oldOwner)
        print('onDetach: ', effect:getId(), oldOwner:getName())
    end
})

-- Use the paperdoll system instead of attachedEffect for this kind of attachment, it’s more consistent.
AttachedEffectManager.register(2, 'Bat Wings', 307, ThingCategoryCreature, {
    speed = 5,
    disableWalkAnimation = true,
    shader = 'Outfit - Rainbow',
    followOwner = true,
    dirOffset = {
        [North] = { 0, -10, true },
        [East] = { 5, -5 },
        [South] = { -5, 0 },
        [West] = { -10, -5, true }
    },
    onAttach = function(effect, owner)
        owner:setBounce(0, 10, 5000)
    end,
    onDetach = function(effect, oldOwner)
        oldOwner:setBounce(0, 0)
    end
})

AttachedEffectManager.register(3, 'Angel Light', 50, ThingCategoryEffect, {
    opacity = 0.5,
    drawOnUI = false
})

AttachedEffectManager.register(4, 'Four Angel Light', 0, 0, {
    onAttach = function(effect, owner)
        local angelLight = g_attachedEffects.getById(3)
        local angelLight1 = angelLight:clone()
        local angelLight2 = angelLight:clone()
        local angelLight3 = angelLight:clone()
        local angelLight4 = angelLight:clone()

        angelLight1:setOffset(-50, 50, true)
        angelLight2:setOffset(50, 50, true)
        angelLight3:setOffset(50, -50, true)
        angelLight4:setOffset(-50, -50, true)

        effect:attachEffect(angelLight1)
        effect:attachEffect(angelLight2)
        effect:attachEffect(angelLight3)
        effect:attachEffect(angelLight4)
    end
})

AttachedEffectManager.register(5, 'Transform', 40, ThingCategoryCreature, {
    transform = true,
    duration = 5000,
    onAttach = function(effect, owner)
        local e = Effect.create()
        e:setId(7)
        owner:getTile():addThing(e)
    end,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(50)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(6, 'Lake Monster', 34, ThingCategoryEffect, {
    hideOwner = true,
    duration = 1500,
    -- loop = 1,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(54)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(7, 'Pentagram Aura', '/images/game/effects/pentagram', ThingExternalTexture, {
    size = { 128, 128 },
    offset = { 50, 45 }
})

AttachedEffectManager.register(8, 'Ki', '/images/game/effects/ki', ThingExternalTexture, {
    size = { 140, 110 },
    offset = { 60, 75, true },
    pulse = { 0, 50, 3000 },
    --fade = { 0, 100, 1000 },
})

AttachedEffectManager.register(9, 'Thunder', '/images/game/effects/thunder', ThingExternalTexture, {
    loop = 1,
    offset = { 215, 230 }
})

AttachedEffectManager.register(10, 'Dynamic Effect', 0, 0, {
    duration = 500,
    onAttach = function(effect, owner)
        local spriteSize = g_gameConfig.getSpriteSize()
        local length = 3

        local missile = AttachedEffect.create(38, ThingCategoryMissile)
        missile:setDuration(effect:getDuration())
        missile:setDirection(5)
        missile:setOffset(spriteSize * length, 0)
        missile:setBounce(0, 15, 1000)
        missile:move(Position.translated(owner:getPosition(), -length, 0), owner:getPosition())
        effect:attachEffect(missile)

        missile = AttachedEffect.create(38, ThingCategoryMissile)
        missile:setDuration(effect:getDuration())
        missile:setDirection(3)
        missile:setOffset(-(spriteSize * length), 0)
        missile:setBounce(0, 15, 1000)
        missile:move(Position.translated(owner:getPosition(), length, 0), owner:getPosition())

        effect:attachEffect(missile)
    end,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(50)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(11, 'Bat', 307, ThingCategoryCreature, {
    speed = 0.5,
    offset = { 0, 0 },
    bounce = { 20, 20, 2000 }
})
