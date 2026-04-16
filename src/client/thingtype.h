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

#include "declarations.h"
#ifdef FRAMEWORK_PROTOBUF
#include <appearances.pb.h>
#endif

#include "staticdata.h"
#include "const.h"
#include "framework/core/declarations.h"
#include "framework/core/timer.h"
#include "framework/graphics/declarations.h"
#include "framework/luaengine/luaobject.h"

#ifdef FRAMEWORK_PROTOBUF
using namespace otclient::protobuf;
#endif

class ThingType final : public LuaObject
{
public:
    struct SkillWheelGem
    {
        uint32_t gem_quality_id = 0;
        uint32_t vocation_id = 0;

        uint32_t getGemQualityId() { return gem_quality_id; }
        uint32_t getVocationId() { return vocation_id; }
    };
#ifdef FRAMEWORK_PROTOBUF
    void applyAppearanceFlags(const appearances::AppearanceFlags& flags);
    void unserializeAppearance(uint16_t clientId, ThingCategory category, const appearances::Appearance& appearance);
#endif
    void unserialize(uint16_t clientId, ThingCategory category, const FileStreamPtr& fin);
    void unserializeOtml(const OTMLNodePtr& node);

#ifdef FRAMEWORK_EDITOR
    void serialize(const FileStreamPtr& fin);
    void exportImage(const std::string& fileName);
#endif

    void draw(const Point& dest, int layer, int xPattern, int yPattern, int zPattern, int animationPhase, const Color& color, bool drawThings = true, LightView* lightView = nullptr);

    void drawWithFrameBuffer(const TexturePtr& texture, const Rect& screenRect, const Rect& textureRect, const Color& color);

    uint16_t getId() { return m_id; }
    ThingCategory getCategory() { return m_category; }
    bool isNull() const { return m_null; }
    bool hasAttr(const ThingAttr attr) { return (m_flags & thingAttrToThingFlagAttr(attr)); }

    int getWidth() { return m_size.width(); }
    int getHeight() { return m_size.height(); }
    int getExactSize(int layer = 0, int xPattern = 0, int yPattern = 0, int zPattern = 0, int animationPhase = 0);
    int getRealSize() { return m_realSize; }
    int getLayers() { return m_layers; }
    int getNumPatternX() { return m_numPatternX; }
    int getNumPatternY() { return m_numPatternY; }
    int getNumPatternZ() { return m_numPatternZ; }
    int getAnimationPhases() const;
    Animator* getAnimator() const { return m_animator; }
    Animator* getIdleAnimator() const { return m_idleAnimator; }

    const Size& getSize() { return m_size; }
    const Point& getDisplacement() { return m_displacement; }
    const Light& getLight() { return m_light; }
    const MarketData& getMarketData() { return m_market; }
    const std::vector<NPCData>& getNpcSaleData() { return m_npcData; }
    int getMeanPrice();

    int getDisplacementX() { return getDisplacement().x; }
    int getDisplacementY() { return getDisplacement().y; }
    int getElevation() { return m_elevation; }

    uint16_t getGroundSpeed() { return m_groundSpeed; }
    int getMaxTextLength() { return m_maxTextLength; }

    int getMinimapColor() { return m_minimapColor; }
    int getLensHelp() { return m_lensHelp; }
    int getClothSlot() { return m_clothSlot; }

    bool isTopGround() { return isGround() && m_size.dimension() == 4; }
    bool isTopGroundBorder() { return isGroundBorder() && m_size.dimension() == 4; }
    bool isSingleGround() { return isGround() && isSingleDimension(); }
    bool isSingleGroundBorder() { return isGroundBorder() && isSingleDimension(); }
    bool isTall(bool useRealSize = false);
    bool isSingleDimension() { return m_size.area() == 1; }

