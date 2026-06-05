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

#include <framework/luaengine/luaobject.h>

#include "attachableobject.h"
#include "declarations.h"
#include "staticdata.h"
#include "statictext.h"

class Tile final : public AttachableObject
{
public:
    Tile(const Position& position);

    LuaObjectPtr attachedObjectToLuaObject() override { return asLuaObject(); }
    bool isTile() override { return true; }

    void onAddInMapView();
    void draw(const Point& dest, int flags, LightView* lightView = nullptr);
    void drawLight(const Point& dest, LightView* lightView);

    void clean();

    void addWalkingCreature(const CreaturePtr& creature);
    void removeWalkingCreature(const CreaturePtr& creature);

    void addThing(const ThingPtr& thing, int stackPos);
    bool removeThing(ThingPtr thing);
    ThingPtr getThing(int stackPos);
    EffectPtr getEffect(uint16_t id) const;
    bool hasThing(const ThingPtr& thing) { return std::ranges::find(m_things, thing) != m_things.end(); }
    int getThingStackPos(const ThingPtr& thing);
    ThingPtr getTopThing();

    ThingPtr getTopLookThing();
    ThingPtr getTopUseThing();
    CreaturePtr getTopCreature(bool checkAround = false);
    ThingPtr getTopMoveThing();
    ThingPtr getTopMultiUseThing();

    int getDrawElevation() const { return m_drawElevation; }
    const Position& getPosition() { return m_position; }
    const std::vector<CreaturePtr>& getWalkingCreatures() { return m_walkingCreatures; }
    const std::vector<ThingPtr>& getThings() { return m_things; }
    std::vector<CreaturePtr> getCreatures();

    std::vector<ItemPtr> getItems();
    ItemPtr getGround();
    int getGroundSpeed();
    uint8_t getMinimapColorByte();
    int getThingCount() { return m_things.size(); }

    bool isWalkable(bool ignoreCreatures = false);
    bool isClickable();
    bool isPathable() { return (m_thingTypeFlag & NOT_PATHABLE) == 0; }
    bool isFullGround() { return m_thingTypeFlag & FULL_GROUND; }
    bool isFullyOpaque();
    bool isSingleDimension() { return (m_thingTypeFlag & NOT_SINGLE_DIMENSION) == 0 && m_walkingCreatures.empty(); }
    bool isLookPossible() { return (m_thingTypeFlag & BLOCK_PROJECTTILE) == 0; }
    bool isEmpty() { return m_things.empty(); }
    bool isDrawable() { return !isEmpty() || !m_walkingCreatures.empty() || hasEffect() || hasAttachedEffects(); }
    bool isCovered(int8_t firstFloor);
    bool isCompletelyCovered(uint8_t firstFloor, bool resetCache);
    bool isLoading() const;

    bool hasBlockingCreature() const;

    bool hasEffect() const { return m_effects && !m_effects->empty(); }
    bool hasGround();
    bool hasTopGround(const bool ignoreBorder = false);

    bool hasCreatures() const { return (m_thingTypeFlag & HAS_CREATURE) != 0; }
    bool hasCreatures() { return static_cast<const Tile&>(*this).hasCreatures(); }

    void appendSpectators(std::vector<CreaturePtr>& out) const;

    bool hasTopItem() const { return m_thingTypeFlag & HAS_TOP_ITEM; }
    bool hasCommonItem() const { return m_thingTypeFlag & HAS_COMMON_ITEM; }
    bool hasBottomItem() const { return m_thingTypeFlag & HAS_BOTTOM_ITEM; }

    bool hasIgnoreLook() { return m_thingTypeFlag & IGNORE_LOOK; }
    bool hasDisplacement() const { return m_thingTypeFlag & HAS_DISPLACEMENT; }
    bool hasLight() const { return m_thingTypeFlag & HAS_LIGHT; }
    bool hasTallThings() const { return m_thingTypeFlag & HAS_TALL_THINGS; }
    bool hasWideThings() const { return m_thingTypeFlag & HAS_WIDE_THINGS; }
    bool hasTallThings2() const { return m_thingTypeFlag & HAS_TALL_THINGS_2; }
    bool hasWideThings2() const { return m_thingTypeFlag & HAS_WIDE_THINGS_2; }
    bool hasWall() const { return m_thingTypeFlag & HAS_WALL; }

