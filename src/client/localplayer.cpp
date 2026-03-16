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

#include "localplayer.h"

#include "container.h"
#include "game.h"
#include "item.h"
#include "map.h"
#include "tile.h"
#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"

void LocalPlayer::lockWalk(const uint16_t millis)
{
    m_walkLockExpiration = std::max<ticks_t>(m_walkLockExpiration, g_clock.millis() + millis);
}

bool LocalPlayer::canWalk(const bool ignoreLock)
{
    // Prevent movement if the player is dead
    if (isDead())
        return false;

    // Prevent movement if walking is locked, unless ignored
    if (isWalkLocked() && !ignoreLock)
        return false;

    // Ensure movement synchronization with the server
    if (g_game.getWalkMaxSteps() > 0) {
        if (m_preWalks.size() > g_game.getWalkMaxSteps())
            return false;
    } else if (getPosition() != getServerPosition())
        return false;

    // Handle ongoing movement cases
    if (isWalking()) {
        if (isAutoWalking()) return true;  // Allow auto-walking
        if (isPreWalking()) return false;  // Prevent pre-walk interruptions
    }

    // allow only if walk done, ex. diagonals may need additional ticks before taking another step
    return m_walkTimer.ticksElapsed() >= getStepDuration();
}

void LocalPlayer::walk(const Position& oldPos, const Position& newPos)
{
    m_autoWalkRetries = 0;

    if (isPreWalking() && newPos == m_preWalks.front()) {
        m_preWalks.pop_front();
        return;
    }

    cancelAdjustInvalidPosEvent();
    m_preWalks.clear();
    m_serverWalk = true;

    Creature::walk(oldPos, newPos);
}

void LocalPlayer::preWalk(Otc::Direction direction)
{
    m_lastMapDuration = -1;

    const auto& oldPos = getPosition();
    Creature::walk(oldPos, m_preWalks.emplace_back(oldPos.translatedToDirection(direction)));
    Creature::onPositionChange(getLastStepToPosition(), getLastStepFromPosition());
    registerAdjustInvalidPosEvent();
}

void LocalPlayer::onWalking() {
    if (isPreWalking()) {
        if (const auto& tile = g_map.getTile(getPosition())) {
            for (const auto& creature : tile->getWalkingCreatures()) {
                // Cancel pre-walk movement if the local player tries to walk on an unwalkable tile.
                if (creature.get() != this && creature->getPosition() == getPosition() && !creature->isPassable()) {
                    cancelWalk();
                    g_map.notificateTileUpdate(getPosition(), asLocalPlayer(), Otc::OPERATION_CLEAN);
                    break;
                }
            }
        }
    }
}

void LocalPlayer::registerAdjustInvalidPosEvent() {
    cancelAdjustInvalidPosEvent();
    m_adjustInvalidPosEvent = g_dispatcher.scheduleEvent([this, self = asLocalPlayer()] {
        m_preWalks.clear();
        g_game.resetMapUpdatedAt();
        m_adjustInvalidPosEvent = nullptr;
    }, std::min<int>(std::max<int>(getStepDuration(), g_game.getPing()) + 100, 1000));
}

void LocalPlayer::cancelAdjustInvalidPosEvent() {
    if (!m_adjustInvalidPosEvent) return;
    m_adjustInvalidPosEvent->cancel();
    m_adjustInvalidPosEvent = nullptr;
}

bool LocalPlayer::retryAutoWalk()
{
    if (!m_autoWalkDestination.isValid()) {
        return false;
    }

    g_game.stop();

    if (m_autoWalkRetries <= 3) {
        if (m_autoWalkContinueEvent)
            m_autoWalkContinueEvent->cancel();

        m_autoWalkContinueEvent = g_dispatcher.scheduleEvent(
            [thisPtr = asLocalPlayer(), autoWalkDest = m_autoWalkDestination] { thisPtr->autoWalk(autoWalkDest, true); }, 200
        );

        m_autoWalkRetries += 1;

        return true;
    }

    m_autoWalkDestination = {};
    return false;
}

void LocalPlayer::cancelWalk(const Otc::Direction direction)
{
    // only cancel client side walks
    if (isWalking() && isPreWalking())
        stopWalk();

    g_map.notificateCameraMove(m_walkOffset);

    if (m_adjustInvalidPosEvent) {
        m_adjustInvalidPosEvent->execute();
    }

    lockWalk();
    if (retryAutoWalk()) return;

    // turn to the cancel direction
    if (direction != Otc::InvalidDirection)
        setDirection(direction);

    callLuaField("onCancelWalk", direction);
}

