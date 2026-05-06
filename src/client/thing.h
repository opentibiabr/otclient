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

#include "attachableobject.h"
#include "staticdata.h"

 // @bindclass
#pragma pack(push,1) // disable memory alignment
class Thing : public AttachableObject
{
public:
    Thing();
    ~Thing() override;

    virtual void draw(const Point& /*dest*/, bool /*drawThings*/ = true, LightView* = nullptr) {}
    virtual void drawLight(const Point& /*dest*/, LightView*) {}

    LuaObjectPtr attachedObjectToLuaObject() override { return asLuaObject(); }
    bool isThing() override { return true; }

    virtual void setId(uint32_t /*id*/) {}
    virtual void setPosition(const Position& position, uint8_t stackPos = 0);

    virtual uint32_t getId() { return m_clientId; }
    uint16_t getClientId() const { return m_clientId; }

    virtual Position getPosition() { return m_position; }
    Position getServerPosition() { return m_position; }

    const TilePtr& getTile();
    ContainerPtr getParentContainer();

    int getStackPos();
    int getStackPriority();

    virtual bool isItem() const { return false; }
    virtual bool isEffect() const { return false; }
    virtual bool isMissile() const { return false; }
    virtual bool isCreature() const { return false; }

    virtual bool isNpc() const { return false; }
    virtual bool isMonster() const { return false; }
    virtual bool isPlayer() const { return false; }
    virtual bool isLocalPlayer() const { return false; }

    bool isCommon() { return !isGround() && !isGroundBorder() && !isOnTop() && !isCreature() && !isOnBottom(); }
    void canDraw(const bool canDraw) { m_canDraw = canDraw; }

    Animator* getAnimator() const;
    Animator* getIdleAnimator() const;

    virtual Point getDisplacement() const;
    virtual int getDisplacementX() const;
    virtual int getDisplacementY() const;
    virtual int getExactSize(int layer = 0, int xPattern = 0, int yPattern = 0, int zPattern = 0, int animationPhase = 0);

    virtual const Light& getLight() const;
    virtual bool hasLight() const;

    const MarketData& getMarketData();
    const std::vector<NPCData>& getNpcSaleData();
    int getMeanPrice();
    const Size& getSize() const;

    int getWidth() const;
    int getHeight() const;
    int getRealSize() const;
    int getLayers() const;
    int getNumPatternX() const;
    int getNumPatternY() const;
    int getNumPatternZ() const;
    int getAnimationPhases() const;
    int getGroundSpeed() const;
    int getMaxTextLength() const;
    int getMinimapColor() const;
    int getLensHelp() const;
    int getElevation() const;

    int getClothSlot();

    bool blockProjectile() const;

    virtual bool isContainer() const;

    bool isTopGround();
    bool isTopGroundBorder();
    bool isSingleGround();
    bool isSingleGroundBorder();
    bool isGround();
    bool isGroundBorder();
    bool isOnBottom();
    bool isOnTop();

    bool isMarketable();
    bool isStackable();
    bool isFluidContainer();
    bool isForceUse();
    bool isMultiUse();
    bool isWritable();
    bool isChargeable();
    bool isWritableOnce();
    bool isSplash();
    bool isNotWalkable();
    bool isNotMoveable();
    bool isMoveable();
    bool isNotPathable();
    bool isPickupable();
    bool isHangable();
    bool isHookSouth();
    bool isHookEast();
    bool isRotateable();
    bool isDontHide();
    bool isTranslucent();
    bool isLyingCorpse();
    bool isAnimateAlways();
    bool isFullGround();
    bool isIgnoreLook();
    bool isCloth();
    bool isUsable();
    bool isWrapable();
    bool isUnwrapable();
    bool isTopEffect();
    bool isPodium() const;
    bool isOpaque() const;
    bool isLoading() const;
    bool isSingleDimension() const;
    bool isTall(bool useRealSize = false) const;

    bool hasMiniMapColor() const;
    bool hasLensHelp() const;
    bool hasDisplacement() const;
    bool hasElevation() const;
    bool hasFloorChange() const;
    bool hasAction() const;
    bool hasWearOut() const;
    bool hasClockExpire() const;
    bool hasExpire() const;
    bool hasExpireStop() const;
    bool hasAnimationPhases() const;
    bool isDecoKit() const;
    bool isAmmo();
    bool isDualWield();

    PLAYER_ACTION getDefaultAction();
    uint16_t getClassification();
    uint32_t getCyclopediaType() const;
    uint32_t getProficiencyId() const;

    bool canDraw(const Color& color = Color::white) const;

    void setShader(std::string_view name);
    uint8_t getShaderId() const { return m_shaderId; }
    PainterShaderProgramPtr getShader() const;

    bool hasShader() const { return m_shaderId > 0; }

    virtual void onPositionChange(const Position& /*newPos*/, const Position& /*oldPos*/) {}
    virtual void onAppear() {}
    virtual void onDisappear() {};
    const Color& getMarkedColor();

    bool isMarked() { return m_markedColor != Color::white; }
    void setMarked(const Color& color) { if (m_markedColor != color) m_markedColor = color; }

    const Color& getHighlightColor();

    bool isHighlighted() { return m_highlightColor != Color::white; }
    void setHighlight(const Color& color) { if (m_highlightColor != color) m_highlightColor = color; }

    bool isHided() { return isOwnerHidden(); }

    uint8_t getPatternX()const { return m_numPatternX; }
    uint8_t getPatternY()const { return m_numPatternY; }
    uint8_t getPatternZ()const { return m_numPatternZ; }

    float getScaleFactor() {
        if (m_scale.value == 100)
            return 1.f;

        const auto scale = m_scale.value * (m_scale.speed == 0 ? 1.f : m_scale.timer.ticksElapsed() / static_cast<float>(m_scale.speed));
        return std::min<float>(scale, m_scale.value) / 100.f;
    }

    void setScaleFactor(float v, uint16_t ms = 0) {
        m_scale.value = v * 100;
        m_scale.speed = ms;
        m_scale.timer.restart();
    }

    bool canAnimate() { return m_animate; }
    void setAnimate(bool aniamte) { m_animate = aniamte; }

protected:
    virtual ThingType* getThingType() const = 0;

    void setAttachedEffectDirection(const Otc::Direction dir) const;

    Color m_markedColor{ Color::white };
    Color m_highlightColor{ Color::white };

    struct
    {
        Timer timer;
        uint16_t speed{ 0 };
        uint16_t value{ 100 };
    } m_scale;

    Position m_position;

    uint16_t m_clientId{ 0 };

    int8_t m_stackPos{ -1 };
    uint8_t m_numPatternX{ 0 };
    uint8_t m_numPatternY{ 0 };
    uint8_t m_numPatternZ{ 0 };

    // Shader
    uint8_t m_shaderId{ 0 };

private:
    void lua_setMarked(const std::string_view color) { setMarked(Color(color)); }
    void lua_setHighlight(const std::string_view color) { setHighlight(Color(color)); }

    bool m_canDraw{ true };
    bool m_animate{ true };

    friend class Client;
    friend class Tile;
};
#pragma pack(pop)
