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
#ifdef __EMSCRIPTEN__
#include <cstring>
#include <limits>
#else
#include <fmt/format.h>
#include <ixwebsocket/IXNetSystem.h>
#endif
#include <utility>
#include <vector>

Http g_http;

#ifdef __EMSCRIPTEN__
namespace {
    enum class FetchKind
    {
        Get,
        Post,
        Download,
    };

    constexpr int httpOkMin = 200;
    constexpr int httpOkMax = 299;

    std::string normalizeDownloadPath(const std::string& path)
    {
        if (!path.empty() && path[0] == '/')
            return path.substr(1);
        return path;
    }

    std::string describeFetchError(const emscripten_fetch_t* fetch, const bool canceled)
    {
        if (canceled)
            return "canceled";
        if (!fetch)
            return "http_error::no_response";
        if (fetch->status < httpOkMin || fetch->status > httpOkMax)
            return "http_status::" + std::to_string(fetch->status);
        return {};
    }
}

struct Http::FetchContext
{
    Http* http = nullptr;
    HttpResult_ptr result;
    FetchKind kind = FetchKind::Get;
    std::string path;
    std::string body;
    ticks_t lastProgress = 0;
    ticks_t lastSpeedSample = stdext::millis();
    int lastBytes = 0;
    std::vector<std::string> headerStorage;
    std::vector<const char*> headerPointers;
};

struct Http::WebSocketContext
{
    Http* http = nullptr;
    HttpResult_ptr result;
    EMSCRIPTEN_WEBSOCKET_T socket = 0;
    bool errorSent = false;
};

void Http::init()
{
    if (m_working.load())
        return;
    m_working.store(true);
}

void Http::terminate()
{
    if (!m_working.load())
        return;
    m_working.store(false);

    std::vector<EMSCRIPTEN_WEBSOCKET_T> websockets;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        for (auto& entry : m_operations) {
            if (entry.second)
                entry.second->canceled = true;
        }
        for (auto& entry : m_websockets) {
            if (entry.second && entry.second->socket > 0)
                websockets.push_back(entry.second->socket);
        }
        m_operations.clear();
        m_downloads.clear();
    }

    for (const auto socket : websockets) {
        emscripten_websocket_close(socket, 1000, "terminate");
    }
}

HttpResult_ptr Http::registerOperation(const std::string& url, int& operationId)
{
    operationId = m_operationId++;
    auto result = std::make_shared<HttpResult>();
    result->url = url;
    result->operationId = operationId;

    std::lock_guard<std::mutex> lock(m_mutex);
    m_operations[operationId] = result;
    return result;
}

void Http::unregisterOperation(int operationId)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_operations.erase(operationId);
}

int Http::computeProgress(const int current, const int total)
{
    if (total <= 0)
        return 0;
    const double value = (static_cast<double>(current) / static_cast<double>(total)) * 100.0;
    return std::clamp(static_cast<int>(value), 0, 100);
}

bool Http::shouldEmitProgress(ticks_t& lastEmit, int progress)
{
    const ticks_t now = stdext::millis();
    if (progress >= 100 || lastEmit == 0 || now - lastEmit >= 100) {
        lastEmit = now;
        return true;
    }
    return false;
}

