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

#include "image.h"

#include "apngloader.h"
#include "framework/core/filestream.h"
#include "framework/core/resourcemanager.h"

#define STB_IMAGE_STATIC
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_JPEG
#define STBI_ONLY_GIF
#define STBI_NO_STDIO
#define STBI_MAX_DIMENSIONS 8192
#include <stb_image.h>

using namespace qrcodegen;

Image::Image(const Size& size, const int bpp, const uint8_t* pixels) : m_size(size), m_bpp(bpp)
{
    m_pixels.resize(size.area() * bpp, 0);
    if (pixels)
        memcpy(&m_pixels[0], pixels, m_pixels.size());
}

ImagePtr Image::load(const std::string& file)
{
    const auto& path = g_resources.guessFilePath(file, "png");
    try {
        return loadPNG(path);
    } catch (const stdext::exception& e) {
        g_logger.error("Unable to load image '{}': {}", path, e.what());
    }
    return nullptr;
}

ImagePtr Image::loadPNG(const char* data, const size_t size)
{
    std::stringstream fin(std::string{ data, size });
    ImagePtr image;
    if (apng_data apng; load_apng(fin, &apng) == 0) {
        const size_t frameSize = static_cast<size_t>(apng.width) * apng.height * apng.bpp;
        const uint32_t availableFrames = apng.last_frame > apng.first_frame
                                             ? apng.last_frame - apng.first_frame
                                             : 0;
        const uint32_t frameCount = std::min(apng.num_frames, availableFrames);
        const uint32_t firstFrame = availableFrames > 0 ? apng.first_frame : 0;
        const auto* firstFrameData = apng.pdata + (static_cast<size_t>(firstFrame) * frameSize);
        image = std::make_shared<Image>(Size(apng.width, apng.height), apng.bpp, firstFrameData);
        if (frameCount > 1 && apng.frames_delay) {
            for (uint32_t i = 0; i < frameCount; ++i) {
                // Create a new Image for every frame to avoid circular reference (image -> m_animation -> image)
                const size_t frameOffset = static_cast<size_t>(apng.first_frame + i) * frameSize;
                ImagePtr frameImage = std::make_shared<Image>(Size(apng.width, apng.height), apng.bpp,
                                                              apng.pdata + frameOffset);
                image->addAnimationFrame(frameImage, apng.frames_delay[i]);
            }
        }
        free_apng(&apng);
    }

    if (!image)
        image = loadJPEG(data, size);

    if (!image)
        image = loadGIF(data, size);

    if (!image)
        return nullptr;

    int cntTransparentPixel = 0;
    for (const auto& pixel : image->getPixels()) {
        if (pixel == 0 && ++cntTransparentPixel == 4) {
            image->setTransparentPixel(true);
            break;
        }
    }

    return image;
}

ImagePtr Image::loadJPEG(const char* data, const size_t size)
{
    const auto* bytes = reinterpret_cast<const unsigned char*>(data);
    if (!data || size < 3 || size > static_cast<size_t>(std::numeric_limits<int>::max())
        || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF)
        return nullptr;

    int width = 0, height = 0, channels = 0;
    // Reject huge images from the header before allocating the decoded buffer.
    constexpr int64_t kMaxPixels = 4096 * 4096;
    if (!stbi_info_from_memory(bytes, static_cast<int>(size), &width, &height, &channels)
        || width <= 0 || height <= 0 || static_cast<int64_t>(width) * height > kMaxPixels)
        return nullptr;

    unsigned char* pixels = stbi_load_from_memory(bytes, static_cast<int>(size), &width, &height, &channels, 4);
    if (!pixels)
        return nullptr;

    ImagePtr image;
    if (width > 0 && height > 0)
        image = std::make_shared<Image>(Size(width, height), 4, pixels);
    stbi_image_free(pixels);
    return image;
}

namespace
{
    struct GifScanResult
    {
        uint32_t frames{ 0 };
        uint16_t numPlays{ 1 }; // no NETSCAPE2.0 extension: play once, like browsers
    };

