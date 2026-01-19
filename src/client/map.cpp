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

#include "map.h"

#include "animatedtext.h"
#include "creatures.h"
#include "game.h"
#include "gameconfig.h"
#include "item.h"
#include "localplayer.h"
#include "mapview.h"
#include "minimap.h"
#include "missile.h"
#include "thing.h"
#include "tile.h"

#include <framework/core/asyncdispatcher.h>
#include <framework/core/eventdispatcher.h>
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/painter.h"
#include <framework/ui/uiwidget.h>

namespace
{
    void cleanNewSpectators(std::vector<CreaturePtr>& creatures, std::unordered_set<uint32_t>& seenIds, const std::size_t startIndex)
    {
        auto it = creatures.begin() + startIndex;
        while (it != creatures.end()) {
            if (const auto& creature = *it; !creature || !seenIds.insert(creature->getId()).second) {
                it = creatures.erase(it);
                continue;
            }
            ++it;
        }
    }
}

#ifdef FRAMEWORK_EDITOR
#include "houses.h"
#include "towns.h"
#endif
#include <framework/platform/platformwindow.h>
#include <framework/core/graphicalapplication.h>

const static TilePtr m_nulltile;

Map g_map;

void Map::init()
{
    g_window.addKeyListener([this](const InputEvent& inputEvent) {
        notificateKeyRelease(inputEvent);
    });

    m_floors.resize(g_gameConfig.getMapMaxZ() + 1);

    resetAwareRange();

#ifdef FRAMEWORK_EDITOR
    m_animationFlags |= Animation_Show;
#endif
}

void Map::terminate()
{
    clean();
}

void Map::addMapView(const MapViewPtr& mapView) { m_mapViews.push_back(mapView); }

void Map::removeMapView(const MapViewPtr& mapView)
{
    const auto it = std::ranges::find(m_mapViews, mapView);
    if (it != m_mapViews.end())
        m_mapViews.erase(it);
}

void Map::notificateKeyRelease(const InputEvent& inputEvent) const
{
    for (const auto& mapView : m_mapViews) {
        mapView->onKeyRelease(inputEvent);
    }
}

void Map::notificateCameraMove(const Point& offset) const
{
    g_drawPool.repaint(DrawPoolType::FOREGROUND_MAP);
    g_drawPool.repaint(DrawPoolType::CREATURE_INFORMATION);

    for (const auto& mapView : m_mapViews) {
        mapView->onCameraMove(offset);
    }
}

void Map::notificateTileUpdate(const Position& pos, const ThingPtr& thing, const Otc::Operation operation)
{
    if (!pos.isMapPosition())
        return;

    for (const auto& mapView : m_mapViews) {
        mapView->onTileUpdate(pos, thing, operation);
    }

    if (thing && thing->isItem()) {
        g_minimap.updateTile(pos, getTile(pos));
    }
}

void Map::clean()
{
    cleanDynamicThings();

    for (auto i = -1; ++i <= g_gameConfig.getMapMaxZ();)
        m_floors[i].tileBlocks.clear();

#ifdef FRAMEWORK_EDITOR
    m_waypoints.clear();
    g_towns.clear();
    g_houses.clear();
    g_creatures.clearSpawns();
#endif
}

void Map::cleanDynamicThings()
{
    for (const auto& mapview : m_mapViews)
        mapview->followCreature(nullptr);

    for (const auto& [uid, creature] : m_knownCreatures) {
        creature->setWidgetInformation(nullptr);
        removeThing(creature);
    }

    m_knownCreatures.clear();

    std::vector<UIWidgetPtr> widgets;
    widgets.reserve(m_attachedObjectWidgetMap.size());

    // we pass the widget to a vector, as destroy() removes the element in m_attachedObjectWidgetMap
    // and thus ends up having a conflict when removing the widget while it is reading.
    for (const auto& [widget, object] : m_attachedObjectWidgetMap)
        widgets.emplace_back(widget);

    for (const auto& widget : widgets)
        widget->destroy();

    for (auto i = -1; ++i <= g_gameConfig.getMapMaxZ();)
        m_floors[i].missiles.clear();

    for (auto& floor : m_floors) {
        floor.missiles.clear();
        floor.tileBlocks.clear();
    }

    cleanTexts();

    g_lua.collectGarbage();
}

void Map::addThing(const ThingPtr& thing, const Position& pos, const int16_t stackPos)
{
    if (!thing)
        return;

    if (thing->isItem() && thing->getId() == 0)
        return;

    if (thing->isMissile()) {
        m_floors[pos.z].missiles.emplace_back(thing->static_self_cast<Missile>());
        thing->setPosition(pos);
        thing->onAppear();
        return;
    }

    if (const auto& tile = getOrCreateTile(pos)) {
        if (m_floatingEffect || !thing->isEffect() || tile->getGround()) {
            tile->addThing(thing, stackPos);
            notificateTileUpdate(pos, thing, Otc::OPERATION_ADD);
        }
    }
}

void Map::addStaticText(const StaticTextPtr& txt, const Position& pos) {
    if (!g_app.isDrawingTexts())
        return;

    g_textDispatcher.addEvent([=, this] {
        for (const auto& other : m_staticTexts) {
            // try to combine messages
            if (other->getPosition() == pos && other->addMessage(txt->getName(), txt->getMessageMode(), txt->getFirstMessage())) {
                return;
            }
        }

        txt->setPosition(pos);
        m_staticTexts.emplace_back(txt);
    });
}

void Map::addAnimatedText(const AnimatedTextPtr& txt, const Position& pos) {
    if (!g_app.isDrawingTexts())
        return;

    g_textDispatcher.addEvent([=, this] {
        // this code will stack animated texts of the same color
        AnimatedTextPtr prevAnimatedText;

        bool merged = false;
        for (const auto& other : m_animatedTexts) {
            if (other->getPosition() == pos) {
                prevAnimatedText = other;
                if (other->merge(txt)) {
                    merged = true;
                    break;
                }
            }
        }

        if (!merged) {
            if (prevAnimatedText) {
                Point offset = prevAnimatedText->getOffset();
                if (const float t = prevAnimatedText->getTimer().ticksElapsed();
                    t < g_gameConfig.getAnimatedTextDuration() / 4.0) { // didnt move 12 pixels
                    const int32_t y = 12 - 48 * t / static_cast<float>(g_gameConfig.getAnimatedTextDuration());
                    offset += Point(0, y);
                }
                offset.y = std::min<int32_t>(offset.y, 12);
                txt->setOffset(offset);
            }
            m_animatedTexts.emplace_back(txt);
        }

        txt->setPosition(pos);
        txt->onAppear();
    });
}

