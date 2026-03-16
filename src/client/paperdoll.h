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

#include "outfit.h"
#include "declarations.h"
#include <framework/core/timer.h>
#include <framework/luaengine/luaobject.h>
#include <framework/graphics/declarations.h>

class Paperdoll : public LuaObject
{
public:
    void draw(const Point& /*dest*/, uint16_t animationPhase, bool mount, bool isOnTop, bool drawThings, const Color& color, LightView* = nullptr);
    void drawLight(const Point& /*dest*/, bool mount, LightView*);

    uint16_t getId() { return m_id; }

    PaperdollPtr clone();

    float getSpeed() { return m_speed / 100.f; }
    void setSpeed(float speed) { m_speed = speed * 100u; }

    float getOpacity() { return m_opacity / 100.f; }
    void setOpacity(float opacity) { m_opacity = opacity * 100u; }

    float getSizeFactor() { return m_sizeFactor; }
    void setSizeFactor(const float s) { m_sizeFactor = s; }

    bool getOnlyAddon() { return m_onlyAddon; }
    void setOnlyAddon(bool s) { m_onlyAddon = s; }

    uint32_t getAddons() { return m_addons; }
    void setAddons(uint32_t addons) { m_addons = addons; }

    uint8_t getPriority() { return m_priority; }
    void setPriority(uint8_t priority) { m_priority = priority; }

    uint32_t hasAddon(uint32_t addon) { return (m_addons & addon) == addon; }
    void setAddon(uint32_t addon) { m_addons |= addon; }
    void removeAddon(uint32_t addon) { m_addons &= ~addon; }

    void setOnTop(bool onTop);
    void setOffset(int16_t x, int16_t y);
    void setOnTopByDir(Otc::Direction direction, bool onTop);

    void setMountOffset(int16_t x, int16_t y);
    void setMountOnTopByDir(Otc::Direction direction, bool onTop);

    void setUseMountPattern(bool b) { m_useMountPattern = b; }
    bool isUsingMountPattern() { return m_useMountPattern; }

    void setShowOnMount(bool b) { m_showOnMount = b; }
    bool isShowingOnMount() { return m_showOnMount; }

    void setDirOffset(Otc::Direction direction, int8_t x, int8_t y, bool onTop = true) { m_offsetDirections[0][direction] = { onTop, {x, y} }; }
    void setMountDirOffset(Otc::Direction direction, int8_t x, int8_t y, bool onTop = true) { m_offsetDirections[1][direction] = { onTop, {x, y} }; }

    void setShader(const std::string_view name);
    void setCanDrawOnUI(bool canDraw) { m_canDrawOnUI = canDraw; }
    bool canDrawOnUI() { return m_canDrawOnUI; }

    void setColor(uint8_t c) {
        m_head = c;
        m_body = c;
        m_legs = c;
        m_feet = c;
    }

    void setHeadColor(uint8_t c) { m_head = c; }
    void setBodyColor(uint8_t c) { m_body = c; }
    void setLegsColor(uint8_t c) { m_legs = c; }
    void setFeetColor(uint8_t c) { m_feet = c; }

    uint8_t getHeadColor() { return m_head; }
    uint8_t getBodyColor() { return m_body; }
    uint8_t getLegsColor() { return m_legs; }
    uint8_t getFeetColor() { return m_feet; }

    void setColorByOutfit(const Outfit& outfit) {
        m_head = outfit.getHead();
        m_body = outfit.getBody();
        m_legs = outfit.getLegs();
        m_feet = outfit.getFeet();
    }

    void reset();

private:
    int getCurrentAnimationPhase();

    struct DirControl
    {
        bool onTop{ true };
        Point offset;
    };

    uint8_t m_priority{ 1 };
    uint8_t m_head{ 0 }, m_body{ 0 }, m_legs{ 0 }, m_feet{ 0 };

    uint8_t m_speed{ 100 };
    uint8_t m_opacity{ 100 };
    uint16_t m_id{ 0 };
    uint16_t m_thingId{ 0 };
    uint32_t m_addons{ 0 };

    Timer m_timer;

    bool m_onlyAddon{ false };
    bool m_canDrawOnUI{ true };
    bool m_useMountPattern{ false };
    bool m_showOnMount{ true };

    ThingType* m_thingType{ nullptr };

    float m_sizeFactor{ 1.0 };
    Timer m_animationTimer;

    Otc::Direction m_direction{ Otc::North };

    std::array<DirControl, Otc::Direction::West + 1> m_offsetDirections[2];

    PainterShaderProgramPtr m_shader;

    friend class Creature;
    friend class PaperdollManager;
};