    bool skipGifSubBlocks(const unsigned char* bytes, const size_t size, size_t& pos)
    {
        while (pos < size) {
            const size_t blockSize = bytes[pos++];
            if (blockSize == 0)
                return true;
            if (blockSize > size - pos)
                return false;
            pos += blockSize;
        }
        return false;
    }

    // Walks the GIF block structure without decoding, so frame count can be capped before allocation.
    std::optional<GifScanResult> scanGif(const unsigned char* bytes, const size_t size)
    {
        if (size < 13)
            return std::nullopt;

        GifScanResult result;
        size_t pos = 13;
        if (bytes[10] & 0x80)
            pos += 3u * (1u << ((bytes[10] & 0x07) + 1));

        while (pos < size) {
            const unsigned char block = bytes[pos++];
            if (block == 0x3B)
                return result;

            if (block == 0x21) {
                if (pos >= size)
                    return std::nullopt;
                const unsigned char label = bytes[pos++];
                if (label == 0xFF && pos + 12 <= size && bytes[pos] == 11
                    && (std::memcmp(bytes + pos + 1, "NETSCAPE2.0", 11) == 0 || std::memcmp(bytes + pos + 1, "ANIMEXTS1.0", 11) == 0)) {
                    const size_t loopPos = pos + 12;
                    if (loopPos + 4 <= size && bytes[loopPos] == 3 && bytes[loopPos + 1] == 1) {
                        const uint32_t loops = bytes[loopPos + 2] | (bytes[loopPos + 3] << 8);
                        // Loop count 0 means forever; otherwise it counts repeats after the first play.
                        result.numPlays = loops == 0 ? 0 : static_cast<uint16_t>(std::min<uint32_t>(loops + 1, std::numeric_limits<uint16_t>::max()));
                    }
                }
                if (!skipGifSubBlocks(bytes, size, pos))
                    return std::nullopt;
                continue;
            }

            if (block == 0x2C) {
                if (size - pos < 9)
                    return std::nullopt;
                const unsigned char flags = bytes[pos + 8];
                pos += 9;
                if (flags & 0x80)
                    pos += 3u * (1u << ((flags & 0x07) + 1));
                if (pos >= size)
                    return std::nullopt;
                ++pos; // LZW minimum code size
                if (!skipGifSubBlocks(bytes, size, pos))
                    return std::nullopt;
                ++result.frames;
                continue;
            }

            return std::nullopt;
        }

        // Truncated file without trailer: stb still decodes the frames it found.
        return result;
    }
}

ImagePtr Image::loadGIF(const char* data, const size_t size)
{
    const auto* bytes = reinterpret_cast<const unsigned char*>(data);
    if (!data || size < 6 || size > static_cast<size_t>(std::numeric_limits<int>::max())
        || (std::memcmp(bytes, "GIF87a", 6) != 0 && std::memcmp(bytes, "GIF89a", 6) != 0))
        return nullptr;

    int width = 0, height = 0, channels = 0;
    constexpr int64_t kMaxPixels = 4096 * 4096;
    if (!stbi_info_from_memory(bytes, static_cast<int>(size), &width, &height, &channels)
        || width <= 0 || height <= 0 || static_cast<int64_t>(width) * height > kMaxPixels)
        return nullptr;

    const auto scan = scanGif(bytes, size);
    if (!scan || scan->frames == 0)
        return nullptr;

    // Every frame is decoded as a full RGBA canvas; cap the total to avoid huge allocations.
    constexpr uint32_t kMaxFrames = 1024;
    constexpr int64_t kMaxTotalPixels = 16LL * 1024 * 1024;
    const int64_t framePixels = static_cast<int64_t>(width) * height;
    if (scan->frames > kMaxFrames || framePixels * scan->frames > kMaxTotalPixels) {
        g_logger.warning("GIF animation too large ({}x{}, {} frames); only the first frame is shown.", width, height, scan->frames);
        unsigned char* pixels = stbi_load_from_memory(bytes, static_cast<int>(size), &width, &height, &channels, 4);
        if (!pixels)
            return nullptr;
        auto image = std::make_shared<Image>(Size(width, height), 4, pixels);
        stbi_image_free(pixels);
        return image;
    }

    int* delays = nullptr;
    int frames = 0;
    unsigned char* pixels = stbi_load_gif_from_memory(bytes, static_cast<int>(size), &delays, &width, &height, &frames, &channels, 4);
    if (!pixels) {
        stbi_image_free(delays);
        return nullptr;
    }

    ImagePtr image;
    if (width > 0 && height > 0 && frames > 0) {
        const Size imageSize(width, height);
        const size_t frameSize = static_cast<size_t>(width) * height * 4;
        image = std::make_shared<Image>(imageSize, 4, pixels);
        if (frames > 1) {
            for (int i = 0; i < frames; ++i) {
                // Browsers treat delays <= 10ms as 100ms; animatedtexture delays are uint16_t.
                int delay = delays ? delays[i] : 0;
                if (delay <= 10)
                    delay = 100;
                delay = std::min(delay, static_cast<int>(std::numeric_limits<uint16_t>::max()));
                // Separate Image per frame to avoid a circular reference (image -> m_animation -> image).
                image->addAnimationFrame(std::make_shared<Image>(imageSize, 4, pixels + (static_cast<size_t>(i) * frameSize)), delay);
            }
            image->setAnimationPlays(scan->numPlays);
        }
    }

    stbi_image_free(pixels);
    stbi_image_free(delays);
    return image;
}

