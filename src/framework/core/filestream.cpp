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

#include "filestream.h"

#include <physfs.h>

#include "binarytree.h"
#include "graphicalapplication.h"
#if ENABLE_ENCRYPTION == 1
#include "resourcemanager.h"
#endif

inline void grow(std::vector<uint8_t>& data, const size_t size) {
    if (size > data.size())
        data.resize(size);
}

FileStream::FileStream(std::string name, PHYSFS_File* fileHandle, const bool writeable) :
    m_name(std::move(name)),
    m_fileHandle(fileHandle),
    m_pos(0),
    m_writeable(writeable),
    m_caching(false)
{
}

FileStream::FileStream(std::string name, const std::string_view buffer) :
    m_name(std::move(name)),
    m_fileHandle(nullptr),
    m_pos(0),
    m_writeable(false),
    m_caching(true)
{
    m_data.resize(buffer.length());
    memcpy(&m_data[0], &buffer[0], buffer.length());
}

FileStream::~FileStream()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    if (!g_app.isTerminated())
        close();
}

void FileStream::cache(bool
#if ENABLE_ENCRYPTION == 1
                       useEnc
#endif
)
{
    m_caching = true;

    if (!m_writeable) {
        if (!m_fileHandle)
            return;

        // Cache entire file into data buffer
        m_pos = PHYSFS_tell(m_fileHandle);
        PHYSFS_seek(m_fileHandle, 0);
        const int size = PHYSFS_fileLength(m_fileHandle);
        m_data.resize(size);

        if (PHYSFS_readBytes(m_fileHandle, m_data.data(), size) == -1)
            throwError("unable to read file data", true);

#if ENABLE_ENCRYPTION == 1
        if (useEnc) {
            if (m_data.size() >= std::string(ENCRYPTION_HEADER).size() &&
                std::memcmp(m_data.data(), ENCRYPTION_HEADER, std::string(ENCRYPTION_HEADER).size()) == 0) {
                m_data.erase(m_data.begin(), m_data.begin() + std::string(ENCRYPTION_HEADER).size());
            }

            uint8_t* decryptedData = ResourceManager::decrypt(m_data.data(), m_data.size());
            m_data.resize(size - std::string(ENCRYPTION_HEADER).size());
            std::memcmp(m_data.data(), decryptedData, m_data.size());
            delete[] decryptedData;
        }
#endif
        PHYSFS_close(m_fileHandle);
        m_fileHandle = nullptr;
    }
}

void FileStream::close()
{
    if (m_fileHandle && PHYSFS_isInit()) {
        if (!PHYSFS_close(m_fileHandle))
            throwError("close failed", true);
        m_fileHandle = nullptr;
    }

    m_data.clear();
    m_pos = 0;
}

void FileStream::flush()
{
    if (!m_writeable)
        throwError("filestream is not writeable");

    if (m_fileHandle) {
        if (m_caching) {
            if (!PHYSFS_seek(m_fileHandle, 0))
                throwError("flush seek failed", true);
            const uint32_t len = m_data.size();
            if (PHYSFS_writeBytes(m_fileHandle, m_data.data(), len) != len)
                throwError("flush write failed", true);
        }

        if (PHYSFS_flush(m_fileHandle) == 0)
            throwError("flush failed", true);
    }
}

int FileStream::read(void* buffer, const uint32_t size, const uint32_t nmemb)
{
    if (!m_caching) {
        const int res = PHYSFS_readBytes(m_fileHandle, buffer, static_cast<PHYSFS_uint64>(size) * nmemb);
        if (res == -1)
            throwError("read failed", true);
        return res;
    }
    int writePos = 0;
    auto* const outBuffer = static_cast<uint8_t*>(buffer);
    for (uint32_t i = 0; i < nmemb; ++i) {
        if (m_pos + size > m_data.size())
            return i;

        for (uint32_t j = 0; j < size; ++j)
            outBuffer[writePos++] = m_data[m_pos++];
    }
    return nmemb;
}

void FileStream::write(const void* buffer, const uint32_t count)
{
    if (!m_caching) {
        if (PHYSFS_writeBytes(m_fileHandle, buffer, count) != count)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + count);
        memcpy(&m_data[m_pos], buffer, count);
        m_pos += count;
    }
}

void FileStream::seek(const uint32_t pos)
{
    if (!m_caching) {
        if (!PHYSFS_seek(m_fileHandle, pos))
            throwError("seek failed", true);
    } else {
        if (pos > m_data.size())
            throwError("seek failed");
        m_pos = pos;
    }
}

void FileStream::skip(const uint32_t len)
{
    seek(tell() + len);
}

uint32_t FileStream::size() const
{
    if (!m_caching)
        return PHYSFS_fileLength(m_fileHandle);
    return m_data.size();
}

uint32_t FileStream::tell() const
{
    if (!m_caching)
        return PHYSFS_tell(m_fileHandle);
    return m_pos;
}

bool FileStream::eof() const
{
    if (!m_caching)
        return PHYSFS_eof(m_fileHandle);
    return m_pos >= m_data.size();
}

uint8_t FileStream::getU8()
{
    uint8_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readBytes(m_fileHandle, &v, 1) != 1)
            throwError("read failed", true);
    } else {
        if (m_pos + 1 > m_data.size())
            throwError("read failed");

        v = m_data[m_pos];
        m_pos += 1;
    }
    return v;
}

