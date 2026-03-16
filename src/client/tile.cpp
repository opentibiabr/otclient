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

#include "tile.h"

#include "client.h"
#include "localplayer.h"
#include "effect.h"
#include "game.h"
#include "gameconfig.h"
#include "item.h"
#include "map.h"
#include "mapview.h"
#include "thing.h"
#include "uimap.h"
#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/image.h"

Tile::Tile(const Position& position) : m_position(position) {}

void updateElevation(const ThingPtr& thing, uint8_t& drawElevation) {
    if (thing->hasElevation())
        drawElevation = std::min<uint8_t>(drawElevation + thing->getElevation(), g_gameConfig.getTileMaxElevation());
}

void drawThing(const ThingPtr& thing, const Point& dest, const int flags, uint8_t& drawElevation, LightView* lightView = nullptr)
{
    const auto& newDest = dest - drawElevation * g_drawPool.getScaleFactor();

    if (flags == Otc::DrawLights)
        thing->drawLight(newDest, lightView);
    else {
        if (thing->isSingleGround())
            g_drawPool.setDrawOrder(DrawOrder::FIRST);
        else if (thing->isSingleGroundBorder())
            g_drawPool.setDrawOrder(DrawOrder::SECOND);
        else if (thing->isEffect() && g_app.isDrawingEffectsOnTop())
            g_drawPool.setDrawOrder(DrawOrder::FOURTH);
        else
            g_drawPool.setDrawOrder(DrawOrder::THIRD);

        thing->draw(newDest, flags & Otc::DrawThings, lightView);
        updateElevation(thing, drawElevation);

        g_drawPool.resetDrawOrder();
    }
}

void Tile::draw(const Point& dest, const int flags, LightView* lightView)
{
    m_lastDrawDest = dest;

    uint8_t drawElevation = 0;

    if (m_fill != Color::alpha) {
        g_drawPool.addFilledRect(Rect(dest, Size{ g_gameConfig.getSpriteSize() }), m_fill);
        return;
    }

    for (const auto& thing : m_things) {
        if (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom())
            break;

        drawThing(thing, dest, flags, drawElevation);
    }

    drawAttachedEffect(dest, dest, lightView, false);

    if (hasCommonItem()) {
        for (auto& item : std::ranges::reverse_view(m_things)) {
            if (!item->isCommon()) continue;
            drawThing(item, dest, flags, drawElevation);
        }
    }

    // after we render 2x2 lying corpses, we must redraw previous creatures/ontop above them
    if (m_tilesRedraw) {
        for (const auto& tile : *m_tilesRedraw) {
            tile->drawCreature(tile->m_lastDrawDest, flags, true, drawElevation);
            tile->drawTop(tile->m_lastDrawDest, flags, true, drawElevation);
        }
    }

    drawCreature(dest, flags, false, drawElevation);
    drawTop(dest, flags, false, drawElevation);
    drawAttachedEffect(dest, dest, lightView, true);
    drawAttachedParticlesEffect(dest);
}

void Tile::drawLight(const Point& dest, LightView* lightView) {
    uint8_t drawElevation = 0;

    for (const auto& thing : m_things) {
        if (thing->isCreature()) continue;

        thing->drawLight(dest - drawElevation * g_drawPool.getScaleFactor(), lightView);
        updateElevation(thing, drawElevation);
    }

    drawCreature(dest, Otc::DrawLights, true, drawElevation, lightView);

    if (m_effects) {
        for (const auto& effect : *m_effects)
            effect->draw(dest - drawElevation * g_drawPool.getScaleFactor(), false, lightView);
    }

    drawAttachedLightEffect(dest, lightView);
}

