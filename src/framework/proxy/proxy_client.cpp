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

 //#define PROXY_DEBUG

#include "proxy_client.h"

#include <framework/core/logger.h>

std::map<uint32_t, std::weak_ptr<Session>> g_sessions;
std::set<std::shared_ptr<Proxy>> g_proxies;
uint32_t UID = (std::chrono::high_resolution_clock::now().time_since_epoch().count()) & 0xFFFFFFFF;

void Proxy::start()
{
#ifdef PROXY_DEBUG
    g_logger.debug("[Proxy {}] start", m_host);
#endif
    auto self(shared_from_this());
    post(m_io, [&, self] {
        const std::error_code ec;
        g_proxies.insert(self);
        check(ec);
    });
}

void Proxy::terminate()
{
    if (m_terminated)
        return;
    m_terminated = true;

#ifdef PROXY_DEBUG
    g_logger.debug("[Proxy {}] terminate", m_host);
#endif

    auto self(shared_from_this());
    post(m_io, [&, self] {
        g_proxies.erase(self);
        disconnect();
        std::error_code ec;
        m_timer.cancel(ec);
    });
}

std::string Proxy::getDebugInfo()
{
    std::stringstream ss;
    ss << "P: " << getPing() << " RP: " << getRealPing() << " In: " << m_packetsRecived << " (" << m_bytesRecived
        << ")  Out: " << m_packetsSent << " (" << m_bytesSent << ") Conns: " << m_connections << " Sess: " << m_sessions << " R: " << m_resolvedIp;
    return ss.str();
}

void Proxy::check(const std::error_code& ec)
{
    if (ec || m_terminated) {
        return;
    }

    const int32_t lastPing = static_cast<int32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - m_lastPingSent).count());
    if (m_state == STATE_NOT_CONNECTED) {
        connect();
    } else if (m_state == STATE_CONNECTING) { // timeout for async_connect
        if (lastPing + 50 > CHECK_INTERVAL * 5) {
            disconnect();
        }
    } else if (m_state == STATE_CONNECTED || m_state == STATE_CONNECTING_WAIT_FOR_PING) {
        if (m_waitingForPing) {
            if (lastPing + 50 > CHECK_INTERVAL * (m_state == STATE_CONNECTING_WAIT_FOR_PING ? 5 : 3)) {
#ifdef PROXY_DEBUG
                g_logger.debug("[Proxy {}] ping timeout", m_host);
#endif
                disconnect();
            }
        } else if (m_state == STATE_CONNECTED) {
            ping();
        }
    }
    m_timer.expires_from_now(std::chrono::milliseconds(CHECK_INTERVAL));
    m_timer.async_wait([capture0 = shared_from_this()](auto&& PH1) {
        capture0->check(std::forward<decltype(PH1)>(PH1));
    });
}

void Proxy::connect()
{
#ifdef PROXY_DEBUG
    g_logger.debug("[Proxy {}] connecting to {}:{}", m_host, m_host, m_port);
#endif
    m_sendQueue.clear();
    m_waitingForPing = false;
    m_state = STATE_CONNECTING;
    m_connections += 1;
    m_sessions = 0;
    m_resolver = asio::ip::tcp::resolver(m_io);
    auto self(shared_from_this());
    m_resolver.async_resolve(m_host, "http", [self](const std::error_code& ec,
                             asio::ip::tcp::resolver::results_type results) {
        auto endpoint = asio::ip::tcp::endpoint();
        if (ec || results.empty()) {
#ifdef PROXY_DEBUG
            g_logger.debug("[Proxy {}] resolve error: {}", self->m_host, ec.message());
#endif
            std::error_code ecc;
            const auto address = asio::ip::make_address_v4(self->m_host, ecc);
            if (ecc) {
                self->m_state = STATE_NOT_CONNECTED;
                return;
            }
            endpoint = asio::ip::tcp::endpoint(address, self->m_port);
        } else {
            endpoint = asio::ip::tcp::endpoint(*results);
            endpoint.port(self->m_port);
        }
        self->m_resolvedIp = endpoint.address().to_string();
        self->m_socket = asio::ip::tcp::socket(self->m_io);
        self->m_lastPingSent = std::chrono::high_resolution_clock::now(); // used for async_connect timeout
        self->m_socket.async_connect(endpoint, [self, endpoint](const std::error_code& ec) {
            if (ec) {
                self->m_state = STATE_NOT_CONNECTED;
                return;
            }
            std::error_code ecc;
            self->m_socket.set_option(asio::ip::tcp::no_delay(true), ecc);
            self->m_socket.set_option(asio::socket_base::send_buffer_size(65536), ecc);
            self->m_socket.set_option(asio::socket_base::receive_buffer_size(65536), ecc);
            if (ecc) {
#ifdef PROXY_DEBUG
                g_logger.debug("[Proxy {}] connect error: {}", self->m_host, ecc.message());
#endif
            }

            self->m_state = STATE_CONNECTING_WAIT_FOR_PING;
            self->readHeader();
            self->ping();
#ifdef PROXY_DEBUG
            g_logger.debug("[Proxy {}] connected", self->m_host);
#endif
        });
    });
}

