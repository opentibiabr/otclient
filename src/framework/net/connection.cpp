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
#ifndef __EMSCRIPTEN__

#include "connection.h"

#include "framework/util/stats.h"
#include "framework/core/graphicalapplication.h"

asio::io_service g_ioService;
std::list<std::shared_ptr<asio::streambuf>> Connection::m_outputStreams;

Connection::Connection() :
    m_readTimer(g_ioService),
    m_writeTimer(g_ioService),
    m_delayedWriteTimer(g_ioService),
    m_resolver(g_ioService),
    m_socket(g_ioService)
{
}

Connection::~Connection()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    close();
}

void Connection::poll()
{
    AutoStat s(STATS_MAIN, "PollConnection");
    g_ioService.restart();
    g_ioService.poll();
}

void Connection::terminate()
{
    g_ioService.stop();
    m_outputStreams.clear();
}

void Connection::close()
{
    if (!m_connected && !m_connecting)
        return;

    if (m_connected && !m_error && m_outputStream)
        internal_write();

    m_connecting = false;
    m_connected = false;
    m_connectCallback = nullptr;
    m_errorCallback = nullptr;
    m_recvCallback = nullptr;

    m_resolver.cancel();
    m_readTimer.cancel();
    m_writeTimer.cancel();
    m_delayedWriteTimer.cancel();

    if (m_socket.is_open()) {
        std::error_code ec;
        m_socket.shutdown(asio::ip::tcp::socket::shutdown_both, ec);
        m_socket.close();
    }
}

void Connection::connect(const std::string_view host, const uint16_t port, const std::function<void()>& connectCallback)
{
    m_connected = false;
    m_connecting = true;
    m_error.clear();
    m_connectCallback = connectCallback;

    auto self = asConnection();
    m_resolver.async_resolve(host.data(), std::to_string(port), [self](const std::error_code& error, asio::ip::tcp::resolver::results_type results) {
        self->onResolve(error, results.begin());
    });

    m_readTimer.cancel();
    m_readTimer.expires_after(std::chrono::seconds(READ_TIMEOUT));
    m_readTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::onResolve(const std::error_code& error, const asio::ip::tcp::resolver::results_type::iterator& endpointIterator)
{
    if (error) {
        handleError(error);
        return;
    }

    internal_connect(endpointIterator);
}

void Connection::internal_connect(const asio::ip::tcp::resolver::results_type::iterator& endpointIterator)
{
    auto self = asConnection();
    m_socket.async_connect(*endpointIterator, [self](const std::error_code& error) {
        self->onConnect(error);
    });

    m_readTimer.cancel();
    m_readTimer.expires_after(std::chrono::seconds(READ_TIMEOUT));
    m_readTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::onConnect(const std::error_code& error)
{
    m_readTimer.cancel();
    if (error) {
        handleError(error);
        return;
    }

    m_connecting = false;
    m_connected = true;
    if (m_connectCallback) {
        m_connectCallback();
        m_connectCallback = nullptr;
    }

    if (m_outputStream)
        internal_write();
}

void Connection::write(const uint8_t* buffer, const size_t size)
{
    if (!m_connected)
        return;

    if (!m_outputStream) {
        if (!m_outputStreams.empty()) {
            m_outputStream = m_outputStreams.front();
            m_outputStreams.pop_front();
        } else
            m_outputStream = std::make_shared<asio::streambuf>();

        auto self = asConnection();
        m_delayedWriteTimer.cancel();
        m_delayedWriteTimer.expires_after(std::chrono::milliseconds(0));
        m_delayedWriteTimer.async_wait([self](const std::error_code& error) {
            self->onCanWrite(error);
        });
    }

    std::ostream os(m_outputStream.get());
    os.write((const char*)buffer, static_cast<std::streamsize>(size));
    os.flush();
}

void Connection::onCanWrite(const std::error_code& error)
{
    if (error) {
        handleError(error);
        return;
    }

    internal_write();
}

void Connection::internal_write()
{
    if (!m_connected)
        return;

    auto self = asConnection();
    std::shared_ptr<asio::streambuf> outputStream = m_outputStream;
    m_outputStream = nullptr;

    asio::async_write(m_socket,
                *outputStream,
                [self, outputStream](const std::error_code& error, size_t writeSize) {
        self->onWrite(error, writeSize, outputStream);
    });

    m_writeTimer.cancel();
    m_writeTimer.expires_after(std::chrono::seconds(WRITE_TIMEOUT));
    m_writeTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::onWrite(const std::error_code& error, size_t /*writeSize*/, const std::shared_ptr<asio::streambuf>& outputStream)
{
    m_writeTimer.cancel();
    if (error) {
        handleError(error);
        return;
    }

    outputStream->consume(outputStream->size());
    m_outputStreams.push_back(outputStream);
}

void Connection::read(const uint16_t bytes, const RecvCallback& callback)
{
    if (!m_connected)
        return;

    m_recvCallback = callback;

    auto self = asConnection();
    asio::async_read(m_socket,
               m_inputStream.prepare(bytes),
               [self](const std::error_code& error, size_t recvSize) {
        self->onRecv(error, recvSize);
    });

    m_readTimer.cancel();
    m_readTimer.expires_after(std::chrono::seconds(READ_TIMEOUT));
    m_readTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::read_until(const std::string_view what, const RecvCallback& callback)
{
    if (!m_connected)
        return;

    m_recvCallback = callback;

    auto self = asConnection();
    asio::async_read_until(m_socket,
                     m_inputStream,
                     what.data(),
                     [self](const std::error_code& error, size_t recvSize) {
        self->onRecv(error, recvSize);
    });

    m_readTimer.cancel();
    m_readTimer.expires_after(std::chrono::seconds(READ_TIMEOUT));
    m_readTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::read_some(const RecvCallback& callback)
{
    if (!m_connected)
        return;

    m_recvCallback = callback;

    auto self = asConnection();
    m_socket.async_read_some(m_inputStream.prepare(RECV_BUFFER_SIZE),
                       [self](const std::error_code& error, size_t recvSize) {
        self->onRecv(error, recvSize);
    });

    m_readTimer.cancel();
    m_readTimer.expires_after(std::chrono::seconds(READ_TIMEOUT));
    m_readTimer.async_wait([self](const std::error_code& error) {
        self->onTimeout(error);
    });
}

void Connection::onRecv(const std::error_code& error, size_t recvSize)
{
    m_readTimer.cancel();
    if (error) {
        handleError(error);
        return;
    }

    m_inputStream.commit(recvSize);

    if (m_recvCallback) {
        std::vector<uint8_t> buffer(recvSize);
        std::istream is(&m_inputStream);
        is.read((char*)&buffer[0], static_cast<std::streamsize>(recvSize));

        m_activityTimer.restart();
        m_recvCallback(&buffer[0], static_cast<uint16_t>(recvSize));
    }
}

void Connection::onTimeout(const std::error_code& error)
{
    if (error == asio::error::operation_aborted)
        return;

    handleError(asio::error::timed_out);
}

void Connection::handleError(const std::error_code& error)
{
    m_error = error;
    if (m_errorCallback)
        m_errorCallback(error);

    close();
}

int Connection::getIp()
{
    std::error_code ec;
    const auto endpoint = m_socket.remote_endpoint(ec);
    if (ec)
        return 0;

    if (endpoint.address().is_v4())
        return static_cast<int>(endpoint.address().to_v4().to_uint());

    return 0;
}

#endif