void Tile::drawCreature(const Point& dest, const int flags, const bool forceDraw, uint8_t drawElevation, LightView* lightView)
{
    if (!forceDraw && !m_drawTopAndCreature)
        return;

    const auto& newDest = dest - drawElevation * g_drawPool.getScaleFactor();

    bool localPlayerDrawed = false;
    if (hasCreatures()) {
        for (const auto& thing : m_things) {
            if (!thing->isCreature() || thing->static_self_cast<Creature>()->isWalking()) continue;

            if (thing->isLocalPlayer()) {
                if (thing->getPosition() != m_position) continue;
                localPlayerDrawed = true;
            }

            drawThing(thing, dest, flags, drawElevation, lightView);
        }
    }

    g_drawPool.setDrawOrder(DrawOrder::THIRD);
    for (const auto& creature : m_walkingCreatures) {
        const auto& cDest = Point(
            dest.x + ((creature->getPosition().x - m_position.x) * g_gameConfig.getSpriteSize() - creature->getDrawElevation()) * g_drawPool.getScaleFactor(),
            dest.y + ((creature->getPosition().y - m_position.y) * g_gameConfig.getSpriteSize() - creature->getDrawElevation()) * g_drawPool.getScaleFactor()
        );

        if (flags == Otc::DrawLights)
            creature->drawLight(cDest, lightView);
        else
            creature->draw(cDest, flags & Otc::DrawThings);
    }
    g_drawPool.resetDrawOrder();

    // draw the local character if he is on a virtual tile, that is, his visual position is not the same as the server.
    if (!localPlayerDrawed && g_game.getLocalPlayer() && !g_game.getLocalPlayer()->isWalking() && g_game.getLocalPlayer()->getPosition() == m_position) {
        drawThing(g_game.getLocalPlayer(), dest, flags, drawElevation, lightView);
    }
}

void Tile::drawTop(const Point& dest, const int flags, const bool forceDraw, uint8_t drawElevation)
{
    if (!forceDraw && !m_drawTopAndCreature)
        return;

    drawElevation = 0;

    if (m_effects) {
        for (const auto& effect : *m_effects)
            drawThing(effect, dest, flags & Otc::DrawThings, drawElevation);
    }

    if (hasTopItem()) {
        for (const auto& item : m_things) {
            if (!item->isOnTop()) continue;
            drawThing(item, dest, flags & Otc::DrawThings, drawElevation);
        }
    }
}

void Tile::clean()
{
    if (g_client.getMapWidget() && (m_text || m_timerText)) {
        g_dispatcher.scheduleEvent([tile = static_self_cast<Tile>()] {
            if (g_client.getMapWidget())
                g_client.getMapWidget()->getMapView()->removeForegroundTile(tile);
        }, g_game.getServerBeat());
    }

    if (hasAttachedWidgets()) {
        clearAttachedWidgets();
    }

    m_highlightThingStackPos = -1;
    while (!m_things.empty())
        removeThing(m_things.front());

    m_tilesRedraw = nullptr;

    m_thingTypeFlag = 0;

    m_firstCreatureIndex = -1;
    m_lastCreatureIndex = -1;

#ifdef FRAMEWORK_EDITOR
    m_flags = 0;
#endif
}

void Tile::addWalkingCreature(const CreaturePtr& creature)
{
    m_walkingCreatures.emplace_back(creature);
    setThingFlag(creature);
}

void Tile::removeWalkingCreature(const CreaturePtr& creature)
{
    const auto it = std::ranges::find(m_walkingCreatures, creature);
    if (it == m_walkingCreatures.end())
        return;

    m_walkingCreatures.erase(it);
    recalculateThingFlag();
}

void Tile::updateThingStackPos() {
    for (int stackpos = -1, s = m_things.size(); ++stackpos < s;) {
        m_things[stackpos]->m_stackPos = stackpos;
    }
}

