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

#include "texture.h"

class AnimatedTexture final : public Texture
{
public:
    AnimatedTexture(const Size& size, const std::vector<ImagePtr>& frames, std::vector<uint16_t> framesDelay, uint16_t numPlays, bool buildMipmaps = false, bool compress = false);
    ~AnimatedTexture() override = default;

    TexturePtr get(uint32_t& frame, Timer& timer);
    TexturePtr getCurrentFrame();

    void create() override;
    void buildHardwareMipmaps() override;

    void setSmooth(bool smooth) override;
    void setRepeat(bool repeat) override;

    uint32_t getNumPlays() const { return m_numPlays; }
    void setNumPlays(const uint32_t n) { m_numPlays = n; }

    bool isOnMap() const { return m_onMap; }
    void setOnMap(const bool v) { m_onMap = v; }

    void update();
    void restart() { m_animTimer.restart(); m_currentPlay = 0; m_currentFrame = 0; }

    bool isAnimatedTexture() const override { return true; }
    bool running() const { return m_animTimer.running(); }

    void allowAtlasCache() override;

private:
    std::vector<TexturePtr> m_frames;
    std::vector<uint16_t> m_framesDelay;

    bool m_onMap{ false };

    uint32_t m_currentFrame{ 0 };
    uint32_t m_currentPlay{ 0 };
    uint32_t m_numPlays{ 0 };

    Timer m_animTimer;
};
