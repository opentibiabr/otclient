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

#ifdef FRAMEWORK_EDITOR

#include <framework/luaengine/luaobject.h>

#include "declarations.h"
#include "outfit.h"

enum CreatureRace : uint8_t
{
    CreatureRaceNone = 0,
    CreatureRaceNpc = 1,
    CreatureRaceMonster = 2
};

class Spawn : public LuaObject
{
public:
    Spawn() = default;
    Spawn(int32_t radius) { setRadius(radius); }

    void setRadius(int32_t r) { m_radius = r; }
    int32_t getRadius() { return m_radius; }

    void setCenterPos(const Position& pos) { m_centerPos = pos; }
    Position getCenterPos() { return m_centerPos; }

    std::vector<CreatureTypePtr> getCreatures();
    void addCreature(const Position& placePos, const CreatureTypePtr& cType);
    void removeCreature(const Position& pos);
    void clear() { m_creatures.clear(); }

protected:
    void load(pugi::xml_node node);
    void save(pugi::xml_node node);

private:
    CreatureMap m_creatures;
    friend class CreatureManager;

    int32_t m_radius;
    Position m_centerPos;
};

class CreatureType : public LuaObject
{
public:
    CreatureType() = default;
    CreatureType(const std::string& name) { setName(name); }

    void setSpawnTime(int32_t spawnTime) { m_spawnTime = spawnTime; }
    int32_t getSpawnTime() { return m_spawnTime; }

    void setName(const std::string& name) { m_name = name; }
    std::string getName() { return m_name; }

    void setOutfit(const Outfit& o) { m_outfit = o; }
    Outfit getOutfit() { return m_outfit; }

    void setDirection(Otc::Direction dir) { m_direction = dir; }
    Otc::Direction getDirection() { return m_direction; }

    void setRace(CreatureRace race) { m_race = race; }
    CreatureRace getRace() { return m_race; }

    CreaturePtr cast();

private:
    int32_t m_spawnTime{ 0 };
    std::string m_name;
    Outfit m_outfit;
    Otc::Direction m_direction{ Otc::InvalidDirection };
    CreatureRace m_race{ CreatureRaceNone };
};

class CreatureManager
{
public:
    CreatureManager();
    void clear() { m_creatures.clear(); }
    void clearSpawns();
    void terminate();

    void loadMonsters(const std::string& file);
    void loadSingleCreature(const std::string& file);
    void loadNpcs(const std::string& folder);
    void loadCreatureBuffer(const std::string& buffer);
    void loadSpawns(const std::string& fileName);
    void saveSpawns(const std::string& fileName);

    const CreatureTypePtr& getCreatureByName(std::string name);
    const CreatureTypePtr& getCreatureByLook(int look);

    std::vector<SpawnPtr> getSpawns();
    SpawnPtr getSpawn(const Position& centerPos);
    SpawnPtr getSpawnForPlacePos(const Position& pos);
    SpawnPtr addSpawn(const Position& centerPos, int radius);
    void deleteSpawn(const SpawnPtr& spawn);

    bool isLoaded() { return m_loaded; }
    bool isSpawnLoaded() { return m_spawnLoaded; }

    const std::vector<CreatureTypePtr>& getCreatures() { return m_creatures; }

protected:
    void internalLoadCreatureBuffer(const pugi::xml_node attrib, const CreatureTypePtr& m);

private:
    std::vector<CreatureTypePtr> m_creatures;
    std::unordered_map<Position, SpawnPtr, Position::Hasher> m_spawns;
    bool m_loaded{ false };
    bool m_spawnLoaded{ false };
    CreatureTypePtr m_nullCreature;
};

extern CreatureManager g_creatures;

#endif