ThingPtr Map::getThing(const Position& pos, const int16_t stackPos)
{
    if (const auto& tile = getTile(pos))
        return tile->getThing(stackPos);

    return nullptr;
}

bool Map::removeThing(const ThingPtr& thing)
{
    if (!thing)
        return false;

    if (thing->isMissile()) {
        auto& missiles = m_floors[thing->getServerPosition().z].missiles;
        const auto it = std::ranges::find(missiles, thing->static_self_cast<Missile>());
        if (it == missiles.end())
            return false;

        missiles.erase(it);
        return true;
    }

    if (const auto& tile = thing->getTile()) {
        if (tile->removeThing(thing)) {
            notificateTileUpdate(thing->getServerPosition(), thing, Otc::OPERATION_REMOVE);
            return true;
        }
    }

    return false;
}

bool Map::removeThingByPos(const Position& pos, const int16_t stackPos)
{
    if (const auto& tile = getTile(pos))
        return removeThing(tile->getThing(stackPos));

    return false;
}

bool Map::removeStaticText(const StaticTextPtr& txt) {
    const auto it = std::ranges::find(m_staticTexts, txt);
    if (it == m_staticTexts.end())
        return false;

    m_staticTexts.erase(it);
    return true;
}

bool Map::removeAnimatedText(const AnimatedTextPtr& txt) {
    const auto it = std::ranges::find(m_animatedTexts, txt);
    if (it == m_animatedTexts.end())
        return false;

    m_animatedTexts.erase(it);
    return true;
}

void Map::colorizeThing(const ThingPtr& thing, const Color& color)
{
    if (!thing)
        return;

    if (thing->isItem())
        thing->static_self_cast<Item>()->setColor(color);
    else if (thing->isCreature()) {
        const auto& tile = thing->getTile();
        assert(tile);

        const auto& topThing = tile->getTopThing();
        assert(topThing);

        topThing->static_self_cast<Item>()->setColor(color);
    }
}

void Map::removeThingColor(const ThingPtr& thing)
{
    if (!thing)
        return;

    if (thing->isItem())
        thing->static_self_cast<Item>()->setColor(Color::alpha);
    else if (thing->isCreature()) {
        const auto& tile = thing->getTile();
        assert(tile);

        const auto& topThing = tile->getTopThing();
        assert(topThing);

        topThing->static_self_cast<Item>()->setColor(Color::alpha);
    }
}

StaticTextPtr Map::getStaticText(const Position& pos) const
{
    for (const auto& staticText : m_staticTexts) {
        // try to combine messages
        if (staticText->getPosition() == pos)
            return staticText;
    }

    return nullptr;
}

const TilePtr& Map::createTile(const Position& pos) { return pos.isMapPosition() ? m_floors[pos.z].tileBlocks[getBlockIndex(pos)].create(pos) : m_nulltile; }
const TilePtr& Map::getOrCreateTile(const Position& pos) { return pos.isMapPosition() ? m_floors[pos.z].tileBlocks[getBlockIndex(pos)].getOrCreate(pos) : m_nulltile; }

template <typename... Items>
const TilePtr& Map::createTileEx(const Position& pos, const Items&... items)
{
    if (!pos.isValid())
        return m_nulltile;

    const auto& tile = getOrCreateTile(pos);
    for (auto vec = { items... }; auto it : vec)
        addThing(it, pos);

    return tile;
}

const TilePtr& Map::getTile(const Position& pos)
{
    if (!pos.isMapPosition())
        return m_nulltile;

    auto& tileBlocks = m_floors[pos.z].tileBlocks;

    const auto it = tileBlocks.find(getBlockIndex(pos));
    if (it != tileBlocks.end())
        return it->second.get(pos);

    return m_nulltile;
}

TileList Map::getTiles(const int8_t floor/* = -1*/)
{
    TileList tiles;
    if (floor > g_gameConfig.getMapMaxZ())
        return tiles;

    if (floor < 0) {
        // Search all floors
        for (auto z = -1; ++z <= g_gameConfig.getMapMaxZ();) {
            for (const auto& [key, block] : m_floors[z].tileBlocks) {
                for (const auto& tile : block.getTiles()) {
                    if (tile != nullptr)
                        tiles.emplace_back(tile);
                }
            }
        }
    } else {
        for (const auto& [key, block] : m_floors[floor].tileBlocks) {
            for (const auto& tile : block.getTiles()) {
                if (tile != nullptr)
                    tiles.emplace_back(tile);
            }
        }
    }

    return tiles;
}

void Map::cleanTile(const Position& pos)
{
    if (!pos.isMapPosition())
        return;

    const auto it = m_floors[pos.z].tileBlocks.find(getBlockIndex(pos));
    if (it != m_floors[pos.z].tileBlocks.end()) {
        auto& block = it->second;
        if (const auto& tile = block.get(pos)) {
            tile->clean();
            if (tile->canErase())
                block.remove(pos);

            notificateTileUpdate(pos, nullptr, Otc::OPERATION_CLEAN);
        } else {
            g_minimap.updateTile(pos, nullptr);
        }
    }

    g_textDispatcher.addEvent([=, this] {
        for (auto itt = m_staticTexts.begin(); itt != m_staticTexts.end();) {
            const auto& staticText = *itt;
            if (staticText->getPosition() == pos && staticText->getMessageMode() == Otc::MessageNone)
                itt = m_staticTexts.erase(itt);
            else
                ++itt;
        }
    });
}

#ifdef FRAMEWORK_EDITOR
void Map::setShowZone(tileflags_t zone, bool show)
{
    if (show)
        m_zoneFlags |= static_cast<uint32_t>(zone);
    else
        m_zoneFlags &= ~static_cast<uint32_t>(zone);
}

void Map::setShowZones(bool show)
{
    if (!show)
        m_zoneFlags = 0;
    else if (m_zoneFlags == 0)
        m_zoneFlags = TILESTATE_HOUSE | TILESTATE_PROTECTIONZONE;
}

