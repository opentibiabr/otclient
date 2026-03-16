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
class InputMessage final : public LuaObject
{
public:
    InputMessage();

    enum
    {
        BUFFER_MAXSIZE = 65536
    };

    inline auto getMaxHeaderSize() const
    {
        return m_maxHeaderSize;
    }

    void setBuffer(const std::string& buffer);
    std::string_view getBuffer() { return std::string_view{ (char*)m_buffer + m_headerPos, m_messageSize }; }
    std::string getBodyBuffer() { return std::string((char*)m_buffer + m_maxHeaderSize, m_messageSize - getHeaderSize()); }

    void skipBytes(const uint16_t bytes) { m_readPos += bytes; }
    void setReadPos(const uint16_t readPos) { m_readPos = readPos; }
    uint8_t getU8();
    uint16_t getU16();
    uint32_t getU32();
    uint64_t getU64();
    int64_t get64();
    std::string getString();
    double getDouble();

    uint8_t peekU8()
    {
        const uint8_t v = getU8(); m_readPos -= 1; return v;
    }
    uint16_t peekU16()
    {
        const uint16_t v = getU16(); m_readPos -= 2; return v;
    }
    uint32_t peekU32()
    {
        const uint32_t v = getU32(); m_readPos -= 4; return v;
    }
    uint64_t peekU64()
    {
        const uint64_t v = getU64(); m_readPos -= 8; return v;
    }

    bool decryptRsa(int size);

    int getReadSize() { return m_readPos - m_headerPos; }
    int getReadPos() { return m_readPos; }
    int getUnreadSize() { return m_messageSize - (m_readPos - m_headerPos); }
    uint16_t getMessageSize() { return m_messageSize; }

    void setPaddingSize(uint8_t padding) { m_padding = padding; }
    uint8_t getPaddingSize() const {
        return m_padding;
    }

    bool eof() { return (m_readPos - m_headerPos) >= m_messageSize; }

    std::vector<uint8_t> peekBytes(int bytes) const
    {
        const int available = m_messageSize - (m_readPos - m_headerPos);
        if (available <= 0)
            return {};

        bytes = std::min<uint8_t>(bytes, available);
        std::vector<uint8_t> data(bytes);
        std::memcpy(data.data(), m_buffer + m_readPos, bytes);
        return data;
    }

protected:
    void reset();
    void fillBuffer(const uint8_t* buffer, uint16_t size);

    void setHeaderSize(uint16_t size);
    void setMessageSize(const uint16_t size) { m_messageSize = size; }

    uint8_t* getReadBuffer() { return m_buffer + m_readPos; }
    uint8_t* getHeaderBuffer() { return m_buffer + m_headerPos; }
    uint8_t* getDataBuffer() { return m_buffer + m_maxHeaderSize; }
    uint16_t getHeaderSize() const { return (m_maxHeaderSize - m_headerPos); }

    uint16_t readSize() { return getU16(); }
    bool readChecksum();

    friend class Protocol;

private:
    bool canRead(int bytes) const;
    void checkRead(int bytes);
    void checkWrite(int bytes);

    uint8_t m_maxHeaderSize = 8;
    uint16_t m_headerPos{ m_maxHeaderSize };
    uint16_t m_readPos{ m_maxHeaderSize };
    uint16_t m_messageSize{ 0 };
    uint8_t m_padding{ 0 };
    uint8_t m_buffer[BUFFER_MAXSIZE]{};
};
