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

#include "thingtypemanager.h"

#include <nlohmann/json.hpp>
#include <nlohmann/json_fwd.hpp>

#include "game.h"
#include "spriteappearances.h"
#include "thingtype.h"
#include "framework/core/filestream.h"
#include "framework/core/resourcemanager.h"
#include "framework/otml/otmldocument.h"
#ifdef FRAMEWORK_PROTOBUF
#include <staticdata.pb.h>
#endif

#ifdef FRAMEWORK_EDITOR
#include "itemtype.h"
#include "creatures.h"
#include <framework/core/binarytree.h>
#endif

using json = nlohmann::json;

ThingTypeManager g_things;

void ThingTypeManager::init()
{
    m_nullThingType = std::make_shared<ThingType>();
    for (auto& m_thingType : m_thingTypes)
        m_thingType.resize(1, m_nullThingType);
#ifdef FRAMEWORK_EDITOR
    m_nullItemType = std::make_shared<ItemType>();
    m_itemTypes.resize(1, m_nullItemType);
#endif
}

void ThingTypeManager::terminate()
{
    for (auto& m_thingType : m_thingTypes)
        m_thingType.clear();

    m_nullThingType = nullptr;

#ifdef FRAMEWORK_EDITOR
    m_itemTypes.clear();
    m_reverseItemTypes.clear();
    m_nullItemType = nullptr;
#endif
}

bool ThingTypeManager::loadDat(std::string file)
{
    m_datLoaded = false;
    m_datSignature = 0;
    m_contentRevision = 0;
    try {
        file = g_resources.guessFilePath(file, "dat");

        const auto& fin = g_resources.openFile(file);
        fin->cache(true);

        m_datSignature = fin->getU32();
        m_contentRevision = static_cast<uint16_t>(m_datSignature);

        for (auto& thingType : m_thingTypes) {
            const int count = fin->getU16() + 1;
            thingType.clear();
            thingType.resize(count, m_nullThingType);
        }

        for (int category = -1; ++category < ThingLastCategory;) {
            const uint16_t firstId = category == ThingCategoryItem ? 100 : 1;

            for (uint16_t id = firstId - 1, s = m_thingTypes[category].size(); ++id < s;) {
                const auto& type = std::make_shared<ThingType>();
                type->unserialize(id, static_cast<ThingCategory>(category), fin);
                m_thingTypes[category][id] = type;
            }
        }

        m_datLoaded = true;
        g_lua.callGlobalField("g_things", "onLoadDat", file);
        return true;
    } catch (const stdext::exception& e) {
        g_logger.error("Failed to read dat '{}': {}'", file, e.what());
        return false;
    }
}

bool ThingTypeManager::loadOtml(std::string file)
{
    try {
        file = g_resources.guessFilePath(file, "otml");

        const auto& doc = OTMLDocument::parse(file);
        for (const auto& node : doc->children()) {
            ThingCategory category;
            if (node->tag() == "creatures")
                category = ThingCategoryCreature;
            else if (node->tag() == "items")
                category = ThingCategoryItem;
            else if (node->tag() == "effects")
                category = ThingCategoryEffect;
            else if (node->tag() == "missiles")
                category = ThingCategoryMissile;
            else {
                throw OTMLException(node, "not a valid thing category");
            }

            for (const auto& node2 : node->children()) {
                const auto id = stdext::safe_cast<uint16_t>(node2->tag());
                const auto& type = getThingType(id, category);
                if (!type)
                    throw OTMLException(node2, "thing not found");
                type->unserializeOtml(node2);
            }
        }
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to read dat otml '{}': {}'", file, e.what());
        return false;
    }
}

