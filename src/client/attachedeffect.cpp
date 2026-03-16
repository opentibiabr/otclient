/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "attachedeffect.h"

#include "animator.h"
#include "gameconfig.h"
#include "lightview.h"
#include "thingtype.h"
#include "thingtypemanager.h"
#include "framework/core/clock.h"
#include "framework/graphics/animatedtexture.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/shadermanager.h"
#include "framework/graphics/texture.h"
#include "framework/graphics/texturemanager.h"

AttachedEffectPtr AttachedEffect::create(const uint16_t thingId, const ThingCategory category) {
    if (!g_things.isValidDatId(thingId, category)) {
        g_logger.error("AttachedEffectManager::getInstance({}, {}): invalid thing with id or category.", thingId, static_cast<uint8_t>(category));
        return nullptr;
    }

    const auto& obj = std::make_shared<AttachedEffect>();
    obj->m_thingId = thingId;
    obj->m_thingCategory = category;
    return obj;
}

AttachedEffectPtr AttachedEffect::clone()
{
    auto obj = std::make_shared<AttachedEffect>();
    *(obj.get()) = *this;

    obj->m_frame = 0;
    obj->m_animationTimer.restart();
    obj->m_bounce.timer.restart();
    obj->m_pulse.timer.restart();
    obj->m_fade.timer.restart();

    if (!obj->m_texturePath.empty()) {
        if ((obj->m_texture = g_textures.getTexture(obj->m_texturePath, obj->m_smooth))) {
            if (obj->m_texture->isAnimatedTexture()) {
                const auto& animatedTexture = std::static_pointer_cast<AnimatedTexture>(obj->m_texture);
                animatedTexture->setOnMap(true);
                animatedTexture->restart();
            }
        }
    }

    return obj;
}

int getBounce(const Bounce& bounce) {
    const auto minHeight = bounce.minHeight * g_drawPool.getScaleFactor();
    const auto height = bounce.height * g_drawPool.getScaleFactor();
    return minHeight + (height - std::abs(height - static_cast<int>(bounce.timer.ticksElapsed() / (bounce.speed / 100.f)) % static_cast<int>(height * 2)));
}

void AttachedEffect::draw(const Point& dest, const bool isOnTop, LightView* lightView, const bool drawThing) {
    if (m_transform)
        return;

    auto* thingType = getThingType();
    if (m_texture != nullptr || thingType != nullptr) {
        const auto& dirControl = m_offsetDirections[m_direction];
        if (dirControl.onTop != isOnTop)
            return;

        if (!m_canDrawOnUI && g_drawPool.getCurrentType() == DrawPoolType::FOREGROUND)
            return;

        const int animation = getCurrentAnimationPhase();
        if (m_loop > -1 && animation != m_lastAnimation) {
            m_lastAnimation = animation;
            if (animation == 0 && --m_loop == 0)
                return;
        }

        // Check if the thing type can actually be drawn before setting opacity/shader
        // This prevents stale state from affecting subsequent draws when this effect
        // returns early due to missing texture or invalid state
        if (!m_texture && thingType && (thingType->isNull() || thingType->getAnimationPhases() == 0))
            return;


        const auto scaleFactor = g_drawPool.getScaleFactor();

        // Only set shader, opacity, pulse and fade when actually drawing things
        // to prevent stale state from affecting subsequent draws
        if (drawThing) {
            if (m_shader) g_drawPool.setShaderProgram(m_shader, true);
            if (m_opacity < 100) g_drawPool.setOpacity(getOpacity(), true);

            if (m_pulse.height > 0 && m_pulse.speed > 0) {
                g_drawPool.setScaleFactor(scaleFactor + getBounce(m_pulse) / 100.f);
            }

            if (m_fade.height > 0 && m_fade.speed > 0) {
                g_drawPool.setOpacity(std::clamp<float>(getBounce(m_fade) / 100.f, 0, 1.f));
            }
        }

        auto point = dest - (dirControl.offset * g_drawPool.getScaleFactor());
        if (!m_toPoint.isNull()) {
            const float fraction = std::min<float>(m_animationTimer.ticksElapsed() / static_cast<float>(m_duration), 1.f);
            point += m_toPoint * fraction * g_drawPool.getScaleFactor();
        }

        if (m_bounce.height > 0 && m_bounce.speed > 0) {
            point -= getBounce(m_bounce);
        }

        if (lightView && m_light.intensity > 0)
            lightView->addLightSource(dest, m_light);

        auto lastDrawOrder = g_drawPool.getDrawOrder();
        if (g_drawPool.getCurrentType() == DrawPoolType::MAP)
            g_drawPool.setDrawOrder(getDrawOrder());

        if (m_texture) {
            if (drawThing) {
                const auto& size = (m_size.isUnset() ? m_texture->getSize() : m_size) * g_drawPool.getScaleFactor();
                const auto& texture = m_texture->isAnimatedTexture() ? std::static_pointer_cast<AnimatedTexture>(m_texture)->get(m_frame, m_animationTimer) : m_texture;
                const auto& rect = Rect(Point(), texture->getSize());

                g_drawPool.addTexturedRect(Rect(point, size), texture, rect, Color::white);
            }
        } else {
            thingType->draw(point, 0, m_direction, 0, 0, animation, Color::white, drawThing, lightView);
        }

        g_drawPool.setDrawOrder(lastDrawOrder);

        if (drawThing) {
            if (m_pulse.height > 0 && m_pulse.speed > 0) {
                g_drawPool.setScaleFactor(scaleFactor);
            }

            if (m_fade.height > 0 && m_fade.speed > 0) {
                g_drawPool.resetOpacity();
            }
        }
    }

    if (drawThing) {
        for (const auto& effect : m_effects)
            effect->draw(dest, isOnTop, lightView);
    }
}