void Map::setZoneColor(tileflags_t zone, const Color& color)
{
    if ((m_zoneFlags & zone) == zone)
        m_zoneColors[zone] = color;
}

Color Map::getZoneColor(tileflags_t flag)
{
    const auto it = m_zoneColors.find(flag);
    if (it == m_zoneColors.end())
        return Color::alpha;

    return it->second;
}

void Map::setForceShowAnimations(bool force)
{
    if (!force) {
        m_animationFlags &= ~Animation_Force;
        return;
    }

    if (!(m_animationFlags & Animation_Force))
        m_animationFlags |= Animation_Force;
}

void Map::setShowAnimations(bool show)
{
    if (show) {
        if (!(m_animationFlags & Animation_Show))
            m_animationFlags |= Animation_Show;
    } else
        m_animationFlags &= ~Animation_Show;
}
#endif

void Map::beginGhostMode(const float opacity) { g_painter->setOpacity(opacity); }
void Map::endGhostMode() { g_painter->resetOpacity(); }

stdext::map<Position, ItemPtr, Position::Hasher> Map::findItemsById(const uint16_t clientId, const uint32_t  max)
{
    stdext::map<Position, ItemPtr, Position::Hasher> ret;
    uint32_t  count = 0;
    for (uint8_t z = 0; z <= g_gameConfig.getMapMaxZ(); ++z) {
        for (const auto& [uid, block] : m_floors[z].tileBlocks) {
            for (const auto& tile : block.getTiles()) {
                if (unlikely(!tile || tile->isEmpty()))
                    continue;
                for (const auto& item : tile->getItems()) {
                    if (item->getId() == clientId) {
                        ret.emplace(tile->getPosition(), item);
                        if (++count >= max)
                            break;
                    }
                }
            }
        }
    }

    return ret;
}

CreaturePtr Map::getCreatureById(const uint32_t  id)
{
    const auto it = m_knownCreatures.find(id);
    return it != m_knownCreatures.end() ? it->second : nullptr;
}

void Map::addCreature(const CreaturePtr& creature) { m_knownCreatures[creature->getId()] = creature; }
void Map::removeCreatureById(const uint32_t  id)
{
    if (id == 0)
        return;

    const auto it = m_knownCreatures.find(id);
    if (it != m_knownCreatures.end())
        m_knownCreatures.erase(it);
}

void Map::removeUnawareThings()
{
    // remove creatures from tiles that we are not aware of anymore
    for (const auto& [uid, creature] : m_knownCreatures) {
        if (!isAwareOfPosition(creature->getPosition()))
            removeThing(creature);
    }

    g_textDispatcher.addEvent([=, this] {
        // remove static texts from tiles that we are not aware anymore
        for (auto it = m_staticTexts.begin(); it != m_staticTexts.end();) {
            const auto& staticText = *it;
            if (staticText->getMessageMode() == Otc::MessageNone && !isAwareOfPosition(staticText->getPosition()))
                it = m_staticTexts.erase(it);
            else
                ++it;
        }
    });

    if (!g_game.getFeature(Otc::GameKeepUnawareTiles)) {
        const auto& customAwareRange = g_game.getFeature(Otc::GameMapCache) ? AwareRange{
            .left = static_cast<uint8_t>(m_awareRange.left * 4),
            .top = static_cast<uint8_t>(m_awareRange.top * 4),
            .right = static_cast<uint8_t>(m_awareRange.right * 4),
            .bottom = static_cast<uint8_t>(m_awareRange.bottom * 4),
        } : m_awareRange;

        // remove tiles that we are not aware anymore
        for (auto z = -1; ++z <= g_gameConfig.getMapMaxZ();) {
            auto& tileBlocks = m_floors[z].tileBlocks;
            for (auto it = tileBlocks.begin(); it != tileBlocks.end();) {
                auto& block = it->second;
                bool blockEmpty = true;
                for (const auto& tile : block.getTiles()) {
                    if (!tile) continue;

                    const auto& pos = tile->getPosition();
                    if (isAwareOfPosition(pos, customAwareRange)) {
                        blockEmpty = false;
                        continue;
                    }

                    if (!tile->isEmpty())
                        tile->clean();

                    block.remove(pos);
                    notificateTileUpdate(pos, nullptr, Otc::OPERATION_CLEAN);
                }

                if (blockEmpty)
                    it = tileBlocks.erase(it);
                else
                    ++it;
            }
        }
    }
}

void Map::setCentralPosition(const Position& centralPosition)
{
    if (m_centralPosition == centralPosition)
        return;

    m_centralPosition = centralPosition;

    removeUnawareThings();

    // this fixes local player position when the local player is removed from the map,
    // the local player is removed from the map when there are too many creatures on his tile,
    // so there is no enough stackpos to the server send him
    g_dispatcher.addEvent([this] {
        const auto& localPlayer = g_game.getLocalPlayer();
        if (!localPlayer || localPlayer->getPosition() == m_centralPosition)
            return;

        if (const auto& tile = localPlayer->getTile()) {
            if (tile->hasThing(localPlayer))
                return;
        }

        const auto& oldPos = localPlayer->getPosition();
        const auto& pos = m_centralPosition;
        if (oldPos != pos) {
            if (!localPlayer->isRemoved())
                localPlayer->onDisappear();
            localPlayer->setPosition(pos);
            localPlayer->onAppear();
            g_logger.debug("forced player position update");
        }
    });

    for (const auto& mapView : m_mapViews)
        mapView->onMapCenterChange(centralPosition, mapView->m_lastCameraPosition);
}

void Map::setLight(const Light& light)
{
    m_light = light;
    for (const auto& mapView : m_mapViews)
        mapView->onGlobalLightChange(m_light);
}