bool ThingTypeManager::loadAppearances(const std::string& file)
{
#ifdef FRAMEWORK_PROTOBUF
    try {
        if (!g_game.getFeature(Otc::GameLoadSprInsteadProtobuf)) {
            g_spriteAppearances.unload();
            int spritesCount = 0;
            std::string appearancesFile;
            json document = json::parse(g_resources.readFileContents(g_resources.resolvePath(g_resources.guessFilePath(file + "catalog-content", "json"))));
            for (const auto& obj : document) {
                const auto& type = obj["type"];
                if (type == "appearances") {
                    appearancesFile = obj["file"];
                } else if (type == "sprite") {
                    int lastSpriteId = obj["lastspriteid"].get<int>();
                    const auto& sheet = std::make_shared<SpriteSheet>(obj["firstspriteid"].get<int>(), lastSpriteId, static_cast<SpriteLayout>(obj["spritetype"].get<int>()), obj["file"].get<std::string>());
                    const int spritesPerSheet = sheet->getSpritesPerSheet();
                    const int maxSpriteId = sheet->firstId + spritesPerSheet - 1;
                    if (lastSpriteId > maxSpriteId) {
                        g_logger.debug("Sprite sheet '{}' lastspriteid {} exceeds capacity {}, clamping to {}", sheet->file, lastSpriteId, maxSpriteId, maxSpriteId);
                        lastSpriteId = maxSpriteId;
                        sheet->lastId = maxSpriteId;
                    }
                    g_spriteAppearances.addSpriteSheet(sheet);
                    spritesCount = std::max<int>(spritesCount, lastSpriteId);
                }
            }
            g_spriteAppearances.setSpritesCount(spritesCount + 1);
            g_spriteAppearances.setPath(file);
            // load appearances.dat
            std::stringstream fin;
            g_resources.readFileStream(g_resources.resolvePath(fmt::format("{}{}", file, appearancesFile)), fin);
            auto appearancesLib = appearances::Appearances();
            if (!appearancesLib.ParseFromIstream(&fin)) {
                throw stdext::exception("Couldn't parse appearances lib.");
            }
            for (int category = ThingCategoryItem; category < ThingLastCategory; ++category) {
                const google::protobuf::RepeatedPtrField<appearances::Appearance>* appearances = nullptr;
                switch (category) {
                    case ThingCategoryItem: appearances = &appearancesLib.object(); break;
                    case ThingCategoryCreature: appearances = &appearancesLib.outfit(); break;
                    case ThingCategoryEffect: appearances = &appearancesLib.effect(); break;
                    case ThingCategoryMissile: appearances = &appearancesLib.missile(); break;
                    default: return false;
                }
                // fix for custom asserts, where ids are not sorted.
                uint32_t lastAppearanceId = 0;
                for (const auto& appearance : *appearances) {
                    if (appearance.id() > lastAppearanceId)
                        lastAppearanceId = appearance.id();
                }
                auto& things = m_thingTypes[category];
                things.clear();
                things.resize(lastAppearanceId + 1, m_nullThingType);
                for (const auto& appearance : *appearances) {
                    const auto& type = std::make_shared<ThingType>();
                    const uint16_t id = appearance.id();
                    type->unserializeAppearance(id, static_cast<ThingCategory>(category), appearance);
                    m_thingTypes[category][id] = type;
                }
            }
            m_datLoaded = true;
        } else {
            std::stringstream datFileStream;
            auto appearancesLib = appearances::Appearances();
            g_resources.readFileStream(g_resources.resolvePath(g_resources.guessFilePath(file, "dat")), datFileStream);
            if (!appearancesLib.ParseFromIstream(&datFileStream)) {
                throw stdext::exception("Couldn't parse appearances.dat.");
            }
            for (const auto& appearance : appearancesLib.object()) {
                const uint16_t id = appearance.id();
                if (auto* type = getRawThingType(id, ThingCategoryItem)) {
                    type->applyAppearanceFlags(appearance.flags());
                }
            }
        }
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (Appearances): {}", file, e.what());
        return false;
    }
#else
    g_logger.error("Protobuf not supported in this build. enable FRAMEWORK_PROTOBUF");
    return false;
#endif
}

#ifdef FRAMEWORK_PROTOBUF
namespace {
    using RaceBank = google::protobuf::RepeatedPtrField<staticdata::Creature>;

