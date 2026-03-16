/*
 * Copyright (c) 2010-2025 OTClient <https://github.com/edubart/otclient>
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

#include <lzma.h>

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
        g_logger.error("unable to load image '{}': {}", path, e.what());
    }
    return nullptr;
}

ImagePtr Image::loadPNG(const char* data, const size_t size)
{
    std::stringstream fin(std::string{ data, size });
    ImagePtr image;
    if (apng_data apng; load_apng(fin, &apng) == 0) {
        image = std::make_shared<Image>(Size(apng.width, apng.height), apng.bpp, apng.pdata);
        free_apng(&apng);
    }

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

void Image::saveBmpLzma(const std::string& fileName)
{
    // Produces a CIP-format .bmp.lzma file compatible with SatelliteMap::loadChunkTexture():
    // [32-byte zero header] + [LZMA-alone stream of a 32-bpp BI_BITFIELDS BMP]

    const int w = m_size.width();
    const int h = m_size.height();
    const uint32_t rowBytes = static_cast<uint32_t>(w) * 4; // 32-bpp, already 4-byte aligned
    const uint32_t pixelDataSize = rowBytes * h;
    const uint32_t pixelDataOffset = 66; // 14 (file hdr) + 40 (DIB hdr) + 12 (3 masks)
    const uint32_t bmpSize = pixelDataOffset + pixelDataSize;

    // --- Build BMP in memory ---
    std::vector<uint8_t> bmp(bmpSize, 0);

    auto writeU16 = [&](size_t off, uint16_t v) {
        bmp[off]     = static_cast<uint8_t>(v);
        bmp[off + 1] = static_cast<uint8_t>(v >> 8);
    };
    auto writeU32 = [&](size_t off, uint32_t v) {
        bmp[off]     = static_cast<uint8_t>(v);
        bmp[off + 1] = static_cast<uint8_t>(v >> 8);
        bmp[off + 2] = static_cast<uint8_t>(v >> 16);
        bmp[off + 3] = static_cast<uint8_t>(v >> 24);
    };
    auto writeI32 = [&](size_t off, int32_t v) { writeU32(off, static_cast<uint32_t>(v)); };

    // BMP File Header (14 bytes)
    bmp[0] = 'B'; bmp[1] = 'M';
    writeU32(2, bmpSize);          // file size
    // bytes 6-9: reserved = 0
    writeU32(10, pixelDataOffset); // pixel data offset

    // BITMAPINFOHEADER (40 bytes) at offset 14
    writeU32(14, 40);              // DIB header size
    writeI32(18, w);               // width
    writeI32(22, -h);              // height (negative = top-down)
    writeU16(26, 1);               // planes
    writeU16(28, 32);              // bits per pixel
    writeU32(30, 3);               // compression = BI_BITFIELDS
    writeU32(34, pixelDataSize);   // image size

    // Channel masks (12 bytes) at offset 54 — standard BGRA
    writeU32(54, 0x00FF0000u);     // R mask
    writeU32(58, 0x0000FF00u);     // G mask
    writeU32(62, 0x000000FFu);     // B mask

    // Pixel data at offset 66: convert RGBA → BGRA
    uint8_t* dst = bmp.data() + pixelDataOffset;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const uint8_t* src = &m_pixels[static_cast<size_t>(y * w + x) * 4];
            dst[0] = src[2]; // B
            dst[1] = src[1]; // G
            dst[2] = src[0]; // R
            dst[3] = src[3]; // A
            dst += 4;
        }
    }

    // --- LZMA-alone compress ---
    lzma_options_lzma options;
    lzma_lzma_preset(&options, 6);

    lzma_stream strm = LZMA_STREAM_INIT;
    if (lzma_alone_encoder(&strm, &options) != LZMA_OK) {
        g_logger.error("saveBmpLzma: failed to init LZMA encoder for '{}'", fileName);
        return;
    }

    strm.next_in  = bmp.data();
    strm.avail_in = bmp.size();

    std::vector<uint8_t> lzmaOut;
    lzmaOut.reserve(bmp.size() / 2); // compressed should be smaller

    std::array<uint8_t, 65536> buf{};
    lzma_ret ret = LZMA_OK;
    while (ret != LZMA_STREAM_END) {
        strm.next_out  = buf.data();
        strm.avail_out = buf.size();

        const lzma_action action = (strm.avail_in == 0) ? LZMA_FINISH : LZMA_RUN;
        ret = lzma_code(&strm, action);

        if (ret != LZMA_OK && ret != LZMA_STREAM_END) {
            g_logger.error("saveBmpLzma: LZMA compression error ({}) for '{}'", static_cast<int>(ret), fileName);
            lzma_end(&strm);
            return;
        }

        const size_t got = buf.size() - strm.avail_out;
        lzmaOut.insert(lzmaOut.end(), buf.begin(), buf.begin() + got);
    }
    lzma_end(&strm);

    // --- Write CIP file: 32-byte header + LZMA data ---
    const auto& fin = g_resources.createFile(fileName);
    if (!fin) {
        g_logger.error("saveBmpLzma: failed to open '{}' for write", fileName);
        return;
    }

    fin->cache();

    // Build proper 32-byte CIP header:
    //   [0x00 padding...] [0x70 0x0A 0xFA 0x80 0x24] [7-bit varint: LZMA data size]
    // Total must be exactly 32 bytes.
    std::array<uint8_t, 32> cipHeader{};  // zero-initialized

    // Encode LZMA data size as 7-bit varint
    std::vector<uint8_t> varintBytes;
    size_t tmpSize = lzmaOut.size();
    do {
        uint8_t b = static_cast<uint8_t>(tmpSize & 0x7F);
        tmpSize >>= 7;
        if (tmpSize > 0)
            b |= 0x80;
        varintBytes.push_back(b);
    } while (tmpSize > 0);

    constexpr uint8_t magic[] = { 0x70, 0x0A, 0xFA, 0x80, 0x24 };
    constexpr size_t magicLen = sizeof(magic);

    // Layout: [zeros] [magic(5)] [varint(N)] = 32
    const size_t magicOffset = 32 - magicLen - varintBytes.size();
    memcpy(&cipHeader[magicOffset], magic, magicLen);
    memcpy(&cipHeader[magicOffset + magicLen], varintBytes.data(), varintBytes.size());

    fin->write(cipHeader.data(), cipHeader.size());

    // LZMA-alone data
    fin->write(lzmaOut.data(), lzmaOut.size());

    fin->flush();
    fin->close();
}

void Image::cut()
{
    if (!m_blited) {
        // Empty image, nothing to cut
        return;
    }
    
    // Remove 2-tile (64px) margin that was added for large items (64x64 sprites)
    const int margin = 64;  // 2 tiles * 32 pixels
    const int newWidth = m_size.width() - margin;
    const int newHeight = m_size.height() - margin;
    
    if (newWidth <= 0 || newHeight <= 0)
        return;
    
    // Copy pixels from center region (offset by 32px) to new smaller buffer
    std::vector<uint8_t> newPixels(newWidth * newHeight * m_bpp, 0);
    const int srcOffset = 32;  // Start copying 1 tile (32px) from edge
    
    for (int y = 0; y < newHeight; ++y) {
        for (int x = 0; x < newWidth; ++x) {
            const int targetPos = (y * newWidth + x) * m_bpp;
            const int sourcePos = ((y + srcOffset) * m_size.width() + x + srcOffset) * m_bpp;
            
            for (int c = 0; c < m_bpp; ++c) {
                newPixels[targetPos + c] = m_pixels[sourcePos + c];
            }
        }
    }
    
    m_pixels = std::move(newPixels);
    m_size = Size(newWidth, newHeight);
}

void Image::addShadow(uint8_t originalPercent)
{
    assert(m_bpp == 4);
    
    if (originalPercent >= 100)
        return;
    
    for (int p = 0; p < getPixelCount(); ++p) {
        const int p4 = p * 4;
        
        if (m_pixels[p4 + 3] > 0) {  // Only affect non-transparent pixels
            m_pixels[p4 + 0] = static_cast<uint8_t>((m_pixels[p4 + 0] * originalPercent) / 100);
            m_pixels[p4 + 1] = static_cast<uint8_t>((m_pixels[p4 + 1] * originalPercent) / 100);
            m_pixels[p4 + 2] = static_cast<uint8_t>((m_pixels[p4 + 2] * originalPercent) / 100);
        }
    }
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

    m_blited = true;  // Mark that something was blitted

    const uint8_t* otherPixels = other->getPixelData();
    for (int p = 0; p < other->getPixelCount(); ++p) {
        const int x = p % other->getWidth();
        const int y = p / other->getWidth();
        const int destX = dest.x + x;
        const int destY = dest.y + y;

        // Bounds check: skip pixels outside target image
        if (destX < 0 || destX >= m_size.width() || destY < 0 || destY >= m_size.height())
            continue;

        const int pos = (destY * m_size.width() + destX) * 4;

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
    if (iw == 1 && ih == 1 || m_pixels.empty())
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

void Image::addShadowToSquare(const Point& dest, int squareSize, int shadowPercent)
{
    assert(m_bpp == 4);

    if (shadowPercent <= 0 || shadowPercent > 100)
        return;

    // clamp to 0-100 and invert so 100% shadow = fully dark
    const int brightnessFactor = 100 - shadowPercent;

    const int startX = std::max(0, dest.x);
    const int startY = std::max(0, dest.y);
    const int endX = std::min(m_size.width(), dest.x + squareSize);
    const int endY = std::min(m_size.height(), dest.y + squareSize);

    for (int y = startY; y < endY; ++y) {
        for (int x = startX; x < endX; ++x) {
            uint8_t* pixel = getPixel(x, y);
            if (pixel && pixel[3] > 0) {  // Only affect non-transparent pixels
                pixel[0] = static_cast<uint8_t>(pixel[0] * brightnessFactor / 100);  // R
                pixel[1] = static_cast<uint8_t>(pixel[1] * brightnessFactor / 100);  // G
                pixel[2] = static_cast<uint8_t>(pixel[2] * brightnessFactor / 100);  // B
            }
        }
    }
}