// TODO: Need refactoring
// Redo Stack Position System
void Tile::addThing(const ThingPtr& thing, int stackPos)
{
    if (!thing)
        return;

    if (thing->isEffect()) {
        if (!m_effects)
            m_effects = std::make_unique<std::vector<EffectPtr>>();

        const auto& newEffect = thing->static_self_cast<Effect>();

        const bool mustOptimize = g_app.mustOptimize() || g_app.isForcedEffectOptimization();

        for (const auto& prevEffect : *m_effects) {
            if (!prevEffect->canDraw())
                continue;

            if (mustOptimize && newEffect->getSize() > prevEffect->getSize()) {
                prevEffect->canDraw(false);
            } else if (mustOptimize || newEffect->getId() == prevEffect->getId()) {
                if (!newEffect->waitFor(prevEffect))
                    return;
            }
        }

        if (!newEffect->isTopEffect())
            m_effects->insert(m_effects->begin(), newEffect);
        else
            m_effects->emplace_back(newEffect);

        setThingFlag(thing);

        thing->setPosition(m_position);
        thing->onAppear();
        return;
    }

    const uint8_t size = m_things.size();

    // priority                                    854
    // 0 - ground,                        -->      -->
    // 1 - ground borders                 -->      -->
    // 2 - bottom (walls),                -->      -->
    // 3 - on top (doors)                 -->      -->
    // 4 - creatures, from top to bottom  <--      -->
    // 5 - items, from top to bottom      <--      <--
    if (stackPos < 0 || stackPos == 255) {
        const int priority = thing->getStackPriority();

        // -1 or 255 => auto detect position
        // -2        => append

        bool append;
        if (stackPos == -2)
            append = true;
        else {
            append = (priority <= 3);

            // newer protocols does not store creatures in reverse order
            if (g_game.getClientVersion() >= 854 && priority == 4)
                append = !append;
        }

        for (stackPos = 0; stackPos < size; ++stackPos) {
            const int otherPriority = m_things[stackPos]->getStackPriority();
            if ((append && otherPriority > priority) || (!append && otherPriority >= priority))
                break;
        }
    } else if (stackPos > static_cast<int>(size))
        stackPos = size;

    markHighlightedThing(Color::white);

    m_things.insert(m_things.begin() + stackPos, thing);

    updateCreatureRangeForInsert(static_cast<int16_t>(stackPos), thing);

    setThingFlag(thing);

    if (size > g_gameConfig.getTileMaxThings())
        removeThing(m_things[g_gameConfig.getTileMaxThings()]);

    updateThingStackPos();
    thing->setPosition(m_position, stackPos);
    thing->onAppear();

    updateElevation(thing, m_drawElevation);
    checkForDetachableThing();

    if (g_game.isTileThingLuaCallbackEnabled())
        callLuaField("onAddThing", thing);
}

// TODO: Need refactoring
bool Tile::removeThing(const ThingPtr thing)
{
    if (!thing) return false;

    if (m_effects && thing->isEffect()) {
        const auto& effect = thing->static_self_cast<Effect>();
        const auto it = std::find(m_effects->begin(), m_effects->end(), effect);
        if (it == m_effects->end())
            return false;

        m_effects->erase(it);
        return true;
    }

    const auto it = std::ranges::find(m_things, thing);
    if (it == m_things.end())
        return false;

    markHighlightedThing(Color::white);

    m_things.erase(it);

    m_highlightThingStackPos = -1;
    thing->m_stackPos = -1;
    thing->setMarked(Color::white);

    recalculateThingFlag();
    if (thing->hasElevation())
        --m_elevation;

    updateThingStackPos();
    checkForDetachableThing();

    if (thing->hasElevation()) {
        m_drawElevation = 0;
        for (const auto& t : m_things)
            updateElevation(t, m_drawElevation);
    }

    thing->onDisappear();

    if (g_game.isTileThingLuaCallbackEnabled())
        callLuaField("onRemoveThing", thing);

    return true;
}

ThingPtr Tile::getThing(const int stackPos)
{
    if (stackPos >= 0 && stackPos < static_cast<int>(m_things.size()))
        return m_things[stackPos];

    return nullptr;
}

void Tile::updateCreatureRangeForInsert(const int16_t stackPos, const ThingPtr& thing)
{
    if (m_firstCreatureIndex != -1 && stackPos <= m_firstCreatureIndex) {
        ++m_firstCreatureIndex;
    }

    if (m_lastCreatureIndex != -1 && stackPos <= m_lastCreatureIndex) {
        ++m_lastCreatureIndex;
    }

    if (!thing->isCreature()) {
        return;
    }

    if (m_firstCreatureIndex == -1 || stackPos < m_firstCreatureIndex) {
        m_firstCreatureIndex = stackPos;
    }

    if (stackPos > m_lastCreatureIndex) {
        m_lastCreatureIndex = stackPos;
    }
}

void Tile::rebuildCreatureRange()
{
    m_firstCreatureIndex = -1;
    m_lastCreatureIndex = -1;

    const auto count = static_cast<int32_t>(m_things.size());
    for (int32_t i = 0; i < count; ++i) {
        if (!m_things[i]->isCreature()) {
            continue;
        }

        if (m_firstCreatureIndex == -1) {
            m_firstCreatureIndex = static_cast<int16_t>(i);
        }

        m_lastCreatureIndex = static_cast<int16_t>(i);
    }
}

