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

#include "platform.h"

Platform g_platform;

std::unordered_map<DeviceType, std::string> Platform::m_deviceShortNames = {
    {Desktop, "desktop"},
    {Mobile,  "mobile"},
    {Console, "console"},
};

std::unordered_map<OperatingSystem, std::string> Platform::m_osShortNames = {
    {Windows, "windows"},
    {Linux,   "linux"},
    {macOS,   "macos"},
    {Android, "android"},
    {iOS,     "ios"},
};

std::string Platform::getDeviceShortName(DeviceType type)
{
    if (type == DeviceUnknown)
        type = m_device.type;

    const auto it = m_deviceShortNames.find(type);
    if (it == m_deviceShortNames.end())
        return "";
    return it->second;
}

std::string Platform::getOsShortName(OperatingSystem os)
{
    if (os == OsUnknown)
        os = m_device.os;

    const auto it = m_osShortNames.find(os);
    if (it == m_osShortNames.end())
        return "";
    return it->second;
}

DeviceType Platform::getDeviceTypeByName(std::string shortName)
{
    for (const auto& [type, name] : m_deviceShortNames) {
        if (name == shortName)
            return type;
    }
    return DeviceUnknown;
}

OperatingSystem Platform::getOsByName(std::string shortName)
{
    for (const auto& [type, name] : m_osShortNames) {
        if (name == shortName)
            return type;
    }
    return OsUnknown;
}