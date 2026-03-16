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

#include "creatures.h"
#include "creature.h"
#include "map.h"

#include <framework/core/resourcemanager.h>

CreatureManager g_creatures;

static bool isInZone(const Position& pos/* placePos*/,
                     const Position& centerPos,
                     int radius)
{
    if (radius == -1)
        return true;

    return ((pos.x >= centerPos.x - radius) && (pos.x <= centerPos.x + radius) &&
            (pos.y >= centerPos.y - radius) && (pos.y <= centerPos.y + radius));
}

void CreatureManager::terminate()
{
    clearSpawns();
    clear();
    m_nullCreature = nullptr;
}

void Spawn::load(pugi::xml_node node)
{
    Position centerPos;
    centerPos.x = node.child("centerx").text().as_int();
    centerPos.y = node.child("centery").text().as_int();
    centerPos.z = node.child("centerz").text().as_int();

    setCenterPos(centerPos);
    setRadius(node.child("radius").text().as_int());

    CreatureTypePtr cType;
    for (pugi::xml_node cNode = node.child("monster"); cNode; cNode = cNode.next_sibling()) {
        if (cNode.name() != std::string("monster") && cNode.name() != std::string("npc"))
            throw Exception("invalid spawn-subnode {}", cNode.name());

        std::string cName = cNode.attribute("name").as_string();
        stdext::tolower(cName);
        stdext::trim(cName);
        stdext::ucwords(cName);

        if (!(cType = g_creatures.getCreatureByName(cName)))
            continue;

        cType->setSpawnTime(cNode.attribute("spawntime").as_int());
        Otc::Direction dir = Otc::North;
        auto dir_ = cNode.attribute("direction").as_int();
        if (dir_ >= Otc::East && dir_ <= Otc::West)
            dir = static_cast<Otc::Direction>(dir_);

        cType->setDirection(dir);

        Position placePos;
        placePos.x = centerPos.x + cNode.attribute("x").as_int();
        placePos.y = centerPos.y + cNode.attribute("y").as_int();
        placePos.z = cNode.attribute("z").as_int();

        cType->setRace(cNode.name() == std::string("npc") ? CreatureRaceNpc : CreatureRaceMonster);
        addCreature(placePos, cType);
    }
}

void Spawn::save(pugi::xml_node node)
{
    const Position& c = getCenterPos();
    node.append_child("centerx").append_child(pugi::node_pcdata).set_value(std::to_string(c.x).c_str());
    node.append_child("centery").append_child(pugi::node_pcdata).set_value(std::to_string(c.y).c_str());
    node.append_child("centerz").append_child(pugi::node_pcdata).set_value(std::to_string(c.z).c_str());

    node.append_child("radius").append_child(pugi::node_pcdata).set_value(std::to_string(getRadius()).c_str());

    for (const auto& [placePos, creature] : m_creatures) {
        auto creatureNode = node.append_child(creature->getRace() == CreatureRaceNpc ? "npc" : "monster");

        if (!creatureNode)
            throw Exception("Spawn::save: Ran out of memory while allocating XML element!  Terminating now.");

        creatureNode.append_attribute("name") = creature->getName().c_str();
        creatureNode.append_attribute("spawntime") = creature->getSpawnTime();
        creatureNode.append_attribute("direction") = static_cast<int>(creature->getDirection());

        assert(placePos.isValid());

        creatureNode.append_attribute("x") = placePos.x - c.x;
        creatureNode.append_attribute("y") = placePos.y - c.y;
        creatureNode.append_attribute("z") = placePos.z;
    }
}

void Spawn::addCreature(const Position& placePos, const CreatureTypePtr& cType)
{
    const Position& centerPos = getCenterPos();
    const int m_radius = getRadius();
    if (!isInZone(placePos, centerPos, m_radius)) {
        g_logger.warning("cannot place creature at {} (spawn's center position: {}, spawn radius: {}) (increment radius)", placePos, centerPos,
                         m_radius);
        return;
    }

    g_map.addThing(cType->cast(), placePos, 4);
    m_creatures.emplace(placePos, cType);
}

void Spawn::removeCreature(const Position& pos)
{
    const auto iterator = m_creatures.find(pos);
    if (iterator != m_creatures.end()) {
        assert(iterator->first.isValid());
        assert(g_map.removeThingByPos(iterator->first, 4));
        m_creatures.erase(iterator);
    }
}

