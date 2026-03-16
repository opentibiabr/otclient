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

#ifdef FRAMEWORK_EDITOR
#include "houses.h"

#include "map.h"

#include <framework/core/resourcemanager.h>

#include "item.h"
#include "tile.h"

HouseManager g_houses;

House::House(uint32_t hId, const std::string_view name, const Position& pos)
{
    setId(hId);
    setName(name);
    if (pos.isValid())
        setEntry(pos);
}

void House::setTile(const TilePtr& tile)
{
    tile->setFlag(TILESTATE_HOUSE);
    tile->setHouseId(getId());
    m_tiles.emplace(tile->getPosition(), tile);
}

TilePtr House::getTile(const Position& position)
{
    const auto iter = m_tiles.find(position);
    if (iter != m_tiles.end())
        return iter->second;
    return nullptr;
}

void House::addDoor(const ItemPtr& door)
{
    if (!door) return;
    door->setDoorId(m_lastDoorId);
    m_doors[++m_lastDoorId] = door;
}

void House::removeDoor(const ItemPtr& door) { removeDoorById(door->getDoorId()); }

void House::removeDoorById(uint32_t doorId)
{
    if (doorId >= m_lastDoorId)
        throw Exception("Failed to remove door of id {} (would overflow), max id: {}", doorId, m_lastDoorId);
    m_doors[doorId] = nullptr;
}

void House::load(const pugi::xml_node& node)
{
    std::string name = node.attribute("name").as_string();
    if (name.empty())
        name = fmt::format("Unnamed house #{}", getId());

    setName(name);
    setRent(node.attribute("rent").as_uint());
    setSize(node.attribute("size").as_uint());
    setTownId(node.attribute("townid").as_uint());
    m_isGuildHall = node.attribute("guildhall").as_bool();

    Position entryPos;
    entryPos.x = node.attribute("entryx").as_int();
    entryPos.y = node.attribute("entryy").as_int();
    entryPos.z = node.attribute("entryz").as_int();
    setEntry(entryPos);
}

void House::save(pugi::xml_node& node)
{
    node.append_attribute("name").set_value(getName().c_str());
    node.append_attribute("houseid").set_value(getId());

    const Position entry = getEntry();
    node.append_attribute("entryx").set_value(entry.x);
    node.append_attribute("entryy").set_value(entry.y);
    node.append_attribute("entryz").set_value(entry.z);

    node.append_attribute("rent").set_value(getRent());
    node.append_attribute("townid").set_value(getTownId());
    node.append_attribute("size").set_value(getSize());
    node.append_attribute("guildhall").set_value(m_isGuildHall);
}

HouseManager::HouseManager()
= default;

void HouseManager::addHouse(const HousePtr& house)
{
    if (findHouse(house->getId()) == m_houses.end())
        m_houses.push_back(house);
}

void HouseManager::removeHouse(uint32_t houseId)
{
    const auto it = findHouse(houseId);
    if (it != m_houses.end())
        m_houses.erase(it);
}

HousePtr HouseManager::getHouse(uint32_t houseId)
{
    const auto it = findHouse(houseId);
    return it != m_houses.end() ? *it : nullptr;
}

HousePtr HouseManager::getHouseByName(const std::string_view name)
{
    const auto it = std::find_if(m_houses.begin(), m_houses.end(),
                                 [=](const HousePtr& house) -> bool { return house->getName() == name; });
    return it != m_houses.end() ? *it : nullptr;
}

void HouseManager::load(const std::string& fileName)
{
    try {
        pugi::xml_document doc;
        doc.load_string(g_resources.readFileContents(fileName).c_str());
        pugi::xml_node root = doc.child("houses");

        if (!root)
            throw Exception("invalid root tag name");

        for (pugi::xml_node elem = root.child("house"); elem; elem = elem.next_sibling("house")) {
            const auto houseId = elem.child("houseid").text().as_uint();
            HousePtr house = getHouse(houseId);
            if (!house)
                house = std::make_shared<House>(houseId), addHouse(house);

            house->load(elem);
        }
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}': {}", fileName, e.what());
    }
    sort();
}

void HouseManager::save(const std::string& fileName)
{
    try {
        pugi::xml_document doc;
        auto decl = doc.append_child(pugi::node_declaration);
        decl.append_attribute("version") = "1.0";
        decl.append_attribute("encoding") = "UTF-8";
        decl.append_attribute("standalone") = "";

        auto root = doc.append_child("houses");

        for (const auto& house : m_houses) {
            auto elem = root.append_child("house");
            house->save(elem);
        }

        if (!doc.save_file(("data" + fileName).c_str(), "\t", pugi::format_default, pugi::encoding_utf8)) {
            throw Exception("failed to save houses XML {}", fileName);
        }
    } catch (const std::exception& e) {
        g_logger.error("Failed to save '{}': {}", fileName, e.what());
    }
}

HouseList HouseManager::filterHouses(uint32_t townId)
{
    HouseList ret;
    for (const HousePtr& house : m_houses)
        if (house->getTownId() == townId)
            ret.push_back(house);
    return ret;
}

HouseList::iterator HouseManager::findHouse(uint32_t houseId)
{
    return std::find_if(m_houses.begin(), m_houses.end(),
                        [=](const HousePtr& house) -> bool { return house->getId() == houseId; });
}

void HouseManager::sort()
{
    m_houses.sort([](const HousePtr& lhs, const HousePtr& rhs) { return lhs->getName() < rhs->getName(); });
}

#endif
/* vim: set ts=4 sw=4 et: */