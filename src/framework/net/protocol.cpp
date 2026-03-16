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

#include "protocol.h"

#include "client/game.h"
#include "framework/core/graphicalapplication.h"
#include "framework/proxy/proxy.h"
#include "inputmessage.h"
#include "outputmessage.h"
#ifdef __EMSCRIPTEN__
#include "webconnection.h"
#else
#include "connection.h"
#endif
#include <framework/net/packet_player.h>
#include <framework/net/packet_recorder.h>

extern asio::io_service g_ioService;

Protocol::Protocol() :m_inputMessage(std::make_shared<InputMessage>()) {
    inflateInit2(&m_zstream, -15);
}

Protocol::~Protocol()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    disconnect();
    inflateEnd(&m_zstream);
}

#ifndef __EMSCRIPTEN__
void Protocol::connect(const std::string_view host, const uint16_t port)
{
    if (host == "proxy" || host == "0.0.0.0" || (host == "127.0.0.1" && g_proxy.isActive())) {
        m_disconnected = false;
        m_proxy = g_proxy.addSession(port,
                                     [capture0 = asProtocol()](auto&& PH1) {
            capture0->onProxyPacket(std::forward<decltype(PH1)>(PH1));
        },
                                     [capture0 = asProtocol()](auto&& PH1) {
            capture0->onLocalDisconnected(std::forward<decltype(PH1)>(PH1));
        });
        return onConnect();
    }

    m_connection = std::make_shared<Connection>();
    std::weak_ptr<Protocol> weakSelf = asProtocol();
    m_connection->setErrorCallback([weakSelf](auto&& err) {
        if (auto self = weakSelf.lock()) {
            self->onError(std::forward<decltype(err)>(err));
        }
    });
    m_connection->connect(host, port, [weakSelf] {
        if (auto self = weakSelf.lock()) {
            if (!self->m_disconnected) {
                self->onConnect();
            }
        }
    });
}
#else
void Protocol::connect(const std::string_view host, uint16_t port, bool gameWorld)
{
    m_connection = std::make_shared<WebConnection>();
    m_connection->setErrorCallback([capture0 = asProtocol()](auto&& PH1) { capture0->onError(std::forward<decltype(PH1)>(PH1));    });
    m_connection->connect(host, port, [capture0 = asProtocol()] { capture0->onConnect(); }, gameWorld);
}
#endif

void Protocol::disconnect()
{
    m_disconnected = true;
    if (m_proxy) {
        g_proxy.removeSession(m_proxy);
        return;
    }

    if (m_connection) {
        m_connection->close();
        m_connection.reset();
    }
}

bool Protocol::isConnected()
{
    if (m_proxy)
        return !m_disconnected;

    return m_connection && m_connection->isConnected();
}

bool Protocol::isConnecting()
{
    if (m_proxy)
        return false;

    return m_connection && m_connection->isConnecting();
}

void Protocol::send(const OutputMessagePtr& outputMessage)
{
    if (m_player) {
        m_player->onOutputPacket(outputMessage);
        return;
    }

    if (m_recorder) {
        m_recorder->addOutputPacket(outputMessage);
    }

    // padding
    if (g_game.getClientVersion() >= 1405) {
        outputMessage->writePaddingAmount();
    }

    // encrypt
    if (m_xteaEncryptionEnabled) {
        xteaEncrypt(outputMessage);
    }

    // write checksum
    if (m_sequencedPackets) {
        outputMessage->writeSequence(m_packetNumber++);
    } else if (m_checksumEnabled) {
        outputMessage->writeChecksum();
    }

    // write message size
    if (g_game.getClientVersion() >= 1405) {
        outputMessage->writeHeaderSize();
    } else {
        outputMessage->writeMessageSize();
    }

    onSend();

    if (m_proxy) {
        const auto packet = std::make_shared<ProxyPacket>(outputMessage->getHeaderBuffer(), outputMessage->getWriteBuffer());
        g_proxy.send(m_proxy, packet);
        outputMessage->reset();
        return;
    }

    // send
    if (m_connection)
        m_connection->write(outputMessage->getHeaderBuffer(), outputMessage->getMessageSize());

    // reset message to allow reuse
    outputMessage->reset();
}

void Protocol::recv()
{
    if (m_proxy) {
        return;
    }

    m_inputMessage->reset();

    // first update message header size
    int headerSize = 2; // 2 bytes for message size
    if (m_checksumEnabled)
        headerSize += 4; // 4 bytes for checksum
    if (g_game.getClientVersion() >= 1405) {
        headerSize += 1; // 1 bytes for padding size
    } else if (m_xteaEncryptionEnabled) {
        headerSize += 2; // 2 bytes for XTEA encrypted message size
    }
    m_inputMessage->setHeaderSize(headerSize);

    // read the first 2 bytes which contain the message size
    if (m_connection)
        m_connection->read(2, [capture0 = asProtocol()](auto&& PH1, auto&& PH2) {
        capture0->internalRecvHeader(std::forward<decltype(PH1)>(PH1),
        std::forward<decltype(PH2)>(PH2));
    });
}