void Proxy::disconnect()
{
    std::error_code ec;
    m_socket.close(ec);
    m_state = STATE_NOT_CONNECTED;
    m_ping = CHECK_INTERVAL * 2;
}

void Proxy::ping()
{
    m_lastPingSent = std::chrono::high_resolution_clock::now();
    m_waitingForPing = true;
    // 2 byte size + 4 byte session (0 so it's ping) + 4 byte packet num (0) + 4 byte last recived packet num + 4 byte local ping
    const auto packet = std::make_shared<ProxyPacket>(18, 0);
    packet->at(0) = 16; // size = 12
    *(uint32_t*)(&packet->data()[10]) = UID;
    *(uint32_t*)(&packet->data()[14]) = m_ping;
    send(packet);
}

void Proxy::onPing(uint32_t /*packetId*/)
{
    if (m_state == STATE_CONNECTING_WAIT_FOR_PING) {
        m_state = STATE_CONNECTED;
    }
    m_waitingForPing = false;
    m_ping = static_cast<uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - m_lastPingSent).count());
}

void Proxy::addSession(const uint32_t id, const int port)
{
    const auto packet = std::make_shared<ProxyPacket>(14, 0);
    packet->at(0) = 12; // size = 12
    *(uint32_t*)(&(packet->data()[2])) = id;
    *(uint32_t*)(&(packet->data()[10])) = port;
    send(packet);
    m_sessions += 1;
}

void Proxy::removeSession(const uint32_t id)
{
    const auto packet = std::make_shared<ProxyPacket>(14, 0);
    packet->at(0) = 12; // size = 12
    *(uint32_t*)(&(packet->data()[2])) = id;
    *(uint32_t*)(&(packet->data()[6])) = 0xFFFFFFFF;
    send(packet);
    m_sessions -= 1;
}

void Proxy::readHeader()
{
    async_read(m_socket, asio::buffer(m_buffer, 2), [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
        capture0->onHeader(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
    });
}

void Proxy::onHeader(const std::error_code& ec, const std::size_t bytes_transferred)
{
    if (ec || bytes_transferred != 2) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Proxy {}] onHeader error {}", m_host, ec.message());
#endif
        return disconnect();
    }

    m_packetsRecived += 1;
    m_bytesRecived += static_cast<int>(bytes_transferred);

    uint16_t packetSize = *(uint16_t*)m_buffer;
    if (packetSize < 12 || packetSize > BUFFER_SIZE) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Proxy {}] onHeader wrong packet size {}", m_host, packetSize);
#endif
        return disconnect();
    }

    async_read(m_socket, asio::buffer(m_buffer, packetSize), [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
        capture0->onPacket(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
    });
}

void Proxy::onPacket(const std::error_code& ec, const std::size_t bytes_transferred)
{
    if (ec || bytes_transferred < 12) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Proxy {}] onPacket error {}", m_host, ec.message());
#endif
        return disconnect();
    }
    m_bytesRecived += static_cast<int>(bytes_transferred);

    uint32_t sessionId = *(uint32_t*)(&m_buffer[0]);
    const uint32_t packetId = *(uint32_t*)(&m_buffer[4]);
    const uint32_t lastRecivedPacketId = *(uint32_t*)(&m_buffer[8]);

    if (sessionId == 0) {
        readHeader();
        return onPing(packetId);
    }
    if (packetId == 0xFFFFFFFFu) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Proxy {}] onPacket, session end: {}", m_host, sessionId);
#endif
        const auto it = g_sessions.find(sessionId);
        if (it != g_sessions.end()) {
            if (const auto session = it->second.lock()) {
                session->terminate();
            }
        }
        readHeader();
        return;
    }

    const uint16_t packetSize = *(uint16_t*)(&m_buffer[12]);

#ifdef PROXY_DEBUG
    // g_logger.debug("[Proxy {}] onPacket, session: {} packetId: {} lastRecivedPacket: {} size: {}", m_host, sessionId, packetId, lastRecivedPacketId, packetSize);
#endif

    const auto packet = std::make_shared<ProxyPacket>(m_buffer + 12, m_buffer + 14 + packetSize);
    const auto it = g_sessions.find(sessionId);
    if (it != g_sessions.end()) {
        if (const auto session = it->second.lock()) {
            session->onProxyPacket(packetId, lastRecivedPacketId, packet);
        }
    }
    readHeader();
}

