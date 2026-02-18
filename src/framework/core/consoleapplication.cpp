/*
 * Copyright (c) 2010-2013 OTClient <https://github.com/edubart/otclient>
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


#include "consoleapplication.h"
#include <framework/core/clock.h>
#include <framework/luaengine/luainterface.h>
#include <framework/core/eventdispatcher.h>
#include <framework/core/asyncdispatcher.h>
#include <framework/stdext/time.h>

#ifdef FW_NET
#include <framework/net/connection.h>
#endif

ConsoleApplication g_app;

void ConsoleApplication::run()
{
    // run the first poll
    mainPoll();
    poll();

    g_lua.callGlobalField("g_app", "onRun");

    // clang c++20 dont support jthread
    std::thread t1([&]() {
        while (!m_stopping) {
            poll();

            stdext::millisleep(1);
        }
    });

    m_running = true;
    while (!m_stopping) {
        mainPoll();
    }

    t1.join();

    m_stopping = false;
    m_running = false;
}

void ConsoleApplication::mainPoll()
{
    g_clock.update();

    // poll window input events
    g_mainDispatcher.poll();
}
