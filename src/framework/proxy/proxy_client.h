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

using ProxyPacket = std::vector<uint8_t>;
using ProxyPacketPtr = std::shared_ptr<ProxyPacket>;

class Session;
using SessionPtr = std::shared_ptr<Session>;

class Proxy : public std::enable_shared_from_this<Proxy>
{
    static constexpr int CHECK_INTERVAL = 2500; // also timeout for ping
    static constexpr int BUFFER_SIZE = 65535;
    enum ProxyState
    {
        STATE_NOT_CONNECTED,
        STATE_CONNECTING,
        STATE_CONNECTING_WAIT_FOR_PING,
        STATE_CONNECTED
    };
public:
    Proxy(asio::io_context& io, const std::string& host, const uint16_t port, const int priority)
        : m_io(io), m_timer(io), m_socket(io), m_resolver(io)

    {
        m_host = host;
        m_port = port;
        m_priority = priority;
    }

    // thread-safe
    void start();
    void terminate();

    uint32_t getPing() { return m_ping + m_priority; }
    uint32_t getRealPing() { return m_ping; }
    uint32_t getPriority() { return m_priority; }
    bool isConnected() { return m_state == STATE_CONNECTED; }
    std::string getHost() { return m_host; }
    uint16_t getPort() { return m_port; }
    std::string getDebugInfo();
    bool isActive() { return m_sessions > 0; }

    // not thread-safe
    void addSession(uint32_t id, int m_port);
    void removeSession(uint32_t id);

    void send(const ProxyPacketPtr& packet);

private:
    void check(const std::error_code& ec);
    void connect();
    void disconnect();

    void ping();
    void onPing(uint32_t packetId);

    void readHeader();
    void onHeader(const std::error_code& ec, std::size_t bytes_transferred);
    void onPacket(const std::error_code& ec, std::size_t bytes_transferred);
    void onSent(const std::error_code& ec, std::size_t bytes_transferred);

    asio::io_context& m_io;
    asio::steady_timer m_timer;
    asio::ip::tcp::socket m_socket;
    asio::ip::tcp::resolver m_resolver;

    ProxyState m_state{ STATE_NOT_CONNECTED };

    std::string m_host;
    uint16_t m_port;

    bool m_terminated = false;

    uint8_t m_buffer[BUFFER_SIZE];
    std::list<ProxyPacketPtr> m_sendQueue;

    bool m_waitingForPing;
    uint32_t m_ping = 0;
    int m_priority = 0;
    std::chrono::time_point<std::chrono::high_resolution_clock> m_lastPingSent;

    int m_packetsRecived = 0;
    int m_packetsSent = 0;
    int m_bytesRecived = 0;
    int m_bytesSent = 0;
    int m_connections = 0;
    int m_sessions = 0;
    std::string m_resolvedIp;
};

using ProxyPtr = std::shared_ptr<Proxy>;

class Session : public std::enable_shared_from_this<Session>
{
    static constexpr int CHECK_INTERVAL = 500;
    static constexpr int BUFFER_SIZE = 65535;
    static constexpr int TIMEOUT = 30000;
public:
    Session(asio::io_context& io, asio::ip::tcp::socket socket, const int port)
        : m_io(io), m_timer(io), m_socket(std::move(socket))
    {
        m_id = (std::chrono::high_resolution_clock::now().time_since_epoch().count()) & 0xFFFFFFFF;
        if (m_id == 0) m_id = 1;
        m_port = port;
        m_useSocket = true;
    }

    Session(asio::io_context& io, const int port, std::function<void(ProxyPacketPtr)> recvCallback, std::function<void(std::error_code)> disconnectCallback)
        : m_io(io), m_timer(io), m_socket(io)
    {
        m_id = (std::chrono::high_resolution_clock::now().time_since_epoch().count()) & 0xFFFFFFFF;
        if (m_id == 0) m_id = 1;
        m_port = port;
        m_useSocket = false;
        m_recvCallback = recvCallback;
        m_disconnectCallback = disconnectCallback;
    }

    // thread safe
    uint32_t getId() { return m_id; }
    void start(int maxConnections = 3);
    void terminate(std::error_code ec = asio::error::eof);
    void onPacket(const ProxyPacketPtr& packet);

    // not thread safe
    void onProxyPacket(uint32_t packetId, uint32_t lastRecivedPacketId, const ProxyPacketPtr& packet);

private:
    void check(const std::error_code& ec);
    void selectProxies();

    void readTibia12Header();
    void readHeader();
    void onHeader(const std::error_code& ec, std::size_t bytes_transferred);
    void onBody(const std::error_code& ec, std::size_t bytes_transferred);
    void onSent(const std::error_code& ec, std::size_t bytes_transferred);

    asio::io_context& m_io;
    asio::steady_timer m_timer;
    asio::ip::tcp::socket m_socket;

    uint32_t m_id;
    uint16_t m_port;
    bool m_useSocket;
    bool m_terminated = false;

    std::function<void(ProxyPacketPtr)> m_recvCallback = nullptr;
    std::function<void(std::error_code)> m_disconnectCallback = nullptr;

    std::set<ProxyPtr> m_proxies;

    size_t m_maxConnections;

    uint8_t m_buffer[BUFFER_SIZE];
    std::map<uint32_t, ProxyPacketPtr> m_sendQueue;
    std::map<uint32_t, ProxyPacketPtr> m_proxySendQueue;

    uint32_t m_inputPacketId = 1;
    uint32_t m_outputPacketId = 1;

    std::chrono::time_point<std::chrono::high_resolution_clock> m_lastPacket;
};
