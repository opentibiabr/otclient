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

#include "configmanager.h"
#include <INIReader.h>
#include "resourcemanager.h"

ConfigManager g_configs;

void ConfigManager::init() {
    m_settings = std::make_shared<Config>();

    // Comment out or remove this line to skip loading config.ini.
    loadPublicConfig("config.ini");
}

void ConfigManager::terminate()
{
    if (m_settings) {
        // ensure settings are saved
        m_settings->save();

        m_settings->unload();
        m_settings = nullptr;
    }

    for (auto config : m_configs) {
        config->unload();
        config = nullptr;
    }

    m_configs.clear();
}

ConfigPtr ConfigManager::getSettings()
{
    return m_settings;
}

ConfigPtr ConfigManager::get(const std::string& file)
{
    for (const auto& config : m_configs) {
        if (config->getFileName() == file) {
            return config;
        }
    }
    return nullptr;
}

ConfigPtr ConfigManager::loadSettings(const std::string& file)
{
    if (file.empty()) {
        g_logger.error("Must provide a configuration file to load.");
    } else {
        if (m_settings->load(file)) {
            return m_settings;
        }
    }
    return nullptr;
}

ConfigPtr ConfigManager::create(const std::string& file)
{
    auto config = load(file);
    if (!config) {
        config = std::make_shared<Config>();

        config->load(file);
        config->save();

        m_configs.emplace_back(config);
    }
    return config;
}

ConfigPtr ConfigManager::load(const std::string& file)
{
    if (file.empty()) {
        g_logger.error("Must provide a configuration file to load.");
        return nullptr;
    }
    auto config = get(file);
    if (!config) {
        config = std::make_shared<Config>();

        if (config->load(file)) {
            m_configs.emplace_back(config);
        } else {
            // cannot load config
            config = nullptr;
        }
    }
    return config;
}

bool ConfigManager::unload(const std::string& file)
{
    if (auto config = get(file)) {
        config->unload();
        remove(config);
        config = nullptr;
        return true;
    }
    return false;
}

void ConfigManager::remove(const ConfigPtr& config) { m_configs.remove(config); }

void ConfigManager::saveSettings()
{
    if (m_settings)
        m_settings->save();
}

void ConfigManager::loadPublicConfig(const std::string& fileName) {
    try {
        auto content = g_resources.readFileContents(fileName);
        INIReader reader(content.c_str(), content.size());

        if (reader.ParseError() < 0) {
            g_logger.error("Failed to read config otml '{}''", fileName);
            return;
        }

        m_publicConfig.graphics.maxAtlasSize = std::max<int>(2048, reader.GetInteger("graphics", "maxAtlasSize", m_publicConfig.graphics.maxAtlasSize));
        m_publicConfig.graphics.mapAtlasSize = reader.GetInteger("graphics", "mapAtlasSize", m_publicConfig.graphics.mapAtlasSize);
        m_publicConfig.graphics.foregroundAtlasSize = reader.GetInteger("graphics", "foregroundAtlasSize", m_publicConfig.graphics.foregroundAtlasSize);
        
        m_publicConfig.font.widget = reader.Get("font", "widget", m_publicConfig.font.widget);
        m_publicConfig.font.staticText = reader.Get("font", "static-text", m_publicConfig.font.staticText);
        m_publicConfig.font.animatedText = reader.Get("font", "animated-text", m_publicConfig.font.animatedText);
        m_publicConfig.font.creatureText = reader.Get("font", "creature-text", m_publicConfig.font.creatureText);
    } catch (const std::exception& e) {
        g_logger.error("Failed to parse public config '{}': {}", fileName, e.what());
    }
}