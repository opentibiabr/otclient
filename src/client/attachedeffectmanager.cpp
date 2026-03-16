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

#include "attachedeffectmanager.h"

#include "attachedeffect.h"
#include "thingtypemanager.h"
#include "framework/core/resourcemanager.h"

AttachedEffectManager g_attachedEffects;

AttachedEffectPtr AttachedEffectManager::getById(const uint16_t id) {
    const auto it = m_effects.find(id);
    if (it == m_effects.end()) {
        g_logger.error("AttachedEffectManager::getById({}): not found.", id);
        return nullptr;
    }

    const auto& obj = it->second;
    if (obj->m_thingId > 0 && !g_things.isValidDatId(obj->m_thingId, obj->m_thingCategory)) {
        g_logger.error("AttachedEffectManager::getById({}): invalid thing with id {}.", id, obj->m_thingId);
        return nullptr;
    }

    return obj->clone();
}

AttachedEffectPtr AttachedEffectManager::registerByThing(uint16_t id, const std::string_view name, const uint16_t thingId, const ThingCategory category) {
    const auto it = m_effects.find(id);
    if (it != m_effects.end()) {
        g_logger.error("AttachedEffectManager::registerByThing({}, {}): has already been registered.", id, name);
        return nullptr;
    }

    const auto& obj = std::make_shared<AttachedEffect>();
    obj->m_id = id;
    obj->m_thingId = thingId;
    obj->m_thingCategory = category;

    obj->m_name = { name.data() };

    m_effects.emplace(id, obj);
    return obj;
}

AttachedEffectPtr AttachedEffectManager::registerByImage(uint16_t id, const std::string_view name, const std::string_view path, const bool smooth) {
    const auto it = m_effects.find(id);
    if (it != m_effects.end()) {
        g_logger.error("AttachedEffectManager::registerByImage({}, {}): has already been registered.", id, name);
        return nullptr;
    }

    const auto& filePath = g_resources.resolvePath(path.data());
    const auto& filePathEx = g_resources.guessFilePath(filePath, "png");
    if (!g_resources.fileExists(filePathEx)) {
        g_logger.error("AttachedEffectManager::registerByImage({}, {}): Texture({}) not found.", id, name, path);
        return nullptr;
    }

    const auto& obj = std::make_shared<AttachedEffect>();
    obj->m_texturePath = path;
    obj->m_smooth = smooth;
    obj->m_id = id;
    obj->m_name = { name.data() };

    m_effects.emplace(id, obj);
    return obj;
}