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

#include "player.h"

 // @bindclass
class LocalPlayer final : public Player
{
public:
    void unlockWalk() { m_walkLockExpiration = 0; }
    void lockWalk(uint16_t millis = 250);
    bool isWalkLocked();
    void stopAutoWalk();

    bool autoWalk(const Position& destination, bool retry = false);
    bool canWalk(bool ignoreLock = false);

    void setStates(uint64_t states);
    void setSkill(Otc::Skill skillId, uint16_t level, uint16_t levelPercent);
    void setBaseSkill(Otc::Skill skill, uint16_t baseLevel);
    void setHealth(uint32_t health, uint32_t maxHealth);
    void setFreeCapacity(uint32_t freeCapacity);
    void setTotalCapacity(uint32_t totalCapacity);
    void setExperience(uint64_t experience);
    void setLevel(uint16_t level, uint8_t levelPercent);
    void setMana(uint32_t mana, uint32_t maxMana);
    void setManaShield(uint32_t manaShield, uint32_t maxManaShield);
    void setMagicLevel(uint16_t magicLevel, uint16_t magicLevelPercent);
    void setBaseMagicLevel(uint16_t baseMagicLevel);
    void setSoul(uint8_t soul);
    void setStamina(uint16_t stamina);
    void setKnown(const bool known) { m_known = known; }
    void setPendingGame(const bool pending) { m_pending = pending; }
    void setInventoryItem(Otc::InventorySlot inventory, const ItemPtr& item);
    void setInventoryCountCache(std::map<std::pair<uint16_t, uint8_t>, uint32_t> counts);
    void setPremium(bool premium);
    void setRegenerationTime(uint16_t regenerationTime);
    void setOfflineTrainingTime(uint16_t offlineTrainingTime);
    void setSpells(const std::vector<uint16_t>& spells);
    void setBlessings(uint16_t blessings);
    void setResourceBalance(Otc::ResourceTypes_t type, uint64_t value);
    void takeScreenshot(uint8_t type);
    void setFlatDamageHealing(uint16_t flatBonus);
    void setAttackInfo(uint16_t attackValue, uint8_t attackElement);
    void setConvertedDamage(double convertedDamage, uint8_t convertedElement);
    void setImbuements(double lifeLeech, double manaLeech, double critChance, double critDamage, double onslaught);
    void setDefenseInfo(uint16_t defense, uint16_t armor, double mitigation, double dodge, uint16_t damageReflection);
    void setCombatAbsorbValues(const std::map<uint8_t, double>& absorbValues);
    void setForgeBonuses(double momentum, double transcendence, double amplification);
    void setExperienceRate(Otc::ExperienceRate_t type, uint16_t value);
    void setStoreExpBoostTime(uint16_t value);
    void setHarmony(uint8_t harmony);
    void setSerene(bool serene);

    uint32_t getFreeCapacity() { return m_freeCapacity; }
    uint32_t getTotalCapacity() { return m_totalCapacity; }

    uint16_t getMagicLevel() { return m_magicLevel; }
    uint16_t getMagicLevelPercent() { return m_magicLevelPercent; }
    uint16_t getBaseMagicLevel() { return m_baseMagicLevel; }
    uint8_t getSoul() { return m_soul; }
    uint8_t getLevelPercent() { return m_levelPercent; }
    uint8_t getHarmony() { return m_harmony; }

    uint16_t getLevel() { return m_level; }
    uint16_t getSkillLevel(const Otc::Skill skill) { return m_skills[skill].level; }
    uint16_t getSkillBaseLevel(const Otc::Skill skill) { return m_skills[skill].baseLevel; }
    uint16_t getSkillLevelPercent(const Otc::Skill skill) { return m_skills[skill].levelPercent; }
    uint16_t getStamina() { return m_stamina; }
    uint16_t getBlessings() { return m_blessings; }
    uint16_t getRegenerationTime() { return m_regenerationTime; }
    uint16_t getOfflineTrainingTime() { return m_offlineTrainingTime; }
    uint16_t getStoreExpBoostTime() { return m_storeExpBoostTime; }

    auto getStates() { return m_states; }
    uint32_t getMana() { return m_mana; }
    uint32_t getMaxMana() { return m_maxMana; }
    uint32_t getManaShield() { return m_manaShield; }
    uint32_t getMaxManaShield() { return m_maxManaShield; }
    uint32_t getHealth() { return m_health; }
    uint32_t getMaxHealth() { return m_maxHealth; }
    uint64_t getExperience() { return m_experience; }

    const std::vector<uint16_t>& getSpells() { return m_spells; }
    ItemPtr getInventoryItem(const Otc::InventorySlot inventory) { return m_inventoryItems[inventory]; }
    bool hasEquippedItemId(uint16_t itemId, uint8_t tier);
    uint32_t getInventoryCount(uint16_t itemId, uint8_t tier);

    uint64_t getResourceBalance(const Otc::ResourceTypes_t type)
    {
        const auto it = m_resourcesBalance.find(type);
        return it != m_resourcesBalance.end() ? it->second : 0;
    }