bool LocalPlayer::autoWalk(const Position& destination, const bool retry)
{
    // reset state
    m_autoWalkDestination = {};
    m_lastAutoWalkPosition = {};
    if (m_autoWalkContinueEvent)
        m_autoWalkContinueEvent->cancel();
    m_autoWalkContinueEvent = nullptr;

    if (!retry)
        m_autoWalkRetries = 0;

    if (destination == m_position)
        return true;

    m_autoWalkDestination = destination;

    g_map.findPathAsync(m_position, destination, [self = asLocalPlayer()](const auto& result) {
        if (self->m_autoWalkDestination != result->destination)
            return;

        if (result->status != Otc::PathFindResultOk) {
            if (self->m_autoWalkRetries > 0 && self->m_autoWalkRetries <= 3) { // try again in 300, 700, 1200 ms if canceled by server
                self->m_autoWalkContinueEvent = g_dispatcher.scheduleEvent([self, capture0 = result->destination] { self->autoWalk(capture0, true); }, 200 + self->m_autoWalkRetries * 100);
                return;
            }
            self->m_autoWalkDestination = {};
            self->callLuaField("onAutoWalkFail", result->status);
            return;
        }

        if (result->path.size() > 127)
            result->path.resize(127);

        if (result->path.empty()) {
            self->m_autoWalkDestination = {};
            self->callLuaField("onAutoWalkFail", result->status);
            return;
        }

        if (self->m_autoWalkDestination != result->destination) {
            self->m_lastAutoWalkPosition = result->destination;
        }

        g_game.autoWalk(result->path, result->start);
    });

    if (!retry)
        lockWalk();

    return true;
}

bool LocalPlayer::isWalkLocked() { return m_walkLockExpiration != 0 && g_clock.millis() < m_walkLockExpiration; }

void LocalPlayer::stopAutoWalk()
{
    m_autoWalkDestination = {};
    m_lastAutoWalkPosition = {};
    m_knownCompletePath = false;

    if (m_autoWalkContinueEvent)
        m_autoWalkContinueEvent->cancel();
}

void LocalPlayer::terminateWalk()
{
    Creature::terminateWalk();
    m_serverWalk = false;
    callLuaField("onWalkFinish");
}

void LocalPlayer::onPositionChange(const Position& newPos, const Position& oldPos)
{
    if (isPreWalking())
        return;

    Creature::onPositionChange(newPos, oldPos);

    if (newPos == m_autoWalkDestination)
        stopAutoWalk();
    else if (m_autoWalkDestination.isValid() && newPos == m_lastAutoWalkPosition)
        autoWalk(m_autoWalkDestination);

    m_serverWalk = false;
}

void LocalPlayer::setStates(const uint64_t states)
{
    if (m_states == states)
        return;

    const uint64_t oldStates = m_states;
    m_states = states;

    if (isParalyzed() && isWalking() && m_serverWalk)
        updateWalk();

    callLuaField("onStatesChange", states, oldStates);
}

void LocalPlayer::setSkill(const Otc::Skill skillId, const uint16_t level, const uint16_t levelPercent)
{
    if (skillId >= Otc::LastSkill) {
        g_logger.traceError("invalid skill");
        return;
    }

    auto& skill = m_skills[skillId];

    const uint16_t oldLevel = skill.level;
    const uint16_t oldLevelPercent = skill.levelPercent;

    if (level == oldLevel && levelPercent == oldLevelPercent)
        return;

    skill.level = level;
    skill.levelPercent = levelPercent;

    callLuaField("onSkillChange", skillId, level, levelPercent, oldLevel, oldLevelPercent);
}

void LocalPlayer::setBaseSkill(const Otc::Skill skill, const uint16_t baseLevel)
{
    if (skill >= Otc::LastSkill) {
        g_logger.traceError("invalid skill");
        return;
    }

    const uint16_t oldBaseLevel = m_skills[skill].baseLevel;
    if (baseLevel == oldBaseLevel)
        return;

    m_skills[skill].baseLevel = baseLevel;

    callLuaField("onBaseSkillChange", skill, baseLevel, oldBaseLevel);
}