void Tile::appendSpectators(std::vector<CreaturePtr>& out) const
{
    if (!hasCreatures() || m_lastCreatureIndex == -1) {
        return;
    }

    const auto size = static_cast<int32_t>(m_things.size());
    const auto beginOffset = size - 1 - static_cast<int32_t>(m_lastCreatureIndex);
    const auto endOffset = size - static_cast<int32_t>(m_firstCreatureIndex);

    auto it = m_things.rbegin() + beginOffset;
    const auto end = m_things.rbegin() + endOffset;

    for (; it != end; ++it) {
        const auto& thing = *it;
        if (thing->isCreature()) {
            out.emplace_back(thing->static_self_cast<Creature>());
        }
    }
}

std::vector<CreaturePtr> Tile::getCreatures()
{
    std::vector<CreaturePtr> creatures;
    appendSpectators(creatures);
    std::ranges::reverse(creatures);
    return creatures;
}

int Tile::getThingStackPos(const ThingPtr& thing)
{
    for (int stackpos = -1, s = m_things.size(); ++stackpos < s;) {
        if (thing == m_things[stackpos]) return stackpos;
    }

    return -1;
}

ThingPtr Tile::getTopThing()
{
    if (isEmpty())
        return nullptr;

    for (const auto& thing : m_things)
        if (thing->isCommon())
            return thing;

    return m_things[m_things.size() - 1];
}

bool Tile::hasGround() { return (getGround() && getGround()->isSingleGround()) || m_thingTypeFlag & HAS_GROUND_BORDER; };
bool Tile::hasTopGround(const bool ignoreBorder) { return (getGround() && getGround()->isTopGround()) || (!ignoreBorder && m_thingTypeFlag & HAS_TOP_GROUND_BORDER); }
bool Tile::hasFloorChange() const
{
    for (const auto& thing : m_things) {
        if (thing->hasFloorChange())
            return true;
    }
    return false;
}
ItemPtr Tile::getGround() { const auto& ground = getThing(0); return ground && ground->isGround() ? ground->static_self_cast<Item>() : nullptr; }

std::vector<ItemPtr> Tile::getItems()
{
    std::vector<ItemPtr> items;
    for (const auto& thing : m_things) {
        if (!thing->isItem()) {
            continue;
        }

        items.emplace_back(thing->static_self_cast<Item>());
    }
    return items;
}

EffectPtr Tile::getEffect(const uint16_t id) const
{
    if (m_effects) {
        for (const auto& effect : *m_effects)
            if (effect->getId() == id)
                return effect;
    }

    return nullptr;
}

int Tile::getGroundSpeed()
{
    if (const auto& ground = getGround())
        return ground->getGroundSpeed();

    return 100;
}

uint8_t Tile::getMinimapColorByte()
{
    if (m_minimapColor != 0)
        return m_minimapColor;

    for (auto& thing : std::ranges::reverse_view(m_things)) {
        if (thing->isCreature() || thing->isCommon())
            continue;

        const uint8_t c = thing->getMinimapColor();
        if (c != 0) return c;
    }

    return 255;
}

ThingPtr Tile::getTopLookThing()
{
    if (isEmpty())
        return nullptr;

    for (const auto& thing : m_things) {
        if (!thing->isIgnoreLook() && (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom() && !thing->isOnTop()))
            return thing;
    }

    return m_things[0];
}

ThingPtr Tile::getTopUseThing()
{
    if (isEmpty())
        return nullptr;

    for (const auto& thing : m_things) {
        if (thing->isForceUse() || (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom() && !thing->isOnTop() && !thing->isCreature() && !thing->isSplash()))
            return thing;
    }

    for (uint i = m_things.size() - 1; i > 0; --i) {
        ThingPtr thing = m_things[i];
        if (!thing->isSplash() && !thing->isCreature())
            return thing;
    }

    return m_things[0];
}

CreaturePtr Tile::getTopCreature(const bool checkAround)
{
    if (!hasCreatures()) return nullptr;

    CreaturePtr creature;
    for (const auto& thing : m_things) {
        if (thing->isLocalPlayer()) // return local player if there is no other creature
            creature = thing->static_self_cast<Creature>();
        else if (thing->isCreature())
            return thing->static_self_cast<Creature>();
    }

    if (creature)
        return creature;

    if (!m_walkingCreatures.empty())
        return m_walkingCreatures.back();

    // check for walking creatures in tiles around
    if (checkAround) {
        for (const auto& pos : m_position.getPositionsAround()) {
            const auto& tile = g_map.getTile(pos);
            if (!tile) continue;

            for (const auto& c : tile->getCreatures()) {
                if (c->isWalking() && c->getLastStepFromPosition() == m_position && c->getStepProgress() < .75f) {
                    return c;
                }
            }
        }
    }

    return nullptr;
}