ImagePtr Image::loadPNG(const std::string& file)
{
    std::stringstream fin;
    g_resources.readFileStream(file, fin);

    const std::string buffer{ fin.str() };

    return loadPNG(buffer.data(), buffer.size());
}

void Image::savePNG(const std::string& fileName)
{
    const auto& fin = g_resources.createFile(fileName);
    if (!fin)
        throw Exception("failed to open file '{}' for write", fileName);

    fin->cache();
    std::stringstream data;
    save_png(data, m_size.width(), m_size.height(), 4, getPixelData());
    fin->write(data.str().c_str(), data.str().length());
    fin->flush();
    fin->close();
}

void Image::overwriteMask(const Color& maskedColor, const Color& insideColor, const Color& outsideColor)
{
    assert(m_bpp == 4);

    for (int p = 0; p < getPixelCount(); ++p) {
        uint8_t& r = m_pixels[p * 4 + 0];
        uint8_t& g = m_pixels[p * 4 + 1];
        uint8_t& b = m_pixels[p * 4 + 2];
        uint8_t& a = m_pixels[p * 4 + 3];

        Color pixelColor(r, g, b, a);
        Color writeColor = (pixelColor == maskedColor) ? insideColor : outsideColor;

        r = writeColor.r();
        g = writeColor.g();
        b = writeColor.b();
        a = writeColor.a();
    }
}

void Image::overwrite(const Color& color)
{
    assert(m_bpp == 4);

    for (int p = 0; p < getPixelCount(); ++p) {
        uint8_t& r = m_pixels[p * 4 + 0];
        uint8_t& g = m_pixels[p * 4 + 1];
        uint8_t& b = m_pixels[p * 4 + 2];
        uint8_t& a = m_pixels[p * 4 + 3];

        Color pixelColor(r, g, b, a);
        Color writeColor = (pixelColor == Color::alpha) ? Color::alpha : color;

        r = writeColor.r();
        g = writeColor.g();
        b = writeColor.b();
        a = writeColor.a();
    }
}

void Image::blit(const Point& dest, const ImagePtr& other)
{
    assert(m_bpp == 4);

    if (!other)
        return;

    const uint8_t* otherPixels = other->getPixelData();
    for (int p = 0; p < other->getPixelCount(); ++p) {
        const int x = p % other->getWidth();
        const int y = p / other->getWidth();
        const int pos = ((dest.y + y) * m_size.width() + (dest.x + x)) * 4;

        if (otherPixels[p * 4 + 3] != 0) {
            m_pixels[pos + 0] = otherPixels[p * 4 + 0];
            m_pixels[pos + 1] = otherPixels[p * 4 + 1];
            m_pixels[pos + 2] = otherPixels[p * 4 + 2];
            m_pixels[pos + 3] = otherPixels[p * 4 + 3];
        }
    }
}