void LocalPlayer::setHealth(const uint32_t health, const uint32_t maxHealth)
{
    if (m_health != health || m_maxHealth != maxHealth) {
        const uint32_t oldHealth = m_health;
        const uint32_t oldMaxHealth = m_maxHealth;
        m_health = health;
        m_maxHealth = maxHealth;

        callLuaField("onHealthChange", health, maxHealth, oldHealth, oldMaxHealth);

        if (isDead()) {
            if (isPreWalking())
                stopWalk();
            lockWalk();
        }
    }
}

void LocalPlayer::setFreeCapacity(const uint32_t freeCapacity)
{
    if (m_freeCapacity == freeCapacity)
        return;

    const uint32_t oldFreeCapacity = m_freeCapacity;
    m_freeCapacity = freeCapacity;

    callLuaField("onFreeCapacityChange", freeCapacity, oldFreeCapacity);
}

void LocalPlayer::setTotalCapacity(const uint32_t totalCapacity)
{
    if (m_totalCapacity == totalCapacity)
        return;

    const uint32_t oldTotalCapacity = m_totalCapacity;
    m_totalCapacity = totalCapacity;

    callLuaField("onTotalCapacityChange", totalCapacity, oldTotalCapacity);
}

void LocalPlayer::setExperience(const uint64_t experience)
{
    if (m_experience == experience)
        return;

    const uint64_t oldExperience = m_experience;
    m_experience = experience;

    callLuaField("onExperienceChange", experience, oldExperience);
}

void LocalPlayer::setLevel(const uint16_t level, const uint8_t levelPercent)
{
    if (m_level == level && m_levelPercent == levelPercent)
        return;

    const uint16_t oldLevel = m_level;
    const uint8_t oldLevelPercent = m_levelPercent;

    m_level = level;
    m_levelPercent = levelPercent;

    callLuaField("onLevelChange", level, levelPercent, oldLevel, oldLevelPercent);
}

void LocalPlayer::setMana(const uint32_t mana, const uint32_t maxMana)
{
    if (m_mana == mana && m_maxMana == maxMana)
        return;

    const uint32_t oldMana = m_mana;
    const uint32_t oldMaxMana = m_maxMana;
    m_mana = mana;
    m_maxMana = maxMana;

    callLuaField("onManaChange", mana, maxMana, oldMana, oldMaxMana);
}

void LocalPlayer::setManaShield(const uint32_t manaShield, const uint32_t maxManaShield)
{
    if (m_manaShield == manaShield && m_maxManaShield == maxManaShield)
        return;

    const uint32_t oldManaShield = m_manaShield;
    const uint32_t oldMaxManaShield = m_maxManaShield;
    m_manaShield = manaShield;
    m_maxManaShield = maxManaShield;

    callLuaField("onManaShieldChange", manaShield, maxManaShield, oldManaShield, oldMaxManaShield);
}

void LocalPlayer::setMagicLevel(const uint16_t magicLevel, const uint16_t magicLevelPercent)
{
    if (m_magicLevel == magicLevel && m_magicLevelPercent == magicLevelPercent)
        return;

    const uint16_t oldMagicLevel = m_magicLevel;
    const uint16_t oldMagicLevelPercent = m_magicLevelPercent;

    m_magicLevel = magicLevel;
    m_magicLevelPercent = magicLevelPercent;

    callLuaField("onMagicLevelChange", magicLevel, magicLevelPercent, oldMagicLevel, oldMagicLevelPercent);
}

void LocalPlayer::setBaseMagicLevel(const uint16_t baseMagicLevel)
{
    if (m_baseMagicLevel == baseMagicLevel)
        return;

    const uint16_t oldBaseMagicLevel = m_baseMagicLevel;
    m_baseMagicLevel = baseMagicLevel;

    callLuaField("onBaseMagicLevelChange", baseMagicLevel, oldBaseMagicLevel);
}

void LocalPlayer::setSoul(const uint8_t soul)
{
    if (m_soul == soul)
        return;

    const uint8_t oldSoul = m_soul;
    m_soul = soul;

    callLuaField("onSoulChange", soul, oldSoul);
}

void LocalPlayer::setStamina(const uint16_t stamina)
{
    if (m_stamina == stamina)
        return;

    const uint16_t oldStamina = m_stamina;
    m_stamina = stamina;

    callLuaField("onStaminaChange", stamina, oldStamina);
}

