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

#pragma once

#include <framework/graphics/declarations.h>
#include <framework/luaengine/luaobject.h>

enum class SpriteLayout
{
    // default sheet sizes
    SIZE_32_32 = 0,
    SIZE_32_64 = 1,
    SIZE_64_32 = 2,
    SIZE_64_64 = 3,

    // extended sheet sizes (all possible combinations within 384x384 spritesheet)
    SIZE_32_96  = 4,
    SIZE_32_128 = 5,
    SIZE_32_192 = 6,
    SIZE_32_384 = 7,
    SIZE_64_96  = 8,
    SIZE_64_128 = 9,
    SIZE_64_192 = 10,
    SIZE_64_384 = 11,
    SIZE_96_32  = 12,
    SIZE_96_64  = 13,
    SIZE_96_96  = 14,
    SIZE_96_128 = 15,
    SIZE_96_192 = 16,
    SIZE_96_384 = 17,
    SIZE_128_32  = 18,
    SIZE_128_64  = 19,
    SIZE_128_96  = 20,
    SIZE_128_128 = 21,
    SIZE_128_192 = 22,
    SIZE_128_384 = 23,
    SIZE_192_32  = 24,
    SIZE_192_64  = 25,
    SIZE_192_96  = 26,
    SIZE_192_128 = 27,
    SIZE_192_192 = 28,
    SIZE_192_384 = 29,
    SIZE_384_32  = 30,
    SIZE_384_64  = 31,
    SIZE_384_96  = 32,
    SIZE_384_128 = 33,
    SIZE_384_192 = 34,
    SIZE_384_384 = 35
};

enum class SpriteLoadState
{
    NONE,
    LOADING,
    LOADED
};

class SpriteSheet
{
public:
    static constexpr uint16_t SIZE = 384;

    SpriteSheet(const int firstId, const int lastId, const SpriteLayout spriteLayout, std::string file) : firstId(firstId), lastId(lastId), spriteLayout(spriteLayout), file(std::move(
        file))
    {
    }

    Size getSpriteSize() const;

    int getSpritesPerSheet() const;

    // 64 pixel width == 6 columns each 64x or 32 pixels, 12 columns
    int getColumns() const { return SIZE / getSpriteSize().width(); }

    int firstId = 0;
    int lastId = 0;

    SpriteLayout spriteLayout = SpriteLayout::SIZE_32_32;
    std::atomic<SpriteLoadState> m_loadingState = SpriteLoadState::NONE;
    std::unique_ptr<uint8_t[]> data;
    std::string file;
};

//@bindsingleton g_spriteAppearances
class SpriteAppearances
{
public:
    void init();
    void terminate();

    void unload();

    void setSpritesCount(const int count) { m_spritesCount = count; }
    int getSpritesCount() const { return m_spritesCount; }

    void setPath(const std::string& path) { m_path = path; }
    std::string getPath() const { return m_path; }

    bool loadSpriteSheet(const SpriteSheetPtr& sheet) const;
    void saveSheetToFileBySprite(int id, const std::string& file);
    void saveSheetToFile(const SpriteSheetPtr& sheet, const std::string& file);
    SpriteSheetPtr getSheetBySpriteId(int id, bool load = true) {
        bool isLoading = false;
        return getSheetBySpriteId(id, isLoading, load);
    }
    SpriteSheetPtr getSheetBySpriteId(int id, bool& isLoading, bool load = true);

    void addSpriteSheet(const SpriteSheetPtr& sheet) { m_sheets.emplace_back(sheet); }

    ImagePtr getSpriteImage(int id) {
        bool isLoading = false;
        return getSpriteImage(id, isLoading);
    }
    ImagePtr getSpriteImage(int id, bool& isLoading);
    void saveSpriteToFile(int id, const std::string& file);

private:
    uint32_t m_spritesCount{ 0 };
    std::vector<SpriteSheetPtr> m_sheets;
    std::string m_path;
};

extern SpriteAppearances g_spriteAppearances;
