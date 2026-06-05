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

#include <algorithm>
#include <fmt/format.h>
#include <utility>
#include <vector>

Http g_http;
std::shared_ptr<ix::HttpClient> g_ixHttpClient;

void Http::init()
{
    // Construct the client eagerly so every subsequent get/post/download/ws
    // call can rely on it being available. Lazy initialization from each
    // public method was not thread-safe and could construct a second client
    // if a request came in after Http::terminate() reset the pointer.
    if (!g_ixHttpClient) {
        g_ixHttpClient = std::make_shared<ix::HttpClient>(true);
    }
    m_working = true;
}

void Http::terminate()
{
    if (!m_working)
        return;
    m_working = false;

    std::vector<std::shared_ptr<ix::WebSocket>> websockets;
    std::vector<std::shared_ptr<ix::HttpRequestArgs>> requests;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        for (auto& entry : m_websockets) {
            websockets.push_back(entry.second);
        }
        for (auto& entry : m_operations) {
            const auto& result = entry.second;
            if (!result)
                continue;
            result->canceled = true;
            if (result->request) {
                requests.push_back(result->request);
            }
        }
        m_websockets.clear();
        m_operations.clear();
        m_downloads.clear();
    }

    for (const auto& request : requests) {
        if (request) {
            request->cancel = true;
        }
    }

    for (const auto& websocket : websockets) {
        if (websocket) {
            websocket->close();
        }
    }

    g_ixHttpClient.reset();
}

