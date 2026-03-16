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

#include "protocolhttp.h"

#include "framework/core/eventdispatcher.h"
#include "framework/util/crypt.h"

Http g_http;

void Http::init()
{
    m_working = true;
    m_thread = std::thread([this] { m_ios.run(); });
}

void Http::terminate()
{
    if (!m_working)
        return;
    m_working = false;
    for (const auto& ws : m_websockets) {
        ws.second->close();
    }
    for (const auto& op : m_operations) {
        if (const auto& session = op.second->session.lock())
            session->close();
    }
    m_guard.reset();
    if (!m_thread.joinable()) {
        stdext::millisleep(100);
    }
    m_ios.stop();
    m_thread.join();
}

int Http::get(const std::string& url, int timeout)
{
    if (!timeout) // lua is not working with default values
        timeout = 2;
    int operationId = m_operationId++;

    asio::post(m_ios, [&, url, timeout, operationId] {
        auto result = std::make_shared<HttpResult>();
        result->url = url;
        result->operationId = operationId;
        m_operations[operationId] = result;
        const auto& session = std::make_shared<HttpSession>(m_ios, url, m_userAgent, m_enable_time_out_on_read_write, m_custom_header, timeout,
                                                     false, true, result, [this, operationId](HttpResult_ptr result) {
            bool finished = result->finished;
            g_dispatcher.addEvent([result, finished] {
                if (!finished) {
                    g_lua.callGlobalField("g_http", "onGetProgress", result->operationId, result->url, result->progress);
                    return;
                }
                g_lua.callGlobalField("g_http", "onGet", result->operationId, result->url, result->error, result->response);
            });
            if (finished) {
                m_operations.erase(operationId);
            }
        });
        result->session = session;
        session->start();
    });

    return operationId;
}

int Http::post(const std::string& url, const std::string& data, int timeout, bool isJson, bool checkContentLength)
{
    if (!timeout) // lua is not working with default values
        timeout = 2;
    if (data.empty()) {
        g_logger.error("Invalid post request for {}, empty data, use get instead", url);
        return -1;
    }

    int operationId = m_operationId++;
    asio::post(m_ios, [&, url, data, timeout, isJson, checkContentLength, operationId] {
        auto result = std::make_shared<HttpResult>();
        result->url = url;
        result->operationId = operationId;
        result->postData = data;
        m_operations[operationId] = result;
        const auto& session = std::make_shared<HttpSession>(m_ios, url, m_userAgent, m_enable_time_out_on_read_write, m_custom_header, timeout,
                                                     isJson, checkContentLength, result, [this, operationId](HttpResult_ptr result) {
            bool finished = result->finished;
            g_dispatcher.addEvent([result, finished] {
                if (!finished) {
                    g_lua.callGlobalField("g_http", "onPostProgress", result->operationId, result->url, result->progress);
                    return;
                }
                g_lua.callGlobalField("g_http", "onPost", result->operationId, result->url, result->error, result->response);
            });
            if (finished) {
                m_operations.erase(operationId);
            }
        });
        result->session = session;
        session->start();
    });
    return operationId;
}

int Http::download(const std::string& url, const std::string& path, int timeout)
{
    if (!timeout) // lua is not working with default values
        timeout = 2;

    int operationId = m_operationId++;
    asio::post(m_ios, [&, url, path, timeout, operationId] {
        auto result = std::make_shared<HttpResult>();
        result->url = url;
        result->operationId = operationId;
        m_operations[operationId] = result;
        const auto& session = std::make_shared<HttpSession>(m_ios, url, m_userAgent, m_enable_time_out_on_read_write, m_custom_header, timeout,
                                                     false, true, result, [&, path](HttpResult_ptr result) {
            if (!result->finished) {
                g_dispatcher.addEvent([result] {
                    g_lua.callGlobalField("g_http", "onDownloadProgress", result->operationId, result->url, result->progress, result->speed);
                });
                return;
            }

            auto checksum = g_crypt.crc32(result->response, false);
            g_dispatcher.addEvent([this, result, path, checksum] {
                if (result->error.empty()) {
                    if (!path.empty() && path[0] == '/')
                        m_downloads[path.substr(1)] = result;
                    else
                        m_downloads[path] = result;
                }
                g_lua.callGlobalField("g_http", "onDownload", result->operationId, result->url, result->error, path, checksum);
            });

            m_operations.erase(operationId);
        });
        result->session = session;
        session->start();
    });

    return operationId;
}