void Protocol::internalRecvHeader(const uint8_t* buffer, const uint16_t size)
{
    // read message size
    m_inputMessage->fillBuffer(buffer, size);
    uint16_t remainingSize = m_inputMessage->readSize();
    if (g_game.getClientVersion() >= 1405) {
        remainingSize = remainingSize * 8 + 4;
    }

    constexpr uint32_t MAX_PACKET = InputMessage::BUFFER_MAXSIZE;
    if (remainingSize == 0 || remainingSize > MAX_PACKET) {
        g_logger.error(fmt::format("invalid packet size = {}", remainingSize));
        return;
    }

    // read remaining message data
    if (m_connection)
        m_connection->read(remainingSize, [capture0 = asProtocol()](auto&& PH1, auto&& PH2) {
        capture0->internalRecvData(std::forward<decltype(PH1)>(PH1),
        std::forward<decltype(PH2)>(PH2));
    });
}

void Protocol::internalRecvData(const uint8_t* buffer, const uint16_t size)
{
    // process data only if really connected
    if (!isConnected()) {
        g_logger.traceError("received data while disconnected");
        return;
    }

    m_inputMessage->fillBuffer(buffer, size);

    bool decompress = false;
    if (m_sequencedPackets) {
        decompress = (m_inputMessage->getU32() & 1 << 31);
    } else if (m_checksumEnabled && !m_inputMessage->readChecksum()) {
        std::string headerHex;
        headerHex.reserve(m_inputMessage->getHeaderSize() * 3); // 2 chars + space por byte

        for (size_t i = 0; i < m_inputMessage->getHeaderSize(); ++i) {
            fmt::format_to(std::back_inserter(headerHex), "{:02X} ", static_cast<uint8_t>(m_inputMessage->getBuffer()[i]));
        }

        g_logger.traceError(fmt::format("got a network message with invalid checksum, header: {}, size: {}", headerHex, static_cast<int>(m_inputMessage->getMessageSize())));
        return;
    }

    if (m_xteaEncryptionEnabled) {
        if (!xteaDecrypt(m_inputMessage)) {
            g_logger.traceError("failed to decrypt message");
            return;
        }
    }

    if (decompress) {
        static uint8_t zbuffer[InputMessage::BUFFER_MAXSIZE];

        m_zstream.next_in = m_inputMessage->getDataBuffer();
        m_zstream.next_out = zbuffer;
        m_zstream.avail_in = m_inputMessage->getUnreadSize();
        m_zstream.avail_out = InputMessage::BUFFER_MAXSIZE;

        const int32_t ret = inflate(&m_zstream, Z_FINISH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            g_logger.traceError("failed to decompress message - {}", m_zstream.msg);
            return;
        }

        const uint32_t totalSize = m_zstream.total_out;
        inflateReset(&m_zstream);
        if (totalSize == 0) {
            g_logger.traceError("invalid size of decompressed message - %i", totalSize);
            return;
        }

        m_inputMessage->fillBuffer(zbuffer, totalSize);
        m_inputMessage->setMessageSize(m_inputMessage->getHeaderSize() + totalSize);
    }

    if (m_recorder) {
        m_recorder->addInputPacket(m_inputMessage);
    }
    onRecv(m_inputMessage);
}

void Protocol::generateXteaKey()
{
    std::random_device rd;
    std::uniform_int_distribution<uint32_t > unif;
    std::ranges::generate(m_xteaKey, [&unif, &rd] { return unif(rd); });
}

namespace
{
    constexpr uint32_t delta = 0x9E3779B9;

    template<typename Round>
    void apply_rounds(uint8_t* data, const size_t length, Round round)
    {
        for (auto j = 0u; j < length; j += 8) {
            uint32_t left = data[j + 0] | data[j + 1] << 8u | data[j + 2] << 16u | data[j + 3] << 24u,
                right = data[j + 4] | data[j + 5] << 8u | data[j + 6] << 16u | data[j + 7] << 24u;

            round(left, right);

            data[j] = static_cast<uint8_t>(left);
            data[j + 1] = static_cast<uint8_t>(left >> 8u);
            data[j + 2] = static_cast<uint8_t>(left >> 16u);
            data[j + 3] = static_cast<uint8_t>(left >> 24u);
            data[j + 4] = static_cast<uint8_t>(right);
            data[j + 5] = static_cast<uint8_t>(right >> 8u);
            data[j + 6] = static_cast<uint8_t>(right >> 16u);
            data[j + 7] = static_cast<uint8_t>(right >> 24u);
        }
    }
}

