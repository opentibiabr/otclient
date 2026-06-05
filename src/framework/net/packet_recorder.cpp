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

#include "packet_recorder.h"

#include "inputmessage.h"
#include "outputmessage.h"
#include "framework/core/clock.h"
PacketRecorder::PacketRecorder(const std::string_view& file)
{
    m_start = g_clock.millis();
#ifdef ANDROID
    g_resources.makeDir("records");
    m_stream = std::ofstream(std::string("records/") + std::string(file));
#else
    std::error_code ec;
    std::filesystem::create_directory("records", ec);
    m_stream = std::ofstream(std::filesystem::path("records") / file);
#endif
}

PacketRecorder::~PacketRecorder()
{
}

void PacketRecorder::addInputPacket(const InputMessagePtr& packet)
{
    m_stream << "< " << (g_clock.millis() - m_start) << " ";
    for (auto& buffer : packet->getBodyBuffer()) {
        m_stream << std::setfill('0') << std::setw(2) << std::hex << (uint16_t)(uint8_t)buffer;
    }
    m_stream << std::dec << "\n";
}

void PacketRecorder::addOutputPacket(const OutputMessagePtr& packet)
{
    if (m_firstOutput) {
        // skip packet with login and password
        m_firstOutput = false;
        return;
    }

    m_stream << "> " << (g_clock.millis() - m_start) << " ";
    for (auto& buffer : packet->getBuffer()) {
        m_stream << std::setfill('0') << std::setw(2) << std::hex << (uint16_t)(uint8_t)buffer;
    }
    m_stream << std::dec << "\n";
}