int Http::ws(const std::string& url, int timeout)
{
    if (!timeout) // lua is not working with default values
        timeout = 2;
    int operationId = m_operationId++;

    asio::post(m_ios, [&, url, timeout, operationId] {
        auto result = std::make_shared<HttpResult>();
        result->url = url;
        result->operationId = operationId;
        m_operations[operationId] = result;
        const auto& session = std::make_shared<WebsocketSession>(m_ios, url, m_userAgent, m_enable_time_out_on_read_write, timeout, result, [&, result](WebsocketCallbackType type, std::string message) {
            g_dispatcher.addEvent([result, type, message] {
                if (type == WebsocketCallbackType::OPEN) {
                    g_lua.callGlobalField("g_http", "onWsOpen", result->operationId, message);
                } else if (type == WebsocketCallbackType::MESSAGE) {
                    g_lua.callGlobalField("g_http", "onWsMessage", result->operationId, message);
                } else if (type == WebsocketCallbackType::CLOSE) {
                    g_lua.callGlobalField("g_http", "onWsClose", result->operationId, message);
                } else if (type == WebsocketCallbackType::ERROR_) {
                    g_lua.callGlobalField("g_http", "onWsError", result->operationId, message);
                }
            });
            if (type == WebsocketCallbackType::CLOSE) {
                m_websockets.erase(result->operationId);
            }
        });
        m_websockets[result->operationId] = session;
        session->start();
    });

    return operationId;
}

bool Http::wsSend(int operationId, const std::string& message)
{
    asio::post(m_ios, [&, operationId, message] {
        const auto wit = m_websockets.find(operationId);
        if (wit == m_websockets.end()) {
            return;
        }
        wit->second->send(message);
    });
    return true;
}

bool Http::wsClose(const int operationId)
{
    cancel(operationId);
    return true;
}

bool Http::cancel(int id)
{
    asio::post(m_ios, [&, id] {
        const auto wit = m_websockets.find(id);
        if (wit != m_websockets.end()) {
            wit->second->close();
        }
        const auto it = m_operations.find(id);
        if (it == m_operations.end())
            return;
        if (it->second->canceled)
            return;
        const auto& session = it->second->session.lock();
        if (session)
            session->close();
    });
    return true;
}

void HttpSession::start()
{
    instance_uri = parseURI(m_url);
    const asio::ip::tcp::resolver::query query_resolver(instance_uri.domain, instance_uri.port);

    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) { sft->onTimeout(ec); });

    if (m_result->postData == "") {
        m_request.append("GET " + instance_uri.query + " HTTP/1.0\r\n");
        m_request.append("Host: " + instance_uri.domain + "\r\n");
        m_request.append("User-Agent: " + m_agent + "\r\n");
        m_request.append("Accept: */*\r\n");
        m_request.append("Accept-Language: en-US,en;q=0.9\r\n");
        m_request.append("Accept-Encoding: identity\r\n");
        m_request.append("Cache-Control: no-cache\r\n");
        m_request.append("Connection: close\r\n");
        for (const auto& ch : m_custom_header) {
            m_request.append(ch.first + ch.second + "\r\n");
        }
        m_request.append("\r\n");
    } else {
        m_request.append("POST " + instance_uri.query + " HTTP/1.0\r\n");
        m_request.append("Host: " + instance_uri.domain + "\r\n");
        m_request.append("User-Agent: " + m_agent + "\r\n");
        m_request.append("Accept: */*\r\n");
        m_request.append("Accept-Language: en-US,en;q=0.9\r\n");
        m_request.append("Accept-Encoding: identity\r\n");
        m_request.append("Cache-Control: no-cache\r\n");
        m_request.append("Connection: close\r\n");
        for (const auto& ch : m_custom_header) {
            m_request.append(ch.first + ch.second + "\r\n");
        }
        if (m_isJson) {
            m_request.append("Content-Type: application/json\r\n");
        } else {
            m_request.append("Content-Type: application/x-www-form-urlencoded\r\n");
        }
        m_request.append("Content-Length: " + std::to_string(m_result->postData.size()) + "\r\n");
        m_request.append("\r\n");
        m_request.append(m_result->postData);
    }

    m_resolver.async_resolve(instance_uri.domain, instance_uri.port, [sft = shared_from_this()](
        const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator) {
        sft->on_resolve(ec, std::move(iterator));
    });
}