void Proxy::send(const ProxyPacketPtr& packet)
{
    const bool sendNow = m_sendQueue.empty();
    m_sendQueue.push_back(packet);
    if (sendNow) {
        async_write(m_socket, asio::buffer(packet->data(), packet->size()),
                    [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
            capture0->onSent(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
        });
    }
}

void Proxy::onSent(const std::error_code& ec, const std::size_t bytes_transferred)
{
    if (ec) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Proxy {}] onSent error {}", m_host, ec.message());
#endif
        return disconnect();
    }
    m_packetsSent += 1;
    m_bytesSent += static_cast<int>(bytes_transferred);
    m_sendQueue.pop_front();
    if (!m_sendQueue.empty()) {
        async_write(m_socket, asio::buffer(m_sendQueue.front()->data(), m_sendQueue.front()->size()),
                    [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
            capture0->onSent(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
        });
    }
}

void Session::start(const int maxConnections)
{
#ifdef PROXY_DEBUG
    g_logger.debug("[Session {}] start", m_id);
#endif
    m_maxConnections = maxConnections;
    auto self(shared_from_this());
    post(m_io, [&, self] {
        g_sessions[self->m_id] = self;
        m_lastPacket = std::chrono::high_resolution_clock::now();
        check(std::error_code());
        if (m_useSocket) {
            readHeader();
        }
    });
}

void Session::terminate(std::error_code ec)
{
    if (m_terminated)
        return;
    m_terminated = true;

#ifdef PROXY_DEBUG
    g_logger.debug("[Session {}] terminate", m_id);
#endif

    auto self(shared_from_this());
    post(m_io, [&, ec] {
        g_sessions.erase(m_id);
        if (m_useSocket) {
            std::error_code ecc;
            m_socket.shutdown(asio::ip::tcp::socket::shutdown_both, ecc);
            m_socket.close(ecc);
            m_timer.cancel(ecc);
        } else if (m_disconnectCallback) {
            m_disconnectCallback(ec);
        }

        for (auto& proxy : m_proxies) {
            proxy->removeSession(m_id);
        }
        m_proxies.clear();
    });
}

void Session::check(const std::error_code& ec)
{
    if (ec || m_terminated) {
        return;
    }

    const uint32_t lastPacket = static_cast<uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - m_lastPacket).count());
    if (lastPacket > TIMEOUT) {
        return terminate(asio::error::timed_out);
    }

    selectProxies();

    m_timer.expires_from_now(std::chrono::milliseconds(CHECK_INTERVAL));
    m_timer.async_wait([capture0 = shared_from_this()](auto&& PH1) {
        capture0->check(std::forward<decltype(PH1)>(PH1));
    });
}

void Session::selectProxies()
{
    ProxyPtr worst_ping = nullptr;
    ProxyPtr best_ping = nullptr;
    ProxyPtr candidate_proxy = nullptr;
    for (auto& proxy : g_proxies) {
        if (!proxy->isConnected()) {
            m_proxies.erase(proxy);
            continue;
        }
        if (!m_proxies.contains(proxy)) {
            if (!candidate_proxy || proxy->getPing() < candidate_proxy->getPing()) {
                candidate_proxy = proxy;
            }
            continue;
        }
        if (!best_ping || proxy->getPing() < best_ping->getPing()) {
            best_ping = proxy;
        }
        if (!worst_ping || proxy->getPing() > worst_ping->getPing()) {
            worst_ping = proxy;
        }
    }
    if (candidate_proxy) {
        // change worst to new proxy only if it has at least 20 ms better ping then worst proxy
        const bool disconnectWorst = worst_ping && worst_ping != best_ping && worst_ping->getPing() > candidate_proxy->getPing() + 20;
        if (m_proxies.size() != m_maxConnections || disconnectWorst) {
#ifdef PROXY_DEBUG
            g_logger.debug("[Session {}] new proxy: {}", m_id, candidate_proxy->getHost());
#endif
            candidate_proxy->addSession(m_id, m_port);
            m_proxies.insert(candidate_proxy);
            for (auto& packet : m_proxySendQueue) {
                candidate_proxy->send(packet.second);
            }
        }
        if (m_proxies.size() > m_maxConnections) {
#ifdef PROXY_DEBUG
            g_logger.debug("[Session {}] remove proxy: {}", m_id, worst_ping->getHost());
#endif
            worst_ping->removeSession(m_id);
            m_proxies.erase(worst_ping);
        }
    }
}

