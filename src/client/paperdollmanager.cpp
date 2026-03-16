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

#include "paperdollmanager.h"
#include "paperdoll.h"
#include "thingtypemanager.h"

PaperdollManager g_paperdolls;

PaperdollPtr PaperdollManager::getById(uint16_t id) {
    const auto it = m_paperdolls.find(id);
    if (it == m_paperdolls.end()) {
        g_logger.error(std::format("PaperdollManager::getById(%d): not found.", id));
        return nullptr;
    }

    const auto& obj = (*it).second;
    if (obj->m_thingId > 0 && obj->m_thingType == nullptr) {
        if (!g_things.isValidDatId(obj->m_thingId, ThingCategoryCreature)) {
            g_logger.error(std::format("PaperdollManager::getById(%d): invalid thing with id %d.", id, obj->m_thingId));
            return nullptr;
        }

        obj->m_thingType = g_things.getThingType(obj->m_thingId, ThingCategoryCreature).get();
    }

    return obj;
}

PaperdollPtr PaperdollManager::set(uint16_t id, uint16_t thingId) {
    const auto it = m_paperdolls.find(id);
    if (it != m_paperdolls.end()) {
        g_logger.error(std::format("PaperdollManager::register(%d, %d): has already been registered.", id, thingId));
        return nullptr;
    }

    const auto& obj = std::make_shared<Paperdoll>();
    obj->m_id = id;
    obj->m_thingId = thingId;

    m_paperdolls.emplace(id, obj);
    return obj;
}