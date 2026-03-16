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

#include "luaexception.h"
#include "luainterface.h"

LuaException::LuaException(const std::string_view error, const int traceLevel)
{
    g_lua.clearStack(); // on every exception, clear lua stack
    generateLuaErrorMessage(error, traceLevel);
}

void LuaException::generateLuaErrorMessage(const std::string_view error, const int traceLevel)
{
    // append trace level to error message
    if (traceLevel >= 0)
        m_what = fmt::format("LUA ERROR: {}", g_lua.traceback(error, traceLevel));
    else
        m_what = fmt::format("LUA ERROR:\n{}", error);
}

LuaBadNumberOfArgumentsException::LuaBadNumberOfArgumentsException(const int expected, const int got)
{
    std::string error = "attempt to call a function with wrong number of arguments";
    if (expected >= 0 && got >= 0)
        error = fmt::format("{} (expected {}, but got {})", error, expected, got);
    generateLuaErrorMessage(error, 1);
}

LuaBadValueCastException::LuaBadValueCastException(const std::string_view luaTypeName, const std::string_view cppTypeName)
{
    const auto& error = fmt::format("attempt to cast a '{}' lua value to '{}'", luaTypeName, cppTypeName);
    generateLuaErrorMessage(error, 0);
}