ThingPtr Tile::getTopMoveThing()
{
    if (isEmpty())
        return nullptr;

    for (int8_t i = -1, s = m_things.size(); ++i < s;) {
        const auto& thing = m_things[i];
        if (thing->isCommon()) {
            if (i > 0 && thing->isNotMoveable())
                return m_things[i - 1];

            return thing;
        }
    }

    for (const auto& thing : m_things) {
        if (thing->isCreature())
            return thing;
    }

    return m_things[0];
}

ThingPtr Tile::getTopMultiUseThing()
{
    if (isEmpty())
        return nullptr;

    if (const auto& topCreature = getTopCreature())
        return topCreature;

    for (const auto& thing : m_things) {
        if (thing->isForceUse())
            return thing;
    }

    for (int8_t i = -1, s = m_things.size(); ++i < s;) {
        const auto& thing = m_things[i];
        if (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom() && !thing->isOnTop()) {
            if (i > 0 && thing->isSplash())
                return m_things[i - 1];

            return thing;
        }
    }

    for (const auto& thing : m_things) {
        if (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnTop())
            return thing;
    }

    return m_things[0];
}

bool Tile::isWalkable(const bool ignoreCreatures)
{
    if (m_thingTypeFlag & NOT_WALKABLE || !getGround()) {
        return false;
    }

    if (!ignoreCreatures && hasCreatures()) {
        for (const auto& thing : m_things) {
            if (!thing->isCreature()) continue;

            const auto& creature = thing->static_self_cast<Creature>();
            if (!creature->isPassable() && creature->canBeSeen())
                return false;
        }
    }

    return true;
}

bool Tile::isCompletelyCovered(const uint8_t firstFloor, const bool resetCache)
{
    if (m_position.z == 0 || m_position.z == firstFloor) return false;

    if (resetCache) {
        m_isCompletelyCovered = m_isCovered = 0;
    }

    if (hasCreatures() || !m_walkingCreatures.empty() || hasLight())
        return false;

    const uint32_t idChecked = 1 << firstFloor;
    const uint32_t idState = 1 << (firstFloor + g_gameConfig.getMapMaxZ());
    if ((m_isCompletelyCovered & idChecked) == 0) {
        m_isCompletelyCovered |= idChecked;
        bool isLoading = false;
        if (g_map.isCompletelyCovered(m_position, isLoading, firstFloor)) {
            m_isCompletelyCovered |= idState;
            m_isCovered |= idChecked; // Set covered is Checked
            m_isCovered |= idState;
        }

        if (isLoading) {
            m_isCompletelyCovered &= ~idState;
            m_isCovered &= ~idChecked;
            m_isCovered &= ~idState;
            return false;
        }
    }

    return (m_isCompletelyCovered & idState) == idState;
}

bool Tile::isCovered(const int8_t firstFloor)
{
    if (m_position.z == 0 || m_position.z == firstFloor) return false;

    const uint32_t idChecked = 1 << firstFloor;
    const uint32_t idState = 1 << (firstFloor + g_gameConfig.getMapMaxZ());

    if ((m_isCovered & idChecked) == 0) {
        m_isCovered |= idChecked;
        bool isLoading = false;
        if (g_map.isCovered(m_position, isLoading, firstFloor))
            m_isCovered |= idState;

        if (isLoading) {
            m_isCovered &= ~idChecked;
            m_isCovered &= ~idState;
            return false;
        }
    }

    return (m_isCovered & idState) == idState;
}

bool Tile::isClickable()
{
    bool hasGround = false;
    bool hasOnBottom = false;
    bool hasIgnoreLook = false;
    for (const auto& thing : m_things) {
        if (thing->isGround())
            hasGround = true;
        else if (thing->isOnBottom())
            hasOnBottom = true;

        if (thing->isIgnoreLook())
            hasIgnoreLook = true;

        if ((hasGround || hasOnBottom) && !hasIgnoreLook)
            return true;
    }

    return false;
}