    void loadCreatureBank(RaceList& otcRaceList, const RaceBank& protobufRaceList, bool boss) {
        for (const auto& protobufRace : protobufRaceList) {
            // add race to vector
            RaceType otcRaceType = RaceType();
            otcRaceType.raceId = protobufRace.raceid();
            otcRaceType.name = protobufRace.name();
            otcRaceType.boss = boss;

            Outfit otcOutfit;
            const auto& protobufOutfit = protobufRace.outfit();
            if (protobufOutfit.lookitem() != 0) {
                otcOutfit.setAuxId(static_cast<uint16_t>(protobufOutfit.lookitem()));
            } else {
                otcOutfit.setId(static_cast<uint16_t>(protobufOutfit.looktype()));
                otcOutfit.setAddons(static_cast<uint8_t>(protobufOutfit.lookaddons()));
                if (protobufOutfit.has_colors()) {
                    const auto& pbColors = protobufOutfit.colors();
                    otcOutfit.setHead(static_cast<uint8_t>(pbColors.head()));
                    otcOutfit.setBody(static_cast<uint8_t>(pbColors.body()));
                    otcOutfit.setLegs(static_cast<uint8_t>(pbColors.legs()));
                    otcOutfit.setFeet(static_cast<uint8_t>(pbColors.feet()));
                }
            }

            otcRaceType.outfit = otcOutfit;
            otcRaceList.emplace_back(otcRaceType);
        }
    }
}

bool ThingTypeManager::loadStaticData(const std::string& file)
{
    try {
        std::string staticDataFile;

        json document = json::parse(g_resources.readFileContents(g_resources.resolvePath(g_resources.guessFilePath(file + "catalog-content", "json"))));
        for (const auto& obj : document) {
            const auto& type = obj["type"];
            if (type == "staticdata") {
                staticDataFile = obj["file"];
            }
        }

        // load staticdata.dat
        std::stringstream datFileStream;
        g_resources.readFileStream(g_resources.resolvePath(fmt::format("{}{}", file, staticDataFile)), datFileStream);
        auto staticDataLib = staticdata::Staticdata();
        if (!staticDataLib.ParseFromIstream(&datFileStream)) {
            throw stdext::exception("Couldn't parse staticdata lib.");
        }

        // if reload, start again
        m_monsterRaces.clear();

        const auto& raceBank = staticDataLib.monsters();
        const auto& bossBank = staticDataLib.bosses();
        m_monsterRaces.reserve(static_cast<size_t>(raceBank.size()) + bossBank.size());

        // load monsters and bosses
        // note: aside from compatibility with the QT client,
        // there is no need to have monsters and bosses
        // in separate data banks
        loadCreatureBank(m_monsterRaces, raceBank, false);
        loadCreatureBank(m_monsterRaces, bossBank, true);
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (StaticData): {}", file, e.what());
        return false;
    }

    return false;
}
#else
bool ThingTypeManager::loadStaticData(const std::string& file)
{
    g_logger.error("Protobuf not supported in this build. enable FRAMEWORK_PROTOBUF");
    return false;
}
#endif

const ThingTypeList& ThingTypeManager::getThingTypes(const ThingCategory category)
{
    if (category < ThingLastCategory)
        return m_thingTypes[category];

    throw Exception("invalid thing type category {}", category);
}

const ThingTypePtr& ThingTypeManager::getThingType(const uint16_t id, const ThingCategory category)
{
    if (category >= ThingLastCategory || id >= m_thingTypes[category].size()) {
        g_logger.error("invalid thing type client id {} in category {}", id, static_cast<uint8_t>(category));
        return m_nullThingType;
    }
    return m_thingTypes[category][id];
}

ThingType* ThingTypeManager::getRawThingType(uint16_t id, ThingCategory category) {
    if (category >= ThingLastCategory || id >= m_thingTypes[category].size()) {
        g_logger.error("invalid thing type client id {} in category {}", id, static_cast<uint8_t>(category));
        return nullptr;
    }
    return m_thingTypes[category][id].get();
}

ThingTypeList ThingTypeManager::findThingTypeByAttr(const ThingAttr attr, const ThingCategory category)
{
    ThingTypeList ret;
    for (const auto& type : m_thingTypes[category])
        if (type->hasAttr(attr))
            ret.emplace_back(type);
    return ret;
}

const RaceType& ThingTypeManager::getRaceData(uint32_t raceId)
{
    for (const auto& raceData : m_monsterRaces) {
        if (raceData.raceId == raceId) {
            return raceData;
        }
    }

    return emptyRaceType;
}