std::vector<CreaturePtr> Map::getSpectatorsInRangeEx(const Position& centerPos, const bool multiFloor, const int32_t minXRange, const int32_t maxXRange, const int32_t minYRange, const int32_t maxYRange)
{
    std::vector<CreaturePtr> creatures;
    creatures.reserve(m_knownCreatures.size());
    std::unordered_set<uint32_t> seenIds;
    seenIds.reserve(m_knownCreatures.size());

    uint8_t minZRange = 0;
    uint8_t maxZRange = 0;

    if (multiFloor) {
        minZRange = centerPos.z - getFirstAwareFloor();
        maxZRange = getLastAwareFloor() - centerPos.z;
    }

    const int startZ = centerPos.z - minZRange;
    const int endZ = centerPos.z + maxZRange;
    const int startY = centerPos.y - minYRange;
    const int endY = centerPos.y + maxYRange;
    const int startX = centerPos.x - minXRange;
    const int endX = centerPos.x + maxXRange;

    const auto appendSpectatorsFromLayer = [&](const int z) {
        for (int y = startY; y <= endY; ++y) {
            for (int x = startX; x <= endX; ++x) {
                const auto tile = getTile(Position(x, y, z));
                if (!tile || !tile->hasCreatures()) {
                    continue;
                }

                const auto sizeBeforeAppend = creatures.size();
                tile->appendSpectators(creatures);
                cleanNewSpectators(creatures, seenIds, sizeBeforeAppend);
            }
        }
    };

    for (int z = startZ; z <= endZ; ++z) {
        appendSpectatorsFromLayer(z);
    }
    return creatures;
}

bool Map::isLookPossible(const Position& pos)
{
    const auto& tile = getTile(pos);
    return tile && tile->isLookPossible();
}

bool Map::isCovered(const Position& pos, bool& isLoading, const uint8_t firstFloor)
{
    // check for tiles on top of the postion
    Position tilePos = pos;
    while (tilePos.coveredUp() && tilePos.z >= firstFloor) {
        // the below tile is covered when the above tile has a full opaque
        if (const auto& tile = getTile(tilePos)) {
            if (tile->isLoading()) {
                isLoading = true;
                return false;
            }

            if (tile->isFullyOpaque())
                return true;
        }

        if (const auto& tile = getTile(tilePos.translated(1, 1))) {
            if (tile->hasTopGround())
                return true;
        }
    }

    return false;
}

bool Map::isCompletelyCovered(const Position& pos, bool& isLoading, const uint8_t firstFloor)
{
    const auto& checkTile = getTile(pos);
    Position tilePos = pos;
    while (tilePos.coveredUp() && tilePos.z >= firstFloor) {
        bool covered = true;
        bool done = false;

        // Check is Top Ground
        for (auto x = -1; ++x < 2 && !done;) {
            for (auto y = -1; ++y < 2 && !done;) {
                const auto& tile = getTile(tilePos.translated(x, x));
                if (!tile || !tile->hasTopGround()) {
                    covered = false;
                    done = true;
                } else if (x == 1 && y == 1 && (!checkTile || checkTile->isSingleDimension())) {
                    done = true;
                }
            }
        }

        if (covered)
            return true;

        covered = true;
        done = false;

        // check in 2x2 range tiles that has no transparent pixels
        for (auto x = -1; ++x < 2 && !done;) {
            for (auto y = -1; ++y < 2 && !done;) {
                const auto& tile = getTile(tilePos.translated(-x, -y));
                if (tile && tile->isLoading()) {
                    isLoading = true;
                    return false;
                }

                if (!tile || !tile->isFullyOpaque()) {
                    covered = false;
                    done = true;
                } else if (x == 0 && y == 0 && (!checkTile || checkTile->isSingleDimension())) {
                    done = true;
                }
            }
        }

        if (covered)
            return true;
    }
    return false;
}

bool Map::isAwareOfPosition(const Position& pos, const AwareRange& awareRange) const
{
    if ((pos.z < getFirstAwareFloor() || pos.z > getLastAwareFloor()) && awareRange == m_awareRange)
        return false;

    Position groundedPos = pos;
    while (groundedPos.z != m_centralPosition.z) {
        if (groundedPos.z > m_centralPosition.z) {
            if (groundedPos.x == UINT16_MAX || groundedPos.y == UINT16_MAX) // When pos == 65535,65535,15 we cant go up to 65536,65536,14
                break;
            groundedPos.coveredUp();
        } else {
            if (groundedPos.x == 0 || groundedPos.y == 0) // When pos == 0,0,0 we cant go down to -1,-1,1
                break;
            groundedPos.coveredDown();
        }
    }

    return m_centralPosition.isInRange(groundedPos, awareRange.left,
                                       awareRange.right,
                                       awareRange.top,
                                       awareRange.bottom);
}

void Map::setAwareRange(const AwareRange& range)
{
    m_awareRange = range;
    removeUnawareThings();
}

void Map::resetAwareRange() {
    setAwareRange({
        .left = static_cast<uint8_t>(g_gameConfig.getMapViewPort().width()) ,
        .top = static_cast<uint8_t>(g_gameConfig.getMapViewPort().height()),
        .right = static_cast<uint8_t>(g_gameConfig.getMapViewPort().width() + 1),
        .bottom = static_cast<uint8_t>(g_gameConfig.getMapViewPort().height() + 1)
    });
}

uint8_t Map::getFirstAwareFloor() const
{
    if (m_centralPosition.z <= g_gameConfig.getMapSeaFloor())
        return 0;

    return m_centralPosition.z - g_gameConfig.getMapAwareUndergroundFloorRange();
}

uint8_t Map::getLastAwareFloor() const
{
    if (m_centralPosition.z <= g_gameConfig.getMapSeaFloor())
        return g_gameConfig.getMapSeaFloor();

    return std::min<uint8_t >(m_centralPosition.z + g_gameConfig.getMapAwareUndergroundFloorRange(), g_gameConfig.getMapMaxZ());
}