void Tile::onAddInMapView()
{
    m_drawTopAndCreature = true;
    if (m_tilesRedraw)
        m_tilesRedraw->clear();

    if (m_thingTypeFlag & CORRECT_CORPSE) {
        if (!m_tilesRedraw)
            m_tilesRedraw = std::make_unique<std::vector<TilePtr>>();

        uint8_t redrawPreviousTopW = 0,
            redrawPreviousTopH = 0;

        for (const auto& item : m_things) {
            if (!item->isLyingCorpse()) continue;

            redrawPreviousTopW = std::max<int>(item->getWidth() - 1, redrawPreviousTopW);
            redrawPreviousTopH = std::max<int>(item->getHeight() - 1, redrawPreviousTopH);
        }

        for (int x = -redrawPreviousTopW; x <= 0; ++x) {
            for (int y = -redrawPreviousTopH; y <= 0; ++y) {
                if (x == 0 && y == 0)
                    continue;

                if (const auto& tile = g_map.getTile(m_position.translated(x, y))) {
                    tile->m_drawTopAndCreature = false;
                    m_tilesRedraw->emplace_back(tile);
                }
            }
        }
    }
}

bool Tile::hasBlockingCreature() const
{
    for (const auto& thing : m_things)
        if (thing->isCreature() && !thing->static_self_cast<Creature>()->isPassable() && !thing->isLocalPlayer())
            return true;
    return false;
}

bool Tile::limitsFloorsView(const bool isFreeView)
{
    // ground and walls limits the view
    for (const auto& thing : m_things) {
        // iterate until common item is encountered
        if (thing->isCommon()) {
            break;
        }

        if (!thing->isDontHide() && (thing->isGround() || (isFreeView ? thing->isOnBottom() : thing->isOnBottom() && thing->blockProjectile()))) {
            return true;
        }
    }

    return false;
}

bool Tile::checkForDetachableThing(const TileSelectType selectType)
{
    const auto& markIfYouNeed = [&] {
        if (m_selectType == TileSelectType::NONE) return;
        markHighlightedThing(Color::yellow);
    };

    m_highlightThingStackPos = -1;
    if (const auto& creature = getTopCreature()) {
        m_highlightThingStackPos = creature->getStackPos();
        markIfYouNeed();
        return true;
    }

    const bool isFiltered = selectType != TileSelectType::NO_FILTERED;

    if (hasCommonItem()) {
        for (const auto& item : m_things) {
            if (!item->isCommon() || !item->canDraw()) {
                continue;
            }

            if (isFiltered && item->isIgnoreLook() && !item->isUsable() && !item->hasLight())
                continue;

            m_highlightThingStackPos = item->getStackPos();
            markIfYouNeed();
            return true;
        }
    }

    if (hasBottomItem()) {
        for (auto& item : std::ranges::reverse_view(m_things)) {
            if (!item->isOnBottom() || !item->canDraw()) continue;

            if (isFiltered && (item->isIgnoreLook() || item->isFluidContainer()))
                continue;

            m_highlightThingStackPos = item->getStackPos();
            markIfYouNeed();
            return true;
        }
    }

    if (hasTopItem()) {
        for (auto& item : std::ranges::reverse_view(m_things)) {
            if (!item->isOnTop()) break;
            if (!item->canDraw()) continue;

            if (isFiltered && (item->isIgnoreLook() || !item->hasLensHelp()))
                continue;

            m_highlightThingStackPos = item->getStackPos();
            markIfYouNeed();
            return true;
        }
    }

    if (!isFiltered) {
        m_highlightThingStackPos = m_things.size() - 1;
        markIfYouNeed();
        return true;
    }

    return false;
}

