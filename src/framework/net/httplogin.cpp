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

#include "httplogin.h"
#include <framework/core/asyncdispatcher.h>
#include <framework/core/eventdispatcher.h>
#include <nlohmann/json.hpp>

#ifdef __EMSCRIPTEN__
#include <emscripten/fetch.h>
#endif

using json = nlohmann::json;

LoginHttp::LoginHttp() {
    this->characters.clear();
    this->worlds.clear();
    this->session.clear();
    this->errorMessage.clear();
    this->cancelled.store(false);
}

void LoginHttp::cancel() {
    cancelled.store(true);
}

void LoginHttp::Logger(const auto& req, const auto& res) {
    std::cout << "======= LOG ======= " << std::endl;
    std::cout << "-- REQUEST --" << std::endl;
    std::cout << req.method << std::endl;
    std::cout << req.path << std::endl;
    std::cout << req.body << std::endl;

    for (auto itr = req.headers.begin(); itr != req.headers.end(); ++itr) {
        std::cout << itr->first << '\t' << itr->second << '\n';
    }
    std::cout << "-- RESPONSE --" << std::endl;
    std::cout << res.version << std::endl;
    std::cout << res.status << std::endl;
    std::cout << res.reason << std::endl;
    std::cout << res.body << std::endl;
    std::cout << res.location << std::endl;

    for (auto itr = res.headers.begin(); itr != res.headers.end(); ++itr) {
        std::cout << itr->first << '\t' << itr->second << '\n';
    }

    std::cout << "========= " << std::endl;
}

void LoginHttp::startHttpLogin(const std::string& host, const std::string& path,
                               const uint16_t port, const std::string& email,
                               const std::string& password) {
    httplib::SSLClient cli(host, port);

    cli.set_logger(
        [this](const auto& req, const auto& res) { LoginHttp::Logger(req, res); });

    const auto body = json{ {"email", email}, {"password", password}, {"stayloggedin", true}, {"type", "login"} };
    const httplib::Headers headers = { {"User-Agent", "Mozilla/5.0"} };

    if (auto res = cli.Post(path, headers, body.dump(1), "application/json")) {
        if (res->status == 200) {
            const json bodyResponse = json::parse(res->body);
            std::cout << bodyResponse.dump() << std::endl;

            std::cout << std::boolalpha << json::accept(res->body) << std::endl;
        }
    } else {
        const auto err = res.error();
        std::cout << "HTTP error: " << to_string(err) << std::endl;
    }
}

std::string LoginHttp::getCharacterList() { return this->characters; }

std::string LoginHttp::getWorldList() { return this->worlds; }

std::string LoginHttp::getSession() { return this->session; }

void LoginHttp::httpLogin(const std::string& host, const std::string& path,
                          uint16_t port, const std::string& email,
                          const std::string& password, int request_id, bool httpLogin, const std::string& token) {
#ifndef __EMSCRIPTEN__
    this->errorMessage.clear();
    g_asyncDispatcher.detach_task(
        [this, host, path, port, email, password, request_id, token, httpLogin] {
        if (cancelled.load()) return;
        httplib::Result result =
            this->loginHttpsJson(host, path, port, email, password, token);
        if (httpLogin && (!result || result->status != Success)) {
            if (cancelled.load()) return;
            result = loginHttpJson(host, path, port, email, password, token);
        }

        if (result && result->status == Success && parseJsonResponse(result->body)) {
            g_dispatcher.addEvent([this, request_id] {
                if (cancelled.load()) return;
                g_lua.callGlobalField("EnterGame", "loginSuccess", request_id,
                this->getSession(), this->getWorldList(),
                this->getCharacterList());
            });
        } else {
            int status = 0;
            std::string msg = "";
            if (result) {
                status = result->status;
                if (!this->errorMessage.empty()) {
                    msg = this->errorMessage;
                }
                try {
                    const auto body = json::parse(result->body);
                    if (msg.empty()) {
                        msg = body.value("errorMessage", "");
                    }
                    status = body.value("errorCode", status);
                } catch (...) {
                }
                if (msg.empty()) {
                    if (status != Success) {
                        msg = "HTTP " + std::to_string(status);
                        if (!result->reason.empty()) {
                            msg += " - " + result->reason;
                        } else {
                            msg += " - Unknown status";
                        }
                    } else if (!this->errorMessage.empty()) {
                        msg = this->errorMessage;
                    } else {
                        msg = "Invalid response received from server (expected JSON).";
                    }
                }
            } else {
                status = -1;
                if (this->errorMessage.length() == 0) {
                    msg = "Failed to connect to login server.";
                } else {
                    msg = this->errorMessage;
                }
            }

            g_dispatcher.addEvent([this, request_id, status, msg] {
                if (cancelled.load()) return;
                g_lua.callGlobalField("EnterGame", "loginFailed", request_id, msg,
                status);
            });
        }
    });
#else
    this->errorMessage.clear();
    g_asyncDispatcher.detach_task(
        [this, host, path, port, email, password, request_id, token, httpLogin] {
        emscripten_fetch_attr_t attr;
        emscripten_fetch_attr_init(&attr);
        strcpy(attr.requestMethod, "POST");
        static const char* const headers[] = {
            "Content-Type", "application/json; charset=utf-8",
            0,
        };
        attr.requestHeaders = headers;
        attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY | EMSCRIPTEN_FETCH_SYNCHRONOUS;
        
        json body = {
            {"email", email},
            {"password", password},
            {"stayloggedin", true},
            {"type", "login"}
        };

        if (!token.empty()) {
            body["token"] = token;
            body["authenticatorToken"] = token;
        }

        std::string bodyStr = body.dump(1);
        attr.requestData = bodyStr.data();
        attr.requestDataSize = bodyStr.length();

        std::string url = "https://" + (host.length() > 0 ? host : "127.0.0.1") + ":" + std::to_string(port) + path;
        emscripten_fetch_t* fetch = emscripten_fetch(&attr, url.c_str());

        if (fetch->status != 200 && httpLogin) {
            std::string url = "http://" + (host.length() > 0 ? host : "127.0.0.1") + ":" + std::to_string(port) + path;
            fetch = emscripten_fetch(&attr, url.c_str());
        }

        if (cancelled.load()) {
            emscripten_fetch_close(fetch);
            return;
        }
        if (fetch && fetch->status == 200 &&
               !parseJsonResponse(std::string(fetch->data, fetch->numBytes))) {
            fetch->status = -1;
        }

        emscripten_fetch_close(fetch);
        if (cancelled.load()) return;
        if (fetch && fetch->status == 200) {
            g_dispatcher.addEvent([this, request_id] {
                if (cancelled.load()) return;
                g_lua.callGlobalField("EnterGame", "loginSuccess", request_id,
                this->getSession(), this->getWorldList(),
                this->getCharacterList());
            });
        } else {
            int status = 0;
            std::string msg = "";
            if (fetch) {
                status = fetch->status;
            } else {
                status = -1;
            }
            if (this->errorMessage.length() == 0) {
                msg = "Unknown error";
            } else {
                msg = this->errorMessage;
            }

            g_dispatcher.addEvent([this, request_id, status, msg] {
                if (cancelled.load()) return;
                g_lua.callGlobalField("EnterGame", "loginFailed", request_id, msg,
                status);
            });
        }
    });
#endif
}

