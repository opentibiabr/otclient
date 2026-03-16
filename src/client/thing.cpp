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

#include "thing.h"

#include "attachedeffect.h"
#include "game.h"
#include "map.h"
#include "thingtype.h"
#include "framework/core/clock.h"
#include "framework/graphics/paintershaderprogram.h"
#include "framework/graphics/shadermanager.h"
#include <framework/util/stats.h>

Thing::Thing()
{
    g_stats.addThing();
}

Thing::~Thing()
{
    g_stats.removeThing();
}

void Thing::setPosition(const Position& position, uint8_t /*stackPos*/)
{
    if (m_position == position)
        return;

    const Position oldPos = m_position;
    m_position = position;
    onPositionChange(position, oldPos);
}

int Thing::getStackPriority()
{
    // Bug fix for old versions
    if (g_game.getClientVersion() <= 800 && isSplash())
        return GROUND;

    if (isGround())
        return GROUND;

    if (isGroundBorder())
        return GROUND_BORDER;

    if (isOnBottom())
        return ON_BOTTOM;

    if (isOnTop())
        return ON_TOP;

    if (isCreature())
        return CREATURE;

    // common items
    return COMMON_ITEMS;
}

const TilePtr& Thing::getTile()
{
    return g_map.getTile(m_position);
}

ContainerPtr Thing::getParentContainer()
{
    if (m_position.x == 0xffff && m_position.y & 0x40) {
        const int containerId = m_position.y ^ 0x40;
        return g_game.getContainer(containerId);
    }

    return nullptr;
}

int Thing::getStackPos()
{
    if (m_position.x == UINT16_MAX && isItem()) // is inside a container
        return m_position.z;

    if (m_stackPos >= 0)
        return m_stackPos;

    g_logger.traceError("got a thing with invalid stackpos");
    return -1;
}

PainterShaderProgramPtr Thing::getShader() const {
    return g_shaders.getShaderById(m_shaderId);
}

void Thing::setShader(const std::string_view name) {
    m_shaderId = 0;
    if (name.empty())
        return;

    if (const auto& shader = g_shaders.getShader(name))
        m_shaderId = shader->getId();
}
void Thing::setAttachedEffectDirection(const Otc::Direction dir) const
{
    if (!hasAttachedEffects()) return;

    for (const auto& effect : m_data->attachedEffects) {
        if (effect->getThingType() && (effect->getThingType()->isCreature() || effect->getThingType()->isMissile()))
            effect->m_direction = dir;
    }
}

Animator* Thing::getAnimator() const {
    if (const auto t = getThingType(); t)
        return t->getAnimator();
    return nullptr;
}
Animator* Thing::getIdleAnimator() const {
    if (const auto t = getThingType(); t)
        return t->getIdleAnimator();
    return nullptr;
}

Point Thing::getDisplacement() const {
    if (const auto t = getThingType(); t)
        return t->getDisplacement();
    return Point();
}
int Thing::getDisplacementX() const {
    if (const auto t = getThingType(); t)
        return t->getDisplacementX();
    return 0;
}
int Thing::getDisplacementY() const {
    if (const auto t = getThingType(); t)
        return t->getDisplacementY();
    return 0;
}
int Thing::getExactSize(const int layer, const int xPattern, const int yPattern, const int zPattern, const int animationPhase) {
    if (const auto t = getThingType(); t)
        return t->getExactSize(layer, xPattern, yPattern, zPattern, animationPhase);
    return 0;
}

const Light& Thing::getLight() const {
    if (const auto t = getThingType(); t)
        return t->getLight();
    static const Light kEmptyLight;
    return kEmptyLight;
}
bool Thing::hasLight() const {
    if (const auto t = getThingType(); t)
        return t->hasLight();
    return false;
}

const MarketData& Thing::getMarketData() {
    if (const auto t = getThingType(); t)
        return t->getMarketData();
    static const MarketData kEmptyMarketData{};
    return kEmptyMarketData;
}
const std::vector<NPCData>& Thing::getNpcSaleData() {
    if (const auto t = getThingType(); t)
        return t->getNpcSaleData();
    static const std::vector<NPCData> kEmptyNpcData;
    return kEmptyNpcData;
}
int Thing::getMeanPrice() {
    if (const auto t = getThingType(); t)
        return t->getMeanPrice();
    return 0;
}
const Size& Thing::getSize() const {
    if (const auto t = getThingType(); t)
        return t->getSize();
    static const Size kEmptySize;
    return kEmptySize;
}