RaceList ThingTypeManager::getRacesByName(const std::string& searchString)
{
    RaceList result;
    for (const auto& race : m_monsterRaces) {
        if (race.name.find(searchString) != std::string::npos) {
            result.push_back(race);
        }
    }
    return result;
}

#ifdef FRAMEWORK_EDITOR
void ThingTypeManager::parseItemType(uint16_t serverId, pugi::xml_node node)
{
    bool s;
    int d;

    if (g_game.getClientVersion() < 960) {
        s = serverId > 20000 && serverId < 20100;
        d = 20000;
    } else {
        s = serverId > 30000 && serverId < 30100;
        d = 30000;
    }

    ItemTypePtr itemType;
    if (s) {
        serverId -= d;
        itemType = std::make_shared<ItemType>();
        itemType->setServerId(serverId);
        addItemType(itemType);
    } else
        itemType = getItemType(serverId);

    itemType->setName(node.attribute("name").as_string());
    for (auto attrib : node.children()) {
        std::string key = attrib.attribute("key").as_string();
        if (key.empty())
            continue;

        stdext::tolower(key);
        if (key == "description")
            itemType->setDesc(attrib.attribute("value").as_string());
        else if (key == "weapontype")
            itemType->setCategory(ItemCategoryWeapon);
        else if (key == "ammotype")
            itemType->setCategory(ItemCategoryAmmunition);
        else if (key == "armor")
            itemType->setCategory(ItemCategoryArmor);
        else if (key == "charges")
            itemType->setCategory(ItemCategoryCharges);
        else if (key == "type") {
            std::string value = attrib.attribute("value").as_string();
            stdext::tolower(value);

            if (value == "key")
                itemType->setCategory(ItemCategoryKey);
            else if (value == "magicfield")
                itemType->setCategory(ItemCategoryMagicField);
            else if (value == "teleport")
                itemType->setCategory(ItemCategoryTeleport);
            else if (value == "door")
                itemType->setCategory(ItemCategoryDoor);
        }
    }
}

void ThingTypeManager::addItemType(const ItemTypePtr& itemType)
{
    const uint16_t id = itemType->getServerId();
    if (unlikely(id >= m_itemTypes.size()))
        m_itemTypes.resize(id + 1, m_nullItemType);
    m_itemTypes[id] = itemType;
}

const ItemTypePtr& ThingTypeManager::findItemTypeByClientId(uint16_t id)
{
    if (id == 0 || id >= m_reverseItemTypes.size())
        return m_nullItemType;

    if (m_reverseItemTypes[id])
        return m_reverseItemTypes[id];
    return m_nullItemType;
}

const ItemTypePtr& ThingTypeManager::findItemTypeByName(const std::string& name)
{
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName() == name)
            return it;
    return m_nullItemType;
}

ItemTypeList ThingTypeManager::findItemTypesByName(const std::string& name)
{
    ItemTypeList ret;
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName() == name)
            ret.emplace_back(it);
    return ret;
}

ItemTypeList ThingTypeManager::findItemTypesByString(const std::string& name)
{
    ItemTypeList ret;
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName().find(name) != std::string::npos)
            ret.emplace_back(it);
    return ret;
}

const ItemTypePtr& ThingTypeManager::getItemType(uint16_t id)
{
    if (id >= m_itemTypes.size() || m_itemTypes[id] == m_nullItemType) {
        g_logger.error("invalid thing type, server id: {}", id);
        return m_nullItemType;
    }
    return m_itemTypes[id];
}

ItemTypeList ThingTypeManager::findItemTypeByCategory(ItemCategory category)
{
    ItemTypeList ret;
    for (const ItemTypePtr& type : m_itemTypes)
        if (type->getCategory() == category)
            ret.emplace_back(type);
    return ret;
}

