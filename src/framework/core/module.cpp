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

#include "module.h"

#include "modulemanager.h"
#include "resourcemanager.h"
#include "framework/otml/otmlnode.h"
#include "framework/platform/platform.h"

Module::Module(const std::string_view name) : m_sandboxEnv(g_lua.newSandboxEnv()), m_name(name.data()) {}

bool Module::load()
{
    if (m_loaded || !m_enabled)
        return true;

    if (!m_supportedDevices.empty() && !hasSupportedDevice(g_platform.getDevice()))
        return true;

    const ticks_t startTime = stdext::millis();

    g_modules.m_currentModule = static_self_cast<Module>();
    try {
        // add to package.loaded
        g_lua.getGlobalField("package", "loaded");
        g_lua.getRef(m_sandboxEnv);
        g_lua.setField(m_name);
        g_lua.pop();

        for (const auto& depName : m_dependencies) {
            if (depName == m_name)
                throw Exception("cannot depend on itself");

            const auto& dep = g_modules.getModule(depName);
            if (!dep)
                throw Exception("dependency '{}' was not found", depName);

            if (dep->hasDependency(m_name, true))
                throw Exception("dependency '{}' is recursively depending on itself", depName);

            if (!dep->isLoaded() && !dep->load())
                throw Exception("dependency '{}' has failed to load", depName);
        }

        if (m_sandboxed)
            g_lua.setGlobalEnvironment(m_sandboxEnv);

        for (const auto& script : m_scripts) {
            g_lua.loadScript(script);
            g_lua.safeCall(0, 0);
        }

        const auto& onLoadBuffer = std::get<0>(m_onLoadFunc);
        const auto& onLoadSource = std::get<1>(m_onLoadFunc);
        if (!onLoadBuffer.empty()) {
            g_lua.loadBuffer(onLoadBuffer, onLoadSource);
            if (m_sandboxed) {
                g_lua.getRef(m_sandboxEnv);
                g_lua.setEnv();
            }
            g_lua.safeCall(0, 0);
        }

        if (m_sandboxed)
            g_lua.resetGlobalEnvironment();

        m_loaded = true;

        g_logger.debug("Loaded module '{}' ({:.2f}s)", m_name, (stdext::millis() - startTime) / 1000.0
        );
    } catch (const stdext::exception& e) {
        // remove from package.loaded
        g_lua.getGlobalField("package", "loaded");
        g_lua.pushNil();
        g_lua.setField(m_name);
        g_lua.pop();

        if (m_sandboxed)
            g_lua.resetGlobalEnvironment();
        g_logger.error("Unable to load module '{}': {}", m_name, e.what());

        g_modules.m_currentModule = nullptr;

        return false;
    }

    g_modules.updateModuleLoadOrder(asModule());

    for (const auto& modName : m_loadLaterModules) {
        const auto& dep = g_modules.getModule(modName);
        if (!dep)
            g_logger.error("Unable to find module '{}' required by '{}'", modName, m_name);
        else if (!dep->isLoaded())
            dep->load();
    }

    g_modules.m_currentModule = nullptr;

    return true;
}

void Module::unload()
{
    if (m_loaded) {
        try {
            if (m_sandboxed)
                g_lua.setGlobalEnvironment(m_sandboxEnv);

            const auto& onUnloadBuffer = std::get<0>(m_onUnloadFunc);
            const auto& onUnloadSource = std::get<1>(m_onUnloadFunc);
            if (!onUnloadBuffer.empty()) {
                g_lua.loadBuffer(onUnloadBuffer, onUnloadSource);
                g_lua.safeCall(0, 0);
            }

            if (m_sandboxed)
                g_lua.resetGlobalEnvironment();
        } catch (const stdext::exception& e) {
            if (m_sandboxed)
                g_lua.resetGlobalEnvironment();
            g_logger.error("Unable to unload module '{}': {}", m_name, e.what());
        }

        // clear all env references
        g_lua.getRef(m_sandboxEnv);
        g_lua.clearTable();
        g_lua.pop();

        // remove from package.loaded
        g_lua.getGlobalField("package", "loaded");
        g_lua.pushNil();
        g_lua.setField(m_name);
        g_lua.pop();

        m_loaded = false;
        //g_logger.info("Unloaded module '{}'", m_name);
        g_modules.updateModuleLoadOrder(asModule());
    }
}