void HttpSession::on_resolve(const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator)
{
    if (ec) {
        onError("HttpSession unable to resolve " + m_url + ": " + ec.message());
        return;
    }

    std::error_code _ec;

    // Try to find IPv4 addresses first
    asio::ip::tcp::resolver::iterator end;
    asio::ip::tcp::resolver::iterator ipv4_it = end;
    auto current = iterator;

    while (current != end) {
        if (!current->endpoint().address().is_v6()) {
            ipv4_it = current;
            break;
        }
        ++current;
    }

    // If no IPv4 found, use the original iterator (IPv6)
    const auto& endpoint_to_use = (ipv4_it != end) ? ipv4_it : iterator;

    g_logger.debug("Attempting connection to: {}:{}", instance_uri.domain, instance_uri.port);

    if (instance_uri.port == "443") {
        // For HTTPS, use the SSL stream's underlying socket
        m_ssl.lowest_layer().async_connect(*endpoint_to_use, [sft = shared_from_this()](
            const std::error_code& ec) {
            sft->on_connect(ec);
        });
    } else {
        // For HTTP, use the regular socket
        m_socket.async_connect(*endpoint_to_use, [sft = shared_from_this()](
            const std::error_code& ec) {
            sft->on_connect(ec);
        });
    }
}

void HttpSession::on_connect(const std::error_code& ec)
{
    if (ec) {
        g_logger.error("TCP connection failed: {}", ec.message());
        onError("HttpSession unable to connect " + m_url + ": " + ec.message());
        return;
    }

    g_logger.debug("TCP connection established to: {}:{}", instance_uri.domain, instance_uri.port);

    if (instance_uri.port == "443") {
        g_logger.debug("Starting SSL handshake...");
        m_ssl.set_verify_mode(asio::ssl::verify_none);
        m_ssl.set_verify_callback([](bool, const asio::ssl::verify_context&) {
            return true;
        });

        // Set SNI (Server Name Indication)
        if (!SSL_set_tlsext_host_name(m_ssl.native_handle(), instance_uri.domain.c_str())) {
            const std::error_code _ec{ static_cast<int>(ERR_get_error()), asio::error::get_ssl_category() };
            g_logger.error("Failed to set SNI hostname: {}", _ec.message());
            onError("HttpSession on SSL_set_tlsext_host_name unable to handshake " + m_url + ": " + _ec.message());
            return;
        }

        g_logger.debug("SNI hostname set to: {}", instance_uri.domain);

        m_ssl.async_handshake(asio::ssl::stream_base::client,
                              [sft = shared_from_this()](const std::error_code& ec) {
            if (ec) {
                g_logger.error("SSL handshake failed: {} (category: {})", ec.message(), ec.category().name());
                sft->onError("HttpSession unable to handshake " + sft->m_url + ": " + ec.message());
                return;
            }
            g_logger.debug("SSL handshake completed successfully");
            sft->on_write();
        });
    } else {
        g_logger.debug("HTTP connection (non-SSL), proceeding with request");
        on_write();
    }

    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
}

void HttpSession::on_write()
{
    g_logger.debug("Sending HTTP request to: {}:{}", instance_uri.domain, instance_uri.port);
    g_logger.debug("Request headers: {}", m_request.substr(0, std::min<size_t>(m_request.length(), size_t(200))));

    if (instance_uri.port == "443") {
        async_write(m_ssl, asio::buffer(m_request), [sft = shared_from_this()]
        (const std::error_code& ec, const size_t bytes) { sft->on_request_sent(ec, bytes); });
    } else {
        async_write(m_socket, asio::buffer(m_request), [sft = shared_from_this()]
        (const std::error_code& ec, const size_t bytes) {sft->on_request_sent(ec, bytes); });
    }

    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
}

