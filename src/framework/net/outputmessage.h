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
class OutputMessage final : public LuaObject
{
public:
    enum
    {
        BUFFER_MAXSIZE = 65536,
        MAX_STRING_LENGTH = 65536
    };

    OutputMessage();

    void reset();

    void setBuffer(const std::string& buffer);
    std::string_view getBuffer() { return std::string_view{ (char*)m_buffer + m_headerPos, m_messageSize }; }

    void addU8(uint8_t value);
    void addU16(uint16_t value);
    void addU32(uint32_t value);
    void addU64(uint64_t value);
    void addString(std::string_view buffer);
    void addBytes(std::string_view buffer);
    void addPaddingBytes(int bytes, uint8_t byte = 0);
    void prependU8(uint8_t value);
    void prependU16(uint16_t value);

    void encryptRsa();

    uint16_t getWritePos() { return m_writePos; }
    uint16_t getMessageSize() { return m_messageSize; }

    void setWritePos(const uint16_t writePos) { m_writePos = writePos; }
    void setMessageSize(const uint16_t messageSize) { m_messageSize = messageSize; }

    uint8_t* getXteaEncryptionBuffer();

protected:
    uint8_t* getWriteBuffer() { return m_buffer + m_writePos; }
    uint8_t* getHeaderBuffer() { return m_buffer + m_headerPos; }
    uint8_t* getDataBuffer() { return m_buffer + m_maxHeaderSize; }

    void writeChecksum();
    void writeSequence(uint32_t sequence);
    void writeMessageSize();
    void writePaddingAmount();
    void writeHeaderSize();

    friend class Protocol;
    friend class PacketPlayer;

private:
    bool canWrite(int bytes) const;
    void checkWrite(int bytes);

    uint8_t m_maxHeaderSize { 8 };
    uint16_t m_headerPos{ m_maxHeaderSize };
    uint16_t m_writePos{ m_maxHeaderSize };
    uint16_t m_messageSize{ 0 };
    uint8_t m_buffer[BUFFER_MAXSIZE];
};