std::tuple<std::vector<Otc::Direction>, Otc::PathFindResult> Map::findPath(const Position& startPos, const Position& goalPos, const int maxComplexity, const int flags)
{
    // pathfinding using dijkstra search algorithm

    struct SNode
    {
        SNode(const Position& pos) :
            pos(pos) {}
        float cost{ 0 };
        float totalCost{ 0 };
        Position pos;
        SNode* prev{ nullptr };
        Otc::Direction dir{ Otc::InvalidDirection };
    };

    struct LessNode
    {
        bool operator()(const std::pair<SNode*, float> a, const std::pair<SNode*, float> b) const
        {
            return b.second < a.second;
        }
    };

    std::tuple<std::vector<Otc::Direction>, Otc::PathFindResult> ret;
    std::vector<Otc::Direction>& dirs = std::get<0>(ret);
    Otc::PathFindResult& result = std::get<1>(ret);

    result = Otc::PathFindResultNoWay;

    if (startPos == goalPos) {
        result = Otc::PathFindResultSamePosition;
        return ret;
    }

    if (startPos.z != goalPos.z) {
        result = Otc::PathFindResultImpossible;
        return ret;
    }

    // check the goal pos is walkable
    if (g_map.isAwareOfPosition(goalPos)) {
        const auto& goalTile = getTile(goalPos);
        if (!goalTile || (!goalTile->isWalkable(flags & Otc::PathFindIgnoreCreatures))) {
            return ret;
        }
    } else {
        const auto& goalTile = g_minimap.getTile(goalPos);
        if (goalTile.hasFlag(MinimapTileNotWalkable)) {
            return ret;
        }
    }

    stdext::map<Position, SNode*, Position::Hasher> nodes;
    std::priority_queue<std::pair<SNode*, float>, std::vector<std::pair<SNode*, float>>, LessNode> searchList;

    auto* currentNode = new SNode(startPos);
    currentNode->pos = startPos;
    nodes[startPos] = currentNode;
    SNode* foundNode = nullptr;
    while (currentNode) {
        if (static_cast<int>(nodes.size()) > maxComplexity) {
            result = Otc::PathFindResultTooFar;
            break;
        }

        // path found
        if (currentNode->pos == goalPos && (!foundNode || currentNode->cost < foundNode->cost))
            foundNode = currentNode;

        // cost too high
        if (foundNode && currentNode->totalCost >= foundNode->cost)
            break;

        for (int i = -1; i <= 1; ++i) {
            for (int j = -1; j <= 1; ++j) {
                if (i == 0 && j == 0)
                    continue;

                bool wasSeen = false;
                bool hasCreature = false;
                bool isNotWalkable = true;
                bool isNotPathable = true;
                int speed = 100;

                Position neighborPos = currentNode->pos.translated(i, j);
                if (neighborPos.x < 0 || neighborPos.y < 0) continue;
                if (g_map.isAwareOfPosition(neighborPos)) {
                    wasSeen = true;
                    if (const auto& tile = getTile(neighborPos)) {
                        hasCreature = tile->hasCreatures() && (!(flags & Otc::PathFindIgnoreCreatures));
                        isNotWalkable = !tile->isWalkable(flags & Otc::PathFindIgnoreCreatures);
                        isNotPathable = !tile->isPathable();
                        speed = tile->getGroundSpeed();
                    }
                } else {
                    const auto& mtile = g_minimap.getTile(neighborPos);
                    wasSeen = mtile.hasFlag(MinimapTileWasSeen);
                    isNotWalkable = mtile.hasFlag(MinimapTileNotWalkable);
                    isNotPathable = mtile.hasFlag(MinimapTileNotPathable);
                    if (isNotWalkable || isNotPathable)
                        wasSeen = true;
                    speed = mtile.getSpeed();
                }

                float walkFactor = 0;
                if (neighborPos != goalPos) {
                    if (!(flags & Otc::PathFindAllowNotSeenTiles) && !wasSeen)
                        continue;
                    if (wasSeen) {
                        if (!(flags & Otc::PathFindAllowCreatures) && hasCreature)
                            continue;
                        if (!(flags & Otc::PathFindAllowNonPathable) && isNotPathable)
                            continue;
                        if (!(flags & Otc::PathFindAllowNonWalkable) && isNotWalkable)
                            continue;
                    }
                } else {
                    if (!(flags & Otc::PathFindAllowNotSeenTiles) && !wasSeen)
                        continue;
                    if (wasSeen) {
                        if (!(flags & Otc::PathFindAllowNonWalkable) && isNotWalkable)
                            continue;
                    }
                }

                const Otc::Direction walkDir = currentNode->pos.getDirectionFromPosition(neighborPos);
                if (walkDir >= Otc::NorthEast)
                    walkFactor += 3.0f;
                else
                    walkFactor += 1.0f;

                const float cost = currentNode->cost + (speed * walkFactor) / 100.0f;

                SNode* neighborNode;
                if (!nodes.contains(neighborPos)) {
                    neighborNode = new SNode(neighborPos);
                    nodes[neighborPos] = neighborNode;
                } else {
                    neighborNode = nodes[neighborPos];
                    if (neighborNode->cost <= cost)
                        continue;
                }

                neighborNode->prev = currentNode;
                neighborNode->cost = cost;
                neighborNode->totalCost = neighborNode->cost + neighborPos.distance(goalPos);
                neighborNode->dir = walkDir;
                searchList.emplace(neighborNode, neighborNode->totalCost);
            }
        }

        if (!searchList.empty()) {
            currentNode = searchList.top().first;
            searchList.pop();
        } else
            currentNode = nullptr;
    }

    if (foundNode) {
        currentNode = foundNode;
        while (currentNode) {
            dirs.push_back(currentNode->dir);
            currentNode = currentNode->prev;
        }
        dirs.pop_back();
        std::ranges::reverse(dirs);
        result = Otc::PathFindResultOk;
    }

    for (const auto& it : nodes)
        delete it.second;

    return ret;
}

void Map::resetLastCamera() const
{
    for (const auto& mapView : m_mapViews)
        mapView->resetLastCamera();
}