bool Module::reload()
{
    unload();
    return load();
}

bool Module::isDependent() const
{
    for (const ModulePtr& module : g_modules.getModules()) {
        if (module->isLoaded() && module->hasDependency(m_name))
            return true;
    }
    return false;
}

bool Module::hasDependency(const std::string_view name, const bool recursive)
{
    if (std::ranges::find(m_dependencies, name) != m_dependencies.end())
        return true;

    if (recursive) {
        for (const auto& depName : m_dependencies) {
            if (const auto& dep = g_modules.getModule(depName)) {
                if (dep->hasDependency(name, true))
                    return true;
            }
        }
    }

    return false;
}

bool Module::hasSupportedDevice(const Device device)
{
    for (const auto& sd : m_supportedDevices) {
        if (sd.type == device.type || sd.type == DeviceUnknown) {
            if (sd.os == device.os || sd.os == OsUnknown)
                return true;
        }
    }
    return false;
}

int Module::getSandbox(LuaInterface* lua)
{
    lua->getRef(m_sandboxEnv);
    return 1;
}

void Module::discover(const OTMLNodePtr& moduleNode)
{
    const static std::string none = "none";
    m_description = moduleNode->valueAt("description", none);
    m_author = moduleNode->valueAt("author", none);
    m_website = moduleNode->valueAt("website", none);
    m_version = moduleNode->valueAt("version", none);
    m_enabled = moduleNode->valueAt<bool>("enabled", true);
    m_autoLoad = moduleNode->valueAt<bool>("autoload", false);
    m_reloadable = moduleNode->valueAt<bool>("reloadable", true);
    m_sandboxed = moduleNode->valueAt<bool>("sandboxed", false);
    m_autoLoadPriority = moduleNode->valueAt<int>("autoload-priority", 9999);
    m_minClientVersion = moduleNode->valueAt<int>("minClientVersion", 0);

    if (const auto& node = moduleNode->get("devices")) {
        for (const auto& tmp : node->children()) {
            auto deviceInfo = stdext::split(tmp->value(), ":");
            if (deviceInfo.empty())
                continue;

            auto device = Device();
            device.type = Platform::getDeviceTypeByName(deviceInfo.at(0));
            if (deviceInfo.size() > 1) device.os = Platform::getOsByName(deviceInfo.at(1));
            m_supportedDevices.emplace_back(device);
        }
    }

    if (const auto& node = moduleNode->get("dependencies")) {
        for (const auto& tmp : node->children())
            m_dependencies.emplace_back(tmp->value());
    }

    if (const auto& node = moduleNode->get("scripts")) {
        for (const auto& tmp : node->children()) {
            auto path = std::filesystem::path(stdext::resolve_path(tmp->value(), node->source())).replace_extension().string();

            if (path.ends_with('*')) {
                path.pop_back();
                if (path.ends_with('/'))
                    path.pop_back();

                for (auto filePath : g_resources.listDirectoryFiles(path, true, false, true)) {
                    if (g_resources.isFileType(filePath, "lua")) {
                        filePath = std::filesystem::path(filePath).replace_extension().string();

                        auto foundElement = std::ranges::find(m_scripts, filePath);
                        if (m_scripts.end() == foundElement)
                            m_scripts.emplace_back(filePath);
                    }
                }
            } else
                m_scripts.emplace_back(path);
        }
    }

    if (const auto& node = moduleNode->get("load-later")) {
        for (const auto& tmp : node->children())
            m_loadLaterModules.emplace_back(tmp->value());
    }

    if (const auto& node = moduleNode->get("@onLoad"))
        m_onLoadFunc = std::make_tuple(node->value(), "@" + node->source() + ":[" + node->tag() + "]");

    if (const auto& node = moduleNode->get("@onUnload"))
        m_onUnloadFunc = std::make_tuple(node->value(), "@" + node->source() + ":[" + node->tag() + "]");
}