std::vector<CreatureTypePtr> Spawn::getCreatures()
{
    std::vector<CreatureTypePtr> creatures;
    for (const auto& p : m_creatures)
        creatures.push_back(p.second);
    return creatures;
}

CreaturePtr CreatureType::cast()
{
    const auto& ret = std::make_shared<Creature>();

    std::string cName = getName();
    stdext::tolower(cName);
    stdext::trim(cName);
    stdext::ucwords(cName);
    ret->setName(cName);

    ret->setDirection(getDirection());
    ret->setOutfit(getOutfit());
    return ret;
}

CreatureManager::CreatureManager()
{
    m_nullCreature = std::make_shared<CreatureType>();
}

void CreatureManager::clearSpawns()
{
    for (const auto& pair : m_spawns)
        pair.second->clear();
    m_spawns.clear();
}

void CreatureManager::loadMonsters(const std::string& file)
{
    pugi::xml_document doc;
    pugi::xml_parse_result result = doc.load_file(file.c_str());
    if (!result)
        throw Exception("cannot open monsters file '{}': '{}'", file, result.description());

    pugi::xml_node root = doc.first_child();
    if (!root || root.name() != std::string("monsters"))
        throw Exception("malformed monsters xml file");

    for (pugi::xml_node monster = root.first_child(); monster; monster = monster.next_sibling()) {
        std::string fname = file.substr(0, file.find_last_of('/')) + '/' + monster.attribute("file").as_string();
        if (fname.substr(fname.length() - 4) != ".xml")
            fname += ".xml";

        loadSingleCreature(fname);
    }

    doc.reset();
    m_loaded = true;
}

void CreatureManager::loadSingleCreature(const std::string& file)
{
    loadCreatureBuffer(g_resources.readFileContents(file));
}

void CreatureManager::loadNpcs(const std::string& folder)
{
    std::string tmp{ folder };
    if (!tmp.ends_with("/"))
        tmp += "/";

    if (!g_resources.directoryExists(tmp))
        throw Exception("NPCs folder '{}' was not found.", folder);

    const auto& fileList = g_resources.listDirectoryFiles(tmp);
    for (const auto& file : fileList)
        loadCreatureBuffer(g_resources.readFileContents(tmp + file));
}

void CreatureManager::loadSpawns(const std::string& fileName)
{
    if (!isLoaded()) {
        g_logger.warning("creatures aren't loaded yet to load spawns.");
        return;
    }

    if (m_spawnLoaded) {
        g_logger.warning("attempt to reload spawns.");
        return;
    }

    try {
        pugi::xml_document doc;
        pugi::xml_parse_result result = doc.load_file(fileName.c_str());
        if (!result)
            throw Exception("cannot load spawns xml file '{}: '{}'", fileName, result.description());

        pugi::xml_node root = doc.child("spawns");
        if (root.empty())
            throw Exception("malformed spawns file");

        for (pugi::xml_node node = root.first_child(); node; node = node.next_sibling()) {
            if (node.name() != std::string("spawn"))
                throw Exception("invalid spawn node");

            const auto& spawn = std::make_shared<Spawn>();
            spawn->load(node);
            m_spawns.emplace(spawn->getCenterPos(), spawn);
        }

        m_spawnLoaded = true;
        g_logger.debug("Spawns read successfully.");
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}': {}", fileName, e.what());
    }
}

void CreatureManager::saveSpawns(const std::string& fileName)
{
    try {
        pugi::xml_document doc;
        doc.append_child(pugi::node_declaration).set_value("1.0");
        auto root = doc.append_child("spawns");

        for (const auto& pair : m_spawns) {
            auto elem = root.append_child("spawn");
            pair.second->save(elem);
        }

        if (!doc.save_file(("data" + fileName).c_str(), "\t", pugi::format_default, pugi::encoding_utf8)) {
            throw Exception("failed to save spawns XML {}", fileName);
        }
        g_logger.debug("Spawns saved successfully.");
    } catch (const std::exception& e) {
        g_logger.error("Failed to save '{}': {}", fileName, e.what());
    }
}

