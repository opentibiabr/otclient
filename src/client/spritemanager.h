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

#include <framework/core/declarations.h>
#include <framework/graphics/declarations.h>

class FileMetadata
{
public:
    FileMetadata() = default;
    FileMetadata(const FileStreamPtr& file);

    uint32_t getSpriteId() const { return spriteId; }
    const std::string& getFileName() const { return fileName; }
    uint32_t getOffset() const { return offset; }
    uint32_t getFileSize() const { return fileSize; }
private:
    std::string fileName;
    uint32_t offset = 0;
    uint32_t fileSize = 0;
    uint32_t spriteId = 0;
};

//@bindsingleton g_sprites
class SpriteManager
{
public:
    void init();
    void terminate();

    bool loadSpr(std::string file);
    bool loadRegularSpr(std::string file);
    bool loadCwmSpr(std::string file);
    void reload();
    void unload();

#ifdef FRAMEWORK_EDITOR
    void saveSpr(const std::string& fileName);
#endif

    uint32_t getSignature() { return m_signature; }
    int getSpritesCount() { return m_spritesCount; }

    ImagePtr getSpriteImage(int id) {
        bool isLoading = false;
        return  getSpriteImage(id, isLoading);
    }

    ImagePtr getSpriteImage(int id, bool& isLoading);
    bool isLoaded() { return m_loaded; }

private:
    enum class SpriteLoadState
    {
        NONE,
        LOADING,
        LOADED
    };

    struct FileStream_m
    {
        FileStreamPtr file;
        std::atomic<SpriteLoadState> m_loadingState = SpriteLoadState::NONE;

        FileStream_m(FileStreamPtr f) : file(std::move(f)) {}
    };

    void load();
    FileStreamPtr getSpriteFile() const {
        return m_spritesFiles[0]->file;
    }

    ImagePtr getSpriteImageHd(int id, const FileStreamPtr& file);
    ImagePtr getSpriteImage(int id, const FileStreamPtr& file);

    std::string m_lastFileName;

    bool m_spritesHd{ false };
    bool m_loaded{ false };
    uint32_t m_signature{ 0 };
    uint32_t m_spritesCount{ 0 };
    uint32_t m_spritesOffset{ 0 };

    std::vector<std::unique_ptr<FileStream_m>> m_spritesFiles;
    std::unordered_map<uint32_t, FileMetadata> m_cwmSpritesMetadata;
};

extern SpriteManager g_sprites;
