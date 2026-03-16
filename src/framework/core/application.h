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

#include <framework/global.h>

class ApplicationContext
{
public:
    ApplicationContext() = default;
    virtual ~ApplicationContext() = default;
};

//@bindsingleton g_app
class Application
{
public:
    virtual ~Application() = default;

    virtual void init(std::vector<std::string>& args, ApplicationContext* context);
    virtual void deinit();
    virtual void terminate();
    virtual void run() = 0;
    virtual void poll();
    virtual void exit();
    virtual void close();
    virtual void restart();

    void setName(const std::string_view name) {
        m_appName = name;
#ifndef NDEBUG
        m_appName += " (DEBUG MODE)";
#endif
    }
    void setCompactName(const std::string_view name) { m_appCompactName = name; }
    void setOrganizationName(const std::string_view name) { m_organizationName = name; }

    bool isRunning() { return m_running; }
    bool isStopping() { return m_stopping; }
    bool isTerminated() const { return m_terminated; }
    const std::string& getName() { return m_appName; }
    const std::string& getCompactName() { return m_appCompactName; }
    const std::string& getOrganizationName() { return m_organizationName; }
    std::string getVersion();

    std::string getCharset() { return m_charset; }
    std::string getBuildCompiler() { return BUILD_COMPILER; }
    std::string getBuildDate() { return std::string{ __DATE__ }; }
    std::string getBuildType() { return BUILD_TYPE; }
    std::string getBuildArch() { return BUILD_ARCH; }
    std::string getBuildRevision();
    std::string getBuildCommit();
    std::string getOs();
    std::string getStartupOptions() { return m_startupOptions; }

protected:
    void registerLuaFunctions();

    std::string m_charset{ "cp1252" };
    std::string m_organizationName{ "otbr" };
    std::string m_appName{ "OTClient - Redemption" };
    std::string m_appCompactName{ "otclient" };
    std::string m_startupOptions;

    std::vector<std::string> m_startupArgs;

    bool m_running{ false };
    bool m_terminated{ false };
    bool m_stopping{ false };

    std::unique_ptr<ApplicationContext> m_context;
};

#ifdef FRAMEWORK_GRAPHICS
#else
#include "consoleapplication.h"
#endif