PathFindResult_ptr Map::newFindPath(const Position& start, const Position& goal, const std::shared_ptr<std::list<Node*>>
                                    & visibleNodes)
{
    auto ret = std::make_shared<PathFindResult>();
    ret->start = start;
    ret->destination = goal;

    if (start == goal) {
        ret->status = Otc::PathFindResultSamePosition;
        return ret;
    }

    if (goal.z != start.z) {
        return ret;
    }

    // check the goal pos is walkable
    if (g_map.isAwareOfPosition(goal)) {
        const auto& goalTile = getTile(goal);
        if (!goalTile || (!goalTile->isWalkable())) {
            return ret;
        }
    } else {
        const auto& goalTile = g_minimap.getTile(goal);
        if (goalTile.hasFlag(MinimapTileNotWalkable)) {
            return ret;
        }
    }

    struct LessNode
    {
        bool operator()(const Node* a, const Node* b) const
        {
            return b->totalCost < a->totalCost;
        }
    };

    stdext::map<Position, Node*, Position::Hasher> nodes;
    std::priority_queue<Node*, std::vector<Node*>, LessNode> searchList;

    if (visibleNodes) {
        for (auto& node : *visibleNodes)
            nodes.emplace(node->pos, node);
    }

    const auto& initNode = new Node{ .cost = 1, .totalCost = 0, .pos = start, .prev = nullptr, .distance = 0, .unseen = 0 };
    nodes[start] = initNode;
    searchList.push(initNode);

    int limit = 50000;
    const float distance = start.distance(goal);

    const Node* dstNode = nullptr;
    while (!searchList.empty() && --limit) {
        Node* node = searchList.top();
        searchList.pop();
        if (node->pos == goal) {
            dstNode = node;
            break;
        }
        if (node->pos.distance(goal) > distance + 10000)
            continue;
        for (int i = -1; i <= 1; ++i) {
            for (int j = -1; j <= 1; ++j) {
                if (i == 0 && j == 0)
                    continue;
                Position neighbor = node->pos.translated(i, j);
                if (neighbor.x < 0 || neighbor.y < 0) continue;
                auto it = nodes.find(neighbor);
                if (it == nodes.end()) {
                    const auto& [block, tile] = g_minimap.threadGetTile(neighbor);
                    const bool wasSeen = tile.hasFlag(MinimapTileWasSeen);
                    const bool isNotWalkable = tile.hasFlag(MinimapTileNotWalkable);
                    const bool isNotPathable = tile.hasFlag(MinimapTileNotPathable);
                    const bool isEmpty = tile.hasFlag(MinimapTileEmpty);
                    float speed = tile.getSpeed();
                    if ((isNotWalkable || isNotPathable || isEmpty) && neighbor != goal) {
                        it = nodes.emplace(neighbor, nullptr).first;
                    } else {
                        if (!wasSeen)
                            speed = 2000;
                        it = nodes.emplace(neighbor, new Node{ .cost = speed, .totalCost = 10000000.0f, .pos = neighbor, .prev =
                                               node,
                                               .distance = node->distance + 1, .unseen = wasSeen ? 0 : 1 }).first;
                    }
                }
                if (!it->second) // no way
                    continue;

                if (it->second->unseen > 50)
                    continue;

                const float diagonal = ((i == 0 || j == 0) ? 1.0f : 3.0f);
                float cost = it->second->cost * diagonal;
                cost += diagonal * (50.0f * std::max<float>(5.0f, it->second->pos.distance(goal))); // heuristic
                if (node->totalCost + cost + 50 < it->second->totalCost) {
                    it->second->totalCost = node->totalCost + cost;
                    it->second->prev = node;
                    if (it->second->unseen)
                        it->second->unseen = node->unseen + 1;
                    it->second->distance = node->distance + 1;
                    searchList.push(it->second);
                }
            }
        }
    }

    if (dstNode) {
        while (dstNode && dstNode->prev) {
            if (dstNode->unseen) {
                ret->path.clear();
            } else {
                ret->path.push_back(dstNode->prev->pos.getDirectionFromPosition(dstNode->pos));
            }
            dstNode = dstNode->prev;
        }
        std::reverse(ret->path.begin(), ret->path.end());
        ret->status = Otc::PathFindResultOk;
    }
    ret->complexity = 50000 - limit;

    for (const auto& node : nodes) {
        delete node.second;
    }

    return ret;
}

void Map::findPathAsync(const Position& start, const Position& goal, const std::function<void(PathFindResult_ptr)>&
                        callback)
{
    const auto visibleNodes = std::make_shared<std::list<Node*>>();
    for (const auto& tile : getTiles(start.z)) {
        if (tile->getPosition() == start)
            continue;
        const bool isNotWalkable = !tile->isWalkable(false);
        const bool isNotPathable = !tile->isPathable();
        const float speed = tile->getGroundSpeed();
        if ((isNotWalkable || isNotPathable) && tile->getPosition() != goal) {
            visibleNodes->push_back(new Node{ .cost = speed, .totalCost = 0, .pos = tile->getPosition(), .prev = nullptr, .distance =
                0,
                .unseen = 0
            });
        } else {
            visibleNodes->push_back(new Node{ .cost = speed, .totalCost = 10000000.0f, .pos = tile->getPosition(), .prev =
                nullptr, .distance = 0, .unseen = 0
            });
        }
    }

    g_asyncDispatcher->detach_task([=] {
        const auto ret = g_map.newFindPath(start, goal, visibleNodes);
        g_dispatcher.addEvent(std::bind(callback, ret));
    });
}

int Map::getMinimapColor(const Position& pos)
{
    int color = 0;
    if (const TilePtr& tile = getTile(pos)) {
        color = tile->getMinimapColorByte();
    }
    if (color == 0) {
        const MinimapTile& mtile = g_minimap.getTile(pos);
        color = mtile.color;
    }
    return color;
}

bool Map::isSightClear(const Position& fromPos, const Position& toPos)
{
    if (fromPos == toPos) {
        return true;
    }

    Position start(fromPos.z > toPos.z ? toPos : fromPos);
    const Position destination(fromPos.z > toPos.z ? fromPos : toPos);

    const int8_t mx = start.x < destination.x ? 1 : start.x == destination.x ? 0 : -1;
    const int8_t my = start.y < destination.y ? 1 : start.y == destination.y ? 0 : -1;

    const int32_t A = destination.y - start.y;
    const int32_t B = start.x - destination.x;
    const int32_t C = -(A * destination.x + B * destination.y);

    while (start.x != destination.x || start.y != destination.y) {
        const int32_t move_hor = std::abs(A * (start.x + mx) + B * (start.y) + C);
        const int32_t move_ver = std::abs(A * (start.x) + B * (start.y + my) + C);
        const int32_t move_cross = std::abs(A * (start.x + mx) + B * (start.y + my) + C);

        if (start.y != destination.y && (start.x == destination.x || move_hor > move_ver || move_hor > move_cross)) {
            start.y += my;
        }

        if (start.x != destination.x && (start.y == destination.y || move_ver > move_hor || move_ver > move_cross)) {
            start.x += mx;
        }

        const auto tile = getTile(Position(start.x, start.y, start.z));
        if (tile && !tile->isLookPossible()) {
            return false;
        }
    }

    while (start.z != destination.z) {
        const auto tile = getTile(Position(start.x, start.y, start.z));
        if (tile && tile->getThingCount() > 0) {
            return false;
        }
        start.z++;
    }

    return true;
}