void Tile::setThingFlag(const ThingPtr& thing)
{
    if (thing->hasLight())
        m_thingTypeFlag |= HAS_LIGHT;

    if (thing->hasDisplacement())
        m_thingTypeFlag |= HAS_DISPLACEMENT;

    if (thing->isEffect()) return;

    if (thing->isCommon())
        m_thingTypeFlag |= HAS_COMMON_ITEM;

    if (thing->isOnTop())
        m_thingTypeFlag |= HAS_TOP_ITEM;

    if (thing->isCreature())
        m_thingTypeFlag |= HAS_CREATURE;

    if (thing->isSingleGroundBorder())
        m_thingTypeFlag |= HAS_GROUND_BORDER;

    if (thing->isTopGroundBorder())
        m_thingTypeFlag |= HAS_TOP_GROUND_BORDER;

    if (thing->isLyingCorpse() && !g_game.getFeature(Otc::GameMapDontCorrectCorpse))
        m_thingTypeFlag |= CORRECT_CORPSE;

    // Creatures and items
    if (thing->isOnBottom()) {
        m_thingTypeFlag |= HAS_BOTTOM_ITEM;

        if (thing->isHookSouth())
            m_thingTypeFlag |= HAS_HOOK_SOUTH;

        if (thing->isHookEast())
            m_thingTypeFlag |= HAS_HOOK_EAST;
    }

    if (hasElevation())
        m_thingTypeFlag |= HAS_THING_WITH_ELEVATION;

    if (thing->isIgnoreLook())
        m_thingTypeFlag |= IGNORE_LOOK;

    // best option to have something more real, but in some cases as a custom project,
    // the developers are not defining crop size
    //if(thing->getRealSize() > g_gameConfig.getSpriteSize())
    if (!thing->isSingleDimension() || thing->hasElevation() || thing->hasDisplacement())
        m_thingTypeFlag |= NOT_SINGLE_DIMENSION;

    if (thing->getHeight() > 1) {
        m_thingTypeFlag |= HAS_TALL_THINGS;

        if (thing->getHeight() > 2)
            m_thingTypeFlag |= HAS_TALL_THINGS_2;
    }

    if (thing->getWidth() > 1) {
        m_thingTypeFlag |= HAS_WIDE_THINGS;

        if (thing->getWidth() > 2)
            m_thingTypeFlag |= HAS_WIDE_THINGS_2;
    }

    if (!thing->isItem()) return;

    if (thing->getWidth() > 1 && thing->getHeight() > 1)
        m_thingTypeFlag |= HAS_WALL;

    if (thing->isNotWalkable())
        m_thingTypeFlag |= NOT_WALKABLE;

    if (thing->isNotPathable())
        m_thingTypeFlag |= NOT_PATHABLE;

    if (thing->blockProjectile())
        m_thingTypeFlag |= BLOCK_PROJECTTILE;

    if (thing->isFullGround())
        m_thingTypeFlag |= FULL_GROUND;

    if (thing->hasElevation())
        ++m_elevation;
}

void Tile::select(const TileSelectType selectType)
{
    m_selectType = selectType;

    if (selectType == TileSelectType::NO_FILTERED && !isEmpty()) {
        checkForDetachableThing(selectType);
    }

    markHighlightedThing(Color::yellow);
}

void Tile::unselect()
{
    m_selectType = TileSelectType::NONE;

    markHighlightedThing(Color::white);

    if (m_selectType == TileSelectType::NO_FILTERED)
        checkForDetachableThing();
}

bool Tile::canRender(uint32_t& flags, const Position& cameraPosition, const AwareRange viewPort)
{
    const int8_t dz = m_position.z - cameraPosition.z;
    const auto& checkPos = m_position.translated(dz, dz);

    bool draw = true;

    // Check for non-visible tiles on the screen and ignore them
    {
        if ((cameraPosition.x - checkPos.x >= viewPort.left) || (checkPos.x - cameraPosition.x == viewPort.right && !hasWideThings() && !hasDisplacement() && !hasThingWithElevation() && m_walkingCreatures.empty()))
            draw = false;
        else if ((cameraPosition.y - checkPos.y >= viewPort.top) || (checkPos.y - cameraPosition.y == viewPort.bottom && !hasTallThings() && !hasWideThings2() && !hasDisplacement() && !hasThingWithElevation() && m_walkingCreatures.empty()))
            draw = false;
        else if (((checkPos.x - cameraPosition.x > viewPort.right && (!hasWideThings() || !hasDisplacement() || !hasThingWithElevation())) || (checkPos.y - cameraPosition.y > viewPort.bottom)) && !hasTallThings2())
            draw = false;
    }

    if (!draw) {
        flags &= ~Otc::DrawThings;
        if (!hasLight())
            flags &= ~Otc::DrawLights;
        if (!hasCreatures())
            flags &= ~(Otc::DrawManaBar | Otc::DrawNames | Otc::DrawBars);
    }

    return flags > 0;
}