void Http::onFetchProgress(emscripten_fetch_t* fetch)
{
    if (!fetch || !fetch->userData)
        return;

    auto* context = static_cast<FetchContext*>(fetch->userData);
    const auto& result = context->result;
    if (!result || result->finished.load() || result->canceled.load())
        return;

    const auto current = static_cast<int>(std::min<unsigned long long>(fetch->dataOffset + fetch->numBytes, std::numeric_limits<int>::max()));
    const auto total = static_cast<int>(std::min<unsigned long long>(fetch->totalBytes, std::numeric_limits<int>::max()));
    const int progress = context->http->computeProgress(current, total);
    result->progress = progress;

    if (!context->http->shouldEmitProgress(context->lastProgress, progress))
        return;

    int speed = 0;
    if (context->kind == FetchKind::Download) {
        const ticks_t now = stdext::millis();
        const ticks_t elapsed = now - context->lastSpeedSample;
        if (elapsed > 0) {
            speed = ((current - context->lastBytes) * 1000) / elapsed;
            context->lastSpeedSample = now;
            context->lastBytes = current;
            result->speed = speed;
        } else {
            speed = result->speed.load();
        }
    }

    const int operationId = result->operationId;
    const std::string url = result->url;
    const FetchKind kind = context->kind;
    g_dispatcher.addEvent([operationId, url, progress, speed, kind] {
        if (kind == FetchKind::Get) {
            g_lua.callGlobalField("g_http", "onGetProgress", operationId, url, progress);
        } else if (kind == FetchKind::Post) {
            g_lua.callGlobalField("g_http", "onPostProgress", operationId, url, progress);
        } else {
            g_lua.callGlobalField("g_http", "onDownloadProgress", operationId, url, progress, speed);
        }
    });
}

void Http::completeFetch(FetchContext* rawContext, emscripten_fetch_t* fetch, std::string error)
{
    std::unique_ptr<FetchContext> context(rawContext);
    if (!context || !context->result) {
        if (fetch)
            emscripten_fetch_close(fetch);
        return;
    }

    auto result = context->result;
    std::string body;
    if (fetch) {
        result->status = fetch->status;
        result->size = static_cast<int>(std::min<unsigned long long>(fetch->numBytes, std::numeric_limits<int>::max()));
        if (fetch->data && fetch->numBytes > 0) {
            body.assign(fetch->data, fetch->data + fetch->numBytes);
        }
    }

    if (error.empty())
        error = describeFetchError(fetch, result->canceled.load());

    result->finished = true;
    result->progress = 100;
    result->response = body;
    result->error = error;

    const int operationId = result->operationId;
    const std::string url = result->url;
    unregisterOperation(operationId);

    if (context->kind == FetchKind::Download) {
        const std::string path = context->path;
        const std::string normalizedPath = normalizeDownloadPath(path);
        const auto checksum = g_crypt.crc32(body, false);
        g_dispatcher.addEvent([this, result, operationId, url, error, path, normalizedPath, checksum] {
            if (error.empty())
                m_downloads[normalizedPath] = result;
            g_lua.callGlobalField("g_http", "onDownload", operationId, url, error, path, checksum);
        });
    } else if (context->kind == FetchKind::Post) {
        g_dispatcher.addEvent([operationId, url, error, body] {
            g_lua.callGlobalField("g_http", "onPost", operationId, url, error, body);
        });
    } else {
        g_dispatcher.addEvent([operationId, url, error, body] {
            g_lua.callGlobalField("g_http", "onGet", operationId, url, error, body);
        });
    }

    if (fetch)
        emscripten_fetch_close(fetch);
}

void Http::onFetchSuccess(emscripten_fetch_t* fetch)
{
    auto* context = fetch ? static_cast<FetchContext*>(fetch->userData) : nullptr;
    if (context)
        context->http->completeFetch(context, fetch, {});
}

void Http::onFetchError(emscripten_fetch_t* fetch)
{
    auto* context = fetch ? static_cast<FetchContext*>(fetch->userData) : nullptr;
    if (context)
        context->http->completeFetch(context, fetch, {});
}