bool Map::isWidgetAttached(const UIWidgetPtr& widget) const {
    return m_attachedObjectWidgetMap.contains(widget);
}

void Map::addAttachedWidgetToObject(const UIWidgetPtr& widget, const AttachableObjectPtr& object) {
    if (isWidgetAttached(widget))
        return;

    m_attachedObjectWidgetMap.emplace(widget, object);
}

bool Map::removeAttachedWidgetFromObject(const UIWidgetPtr& widget) {
    // remove elemnt form unordered map
    const auto it = m_attachedObjectWidgetMap.find(widget);
    if (it == m_attachedObjectWidgetMap.end())
        return false;

    if (!widget->isDestroyed())
        widget->destroy();

    m_attachedObjectWidgetMap.erase(it);
    return true;
}

void Map::updateAttachedWidgets(const MapViewPtr& mapView)
{
    g_drawPool.select(DrawPoolType::MAP);
    for (const auto& [widget, object] : m_attachedObjectWidgetMap) {
        if (widget->isDestroyed()) {
            continue;
        }

        if (!widget->isVisible())
            continue;

        Position pos;
        if (object->isTile()) {
            const auto& tile = object->static_self_cast<Tile>();
            pos = tile->getPosition();
        } else if (object->isThing()) {
            const auto& thing = object->static_self_cast<Thing>();
            pos = thing->getPosition();
        }

        if (!pos.isValid())
            continue;

        Point p = mapView->transformPositionTo2D(pos) - mapView->m_posInfo.drawOffset;

        if (object->isThing() && object->static_self_cast<Thing>()->isCreature()) {
            const auto& creature = object->static_self_cast<Thing>()->static_self_cast<Creature>();

            const auto displacementX = g_game.getFeature(Otc::GameNegativeOffset) ? 0 : creature->getDisplacementX();
            const auto displacementY = g_game.getFeature(Otc::GameNegativeOffset) ? 0 : creature->getDisplacementY();

            const auto& jumpOffset = creature->getJumpOffset() * g_drawPool.getScaleFactor();
            const auto& creatureOffset = Point(16 - displacementX, -displacementY - 2) + creature->getDrawOffset();
            p += creatureOffset * g_drawPool.getScaleFactor() - Point(std::round(jumpOffset.x), std::round(jumpOffset.y));
        }

        p.x *= mapView->m_posInfo.horizontalStretchFactor;
        p.y *= mapView->m_posInfo.verticalStretchFactor;
        p += mapView->m_posInfo.rect.topLeft();

        p.x += widget->getMarginLeft();
        p.x -= widget->getMarginRight();
        p.y += widget->getMarginTop();
        p.y -= widget->getMarginBottom();

        const bool isScaled = g_app.getHUDScale() != DEFAULT_DISPLAY_DENSITY;
        if (isScaled) {
            p.scale(g_app.getHUDScale());
        }

        const auto& widgetRect = widget->getRect();
        const auto& newWidgetRect = Rect(p, widgetRect.width(), widgetRect.height());

        widget->disableUpdateTemporarily();
        widget->setRect(newWidgetRect);
    }
}