void HttpSession::on_request_sent(const std::error_code& ec, size_t /*bytes_transferred*/)
{
    if (ec) {
        g_logger.error("Failed to send HTTP request: {}", ec.message());
        onError("HttpSession error on sending request " + m_url + ": " + ec.message());
        return;
    }

    g_logger.debug("HTTP request sent successfully, waiting for response...");

    if (instance_uri.port == "443") {
        async_read_until(
            m_ssl, m_response, "\r\n\r\n",
            [this](const std::error_code& ec, const size_t size) {
            if (ec) {
                g_logger.error("Failed to read HTTP headers: {}", ec.message());
                onError("HttpSession error receiving header " + m_url + ": " + ec.message());
                return;
            }
            g_logger.debug("HTTP headers received ({} bytes)", size);
            std::string header(
                buffers_begin(m_response.data()),
                buffers_begin(m_response.data()) + size);
            m_response.consume(size);

            // Check for Content-Length
            const size_t contentLengthPos = header.find("Content-Length: ");
            if (contentLengthPos != std::string::npos) {
                const size_t len = std::strtoul(
                    header.c_str() + contentLengthPos + sizeof("Content-Length: ") - 1,
                    nullptr, 10);
                m_result->size = len;
                g_logger.debug("Content-Length: {}", len);
            } else {
                // Check for Transfer-Encoding: chunked
                const size_t transferEncodingPos = header.find("Transfer-Encoding: chunked");
                if (transferEncodingPos != std::string::npos) {
                    g_logger.debug("Server using chunked transfer encoding");
                    m_result->size = 0; // Unknown size for chunked
                } else {
                    g_logger.warning("No Content-Length or Transfer-Encoding found in headers");
                    m_result->size = 0; // Unknown size
                }
            }

            async_read(m_ssl, m_response,
                             asio::transfer_at_least(1),
                             [sft = shared_from_this()](
                       const std::error_code& ec, const size_t bytes) {
                sft->on_read(ec, bytes);
            });
        });
    } else {
        async_read_until(
            m_socket, m_response, "\r\n\r\n",
            [this](const std::error_code& ec, const size_t size) {
            if (ec) {
                onError("HttpSession error receiving header " + m_url + ": " + ec.message());
                return;
            }
            std::string header(
                buffers_begin(m_response.data()),
                buffers_begin(m_response.data()) + size);
            m_response.consume(size);

            const size_t pos = header.find("Content-Length: ");
            if (pos != std::string::npos) {
                const size_t len = std::strtoul(
                    header.c_str() + pos + sizeof("Content-Length: ") - 1,
                    nullptr, 10);
                m_result->size = len - m_response.size();
            } else if (m_checkContentLength) {
                onError("HttpSession error receiving header " + m_url + ": " + "Content-Length not found");
                return;
            }

            async_read(m_socket, m_response,
                             asio::transfer_at_least(1),
                             [sft = shared_from_this()](
                       const std::error_code& ec, const size_t bytes) {
                sft->on_read(ec, bytes);
            });
        });
    }

    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
}

void HttpSession::on_read(const std::error_code& ec, const size_t bytes_transferred)
{
    auto on_done_read = [this] {
        m_timer.cancel();
        const auto& data = m_response.data();
        m_result->response.append(buffers_begin(data), buffers_end(data));
        g_logger.debug("HTTP response received ({} bytes): {}", m_result->response.size(), m_result->response);
        m_result->finished = true;
        m_callback(m_result);
    };

    if (ec && ec != asio::error::eof) {
        onError("HttpSession unable to on_read " + m_url + ": " + ec.message());
        return;
    }

    sum_bytes_response += bytes_transferred;
    sum_bytes_speed_response += bytes_transferred;

    if (stdext::millis() > m_last_progress_update) {
        m_result->speed = (sum_bytes_speed_response) / ((stdext::millis() - (m_last_progress_update - 100)));

        if (m_result->size > 0) {
            m_result->progress = (static_cast<double>(sum_bytes_response) / m_result->size) * 100;
        } else {
            // For chunked encoding or unknown size, just show bytes received
            m_result->progress = std::min<int>(static_cast<double>(sum_bytes_response / 1024), 100.0); // Show KB received, max 100%
        }
        m_last_progress_update = stdext::millis() + 100;
        sum_bytes_speed_response = 0;
        m_callback(m_result);
    }

    if (m_enable_time_out_on_read_write) {
        m_timer.expires_after(std::chrono::seconds(m_timeout));
        m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
    } else {
        m_timer.cancel();
    }

    if (instance_uri.port == "443") {
        async_read(m_ssl, m_response,
                         asio::transfer_at_least(1),
                         [sft = shared_from_this(), on_done_read](
                   const std::error_code& ec, const size_t bytes) {
            if (bytes > 0) {
                sft->on_read(ec, bytes);
            } else {
                on_done_read();
            }
        });
    } else {
        async_read(m_socket, m_response,
                         asio::transfer_at_least(1),
                         [sft = shared_from_this(), on_done_read](
                   const std::error_code& ec, const size_t bytes) {
            if (bytes > 0) {
                sft->on_read(ec, bytes);
            } else {
                on_done_read();
            }
        });
    }
}

void HttpSession::close()
{
    m_result->canceled = true;
    g_logger.error("HttpSession close");
    if (instance_uri.port == "443") {
        m_ssl.async_shutdown(
            [sft = shared_from_this()](
            std::error_code ec) {
            if (ec == asio::error::eof) {
                ec = {};
            }

            if (ec) {
                sft->onError("shutdown " + sft->m_url + ": " + ec.message());
            }
        });
    } else {
        std::error_code ec;
        m_socket.shutdown(asio::ip::tcp::socket::shutdown_both, ec);

        // not_connected happens sometimes so don't bother reporting it.
        if (ec && ec != asio::error::not_connected) {
            onError("shutdown " + m_url + ": " + ec.message());
        }
    }
}

