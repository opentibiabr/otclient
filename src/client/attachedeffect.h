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

#pragma once
#include "framework/core/timer.h"
#include "framework/graphics/declarations.h"
#include "framework/luaengine/luaobject.h"
#include "staticdata.h"

class AttachedEffect final : public LuaObject
{
public:
    static AttachedEffectPtr create(uint16_t thingId, ThingCategory category);

    void draw(const Point& /*dest*/, bool /*isOnTop*/, LightView* = nullptr, bool drawThing = true);
    void drawLight(const Point& /*dest*/, LightView*);

    uint16_t getId() { return m_id; }

    AttachedEffectPtr clone();

    float getSpeed() { return m_speed / 100.f; }
    void setSpeed(const float speed) { m_speed = speed * 100u; }

    float getOpacity() { return m_opacity / 100.f; }
    void setOpacity(const float opacity) { m_opacity = opacity * 100u; }

    Size getSize() { return m_size; }
    void setSize(const Size& s) { m_size = s; }

    bool isHidedOwner() { return m_hideOwner; }
    void setHideOwner(const bool v) { m_hideOwner = v; }

    bool isTransform() { return m_transform; }
    void setTransform(const bool v) { m_transform = v; }

    bool isDisabledWalkAnimation() { return m_disableWalkAnimation; }
    void setDisableWalkAnimation(const bool v) { m_disableWalkAnimation = v; }

    bool isPermanent() { return m_permanent; }
    void setPermanent(const bool permanent) { m_permanent = permanent; }

    bool isFollowingOwner() { return m_followOwner; }
    void setFollowOwner(const bool v) { m_followOwner = v; }

    uint16_t getDuration() { return m_duration; }
    void setDuration(const uint16_t v) { m_duration = v; }

    int8_t getLoop() { return m_loop; }
    void setLoop(const int8_t v) { m_loop = v; }

    void setName(std::string_view n) { m_name = n.data(); }
    std::string getName() { return m_name; }

    Otc::Direction getDirection() { return m_direction; }
    void setDirection(const Otc::Direction dir) { m_direction = std::min<Otc::Direction>(dir, Otc::NorthWest); }

    void setBounce(const uint8_t minHeight, const uint8_t height, const uint16_t speed) {
        m_bounce = { .minHeight = minHeight,.height = height, .speed = speed };
    }
    void setPulse(const uint8_t minHeight, const uint8_t height, const uint16_t speed) {
        m_pulse = { .minHeight = minHeight,.height = height, .speed = speed };
    }
    void setFade(const uint8_t start, const uint8_t end, const uint16_t speed) {
        m_fade = { .minHeight = start, .height = end,.speed = speed };
    }

    void setOnTop(const bool onTop) { for (auto& control : m_offsetDirections) control.onTop = onTop; }
    void setOffset(int16_t x, int16_t y) { for (auto& control : m_offsetDirections) control.offset = { x, y }; }
    void setOnTopByDir(const Otc::Direction direction, const bool onTop) { m_offsetDirections[direction].onTop = onTop; }

    void setDirOffset(const Otc::Direction direction, int8_t x, int8_t y, const bool onTop = false) {
        m_offsetDirections[direction] = { .onTop = onTop,.offset = {x, y} };
    }
    void setShader(std::string_view name);
    void setCanDrawOnUI(const bool canDraw) { m_canDrawOnUI = canDraw; }
    bool canDrawOnUI() { return m_canDrawOnUI; }

    void move(const Position& fromPosition, const Position& toPosition);

    void attachEffect(const AttachedEffectPtr& e) { m_effects.emplace_back(e); }

    DrawOrder getDrawOrder() { return m_drawOrder; }
    void setDrawOrder(const DrawOrder drawOrder) { m_drawOrder = drawOrder; }
    const Light& getLight() const { return m_light; }
    void setLight(const Light& light) { m_light = light; }

    ThingType* getThingType() const;

private:
    int getCurrentAnimationPhase();

    struct DirControl
    {
        bool onTop{ false };
        Point offset;
    };

    int8_t m_loop{ -1 };

    uint8_t m_speed{ 100 };
    uint8_t m_opacity{ 100 };
    uint8_t m_lastAnimation{ 0 };
    DrawOrder m_drawOrder{ THIRD };

    uint16_t m_id{ 0 };
    uint16_t m_duration{ 0 };

    uint32_t m_frame{ 0 };

    bool m_hideOwner{ false };
    bool m_transform{ false };
    bool m_canDrawOnUI{ true };
    bool m_disableWalkAnimation{ false };
    bool m_permanent{ false };
    bool m_smooth = { true };
    bool m_followOwner{ false };

    Outfit m_outfitOwner;
    Light m_light;

    uint16_t m_thingId{ 0 };
    ThingCategory m_thingCategory{ ThingInvalidCategory };

    Size m_size;

    Timer m_animationTimer;

    Otc::Direction m_direction{ Otc::North };

    std::array<DirControl, Otc::Direction::NorthWest + 1> m_offsetDirections;
    std::string m_texturePath;

    Bounce m_bounce;
    Bounce m_pulse;
    Bounce m_fade;

    PainterShaderProgramPtr m_shader;
    TexturePtr m_texture;

    std::string m_name;

    std::vector<AttachedEffectPtr> m_effects;

    Point m_toPoint;

    friend class Thing;
    friend class Creature;
    friend class AttachedEffectManager;
};