    bool mustHookSouth() const { return m_thingTypeFlag & HAS_HOOK_SOUTH; }
    bool mustHookEast() const { return m_thingTypeFlag & HAS_HOOK_EAST; }

    bool limitsFloorsView(bool isFreeView = false);

    bool canShade() { return isFullyOpaque() || hasTopGround() || isFullGround(); }
    bool canRender(uint32_t& flags, const Position& cameraPosition, AwareRange viewPort);
    bool canErase()
    {
        return !isDrawable() && m_minimapColor == 0
#ifdef FRAMEWORK_EDITOR
            && m_flags == 0
#endif
            ;
    }

    bool hasElevation(const int elevation = 1) { return m_elevation >= elevation; }
    bool hasFloorChange() const;

#ifdef FRAMEWORK_EDITOR
    void overwriteMinimapColor(uint8_t color) { m_minimapColor = color; }

    void remFlag(uint32_t flag) { m_flags &= ~flag; }
    void setFlag(uint32_t flag) { m_flags |= flag; }
    void setFlags(uint32_t flags) { m_flags = flags; }
    bool hasFlag(uint32_t flag) { return (m_flags & flag) == flag; }
    uint32_t getFlags() { return m_flags; }

    void setHouseId(uint32_t hid) { m_houseId = hid; }
    uint32_t getHouseId() { return m_houseId; }
    bool isHouseTile() { return m_houseId != 0 && hasFlag(TILESTATE_HOUSE); }
#endif

    void select(TileSelectType selectType = TileSelectType::NO_FILTERED);
    void unselect();
    bool isSelected() { return m_selectType != TileSelectType::NONE; }

    TilePtr asTile() { return static_self_cast<Tile>(); }

    bool checkForDetachableThing(TileSelectType selectType = TileSelectType::FILTERED);

    void drawTexts(Point dest);
    void setText(const std::string& text, Color color);
    std::string getText();
    void setTimer(int time, Color color);
    int getTimer();
    void setFill(Color color);
    void resetFill() { m_fill = Color::alpha; }
    bool canShoot(int distance);

private:
    void updateThingStackPos();
    void drawTop(const Point& dest, int flags, bool forceDraw, uint8_t drawElevation);
    void drawCreature(const Point& dest, int flags, bool forceDraw, uint8_t drawElevation, LightView* lightView = nullptr);

    void updateCreatureRangeForInsert(int16_t stackPos, const ThingPtr& thing);
    void rebuildCreatureRange();

    void setThingFlag(const ThingPtr& thing);

    void recalculateThingFlag()
    {
        m_thingTypeFlag = 0;
        rebuildCreatureRange();
        for (const auto& thing : m_things)
            setThingFlag(thing);
    }

    bool hasThingWithElevation() { return hasElevation() && m_thingTypeFlag & HAS_THING_WITH_ELEVATION; }
    void markHighlightedThing(const Color& color);

    std::vector<CreaturePtr> m_walkingCreatures;
    std::vector<ThingPtr> m_things;

    std::unique_ptr<std::vector<EffectPtr>> m_effects;
    std::unique_ptr<std::vector<TilePtr>> m_tilesRedraw;

    std::unique_ptr<StaticText> m_timerText;
    std::unique_ptr<StaticText> m_text;
    Color m_fill = Color::alpha;
    ticks_t m_timer = 0;

    uint32_t m_isCompletelyCovered{ 0 };
    uint32_t m_isCovered{ 0 };
    uint32_t m_thingTypeFlag{ 0 };

#ifdef FRAMEWORK_EDITOR
    uint32_t m_houseId{ 0 };
    uint32_t m_flags{ 0 };
#endif

    Position m_position;
    Point m_lastDrawDest;

    uint8_t m_drawElevation{ 0 };
    uint8_t m_minimapColor{ 0 };
    uint8_t m_elevation{ 0 };

    int16_t m_firstCreatureIndex{ -1 };
    int16_t m_lastCreatureIndex{ -1 };

    int8_t m_highlightThingStackPos = -1;

    TileSelectType m_selectType{ TileSelectType::NONE };

    bool m_drawTopAndCreature{ true };
};