void HttpSession::onTimeout(const std::error_code& ec)
{
    if (!ec) {
        // Timer expired - this is an actual timeout
        g_logger.error("HttpSession timeout after {} seconds", m_timeout);
        onError("HttpSession timeout after " + std::to_string(m_timeout) + " seconds");
    }
}

void HttpSession::onError(const std::string& ec, const std::string& /*details*/) const
{
    g_logger.error("{}", ec);
    m_result->error = fmt::format("{}", ec);
    m_result->finished = true;
    m_callback(m_result);
}

void WebsocketSession::start()
{
    instance_uri = parseURI(m_url);
    const asio::ip::tcp::resolver::query query_resolver(instance_uri.domain, instance_uri.port);

    m_request.append("GET " + instance_uri.query + " HTTP/1.1\r\n");
    m_request.append("Host: " + instance_uri.domain + ":" + instance_uri.port + "\r\n");
    m_request.append("Upgrade: websocket\r\n");
    m_request.append("Connection: Upgrade\r\n");
    m_request.append("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n");
    m_request.append("Sec-WebSocket-Version: 13\r\n");
    m_request.append("\r\n");

    m_resolver.async_resolve(
        query_resolver,
        [sft = shared_from_this()](
        const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator) {
        sft->on_resolve(ec, std::move(iterator));
    });
}

void WebsocketSession::on_resolve(const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator)
{
    if (ec) {
        onError("WebsocketSession unable to resolve " + m_url + ": " + ec.message());
        return;
    }

    std::error_code _ec;
    if (instance_uri.port == "443") {
        while (iterator != asio::ip::tcp::resolver::iterator()) {
            m_ssl.lowest_layer().close();
            m_ssl.lowest_layer().connect(*iterator++, _ec);
            if (!_ec) {
                const std::error_code __ec;
                on_connect(__ec);
                break;
            }
        }
    } else {
        while (iterator != asio::ip::tcp::resolver::iterator()) {
            m_socket.close();
            m_socket.connect(*iterator++, _ec);
            if (!_ec) {
                const std::error_code __ec;
                on_connect(__ec);
                break;
            }
        }
    }

    if (_ec) {
        onError("WebsocketSession unable to resolve " + m_url + ": " + ec.message());
        return;
    }

    m_timer.cancel();
    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
}

void WebsocketSession::on_connect(const std::error_code& ec)
{
    if (ec) {
        onError("WebsocketSession unable to on_connect " + m_url + ": " + ec.message());
        return;
    }

    if (instance_uri.port == "443") {
        std::error_code _ec;
        m_ssl.handshake(asio::ssl::stream_base::client, _ec);
        if (_ec) {
            onError("WebsocketSession unable to handshake " + m_url + ": " + _ec.message());
            return;
        }
        async_write(
            m_ssl, asio::buffer(m_request),
            [sft = shared_from_this()](
            const std::error_code& ec, const size_t bytes) {
            sft->on_request_sent(ec, bytes);
        });
    } else {
        async_write(
            m_socket, asio::buffer(m_request),
            [sft = shared_from_this()](
            const std::error_code& ec, const size_t bytes) {
            sft->on_request_sent(ec, bytes);
        });
    }

    m_timer.cancel();
    m_timer.expires_after(std::chrono::seconds(m_timeout));
    m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
}