void AttachedEffect::drawLight(const Point& dest, LightView* lightView) {
    if (!lightView) return;

    const auto& dirControl = m_offsetDirections[m_direction];
    draw(dest, dirControl.onTop, lightView, false);

    for (const auto& effect : m_effects)
        effect->drawLight(dest, lightView);
}

int AttachedEffect::getCurrentAnimationPhase()
{
    if (m_texture) {
        if (m_texture->isAnimatedTexture())
            std::static_pointer_cast<AnimatedTexture>(m_texture)->get(m_frame, m_animationTimer);
        return m_frame;
    }

    const auto thingTye = getThingType();

    const auto* animator = thingTye->getIdleAnimator();
    if (!animator && thingTye->isAnimateAlways())
        animator = thingTye->getAnimator();

    if (animator)
        return animator->getPhaseAt(m_animationTimer, getSpeed());

    if (thingTye->isEffect()) {
        const int lastPhase = thingTye->getAnimationPhases() - 1;
        const int phase = std::min<int>(static_cast<int>(m_animationTimer.ticksElapsed() / (g_gameConfig.getEffectTicksPerFrame() / getSpeed())), lastPhase);
        if (phase == lastPhase) m_animationTimer.restart();
        return phase;
    }

    if (thingTye->isCreature() && thingTye->isAnimateAlways()) {
        const int ticksPerFrame = std::round(1000 / thingTye->getAnimationPhases()) / getSpeed();
        return (g_clock.millis() % (static_cast<long long>(ticksPerFrame) * thingTye->getAnimationPhases())) / ticksPerFrame;
    }

    return 0;
}

void AttachedEffect::setShader(const std::string_view name) { m_shader = g_shaders.getShader(name); }

void AttachedEffect::move(const Position& fromPosition, const Position& toPosition) {
    m_toPoint = Point(toPosition.x - fromPosition.x, toPosition.y - fromPosition.y) * g_gameConfig.getSpriteSize();
    m_animationTimer.restart();
}

ThingType* AttachedEffect::getThingType() const {
    return m_thingId > 0 ? g_things.getRawThingType(m_thingId, m_thingCategory) : nullptr;
}