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

#include "packet_player.h"

#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"

PacketPlayer::~PacketPlayer()
{
    if (m_event)
        m_event->cancel();
}

PacketPlayer::PacketPlayer(const std::string_view& file)
{
#ifdef ANDROID
    std::ifstream f(std::string("records/") + std::string(file));
#else
    std::ifstream f(std::filesystem::path("records") / file);
#endif
    if (!f.is_open())
        return;
    std::string type, packetHex;
    ticks_t time;
    while (f >> type >> time >> packetHex) {
        // Convert hex string to binary data manually
        std::string packetStr;
        for (size_t i = 0; i < packetHex.length(); i += 2) {
            std::string byteString = packetHex.substr(i, 2);
            char byte = (char)strtol(byteString.c_str(), nullptr, 16);
            packetStr.push_back(byte);
        }
        auto packet = std::make_shared<std::vector<uint8_t>>(packetStr.begin(), packetStr.end());
        if (type == "<") {
            m_input.push_back(std::make_pair(time, packet));
        } else if (type == ">") {
            m_output.push_back(std::make_pair(time, packet));
        }
    }
}

void PacketPlayer::start(std::function<void(std::shared_ptr<std::vector<uint8_t>>)> recvCallback,
                         std::function<void(std::error_code)> disconnectCallback)
{
    m_start = g_clock.millis();
    m_recvCallback = recvCallback;
    m_disconnectCallback = disconnectCallback;
    m_event = g_dispatcher.scheduleEvent(std::bind(&PacketPlayer::process, this), 50);
}

void PacketPlayer::stop()
{
    if (m_event)
        m_event->cancel();
    m_event = nullptr;
}

void PacketPlayer::onOutputPacket(const OutputMessagePtr& packet)
{
    if (packet->getBuffer()[0] == 0x14) { // logout
        m_disconnectCallback(asio::error::eof);
        stop();
    }
}

void PacketPlayer::process()
{
    ticks_t nextPacket = 1;
    while (!m_input.empty()) {
        auto& packet = m_input.front();
        nextPacket = (packet.first + m_start) - g_clock.millis();
        if (nextPacket > 1)
            break;
        m_recvCallback(packet.second);
        m_input.pop_front();
    }

    if (!m_input.empty() && nextPacket > 1) {
        m_event = g_dispatcher.scheduleEvent(std::bind(&PacketPlayer::process, this), nextPacket);
    } else {
        m_disconnectCallback(asio::error::eof);
        stop();
    }
}