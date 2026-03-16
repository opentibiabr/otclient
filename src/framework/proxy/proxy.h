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

class Proxy;
class Session;

using ProxyPacket = std::vector<uint8_t>;
using ProxyPacketPtr = std::shared_ptr<ProxyPacket>;

class ProxyManager
{
public:
    ProxyManager() : m_guard(make_work_guard(m_io))
    {
    }
    void init();
    void terminate();
    void clear();
    void setMaxActiveProxies(const int value)
    {
        m_maxActiveProxies = value;
        if (m_maxActiveProxies < 1)
            m_maxActiveProxies = 1;
    }
    bool isActive();
    void addProxy(const std::string& host, uint16_t port, int priority);
    void removeProxy(const std::string& host, uint16_t port);
    uint32_t addSession(uint16_t port, std::function<void(ProxyPacketPtr)> recvCallback, std::function<void(std::error_code)> disconnectCallback);
    void removeSession(uint32_t sessionId);
    void send(uint32_t sessionId, ProxyPacketPtr packet);
    // tools
    std::map<std::string, uint32_t> getProxies();
    std::map<std::string, std::string> getProxiesDebugInfo();
    int getPing();

private:
    asio::io_context m_io;
    asio::executor_work_guard<asio::io_context::executor_type> m_guard;

    bool m_working = false;
    std::thread m_thread;

    int m_maxActiveProxies = 2;

    std::list<std::weak_ptr<Proxy>> m_proxies;
    std::list<std::weak_ptr<Session>> m_sessions;
};

extern ProxyManager g_proxy;
