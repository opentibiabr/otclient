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

#include "declarations.h"
#include <framework/luaengine/luaobject.h>

 // @bindclass
class Protocol : public LuaObject
{
public:
    Protocol();
    ~Protocol() override;

#ifndef __EMSCRIPTEN__
    void connect(std::string_view host, uint16_t port);
#else
    void connect(const std::string_view host, uint16_t port, bool gameWorld = false);
#endif
    void disconnect();

    void setRecorder(PacketRecorderPtr recorder);
    void playRecord(PacketPlayerPtr player);

    bool isConnected();
    bool isConnecting();
    ticks_t getElapsedTicksSinceLastRead() const;
#ifdef __EMSCRIPTEN__
    WebConnectionPtr getConnection() { return m_connection; }
#else
    ConnectionPtr getConnection() { return m_connection; }
#endif
#ifdef __EMSCRIPTEN__
    void setConnection(const WebConnectionPtr& connection) { m_connection = connection; }
#else
    void setConnection(const ConnectionPtr& connection) { m_connection = connection; }
#endif

    void generateXteaKey();
    void setXteaKey(const uint32_t a, const uint32_t b, const uint32_t c, const uint32_t d) { m_xteaKey = { a, b, c, d }; }
    std::vector<uint32_t > getXteaKey() { return { m_xteaKey.begin(), m_xteaKey.end() }; }
    void enableXteaEncryption() { m_xteaEncryptionEnabled = true; }

    void enableChecksum() { m_checksumEnabled = true; }
    void enabledSequencedPackets() { m_sequencedPackets = true; }

    virtual void send(const OutputMessagePtr& outputMessage);
    virtual void recv();

    ProtocolPtr asProtocol() { return static_self_cast<Protocol>(); }

protected:
    virtual void onConnect();
    virtual void onRecv(const InputMessagePtr& inputMessage);
    virtual void onError(const std::error_code& err);
    virtual void onSend() {};

    void onProxyPacket(const std::shared_ptr<std::vector<uint8_t>>& packet);
    void onPlayerPacket(const std::shared_ptr<std::vector<uint8_t>>& packet);
    void onLocalDisconnected(std::error_code ec);
    bool m_disconnected = false;
    uint32_t m_proxy = 0;

    std::array<uint32_t, 4> m_xteaKey{};
    uint32_t m_packetNumber{ 0 };

    PacketPlayerPtr m_player;
    PacketRecorderPtr m_recorder;
private:
    void internalRecvHeader(const uint8_t* buffer, uint16_t size);
    void internalRecvData(const uint8_t* buffer, uint16_t size);

    bool xteaDecrypt(const InputMessagePtr& inputMessage) const;
    void xteaEncrypt(const OutputMessagePtr& outputMessage) const;

    bool m_checksumEnabled{ false };
    bool m_sequencedPackets{ false };
    bool m_xteaEncryptionEnabled{ false };
#ifdef __EMSCRIPTEN__
    WebConnectionPtr m_connection;
#else
    ConnectionPtr m_connection;
#endif
    InputMessagePtr m_inputMessage;

    z_stream m_zstream{};
};
