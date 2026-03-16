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
#include "declarations.h"
#include <framework/luaengine/luaobject.h>

class House : public LuaObject
{
public:
    House() = default;
    House(uint32_t hId, const std::string_view name = "", const Position& pos = {});
    ~House() override { m_tiles.clear(); }

    void setTile(const TilePtr& tile);
    TilePtr getTile(const Position& pos);

    void setName(const std::string_view name) { m_name = std::string{ name }; }
    std::string getName() { return m_name; }

    void setId(uint32_t hId) { m_id = hId; }
    uint32_t getId() { return m_id; }

    void setTownId(uint32_t tid) { m_townId = tid; }
    uint32_t getTownId() { return m_townId; }

    void setSize(uint32_t s) { m_size = s; }
    uint32_t getSize() { return m_size; }

    void setRent(uint32_t r) { m_rent = r; }
    uint32_t getRent() { return m_rent; }

    void setEntry(const Position& p) { m_entry = p; }
    Position getEntry() { return m_entry; }

    void addDoor(const ItemPtr& door);
    void removeDoor(const ItemPtr& door);
    void removeDoorById(uint32_t doorId);

protected:
    void load(const pugi::xml_node& node);
    void save(pugi::xml_node& node);

private:
    stdext::map<Position, TilePtr, Position::Hasher> m_tiles;
    ItemVector m_doors;
    uint32_t m_lastDoorId{ 0 };
    uint32_t m_id{ 0 };
    uint32_t m_townId{ 0 };
    uint32_t m_size{ 0 };
    uint32_t m_rent{ 0 };
    Position m_entry;

    bool m_isGuildHall{ false };

    std::string m_name;

    friend class HouseManager;
};

class HouseManager
{
public:
    HouseManager();

    void addHouse(const HousePtr& house);
    void removeHouse(uint32_t houseId);
    HousePtr getHouse(uint32_t houseId);
    HousePtr getHouseByName(const std::string_view name);

    void load(const std::string& fileName);
    void save(const std::string& fileName);

    void sort();
    void clear() { m_houses.clear(); }
    HouseList getHouseList() { return m_houses; }
    HouseList filterHouses(uint32_t townId);

private:
    HouseList m_houses;

protected:
    HouseList::iterator findHouse(uint32_t houseId);
};

extern HouseManager g_houses;

#endif