    uint64_t getTotalMoney()
    {
        const uint64_t bankBalance = getResourceBalance(Otc::RESOURCE_BANK_BALANCE);
        const uint64_t equippedBalance = getResourceBalance(Otc::RESOURCE_GOLD_EQUIPPED);
        return bankBalance + equippedBalance;
    }

    bool hasSight(const Position& pos);
    bool isKnown() { return m_known; }
    bool isServerWalking() { return m_serverWalk; }
    bool isPreWalking() { return !m_preWalks.empty(); }

    bool isSupplyStashAvailable() const { return m_isSupplyStashAvailable; }
    void setSupplyStashAvailable(bool available) {
        m_isSupplyStashAvailable = available;
    }

    bool isAutoWalking() { return m_autoWalkDestination.isValid(); }
    bool isPremium() { return m_premium; }
    bool isPendingGame() const { return m_pending; }
    bool isParalyzed() const { return (m_states & Otc::IconParalyze) == Otc::IconParalyze; }
    bool isSerene() { return m_serene; }

    LocalPlayerPtr asLocalPlayer() { return static_self_cast<LocalPlayer>(); }
    bool isLocalPlayer() const override { return true; }

    void onPositionChange(const Position& newPos, const Position& oldPos) override;

    void preWalk(Otc::Direction direction);

    Position getPosition() override { return isPreWalking() ? m_preWalks.back() : m_position; }
    void resetPreWalk() { m_preWalks.clear(); }
    auto getPreWalkingSize() { return m_preWalks.size(); }


private:
    struct Skill
    {
        uint16_t level{ 0 };
        uint16_t baseLevel{ 0 };
        uint16_t levelPercent{ 0 };
    };

    void onWalking() override;

    void walk(const Position& oldPos, const Position& newPos) override;
    void terminateWalk() override;
    void cancelWalk(Otc::Direction direction = Otc::InvalidDirection);
    void cancelAdjustInvalidPosEvent();
    void registerAdjustInvalidPosEvent();

    bool retryAutoWalk();

    // walk related
    Position m_lastAutoWalkPosition;
    Position m_autoWalkDestination;
    std::deque<Position> m_preWalks;

    ScheduledEventPtr m_adjustInvalidPosEvent;
    ScheduledEventPtr m_autoWalkContinueEvent;
    ticks_t m_walkLockExpiration{ 0 };

    bool m_knownCompletePath{ false };
    bool m_premium{ false };
    bool m_known{ false };
    bool m_pending{ false };
    bool m_serverWalk{ false };
    bool m_serene{ false };

    bool m_isSupplyStashAvailable{ false };

    ItemPtr m_inventoryItems[Otc::LastInventorySlot];

    std::array<Skill, Otc::LastSkill> m_skills;
    std::vector<uint16_t> m_spells;

    stdext::map<Otc::ResourceTypes_t, uint64_t> m_resourcesBalance;
    std::map<uint8_t, double> m_combatAbsorbValues;
    std::map<Otc::ExperienceRate_t, uint16_t> m_experienceRates;
    std::map<std::pair<uint16_t, uint8_t>, uint32_t> m_inventoryCountCache;

    uint8_t m_autoWalkRetries{ 0 };

    uint64_t m_states{ 0 };
    uint8_t m_vocation{ 0 };
    uint16_t m_blessings{ Otc::BlessingNone };

    uint32_t m_freeCapacity{ 0 };
    uint32_t m_totalCapacity{ 0 };

    uint32_t m_health{ 0 };
    uint32_t m_maxHealth{ 0 };
    uint64_t m_experience{ 0 };
    uint16_t m_level{ 0 };
    uint8_t m_levelPercent{ 0 };
    uint32_t m_mana{ 0 };
    uint32_t m_maxMana{ 0 };
    uint32_t m_manaShield{ 0 };
    uint32_t m_maxManaShield{ 0 };
    uint16_t m_magicLevel{ 0 };
    uint16_t m_magicLevelPercent{ 0 };
    uint16_t m_baseMagicLevel{ 0 };
    uint8_t m_soul{ 0 };
    uint16_t m_stamina{ 0 };
    uint16_t m_regenerationTime{ 0 };
    uint16_t m_offlineTrainingTime{ 0 };
    uint16_t m_storeExpBoostTime{ 0 };

    uint8_t m_attackElement{ 0 };
    uint8_t m_convertedElement{ 0 };
    uint8_t m_harmony{ 0 };

    uint16_t m_flatDamageHealing{ 0 };
    uint16_t m_attackValue{ 0 };
    uint16_t m_defense{ 0 };
    uint16_t m_armor{ 0 };
    uint16_t m_damageReflection{ 0 };

    double m_convertedDamage{ 0 };
    double m_lifeLeech{ 0 };
    double m_manaLeech{ 0 };
    double m_critChance{ 0 };
    double m_critDamage{ 0 };
    double m_onslaught{ 0 };
    double m_mitigation{ 0 };
    double m_dodge{ 0 };
    double m_momentum{ 0 };
    double m_transcendence{ 0 };
    double m_amplification{ 0 };

    friend class Game;
    friend class Creature;
};