void ThingTypeManager::saveDat(const std::string& fileName)
{
    if (!m_datLoaded)
        throw Exception("failed to save, dat is not loaded");

    try {
        const auto& fin = g_resources.createFile(fileName);
        if (!fin)
            throw Exception("failed to open file '{}' for write", fileName);

        fin->cache();

        fin->addU32(m_datSignature);

        for (const auto& m_thingType : m_thingTypes)
            fin->addU16(m_thingType.size() - 1);

        for (int category = 0; category < ThingLastCategory; ++category) {
            uint16_t firstId = 1;
            if (category == ThingCategoryItem)
                firstId = 100;

            for (uint16_t id = firstId; id < m_thingTypes[category].size(); ++id)
                m_thingTypes[category][id]->serialize(fin);
        }

        fin->flush();
        fin->close();
    } catch (const std::exception& e) {
        g_logger.error("Failed to save '{}': {}", fileName, e.what());
    }
}

void ThingTypeManager::loadOtb(const std::string& file)
{
    try {
        const auto& fin = g_resources.openFile(file);
        fin->cache();

        uint32_t signature = fin->getU32();
        if (signature != 0)
            throw Exception("invalid otb file");

        const auto& root = fin->getBinaryTree();
        root->skip(1); // otb first byte is always 0

        signature = root->getU32();
        if (signature != 0)
            throw Exception("invalid otb file");

        if (const uint8_t rootAttr = root->getU8(); rootAttr == 0x01) { // OTB_ROOT_ATTR_VERSION
            if (const uint16_t size = root->getU16(); size != 4 + 4 + 4 + 128)
                throw Exception("invalid otb root attr version size");

            m_otbMajorVersion = root->getU32();
            m_otbMinorVersion = root->getU32();
            root->skip(4); // buildNumber
            root->skip(128); // description
        }

        const BinaryTreeVec children = root->getChildren();
        m_reverseItemTypes.clear();
        m_itemTypes.resize(children.size() + 1, m_nullItemType);
        m_reverseItemTypes.resize(children.size() + 1, m_nullItemType);

        for (const auto& node : children) {
            const auto& itemType = std::make_shared<ItemType>();
            itemType->unserialize(node);
            addItemType(itemType);

            const uint16_t clientId = itemType->getClientId();
            if (unlikely(clientId >= m_reverseItemTypes.size()))
                m_reverseItemTypes.resize(clientId + 1);
            m_reverseItemTypes[clientId] = itemType;
        }

        m_otbLoaded = true;
        g_lua.callGlobalField("g_things", "onLoadOtb", file);
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (OTB file): {}", file, e.what());
    }
}

void ThingTypeManager::loadXml(const std::string& file)
{
    try {
        if (!isOtbLoaded())
            throw Exception("OTB must be loaded before XML");

        pugi::xml_document doc;
        pugi::xml_parse_result result = doc.load_file(file.c_str());
        if (!result)
            throw Exception("failed to parse '{}': '{}'", file, result.description());

        pugi::xml_node root = doc.child("items");
        if (root.empty())
            throw Exception("invalid root tag name");

        for (pugi::xml_node element = root.first_child(); element; element = element.next_sibling()) {
            if (element.name() != std::string("item"))
                continue;

            const auto id = element.attribute("id").as_uint();
            if (id != 0) {
                std::vector<std::string> s_ids = stdext::split(element.attribute("id").as_string(), ";");
                for (const std::string& s : s_ids) {
                    std::vector<int32_t> ids = stdext::split<int32_t>(s, "-");
                    if (ids.size() > 1) {
                        int32_t i = ids[0];
                        while (i <= ids[1])
                            parseItemType(++i, element);
                    } else
                        parseItemType(atoi(s.c_str()), element);
                }
            } else {
                std::vector<int32_t> begin = stdext::split<int32_t>(element.attribute("fromid").as_string(), ";");
                std::vector<int32_t> end = stdext::split<int32_t>(element.attribute("toid").as_string(), ";");
                if (begin[0] && begin.size() == end.size()) {
                    const size_t size = begin.size();
                    for (size_t i = 0; i < size; ++i)
                        while (begin[i] <= end[i])
                            parseItemType(++begin[i], element);
                }
            }
        }

        m_xmlLoaded = true;
        g_logger.debug("items.xml read successfully.");
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (XML file): {}", file, e.what());
    }
}

#endif

/* vim: set ts=4 sw=4 et: */