int Thing::getWidth() const {
    if (const auto t = getThingType(); t)
        return t->getWidth();
    return 0;
}
int Thing::getHeight() const {
    if (const auto t = getThingType(); t)
        return t->getHeight();
    return 0;
}
int Thing::getRealSize() const {
    if (const auto t = getThingType(); t)
        return t->getRealSize();
    return 0;
}
int Thing::getLayers() const {
    if (const auto t = getThingType(); t)
        return t->getLayers();
    return 0;
}
int Thing::getNumPatternX() const {
    if (const auto t = getThingType(); t)
        return t->getNumPatternX();
    return 0;
}
int Thing::getNumPatternY() const {
    if (const auto t = getThingType(); t)
        return t->getNumPatternY();
    return 0;
}
int Thing::getNumPatternZ() const {
    if (const auto t = getThingType(); t)
        return t->getNumPatternZ();
    return 0;
}
int Thing::getAnimationPhases() const {
    if (const auto t = getThingType(); t)
        return t->getAnimationPhases();
    return 0;
}
int Thing::getGroundSpeed() const {
    if (const auto t = getThingType(); t)
        return t->getGroundSpeed();
    return 0;
}
int Thing::getMaxTextLength() const {
    if (const auto t = getThingType(); t)
        return t->getMaxTextLength();
    return 0;
}
int Thing::getMinimapColor() const {
    if (const auto t = getThingType(); t)
        return t->getMinimapColor();
    return 0;
}
int Thing::getLensHelp() const {
    if (const auto t = getThingType(); t)
        return t->getLensHelp();
    return 0;
}
int Thing::getElevation() const {
    if (const auto t = getThingType(); t)
        return t->getElevation();
    return 0;
}

int Thing::getClothSlot() {
    if (const auto t = getThingType(); t)
        return t->getClothSlot();
    return 0;
}

bool Thing::blockProjectile() const {
    if (const auto t = getThingType(); t)
        return t->blockProjectile();
    return false;
}

bool Thing::isContainer() const {
    if (const auto t = getThingType(); t)
        return t->isContainer();
    return false;
}

bool Thing::isTopGround() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isTopGround();
    return false;
}
bool Thing::isTopGroundBorder() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isTopGroundBorder();
    return false;
}
bool Thing::isSingleGround() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isSingleGround();
    return false;
}
bool Thing::isSingleGroundBorder() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isSingleGroundBorder();
    return false;
}
bool Thing::isGround() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isGround();
    return false;
}
bool Thing::isGroundBorder() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isGroundBorder();
    return false;
}
bool Thing::isOnBottom() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isOnBottom();
    return false;
}
bool Thing::isOnTop() {
    if (const auto t = getThingType(); !isCreature() && t)
        return t->isOnTop();
    return false;
}

bool Thing::isMarketable() {
    if (const auto t = getThingType(); t)
        return t->isMarketable();
    return false;
}
bool Thing::isStackable() {
    if (const auto t = getThingType(); t)
        return t->isStackable();
    return false;
}
bool Thing::isFluidContainer() {
    if (const auto t = getThingType(); t)
        return t->isFluidContainer();
    return false;
}
bool Thing::isForceUse() {
    if (const auto t = getThingType(); t)
        return t->isForceUse();
    return false;
}
bool Thing::isMultiUse() {
    if (const auto t = getThingType(); t)
        return t->isMultiUse();
    return false;
}
bool Thing::isWritable() {
    if (const auto t = getThingType(); t)
        return t->isWritable();
    return false;
}
bool Thing::isChargeable() {
    if (const auto t = getThingType(); t)
        return t->isChargeable();
    return false;
}
bool Thing::isWritableOnce() {
    if (const auto t = getThingType(); t)
        return t->isWritableOnce();
    return false;
}
bool Thing::isSplash() {
    if (const auto t = getThingType(); t)
        return t->isSplash();
    return false;
}
bool Thing::isNotWalkable() {
    if (const auto t = getThingType(); t)
        return t->isNotWalkable();
    return false;
}
bool Thing::isNotMoveable() {
    if (const auto t = getThingType(); t)
        return t->isNotMoveable();
    return false;
}
bool Thing::isMoveable() {
    if (const auto t = getThingType(); t)
        return !t->isNotMoveable();
    return false;
}
bool Thing::isNotPathable() {
    if (const auto t = getThingType(); t)
        return t->isNotPathable();
    return false;
}
bool Thing::isPickupable() {
    if (const auto t = getThingType(); t)
        return t->isPickupable();
    return false;
}
bool Thing::isHangable() {
    if (const auto t = getThingType(); t)
        return t->isHangable();
    return false;
}
bool Thing::isHookSouth() {
    if (const auto t = getThingType(); t)
        return t->isHookSouth();
    return false;
}
bool Thing::isHookEast() {
    if (const auto t = getThingType(); t)
        return t->isHookEast();
    return false;
}
bool Thing::isRotateable() {
    if (const auto t = getThingType(); t)
        return t->isRotateable();
    return false;
}
bool Thing::isDontHide() {
    if (const auto t = getThingType(); t)
        return t->isDontHide();
    return false;
}
bool Thing::isTranslucent() {
    if (const auto t = getThingType(); t)
        return t->isTranslucent();
    return false;
}
bool Thing::isLyingCorpse() {
    if (const auto t = getThingType(); t)
        return t->isLyingCorpse();
    return false;
}
bool Thing::isAnimateAlways() {
    if (const auto t = getThingType(); t)
        return t->isAnimateAlways();
    return false;
}
bool Thing::isFullGround() {
    if (const auto t = getThingType(); t)
        return t->isFullGround();
    return false;
}
bool Thing::isIgnoreLook() {
    if (const auto t = getThingType(); t)
        return t->isIgnoreLook();
    return false;
}
bool Thing::isCloth() {
    if (const auto t = getThingType(); t)
        return t->isCloth();
    return false;
}
bool Thing::isUsable() {
    if (const auto t = getThingType(); t)
        return t->isUsable();
    return false;
}
bool Thing::isWrapable() {
    if (const auto t = getThingType(); t)
        return t->isWrapable();
    return false;
}
bool Thing::isUnwrapable() {
    if (const auto t = getThingType(); t)
        return t->isUnwrapable();
    return false;
}
bool Thing::isTopEffect() {
    if (const auto t = getThingType(); t)
        return t->isTopEffect();
    return false;
}
bool Thing::isPodium() const {
    if (const auto t = getThingType(); t)
        return t->isPodium();
    return false;
}
bool Thing::isOpaque() const {
    if (const auto t = getThingType(); t)
        return t->isOpaque();
    return false;
}
bool Thing::isLoading() const {
    if (const auto t = getThingType(); t)
        return t->isLoading();
    return false;
}
bool Thing::isSingleDimension() const {
    if (const auto t = getThingType(); t)
        return t->isSingleDimension();
    return false;
}
bool Thing::isTall(const bool useRealSize) const {
    if (const auto t = getThingType(); t)
        return t->isTall(useRealSize);
    return false;
}

