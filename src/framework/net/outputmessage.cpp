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

#include <framework/net/outputmessage.h>

#include "client/game.h"
#include "framework/util/crypt.h"

OutputMessage::OutputMessage() {
    m_maxHeaderSize = g_game.getClientVersion() >= 1405 ? 7 : 8;
    m_writePos = m_maxHeaderSize;
    m_headerPos = m_maxHeaderSize;
}

void OutputMessage::reset()
{
    m_maxHeaderSize = g_game.getClientVersion() >= 1405 ? 7 : 8;
    m_writePos = m_maxHeaderSize;
    m_headerPos = m_maxHeaderSize;
    m_messageSize = 0;
}

void OutputMessage::setBuffer(const std::string& buffer)
{
    const int len = buffer.size();
    reset();
    checkWrite(len);
    memcpy(m_buffer + m_writePos, buffer.data(), len);
    m_writePos += len;
    m_messageSize += len;
}

void OutputMessage::addU8(const uint8_t value)
{
    checkWrite(1);
    m_buffer[m_writePos] = value;
    m_writePos += 1;
    m_messageSize += 1;
}

void OutputMessage::addU16(const uint16_t value)
{
    checkWrite(2);
    stdext::writeULE16(m_buffer + m_writePos, value);
    m_writePos += 2;
    m_messageSize += 2;
}

void OutputMessage::addU32(const uint32_t value)
{
    checkWrite(4);
    stdext::writeULE32(m_buffer + m_writePos, value);
    m_writePos += 4;
    m_messageSize += 4;
}

void OutputMessage::addU64(const uint64_t value)
{
    checkWrite(8);
    stdext::writeULE64(m_buffer + m_writePos, value);
    m_writePos += 8;
    m_messageSize += 8;
}

void OutputMessage::addString(const std::string_view buffer)
{
    const int len = buffer.length();
    if (len > MAX_STRING_LENGTH)
        throw stdext::exception(fmt::format("string length > {}", MAX_STRING_LENGTH));
    checkWrite(len + 2);
    addU16(len);
    memcpy(m_buffer + m_writePos, buffer.data(), len);
    m_writePos += len;
    m_messageSize += len;
}

void OutputMessage::addBytes(const std::string_view buffer)
{
    const int len = buffer.length();
    checkWrite(len);
    memcpy(m_buffer + m_writePos, buffer.data(), len);
    m_writePos += len;
    m_messageSize += len;
}

void OutputMessage::addPaddingBytes(const int bytes, const uint8_t byte)
{
    if (bytes <= 0)
        return;
    checkWrite(bytes);
    memset(&m_buffer[m_writePos], byte, bytes);
    m_writePos += bytes;
    m_messageSize += bytes;
}

void OutputMessage::encryptRsa()
{
    const int size = g_crypt.rsaGetSize();
    if (m_messageSize < size)
        throw stdext::exception("insufficient bytes in buffer to encrypt");

    if (!g_crypt.rsaEncrypt(static_cast<uint8_t*>(m_buffer) + m_writePos - size, size))
        throw stdext::exception("rsa encryption failed");
}

void OutputMessage::writeChecksum()
{
    const auto messageSize = static_cast<uInt>(m_messageSize);
    const uint32_t checksum = stdext::computeChecksum({ m_buffer + m_headerPos, messageSize });
    assert(m_headerPos - 4 >= 0);
    m_headerPos -= 4;
    stdext::writeULE32(m_buffer + m_headerPos, checksum);
    m_messageSize += 4;
}

void OutputMessage::writeSequence(const uint32_t sequence)
{
    assert(m_headerPos >= 4);
    m_headerPos -= 4;
    stdext::writeULE32(m_buffer + m_headerPos, sequence);
    m_messageSize += 4;
}

void OutputMessage::writeMessageSize()
{
    assert(m_headerPos - 2 >= 0);
    m_headerPos -= 2;
    stdext::writeULE16(m_buffer + m_headerPos, m_messageSize);
    m_messageSize += 2;
}

void OutputMessage::writePaddingAmount()
{
    const uint8_t paddingAmount = 8 - (m_messageSize % 8) - 1;
    addPaddingBytes(paddingAmount);
    prependU8(paddingAmount);
}

void OutputMessage::writeHeaderSize()
{
    auto headerSize = static_cast<uint16_t>((m_messageSize - 4) / 8); // -4 for checksum
    prependU16(headerSize); // Uses writeULE16 and updates `m_headerPos` and `m_messageSize`
}

bool OutputMessage::canWrite(const int bytes) const
{
    return m_writePos + bytes <= BUFFER_MAXSIZE;
}

void OutputMessage::checkWrite(const int bytes)
{
    if (!canWrite(bytes))
        throw stdext::exception("OutputMessage max buffer size reached");
}

void OutputMessage::prependU8(uint8_t value)
{
    assert(m_headerPos > 0);
    m_headerPos--;
    m_writePos--;
    m_buffer[m_headerPos] = value;
    m_messageSize++;
}

void OutputMessage::prependU16(uint16_t value)
{
    assert(m_headerPos >= 2);
    m_headerPos -= 2;
    m_writePos -= 2;
    stdext::writeULE16(m_buffer + m_headerPos, value);
    m_messageSize += 2;
}

uint8_t* OutputMessage::getXteaEncryptionBuffer()
{
    return g_game.getClientVersion() >= 1405 ? getHeaderBuffer() : getDataBuffer() - 2;
}