    bool isGround() { return (m_flags & ThingFlagAttrGround); }
    bool isGroundBorder() { return (m_flags & ThingFlagAttrGroundBorder); }
    bool isOnBottom() { return (m_flags & ThingFlagAttrOnBottom); }
    bool isOnTop() { return (m_flags & ThingFlagAttrOnTop); }
    bool isContainer() const { return (m_flags & ThingFlagAttrContainer); }
    bool isStackable() { return (m_flags & ThingFlagAttrStackable); }
    bool isForceUse() { return (m_flags & ThingFlagAttrForceUse); }
    bool isMultiUse() { return (m_flags & ThingFlagAttrMultiUse); }
    bool isWritable() { return (m_flags & ThingFlagAttrWritable); }
    bool isChargeable() { return (m_flags & ThingFlagAttrChargeable); }
    bool isWritableOnce() { return (m_flags & ThingFlagAttrWritableOnce); }
    bool isFluidContainer() { return (m_flags & ThingFlagAttrFluidContainer); }
    bool isSplash() { return (m_flags & ThingFlagAttrSplash); }
    bool isNotWalkable() { return (m_flags & ThingFlagAttrNotWalkable); }
    bool isNotMoveable() { return (m_flags & ThingFlagAttrNotMoveable); }
    bool blockProjectile() { return (m_flags & ThingFlagAttrBlockProjectile); }
    bool isNotPathable() { return (m_flags & ThingFlagAttrNotPathable); }
    bool isPickupable() { return (m_flags & ThingFlagAttrPickupable); }
    bool isHangable() { return (m_flags & ThingFlagAttrHangable); }
    bool isHookSouth() { return (m_flags & ThingFlagAttrHookSouth); }
    bool isHookEast() { return (m_flags & ThingFlagAttrHookEast); }
    bool isRotateable() { return (m_flags & ThingFlagAttrRotateable); }
    bool hasLight() { return (m_flags & ThingFlagAttrLight); }
    bool isDontHide() { return (m_flags & ThingFlagAttrDontHide); }
    bool isTranslucent() { return (m_flags & ThingFlagAttrTranslucent); }
    bool hasDisplacement() { return (m_flags & ThingFlagAttrDisplacement); }
    bool hasElevation() { return (m_flags & ThingFlagAttrElevation); }
    bool hasFloorChange() const { return (m_flags & ThingFlagAttrFloorChange); }
    bool isLyingCorpse() { return (m_flags & ThingFlagAttrLyingCorpse); }
    bool isAnimateAlways() { return (m_flags & ThingFlagAttrAnimateAlways); }
    bool hasMiniMapColor() { return (m_flags & ThingFlagAttrMinimapColor); }
    bool hasLensHelp() { return (m_flags & ThingFlagAttrLensHelp); }
    bool isFullGround() { return (m_flags & ThingFlagAttrFullGround); }
    bool isIgnoreLook() { return (m_flags & ThingFlagAttrLook); }
    bool isCloth() { return (m_flags & ThingFlagAttrCloth); }
    bool isMarketable() { return (m_flags & ThingFlagAttrMarket); }
    bool isUsable() { return (m_flags & ThingFlagAttrUsable); }
    bool isWrapable() { return (m_flags & ThingFlagAttrWrapable); }
    bool isUnwrapable() { return (m_flags & ThingFlagAttrUnwrapable); }
    bool hasWearOut() { return (m_flags & ThingFlagAttrWearOut); }
    bool hasClockExpire() { return (m_flags & ThingFlagAttrClockExpire); }
    bool hasExpire() { return (m_flags & ThingFlagAttrExpire); }
    bool hasExpireStop() { return (m_flags & ThingFlagAttrExpireStop); }
    bool isPodium() { return (m_flags & ThingFlagAttrPodium); }
    bool isTopEffect() { return (m_flags & ThingFlagAttrTopEffect); }
    bool hasAction() { return (m_flags & ThingFlagAttrDefaultAction); }
    bool isOpaque() { return m_opaque == 1; }