int Http::get(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load()) {
        g_logger.error("Http::get called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto context = std::make_unique<FetchContext>();
    context->http = this;
    context->result = result;
    context->kind = FetchKind::Get;
    context->headerStorage.reserve((m_custom_header.size() * 2) + 2);
    context->headerStorage.emplace_back("Accept");
    context->headerStorage.emplace_back("*/*");
    for (const auto& header : m_custom_header) {
        context->headerStorage.emplace_back(header.first);
        context->headerStorage.emplace_back(header.second);
    }
    context->headerPointers.reserve(context->headerStorage.size() + 1);
    for (const auto& header : context->headerStorage)
        context->headerPointers.push_back(header.c_str());
    context->headerPointers.push_back(nullptr);

    emscripten_fetch_attr_t attr;
    emscripten_fetch_attr_init(&attr);
    std::strcpy(attr.requestMethod, "GET");
    attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY;
    attr.timeoutMSecs = timeout * 1000;
    attr.requestHeaders = context->headerPointers.data();
    attr.userData = context.get();
    attr.onsuccess = &Http::onFetchSuccess;
    attr.onerror = &Http::onFetchError;
    attr.onprogress = &Http::onFetchProgress;

    if (!emscripten_fetch(&attr, url.c_str())) {
        completeFetch(context.release(), nullptr, "http_error::queue");
    } else {
        context.release();
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

    if (!m_working.load()) {
        g_logger.error("Http::post called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    result->postData = data;

    auto context = std::make_unique<FetchContext>();
    context->http = this;
    context->result = result;
    context->kind = FetchKind::Post;
    context->body = data;
    context->headerStorage.reserve((m_custom_header.size() * 2) + 4);
    context->headerStorage.emplace_back("Accept");
    context->headerStorage.emplace_back("*/*");
    context->headerStorage.emplace_back("Content-Type");
    context->headerStorage.emplace_back(isJson ? "application/json" : "application/x-www-form-urlencoded");
    for (const auto& header : m_custom_header) {
        context->headerStorage.emplace_back(header.first);
        context->headerStorage.emplace_back(header.second);
    }
    context->headerPointers.reserve(context->headerStorage.size() + 1);
    for (const auto& header : context->headerStorage)
        context->headerPointers.push_back(header.c_str());
    context->headerPointers.push_back(nullptr);

    emscripten_fetch_attr_t attr;
    emscripten_fetch_attr_init(&attr);
    std::strcpy(attr.requestMethod, "POST");
    attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY;
    attr.timeoutMSecs = timeout * 1000;
    attr.requestHeaders = context->headerPointers.data();
    attr.requestData = context->body.data();
    attr.requestDataSize = context->body.size();
    attr.userData = context.get();
    attr.onsuccess = &Http::onFetchSuccess;
    attr.onerror = &Http::onFetchError;
    attr.onprogress = &Http::onFetchProgress;

    if (!emscripten_fetch(&attr, url.c_str())) {
        completeFetch(context.release(), nullptr, "http_error::queue");
    } else {
        context.release();
    }

    return operationId;
}

int Http::download(const std::string& url, const std::string& path, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load()) {
        g_logger.error("Http::download called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto context = std::make_unique<FetchContext>();
    context->http = this;
    context->result = result;
    context->kind = FetchKind::Download;
    context->path = path;
    context->headerStorage.reserve((m_custom_header.size() * 2) + 2);
    context->headerStorage.emplace_back("Accept");
    context->headerStorage.emplace_back("*/*");
    for (const auto& header : m_custom_header) {
        context->headerStorage.emplace_back(header.first);
        context->headerStorage.emplace_back(header.second);
    }
    context->headerPointers.reserve(context->headerStorage.size() + 1);
    for (const auto& header : context->headerStorage)
        context->headerPointers.push_back(header.c_str());
    context->headerPointers.push_back(nullptr);

    emscripten_fetch_attr_t attr;
    emscripten_fetch_attr_init(&attr);
    std::strcpy(attr.requestMethod, "GET");
    attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY;
    attr.timeoutMSecs = timeout * 1000;
    attr.requestHeaders = context->headerPointers.data();
    attr.userData = context.get();
    attr.onsuccess = &Http::onFetchSuccess;
    attr.onerror = &Http::onFetchError;
    attr.onprogress = &Http::onFetchProgress;

    if (!emscripten_fetch(&attr, url.c_str())) {
        completeFetch(context.release(), nullptr, "http_error::queue");
    } else {
        context.release();
    }

    return operationId;
}

EM_BOOL Http::onWebSocketOpen(int, const EmscriptenWebSocketOpenEvent*, void* userData)
{
    auto* context = static_cast<WebSocketContext*>(userData);
    if (!context || !context->result)
        return EM_TRUE;

    auto result = context->result;
    result->connected = true;
    const int operationId = result->operationId;
    g_dispatcher.addEvent([operationId] {
        g_lua.callGlobalField("g_http", "onWsOpen", operationId, "code::websocket_open");
    });
    return EM_TRUE;
}

EM_BOOL Http::onWebSocketMessage(int, const EmscriptenWebSocketMessageEvent* event, void* userData)
{
    auto* context = static_cast<WebSocketContext*>(userData);
    if (!context || !context->result || !event || !event->data || event->numBytes == 0)
        return EM_TRUE;

    const int operationId = context->result->operationId;
    const std::string payload(reinterpret_cast<const char*>(event->data), event->numBytes);
    g_dispatcher.addEvent([operationId, payload] {
        g_lua.callGlobalField("g_http", "onWsMessage", operationId, payload);
    });
    return EM_TRUE;
}

EM_BOOL Http::onWebSocketError(int, const EmscriptenWebSocketErrorEvent*, void* userData)
{
    auto* context = static_cast<WebSocketContext*>(userData);
    if (!context || !context->result)
        return EM_TRUE;

    if (!context->errorSent) {
        context->errorSent = true;
        const int operationId = context->result->operationId;
        const std::string errorReason = "close_code::error websocket";
        context->result->error = errorReason;
        g_dispatcher.addEvent([operationId, errorReason] {
            g_lua.callGlobalField("g_http", "onWsError", operationId, errorReason);
        });
    }

    if (context->socket > 0)
        emscripten_websocket_close(context->socket, 1000, "error");
    return EM_TRUE;
}

void Http::cleanupWebSocket(WebSocketContext* context, const std::string& closeMessage, bool dispatchClose)
{
    if (!context || !context->result)
        return;

    const int operationId = context->result->operationId;
    std::shared_ptr<WebSocketContext> owner;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto it = m_websockets.find(operationId);
        if (it != m_websockets.end() && it->second.get() == context) {
            owner = it->second;
            m_websockets.erase(it);
        }
        m_operations.erase(operationId);
    }

    if (dispatchClose && m_working.load()) {
        g_dispatcher.addEvent([operationId, closeMessage] {
            g_lua.callGlobalField("g_http", "onWsClose", operationId, closeMessage);
        });
    }
}

EM_BOOL Http::onWebSocketClose(int, const EmscriptenWebSocketCloseEvent*, void* userData)
{
    auto* context = static_cast<WebSocketContext*>(userData);
    if (!context || !context->http)
        return EM_TRUE;

    context->http->cleanupWebSocket(context, "close_code::normal", !context->errorSent);
    return EM_TRUE;
}

int Http::ws(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load()) {
        g_logger.error("Http::ws called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto context = std::make_shared<WebSocketContext>();
    context->http = this;
    context->result = result;

    EmscriptenWebSocketCreateAttributes attributes = {
        url.c_str(),
        nullptr,
        EM_FALSE,
    };

    const EMSCRIPTEN_WEBSOCKET_T socket = emscripten_websocket_new(&attributes);
    if (socket <= 0) {
        const std::string errorReason = "close_code::error websocket_create";
        unregisterOperation(operationId);
        g_dispatcher.addEvent([operationId, errorReason] {
            g_lua.callGlobalField("g_http", "onWsError", operationId, errorReason);
        });
        return operationId;
    }

    context->socket = socket;
    auto* rawContext = context.get();
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_websockets[operationId] = context;
    }

    emscripten_websocket_set_onopen_callback(socket, rawContext, &Http::onWebSocketOpen);
    emscripten_websocket_set_onmessage_callback(socket, rawContext, &Http::onWebSocketMessage);
    emscripten_websocket_set_onerror_callback(socket, rawContext, &Http::onWebSocketError);
    emscripten_websocket_set_onclose_callback(socket, rawContext, &Http::onWebSocketClose);

    return operationId;
}

bool Http::wsSend(int operationId, const std::string& message)
{
    EMSCRIPTEN_WEBSOCKET_T socket = 0;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto it = m_websockets.find(operationId);
        if (it != m_websockets.end() && it->second)
            socket = it->second->socket;
    }

    if (socket <= 0)
        return false;

    return emscripten_websocket_send_utf8_text(socket, message.c_str()) == EMSCRIPTEN_RESULT_SUCCESS;
}

bool Http::wsClose(int operationId)
{
    cancel(operationId);
    return true;
}

bool Http::cancel(int id)
{
    EMSCRIPTEN_WEBSOCKET_T socket = 0;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        const auto it = m_operations.find(id);
        if (it != m_operations.end() && it->second)
            it->second->canceled = true;
        const auto wit = m_websockets.find(id);
        if (wit != m_websockets.end() && wit->second)
            socket = wit->second->socket;
    }

    if (socket > 0)
        emscripten_websocket_close(socket, 1000, "cancel");

    return true;
}

#else
std::shared_ptr<ix::HttpClient> g_ixHttpClient;

void Http::init()
{
    if (m_working.load())
        return;

    ix::initNetSystem();

    // Construct the client eagerly so every subsequent get/post/download/ws
    // call can rely on it being available. Lazy initialization from each
    // public method was not thread-safe and could construct a second client
    // if a request came in after Http::terminate() reset the pointer.
    if (!g_ixHttpClient) {
        g_ixHttpClient = std::make_shared<ix::HttpClient>(true);
    }
    m_working.store(true);
}

void Http::terminate()
{
    if (!m_working.load())
        return;
    m_working.store(false);

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
    ix::uninitNetSystem();
}

int Http::get(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load() || !g_ixHttpClient) {
        g_logger.error("Http::get called while the client is not running ({})", url);
        return -1;
    }

    int operationId = 0;
    auto result = registerOperation(url, operationId);
    auto request = buildRequest(url, ix::HttpClient::kGet, timeout);
    result->request = request;

    const auto lastProgress = std::make_shared<ticks_t>(0);

    request->onProgressCallback = [this, result, lastProgress](int current, int total) {
        const int progress = computeProgress(current, total);

        if (result->finished.load() || result->canceled.load())
            return false;
        result->progress = progress;

        if (!shouldEmitProgress(*lastProgress, progress))
            return true;

        g_dispatcher.addEvent([result, progress] {
            if (result->finished.load() || result->canceled.load())
                return;
            g_lua.callGlobalField("g_http", "onGetProgress", result->operationId, result->url, progress);
        });
        return true;
    };

    const auto callback = [this, operationId, result](const ix::HttpResponsePtr& response) {
        std::string error;
        std::string body;
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        error = describeHttpError(response, result->canceled.load());
        result->error = error;
        body = result->response;
        unregisterOperation(operationId);

        g_dispatcher.addEvent([result, error, body] {
            g_lua.callGlobalField("g_http", "onGet", result->operationId, result->url, error, body);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        const std::string error = "http_error::queue";
        std::string body;
        result->finished = true;
        result->error = error;
        body = result->response;
        unregisterOperation(operationId);
        g_dispatcher.addEvent([result, error, body] {
            g_lua.callGlobalField("g_http", "onGet", result->operationId, result->url, error, body);
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

    if (!m_working.load() || !g_ixHttpClient) {
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
        const int progress = computeProgress(current, total);

        if (result->finished.load() || result->canceled.load())
            return false;
        result->progress = progress;

        if (!shouldEmitProgress(*lastProgress, progress))
            return true;

        g_dispatcher.addEvent([result, progress] {
            if (result->finished.load() || result->canceled.load())
                return;
            g_lua.callGlobalField("g_http", "onPostProgress", result->operationId, result->url, progress);
        });
        return true;
    };

    const auto callback = [this, operationId, result](const ix::HttpResponsePtr& response) {
        std::string error;
        std::string body;
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        error = describeHttpError(response, result->canceled.load());
        result->error = error;
        body = result->response;
        unregisterOperation(operationId);

        g_dispatcher.addEvent([result, error, body] {
            g_lua.callGlobalField("g_http", "onPost", result->operationId, result->url, error, body);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        const std::string error = "http_error::queue";
        std::string body;
        result->finished = true;
        result->error = error;
        body = result->response;
        unregisterOperation(operationId);
        g_dispatcher.addEvent([result, error, body] {
            g_lua.callGlobalField("g_http", "onPost", result->operationId, result->url, error, body);
        });
    }

    return operationId;
}

int Http::download(const std::string& url, const std::string& path, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load() || !g_ixHttpClient) {
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
        const ticks_t now = stdext::millis();
        const ticks_t elapsed = now - *lastSpeedSample;
        const int progress = computeProgress(current, total);
        int speed = 0;

        if (result->finished.load() || result->canceled.load())
            return false;

        if (elapsed > 0) {
            speed = ((current - *lastBytes) * 1000) / elapsed;
            result->speed = speed;
            *lastSpeedSample = now;
            *lastBytes = current;
        } else {
            speed = result->speed.load();
        }
        result->progress = progress;

        if (!shouldEmitProgress(*lastProgress, progress))
            return true;

        g_dispatcher.addEvent([result, progress, speed] {
            if (result->finished.load() || result->canceled.load())
                return;
            g_lua.callGlobalField("g_http", "onDownloadProgress", result->operationId, result->url, progress, speed);
        });
        return true;
    };

    const auto callback = [this, operationId, result, path](const ix::HttpResponsePtr& response) {
        std::string error;
        std::string body;
        result->finished = true;
        if (response) {
            result->status = response->statusCode;
            result->response = response->body;
            result->size = static_cast<int>(response->body.size());
            result->progress = 100;
        }
        error = describeHttpError(response, result->canceled.load());
        result->error = error;
        body = result->response;

        const auto checksum = g_crypt.crc32(body, false);
        unregisterOperation(operationId);

        g_dispatcher.addEvent([this, result, path, error, checksum] {
            if (error.empty()) {
                std::string normalizedPath = path;
                if (!normalizedPath.empty() && normalizedPath[0] == '/')
                    normalizedPath = normalizedPath.substr(1);
                std::lock_guard<std::mutex> lock(m_mutex);
                m_downloads[normalizedPath] = result;
            }
            g_lua.callGlobalField("g_http", "onDownload", result->operationId, result->url, error, path, checksum);
        });
    };

    if (!g_ixHttpClient->performRequest(request, callback)) {
        const std::string error = "http_error::queue";
        std::string body;
        result->finished = true;
        result->error = error;
        body = result->response;
        const auto checksum = g_crypt.crc32(body, false);
        unregisterOperation(operationId);
        g_dispatcher.addEvent([result, path, error, checksum] {
            g_lua.callGlobalField("g_http", "onDownload", result->operationId, result->url, error, path, checksum);
        });
    }

    return operationId;
}

int Http::ws(const std::string& url, int timeout)
{
    if (!timeout)
        timeout = 2;

    if (!m_working.load()) {
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
    std::shared_ptr<ix::HttpRequestArgs> request;
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

        if (result && !result->canceled.load()) {
            result->canceled = true;
            request = result->request;
        }
    }

    if (websocket) {
        websocket->close();
    }

    if (request) {
        request->cancel = true;
    }

    return true;
}

std::string Http::describeHttpError(const ix::HttpResponsePtr& response, bool canceled)
{
    if (!response) {
        return "http_error::no_response";
    }

    if (response->errorCode == ix::HttpErrorCode::Cancelled || canceled) {
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

#endif