void CreatureManager::loadCreatureBuffer(const std::string& buffer)
{
    pugi::xml_document doc;
    auto result = doc.load_string(buffer.c_str());
    if (result.status != pugi::status_ok)
        throw Exception("cannot load creature buffer: {}", result.description());

    pugi::xml_node root = doc.first_child();

    if (!root || (std::string(root.name()) != "monster" && std::string(root.name()) != "npc"))
        throw Exception("invalid root tag name");

    std::string cName = root.attribute("name").value();

    stdext::tolower(cName);
    stdext::trim(cName);
    stdext::ucwords(cName);

    const auto& newType = std::make_shared<CreatureType>(cName);
    for (pugi::xml_node attrib = root.first_child(); attrib; attrib = attrib.next_sibling()) {
        if (std::string(attrib.name()) != "look")
            continue;

        internalLoadCreatureBuffer(attrib, newType);
        break;
    }

    doc.reset();
}

void CreatureManager::internalLoadCreatureBuffer(const pugi::xml_node attrib, const CreatureTypePtr& m)
{
    if (std::find(m_creatures.begin(), m_creatures.end(), m) != m_creatures.end())
        return;

    Outfit out;

    if (const auto type = attrib.attribute("type").as_int(); type > 0) {
        out.setCategory(ThingCategoryCreature);
        out.setId(type);
    } else {
        out.setCategory(ThingCategoryItem);
        out.setAuxId(attrib.attribute("typeex").as_int());
    }

    {
        out.setHead(attrib.attribute("head").as_int());
        out.setBody(attrib.attribute("body").as_int());
        out.setLegs(attrib.attribute("legs").as_int());
        out.setFeet(attrib.attribute("feet").as_int());
        out.setAddons(attrib.attribute("addons").as_int());
        out.setMount(attrib.attribute("mount").as_int());
    }

    m->setOutfit(out);
    m_creatures.push_back(m);
}

const CreatureTypePtr& CreatureManager::getCreatureByName(std::string name)
{
    stdext::tolower(name);
    stdext::trim(name);
    stdext::ucwords(name);
    const auto it = std::find_if(m_creatures.begin(), m_creatures.end(),
                                 [=](const CreatureTypePtr& m) -> bool { return m->getName() == name; });
    if (it != m_creatures.end())
        return *it;
    g_logger.warning("could not find creature with name: {}", name);
    return m_nullCreature;
}

const CreatureTypePtr& CreatureManager::getCreatureByLook(int look)
{
    auto findFun = [=](const auto& c) -> bool {
        const auto& o = c->getOutfit();
        return o.getId() == look || o.getAuxId() == look;
    };
    const auto it = std::find_if(m_creatures.begin(), m_creatures.end(), findFun);
    if (it != m_creatures.end())
        return *it;
    g_logger.warning("could not find creature with looktype: {}", look);
    return m_nullCreature;
}

SpawnPtr CreatureManager::getSpawn(const Position& centerPos)
{
    const auto it = m_spawns.find(centerPos);
    if (it != m_spawns.end())
        return it->second;
    g_logger.debug("failed to find spawn at center {}", centerPos);
    return nullptr;
}

SpawnPtr CreatureManager::getSpawnForPlacePos(const Position& pos)
{
    for (const auto& [centerPos, spawn] : m_spawns) {
        if (isInZone(pos, centerPos, spawn->getRadius()))
            return spawn;
    }

    return nullptr;
}

SpawnPtr CreatureManager::addSpawn(const Position& centerPos, int radius)
{
    const auto iter = m_spawns.find(centerPos);
    if (iter != m_spawns.end()) {
        if (iter->second->getRadius() != radius)
            iter->second->setRadius(radius);
        return iter->second;
    }

    const auto& ret = std::make_shared<Spawn>();
    ret->setRadius(radius);
    ret->setCenterPos(centerPos);

    m_spawns.emplace(centerPos, ret);
    return ret;
}

void CreatureManager::deleteSpawn(const SpawnPtr& spawn)
{
    const Position& centerPos = spawn->getCenterPos();
    const auto it = m_spawns.find(centerPos);
    if (it != m_spawns.end())
        m_spawns.erase(it);
}

std::vector<SpawnPtr> CreatureManager::getSpawns()
{
    std::vector<SpawnPtr> spawns;
    for (const auto& p : m_spawns)
        spawns.push_back(p.second);
    return spawns;
}

#endif
/* vim: set ts=4 sw=4 et: */