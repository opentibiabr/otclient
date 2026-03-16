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

 //  result
class HttpSession;

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
    std::weak_ptr<HttpSession> session;
};

using HttpResult_ptr = std::shared_ptr<HttpResult>;
using HttpResult_cb = std::function<void(HttpResult_ptr)>;

//  session

class HttpSession : public std::enable_shared_from_this<HttpSession>
{
public:

    HttpSession(asio::io_service& service, std::string url, std::string agent,
                const bool& enable_time_out_on_read_write,
                const std::unordered_map<std::string, std::string>& custom_header,
                const int timeout, const bool isJson, const bool checkContentLength, HttpResult_ptr result, HttpResult_cb callback) :
        m_service(service),
        m_url(std::move(url)),
        m_agent(std::move(agent)),
        m_enable_time_out_on_read_write(enable_time_out_on_read_write),
        m_custom_header(custom_header),
        m_timeout(timeout),
        m_isJson(isJson),
        m_checkContentLength(checkContentLength),
        m_result(std::move(result)),
        m_callback(std::move(callback)),
        m_socket(service),
        m_resolver(service),
        m_timer(service)
    {
        assert(m_callback != nullptr);
        assert(m_result != nullptr);

        // Configure SSL context properly
        m_context.set_default_verify_paths();
        m_context.set_verify_mode(asio::ssl::verify_none);
        m_context.set_options(asio::ssl::context::default_workarounds |
                              asio::ssl::context::no_sslv2 |
                              asio::ssl::context::no_sslv3 |
                              asio::ssl::context::single_dh_use);
    };
    void start();
    void cancel() const { onError("canceled"); }
    void close();

private:
    asio::io_service& m_service;
    std::string m_url;
    std::string m_agent;
    bool m_enable_time_out_on_read_write;
    std::unordered_map<std::string, std::string> m_custom_header;
    int m_timeout;
    bool m_isJson;
    bool m_checkContentLength;
    HttpResult_ptr m_result;
    HttpResult_cb m_callback;
    asio::ip::tcp::socket m_socket;
    asio::ip::tcp::resolver m_resolver;
    asio::steady_timer m_timer;
    ParsedURI instance_uri;

    asio::ssl::context m_context{ asio::ssl::context::sslv23_client };
    asio::ssl::stream<asio::ip::tcp::socket> m_ssl{ m_service, m_context };

    std::string m_request;
    asio::streambuf m_response;
    int sum_bytes_response = 0;
    int sum_bytes_speed_response = 0;
    ticks_t m_last_progress_update = stdext::millis();

    void on_resolve(const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator);
    void on_connect(const std::error_code& ec);

    void on_request_sent(const std::error_code& ec, size_t bytes_transferred);

    void on_write();
    void on_read(const std::error_code& ec, size_t bytes_transferred);

    void onTimeout(const std::error_code& ec);
    void onError(const std::string& ec, const std::string& details = "") const;
};

//  web socket
enum class WebsocketCallbackType { OPEN, MESSAGE, ERROR_, CLOSE };
using WebsocketSession_cb = std::function<void(WebsocketCallbackType, const std::string& message)>;

class WebsocketSession : public std::enable_shared_from_this<WebsocketSession>
{
public:

    WebsocketSession(asio::io_service& service, std::string url, std::string agent,
                     const bool& enable_time_out_on_read_write, const int timeout, HttpResult_ptr result, WebsocketSession_cb callback) :
        m_service(service),
        m_url(std::move(url)),
        m_agent(std::move(agent)),
        m_enable_time_out_on_read_write(enable_time_out_on_read_write),
        m_timeout(timeout),
        m_result(std::move(result)),
        m_callback(std::move(callback)),
        m_timer(service),
        m_socket(service),
        m_resolver(service)
    {
        assert(m_callback != nullptr);
        assert(m_result != nullptr);
    };

    void start();
    void send(const std::string& data, uint8_t ws_opcode = 0);
    void close();

private:
    asio::io_service& m_service;
    std::string m_url;
    std::string m_agent;
    std::string m_read_buffer;
    std::queue<std::pair<std::string, uint8_t>> m_pending_messages;
    bool m_enable_time_out_on_read_write;
    int m_timeout;
    HttpResult_ptr m_result;
    WebsocketSession_cb m_callback;
    asio::steady_timer m_timer;
    asio::ip::tcp::socket m_socket;
    asio::ip::tcp::resolver m_resolver;
    bool m_closed{ false };
    bool m_handshake_complete{ false };
    ParsedURI instance_uri;

    asio::ssl::context m_context{ asio::ssl::context::sslv23_client };
    asio::ssl::stream<asio::ip::tcp::socket> m_ssl{ m_service, m_context };

    std::queue<std::string> m_sendQueue;

    std::string m_request;
    asio::streambuf m_response;

    void on_resolve(const std::error_code& ec, asio::ip::tcp::resolver::iterator iterator);
    void on_connect(const std::error_code& ec);
    void on_request_sent(const std::error_code& ec, size_t bytes_transferred);

    void on_write(const std::error_code& ec, size_t bytes_transferred);
    void on_read(const std::error_code& ec, size_t bytes_transferred);

    void on_close(const std::error_code& ec);
    void onTimeout(const std::error_code& ec);
    void onError(const std::string& ec, const std::string& details = "");
};

class Http
{
public:
    Http() : m_guard(make_work_guard(m_ios)) {}

    void init();
    void terminate();

    int get(const std::string& url, int timeout = 5);
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
    bool m_working = false;
    bool m_enable_time_out_on_read_write = false;
    int m_operationId = 1;
    std::thread m_thread;
    asio::io_context m_ios{};
    asio::executor_work_guard<asio::io_context::executor_type> m_guard;
    std::unordered_map<int, HttpResult_ptr> m_operations;
    std::unordered_map<int, std::shared_ptr<WebsocketSession>> m_websockets;
    std::unordered_map<std::string, HttpResult_ptr> m_downloads;
    std::string m_userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
    std::unordered_map<std::string, std::string> m_custom_header;
};

extern Http g_http;
