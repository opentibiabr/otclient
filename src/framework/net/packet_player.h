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

#include <framework/net/outputmessage.h>

#include "framework/core/declarations.h"

class PacketPlayer : public LuaObject
{
public:
    PacketPlayer(const std::string_view& file);
    virtual ~PacketPlayer();

    void start(std::function<void(std::shared_ptr<std::vector<uint8_t>>)> recvCallback, std::function<void(std::error_code)> disconnectCallback);
    void stop();

    void onOutputPacket(const OutputMessagePtr& packet);

private:
    void process();

    ticks_t m_start;
    ScheduledEventPtr m_event;
    std::deque<std::pair<ticks_t, std::shared_ptr<std::vector<uint8_t>>>> m_input;
    std::deque<std::pair<ticks_t, std::shared_ptr<std::vector<uint8_t>>>> m_output;
    std::function<void(std::shared_ptr<std::vector<uint8_t>>)> m_recvCallback;
    std::function<void(std::error_code)> m_disconnectCallback;
};
