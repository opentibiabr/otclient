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

#include "declarations.h"
#include <framework/util/stats.h>

 /// LuaObject, all script-able classes have it as base
 // @bindclass
class LuaObject : public std::enable_shared_from_this<LuaObject>
{
public:
    LuaObject();
    virtual ~LuaObject();

    template<typename T>
    void connectLuaField(std::string_view field, const std::function<T>& f, bool pushFront = false);

    /// Calls a function or table of functions stored in a lua field, results are pushed onto the stack,
    /// if any lua error occurs, it will be reported to stdout and return 0 results
    /// @return the number of results
    template<typename... T>
    int luaCallLuaField(std::string_view field, const T&... args);

    template<typename R, typename... T>
    R callLuaField(std::string_view field, const T&... args);
    template<typename... T>
    void callLuaField(std::string_view field, const T&... args);
    template<typename... T>
    void callLuaFieldUnchecked(std::string_view field, const T&... args);

    /// Returns true if the lua field exists
    bool hasLuaField(std::string_view field) const;

    /// Sets a field in this lua object
    template<typename T>
    void setLuaField(std::string_view key, const T& value);

    void clearLuaField(std::string_view key);

    /// Gets a field from this lua object
    template<typename T>
    T getLuaField(std::string_view key);

    /// Release fields table reference
    void releaseLuaFieldsTable();

    /// Sets a field from this lua object, the value must be on the stack
    void luaSetField(std::string_view key);

    /// Gets a field from this lua object, the result is pushed onto the stack
    void luaGetField(std::string_view key) const;

    /// Get object's metatable
    void luaGetMetatable();

    /// Gets the table containing all stored fields of this lua object, the result is pushed onto the stack
    void luaGetFieldsTable() const;

    /// Returns the derived class name, its the same name used in Lua
    std::string getClassName();

    LuaObjectPtr asLuaObject() { return shared_from_this(); }

    /// Returns the number of references of this object
    /// @note each shared_ptr reference counts as a reference
    int getUseCount();

    template<typename T>
    std::shared_ptr<T> static_self_cast() { return std::static_pointer_cast<T>(shared_from_this()); }
    template<typename T>
    std::shared_ptr<T> dynamic_self_cast() { return std::dynamic_pointer_cast<T>(shared_from_this()); }

private:
    int m_fieldsTableRef;
    std::unordered_map<std::string, bool> m_events;

    friend class LuaInterface;
};

extern int16_t g_luaThreadId;

template<typename F>
void connect(const LuaObjectPtr& obj, std::string_view field, const std::function<F>& f, bool pushFront = false);

template<typename Lambda>
std::enable_if_t<std::is_constructible_v<decltype(&Lambda::operator())>, void>
connect(const LuaObjectPtr& obj, std::string_view field, const Lambda& f, bool pushFront = false);

#include "luainterface.h"

template<typename T>
void LuaObject::connectLuaField(const std::string_view field, const std::function<T>& f, const bool pushFront)
{
    luaGetField(field);
    if (g_lua.isTable()) {
        if (pushFront)
            g_lua.pushInteger(1);
        push_luavalue(f);
        g_lua.callGlobalField("table", "insert");
    } else {
        if (g_lua.isNil()) {
            push_luavalue(f);
            luaSetField(field);
            g_lua.pop();
        } else if (g_lua.isFunction()) {
            g_lua.newTable();
            g_lua.insert(-2);
            g_lua.rawSeti(1);
            push_luavalue(f);
            g_lua.rawSeti(2);
            luaSetField(field);
        }
    }
}

// connect for std::function
template<typename F>
void connect(const LuaObjectPtr& obj, const std::string_view field, const std::function<F>& f, const bool pushFront)
{
    obj->connectLuaField<F>(field, f, pushFront);
}

namespace luabinder
{
    template<typename F>
    struct connect_lambda;

    template<typename Lambda, typename Ret, typename... Args>
    struct connect_lambda<Ret(Lambda::*)(Args...) const>
    {
        static void call(const LuaObjectPtr& obj, const std::string_view field, const Lambda& f, bool pushFront)
        {
            connect(obj, field, std::function<Ret(Args...)>(f), pushFront);
        }
    };
};

// connect for lambdas
template<typename Lambda>
std::enable_if_t<std::is_constructible_v<decltype(&Lambda::operator())>, void>
connect(const LuaObjectPtr& obj, const std::string_view field, const Lambda& f, bool pushFront)
{
    using F = decltype(&Lambda::operator());
    luabinder::connect_lambda<F>::call(obj, field, f, pushFront);
}

template<typename... T>
int LuaObject::luaCallLuaField(const std::string_view field, const T&... args)
{
    if (g_luaThreadId > -1 && g_luaThreadId != stdext::getThreadId()) {
        g_logger.warning("luaCallLuaField(" + std::string{ field } + ") is being called outside the context of the lua call.");
        return 0;
    }

    // we need to gracefully catch a cast exception here in case
    // this is called from a constructor, this does not need to
    // blow up, we can just debug log it and exit.
    LuaObjectPtr self;
    try {
        self = asLuaObject();
    } catch (...) {
        g_logger.warning("({}):luaCallLuaField: Calling lua during object construction is not allowed.", getClassName());
        return -1;
    }

    AutoStat s(STATS_LUA, getClassName() + ":" + std::string{ field });

    // note that the field must be retrieved from this object lua value
    // to force using the __index metamethod of it's metatable
    // so cannot use LuaObject::getField here
    // push field
    g_lua.pushObject(self);
    g_lua.getField(field);

    if (!g_lua.isNil()) {
        // the first argument is always this object (self)
        g_lua.insert(-2);
        const int numArgs = g_lua.polymorphicPush(args...);
        return g_lua.signalCall(1 + numArgs);
    }
    g_lua.pop(2);
    return -1;
}

template<typename R, typename... T>
R LuaObject::callLuaField(const std::string_view field, const T&... args)
{
    R result;
    if (const int rets = luaCallLuaField(field, args...); rets > 0) {
        assert(rets == 1);
        result = g_lua.polymorphicPop<R>();
    } else
        result = R();

    return result;
}

template<typename... T>
void LuaObject::callLuaField(const std::string_view field, const T&... args)
{
    const std::string fieldStr = field.data();

    // Avoids unnecessary overhead by checking if the field is registered before invoking the Lua event.
    auto it = m_events.find(fieldStr);
    if (it != m_events.end() && !it->second)
        return;

    const int rets = luaCallLuaField(field, args...);
    if (rets > 0)
        g_lua.pop(rets);

    if (it == m_events.end())
        m_events[fieldStr] = rets > -1;
}

template<typename... T>
void LuaObject::callLuaFieldUnchecked(const std::string_view field, const T&... args)
{
    const int rets = luaCallLuaField(field, args...);
    if (rets > 0)
        g_lua.pop(rets);
}

template<typename T>
void LuaObject::setLuaField(const std::string_view key, const T& value)
{
    g_lua.polymorphicPush(value);
    luaSetField(key);
}

template<typename T>
T LuaObject::getLuaField(const std::string_view key)
{
    luaGetField(key);
    return g_lua.polymorphicPop<T>();
}
