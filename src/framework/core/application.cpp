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

#include "application.h"

#include <gitinfo.h>

#define ADD_QUOTES_HELPER(s) #s
#define ADD_QUOTES(s) ADD_QUOTES_HELPER(s)

#include <csignal>

#include "clock.h"
#include "configmanager.h"
#include "eventdispatcher.h"
#include "graphicalapplication.h"
#include "modulemanager.h"
#include "resourcemanager.h"
#include "framework/platform/crashhandler.h"
#include "framework/platform/platform.h"
#include "framework/proxy/proxy.h"

#ifdef FRAMEWORK_NET
#ifdef __EMSCRIPTEN__
#include <framework/net/webconnection.h>
#else
#include <framework/net/connection.h>
#endif
#endif

void exitSignalHandler(const int sig)
{
    static bool signaled = false;
    switch (sig) {
        case SIGTERM:
        case SIGINT:
            if (!signaled && !g_app.isStopping() && !g_app.isTerminated()) {
                signaled = true;
                g_dispatcher.addEvent([ObjectPtr = &g_app] { ObjectPtr->close(); });
            }
            break;
    }
}

void Application::init(std::vector<std::string>& args, ApplicationContext* context)
{
    m_context = std::unique_ptr<ApplicationContext>(context);

    // capture exit signals
    signal(SIGTERM, exitSignalHandler);
    signal(SIGINT, exitSignalHandler);

#ifdef CRASH_HANDLER
    installCrashHandler();
#endif

    // setup locale
    std::locale::global(std::locale());

    g_dispatcher.init();
    g_textDispatcher.init();
    g_mainDispatcher.init();

    std::string startupOptions;
    for (uint32_t i = 1; i < args.size(); ++i) {
        const auto& arg = args[i];
        startupOptions += " ";
        startupOptions += arg;
    }
    if (startupOptions.length() > 0)
        g_logger.info("Startup options: {}", startupOptions);

    m_startupOptions = startupOptions;
    m_startupArgs = args;

    // mobile testing
    if (startupOptions.find("-mobile") != std::string::npos) {
        g_platform.setDevice({ Mobile, Android });
    }

    // initialize configs
    g_configs.init();

    // initialize lua
    g_lua.init();
    registerLuaFunctions();

    // initalize proxy
    g_proxy.init();
}

void Application::deinit()
{
    g_lua.callGlobalField("g_app", "onTerminate");

    // poll remaining events
    poll();
    Application::poll();

    // disable dispatcher events
    g_textDispatcher.shutdown();
    g_dispatcher.shutdown();
    g_mainDispatcher.shutdown();

    // run modules unload events
    g_modules.unloadModules();
    g_modules.clear();

    // release remaining lua object references
    g_lua.collectGarbage();
}

void Application::terminate()
{
#ifdef FRAMEWORK_NET
#ifdef __EMSCRIPTEN__
    WebConnection::terminate();
#else
    Connection::terminate();
#endif
#endif

    // release configs
    g_configs.terminate();

    // release resources
    g_resources.terminate();

    // terminate script environment
    g_lua.terminate();

    // terminate proxy
    g_proxy.terminate();

    m_terminated = true;

    signal(SIGTERM, SIG_DFL);
    signal(SIGINT, SIG_DFL);
}

void Application::poll()
{
    g_clock.update();

#ifdef FRAMEWORK_NET
#ifdef __EMSCRIPTEN__
    WebConnection::poll();
#else
    Connection::poll();
#endif
#endif

    g_dispatcher.poll();

    // poll connection again to flush pending write
#ifdef FRAMEWORK_NET
#ifdef __EMSCRIPTEN__
    WebConnection::poll();
#else
    Connection::poll();
#endif
#endif

    g_clock.update();
}

void Application::exit()
{
    g_lua.callGlobalField<bool>("g_app", "onExit");
    m_stopping = true;
}

void Application::close()
{
    if (!g_lua.callGlobalField<bool>("g_app", "onClose"))
        exit();
}

void Application::restart()
{
    g_lua.callGlobalField<bool>("g_app", "onRestart");
    g_platform.spawnProcess(g_resources.getBinaryPath(), m_startupArgs);
    exit();
}

std::string Application::getOs()
{
#if defined(WIN32)
    return "windows";
#elif defined(__APPLE__)
    return "mac";
#elif __linux
    return "linux";
#elif ANDROID
    return "android";
#elif __EMSCRIPTEN__
    return "browser";
#else
    return "unknown";
#endif
}

// https://stackoverflow.com/a/46448040
std::string Application::getBuildRevision()
{
    std::stringstream ss;
    ss << std::fixed << std::setprecision(3) << (static_cast<float>(GIT_COMMITS) / 1000);
    return ss.str();
}
std::string Application::getVersion() { return ADD_QUOTES(GIT_VERSION); }
std::string Application::getBuildCommit() { return ADD_QUOTES(GIT_BRANCH); }