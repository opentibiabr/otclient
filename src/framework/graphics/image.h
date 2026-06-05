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

class Image
{
public:
    Image(const Size& size, int bpp = 4, const uint8_t* pixels = nullptr);

    static ImagePtr load(const std::string& file);
    static ImagePtr loadPNG(const char* data, size_t size);
    static ImagePtr loadPNG(const std::string& file);
    static ImagePtr fromQRCode(const std::string& code, int border);

    void savePNG(const std::string& fileName);

    void overwriteMask(const Color& maskedColor, const Color& insideColor = Color::white, const Color& outsideColor = Color::alpha);
    void overwrite(const Color& color);
    void blit(const Point& dest, const ImagePtr& other);
    void paste(const ImagePtr& other);
    void resize(const Size& size) {
        if (m_size == size)
            return;

        m_pixels.resize((m_size = size).area() * static_cast<size_t>(m_bpp), 0);
    }
    bool nextMipmap();

    void flipVertically();
    void setOpacity(uint8_t v);

    void reverseChannels(); // argb -> bgra or bgra -> argb

    void setPixel(const int x, const int y, const uint8_t* pixel) {
        const auto index = static_cast<size_t>(y * m_size.width() + x) * m_bpp;
        if (index < m_pixels.size())
            memcpy(&m_pixels[index], pixel, m_bpp);
    }
    void setPixel(const int x, const int y, const Color& color) { setPixel(x, y, Color(color.rgba()).rgba()); }
    void setPixel(const int x, const int y, uint32_t rgba) { setPixel(x, y, reinterpret_cast<uint8_t*>(&rgba)); }

    std::vector<uint8_t>& getPixels() { return m_pixels; }
    uint8_t* getPixelData() { return &m_pixels[0]; }
    int getPixelCount() const { return m_size.area(); }
    const Size& getSize() const { return m_size; }
    int getWidth() const { return m_size.width(); }
    int getHeight() const { return m_size.height(); }
    int getBpp() const { return m_bpp; }
    uint8_t* getPixel(const int x, const int y) { return &m_pixels[static_cast<size_t>(y * m_size.width() + x) * m_bpp]; }

    bool hasTransparentPixel() const { return m_transparentPixel; }
    void setTransparentPixel(const bool value) { m_transparentPixel = value; }

private:
    std::vector<uint8_t > m_pixels;
    Size m_size;

    int m_bpp;
    bool m_transparentPixel{ false };

public:
    struct AnimationFrame {
        std::shared_ptr<Image> image;
        int delay;
    };

private:
    std::vector<AnimationFrame> m_animation;

public:
    bool isAnimated() const { return !m_animation.empty(); }
    const std::vector<AnimationFrame>& getAnimation() const { return m_animation; }
    void addAnimationFrame(const std::shared_ptr<Image>& image, int delay) { m_animation.push_back({ image, delay }); }
};

