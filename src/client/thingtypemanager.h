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

#include "staticdata.h"

using RaceList = std::vector<RaceType>;
static const RaceType emptyRaceType{};

class ThingTypeManager
{
public:
    void init();
    void terminate();

    bool loadDat(std::string file);
    bool loadOtml(std::string file);
    bool loadAppearances(const std::string& file);
    bool loadStaticData(const std::string& file);

#ifdef FRAMEWORK_EDITOR
    void parseItemType(uint16_t id, pugi::xml_node node);
    void loadOtb(const std::string& file);
    void loadXml(const std::string& file);
    void saveDat(const std::string& fileName);
    uint32_t getOtbMajorVersion() { return m_otbMajorVersion; }
    uint32_t getOtbMinorVersion() { return m_otbMinorVersion; }
    bool isXmlLoaded() { return m_xmlLoaded; }
    bool isOtbLoaded() { return m_otbLoaded; }
    bool isValidOtbId(uint16_t id) { return id >= 1 && id < m_itemTypes.size(); }
    const ItemTypeList& getItemTypes() { return m_itemTypes; }
    void addItemType(const ItemTypePtr& itemType);
    const ItemTypePtr& findItemTypeByClientId(uint16_t id);
    const ItemTypePtr& findItemTypeByName(const std::string& name);
    ItemTypeList findItemTypesByName(const std::string& name);
    ItemTypeList findItemTypesByString(const std::string& name);
    const ItemTypePtr& getNullItemType() { return m_nullItemType; }
    const ItemTypePtr& getItemType(uint16_t id);

    ItemTypeList findItemTypeByCategory(ItemCategory category);
#endif

    ThingTypeList findThingTypeByAttr(ThingAttr attr, ThingCategory category);

    const RaceType& getRaceData(uint32_t raceId);
    RaceList getRacesByName(const std::string& searchString);

    const ThingTypePtr& getNullThingType() { return m_nullThingType; }

    const ThingTypePtr& getThingType(uint16_t id, ThingCategory category);
    ThingType* getRawThingType(uint16_t id, ThingCategory category);

    const ThingTypeList& getThingTypes(ThingCategory category);

    uint32_t getDatSignature() { return m_datSignature; }
    uint16_t getContentRevision() { return m_contentRevision; }

    bool isDatLoaded() { return m_datLoaded; }
    bool isValidDatId(const uint16_t id, const ThingCategory category) const { return category < ThingLastCategory && id >= 1 && id < m_thingTypes[category].size(); }

private:
    ThingTypeList m_thingTypes[ThingLastCategory];
    RaceList m_monsterRaces;

    ThingTypePtr m_nullThingType;

    bool m_datLoaded{ false };

    uint32_t m_datSignature{ 0 };
    uint16_t m_contentRevision{ 0 };

#ifdef FRAMEWORK_EDITOR
    ItemTypePtr m_nullItemType;
    ItemTypeList m_reverseItemTypes;
    ItemTypeList m_itemTypes;
    uint32_t m_otbMinorVersion{ 0 };
    uint32_t m_otbMajorVersion{ 0 };
    bool m_xmlLoaded{ false };
    bool m_otbLoaded{ false };
#endif

    friend class GarbageCollection;
};

extern ThingTypeManager g_things;
