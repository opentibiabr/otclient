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
#include <framework/core/declarations.h>

class SoundFile : public std::enable_shared_from_this<SoundFile>
{
public:
    virtual ~SoundFile() = default; // fix clang warning

    SoundFile(FileStreamPtr fileStream) : m_file(std::move(fileStream)) {}
    static SoundFilePtr loadSoundFile(const std::string& filename);

    virtual int read(void* /*buffer*/, int /*bufferSize*/) { return -1; }
    virtual void reset() {}
    bool eof() const;

    ALenum getSampleFormat() const;

    int getChannels() const { return m_channels; }
    int getRate() const { return m_rate; }
    int getBps() const { return m_bps; }
    int getSize() const { return m_size; }
    std::string getName() const;

protected:
    FileStreamPtr m_file;
    int m_channels{ 0 };
    int m_rate{ 0 };
    int m_bps{ 0 };
    int m_size{ 0 };
};
