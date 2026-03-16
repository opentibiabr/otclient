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

#include "soundbuffer.h"
#include "soundfile.h"

SoundBuffer::SoundBuffer()
{
    alGenBuffers(1, &m_bufferId);
    assert(alGetError() == AL_NO_ERROR);
}

SoundBuffer::~SoundBuffer()
{
    alDeleteBuffers(1, &m_bufferId);
    assert(alGetError() == AL_NO_ERROR);
}

bool SoundBuffer::fillBuffer(const SoundFilePtr& soundFile)
{
    const ALenum format = soundFile->getSampleFormat();
    if (format == AL_UNDETERMINED) {
        g_logger.error("unable to determine sample format for '{}'", soundFile->getName());
        return false;
    }

    std::vector<char> samples(soundFile->getSize());
    const int read = soundFile->read(samples.data(), soundFile->getSize());
    if (read == 0) {
        g_logger.error("unable to fill audio buffer data for '{}'", soundFile->getName());
        return false;
    }

    return fillBuffer(format, samples, samples.size(), soundFile->getRate());
}

bool SoundBuffer::fillBuffer(const ALenum sampleFormat, const std::vector<char>& data, const int size, const int rate) const
{
    alBufferData(m_bufferId, sampleFormat, data.data(), size, rate);
    const ALenum err = alGetError();
    if (err != AL_NO_ERROR) {
        g_logger.error("unable to fill audio buffer data: {}", alGetString(err));
        return false;
    }
    return true;
}