void LocalPlayer::setInventoryItem(const Otc::InventorySlot inventory, const ItemPtr& item)
{
    if (inventory >= Otc::LastInventorySlot) {
        g_logger.traceError("invalid slot");
        return;
    }

    if (m_inventoryItems[inventory] == item)
        return;

    const auto& oldItem = m_inventoryItems[inventory];
    m_inventoryItems[inventory] = item;

    callLuaField("onInventoryChange", inventory, item, oldItem);
}

void LocalPlayer::setInventoryCountCache(std::map<std::pair<uint16_t, uint8_t>, uint32_t> counts)
{
    m_inventoryCountCache = std::move(counts);
}

bool LocalPlayer::hasEquippedItemId(const uint16_t itemId, const uint8_t tier)
{
    if (itemId == 0)
        return false;

    for (const auto& item : m_inventoryItems) {
        if (!item)
            continue;

        if (item->getId() != itemId)
            continue;

        if (item->getTier() != tier)
            continue;

        return true;
    }

    return false;
}

uint32_t LocalPlayer::getInventoryCount(const uint16_t itemId, const uint8_t tier)
{
    if (std::cmp_equal(itemId, 0))
        return 0;

    const auto key = std::make_pair(itemId, tier);
    const auto it = m_inventoryCountCache.find(key);
    if (it != m_inventoryCountCache.end()) {
        return it->second;
    }

    uint32_t total = 0;

    const auto accumulate = [&](const ItemPtr& item) {
        if (item && std::cmp_equal(item->getId(), itemId) && item->getTier() == tier) {
            total += item->getCount();
        }
    };

    for (const auto& item : m_inventoryItems)
        accumulate(item);

    for (const auto& [containerId, container] : g_game.getContainers()) {
        if (!container)
            continue;

        for (const auto& item : container->getItems())
            accumulate(item);
    }

    if (const uint64_t maxUint32 = std::numeric_limits<uint32_t>::max(); total > maxUint32) {
        total = maxUint32;
    }

    return total;
}

void LocalPlayer::setPremium(const bool premium)
{
    if (m_premium == premium)
        return;

    m_premium = premium;

    callLuaField("onPremiumChange", premium);
}

void LocalPlayer::setRegenerationTime(const uint16_t regenerationTime)
{
    if (m_regenerationTime == regenerationTime)
        return;

    const uint16_t oldRegenerationTime = m_regenerationTime;
    m_regenerationTime = regenerationTime;

    callLuaField("onRegenerationChange", regenerationTime, oldRegenerationTime);
}

void LocalPlayer::setOfflineTrainingTime(const uint16_t offlineTrainingTime)
{
    if (m_offlineTrainingTime == offlineTrainingTime)
        return;

    const uint16_t oldOfflineTrainingTime = m_offlineTrainingTime;
    m_offlineTrainingTime = offlineTrainingTime;

    callLuaField("onOfflineTrainingChange", offlineTrainingTime, oldOfflineTrainingTime);
}

void LocalPlayer::setSpells(const std::vector<uint16_t>& spells)
{
    if (m_spells == spells)
        return;

    const std::vector<uint16_t> oldSpells = m_spells;
    m_spells = spells;

    callLuaField("onSpellsChange", spells, oldSpells);
}

void LocalPlayer::setBlessings(const uint16_t blessings)
{
    if (blessings == m_blessings)
        return;

    const uint16_t oldBlessings = m_blessings;
    m_blessings = blessings;

    callLuaField("onBlessingsChange", blessings, oldBlessings);
}

void LocalPlayer::takeScreenshot(const uint8_t type)
{
    g_lua.callGlobalField("LocalPlayer", "onTakeScreenshot", type);
}

void LocalPlayer::setResourceBalance(const Otc::ResourceTypes_t type, const uint64_t value)
{
    const uint64_t oldBalance = getResourceBalance(type);
    if (value == oldBalance)
        return;

    m_resourcesBalance[type] = value;
    g_lua.callGlobalField("g_game", "onResourcesBalanceChange", value, oldBalance, type);
}

bool LocalPlayer::hasSight(const Position& pos)
{
    return m_position.isInRange(pos, g_map.getAwareRange().left - 1, g_map.getAwareRange().top - 1);
}

void LocalPlayer::setFlatDamageHealing(uint16_t flatBonus)
{
    if (m_flatDamageHealing == flatBonus)
        return;

    const uint16_t oldFlatBonus = m_flatDamageHealing;
    m_flatDamageHealing = flatBonus;

    callLuaField("onFlatDamageHealingChange", flatBonus);
}