void WebsocketSession::on_request_sent(const std::error_code& ec, size_t /*bytes_transferred*/)
{
    if (ec) {
        onError("WebsocketSession error on sending request " + m_url + ": " + ec.message());
        return;
    }

    if (instance_uri.port == "443") {
        async_read_until(
            m_ssl, m_response, "\r\n\r\n",
            [this](const std::error_code& ec, const size_t size) {
            if (ec) {
                onError("WebsocketSession error receiving header " + m_url + ": " + ec.message());
                return;
            }
            std::string header(
                buffers_begin(m_response.data()),
                buffers_begin(m_response.data()) + size);
            m_response.consume(size);

            //TODO: Local variable 'websocket_accept' is only assigned but never accessed
            /*size_t pos = header.find("Sec-WebSocket-Accept: ");
            std::string websocket_accept;
            if (pos != std::string::npos) {
                websocket_accept = header.c_str() + pos + sizeof("Sec-WebSocket-Accept: ") - 1;
            }*/

            if (!m_closed && m_ssl.lowest_layer().is_open()) {
                m_handshake_complete = true;
                m_callback(WebsocketCallbackType::OPEN, "code::websocket_open");
                m_timer.cancel();

                while (!m_pending_messages.empty() && !m_closed) {
                    auto msg = m_pending_messages.front();
                    m_pending_messages.pop();
                    send(msg.first, msg.second);
                }

                async_read(m_ssl, m_response,
                                 asio::transfer_at_least(1),
                                 [sft = shared_from_this()](
                           const std::error_code& ec, const size_t bytes) {
                    sft->on_read(ec, bytes);
                });
            }
        });
    } else {
        async_read_until(
            m_socket, m_response, "\r\n\r\n",
            [this](const std::error_code& ec, const size_t size) {
            if (ec) {
                onError("WebsocketSession error receiving header " + m_url + ": " + ec.message());
                return;
            }
            std::string header(
                buffers_begin(m_response.data()),
                buffers_begin(m_response.data()) + size);
            m_response.consume(size);

            //TODO: Local variable 'websocket_accept' is only assigned but never accessed
            /*size_t pos = header.find("Sec-WebSocket-Accept: ");
            std::string websocket_accept;
            if (pos != std::string::npos) {
                websocket_accept = header.c_str() + pos + sizeof("Sec-WebSocket-Accept: ") - 1;
            }*/

            if (!m_closed && m_socket.is_open()) {
                m_handshake_complete = true;
                m_callback(WebsocketCallbackType::OPEN, "code::websocket_open");
                m_timer.cancel();

                while (!m_pending_messages.empty() && !m_closed) {
                    auto msg = m_pending_messages.front();
                    m_pending_messages.pop();
                    send(msg.first, msg.second);
                }

                async_read(m_socket, m_response,
                                 asio::transfer_at_least(1),
                                 [sft = shared_from_this()](
                           const std::error_code& ec, const size_t bytes) {
                    sft->on_read(ec, bytes);
                });
            }
        });
    }
}

void WebsocketSession::on_write(const std::error_code& ec, size_t /*bytes_transferred*/)
{
    if (ec) {
        onError("WebsocketSession unable to on_write " + m_url + ": " + ec.message());
        return;
    }

    if (m_enable_time_out_on_read_write) {
        m_timer.expires_after(std::chrono::seconds(m_timeout));
        m_timer.async_wait([sft = shared_from_this()](const std::error_code& ec) {sft->onTimeout(ec); });
    } else {
        m_timer.cancel();
    }

    if (!m_sendQueue.empty()) {
        m_sendQueue.pop();
    }

    if (instance_uri.port == "443") {
        if (!m_sendQueue.empty())
            async_write(m_ssl, asio::buffer(m_sendQueue.front()), [sft = shared_from_this()](const std::error_code& ec, const size_t bytes) {
            sft->on_write(ec, bytes);
        });
    } else {
        if (!m_sendQueue.empty())
            async_write(
            m_socket, asio::buffer(m_sendQueue.front()),
            [sft = shared_from_this()](
            const std::error_code& ec, const size_t bytes) {
            sft->on_write(ec, bytes);
        });
    }
}