void Tile::drawTexts(Point dest)
{
    if (m_timerText && g_clock.millis() < m_timer) {
        if (m_text && m_text->hasText())
            dest.y -= 8;
        m_timerText->setText(fmt::format("{:.1f}", (m_timer - g_clock.millis()) / 1000.));
        m_timerText->drawText(dest, Rect(dest.x - 64, dest.y - 64, 128, 128));
        dest.y += 16;
    }

    if (m_text && m_text->hasText()) {
        m_text->drawText(dest, Rect(dest.x - 64, dest.y - 64, 128, 128));
    }
}

void Tile::markHighlightedThing(const Color& color) {
    if (m_highlightThingStackPos > -1 && m_highlightThingStackPos < static_cast<int8_t>(m_things.size())) {
        m_things[m_highlightThingStackPos]->setMarked(color);
    }
}

void Tile::setText(const std::string& text, Color color)
{
    if (!m_text) {
        m_text = std::make_unique<StaticText>();
        g_dispatcher.scheduleEvent([tile = static_self_cast<Tile>()] {
            if (g_client.getMapWidget())
                g_client.getMapWidget()->getMapView()->addForegroundTile(tile);
        }, g_game.getServerBeat());
    }

    m_text->setText(text);
    m_text->setColor(color);
}

std::string Tile::getText()
{
    return m_text ? m_text->getText() : "";
}

void Tile::setTimer(int time, Color color)
{
    if (time > 60000) {
        g_logger.warning("Max tile timer value is 300000 (300s)!");
        return;
    }
    m_timer = time + g_clock.millis();
    if (!m_timerText) {
        m_timerText = std::make_unique<StaticText>();
        g_dispatcher.scheduleEvent([tile = static_self_cast<Tile>()] {
            if (g_client.getMapWidget())
                g_client.getMapWidget()->getMapView()->addForegroundTile(tile);
        }, g_game.getServerBeat());
    }

    m_timerText->setColor(color);
}

int Tile::getTimer()
{
    return m_timerText ? std::max<int>(0, m_timer - g_clock.millis()) : 0;
}

void Tile::setFill(Color color)
{
    m_fill = color;
}

bool Tile::canShoot(int distance)
{
    auto player = g_game.getLocalPlayer();
    if (!player) return false;
    auto playerPos = player->getPosition();
    if (distance > 0 && std::max<int>(std::abs(m_position.x - playerPos.x), std::abs(m_position.y - playerPos.y)) > distance)
        return false;
    return g_map.isSightClear(playerPos, m_position);
}

bool Tile::isFullyOpaque() {
    if (isFullGround())
        return true;

    for (const auto& thing : m_things) {
        if (thing->isOpaque())
            return true;
    }

    return false;
}

bool Tile::isLoading() const {
    for (const auto& thing : m_things) {
        if (thing->isLoading())
            return true;
    }

    return false;
}

bool Tile::drawToImage(const Point& dest, ImagePtr image)
{
    if (!image)
        return false;

    int x = dest.x;
    int y = dest.y;

    // first bottom items
    m_drawElevation = 0;
    for (const ThingPtr& thing : m_things) {

        if (!thing->isGround() && !thing->isGroundBorder() && !thing->isOnBottom())
            break;

        if (thing->isGround() || thing->isGroundBorder() || thing->isOnBottom()) {
            // little hack to fix tables height
            if (thing->getId() == 2322 || thing->getId() == 2323) {
                m_drawElevation += thing->getElevation();
                if (m_drawElevation > 24)
                    m_drawElevation = 24;
            }
            thing->drawToImage(Point(x - m_drawElevation, y - m_drawElevation), image);
        }

        // little hack to fix tables height
        if (thing->getId() != 2322 && thing->getId() != 2323) {
            m_drawElevation += thing->getElevation();
            if (m_drawElevation > 24)
                m_drawElevation = 24;
        }
    }

    // normal items
    for (auto it = m_things.rbegin(); it != m_things.rend(); ++it) {
        const ThingPtr& thing = *it;

        if (thing->isOnTop() || thing->isOnBottom() || thing->isGroundBorder() || thing->isGround() || thing->isCreature())
            break;
        thing->drawToImage(Point(x - m_drawElevation, y - m_drawElevation), image);

        m_drawElevation += thing->getElevation();
        if (m_drawElevation > 24)
            m_drawElevation = 24;
    }

    // top items
    for (const ThingPtr& thing : m_things) {
        if (thing->isOnTop()) {
            thing->drawToImage(Point(x - m_drawElevation, y - m_drawElevation), image);
        }
    }

    return !m_things.empty();
}