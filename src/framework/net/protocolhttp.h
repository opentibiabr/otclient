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
#include <framework/stdext/uri.h>

#ifdef __EMSCRIPTEN__
#include <emscripten/fetch.h>
#include <emscripten/websocket.h>
#else
#include <ixwebsocket/IXHttp.h>
#include <ixwebsocket/IXWebSocket.h>
#endif

#include <atomic>
#include <memory>
#include <mutex>
#include <queue>

#include <zlib.h>

struct HttpResult
{
    std::string url;
    int operationId = 0;
    int status = 0;
    int size = 0;
    std::atomic<int> progress{ 0 }; // from 0 to 100
    std::atomic<int> speed{ 0 };
    int redirects = 0; // redirect
    std::atomic_bool connected{ false };
    std::atomic_bool finished{ false };
    std::atomic_bool canceled{ false };
    std::string postData;
    std::string response;
    std::string error;
#ifndef __EMSCRIPTEN__
    std::shared_ptr<ix::HttpRequestArgs> request;
#endif
};

using HttpResult_ptr = std::shared_ptr<HttpResult>;

class Http
{
public:
    void init();
    void terminate();

    int get(const std::string& url, int timeout = 5);
    // The trailing checkContentLength parameter is preserved for Lua binding
    // compatibility. ixwebsocket does not expose the old Content-Length hook,
    // so new call-sites should omit it.
    int post(const std::string& url, const std::string& data, int timeout = 5, bool isJson = false, bool checkContentLength = true);
    int download(const std::string& url, const std::string& path, int timeout = 5);
    int ws(const std::string& url, int timeout = 5);
    bool wsSend(int operationId, const std::string& message);
    bool wsClose(int operationId);
    bool cancel(int id);

    const std::unordered_map<std::string, HttpResult_ptr>& downloads() const { return m_downloads; }

    void clearDownloads() { m_downloads.clear(); }

    HttpResult_ptr getFile(std::string path)
    {
        if (!path.empty() && path[0] == '/')
            path = path.substr(1);
        const auto it = m_downloads.find(path);
        if (it == m_downloads.end())
            return nullptr;
        return it->second;
    }

    void setUserAgent(const std::string& userAgent) { m_userAgent = userAgent; }

    void addCustomHeader(const std::string& name, const std::string& value) { m_custom_header[name] = value; }

    void setEnableTimeOutOnReadWrite(const bool enable_time_out_on_read_write) { m_enable_time_out_on_read_write = enable_time_out_on_read_write; }

private:
#ifdef __EMSCRIPTEN__
    struct FetchContext;
    struct WebSocketContext;

    static void onFetchSuccess(emscripten_fetch_t* fetch);
    static void onFetchError(emscripten_fetch_t* fetch);
    static void onFetchProgress(emscripten_fetch_t* fetch);
    static EM_BOOL onWebSocketOpen(int eventType, const EmscriptenWebSocketOpenEvent* event, void* userData);
    static EM_BOOL onWebSocketMessage(int eventType, const EmscriptenWebSocketMessageEvent* event, void* userData);
    static EM_BOOL onWebSocketError(int eventType, const EmscriptenWebSocketErrorEvent* event, void* userData);
    static EM_BOOL onWebSocketClose(int eventType, const EmscriptenWebSocketCloseEvent* event, void* userData);

    void completeFetch(FetchContext* context, emscripten_fetch_t* fetch, std::string error);
    void cleanupWebSocket(WebSocketContext* context, const std::string& closeMessage, bool dispatchClose);
#else
    std::string describeHttpError(const ix::HttpResponsePtr& response, bool canceled);
    void copyHeaders(const std::unordered_map<std::string, std::string>& source, ix::WebSocketHttpHeaders& target);
    std::shared_ptr<ix::HttpRequestArgs> buildRequest(const std::string& url, const std::string& verb, int timeout);
#endif

    int computeProgress(const int current, const int total);
    HttpResult_ptr registerOperation(const std::string& url, int& operationId);
    void unregisterOperation(int operationId);
    bool shouldEmitProgress(ticks_t& lastEmit, int progress);

    std::atomic_bool m_working{ false };
    bool m_enable_time_out_on_read_write = false;
    std::atomic<int> m_operationId{ 1 };
    std::unordered_map<int, HttpResult_ptr> m_operations;
#ifdef __EMSCRIPTEN__
    std::unordered_map<int, std::shared_ptr<WebSocketContext>> m_websockets;
#else
    std::unordered_map<int, std::shared_ptr<ix::WebSocket>> m_websockets;
#endif
    std::unordered_map<std::string, HttpResult_ptr> m_downloads;
    std::string m_userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    std::unordered_map<std::string, std::string> m_custom_header;
    std::mutex m_mutex;
};

extern Http g_http;
#ifndef __EMSCRIPTEN__
extern std::shared_ptr<ix::HttpClient> g_ixHttpClient;
#endif