void WebsocketSession::on_read(const std::error_code& ec, const size_t bytes_transferred)
{
    if (ec && ec != asio::error::eof) {
        if (ec != asio::error::operation_aborted && ec != asio::error::not_connected) {
            onError("WebsocketSession unable to on_read " + m_url + ": " + ec.message());
        }
        return;
    }

    if (m_closed || !m_handshake_complete) {
        return;
    }

    stdext::millisleep(100);
    if (bytes_transferred > 0) {
        const auto& data = m_response.data();
        std::string received_data(buffers_begin(data), buffers_begin(data) + bytes_transferred);
        m_read_buffer.append(received_data);
        m_response.consume(bytes_transferred);

        while (m_read_buffer.size() >= 2) {
            size_t frame_start = 0;

            const uint8_t fin_opcode = static_cast<uint8_t>(m_read_buffer[frame_start]);
            const uint8_t mask_len = static_cast<uint8_t>(m_read_buffer[frame_start + 1]);

            const uint8_t opcode = fin_opcode & 0x0F;
            const bool masked = (mask_len & 0x80) != 0;
            uint64_t payload_length = mask_len & 0x7F;

            size_t header_size = 2;

            if (payload_length == 126) {
                if (m_read_buffer.size() < frame_start + 4) break;
                payload_length = (static_cast<uint8_t>(m_read_buffer[frame_start + 2]) << 8) |
                    static_cast<uint8_t>(m_read_buffer[frame_start + 3]);
                header_size += 2;
            } else if (payload_length == 127) {
                if (m_read_buffer.size() < frame_start + 10) break;
                payload_length = 0;
                for (int i = 0; i < 8; i++) {
                    payload_length = (payload_length << 8) | static_cast<uint8_t>(m_read_buffer[frame_start + 2 + i]);
                }
                header_size += 8;
            }

            if (masked) {
                header_size += 4;
            }
            if (m_read_buffer.size() < frame_start + header_size + payload_length) {
                break;
            }
            std::string payload;
            if (payload_length > 0) {
                size_t payload_start = frame_start + header_size;

                if (masked) {
                    std::array<uint8_t, 4> mask;
                    for (int i = 0; i < 4; i++) {
                        mask[i] = static_cast<uint8_t>(m_read_buffer[frame_start + header_size - 4 + i]);
                    }

                    payload.reserve(payload_length);
                    for (uint64_t i = 0; i < payload_length; i++) {
                        uint8_t masked_byte = static_cast<uint8_t>(m_read_buffer[payload_start + i]);
                        payload.push_back(static_cast<char>(masked_byte ^ mask[i % 4]));
                    }
                } else {
                    payload = m_read_buffer.substr(payload_start, payload_length);
                }
            }

            if (opcode == 0x8) {
                close();
                return;
            } else if (opcode == 0x9) {
                send(payload, 0x8A);
            } else if (opcode == 0xA) {
                //
            } else if (opcode == 0x1 || opcode == 0x2 || opcode == 0x0) {
                if (!payload.empty()) {
                    m_callback(WebsocketCallbackType::MESSAGE, payload);
                }
            }
            m_read_buffer.erase(0, frame_start + header_size + payload_length);
        }
    }
    if (!m_closed) {
        if (instance_uri.port == "443") {
            if (m_ssl.lowest_layer().is_open()) {
                async_read(m_ssl, m_response,
                                 asio::transfer_at_least(1),
                                 [sft = shared_from_this()](
                           const std::error_code& ec, const size_t bytes) {
                    sft->on_read(ec, bytes);
                });
            }
        } else {
            if (m_socket.is_open()) {
                async_read(m_socket, m_response,
                                 asio::transfer_at_least(1),
                                 [sft = shared_from_this()](
                           const std::error_code& ec, const size_t bytes) {
                    sft->on_read(ec, bytes);
                });
            }
        }
    }
}

void WebsocketSession::on_close(const std::error_code& ec)
{
    if (!ec) {
        onError("WebsocketSession unable to on_close " + m_url + ": " + ec.message());
        return;
    }
    m_closed = true;
    m_callback(WebsocketCallbackType::CLOSE, "close_code::normal");
}

void WebsocketSession::onError(const std::string& ec, const std::string& /*details*/)
{
    g_logger.error("WebsocketSession error {}", ec);
    m_closed = true;
    m_callback(WebsocketCallbackType::ERROR_, "close_code::error " + ec);
}

void WebsocketSession::onTimeout(const std::error_code& ec)
{
    if (!ec) {
        g_logger.error("WebsocketSession ontimeout {}", ec.message());
        m_closed = true;
        m_callback(WebsocketCallbackType::ERROR_, "close_code::ontimeout " + ec.message());
        close();
    }
}

