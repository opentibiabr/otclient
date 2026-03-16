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

#include <framework/global.h>

#include <AL/al.h>
#include <AL/alc.h>
#include <AL/efx-presets.h>
#include <AL/efx.h>

class SoundManager;
class SoundSource;
class SoundBuffer;
class SoundFile;
class SoundChannel;
class StreamSoundSource;
class CombinedSoundSource;
class OggSoundFile;
class SoundEffect;

using SoundSourcePtr = std::shared_ptr<SoundSource>;
using SoundFilePtr = std::shared_ptr<SoundFile>;
using SoundBufferPtr = std::shared_ptr<SoundBuffer>;
using SoundChannelPtr = std::shared_ptr<SoundChannel>;
using StreamSoundSourcePtr = std::shared_ptr<StreamSoundSource>;
using CombinedSoundSourcePtr = std::shared_ptr<CombinedSoundSource>;
using OggSoundFilePtr = std::shared_ptr<OggSoundFile>;
using SoundEffectPtr = std::shared_ptr<SoundEffect>;
