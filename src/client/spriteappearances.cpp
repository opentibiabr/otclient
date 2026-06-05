/*
 * Copyright (c) 2022 Nekiro <https://github.com/nekiro>
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

#include "spriteappearances.h"

#include <nlohmann/json_fwd.hpp>
#include "lzma.h"
#include "gameconfig.h"
#include "framework/core/filestream.h"
#include "framework/core/resourcemanager.h"
#include "framework/graphics/image.h"

 // warnings related to protobuf
    // https://android.googlesource.com/platform/external/protobuf/+/brillo-m9-dev/vsprojects/readme.txt

using json = nlohmann::json;

SpriteAppearances g_spriteAppearances;

void SpriteAppearances::init()
{
    // in tibia 12.81 there is currently 3482 sheets
    m_sheets.reserve(4000);
}

void SpriteAppearances::terminate()
{
    unload();
}

Size SpriteSheet::getSpriteSize() const
{    
    // this array includes all possible combinations within 384x384 sheet
    // if you intend to change that, you will also have to modify the assets editor
    // CHANGING THIS MAY BREAK READING EXISTING SPRITESHEETS

    // tile sizes in spritesheets, see SpriteLayout for array key definitions
    static const std::array<Size, 36> sizes = {
        Size(32,32),  // 0
        Size(32,64),  // 1
        Size(64,32),  // 2
        Size(64,64),  // 3
        Size(32,96),  // 4
        Size(32,128), // 5
        Size(32,192), // 6
        Size(32,384), // 7
        Size(64,96),  // 8
        Size(64,128), // 9
        Size(64,192), // 10
        Size(64,384), // 11
        Size(96,32),  // 12
        Size(96,64),  // 13
        Size(96,96),  // 14
        Size(96,128), // 15
        Size(96,192), // 16
        Size(96,384), // 17
        Size(128,32),  // 18
        Size(128,64),  // 19
        Size(128,96),  // 20
        Size(128,128), // 21
        Size(128,192), // 22
        Size(128,384), // 23
        Size(192,32),  // 24
        Size(192,64),  // 25
        Size(192,96),  // 26
        Size(192,128), // 27
        Size(192,192), // 28
        Size(192,384), // 29
        Size(384,32),  // 30
        Size(384,64),  // 31
        Size(384,96),  // 32
        Size(384,128), // 33
        Size(384,192), // 34
        Size(384,384)  // 35
    };

    const size_t idx = static_cast<size_t>(spriteLayout);
    if (idx < sizes.size())
        return sizes[idx];

    return sizes[0];
}

int SpriteSheet::getSpritesPerSheet() const
{
    const Size& size = getSpriteSize();
    const int spritesPerColumn = SpriteSheet::SIZE / size.height();

    return getColumns() * spritesPerColumn;
}

bool SpriteAppearances::loadSpriteSheet(const SpriteSheetPtr& sheet) const
{
    if (sheet->m_loadingState.load(std::memory_order_acquire) == SpriteLoadState::LOADING)
        return false;

    if (sheet->data)
        return true;

    if (sheet->m_loadingState.exchange(SpriteLoadState::LOADING, std::memory_order_acq_rel) == SpriteLoadState::LOADING)
        return false;

    try {
        const auto& path = fmt::format("{}{}", g_spriteAppearances.getPath(), sheet->file);
        if (!g_resources.fileExists(path))
            return false;

        const auto& fin = g_resources.openFile(path);
        fin->cache(true);

        thread_local static std::array<uint8_t, LZMA_UNCOMPRESSED_SIZE> decompressBuffer;

        /*
           CIP's header, always 32 (0x20) bytes.
           Header format:
           [0x00, X):          A variable number of NULL (0x00) bytes. The amount of pad-bytes can vary depending on how many
                               bytes the "7-bit integer encoded LZMA file size" take.
           [X, X + 0x05):      The constant byte sequence [0x70 0x0A 0xFA 0x80 0x24]
           [X + 0x05, 0x20]:   LZMA file size (Note: excluding the 32 bytes of this header) encoded as a 7-bit integer
       */

        while (fin->getU8() == 0x00);
        fin->skip(4);
        while ((fin->getU8() & 0x80) == 0x80);

        const uint8_t lclppb = fin->getU8();

        lzma_options_lzma options{};
        options.lc = lclppb % 9;

        const int remainder = lclppb / 9;
        options.lp = remainder % 5;
        options.pb = remainder / 5;

        uint32_t dictionarySize = 0;
        for (uint8_t i = 0; i < 4; ++i) {
            dictionarySize += fin->getU8() << (i * 8);
        }

        options.dict_size = dictionarySize;

        fin->skip(8); // cip compressed size

        lzma_stream stream = LZMA_STREAM_INIT;

        const lzma_filter filters[2] = {
            lzma_filter{LZMA_FILTER_LZMA1, &options},
            lzma_filter{LZMA_VLI_UNKNOWN, nullptr}
        };

        lzma_ret ret = lzma_raw_decoder(&stream, filters);
        if (ret != LZMA_OK) {
            throw stdext::exception(fmt::format("failed to initialize lzma raw decoder result: {}", ret));
        }

        stream.next_in = &fin->m_data[fin->tell()];
        stream.avail_in = fin->size() - fin->tell();
        stream.next_out = decompressBuffer.data();
        stream.avail_out = decompressBuffer.size();

        const auto result = lzma_code(&stream, LZMA_RUN);
        lzma_end(&stream);

        if (result != LZMA_STREAM_END)
            throw stdext::exception("LZMA decompression failed");

        // pixel offset
        const uint8_t* bmpOffsetPtr = decompressBuffer.data() + 10;
        const uint32_t bmpDataOffset =
            bmpOffsetPtr[0] |
            (bmpOffsetPtr[1] << 8) |
            (bmpOffsetPtr[2] << 16) |
            (bmpOffsetPtr[3] << 24);

        // validate offset
        if (bmpDataOffset + BYTES_IN_SPRITE_SHEET > LZMA_UNCOMPRESSED_SIZE)
            throw stdext::exception("sprite sheet image offset out of bounds");

        uint8_t* bufferStart = decompressBuffer.data() + bmpDataOffset;

        // swap BGR ? RGB and fix magenta
        for (int i = 0; i < BYTES_IN_SPRITE_SHEET; i += 4) {
            std::swap(bufferStart[i], bufferStart[i + 2]); // B <-> R

            const uint32_t rgb = bufferStart[i] | (bufferStart[i + 1] << 8) | (bufferStart[i + 2] << 16);
            if (rgb == 0xFF00FF) {
                bufferStart[i + 0] = 0x00;
                bufferStart[i + 1] = 0x00;
                bufferStart[i + 2] = 0x00;
                bufferStart[i + 3] = 0x00;
            }
        }

        // vertical flip
        constexpr int halfHeight = SpriteSheet::SIZE / 2;
        uint8_t tempLine[SPRITE_SHEET_WIDTH_BYTES];
        for (int y = 0; y < halfHeight; ++y) {
            uint8_t* top = bufferStart + y * SPRITE_SHEET_WIDTH_BYTES;
            uint8_t* bottom = bufferStart + (SpriteSheet::SIZE - 1 - y) * SPRITE_SHEET_WIDTH_BYTES;

            std::memcpy(tempLine, top, SPRITE_SHEET_WIDTH_BYTES);
            std::memcpy(top, bottom, SPRITE_SHEET_WIDTH_BYTES);
            std::memcpy(bottom, tempLine, SPRITE_SHEET_WIDTH_BYTES);
        }

        sheet->data = std::make_unique<uint8_t[]>(BYTES_IN_SPRITE_SHEET);
        std::memcpy(sheet->data.get(), bufferStart, BYTES_IN_SPRITE_SHEET);

        sheet->m_loadingState.store(SpriteLoadState::LOADED, std::memory_order_release);
        return true;
    } catch (const std::exception& e) {
        sheet->m_loadingState.store(SpriteLoadState::NONE, std::memory_order_release);
        g_logger.error("Failed to load single sprite sheet '{}': {}", sheet->file, e.what());
        return false;
    }
}