void WebsocketSession::send(const std::string& data, const uint8_t ws_opcode)
{
    if (!m_handshake_complete || m_closed) {
        if (!m_closed) {
            m_pending_messages.emplace(data, ws_opcode);
        }
        return;
    }
    bool socket_open = false;
    if (instance_uri.port == "443") {
        socket_open = m_ssl.lowest_layer().is_open();
    } else {
        socket_open = m_socket.is_open();
    }

    if (!socket_open) {
        onError("WebsocketSession attempted to send on closed socket " + m_url);
        return;
    }

    std::vector<uint8_t> ws_frame;
    std::array<unsigned char, 4> mask;
    std::uniform_int_distribution<unsigned short> dist(0, 255);
    std::random_device rd;
    for (auto c = 0; c < 4; c++)
        mask[c] = static_cast<unsigned char>(dist(rd));

    const size_t length = data.size();

    if (ws_opcode == 0) {
        /*
            0x81 in binary format is 1000 0001
            1... .... = Fin: True
            .000 .... = Reserved: 0x0
            .... 0001 = Opcode: Text (1)
        */
        ws_frame.push_back(0x81);

        /*
            0x82 in binary format is 1000 0010
            1... .... = Fin: True
            .000 .... = Reserved: 0x0
            .... 0010 = Opcode: Binary (1)

            ws_frame.push_back(0x82);
        */
    } else {
        ws_frame.push_back(ws_opcode);
    }

    /*
        ... size < 126 ...
            128 in binary is 1000 0000 the first bit represent a mask.
            now the other 7 bits represent a size payload

             1000 0000
            +1000 0011
            =1000 0011

            ...
            1... .... = Mask: True
            .000 0011 = Payload length: 3
            ...

        ... size < 65535 ...
            128 ->  1000 0000
            126 -> +0111 1110
            254 -> =1111 1110

            1... .... = Mask: True
            .111 1110 = Payload length: 126 Extended Payload Length (16 bits)
            Extended Payload length (16 bits): 276
    */
    if (length < 126) {
        /*
            7 bit length, 1 bit is to mask
            ...
            1... .... = Mask: True
            .000 0011 = Payload length: 3
            ...
        */
        ws_frame.push_back(length + 128);
    } else {
        size_t num_bytes;
        if (length < 65535) {    // 16 bit length
            /*
                7 bit length, 1 bit is to mask
                1111 1110 == 254
                ...
                1... .... = Mask: True
                .111 1110 = Payload length: 126 Extended Payload Length (16 bits)
                Extended Payload length (16 bits): 276
                ...
            */
            num_bytes = 2;
            ws_frame.push_back(126 + 128);
        } else {                  // 64 bit length
            /*
                7 bit length, 1 bit is to mask
                1111 1111 == 255
                ...
                1... .... = Mask: True
                .111 1111 = Payload length: 127 Extended Payload Length (64 bits)
                Extended Payload length (64 bits): 273299
                ...
            */
            num_bytes = 8;
            ws_frame.push_back(127 + 128);
        }

        for (auto c = num_bytes - 1; c != static_cast<size_t>(-1); c--)
            ws_frame.push_back((static_cast<unsigned long long>(length) >> (8 * c)) % 256);
    }

    //  add mask, the size of mask is 32bits
    for (auto c = 0; c < 4; c++)
        ws_frame.push_back(static_cast<char>(mask[c]));

    // the payload use a mask with xor
    for (size_t c = 0; c < length; c++)
        ws_frame.push_back(data.at(c) ^ mask[c % 4]);

    m_sendQueue.emplace(ws_frame.begin(), ws_frame.end());

    if (m_sendQueue.size() > 1)
        return;

    if (instance_uri.port == "443") {
        async_write(
            m_ssl, asio::buffer(m_sendQueue.front()),
            [sft = shared_from_this()](
            const std::error_code& ec, const size_t bytes) {
            sft->on_write(ec, bytes);
        });
    } else {
        async_write(
            m_socket, asio::buffer(m_sendQueue.front()),
            [sft = shared_from_this()](
            const std::error_code& ec, const size_t bytes) {
            sft->on_write(ec, bytes);
        });
    }
}

void WebsocketSession::close()
{
    if (!m_closed) {
        m_closed = true;
        bool socket_open = false;
        if (instance_uri.port == "443") {
            socket_open = m_ssl.lowest_layer().is_open();
        } else {
            socket_open = m_socket.is_open();
        }

        if (socket_open && m_handshake_complete) {
            /*
                0x88 in binary format is 1000 1000
                1... .... = Fin: True
                .000 .... = Reserved: 0x0
                .... 1000 = Opcode: Connection Close (8)
            */
            try {
                send("", 0x88);
            } catch (...) {
                //
            }
        }

        if (instance_uri.port == "443") {
            try {
                if (m_ssl.lowest_layer().is_open()) {
                    std::error_code ec;
                    m_ssl.lowest_layer().close(ec);
                    m_ssl.async_shutdown(
                        [sft = shared_from_this()](
                        std::error_code ec) {
                        if (ec == asio::error::eof) {
                            ec = {};
                        }
                        if (ec && ec != asio::error::not_connected && ec != asio::error::operation_aborted) {
                            sft->onError("shutdown " + sft->m_url + ": " + ec.message());
                        }
                    });
                }
            } catch (...) {
                //
            }
        } else {
            try {
                if (m_socket.is_open()) {
                    std::error_code ec;
                    m_socket.shutdown(asio::ip::tcp::socket::shutdown_both, ec);
                    m_socket.close(ec);
                    if (ec && ec != asio::error::not_connected && ec != asio::error::operation_aborted) {
                        onError("shutdown " + m_url + ": " + ec.message());
                    }
                }
            } catch (...) {
                //
            }
        }
    }
}