httplib::Result LoginHttp::loginHttpsJson(const std::string& host,
                                          const std::string& path,
                                          const uint16_t port,
                                          const std::string& email,
                                          const std::string& password,
                                          const std::string& token) {
    httplib::SSLClient client(host, port);

    client.set_logger(
        [this](const auto& req, const auto& res) { LoginHttp::Logger(req, res); });

    client.set_ca_cert_path("./cacert.pem");
    client.enable_server_certificate_verification(false);
    client.enable_server_hostname_verification(false);

    json body = {
        {"email", email},
        {"password", password},
        {"stayloggedin", true},
        {"type", "login"}
    };

    if (!token.empty()) {
        body["token"] = token;
        body["authenticatorToken"] = token;
    }

    const httplib::Headers headers = { {"User-Agent", "Mozilla/5.0"} };

    httplib::Result response =
        client.Post(path, headers, body.dump(), "application/json");
    if (!response) {
        this->errorMessage = "Failed to connect to server (HTTPS). Check the address and port.";
        std::cout << "HTTPS error: unknown" << std::endl;
    } else if (response->status != Success) {
        this->errorMessage = "HTTP " + std::to_string(response->status);
        if (!response->reason.empty()) {
            this->errorMessage += " - " + response->reason;
        }
        std::cout << "HTTPS error: " << to_string(response.error())
            << std::endl;
    } else {
        std::cout << "HTTPS status: " << to_string(response.error())
            << std::endl;
    }

    return response;
}

httplib::Result LoginHttp::loginHttpJson(const std::string& host,
                                         const std::string& path,
                                         const uint16_t port,
                                         const std::string& email,
                                         const std::string& password,
                                         const std::string& token) {
    httplib::Client client(host, port);
    client.set_logger(
        [this](const auto& req, const auto& res) { LoginHttp::Logger(req, res); });

    const httplib::Headers headers = { {"User-Agent", "Mozilla/5.0"} };
    json body = {
        {"email", email},
        {"password", password},
        {"stayloggedin", true},
        {"type", "login"}
    };

    if (!token.empty()) {
        body["token"] = token;
    }

    httplib::Result response =
        client.Post(path, headers, body.dump(), "application/json");
    if (!response) {
        this->errorMessage = "Failed to connect to server (HTTP). Check the address and port.";
        std::cout << "HTTP error: unknown" << std::endl;
    } else if (response->status != Success) {
        this->errorMessage = "HTTP " + std::to_string(response->status);
        if (!response->reason.empty()) {
            this->errorMessage += " - " + response->reason;
        }
        std::cout << "HTTP error: " << to_string(response.error())
            << std::endl;
    } else {
        std::cout << "HTTP status: " << to_string(response.error())
            << std::endl;
    }
    if (response && response->status == Success && !parseJsonResponse(response->body)) {
        return response;
    }

    return response;
}

bool LoginHttp::parseJsonResponse(const std::string& body) {
    if (cancelled.load()) return false;
    json responseJson;
    try {
        if (cancelled.load()) return false;
        responseJson = json::parse(body);
    } catch (...) {
        g_logger.info("Failed to parse json response");
        this->errorMessage = "Invalid response received from server (expected JSON).";
        return false;
    }

    if (responseJson.contains("errorCode") && responseJson["errorCode"].get<int>() != 0) {
        this->errorMessage = responseJson.value("errorMessage", "Authenticator token required.");
        g_logger.debug("Error code: {}, message: {}", responseJson["errorCode"].get<int>(), this->errorMessage);
        return false;
    }

    if (!responseJson.contains("session") || !responseJson.contains("playdata")) {
        this->errorMessage = "Missing session or playdata.";
        return false;
    }

    json playdata = responseJson["playdata"];
    if (!playdata.contains("characters") || !playdata.contains("worlds")) {
        this->errorMessage = "Missing characters or worlds.";
        return false;
    }

    this->session = to_string(responseJson["session"]);
    this->characters = to_string(playdata["characters"]);
    this->worlds = to_string(playdata["worlds"]);

    return true;
}