void Image::paste(const ImagePtr& other)
{
    assert(m_bpp == 4);

    if (!other)
        return;

    const uint8_t* otherPixels = other->getPixelData();
    for (int p = 0; p < other->getPixelCount(); ++p) {
        const int x = p % other->getWidth();
        const int y = p / other->getWidth();
        const int pos = (y * m_size.width() + x) * 4;

        m_pixels[pos + 0] = otherPixels[p * 4 + 0];
        m_pixels[pos + 1] = otherPixels[p * 4 + 1];
        m_pixels[pos + 2] = otherPixels[p * 4 + 2];
        m_pixels[pos + 3] = otherPixels[p * 4 + 3];
    }
}

bool Image::nextMipmap()
{
    assert(m_bpp == 4);

    const int iw = m_size.width();
    const int ih = m_size.height();
    if ((iw == 1 && ih == 1) || m_pixels.empty())
        return false;

    const int ow = iw > 1 ? iw / 2 : 1;
    const int oh = ih > 1 ? ih / 2 : 1;

    std::vector<uint8_t > pixels(ow * oh * 4, 0xFF);

    //FIXME: calculate mipmaps for 8x1, 4x1, 2x1 ...
    if (iw != 1 && ih != 1) {
        for (int x = 0; x < ow; ++x) {
            for (int y = 0; y < oh; ++y) {
                uint8_t* inPixel[4];
                inPixel[0] = &m_pixels[((y * 2) * iw + (x * 2)) * 4];
                inPixel[1] = &m_pixels[((y * 2) * iw + (x * 2) + 1) * 4];
                inPixel[2] = &m_pixels[((y * 2 + 1) * iw + (x * 2)) * 4];
                inPixel[3] = &m_pixels[((y * 2 + 1) * iw + (x * 2) + 1) * 4];
                uint8_t* outPixel = &pixels[(y * ow + x) * 4];

                int pixelsSum[4];
                for (int& i : pixelsSum)
                    i = 0;

                int usedPixels = 0;
                for (auto& j : inPixel) {
                    // ignore colors of complete alpha pixels
                    if (j[3] < 16)
                        continue;

                    for (int i = 0; i < 4; ++i)
                        pixelsSum[i] += j[i];

                    ++usedPixels;
                }

                // try to guess the alpha pixel more accurately
                for (int i = 0; i < 4; ++i) {
                    if (usedPixels > 0)
                        outPixel[i] = pixelsSum[i] / usedPixels;
                    else
                        outPixel[i] = 0;
                }
                outPixel[3] = pixelsSum[3] / 4;
            }
        }
    }

    m_pixels = pixels;
    m_size = { ow, oh };
    return true;
}

void Image::flipVertically()
{
    for (int line = 0, h = m_size.height(), w = m_size.width(); line != h / 2; ++line) {
        std::swap_ranges(
            m_pixels.begin() + 4 * w * line,
            m_pixels.begin() + 4 * w * (line + 1),
            m_pixels.begin() + 4 * w * (h - line - 1));
    }
}

void Image::setOpacity(const uint8_t v) {
    for (size_t i = 3, s = m_pixels.size(); i < s; i += 4)
        m_pixels[i] = v;
}

void Image::reverseChannels()
{
    uint8_t* pixelData = m_pixels.data();
    for (uint8_t* itr = pixelData; itr < pixelData + m_pixels.size(); itr += m_bpp) {
        std::swap(*(itr + 0), *(itr + 2));
    }
}

ImagePtr Image::fromQRCode(const std::string& code, const int border)
{
    try {
        const QrCode qrCode = QrCode::encodeText(code.c_str(), QrCode::Ecc::MEDIUM);

        const auto size = qrCode.getSize();
        ImagePtr image(new Image(Size(size + border * 2, size + border * 2)));

        for (int x = 0; x < size + border * 2; ++x) {
            for (int y = 0; y < size + border * 2; ++y) {
                image->setPixel(x, y, qrCode.getModule(x - border, y - border) ? Color::black : Color::white);
            }
        }

        return image;
    } catch (const std::exception& e) {
        g_logger.error("Failed to encode qr-code: '{}': {}", code, e.what());
    }

    return {};
}