uint16_t FileStream::getU16()
{
    uint16_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readULE16(m_fileHandle, &v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 2 > m_data.size())
            throwError("read failed");

        v = stdext::readULE16(&m_data[m_pos]);
        m_pos += 2;
    }
    return v;
}

uint32_t FileStream::getU32()
{
    uint32_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readULE32(m_fileHandle, &v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 4 > m_data.size())
            throwError("read failed");

        v = stdext::readULE32(&m_data[m_pos]);
        m_pos += 4;
    }
    return v;
}

uint64_t FileStream::getU64()
{
    uint64_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readULE64(m_fileHandle, (PHYSFS_uint64*)&v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 8 > m_data.size())
            throwError("read failed");
        v = stdext::readULE64(&m_data[m_pos]);
        m_pos += 8;
    }
    return v;
}

int8_t FileStream::get8()
{
    int8_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readBytes(m_fileHandle, &v, 1) != 1)
            throwError("read failed", true);
    } else {
        if (m_pos + 1 > m_data.size())
            throwError("read failed");

        v = m_data[m_pos];
        m_pos += 1;
    }
    return v;
}

int16_t FileStream::get16()
{
    int16_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readSLE16(m_fileHandle, &v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 2 > m_data.size())
            throwError("read failed");

        v = stdext::readSLE16(&m_data[m_pos]);
        m_pos += 2;
    }
    return v;
}

int32_t FileStream::get32()
{
    int32_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readSLE32(m_fileHandle, &v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 4 > m_data.size())
            throwError("read failed");

        v = stdext::readSLE32(&m_data[m_pos]);
        m_pos += 4;
    }
    return v;
}

int64_t FileStream::get64()
{
    int64_t v = 0;
    if (!m_caching) {
        if (PHYSFS_readSLE64(m_fileHandle, (PHYSFS_sint64*)&v) == 0)
            throwError("read failed", true);
    } else {
        if (m_pos + 8 > m_data.size())
            throwError("read failed");
        v = stdext::readSLE64(&m_data[m_pos]);
        m_pos += 8;
    }
    return v;
}

std::string FileStream::getString()
{
    std::string str;
    if (const uint16_t len = getU16(); len > 0 && len < 8192) {
        char buffer[8192];
        if (m_fileHandle) {
            if (PHYSFS_readBytes(m_fileHandle, buffer, len) == 0)
                throwError("read failed", true);
            else
                str = { buffer, len };
        } else {
            if (m_pos + len > m_data.size()) {
                throwError("[FileStream::getString] - Read failed");
                return {};
            }

            str = { (char*)&m_data[m_pos], len };
            m_pos += len;
        }
    } else if (len != 0)
        throwError("[FileStream::getString] - Read failed because string is too big");
    return str;
}

BinaryTreePtr FileStream::getBinaryTree()
{
    if (const uint8_t byte = getU8(); byte != static_cast<uint8_t>(BinaryTree::Node::START))
        throw Exception("failed to read node start (getBinaryTree): {}", byte);

    return  std::make_shared<BinaryTree>(shared_from_this());
}

void FileStream::startNode(const uint8_t n)
{
    addU8(static_cast<uint8_t>(BinaryTree::Node::START));
    addU8(n);
}

void FileStream::endNode()
{
    addU8(static_cast<uint8_t>(BinaryTree::Node::END));
}

void FileStream::addU8(const uint8_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeBytes(m_fileHandle, &v, 1) != 1)
            throwError("write failed", true);
    } else {
        m_data.push_back(v);
        m_pos++;
    }
}

void FileStream::addU16(const uint16_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeULE16(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 2);
        stdext::writeULE16(&m_data[m_pos], v);
        m_pos += 2;
    }
}

void FileStream::addU32(const uint32_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeULE32(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 4);
        stdext::writeULE32(&m_data[m_pos], v);
        m_pos += 4;
    }
}

void FileStream::addU64(const uint64_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeULE64(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 8);
        stdext::writeULE64(&m_data[m_pos], v);
        m_pos += 8;
    }
}

void FileStream::add8(const int8_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeBytes(m_fileHandle, &v, 1) != 1)
            throwError("write failed", true);
    } else {
        m_data.push_back(v);
        m_pos++;
    }
}

void FileStream::add16(const int16_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeSLE16(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 2);
        stdext::writeSLE16(&m_data[m_pos], v);
        m_pos += 2;
    }
}

void FileStream::add32(const int32_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeSLE32(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 4);
        stdext::writeSLE32(&m_data[m_pos], v);
        m_pos += 4;
    }
}

void FileStream::add64(const int64_t v)
{
    if (!m_caching) {
        if (PHYSFS_writeSLE64(m_fileHandle, v) == 0)
            throwError("write failed", true);
    } else {
        grow(m_data, m_pos + 8);
        stdext::writeSLE64(&m_data[m_pos], v);
        m_pos += 8;
    }
}

void FileStream::addString(const std::string_view v)
{
    addU16(v.length());
    write(v.data(), v.length());
}

void FileStream::throwError(const std::string_view message, const bool physfsError) const
{
    std::string completeMessage = fmt::format("in file '{}': {}", m_name, message);
    if (physfsError)
        completeMessage += ": "s + PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode());
    throw Exception(completeMessage);
}