int Http::get(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working || !g_ixHttpClient) {
        g_logger.error("Http::get called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto request = buildRequest(url, ix::HttpClient::kGet, timeout);
    result->request = request;

    const auto lastProgress = std::make_shared<ticks_t>(0);

    request->onProgressCallback = [this, result, lastProgress](int current, int total) {
        if (result->finished || result->canceled)
            return false;

        result->progress = computeProgress(current, total);
        if (!shouldEmitProgress(*lastProgress, result->progress))
            return true;

        g_dispatcher.addEvent([result] {
            if (!result->finished) {
                g_lua.callGlobalField("g_http", "onGetProgress", result->operationId, result->url, result->progress);
            }
        });
        return true;
    };

    const auto callback = [this, operationId, result](const ix::HttpResponsePtr& response) {
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        result->error = describeHttpError(response, result);
        unregisterOperation(operationId);

        g_dispatcher.addEvent([result] {
            g_lua.callGlobalField("g_http", "onGet", result->operationId, result->url, result->error, result->response);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        result->finished = true;
        result->error = "http_error::queue";
        unregisterOperation(operationId);
        g_dispatcher.addEvent([result] {
            g_lua.callGlobalField("g_http", "onGet", result->operationId, result->url, result->error, result->response);
        });
    }

    return operationId;
}

int Http::post(const std::string& url, const std::string& data, int timeout, bool isJson, bool /*checkContentLength*/)
{
    if (!timeout)
        timeout = 2;
    if (data.empty()) {
        g_logger.error("Invalid post request for {}, empty data, use get instead", url);
        return -1;
    }

    if (!m_working || !g_ixHttpClient) {
        g_logger.error("Http::post called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    result->postData = data;

    auto request = buildRequest(url, ix::HttpClient::kPost, timeout);
    request->body = data;
    request->extraHeaders["Accept"] = "*/*";
    request->extraHeaders["Connection"] = "close";
    request->extraHeaders["Content-Type"] = isJson
        ? "application/json"
        : "application/x-www-form-urlencoded";
    result->request = request;

    const auto lastProgress = std::make_shared<ticks_t>(0);

    request->onProgressCallback = [this, result, lastProgress](int current, int total) {
        if (result->finished || result->canceled)
            return false;

        result->progress = computeProgress(current, total);
        if (!shouldEmitProgress(*lastProgress, result->progress))
            return true;

        g_dispatcher.addEvent([result] {
            if (!result->finished) {
                g_lua.callGlobalField("g_http", "onPostProgress", result->operationId, result->url, result->progress);
            }
        });
        return true;
    };

    const auto callback = [this, operationId, result](const ix::HttpResponsePtr& response) {
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        result->error = describeHttpError(response, result);
        unregisterOperation(operationId);

        g_dispatcher.addEvent([result] {
            g_lua.callGlobalField("g_http", "onPost", result->operationId, result->url, result->error, result->response);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        result->finished = true;
        result->error = "http_error::queue";
        unregisterOperation(operationId);
        g_dispatcher.addEvent([result] {
            g_lua.callGlobalField("g_http", "onPost", result->operationId, result->url, result->error, result->response);
        });
    }

    return operationId;
}

int Http::download(const std::string& url, const std::string& path, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working || !g_ixHttpClient) {
        g_logger.error("Http::download called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto request = buildRequest(url, ix::HttpClient::kGet, timeout);
    result->request = request;

    const auto lastSpeedSample = std::make_shared<ticks_t>(stdext::millis());
    const auto lastBytes = std::make_shared<int>(0);
    const auto lastProgress = std::make_shared<ticks_t>(0);

    request->onProgressCallback = [this, result, lastSpeedSample, lastBytes, lastProgress](int current, int total) {
        if (result->finished || result->canceled)
            return false;

        const ticks_t now = stdext::millis();
        const ticks_t elapsed = now - *lastSpeedSample;
        if (elapsed > 0) {
            result->speed = ((current - *lastBytes) * 1000) / elapsed;
            *lastSpeedSample = now;
            *lastBytes = current;
        }
        result->progress = computeProgress(current, total);
        if (!shouldEmitProgress(*lastProgress, result->progress))
            return true;

        g_dispatcher.addEvent([result] {
            if (!result->finished) {
                g_lua.callGlobalField("g_http", "onDownloadProgress", result->operationId, result->url, result->progress, result->speed);
            }
        });
        return true;
    };

    const auto callback = [this, operationId, result, path](const ix::HttpResponsePtr& response) {
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        result->error = describeHttpError(response, result);

        const auto checksum = g_crypt.crc32(result->response, false);
        unregisterOperation(operationId);

        g_dispatcher.addEvent([this, result, path, checksum] {
            if (result->error.empty()) {
                std::string normalizedPath = path;
                if (!normalizedPath.empty() && normalizedPath[0] == '/')
                    normalizedPath = normalizedPath.substr(1);
                m_downloads[normalizedPath] = result;
            }
            g_lua.callGlobalField("g_http", "onDownload", result->operationId, result->url, result->error, path, checksum);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        result->finished = true;
        result->error = "http_error::queue";
        const auto checksum = g_crypt.crc32(result->response, false);
        unregisterOperation(operationId);
        g_dispatcher.addEvent([this, result, path, checksum] {
            g_lua.callGlobalField("g_http", "onDownload", result->operationId, result->url, result->error, path, checksum);
        });
    }

    return operationId;
}

int Http::ws(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working) {
        g_logger.error("Http::ws called while the client is not running ({})", url);
        return -1;
    }

    const int operationId = m_operationId++;
    auto result = std::make_shared<HttpResult>();
    result->url = url;
    result->operationId = operationId;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_operations[operationId] = result;
    }

    auto websocket = std::make_shared<ix::WebSocket>();
    websocket->setUrl(url);
    websocket->setHandshakeTimeout(timeout);
    websocket->setPingInterval(10);
    // Keep the ix::WebSocket reconnection disabled: the Lua callbacks
    // (onWsClose / onWsError) own the reconnection policy so any custom
    // timing, authentication refresh or backoff implemented in the higher
    // level modules keeps working. Re-enabling the built-in reconnection
    // would race with the dispatcher-deferred cleanup of m_websockets.
    websocket->disableAutomaticReconnection();

    ix::WebSocketHttpHeaders headers;
    headers["User-Agent"] = m_userAgent;
    copyHeaders(m_custom_header, headers);
    websocket->setExtraHeaders(headers);

    websocket->setOnMessageCallback([this, operationId, result](const ix::WebSocketMessagePtr& msg) {
        if (!msg)
            return;

        if (msg->type == ix::WebSocketMessageType::Open) {
            result->connected = true;
            g_dispatcher.addEvent([result] {
                g_lua.callGlobalField("g_http", "onWsOpen", result->operationId, "code::websocket_open");
            });
        } else if (msg->type == ix::WebSocketMessageType::Message) {
            const std::string payload = msg->str;
            g_dispatcher.addEvent([result, payload] {
                g_lua.callGlobalField("g_http", "onWsMessage", result->operationId, payload);
            });
        } else if (msg->type == ix::WebSocketMessageType::Error) {
            result->error = msg->errorInfo.reason;
            const std::string errorReason = fmt::format("close_code::error {}", result->error);

            // Mirror the Close branch: transfer the socket ownership to the
            // dispatcher event so its destructor runs off the worker thread.
            // Without this the websocket remained alive in m_websockets after
            // a terminal error, leaking the connection until Http::terminate.
            std::shared_ptr<ix::WebSocket> expiringSocket;
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                const auto wit = m_websockets.find(operationId);
                if (wit != m_websockets.end()) {
                    expiringSocket = std::move(wit->second);
                    m_websockets.erase(wit);
                }
                m_operations.erase(operationId);
            }

            g_dispatcher.addEvent([result, errorReason, expiringSocket = std::move(expiringSocket)] {
                (void)expiringSocket;
                g_lua.callGlobalField("g_http", "onWsError", result->operationId, errorReason);
            });
        } else if (msg->type == ix::WebSocketMessageType::Close) {
            const std::string closeMessage = "close_code::normal";

            // The Close callback runs on the WebSocket's own worker thread.
            // Dropping the last shared_ptr<ix::WebSocket> here triggers
            // ~WebSocket() -> stop() -> thread::join(), which tries to join
            // the current thread and throws resource_deadlock_would_occur,
            // terminating the process. Transfer ownership to the dispatcher
            // event so the destruction happens on the main thread.
            std::shared_ptr<ix::WebSocket> expiringSocket;
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                const auto wit = m_websockets.find(operationId);
                if (wit != m_websockets.end()) {
                    expiringSocket = std::move(wit->second);
                    m_websockets.erase(wit);
                }
                m_operations.erase(operationId);
            }

            g_dispatcher.addEvent([result, closeMessage, expiringSocket = std::move(expiringSocket)] {
                // expiringSocket is destroyed on the dispatcher thread after
                // the callback returns, avoiding the self-join above.
                (void)expiringSocket;
                g_lua.callGlobalField("g_http", "onWsClose", result->operationId, closeMessage);
            });
        }
    });

    // Track the socket before start() so an immediate Close/Error arriving
    // on a fast reject path (TLS failure, TCP RST, server close on handshake)
    // finds the map entry and releases the socket through the deferred-destroy
    // path, rather than silently leaking into m_websockets after the insert
    // completes.
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_websockets[operationId] = websocket;
    }

    websocket->start();

    return operationId;
}

bool Http::wsSend(int operationId, const std::string& message)
{
    std::shared_ptr<ix::WebSocket> websocket;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto it = m_websockets.find(operationId);
        if (it != m_websockets.end()) {
            websocket = it->second;
        }
    }

    if (!websocket)
        return false;

    websocket->send(message);
    return true;
}

bool Http::wsClose(int operationId)
{
    cancel(operationId);
    return true;
}

bool Http::cancel(int id)
{
    std::shared_ptr<ix::WebSocket> websocket;
    HttpResult_ptr result;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto wit = m_websockets.find(id);
        if (wit != m_websockets.end()) {
            websocket = wit->second;
        }
        const auto it = m_operations.find(id);
        if (it != m_operations.end()) {
            result = it->second;
        }
    }

    if (websocket) {
        websocket->close();
    }

    if (result && !result->canceled) {
        result->canceled = true;
        if (result->request) {
            result->request->cancel = true;
        }
    }

    return true;
}

std::string Http::describeHttpError(const ix::HttpResponsePtr& response, const HttpResult_ptr& result)
{
    if (!response) {
        return "http_error::no_response";
    }

    if (response->errorCode == ix::HttpErrorCode::Cancelled || (result && result->canceled)) {
        return "canceled";
    }

    if (response->errorCode != ix::HttpErrorCode::Ok) {
        if (!response->errorMsg.empty()) {
            return response->errorMsg;
        }
        return fmt::format("http_error_code::{}", static_cast<int>(response->errorCode));
    }

    if (response->statusCode < 200 || response->statusCode > 299) {
        if (!response->errorMsg.empty()) {
            return fmt::format("http_status::{} {}", response->statusCode, response->errorMsg);
        }
        return fmt::format("http_status::{}", response->statusCode);
    }

    return std::string();
}

int Http::computeProgress(const int current, const int total)
{
    if (total <= 0) {
        return 0;
    }
    const double value = (static_cast<double>(current) / static_cast<double>(total)) * 100.0;
    return std::clamp(static_cast<int>(value), 0, 100);
}

void Http::copyHeaders(const std::unordered_map<std::string, std::string>& source, ix::WebSocketHttpHeaders& target)
{
    for (const auto& header : source) {
        target[header.first] = header.second;
    }
}

HttpResult_ptr Http::registerOperation(const std::string& url, int& operationId)
{
    operationId = m_operationId++;
    auto result = std::make_shared<HttpResult>();
    result->url = url;
    result->operationId = operationId;

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_operations[operationId] = result;
    }
    return result;
}

std::shared_ptr<ix::HttpRequestArgs> Http::buildRequest(const std::string& url, const std::string& verb, int timeout)
{
    auto request = g_ixHttpClient->createRequest(url, verb);
    request->connectTimeout = timeout;
    if (m_enable_time_out_on_read_write) {
        request->transferTimeout = timeout;
    }
    request->followRedirects = true;
    request->extraHeaders["User-Agent"] = m_userAgent;
    for (const auto& header : m_custom_header) {
        request->extraHeaders[header.first] = header.second;
    }
    return request;
}

void Http::unregisterOperation(int operationId)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_operations.erase(operationId);
}

bool Http::shouldEmitProgress(ticks_t& lastEmit, int progress)
{
    // Port the 100 ms cadence the old ASIO implementation used so a busy
    // download does not flood the dispatcher with a Lua callback per
    // transfer tick. Always emit the terminal 100% update.
    const ticks_t now = stdext::millis();
    if (progress >= 100 || lastEmit == 0 || now - lastEmit >= 100) {
        lastEmit = now;
        return true;
    }
    return false;
}