    uint32_t getSkillWheelGemQualityId() { return m_skillWheelGem.gem_quality_id; }
    uint32_t getSkillWheelGemVocationId() { return m_skillWheelGem.vocation_id; }

    bool isDecoKit() { return (m_flags & ThingFlagAttrDecoKit); }
    bool isLoading() const { return m_loading.load(std::memory_order_acquire); }
    bool isAmmo() { return (m_flags & ThingFlagAttrAmmo); }
    bool isDualWield() { return (m_flags & ThingFlagAttrDualWield); }
    bool hasSkillWheelGem() { return (m_flags & ThingFlagAttrSkillWheelGem); }
    SkillWheelGem getSkillWheelGem() { return m_skillWheelGem; }

    bool isItem() const { return m_category == ThingCategoryItem; }
    bool isEffect() const { return m_category == ThingCategoryEffect; }
    bool isMissile() const { return m_category == ThingCategoryMissile; }
    bool isCreature() const { return m_category == ThingCategoryCreature; }

    bool hasTexture() const { return !m_textureData.empty() && m_textureData[0].source != nullptr; }
    const Timer getLastTimeUsage() const { return m_lastTimeUsage; }

    void unload() {
        for (auto& data : m_textureData) {
            data.source = nullptr;
        }
    }

    PLAYER_ACTION getDefaultAction() { return m_defaultAction; }

    uint16_t getClassification() { return m_upgradeClassification; }
    const auto& getSprites() { return m_spritesIndex; }

    // additional
    float getOpacity() { return m_opacity; }
    void setPathable(bool var);
    int getExactHeight();
    const TexturePtr& getTexture(int animationPhase);

    std::string getName() { return m_name; }
    std::string getDescription() { return m_description; }

private:
    static ThingFlagAttr thingAttrToThingFlagAttr(ThingAttr attr);
    static Size getBestTextureDimension(int w, int h, int count);

    void loadTexture(int animationPhase);

    struct TextureData
    {
        struct Pos
        {
            Rect rects;
            Rect originRects;
            Point offsets;
        };

        TexturePtr source;
        std::vector<Pos> pos;
    };

    uint32_t getSpriteIndex(int w, int h, int l, int x, int y, int z, int a) const;
    uint32_t getTextureIndex(int l, int x, int y, int z) const;

    ThingCategory m_category{ ThingInvalidCategory };

    bool m_null{ true };
    int8_t m_opaque{ -1 };

    Size m_size;
    Point m_displacement;

    Animator* m_animator{ nullptr };
    Animator* m_idleAnimator{ nullptr };

    uint8_t m_animationPhases{ 0 };
    uint8_t m_realSize{ 0 };
    uint8_t m_numPatternX{ 0 };
    uint8_t m_numPatternY{ 0 };
    uint8_t m_numPatternZ{ 0 };
    uint8_t m_layers{ 0 };
    uint8_t m_exactHeight{ 0 };
    uint8_t m_minimapColor{ 0 };
    uint8_t m_clothSlot{ 0 };
    uint8_t m_lensHelp{ 0 };
    uint8_t m_elevation{ 0 };

    PLAYER_ACTION m_defaultAction{ 0 };

    uint16_t m_id{ 0 };
    uint16_t m_groundSpeed{ 0 };
    uint16_t m_maxTextLength{ 0 };
    uint16_t m_upgradeClassification{ 0 };

    uint64_t m_flags{ 0 };

    MarketData m_market;
    std::vector<NPCData> m_npcData;

    Light m_light;

    float m_opacity{ 1.f };

    std::string m_customImage;

    std::vector<uint32_t> m_spritesIndex;
    std::vector<TextureData> m_textureData;

    std::atomic_bool m_loading{ false };

    Timer m_lastTimeUsage;

    std::string m_name;
    std::string m_description;
    SkillWheelGem m_skillWheelGem;
};
