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

#include <ixwebsocket/IXHttp.h>
#include <ixwebsocket/IXWebSocket.h>

#include <atomic>
#include <mutex>
#include <queue>

#include <zlib.h>

struct HttpResult
{
    std::string url;
    int operationId = 0;
    int status = 0;
    int size = 0;
    int progress = 0; // from 0 to 100
    int speed = 0;
    int redirects = 0; // redirect
    bool connected = false;
    bool finished = false;
    bool canceled = false;
    std::string postData;
    std::string response;
    std::string error;
    std::shared_ptr<ix::HttpRequestArgs> request;
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
    std::string describeHttpError(const ix::HttpResponsePtr& response, const HttpResult_ptr& result);
    int computeProgress(const int current, const int total);
    void copyHeaders(const std::unordered_map<std::string, std::string>& source, ix::WebSocketHttpHeaders& target);

    HttpResult_ptr registerOperation(const std::string& url, int& operationId);
    std::shared_ptr<ix::HttpRequestArgs> buildRequest(const std::string& url, const std::string& verb, int timeout);
    void unregisterOperation(int operationId);
    bool shouldEmitProgress(ticks_t& lastEmit, int progress);

    bool m_working = false;
    bool m_enable_time_out_on_read_write = false;
    std::atomic<int> m_operationId{ 1 };
    std::unordered_map<int, HttpResult_ptr> m_operations;
    std::unordered_map<int, std::shared_ptr<ix::WebSocket>> m_websockets;
    std::unordered_map<std::string, HttpResult_ptr> m_downloads;
    std::string m_userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    std::unordered_map<std::string, std::string> m_custom_header;
    std::mutex m_mutex;
};

extern Http g_http;
extern std::shared_ptr<ix::HttpClient> g_ixHttpClient;