bool Thing::hasMiniMapColor() const {
    if (const auto t = getThingType(); t)
        return t->hasMiniMapColor();
    return false;
}
bool Thing::hasLensHelp() const {
    if (const auto t = getThingType(); t)
        return t->hasLensHelp();
    return false;
}
bool Thing::hasDisplacement() const {
    if (const auto t = getThingType(); t)
        return t->hasDisplacement();
    return false;
}
bool Thing::hasElevation() const {
    if (const auto t = getThingType(); t)
        return t->hasElevation();
    return false;
}
bool Thing::hasFloorChange() const
{
    if (const auto t = getThingType(); t)
        return t->hasFloorChange();
    return false;
}

bool Thing::hasAction() const {
    if (const auto t = getThingType(); t)
        return t->hasAction();
    return false;
}
bool Thing::hasWearOut() const {
    if (const auto t = getThingType(); t)
        return t->hasWearOut();
    return false;
}
bool Thing::hasClockExpire() const {
    if (const auto t = getThingType(); t)
        return t->hasClockExpire();
    return false;
}
bool Thing::hasExpire() const {
    if (const auto t = getThingType(); t)
        return t->hasExpire();
    return false;
}
bool Thing::hasExpireStop() const {
    if (const auto t = getThingType(); t)
        return t->hasExpireStop();
    return false;
}
bool Thing::hasAnimationPhases() const {
    if (const auto t = getThingType(); t)
        return t->getAnimationPhases() > 1;
    return false;
}
bool Thing::isDecoKit() const {
    if (const auto t = getThingType(); t)
        return t->isDecoKit();
    return false;
}
bool Thing::isAmmo() {
    if (const auto t = getThingType(); t)
        return t->isAmmo();
    return false;
}

bool Thing::isDualWield() {
    if (const auto t = getThingType(); t)
        return t->isDualWield();
    return false;
}

PLAYER_ACTION Thing::getDefaultAction() {
    if (const auto t = getThingType(); t)
        return t->getDefaultAction();
    return static_cast<PLAYER_ACTION>(0);
}

uint16_t Thing::getClassification() {
    if (const auto t = getThingType(); t)
        return t->getClassification();
    return 0;
}

bool Thing::canDraw(const Color& color) const {
    if (const auto t = getThingType(); t)
        return m_canDraw && m_clientId > 0 && color.aF() > Fw::MIN_ALPHA && t->getOpacity() > Fw::MIN_ALPHA;
    return false;
}

const Color& Thing::getMarkedColor() {
    if (m_markedColor == Color::white)
        return Color::white;

    m_markedColor.setAlpha(0.1f + std::abs(500 - g_clock.millis() % 1000) / 1000.0f);
    return m_markedColor;
}

const Color& Thing::getHighlightColor() {
    if (m_highlightColor == Color::white)
        return Color::white;

    m_highlightColor.setAlpha(0.1f + std::abs(500 - g_clock.millis() % 1000) / 1000.0f);
    return m_highlightColor;
}