void Session::onProxyPacket(uint32_t packetId, uint32_t lastRecivedPacketId, const ProxyPacketPtr& packet)
{
#ifdef PROXY_DEBUG
    g_logger.debug("[Session {}] onProxyPacket, id: {} ({}) last: {} ({}) size: {}", m_id, packetId, m_inputPacketId, lastRecivedPacketId, m_outputPacketId, packet->size());
#endif
    if (packetId < m_inputPacketId) {
        return; // old packet, ignore
    }

    auto it = m_proxySendQueue.begin();
    while (it != m_proxySendQueue.end() && it->first <= lastRecivedPacketId) {
        it = m_proxySendQueue.erase(it);
    }

    m_lastPacket = std::chrono::high_resolution_clock::now();
    const bool sendNow = m_sendQueue.emplace(packetId, packet).second;

    if (!sendNow || packetId != m_inputPacketId) {
        return;
    }

    if (!m_useSocket) {
        while (!m_sendQueue.empty() && m_sendQueue.begin()->first == m_inputPacketId) {
            m_inputPacketId += 1;
            if (m_recvCallback) {
                m_recvCallback(packet);
            }
            m_sendQueue.erase(m_sendQueue.begin());
        }
        return;
    }

    async_write(m_socket, asio::buffer(packet->data(), packet->size()),
                [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
        capture0->onSent(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
    });
}

void Session::readTibia12Header()
{
    auto self(shared_from_this());
    async_read(m_socket, asio::buffer(m_buffer, 1),
                            [self](const std::error_code& ec, std::size_t /*bytes_transferred*/) {
        if (ec) {
            return self->terminate();
        }
        if (self->m_buffer[0] == 0x0A) {
#ifdef PROXY_DEBUG
            g_logger.debug("[Session {}] Tibia 12 read header finished", self->m_id);
#endif
            return self->readHeader();
        }
        self->readTibia12Header();
    });
}

void Session::readHeader()
{
    async_read(m_socket, asio::buffer(m_buffer, 2),
               [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
        capture0->onHeader(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
    });
}

void Session::onHeader(const std::error_code& ec, std::size_t /*bytes_transferred*/)
{
    if (ec) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Session {}] onHeader error: {}", m_id, ec.message());
#endif
        return terminate();
    }

    uint16_t packetSize = *(uint16_t*)(m_buffer);
    if (packetSize > 1024 && m_outputPacketId == 1) {
        return readTibia12Header();
    }

    if (packetSize == 0 || packetSize + 16 > BUFFER_SIZE) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Session {}] onHeader invalid packet size: {}", m_id, packetSize);
#endif
        return terminate();
    }

    async_read(m_socket, asio::buffer(m_buffer + 2, packetSize),
               [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
        capture0->onBody(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
    });
}

void Session::onBody(const std::error_code& ec, const std::size_t bytes_transferred)
{
    if (ec) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Session {}] onBody error: {}", m_id, ec.message());
#endif
        return terminate();
    }

    const auto packet = std::make_shared<ProxyPacket>(m_buffer, m_buffer + bytes_transferred + 2);
    onPacket(packet);

    readHeader();
}

void Session::onPacket(const ProxyPacketPtr& packet)
{
    if (!packet || packet->empty() || packet->size() + 14 > BUFFER_SIZE) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Session {}] onPacket error: missing packet or wrong size", m_id);
#endif
        return terminate();
    }

    auto self(shared_from_this());
    post(m_io, [&, packet] {
        const uint32_t packetId = m_outputPacketId++;
        const auto newPacket = std::make_shared<ProxyPacket>(packet->size() + 14);

        *(uint16_t*)(&(newPacket->data()[0])) = static_cast<uint16_t>(packet->size()) + 12;
        *(uint32_t*)(&(newPacket->data()[2])) = m_id;
        *(uint32_t*)(&(newPacket->data()[6])) = packetId;
        *(uint32_t*)(&(newPacket->data()[10])) = m_inputPacketId - 1;
        std::copy(packet->begin(), packet->end(), newPacket->begin() + 14);

        m_proxySendQueue[packetId] = newPacket;
        for (auto& proxy : m_proxies) {
            proxy->send(newPacket);
        }
    });
}

void Session::onSent(const std::error_code& ec, std::size_t /*bytes_transferred*/)
{
    if (ec) {
#ifdef PROXY_DEBUG
        g_logger.debug("[Session {}] onSent error: {}", m_id, ec.message());
#endif
        return terminate();
    }

    m_inputPacketId += 1;
    m_sendQueue.erase(m_sendQueue.begin());
    if (!m_sendQueue.empty() && m_sendQueue.begin()->first == m_inputPacketId) {
        async_write(m_socket, asio::buffer(m_sendQueue.begin()->second->data(), m_sendQueue.begin()->second->size()),
                    [capture0 = shared_from_this()](auto&& PH1, auto&& PH2) {
            capture0->onSent(std::forward<decltype(PH1)>(PH1), std::forward<decltype(PH2)>(PH2));
        });
    }
}
