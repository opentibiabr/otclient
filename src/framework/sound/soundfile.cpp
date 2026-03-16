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

#include "oggsoundfile.h"
#include "soundfile.h"
#include "framework/core/filestream.h"
#include <framework/core/resourcemanager.h>

std::string SoundFile::getName() const { return m_file ? m_file->name() : std::string(); }
bool SoundFile::eof() const { return m_file->eof(); }
SoundFilePtr SoundFile::loadSoundFile(const std::string& filename)
{
    const auto& file = g_resources.openFile(filename);
    if (!file)
        throw Exception("unable to open {}", filename);

    // cache file buffer to avoid lags from hard drive
    file->cache();

    char magic[4]{ 0 };
    file->read(magic, 4);
    file->seek(0);

    if (strncmp(magic, "OggS", 4) == 0) {
        const auto& oggSoundFile = std::make_shared<OggSoundFile>(file);
        if (oggSoundFile->prepareOgg())
            return oggSoundFile;
    } else
        throw Exception("unknown sound file format {}", filename);

    return nullptr;
}

ALenum SoundFile::getSampleFormat() const
{
    if (m_channels == 2) {
        if (m_bps == 16)
            return AL_FORMAT_STEREO16;
        if (m_bps == 8)
            return AL_FORMAT_STEREO8;
    } else if (m_channels == 1) {
        if (m_bps == 16)
            return AL_FORMAT_MONO16;
        if (m_bps == 8)
            return AL_FORMAT_MONO8;
    }
    return AL_UNDETERMINED;
}