void SpriteAppearances::unload()
{
    m_spritesCount = 0;
    m_sheets.clear();
}

SpriteSheetPtr SpriteAppearances::getSheetBySpriteId(const int id, bool& isLoading, const bool load /* = true */)
{
    if (id == 0) {
        return nullptr;
    }

    // find sheet
    const auto sheetIt = std::ranges::find_if(m_sheets, [=](const SpriteSheetPtr& sheet) {
        return id >= sheet->firstId && id <= sheet->lastId;
    });

    if (sheetIt == m_sheets.end())
        return nullptr;

    const auto& sheet = *sheetIt;

    if (load && !loadSpriteSheet(sheet)) {
        isLoading = sheet->m_loadingState == SpriteLoadState::LOADING;
        return nullptr;
    }

    return sheet;
}

ImagePtr SpriteAppearances::getSpriteImage(const int id, bool& isLoading)
{
    try {
        const auto& sheet = getSheetBySpriteId(id, isLoading, true);
        if (!sheet) {
            return nullptr;
        }

        const Size& size = sheet->getSpriteSize();

        const auto& image = std::make_shared<Image>(size);
        uint8_t* pixelData = image->getPixelData();

        const int spriteOffset = id - sheet->firstId;
        const int allColumns = sheet->getColumns();
        const int spritesPerSheet = sheet->getSpritesPerSheet();

        if (spriteOffset < 0 || spriteOffset >= spritesPerSheet) {
            g_logger.error("Sprite id {} is out of bounds for sheet {} (offset {}, max {})", id, sheet->file, spriteOffset, spritesPerSheet);
            return nullptr;
        }
        const int spriteRow = std::floor(static_cast<float>(spriteOffset) / static_cast<float>(allColumns));
        const int spriteColumn = spriteOffset % allColumns;

        const int spriteWidthBytes = size.width() * 4;

        for (int height = size.height() * spriteRow, offset = 0; height < size.height() + (spriteRow * size.height()); height++, offset++) {
            std::memcpy(&pixelData[offset * spriteWidthBytes], &sheet->data[(height * SPRITE_SHEET_WIDTH_BYTES) + (spriteColumn * spriteWidthBytes)], spriteWidthBytes);
        }

        if (!image->hasTransparentPixel()) {
            // The image must be more than 4 pixels transparent to be considered transparent.
            uint8_t cntTrans = 0;
            const auto& buf = image->getPixels();
            for (size_t i = 3, n = buf.size(); i < n; i += 4) {
                if (buf[i] == 0x00 && ++cntTrans > 4) {
                    image->setTransparentPixel(true);
                    break;
                }
            }
        }

        return image;
    } catch (const stdext::exception& e) {
        g_logger.error("Failed to get sprite id {}: {}", id, e.what());
        return nullptr;
    }
}

void SpriteAppearances::saveSpriteToFile(const int id, const std::string& file)
{
    if (const auto& sprite = getSpriteImage(id)) {
        sprite->savePNG(file);
    }
}

void SpriteAppearances::saveSheetToFileBySprite(const int id, const std::string& file)
{
    if (const auto& sheet = getSheetBySpriteId(id)) {
        Image image({ SpriteSheet::SIZE }, 4, sheet->data.get());
        image.savePNG(file);
    }
}

void SpriteAppearances::saveSheetToFile(const SpriteSheetPtr& sheet, const std::string& file)
{
    Image image({ SpriteSheet::SIZE }, 4, sheet->data.get());
    image.savePNG(file);
}