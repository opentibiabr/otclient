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
#include <framework/core/declarations.h>
#include <framework/luaengine/luaobject.h>

#include "const.h"

class ItemType : public LuaObject
{
public:
    void unserialize(const BinaryTreePtr& node);

    void setServerId(uint16_t serverId) { m_serverId = serverId; }
    uint16_t getServerId() { return m_serverId; }

    void setClientId(uint16_t clientId) { m_clientId = clientId; }
    uint16_t getClientId() { return m_clientId; }

    void setCategory(ItemCategory category) { m_category = category; }
    ItemCategory getCategory() { return m_category; }

    void setName(const std::string& name) { m_name = name; }
    std::string getName() { return m_name; }

    void setDesc(const std::string& desc) { m_desc = desc; }
    std::string getDesc() { return m_desc; }

    bool isNull() { return m_null; }
    bool isWritable() { return m_writable; }

private:
    ItemCategory m_category{ ItemCategoryInvalid };
    bool m_null{ true };
    bool m_writable{ false };

    uint16_t m_serverId{ 0 };
    uint16_t m_clientId{ 0 };
    std::string m_name;
    std::string m_desc;
};
#endif