std::map<std::string, std::tuple<int, int, int, std::string>> Map::findEveryPath(const Position& start, int maxDistance, const std::map<std::string, std::string>& params)
{
    // using Dijkstra's algorithm
    struct LessNode
    {
        bool operator()(Node* a, Node* b) const
        {
            return b->totalCost < a->totalCost;
        }
    };

    std::map<std::string, std::string>::const_iterator it;
    it = params.find("ignoreLastCreature");
    bool ignoreLastCreature = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("ignoreCreatures");
    bool ignoreCreatures = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("ignoreNonPathable");
    bool ignoreNonPathable = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("ignoreNonWalkable");
    bool ignoreNonWalkable = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("ignoreStairs");
    bool ignoreStairs = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("ignoreCost");
    bool ignoreCost = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("allowUnseen");
    bool allowUnseen = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("allowOnlyVisibleTiles");
    bool allowOnlyVisibleTiles = it != params.end() && it->second != "0" && it->second != "";
    it = params.find("marginMin");
    bool hasMargin = it != params.end();
    it = params.find("marginMax");
    hasMargin = hasMargin || (it != params.end());

    Position destPos;
    it = params.find("destination");
    if (it != params.end()) {
        std::vector<int32_t> pos = stdext::split<int32_t>(it->second, ",");
        if (pos.size() == 3) {
            destPos = Position(pos[0], pos[1], pos[2]);
        }
    }

    Position maxDistanceFromPos;
    int maxDistanceFrom = 0;
    it = params.find("maxDistanceFrom");
    if (it != params.end()) {
        std::vector<int32_t> pos = stdext::split<int32_t>(it->second, ",");
        if (pos.size() == 4) {
            maxDistanceFromPos = Position(pos[0], pos[1], pos[2]);
            maxDistanceFrom = pos[3];
        }
    }

    std::map<std::string, std::tuple<int, int, int, std::string>> ret;
    std::unordered_map<Position, Node*, Position::Hasher> nodes;
    std::priority_queue<Node*, std::vector<Node*>, LessNode> searchList;

    Node* initNode = new Node{ 1, 0, start, nullptr, 0, 0 };
    nodes[start] = initNode;
    searchList.push(initNode);

    while (!searchList.empty()) {
        Node* node = searchList.top();
        searchList.pop();
        ret[node->pos.toString()] = std::make_tuple(node->totalCost, node->distance,
                                                    node->prev ? node->prev->pos.getDirectionFromPosition(node->pos) : -1,
                                                    node->prev ? node->prev->pos.toString() : "");
        if (node->pos == destPos) {
            if (hasMargin) {
                maxDistance = std::min<int>(node->distance + 4, maxDistance);
            } else {
                break;
            }
        }
        if (node->distance >= maxDistance)
            continue;
        for (int i = -1; i <= 1; ++i) {
            for (int j = -1; j <= 1; ++j) {
                if (i == 0 && j == 0)
                    continue;
                Position neighbor = node->pos.translated(i, j);
                if (neighbor.x < 0 || neighbor.y < 0) continue;
                auto it = nodes.find(neighbor);
                if (it == nodes.end()) {
                    bool wasSeen = false;
                    bool hasCreature = false;
                    bool isNotWalkable = true;
                    bool isNotPathable = true;
                    int mapColor = 0;
                    int speed = 1000;
                    if (g_map.isAwareOfPosition(neighbor)) {
                        if (const TilePtr& tile = getTile(neighbor)) {
                            wasSeen = true;
                            hasCreature = tile->hasBlockingCreature();
                            isNotWalkable = !tile->isWalkable(true);
                            isNotPathable = !tile->isPathable();
                            mapColor = tile->getMinimapColorByte();
                            speed = tile->getGroundSpeed();
                        }
                    } else if (!allowOnlyVisibleTiles) {
                        const MinimapTile& mtile = g_minimap.getTile(neighbor);
                        wasSeen = mtile.hasFlag(MinimapTileWasSeen);
                        isNotWalkable = mtile.hasFlag(MinimapTileNotWalkable);
                        isNotPathable = mtile.hasFlag(MinimapTileNotPathable);
                        mapColor = mtile.color;
                        if (isNotWalkable || isNotPathable)
                            wasSeen = true;
                        speed = mtile.getSpeed();
                    }
                    bool hasStairs = isNotPathable && mapColor >= 210 && mapColor <= 213;
                    bool hasReachedMaxDistance = maxDistanceFrom && maxDistanceFromPos.isValid() && maxDistanceFromPos.distance(neighbor) > maxDistanceFrom;
                    if ((!wasSeen && !allowUnseen) || (hasStairs && !ignoreStairs && neighbor != destPos) ||
                        (isNotPathable && !ignoreNonPathable && neighbor != destPos) || (isNotWalkable && !ignoreNonWalkable) ||
                        hasReachedMaxDistance) {
                        it = nodes.emplace(neighbor, nullptr).first;
                    } else if ((hasCreature && !ignoreCreatures)) {
                        it = nodes.emplace(neighbor, nullptr).first;
                        if (ignoreLastCreature) {
                            ret[neighbor.toString()] = std::make_tuple(node->totalCost + 100, node->distance + 1,
                                                                       node->pos.getDirectionFromPosition(neighbor),
                                                                       node->pos.toString());
                        }
                    } else {
                        it = nodes.emplace(neighbor, new Node{ (float)speed, 10000000.0f, neighbor, node, node->distance + 1, wasSeen ? 0 : 1 }).first;
                    }
                }

                if (!it->second) {
                    continue;
                }

                float diagonal = ((i == 0 || j == 0) ? 1.0f : 3.0f);
                float cost = it->second->cost * diagonal;
                if (ignoreCost)
                    cost = 1;
                if (node->totalCost + cost < it->second->totalCost) {
                    it->second->totalCost = node->totalCost + cost;
                    it->second->prev = node;
                    if (it->second->unseen)
                        it->second->unseen = node->unseen + 1;
                    it->second->distance = node->distance + 1;
                    searchList.push(it->second);
                }
            }
        }
    }

    for (auto& node : nodes) {
        if (node.second)
            delete node.second;
    }

    return ret;
}

std::vector<CreaturePtr> Map::getSpectatorsByPattern(const Position& centerPos, const std::string& pattern, Otc::Direction direction)
{
    std::vector<bool> finalPattern(pattern.size(), false);
    std::vector<CreaturePtr> creatures;
    int width = 0, height = 0, lineLength = 0, p = 0;
    for (auto& c : pattern) {
        lineLength += 1;
        if (c == '0' || c == '-') {
            p += 1;
        } else if (c == '1' || c == '+') {
            finalPattern[p++] = true;
        } else if (c == 'N' || c == 'n') {
            finalPattern[p++] = direction == Otc::North;
        } else if (c == 'E' || c == 'e') {
            finalPattern[p++] = direction == Otc::East;
        } else if (c == 'W' || c == 'w') {
            finalPattern[p++] = direction == Otc::West;
        } else if (c == 'S' || c == 's') {
            finalPattern[p++] = direction == Otc::South;
        } else {
            lineLength -= 1;
            if (lineLength > 1) {
                if (width == 0)
                    width = lineLength;
                if (width != lineLength) {
                    g_logger.error("Invalid pattern for getSpectatorsByPattern: {}", pattern);
                    return creatures;
                }
                height += 1;
                lineLength = 0;
            }
        }
    }
    if (lineLength > 0) {
        if (width == 0)
            width = lineLength;
        if (width != lineLength) {
            g_logger.error("Invalid pattern for getSpectatorsByPattern: {}", pattern);
            return creatures;
        }
        height += 1;
    }
    if (width % 2 != 1 || height % 2 != 1) {
        g_logger.error("Invalid pattern for getSpectatorsByPattern, width and height should be odd (height: %i width: %i)", height, width);
        return creatures;
    }

    p = 0;
    std::unordered_set<uint32_t> seenIds;
    seenIds.reserve(m_knownCreatures.size());
    for (int y = centerPos.y - height / 2, endy = centerPos.y + height / 2; y <= endy; ++y) {
        for (int x = centerPos.x - width / 2, endx = centerPos.x + width / 2; x <= endx; ++x) {
            const auto enabled = finalPattern[p];
            ++p;
            if (!enabled) {
                continue;
            }

            const auto tile = getTile(Position(x, y, centerPos.z));
            if (!tile || !tile->hasCreatures()) {
                continue;
            }

            const auto sizeBeforeAppend = creatures.size();
            tile->appendSpectators(creatures);
            cleanNewSpectators(creatures, seenIds, sizeBeforeAppend);
        }
    }
    return creatures;
}

const TilePtr& TileBlock::create(const Position& pos)
{
    auto& tile = m_tiles[getTileIndex(pos)];
    tile = std::make_shared<Tile>(pos);
    return tile;
}
const TilePtr& TileBlock::getOrCreate(const Position& pos)
{
    auto& tile = m_tiles[getTileIndex(pos)];
    if (!tile)
        tile = std::make_shared<Tile>(pos);
    return tile;
}