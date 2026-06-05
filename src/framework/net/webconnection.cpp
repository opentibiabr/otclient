/*
 * Copyright (c) 2024 OTArchive <https://otarchive.com>
 * Copyright (c) 2010-2022 OTClient <https://github.com/edubart/otclient>
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
#ifdef __EMSCRIPTEN__

#include "webconnection.h"

#include <framework/core/application.h>
#include <client/game.h>

#include <utility>
#include <asio/read.hpp>
#include <asio/read_until.hpp>
#include <framework/core/eventdispatcher.h>

#include <emscripten/threading.h>

std::list<std::shared_ptr<asio::streambuf>> WebConnection::m_outputStreams;
WebConnection::WebConnection()
{
}

WebConnection::~WebConnection()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    close();
}

void WebConnection::poll()
{
}

void WebConnection::terminate()
{
    emscripten_websocket_deinitialize();
}

void WebConnection::close()
{
    if (!m_connected && !m_connecting)
        return;

    emscripten_websocket_deinitialize();
    m_websocket = 0;

    if (!m_gameWorld)
        return;

    m_connecting = false;
    m_connected = false;
    m_connectCallback = nullptr;
    m_errorCallback = nullptr;
    m_recvCallback = nullptr;

    m_inputStream.consume(m_inputStream.size());

    //Workaround for the abrupt termination of the websocket
    g_dispatcher.addEvent([] {
        g_game.forceLogout();
    });
}

void WebConnection::connect(const std::string_view host, uint16_t port, const std::function<void()>& connectCallback, bool gameWorld)
{
    m_gameWorld = gameWorld;

    m_connected = false;
    m_connecting = true;
    m_connectCallback = connectCallback;

    std::string ip = std::string(host);
    ip.length() == 0 ? ip = "localhost" : ip;

#ifdef NDEBUG
    const std::string prefix = "wss://";
#else
    const std::string prefix = "ws://";
#endif

    m_pthread = pthread_self();

    const std::string url = prefix + ip + ":" + std::to_string(port);
    EmscriptenWebSocketCreateAttributes attributes =
    {
        url.c_str(),
        "binary",
        EM_FALSE // if the webscocket should be created in the main thread. Currently not implemented by emscripten so this does nothing
    };

    m_websocket = emscripten_websocket_new(&attributes);

    if (m_websocket < 1) {
        if (m_errorCallback)
            m_errorCallback(asio::error::network_unreachable);

        close();
        return;
    }

    emscripten_websocket_set_onopen_callback(m_websocket, this, ([](int /*eventType*/, const EmscriptenWebSocketOpenEvent* /*event*/, void* userData) -> EM_BOOL {
        WebConnection* webConnection = static_cast<WebConnection*>(userData);
        webConnection->m_connected = true;

        if (webConnection->m_connectCallback) {
            emscripten_dispatch_to_thread(webConnection->m_pthread, EM_FUNC_SIG_VI, reinterpret_cast<void*>(runOnConnectCallback), nullptr, &webConnection->m_connectCallback);
        }

        webConnection->m_connecting = false;

        return EM_TRUE;
    }));

    emscripten_websocket_set_onerror_callback(m_websocket, this, ([](int /*eventType*/, const EmscriptenWebSocketErrorEvent* /*event*/, void* userData) -> EM_BOOL {
        WebConnection* webConnection = static_cast<WebConnection*>(userData);
        if (webConnection->m_errorCallback) {
            emscripten_dispatch_to_thread(webConnection->m_pthread, EM_FUNC_SIG_VI, reinterpret_cast<void*>(runOnErrorCallback), nullptr, &webConnection->m_errorCallback);
        }
        if (webConnection->m_connected || webConnection->m_connecting) {
            webConnection->close();
        }
        return EM_TRUE;
    }));

    emscripten_websocket_set_onclose_callback(m_websocket, this, ([](int /*eventType*/, const EmscriptenWebSocketCloseEvent* /*event*/, void* userData) -> EM_BOOL {
        WebConnection* webConnection = static_cast<WebConnection*>(userData);
        webConnection->close();
        return EM_TRUE;
    }));

    emscripten_websocket_set_onmessage_callback(m_websocket, this, ([](int /*eventType*/, const EmscriptenWebSocketMessageEvent* webSocketEvent, void* userData) -> EM_BOOL {
        auto numBytes = webSocketEvent->numBytes;
        if (numBytes == 0)
            return EM_TRUE;
        if (webSocketEvent->isText)
            return EM_TRUE;

        uint8_t* const data = webSocketEvent->data;
        auto webConnection = static_cast<WebConnection*>(userData);

        std::ostream os(&webConnection->m_inputStream);
        os.write((const char*)data, numBytes);
        os.flush();

        return EM_TRUE;
    }));
}

bool WebConnection::sendPacket(uint8_t* buffer, uint16_t size)
{
    if (m_websocket < 1) {
        close();
        return false;
    }

    const EMSCRIPTEN_RESULT result = emscripten_websocket_send_binary(m_websocket, buffer, size);
    return (result == EMSCRIPTEN_RESULT_SUCCESS);
}

void WebConnection::write(uint8_t* buffer, size_t size)
{
    if (!m_connected)
        return;

    if (!m_outputStream) {
        if (!m_outputStreams.empty()) {
            m_outputStream = m_outputStreams.front();
            m_outputStreams.pop_front();
        } else
            m_outputStream = std::make_shared<asio::streambuf>();
    }

    std::ostream os(m_outputStream.get());
    os.write((const char*)buffer, size);
    os.flush();

    internal_write();
}

void WebConnection::internal_write()
{
    if (!m_connected)
        return;

    std::shared_ptr<asio::streambuf> outputStream = m_outputStream;
    m_outputStream = nullptr;

    const auto* data = asio::buffer_cast<const uint8_t*>(outputStream->data());
    bool write = sendPacket((uint8_t*)data, outputStream->size());
    if (write) {
        onWrite(outputStream);
    }
}

void WebConnection::read(const uint16_t size, const RecvCallback& callback, int tries)
{
    if (!m_connected)
        return;

    m_recvCallback = callback;

    if (tries > 1000) {
        onTimeout();
        return;
    }

    auto retry = [capture0 = asWebConnection(), size, callback, tries] { capture0->read(size, callback, tries + 1); };

    if (tries == 0) {
        g_dispatcher.addEvent(std::move(retry));
        return;
    }

    if (m_inputStream.size() < size) {
        emscripten_thread_sleep(10);
        g_dispatcher.addEvent(std::move(retry));
        return;
    }

    onRecv(size);
}

void WebConnection::runOnConnectCallback(std::function<void()> callback) {
    callback();
}

void WebConnection::runOnErrorCallback(ErrorCallback callback) {
    callback(asio::error::timed_out);
}

void WebConnection::onWrite(const std::shared_ptr<asio::streambuf>& outputStream)
{
    // free output stream and store for using it again later
    outputStream->consume(outputStream->size());
    m_outputStreams.emplace_back(outputStream);
}

void WebConnection::onRecv(const uint16_t recvSize)
{
    m_activityTimer.restart();

    if (m_connected) {
        if (m_recvCallback) {
            const auto* header = asio::buffer_cast<const char*>(m_inputStream.data());
            m_recvCallback((uint8_t*)header, recvSize);
        }
    }
    m_inputStream.consume(recvSize);
}

void WebConnection::onTimeout()
{
    if (m_errorCallback)
        m_errorCallback(asio::error::timed_out);

    if (m_connected || m_connecting)
        close();
}

int WebConnection::getIp()
{
    g_logger.error("Getting remote ip");
    return 0;
}

#endif