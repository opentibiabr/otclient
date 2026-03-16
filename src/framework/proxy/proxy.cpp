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

#include "proxy.h"
#include "proxy_client.h"

ProxyManager g_proxy;

void ProxyManager::init()
{
    if (m_working)
        return;
    m_working = true;
    m_thread = std::thread([&] {
        m_io.run();
    });
}

void ProxyManager::terminate()
{
    if (!m_working)
        return;
    m_working = false;
    clear();
    m_guard.reset();
    if (!m_thread.joinable()) {
        stdext::millisleep(100);
        m_io.stop();
    }
    m_thread.join();
}

void ProxyManager::clear()
{
    for (auto& session_weak : m_sessions) {
        if (const auto session = session_weak.lock()) {
            session->terminate();
        }
    }
    m_sessions.clear();
    for (auto& proxy_weak : m_proxies) {
        if (const auto proxy = proxy_weak.lock()) {
            proxy->terminate();
        }
    }
    m_proxies.clear();
}

bool ProxyManager::isActive()
{
    return m_proxies.size() > 0;
}

void ProxyManager::addProxy(const std::string& host, uint16_t port, int priority)
{
    for (auto& proxy_weak : m_proxies) {
        if (const auto proxy = proxy_weak.lock()) {
            if (proxy->getHost() == host && proxy->getPort() == port) {
                return; // already exist
            }
        }
    }

    const auto proxy = std::make_shared<Proxy>(m_io, host, port, priority);
    proxy->start();
    m_proxies.push_back(proxy);
}

void ProxyManager::removeProxy(const std::string& host, const uint16_t port)
{
    for (auto it = m_proxies.begin(); it != m_proxies.end(); ) {
        if (const auto proxy = it->lock()) {
            if (proxy->getHost() == host && proxy->getPort() == port) {
                proxy->terminate();
                it = m_proxies.erase(it);
            } else {
                ++it;
            }
            continue;
        }
        it = m_proxies.erase(it);
    }
}

uint32_t ProxyManager::addSession(uint16_t port, std::function<void(ProxyPacketPtr)> recvCallback, std::function<void(std::error_code)> disconnectCallback)
{
    assert(recvCallback && disconnectCallback);
    const auto session = std::make_shared<Session>(m_io, port, recvCallback, disconnectCallback);
    session->start(m_maxActiveProxies);
    m_sessions.push_back(session);
    return session->getId();
}

void ProxyManager::removeSession(const uint32_t sessionId)
{
    for (auto it = m_sessions.begin(); it != m_sessions.end(); ) {
        if (const auto session = it->lock()) {
            if (session->getId() == sessionId) {
                session->terminate();
                it = m_sessions.erase(it);
            } else {
                ++it;
            }
            continue;
        }
        it = m_sessions.erase(it);
    }
}

void ProxyManager::send(const uint32_t sessionId, ProxyPacketPtr packet)
{
    SessionPtr session = nullptr;
    for (auto& session_weak : m_sessions) {
        if (const auto tsession = session_weak.lock()) {
            if (tsession->getId() == sessionId) {
                session = tsession;
                break;
            }
        }
    }

    if (!session)
        return;

    session->onPacket(packet);
}

std::map<std::string, uint32_t> ProxyManager::getProxies()
{
    std::map<std::string, uint32_t> ret;
    for (auto& proxy_weak : m_proxies) {
        if (const auto proxy = proxy_weak.lock()) {
            ret[proxy->getHost() + ":" + std::to_string(proxy->getPort())] = proxy->getRealPing();
        }
    }
    return ret;
}

std::map<std::string, std::string> ProxyManager::getProxiesDebugInfo()
{
    std::map<std::string, std::string> ret;
    for (auto& proxy_weak : m_proxies) {
        if (const auto proxy = proxy_weak.lock()) {
            ret[proxy->getHost() + ":" + std::to_string(proxy->getPort())] = proxy->getDebugInfo();
        }
    }
    return ret;
}

int ProxyManager::getPing()
{
    uint32_t ret = 0;
    for (auto& proxy_weak : m_proxies) {
        if (const auto proxy = proxy_weak.lock()) {
            if ((proxy->getRealPing() < ret || ret == 0) && proxy->getRealPing() > 0)
                ret = proxy->getRealPing();
        }
    }
    return ret;
}