void LocalPlayer::setAttackInfo(uint16_t attackValue, uint8_t attackElement)
{
    if (m_attackValue == attackValue && m_attackElement == attackElement)
        return;

    const uint16_t oldAttackValue = m_attackValue;
    const uint8_t oldAttackElement = m_attackElement;
    m_attackValue = attackValue;
    m_attackElement = attackElement;

    callLuaField("onAttackInfoChange", attackValue, attackElement);
}

void LocalPlayer::setConvertedDamage(double convertedDamage, uint8_t convertedElement)
{
    if (m_convertedDamage == convertedDamage && m_convertedElement == convertedElement)
        return;

    const double oldConvertedDamage = m_convertedDamage;
    const uint8_t oldConvertedElement = m_convertedElement;
    m_convertedDamage = convertedDamage;
    m_convertedElement = convertedElement;

    callLuaField("onConvertedDamageChange", convertedDamage, convertedElement);
}

void LocalPlayer::setImbuements(double lifeLeech, double manaLeech, double critChance, double critDamage, double onslaught)
{
    if (m_lifeLeech == lifeLeech && m_manaLeech == manaLeech && m_critChance == critChance &&
        m_critDamage == critDamage && m_onslaught == onslaught)
        return;

    const double oldLifeLeech = m_lifeLeech;
    const double oldManaLeech = m_manaLeech;
    const double oldCritChance = m_critChance;
    const double oldCritDamage = m_critDamage;
    const double oldOnslaught = m_onslaught;

    m_lifeLeech = lifeLeech;
    m_manaLeech = manaLeech;
    m_critChance = critChance;
    m_critDamage = critDamage;
    m_onslaught = onslaught;

    callLuaField("onImbuementsChange", lifeLeech, manaLeech, critChance, critDamage, onslaught);
}

void LocalPlayer::setDefenseInfo(uint16_t defense, uint16_t armor, double mitigation, double dodge, uint16_t damageReflection)
{
    if (m_defense == defense && m_armor == armor && m_mitigation == mitigation &&
        m_dodge == dodge && m_damageReflection == damageReflection)
        return;

    const uint16_t oldDefense = m_defense;
    const uint16_t oldArmor = m_armor;
    const double oldMitigation = m_mitigation;
    const double oldDodge = m_dodge;
    const uint16_t oldDamageReflection = m_damageReflection;

    m_defense = defense;
    m_armor = armor;
    m_mitigation = mitigation;
    m_dodge = dodge;
    m_damageReflection = damageReflection;

    callLuaField("onDefenseInfoChange", defense, armor, mitigation, dodge, damageReflection);
}

void LocalPlayer::setCombatAbsorbValues(const std::map<uint8_t, double>& absorbValues)
{
    if (m_combatAbsorbValues == absorbValues)
        return;

    const auto oldAbsorbValues = m_combatAbsorbValues;
    m_combatAbsorbValues = absorbValues;

    callLuaField("onCombatAbsorbValuesChange", absorbValues);
}

void LocalPlayer::setForgeBonuses(double momentum, double transcendence, double amplification)
{
    if (m_momentum == momentum && m_transcendence == transcendence && m_amplification == amplification)
        return;

    const double oldMomentum = m_momentum;
    const double oldTranscendence = m_transcendence;
    const double oldAmplification = m_amplification;

    m_momentum = momentum;
    m_transcendence = transcendence;
    m_amplification = amplification;

    callLuaField("onForgeBonusesChange", momentum, transcendence, amplification);
}

void LocalPlayer::setExperienceRate(Otc::ExperienceRate_t type, uint16_t value)
{
    if (m_experienceRates[type] == value)
        return;

    const uint16_t oldValue = m_experienceRates[type];
    m_experienceRates[type] = value;

    callLuaField("onExperienceRateChange", type, value);
}

void LocalPlayer::setStoreExpBoostTime(uint16_t value)
{
    if (m_storeExpBoostTime == value)
        return;

    m_storeExpBoostTime = value;
}

void LocalPlayer::setHarmony(const uint8_t harmony)
{
    const uint8_t oldHarmony = m_harmony;
    m_harmony = harmony;

    callLuaField("onHarmonyChange", harmony, oldHarmony);
}

void LocalPlayer::setSerene(const bool serene)
{
    const bool oldSerene = m_serene;
    m_serene = serene;

    callLuaField("onSereneChange", serene, oldSerene);
}