bool Protocol::xteaDecrypt(const InputMessagePtr& inputMessage) const
{
    const uint16_t encryptedSize = inputMessage->getUnreadSize();
    if (encryptedSize % 8 != 0) {
        g_logger.traceError("invalid encrypted network message");
        return false;
    }

    for (uint32_t i = 0, sum = delta << 5, next_sum = sum - delta; i < 32; ++i, sum = next_sum, next_sum -= delta) {
        apply_rounds(inputMessage->getReadBuffer(), encryptedSize, [&](uint32_t& left, uint32_t& right) {
            right -= ((left << 4 ^ left >> 5) + left) ^ (sum + m_xteaKey[(sum >> 11) & 3]);
            left -= ((right << 4 ^ right >> 5) + right) ^ (next_sum + m_xteaKey[next_sum & 3]);
        });
    }

    uint16_t decryptedSize;
    if (g_game.getClientVersion() >= 1405) {
        const uint8_t paddingSize = inputMessage->getU8();
        inputMessage->setPaddingSize(paddingSize);
        decryptedSize = encryptedSize - paddingSize - 1;
        inputMessage->setMessageSize(inputMessage->getHeaderSize() + decryptedSize);
    } else {
        decryptedSize = inputMessage->getU16() + 2;
        const int sizeDelta = decryptedSize - encryptedSize;
        if (sizeDelta > 0 || -sizeDelta > encryptedSize) {
            g_logger.traceError("invalid decrypted network message");
            return false;
        }
        inputMessage->setMessageSize(inputMessage->getMessageSize() + sizeDelta);
    }

    return true;
}

void Protocol::xteaEncrypt(const OutputMessagePtr& outputMessage) const
{
    if (g_game.getClientVersion() < 1405) {
        outputMessage->writeMessageSize();
    }

    uint16_t encryptedSize = outputMessage->getMessageSize();

    //add bytes until reach 8 multiple
    if ((encryptedSize % 8) != 0) {
        const uint16_t n = 8 - (encryptedSize % 8);
        outputMessage->addPaddingBytes(n);
        encryptedSize += n;
    }

    for (uint32_t i = 0, sum = 0, next_sum = sum + delta; i < 32; ++i, sum = next_sum, next_sum += delta) {
        apply_rounds(outputMessage->getXteaEncryptionBuffer(), encryptedSize, [&, sum, next_sum, this](uint32_t& left, uint32_t& right) mutable {
            left += ((right << 4 ^ right >> 5) + right) ^ (sum + m_xteaKey[sum & 3]);
            right += ((left << 4 ^ left >> 5) + left) ^ (next_sum + m_xteaKey[(next_sum >> 11) & 3]);
        });
    }
}

void Protocol::onConnect() { callLuaField("onConnect"); }

void Protocol::onRecv(const InputMessagePtr& inputMessage)
{
    callLuaField("onRecv", inputMessage);
}

void Protocol::onError(const std::error_code& err)
{
    callLuaField("onError", err.message(), err.value());
    disconnect();
}

void Protocol::onProxyPacket(const std::shared_ptr<std::vector<uint8_t>>& packet)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
    post(g_ioService, [&, packet] {
        if (m_disconnected)
            return;
        m_inputMessage->reset();

        // first update message header size
        int headerSize = 2; // 2 bytes for message size
        if (m_checksumEnabled)
            headerSize += 4; // 4 bytes for checksum
        if (g_game.getClientVersion() >= 1405) {
            headerSize += 1; // 1 bytes for padding size
        } else if (m_xteaEncryptionEnabled) {
            headerSize += 2; // 2 bytes for XTEA encrypted message size
        }
        m_inputMessage->setHeaderSize(headerSize);
        m_inputMessage->fillBuffer(packet->data(), 2);
        m_inputMessage->readSize();
        internalRecvData(packet->data() + 2, packet->size() - 2);
    });
}

void Protocol::onLocalDisconnected(std::error_code ec)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
#ifndef __EMSCRIPTEN__
    post(g_ioService, [&, ec] {
        if (m_disconnected)
            return;
        m_disconnected = true;
        onError(ec);
    });
#endif
}

void Protocol::onPlayerPacket(const std::shared_ptr<std::vector<uint8_t>>& packet)
{
    if (m_disconnected)
        return;
    auto self(asProtocol());
#ifndef __EMSCRIPTEN__
    post(g_ioService, [&, packet] {
        if (m_disconnected)
            return;
        m_inputMessage->reset();

        m_inputMessage->setHeaderSize(0);
        m_inputMessage->fillBuffer(packet->data(), packet->size());
        m_inputMessage->setMessageSize(packet->size());
        onRecv(m_inputMessage);
    });
#endif
}

void Protocol::playRecord(PacketPlayerPtr player)
{
    m_disconnected = false;
    m_player = player;
    m_player->start([capture0 = asProtocol()](auto&& PH1) {
        capture0->onPlayerPacket(std::forward<decltype(PH1)>(PH1));
    },
    [capture0 = asProtocol()](auto&& PH1) {
        capture0->onLocalDisconnected(std::forward<decltype(PH1)>(PH1));
    });
    return onConnect();
}

void Protocol::setRecorder(PacketRecorderPtr recorder) { m_recorder = recorder; }

ticks_t Protocol::getElapsedTicksSinceLastRead() const { return m_connection ? m_connection->getElapsedTicksSinceLastRead() : -1; }