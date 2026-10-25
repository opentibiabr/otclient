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

#include <nlohmann/json.hpp>
#include "lzma.h"
#include "gameconfig.h"
#include "game.h"
#include "thingtypemanager.h"
#include "framework/core/filestream.h"
#include "framework/core/resourcemanager.h"
#include "framework/graphics/apngloader.h"
#include "framework/graphics/image.h"
#include "framework/graphics/texturemanager.h"
#include "framework/util/crypt.h"

#ifdef FRAMEWORK_EDITOR
#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <cstring>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iterator>
#include <limits>
#include <map>
#include <optional>
#include <sstream>
#include <unordered_map>
#include <utility>
#include <vector>
#endif

 // warnings related to protobuf
    // https://android.googlesource.com/platform/external/protobuf/+/brillo-m9-dev/vsprojects/readme.txt

using json = nlohmann::json;

SpriteAppearances g_spriteAppearances;

#ifdef FRAMEWORK_EDITOR
namespace {

uint32_t readU32(const std::vector<uint8_t>& data, size_t offset);

struct SpriteSheetLzmaHeader {
    size_t payloadOffset{ 0 };
    size_t compressedSizeOffset{ 0 };
    uint32_t dictionarySize{ 0 };
    uint8_t lc{ 0 };
    uint8_t lp{ 0 };
    uint8_t pb{ 0 };
};

bool isPathWithin(const std::filesystem::path& root, const std::filesystem::path& path)
{
    const auto relative = path.lexically_relative(root);
    return !relative.empty() && relative != "." && !relative.is_absolute() &&
           *relative.begin() != "..";
}

void ensureNoSymlinkPath(const std::filesystem::path& root, const std::filesystem::path& target)
{
    const auto relative = target.lexically_relative(root);
    if (relative.empty() || relative.is_absolute() || *relative.begin() == "..")
        throw stdext::exception("sprite editor path is outside the writable directory");

    auto current = root;
    for (const auto& part : relative) {
        current /= part;
        std::error_code error;
        const auto status = std::filesystem::symlink_status(current, error);
        if (error == std::errc::no_such_file_or_directory)
            continue;
        if (error)
            throw stdext::exception("unable to validate sprite editor path: {}", error.message());
        if (std::filesystem::is_symlink(status))
            throw stdext::exception("sprite editor work copies cannot contain symbolic links");
    }
}

void validateAssetDirectory(const std::filesystem::path& root)
{
    for (const auto& entry : std::filesystem::recursive_directory_iterator(root)) {
        const auto status = entry.symlink_status();
        if (std::filesystem::is_symlink(status))
            throw stdext::exception("sprite asset copies do not support symbolic links");
        if (!std::filesystem::is_directory(status) && !std::filesystem::is_regular_file(status))
            throw stdext::exception("sprite asset package contains an unsupported file type");
    }
}

std::filesystem::path safeAssetPath(const std::string& file)
{
    auto relative = std::filesystem::path(file);
    relative.make_preferred();
    relative = relative.lexically_normal();
    if (relative.empty() || relative.is_absolute() || relative.has_root_name() || relative.has_root_directory())
        throw stdext::exception("invalid sprite sheet path");

    for (const auto& part : relative) {
        if (part == ".." || part == ".")
            throw stdext::exception("invalid sprite sheet path");
    }
    return relative;
}

std::filesystem::path getEditorCatalogPath(const int version)
{
    if (version < 1500 || version >= 1600)
        throw stdext::exception("the sprite editor supports only client versions 15.x");

    const auto writeRoot = std::filesystem::weakly_canonical(std::filesystem::path(g_resources.getWriteDir()));
    const auto package = writeRoot / "sprite-editor" / "data" / "things" / std::to_string(version);
    const auto catalog = std::filesystem::path(g_resources.getRealPath(
        fmt::format("/data/things/{}/catalog-content.json", version))).lexically_normal();
    ensureNoSymlinkPath(writeRoot, package);
    ensureNoSymlinkPath(package, catalog);
    if (!isPathWithin(package, catalog) || !std::filesystem::is_regular_file(catalog) ||
        std::filesystem::weakly_canonical(catalog.parent_path()) != std::filesystem::weakly_canonical(package))
        throw stdext::exception("sprite editing is allowed only inside the active work copy");
    return catalog;
}

std::filesystem::path getEditorWorkPackagePath(const int version)
{
    if (version < 1500 || version >= 1600)
        throw stdext::exception("the sprite editor supports only client versions 15.x");

    const std::filesystem::path writeDirectory(g_resources.getWriteDir());
    if (writeDirectory.empty())
        throw stdext::exception("the client has no writable user directory");

    const auto normalizedWriteDirectory = std::filesystem::weakly_canonical(writeDirectory);
    const auto package = normalizedWriteDirectory / "sprite-editor" / "data" / "things" / std::to_string(version);
    ensureNoSymlinkPath(normalizedWriteDirectory, package);
    return package;
}

std::filesystem::path getEditorAssetHistoryPath(const int version)
{
    namespace fs = std::filesystem;
    const auto catalog = getEditorCatalogPath(version);
    const auto package = getEditorWorkPackagePath(version);
    const auto history = package / "asset-editor-history.json";
    ensureNoSymlinkPath(package, history);
    if (!fs::is_regular_file(catalog) || fs::weakly_canonical(catalog.parent_path()) != fs::weakly_canonical(package))
        throw stdext::exception("asset edit history is available only inside the active work copy");
    return history;
}

std::string getUtcTimestamp()
{
    const auto now = std::chrono::system_clock::now();
    const auto time = std::chrono::system_clock::to_time_t(now);
    std::tm utc{};
#ifdef _WIN32
    gmtime_s(&utc, &time);
#else
    gmtime_r(&time, &utc);
#endif
    std::ostringstream timestamp;
    timestamp << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");
    return timestamp.str();
}

std::string readSmallFile(const std::filesystem::path& path, const size_t maximumSize)
{
    const auto size = std::filesystem::file_size(path);
    if (size > maximumSize)
        throw stdext::exception("asset edit history file is larger than the supported limit");
    std::ifstream file(path, std::ios::binary);
    if (!file)
        throw stdext::exception("unable to read asset edit history");
    return std::string(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
}

std::optional<std::filesystem::path> findInstalledAssetPackageIfPresent(
    const int version, const std::filesystem::path& workPackage)
{
    namespace fs = std::filesystem;
    std::error_code error;
    const auto normalizedWorkPackage = fs::weakly_canonical(workPackage, error);
    if (error)
        throw stdext::exception("unable to resolve the sprite editor work copy: {}", error.message());

    const auto inspectPackage = [&](const fs::path& assetRoot, const fs::path& package)
        -> std::optional<fs::path> {
        const auto catalog = package / "catalog-content.json";
        const auto packageStatus = fs::symlink_status(package, error);
        if (error == std::errc::no_such_file_or_directory) {
            error.clear();
            return std::nullopt;
        }
        if (error)
            throw stdext::exception("unable to inspect installed assets for client version {}: {}", version, error.message());
        if (fs::is_symlink(packageStatus))
            throw stdext::exception("installed asset catalogs cannot be symbolic links");
        if (!fs::is_directory(packageStatus))
            return std::nullopt;

        ensureNoSymlinkPath(assetRoot, package);
        const auto installedPackage = fs::weakly_canonical(package, error);
        if (error)
            throw stdext::exception("unable to resolve installed assets: {}", error.message());
        if (installedPackage == normalizedWorkPackage)
            return std::nullopt;

        const auto catalogStatus = fs::symlink_status(catalog, error);
        if (error == std::errc::no_such_file_or_directory)
            throw stdext::exception("installed assets for client version {} are incomplete: catalog-content.json is missing", version);
        if (error)
            throw stdext::exception("unable to inspect installed assets for client version {}: {}", version, error.message());
        if (fs::is_symlink(catalogStatus))
            throw stdext::exception("installed asset catalogs cannot be symbolic links");
        if (!fs::is_regular_file(catalogStatus))
            throw stdext::exception("installed assets for client version {} are incomplete: catalog-content.json is missing", version);

        validateAssetDirectory(installedPackage);
        return installedPackage;
    };

    const auto resolvedCatalog = fs::path(g_resources.getRealPath(
        fmt::format("/data/things/{}/catalog-content.json", version)));
    if (fs::is_regular_file(resolvedCatalog)) {
        const auto resolvedPackage = resolvedCatalog.parent_path();
        const auto resolvedRoot = resolvedPackage.parent_path().parent_path().parent_path();
        if (const auto installedPackage = inspectPackage(resolvedRoot, resolvedPackage))
            return installedPackage;
    }

    const fs::path workDirectory(g_resources.getWorkDir());
    const fs::path writeDirectory(g_resources.getWriteDir());
    std::vector<fs::path> searchRoots;
    bool workDirectoryAdded = false;
    bool writeDirectoryAdded = false;
    for (const auto& searchRoot : g_resources.getSearchPaths()) {
        const fs::path root(searchRoot);
        if (!workDirectoryAdded && !writeDirectory.empty() && root.lexically_normal() == writeDirectory.lexically_normal()) {
            searchRoots.push_back(workDirectory);
            workDirectoryAdded = true;
        }
        searchRoots.push_back(root);
        if (!writeDirectory.empty() && root.lexically_normal() == writeDirectory.lexically_normal())
            writeDirectoryAdded = true;
    }
    if (!workDirectoryAdded && !workDirectory.empty())
        searchRoots.push_back(workDirectory);
    if (!writeDirectoryAdded && !writeDirectory.empty())
        searchRoots.push_back(writeDirectory);

    for (const auto& assetRoot : searchRoots) {
        const auto package = assetRoot / "data" / "things" / std::to_string(version);
        if (const auto installedPackage = inspectPackage(assetRoot, package))
            return installedPackage;
    }
    return std::nullopt;
}

std::filesystem::path findInstalledAssetPackage(const int version, const std::filesystem::path& workPackage)
{
    const auto installedPackage = findInstalledAssetPackageIfPresent(version, workPackage);
    if (!installedPackage)
        throw stdext::exception("installed assets for client version {} were not found", version);
    return *installedPackage;
}

void verifyAssetCopy(const std::filesystem::path& source, const std::filesystem::path& copy)
{
    namespace fs = std::filesystem;
    const auto sourceCatalog = source / "catalog-content.json";
    const auto copiedCatalog = copy / "catalog-content.json";
    if (!fs::is_regular_file(copiedCatalog) || fs::file_size(sourceCatalog) != fs::file_size(copiedCatalog))
        throw stdext::exception("sprite editor asset copy verification failed");
    validateAssetDirectory(copy);
}

struct WorkCopyHistoryEntry {
    std::filesystem::path snapshot;
    std::string label;
};

struct WorkCopyHistory {
    std::vector<WorkCopyHistoryEntry> undo;
    std::vector<WorkCopyHistoryEntry> redo;
    std::filesystem::path pending;
};

std::unordered_map<int, WorkCopyHistory> workCopyHistory;
uint64_t workCopyHistoryCounter = 0;
constexpr size_t MAX_WORK_COPY_HISTORY = 20;

std::filesystem::path getWorkCopyHistoryPath(const int version)
{
    const std::filesystem::path writeDirectory(g_resources.getWriteDir());
    if (writeDirectory.empty())
        throw stdext::exception("the client has no writable user directory");

    const auto normalizedWriteDirectory = std::filesystem::weakly_canonical(writeDirectory);
    const auto historyPath = normalizedWriteDirectory / "sprite-editor" / "history" / std::to_string(version);
    ensureNoSymlinkPath(normalizedWriteDirectory, historyPath);
    return historyPath;
}

std::filesystem::path createWorkCopySnapshot(const int version, const std::filesystem::path& source,
                                             const std::string& purpose)
{
    namespace fs = std::filesystem;
    const auto historyRoot = getWorkCopyHistoryPath(version);
    std::error_code error;
    fs::create_directories(historyRoot, error);
    if (error)
        throw stdext::exception("unable to create the work copy history folder: {}", error.message());

    const auto snapshot = historyRoot / fmt::format("{}-{}", purpose, ++workCopyHistoryCounter);
    ensureNoSymlinkPath(historyRoot, snapshot);
    fs::create_directory(snapshot, error);
    if (error)
        throw stdext::exception("unable to create a work copy history snapshot: {}", error.message());

    try {
        for (const auto& entry : fs::recursive_directory_iterator(source)) {
            const auto status = entry.symlink_status();
            if (fs::is_symlink(status))
                throw stdext::exception("work copy history does not support symbolic links");
            if (!fs::is_directory(status) && !fs::is_regular_file(status))
                throw stdext::exception("work copy history does not support this asset file type");

            const auto relative = entry.path().lexically_relative(source);
            const auto target = snapshot / relative;
            ensureNoSymlinkPath(snapshot, target);
            if (fs::is_directory(status)) {
                fs::create_directories(target, error);
                if (error)
                    throw stdext::exception("unable to create a history snapshot folder: {}", error.message());
            } else if (fs::is_regular_file(status)) {
                fs::create_directories(target.parent_path(), error);
                if (error)
                    throw stdext::exception("unable to create a history snapshot folder: {}", error.message());
                // Asset editors replace files atomically, so these links retain the pre-edit file contents.
                fs::create_hard_link(entry.path(), target, error);
                if (error) {
                    error.clear();
                    fs::copy_file(entry.path(), target, fs::copy_options::none, error);
                    if (error)
                        throw stdext::exception("unable to preserve a work copy history file: {}", error.message());
                }
            }
        }
    } catch (...) {
        fs::remove_all(snapshot, error);
        throw;
    }
    return snapshot;
}

using AssetFiles = std::map<std::string, std::filesystem::path>;

AssetFiles collectAssetFiles(const std::filesystem::path& root)
{
    namespace fs = std::filesystem;
    AssetFiles files;
    for (const auto& entry : fs::recursive_directory_iterator(root)) {
        const auto status = entry.symlink_status();
        if (fs::is_symlink(status))
            throw stdext::exception("work copy history does not support symbolic links");
        if (fs::is_directory(status))
            continue;
        if (!fs::is_regular_file(status))
            throw stdext::exception("work copy history does not support this asset file type");
        files.emplace(entry.path().lexically_relative(root).generic_string(), entry.path());
    }
    return files;
}

bool areFilesEqual(const std::filesystem::path& left, const std::filesystem::path& right)
{
    namespace fs = std::filesystem;
    std::error_code error;
    if (fs::equivalent(left, right, error) && !error)
        return true;
    if (error)
        error.clear();
    const auto leftSize = fs::file_size(left, error);
    if (error)
        return false;
    const auto rightSize = fs::file_size(right, error);
    if (error || leftSize != rightSize)
        return false;

    std::ifstream leftStream(left, std::ios::binary);
    std::ifstream rightStream(right, std::ios::binary);
    if (!leftStream || !rightStream)
        throw stdext::exception("unable to compare work copy history files");
    std::array<char, 65536> leftBuffer{};
    std::array<char, 65536> rightBuffer{};
    do {
        leftStream.read(leftBuffer.data(), static_cast<std::streamsize>(leftBuffer.size()));
        rightStream.read(rightBuffer.data(), static_cast<std::streamsize>(rightBuffer.size()));
        if (leftStream.gcount() != rightStream.gcount() ||
            !std::equal(leftBuffer.begin(), leftBuffer.begin() + leftStream.gcount(), rightBuffer.begin()))
            return false;
    } while (leftStream && rightStream);
    return leftStream.eof() && rightStream.eof();
}

bool areAssetStatesEqual(const std::filesystem::path& left, const std::filesystem::path& right)
{
    const auto leftFiles = collectAssetFiles(left);
    const auto rightFiles = collectAssetFiles(right);
    if (leftFiles.size() != rightFiles.size())
        return false;
    for (const auto& [relative, leftPath] : leftFiles) {
        const auto it = rightFiles.find(relative);
        if (it == rightFiles.end() || !areFilesEqual(leftPath, it->second))
            return false;
    }
    return true;
}

void replaceFileFromSnapshot(const std::filesystem::path& source, const std::filesystem::path& target)
{
    namespace fs = std::filesystem;
    auto temporary = target;
    temporary += ".sprite-editor-undo.tmp";
    auto backup = target;
    backup += ".sprite-editor-undo.bak";
    std::error_code error;
    for (const auto& candidate : { temporary, backup }) {
        const auto status = fs::symlink_status(candidate, error);
        if (!error && fs::exists(status))
            throw stdext::exception("a previous work copy undo was interrupted; inspect '{}'", candidate.generic_string());
        if (error == std::errc::no_such_file_or_directory)
            error.clear();
        else if (error)
            throw stdext::exception("unable to validate a work copy undo path: {}", error.message());
    }

    fs::copy_file(source, temporary, fs::copy_options::none, error);
    if (error)
        throw stdext::exception("unable to stage a work copy undo file: {}", error.message());
    const bool hadTarget = fs::exists(target, error);
    if (error) {
        fs::remove(temporary, error);
        throw stdext::exception("unable to inspect a work copy undo target: {}", error.message());
    }
    if (hadTarget) {
        fs::rename(target, backup, error);
        if (error) {
            fs::remove(temporary, error);
            throw stdext::exception("unable to preserve a work copy file before undo: {}", error.message());
        }
    }
    fs::rename(temporary, target, error);
    if (error) {
        if (hadTarget) {
            std::error_code rollbackError;
            fs::rename(backup, target, rollbackError);
        }
        fs::remove(temporary, error);
        throw stdext::exception("unable to apply a work copy undo file: {}", error.message());
    }
    if (hadTarget)
        fs::remove(backup, error);
}

void restoreWorkCopySnapshot(const std::filesystem::path& snapshot, const std::filesystem::path& package)
{
    namespace fs = std::filesystem;
    const auto snapshotFiles = collectAssetFiles(snapshot);
    const auto packageFiles = collectAssetFiles(package);
    std::error_code error;

    for (const auto& [relative, currentPath] : packageFiles) {
        if (snapshotFiles.find(relative) != snapshotFiles.end())
            continue;
        fs::remove(currentPath, error);
        if (error)
            throw stdext::exception("unable to remove a work copy file during undo: {}", error.message());
    }
    for (const auto& [relative, snapshotPath] : snapshotFiles) {
        const auto target = package / fs::path(relative);
        ensureNoSymlinkPath(package, target);
        fs::create_directories(target.parent_path(), error);
        if (error)
            throw stdext::exception("unable to restore a work copy folder: {}", error.message());
        const auto current = packageFiles.find(relative);
        if (current != packageFiles.end() && areFilesEqual(current->second, snapshotPath))
            continue;
        replaceFileFromSnapshot(snapshotPath, target);
    }

    std::vector<fs::path> directories;
    for (const auto& entry : fs::recursive_directory_iterator(package)) {
        if (entry.is_directory())
            directories.push_back(entry.path());
    }
    std::sort(directories.begin(), directories.end(), [](const fs::path& left, const fs::path& right) {
        return std::distance(left.begin(), left.end()) > std::distance(right.begin(), right.end());
    });
    for (const auto& directory : directories) {
        fs::remove(directory, error);
        error.clear();
    }
}

void removeHistorySnapshot(const std::filesystem::path& snapshot)
{
    std::error_code error;
    std::filesystem::remove_all(snapshot, error);
}

void clearHistoryWorkCopy(const int version)
{
    const auto historyPath = getWorkCopyHistoryPath(version);
    std::error_code error;
    const auto status = std::filesystem::symlink_status(historyPath, error);
    if (!error && std::filesystem::exists(status)) {
        ensureNoSymlinkPath(historyPath.parent_path().parent_path().parent_path(), historyPath);
        std::filesystem::remove_all(historyPath, error);
        if (error)
            throw stdext::exception("unable to clear stale work copy history: {}", error.message());
    } else if (error != std::errc::no_such_file_or_directory && error) {
        throw stdext::exception("unable to inspect work copy history: {}", error.message());
    }
    workCopyHistory.erase(version);
}

ImagePtr loadPreparedSprite(const std::string& fileName, const Size& expectedSize = Size(32, 32))
{
    const std::filesystem::path source(fileName);
    if (fileName.empty() || !source.is_absolute())
        throw stdext::exception("enter an absolute PNG file path");

    auto extension = source.extension().string();
    std::ranges::transform(extension, extension.begin(), [](const unsigned char value) {
        return static_cast<char>(std::tolower(value));
    });
    if (extension != ".png")
        throw stdext::exception("prepared sprites must be PNG files");

    std::error_code error;
    if (!std::filesystem::is_regular_file(source, error) || error)
        throw stdext::exception("the selected PNG file does not exist");
    const auto fileSize = std::filesystem::file_size(source, error);
    if (error || fileSize < 24 || fileSize > 4 * 1024 * 1024)
        throw stdext::exception("the selected PNG file has an unsupported size");

    std::ifstream stream(source, std::ios::binary);
    if (!stream)
        throw stdext::exception("unable to open the selected PNG file");
    const std::string contents(std::istreambuf_iterator<char>(stream), {});
    static constexpr std::array<uint8_t, 8> pngSignature = { 137, 80, 78, 71, 13, 10, 26, 10 };
    if (contents.size() != fileSize || !std::equal(pngSignature.begin(), pngSignature.end(), contents.begin(),
            [](const uint8_t expected, const char actual) { return expected == static_cast<uint8_t>(actual); }) ||
        contents.compare(12, 4, "IHDR") != 0)
        throw stdext::exception("the selected file is not a valid PNG image");

    const auto readBigEndianU32 = [&](const size_t offset) {
        return (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset])) << 24) |
               (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 1])) << 16) |
               (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 2])) << 8) |
               static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 3]));
    };
    const Size pngSize(readBigEndianU32(16), readBigEndianU32(20));
    if (pngSize.width() < 1 || pngSize.height() < 1 ||
        pngSize.width() > SpriteSheet::SIZE || pngSize.height() > SpriteSheet::SIZE)
        throw stdext::exception("prepared sprite PNG dimensions must be between 1 and 384 pixels");
    if (expectedSize.width() > 0 && expectedSize.height() > 0 && pngSize != expectedSize)
        throw stdext::exception("prepared PNG dimensions must match the selected sprite");

    const auto image = Image::loadPNG(contents.data(), contents.size());
    if (!image || image->getBpp() != 4 || image->getSize() != pngSize)
        throw stdext::exception("the selected PNG could not be decoded as an RGBA sprite");
    return image;
}

ImagePtr loadPreparedSpriteSheet(const std::string& fileName)
{
    const std::filesystem::path source(fileName);
    if (fileName.empty() || !source.is_absolute())
        throw stdext::exception("enter an absolute PNG file path");

    auto extension = source.extension().string();
    std::ranges::transform(extension, extension.begin(), [](const unsigned char value) {
        return static_cast<char>(std::tolower(value));
    });
    if (extension != ".png")
        throw stdext::exception("sprite sheets must be PNG files");

    std::error_code error;
    if (!std::filesystem::is_regular_file(source, error) || error)
        throw stdext::exception("the selected PNG file does not exist");
    const auto fileSize = std::filesystem::file_size(source, error);
    if (error || fileSize < 24 || fileSize > 32 * 1024 * 1024)
        throw stdext::exception("the selected sprite sheet has an unsupported file size");

    std::ifstream stream(source, std::ios::binary);
    if (!stream)
        throw stdext::exception("unable to open the selected sprite sheet");
    const std::string contents(std::istreambuf_iterator<char>(stream), {});
    static constexpr std::array<uint8_t, 8> pngSignature = { 137, 80, 78, 71, 13, 10, 26, 10 };
    if (contents.size() != fileSize || !std::equal(pngSignature.begin(), pngSignature.end(), contents.begin(),
            [](const uint8_t expected, const char actual) { return expected == static_cast<uint8_t>(actual); }) ||
        contents.compare(12, 4, "IHDR") != 0)
        throw stdext::exception("the selected file is not a valid PNG image");

    const auto readBigEndianU32 = [&](const size_t offset) {
        return (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset])) << 24) |
               (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 1])) << 16) |
               (static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 2])) << 8) |
               static_cast<uint32_t>(static_cast<uint8_t>(contents[offset + 3]));
    };
    const Size pngSize(readBigEndianU32(16), readBigEndianU32(20));
    if (pngSize.width() < 1 || pngSize.height() < 1 || pngSize.width() > 4096 || pngSize.height() > 4096 ||
        pngSize.area() > 16 * 1024 * 1024)
        throw stdext::exception("sprite sheet dimensions must not exceed 4096 x 4096 pixels");

    for (size_t offset = 8; offset + 12 <= contents.size();) {
        const auto chunkLength = readBigEndianU32(offset);
        if (chunkLength > contents.size() - offset - 12)
            throw stdext::exception("the PNG contains an invalid chunk length");
        if (contents.compare(offset + 4, 4, "acTL") == 0)
            throw stdext::exception("animated PNG files are not supported as sprite sheets");
        if (contents.compare(offset + 4, 4, "IEND") == 0)
            break;
        offset += static_cast<size_t>(chunkLength) + 12;
    }

    const auto image = Image::loadPNG(contents.data(), contents.size());
    if (!image || image->getBpp() != 4 || image->getSize() != pngSize || image->isAnimated())
        throw stdext::exception("the selected PNG could not be decoded as a static RGBA sprite sheet");
    return image;
}

SpriteLayout getSpriteLayout(const Size& spriteSize)
{
    const auto firstLayout = static_cast<int>(SpriteLayout::SIZE_32_32);
    const auto lastLayout = static_cast<int>(SpriteLayout::SIZE_384_384);
    for (int value = firstLayout; value <= lastLayout; ++value) {
        const auto layout = static_cast<SpriteLayout>(value);
        if (SpriteSheet(0, 0, layout, {}).getSpriteSize() == spriteSize)
            return layout;
    }

    throw stdext::exception("new sprite PNG dimensions must match a supported sprite size (32, 64, 96, 128, 192, or 384 pixels per side)");
}

uint32_t validateSpriteSheetBitmap(const std::vector<uint8_t>& bitmap)
{
    if (bitmap.size() < 54 || bitmap[0] != 'B' || bitmap[1] != 'M')
        throw stdext::exception("sprite sheet does not contain a Windows bitmap");
    const uint32_t bitmapOffset = readU32(bitmap, 10);
    const uint32_t bitmapWidth = readU32(bitmap, 18);
    const uint32_t bitmapHeight = readU32(bitmap, 22);
    const uint16_t bitmapPlanes = static_cast<uint16_t>(bitmap[26] | (bitmap[27] << 8));
    const uint16_t bitmapBitsPerPixel = static_cast<uint16_t>(bitmap[28] | (bitmap[29] << 8));
    const uint32_t bitmapCompression = readU32(bitmap, 30);
    if (bitmapWidth != SpriteSheet::SIZE || bitmapHeight != SpriteSheet::SIZE ||
        bitmapPlanes != 1 || bitmapBitsPerPixel != 32 || bitmapCompression != 3 ||
        bitmapOffset < 54 || bitmapOffset > bitmap.size() ||
        BYTES_IN_SPRITE_SHEET > bitmap.size() - bitmapOffset)
        throw stdext::exception("sprite sheet bitmap format or pixel offset is unsupported");
    return bitmapOffset;
}

void writeSpritePixels(std::vector<uint8_t>& bitmap, const uint32_t bitmapOffset,
                       const int spriteIndex, const Size& spriteSize, const ImagePtr& image)
{
    const int spritesPerRow = SpriteSheet::SIZE / spriteSize.width();
    const int originX = (spriteIndex % spritesPerRow) * spriteSize.width();
    const int originY = (spriteIndex / spritesPerRow) * spriteSize.height();
    const auto& pixels = image->getPixels();
    for (int y = 0; y < spriteSize.height(); ++y) {
        for (int x = 0; x < spriteSize.width(); ++x) {
            const size_t imageOffset = static_cast<size_t>(y * spriteSize.width() + x) * 4;
            const int sheetX = originX + x;
            const int sheetY = SpriteSheet::SIZE - 1 - (originY + y);
            const size_t bitmapPixelOffset = bitmapOffset +
                static_cast<size_t>(sheetY * SpriteSheet::SIZE + sheetX) * 4;
            if (pixels[imageOffset + 3] == 0) {
                bitmap[bitmapPixelOffset + 0] = 0xff;
                bitmap[bitmapPixelOffset + 1] = 0x00;
                bitmap[bitmapPixelOffset + 2] = 0xff;
                bitmap[bitmapPixelOffset + 3] = 0x00;
            } else {
                bitmap[bitmapPixelOffset + 0] = pixels[imageOffset + 2];
                bitmap[bitmapPixelOffset + 1] = pixels[imageOffset + 1];
                bitmap[bitmapPixelOffset + 2] = pixels[imageOffset + 0];
                bitmap[bitmapPixelOffset + 3] = 0xff;
            }
        }
    }
}

std::vector<uint8_t> readBinaryFile(const std::filesystem::path& path)
{
    std::ifstream stream(path, std::ios::binary);
    if (!stream)
        throw stdext::exception("unable to read sprite sheet file");
    return std::vector<uint8_t>(std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>());
}

uint32_t readU32(const std::vector<uint8_t>& data, const size_t offset)
{
    if (offset + 4 > data.size())
        throw stdext::exception("sprite sheet header is truncated");
    return static_cast<uint32_t>(data[offset]) |
           (static_cast<uint32_t>(data[offset + 1]) << 8) |
           (static_cast<uint32_t>(data[offset + 2]) << 16) |
           (static_cast<uint32_t>(data[offset + 3]) << 24);
}

uint64_t readU64(const std::vector<uint8_t>& data, const size_t offset)
{
    if (offset + 8 > data.size())
        throw stdext::exception("sprite sheet header is truncated");

    uint64_t value = 0;
    for (size_t i = 0; i < 8; ++i)
        value |= static_cast<uint64_t>(data[offset + i]) << (i * 8);
    return value;
}

void writeU64(std::vector<uint8_t>& data, const size_t offset, const uint64_t value)
{
    if (offset + 8 > data.size())
        throw stdext::exception("sprite sheet header is truncated");

    for (size_t i = 0; i < 8; ++i)
        data[offset + i] = static_cast<uint8_t>((value >> (i * 8)) & 0xff);
}

SpriteSheetLzmaHeader readSpriteSheetHeader(const std::vector<uint8_t>& data)
{
    size_t markerOffset = 0;
    while (markerOffset < data.size() && data[markerOffset] == 0)
        ++markerOffset;

    static constexpr std::array<uint8_t, 5> marker = { 0x70, 0x0a, 0xfa, 0x80, 0x24 };
    if (markerOffset + marker.size() > data.size() ||
        !std::equal(marker.begin(), marker.end(), data.begin() + markerOffset))
        throw stdext::exception("unsupported sprite sheet LZMA header");

    size_t position = markerOffset + marker.size();
    size_t varintBytes = 0;
    while (position < data.size() && (data[position++] & 0x80) != 0) {
        if (++varintBytes > 9)
            throw stdext::exception("invalid sprite sheet LZMA header");
    }
    if (position >= data.size())
        throw stdext::exception("sprite sheet LZMA properties are missing");

    const uint8_t properties = data[position++];
    SpriteSheetLzmaHeader header;
    header.lc = properties % 9;
    const uint8_t remainder = properties / 9;
    header.lp = remainder % 5;
    header.pb = remainder / 5;
    if (header.lc > 8 || header.lp > 4 || header.pb > 4 || header.lc + header.lp > 4)
        throw stdext::exception("invalid sprite sheet LZMA properties");
    header.dictionarySize = readU32(data, position);
    if (header.dictionarySize == 0 || header.dictionarySize > 64 * 1024 * 1024)
        throw stdext::exception("unsupported sprite sheet LZMA dictionary size");
    position += 4;
    header.compressedSizeOffset = position;
    position += 8;
    header.payloadOffset = position;

    if (header.payloadOffset > data.size() ||
        readU64(data, header.compressedSizeOffset) != data.size() - header.payloadOffset)
        throw stdext::exception("sprite sheet compressed size does not match its file");
    return header;
}

std::vector<uint8_t> decompressSpriteSheet(const std::vector<uint8_t>& data,
                                          const SpriteSheetLzmaHeader& header)
{
    std::vector<uint8_t> output(LZMA_UNCOMPRESSED_SIZE);
    lzma_options_lzma options{};
    options.lc = header.lc;
    options.lp = header.lp;
    options.pb = header.pb;
    options.dict_size = header.dictionarySize;

    const lzma_filter filters[2] = {
        lzma_filter{ LZMA_FILTER_LZMA1, &options },
        lzma_filter{ LZMA_VLI_UNKNOWN, nullptr }
    };
    lzma_stream stream = LZMA_STREAM_INIT;
    if (lzma_raw_decoder(&stream, filters) != LZMA_OK)
        throw stdext::exception("failed to initialize sprite sheet LZMA decoder");

    stream.next_in = data.data() + header.payloadOffset;
    stream.avail_in = data.size() - header.payloadOffset;
    stream.next_out = output.data();
    stream.avail_out = output.size();
    const lzma_ret result = lzma_code(&stream, LZMA_RUN);
    const size_t outputSize = output.size() - stream.avail_out;
    const size_t remainingInput = stream.avail_in;
    lzma_end(&stream);

    if (result != LZMA_STREAM_END || outputSize != LZMA_UNCOMPRESSED_SIZE || remainingInput != 0)
        throw stdext::exception("sprite sheet LZMA decompression failed validation");
    return output;
}

std::vector<uint8_t> compressSpriteSheet(const std::vector<uint8_t>& input,
                                         const SpriteSheetLzmaHeader& header,
                                         const std::vector<uint8_t>& original)
{
    lzma_options_lzma options{};
    if (lzma_lzma_preset(&options, 6))
        throw stdext::exception("failed to initialize sprite sheet LZMA encoder");
    options.lc = header.lc;
    options.lp = header.lp;
    options.pb = header.pb;
    options.dict_size = header.dictionarySize;

    const lzma_filter filters[2] = {
        lzma_filter{ LZMA_FILTER_LZMA1, &options },
        lzma_filter{ LZMA_VLI_UNKNOWN, nullptr }
    };
    lzma_stream stream = LZMA_STREAM_INIT;
    if (lzma_raw_encoder(&stream, filters) != LZMA_OK)
        throw stdext::exception("failed to initialize sprite sheet LZMA encoder");

    stream.next_in = input.data();
    stream.avail_in = input.size();
    std::array<uint8_t, 65536> outputBuffer{};
    std::vector<uint8_t> compressed;
    lzma_ret result = LZMA_OK;
    while (result != LZMA_STREAM_END) {
        stream.next_out = outputBuffer.data();
        stream.avail_out = outputBuffer.size();
        result = lzma_code(&stream, LZMA_FINISH);
        if (result != LZMA_OK && result != LZMA_STREAM_END) {
            lzma_end(&stream);
            throw stdext::exception("sprite sheet LZMA compression failed");
        }
        const size_t bytesWritten = outputBuffer.size() - stream.avail_out;
        compressed.insert(compressed.end(), outputBuffer.begin(), outputBuffer.begin() + bytesWritten);
    }
    lzma_end(&stream);

    std::vector<uint8_t> resultData(original.begin(), original.begin() + header.payloadOffset);
    writeU64(resultData, header.compressedSizeOffset, compressed.size());
    resultData.insert(resultData.end(), compressed.begin(), compressed.end());

    const auto decoded = decompressSpriteSheet(resultData, header);
    if (decoded != input)
        throw stdext::exception("sprite sheet output failed round-trip validation");
    return resultData;
}

void writeFileAtomically(const std::filesystem::path& target, const std::vector<uint8_t>& contents)
{
    auto temporary = target;
    temporary += ".sprite-editor.tmp";
    auto backup = target;
    backup += ".sprite-editor.bak";

    std::error_code error;
    for (const auto& candidate : { temporary, backup }) {
        const auto status = std::filesystem::symlink_status(candidate, error);
        if (!error && std::filesystem::is_symlink(status))
            throw stdext::exception("sprite asset work copy contains an unsafe temporary path");
        if (error == std::errc::no_such_file_or_directory)
            error.clear();
        else if (error)
            throw stdext::exception("unable to validate sprite asset temporary path: {}", error.message());
    }
    if (std::filesystem::exists(backup, error)) {
        if (!std::filesystem::exists(target, error))
            std::filesystem::rename(backup, target);
        else
            std::filesystem::remove(backup, error);
    }
    std::filesystem::remove(temporary, error);

    {
        std::ofstream file(temporary, std::ios::binary | std::ios::trunc);
        if (!file)
            throw stdext::exception("unable to create temporary sprite sheet file");
        file.write(reinterpret_cast<const char*>(contents.data()), static_cast<std::streamsize>(contents.size()));
        file.flush();
        if (!file)
            throw stdext::exception("unable to write temporary sprite sheet file");
    }

    if (std::filesystem::exists(target))
        std::filesystem::rename(target, backup);

    try {
        std::filesystem::rename(temporary, target);
    } catch (...) {
        if (std::filesystem::exists(backup))
            std::filesystem::rename(backup, target);
        throw;
    }
    std::filesystem::remove(backup, error);
}

void copyAssetDirectory(const std::filesystem::path& source, const std::filesystem::path& destination)
{
    std::error_code error;
    std::filesystem::create_directories(destination, error);
    if (error)
        throw stdext::exception("unable to create sprite editor work copy: {}", error.message());

    for (const auto& entry : std::filesystem::recursive_directory_iterator(source)) {
        const auto status = entry.symlink_status();
        if (std::filesystem::is_symlink(status))
            throw stdext::exception("sprite asset copies do not support symbolic links");

        const auto relative = entry.path().lexically_relative(source);
        const auto target = destination / relative;
        if (std::filesystem::is_directory(status)) {
            std::filesystem::create_directories(target);
            continue;
        }
        if (!std::filesystem::is_regular_file(status))
            throw stdext::exception("sprite asset package contains an unsupported file type");

        std::filesystem::create_directories(target.parent_path());
        if (!std::filesystem::copy_file(entry.path(), target, std::filesystem::copy_options::none))
            throw stdext::exception("unable to copy sprite asset file");
        if (std::filesystem::file_size(entry.path()) != std::filesystem::file_size(target))
            throw stdext::exception("sprite asset copy verification failed");
    }
}

} // namespace
#endif

void SpriteAppearances::init()
{
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

std::string SpriteAppearances::getSpriteRanges() const
{
    json ranges = json::array();
    for (const auto& sheet : m_sheets)
        ranges.push_back({ sheet->firstId, sheet->lastId });
    return ranges.dump();
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

#ifdef FRAMEWORK_EDITOR
std::string SpriteAppearances::createWorkCopy(const int version)
{
    if (version < 1500 || version >= 1600)
        throw stdext::exception("the sprite editor supports only client versions 15.x");

    const std::filesystem::path writeDirectory(g_resources.getWriteDir());
    if (writeDirectory.empty())
        throw stdext::exception("the client has no writable user directory");
    const auto normalizedWriteDirectory = std::filesystem::weakly_canonical(writeDirectory);

    const auto virtualPackage = fmt::format("/data/things/{}/", version);
    const auto sourceCatalog = std::filesystem::path(g_resources.getRealPath(virtualPackage + "catalog-content.json")).lexically_normal();
    if (!std::filesystem::is_regular_file(sourceCatalog))
        throw stdext::exception("catalog-content.json was not found for client version {}", version);

    const auto sourcePackage = sourceCatalog.parent_path();
    const auto workRoot = normalizedWriteDirectory / "sprite-editor";
    const auto packagePath = workRoot / "data" / "things" / std::to_string(version);
    const auto copiedCatalog = packagePath / "catalog-content.json";
    ensureNoSymlinkPath(normalizedWriteDirectory, packagePath);
    if (workCopyHistory.find(version) == workCopyHistory.end())
        clearHistoryWorkCopy(version);

    if (std::filesystem::exists(packagePath)) {
        validateAssetDirectory(packagePath);
        if (!std::filesystem::is_regular_file(copiedCatalog) || std::filesystem::file_size(copiedCatalog) == 0)
            throw stdext::exception("the existing sprite editor work copy is incomplete; remove it before creating a new copy");
        return workRoot.generic_string();
    }

    if (std::filesystem::weakly_canonical(sourcePackage) == std::filesystem::weakly_canonical(packagePath))
        throw stdext::exception("the installed asset folder cannot be used as the work copy");

    std::filesystem::create_directories(packagePath.parent_path());
    auto temporaryPackage = packagePath;
    temporaryPackage += ".sprite-editor.tmp";
    std::error_code error;
    std::filesystem::remove_all(temporaryPackage, error);

    try {
        copyAssetDirectory(sourcePackage, temporaryPackage);
        const auto temporaryCatalog = temporaryPackage / "catalog-content.json";
        if (!std::filesystem::is_regular_file(temporaryCatalog) ||
            std::filesystem::file_size(sourceCatalog) != std::filesystem::file_size(temporaryCatalog))
            throw stdext::exception("sprite editor work copy verification failed");
        std::filesystem::rename(temporaryPackage, packagePath);
    } catch (...) {
        std::filesystem::remove_all(temporaryPackage, error);
        throw;
    }

    return workRoot.generic_string();
}

bool SpriteAppearances::workCopyExists(const int version)
{
    namespace fs = std::filesystem;
    const auto packagePath = getEditorWorkPackagePath(version);
    std::error_code error;
    const auto status = fs::symlink_status(packagePath, error);
    if (error == std::errc::no_such_file_or_directory)
        return false;
    if (error)
        throw stdext::exception("unable to inspect the sprite editor work copy: {}", error.message());
    if (fs::is_symlink(status))
        throw stdext::exception("sprite editor work copies cannot be symbolic links");
    if (!fs::is_directory(status))
        return false;

    validateAssetDirectory(packagePath);
    const auto catalog = packagePath / "catalog-content.json";
    if (!fs::is_regular_file(catalog) || fs::file_size(catalog) == 0)
        throw stdext::exception("the existing sprite editor work copy is incomplete");
    return true;
}

std::string SpriteAppearances::resetWorkCopy(const int version)
{
    namespace fs = std::filesystem;
    const fs::path writeDirectory(g_resources.getWriteDir());
    if (writeDirectory.empty())
        throw stdext::exception("the client has no writable user directory");

    const auto normalizedWriteDirectory = fs::weakly_canonical(writeDirectory);
    const auto packagePath = getEditorWorkPackagePath(version);
    const auto sourcePackage = findInstalledAssetPackage(version, packagePath);
    if (sourcePackage == fs::weakly_canonical(packagePath))
        throw stdext::exception("the installed asset folder cannot be used as the work copy");
    validateAssetDirectory(sourcePackage);

    const auto temporaryPackage = fs::path(packagePath.generic_string() + ".sprite-editor.reset.tmp");
    const auto previousPackage = fs::path(packagePath.generic_string() + ".sprite-editor.reset.bak");
    ensureNoSymlinkPath(normalizedWriteDirectory, temporaryPackage);
    ensureNoSymlinkPath(normalizedWriteDirectory, previousPackage);

    std::error_code error;
    for (const auto& stalePath : { temporaryPackage, previousPackage }) {
        const auto status = fs::symlink_status(stalePath, error);
        if (!error && fs::exists(status))
            throw stdext::exception("a previous work copy reset was interrupted; inspect '{}' before retrying", stalePath.generic_string());
        if (error == std::errc::no_such_file_or_directory)
            error.clear();
        else if (error)
            throw stdext::exception("unable to validate sprite editor reset path: {}", error.message());
    }

    fs::create_directories(packagePath.parent_path(), error);
    if (error)
        throw stdext::exception("unable to create sprite editor work copy folders: {}", error.message());

    try {
        copyAssetDirectory(sourcePackage, temporaryPackage);
        verifyAssetCopy(sourcePackage, temporaryPackage);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        throw;
    }

    bool movedPrevious = false;
    try {
        if (fs::exists(packagePath)) {
            validateAssetDirectory(packagePath);
            fs::rename(packagePath, previousPackage);
            movedPrevious = true;
        }
        fs::rename(temporaryPackage, packagePath);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        if (movedPrevious) {
            try {
                fs::rename(previousPackage, packagePath);
            } catch (const std::exception& rollbackError) {
                throw stdext::exception("work copy reset failed and the prior copy could not be restored; it remains at '{}': {}",
                    previousPackage.generic_string(), rollbackError.what());
            }
        }
        throw;
    }

    if (movedPrevious)
        fs::remove_all(previousPackage, error);
    try {
        clearHistoryWorkCopy(version);
    } catch (const std::exception& exception) {
        g_logger.warning("Unable to clear sprite editor history after resetting client version {}: {}",
                         version, exception.what());
    }
    return (normalizedWriteDirectory / "sprite-editor").generic_string();
}

std::string SpriteAppearances::getWorkCopyHistoryState(const int version)
{
    const auto it = workCopyHistory.find(version);
    const size_t undoCount = it == workCopyHistory.end() ? 0 : it->second.undo.size();
    const size_t redoCount = it == workCopyHistory.end() ? 0 : it->second.redo.size();
    return json({ { "undo", undoCount }, { "redo", redoCount } }).dump();
}

void SpriteAppearances::beginWorkCopyEdit(const int version)
{
    const auto package = getEditorWorkPackagePath(version);
    if (!std::filesystem::is_regular_file(package / "catalog-content.json"))
        throw stdext::exception("the selected sprite editor work copy is incomplete");
    validateAssetDirectory(package);

    auto& history = workCopyHistory[version];
    if (!history.pending.empty())
        throw stdext::exception("another work copy edit is already being recorded");
    history.pending = createWorkCopySnapshot(version, package, "pending");
}

bool SpriteAppearances::commitWorkCopyEdit(const int version, const std::string& label)
{
    auto it = workCopyHistory.find(version);
    if (it == workCopyHistory.end() || it->second.pending.empty())
        throw stdext::exception("there is no work copy edit to record");

    auto& history = it->second;
    const auto package = getEditorWorkPackagePath(version);
    const auto pending = history.pending;
    if (areAssetStatesEqual(pending, package)) {
        removeHistorySnapshot(pending);
        history.pending.clear();
        return false;
    }

    for (const auto& entry : history.redo)
        removeHistorySnapshot(entry.snapshot);
    history.redo.clear();
    history.undo.push_back({ pending, label.empty() ? "Edit assets" : label });
    history.pending.clear();
    while (history.undo.size() > MAX_WORK_COPY_HISTORY) {
        removeHistorySnapshot(history.undo.front().snapshot);
        history.undo.erase(history.undo.begin());
    }
    return true;
}

std::string SpriteAppearances::undoWorkCopyEdit(const int version)
{
    auto it = workCopyHistory.find(version);
    if (it == workCopyHistory.end() || it->second.undo.empty())
        return {};
    auto& history = it->second;
    if (!history.pending.empty())
        throw stdext::exception("finish the current work copy edit before undoing");

    const auto package = getEditorWorkPackagePath(version);
    const auto previous = history.undo.back();
    const auto redoSnapshot = createWorkCopySnapshot(version, package, "redo");
    try {
        restoreWorkCopySnapshot(previous.snapshot, package);
    } catch (...) {
        try {
            restoreWorkCopySnapshot(redoSnapshot, package);
        } catch (const std::exception& rollbackError) {
            throw stdext::exception("undo failed and the current work copy could not be restored: {}", rollbackError.what());
        }
        removeHistorySnapshot(redoSnapshot);
        throw;
    }

    history.undo.pop_back();
    history.redo.push_back(previous);
    removeHistorySnapshot(previous.snapshot);
    history.redo.back().snapshot = redoSnapshot;
    return previous.label;
}

std::string SpriteAppearances::redoWorkCopyEdit(const int version)
{
    auto it = workCopyHistory.find(version);
    if (it == workCopyHistory.end() || it->second.redo.empty())
        return {};
    auto& history = it->second;
    if (!history.pending.empty())
        throw stdext::exception("finish the current work copy edit before redoing");

    const auto package = getEditorWorkPackagePath(version);
    const auto next = history.redo.back();
    const auto undoSnapshot = createWorkCopySnapshot(version, package, "undo");
    try {
        restoreWorkCopySnapshot(next.snapshot, package);
    } catch (...) {
        try {
            restoreWorkCopySnapshot(undoSnapshot, package);
        } catch (const std::exception& rollbackError) {
            throw stdext::exception("redo failed and the current work copy could not be restored: {}", rollbackError.what());
        }
        removeHistorySnapshot(undoSnapshot);
        throw;
    }

    history.redo.pop_back();
    history.undo.push_back({ undoSnapshot, next.label });
    removeHistorySnapshot(next.snapshot);
    while (history.undo.size() > MAX_WORK_COPY_HISTORY) {
        removeHistorySnapshot(history.undo.front().snapshot);
        history.undo.erase(history.undo.begin());
    }
    return next.label;
}

std::string SpriteAppearances::getInstalledAssetBackups(const int version)
{
    namespace fs = std::filesystem;
    const auto workPackage = getEditorWorkPackagePath(version);
    const auto installedPackage = findInstalledAssetPackageIfPresent(version, workPackage);
    if (!installedPackage)
        return "[]";
    const auto thingsDirectory = installedPackage->parent_path();
    const auto backupDirectory = thingsDirectory / "backup";
    ensureNoSymlinkPath(thingsDirectory, backupDirectory);
    std::error_code error;
    if (!fs::exists(backupDirectory, error)) {
        if (error)
            throw stdext::exception("unable to inspect the Things backup folder: {}", error.message());
        return "[]";
    }
    if (!fs::is_directory(backupDirectory, error) || error)
        throw stdext::exception("the Things backup path is not a directory");

    const auto prefix = fmt::format("{}-", version);
    std::vector<std::string> backups;
    for (const auto& entry : fs::directory_iterator(backupDirectory)) {
        const auto name = entry.path().filename().string();
        if (!name.starts_with(prefix))
            continue;
        const auto status = entry.symlink_status();
        if (fs::is_symlink(status) || !fs::is_directory(status))
            continue;
        if (fs::is_regular_file(entry.path() / "catalog-content.json"))
            backups.push_back(name);
    }
    std::sort(backups.begin(), backups.end(), std::greater<>());
    return json(backups).dump();
}

std::string SpriteAppearances::getInstalledAssetBackupHistory(const int version, const std::string& backupName)
{
    namespace fs = std::filesystem;
    constexpr size_t MAX_HISTORY_FILE_SIZE = 32 * 1024 * 1024;
    if (backupName.empty() || fs::path(backupName).filename() != fs::path(backupName) ||
        !backupName.starts_with(fmt::format("{}-", version)))
        throw stdext::exception("choose a backup for the selected client assets version");

    const auto workPackage = getEditorWorkPackagePath(version);
    const auto installedPackage = findInstalledAssetPackage(version, workPackage);
    const auto thingsDirectory = installedPackage.parent_path();
    const auto backupDirectory = thingsDirectory / "backup";
    const auto selectedBackup = backupDirectory / backupName;
    ensureNoSymlinkPath(thingsDirectory, backupDirectory);
    ensureNoSymlinkPath(backupDirectory, selectedBackup);
    if (!fs::is_directory(selectedBackup) || !fs::is_regular_file(selectedBackup / "catalog-content.json"))
        throw stdext::exception("the selected asset backup is unavailable or incomplete");

    const auto path = selectedBackup / "asset-editor-history.json";
    ensureNoSymlinkPath(selectedBackup, path);
    std::error_code error;
    if (!fs::exists(path, error)) {
        if (error)
            throw stdext::exception("unable to inspect the selected backup history: {}", error.message());
        return json({ { "schemaVersion", 1 }, { "clientVersion", version },
                      { "historyAvailable", false }, { "entries", json::array() } }).dump();
    }
    const auto status = fs::symlink_status(path, error);
    if (error || fs::is_symlink(status) || !fs::is_regular_file(status))
        throw stdext::exception("the selected backup history is not a regular file");

    const auto history = json::parse(readSmallFile(path, MAX_HISTORY_FILE_SIZE));
    if (!history.is_object() || !history.contains("entries") || !history["entries"].is_array())
        throw stdext::exception("the selected backup history has an unsupported format");
    auto result = history;
    result["historyAvailable"] = true;
    return result.dump();
}

std::string SpriteAppearances::getAssetEditHistory(const int version)
{
    namespace fs = std::filesystem;
    constexpr size_t MAX_HISTORY_FILE_SIZE = 32 * 1024 * 1024;
    const auto path = getEditorAssetHistoryPath(version);
    std::error_code error;
    if (!fs::exists(path, error)) {
        if (error)
            throw stdext::exception("unable to inspect asset edit history: {}", error.message());
        return json({ { "schemaVersion", 1 }, { "clientVersion", version }, { "entries", json::array() } }).dump();
    }
    const auto status = fs::symlink_status(path, error);
    if (error || fs::is_symlink(status) || !fs::is_regular_file(status))
        throw stdext::exception("asset edit history is not a regular file");

    const auto history = json::parse(readSmallFile(path, MAX_HISTORY_FILE_SIZE));
    if (!history.is_object() || !history.contains("entries") || !history["entries"].is_array())
        throw stdext::exception("asset edit history has an unsupported format");
    return history.dump();
}

std::string SpriteAppearances::appendAssetEditHistory(const int version, const std::string& encodedEntry)
{
    namespace fs = std::filesystem;
    constexpr size_t MAX_HISTORY_FILE_SIZE = 32 * 1024 * 1024;
    constexpr size_t MAX_HISTORY_ENTRIES = 200;
    if (encodedEntry.size() > 16 * 1024 * 1024)
        throw stdext::exception("this asset edit is too large to store in the history");

    auto entry = json::parse(encodedEntry);
    if (!entry.is_object())
        throw stdext::exception("asset edit history entry must be an object");
    if (!entry.contains("label") || !entry["label"].is_string() || entry["label"].get<std::string>().empty())
        throw stdext::exception("asset edit history entry needs a label");

    const auto path = getEditorAssetHistoryPath(version);
    json history = { { "schemaVersion", 1 }, { "clientVersion", version }, { "entries", json::array() } };
    std::error_code error;
    if (fs::exists(path, error)) {
        const auto status = fs::symlink_status(path, error);
        if (error || fs::is_symlink(status) || !fs::is_regular_file(status))
            throw stdext::exception("asset edit history is not a regular file");
        history = json::parse(readSmallFile(path, MAX_HISTORY_FILE_SIZE));
        if (!history.is_object() || !history.contains("entries") || !history["entries"].is_array())
            throw stdext::exception("asset edit history has an unsupported format");
    } else if (error) {
        throw stdext::exception("unable to inspect asset edit history: {}", error.message());
    }

    entry["id"] = g_crypt.genUUID();
    entry["createdAt"] = getUtcTimestamp();
    history["schemaVersion"] = 1;
    history["clientVersion"] = version;
    history["entries"].push_back(std::move(entry));
    while (history["entries"].size() > MAX_HISTORY_ENTRIES)
        history["entries"].erase(history["entries"].begin());

    auto serialized = history.dump(2);
    while (serialized.size() > MAX_HISTORY_FILE_SIZE && history["entries"].size() > 1) {
        history["entries"].erase(history["entries"].begin());
        serialized = history.dump(2);
    }
    if (serialized.size() > MAX_HISTORY_FILE_SIZE)
        throw stdext::exception("asset edit history reached its storage limit");

    const std::vector<uint8_t> bytes(serialized.begin(), serialized.end());
    writeFileAtomically(path, bytes);
    return history["entries"].back()["id"].get<std::string>();
}

std::string SpriteAppearances::getSpriteImagePngBase64(const int version, const int spriteId)
{
    if (spriteId < 1)
        throw stdext::exception("sprite ID must be positive");
    const auto catalog = getEditorCatalogPath(version);
    const auto package = getEditorWorkPackagePath(version);
    if (std::filesystem::weakly_canonical(catalog.parent_path()) != std::filesystem::weakly_canonical(package))
        throw stdext::exception("sprite snapshots are available only inside the active work copy");
    const auto image = getSpriteImage(spriteId);
    if (!image)
        throw stdext::exception("sprite {} is not available in the loaded asset package", spriteId);

    std::stringstream png;
    save_png(png, image->getSize().width(), image->getSize().height(), 4, image->getPixelData());
    const auto contents = png.str();
    if (contents.size() > 4 * 1024 * 1024)
        throw stdext::exception("sprite image is too large to store in asset history");
    return g_crypt.base64Encode(contents);
}

void SpriteAppearances::restoreSpriteImageFromPngBase64(const int version, const int spriteId,
                                                         const std::string& encodedPng)
{
    if (spriteId < 1 || encodedPng.empty() || encodedPng.size() > 8 * 1024 * 1024)
        throw stdext::exception("invalid sprite history restore request");
    const auto decoded = g_crypt.base64Decode(encodedPng);
    const auto image = Image::loadPNG(decoded.data(), decoded.size());
    if (!image)
        throw stdext::exception("the saved sprite image in asset history is invalid");
    saveSpriteToWorkCopy(spriteId, image, version);
}

std::string SpriteAppearances::restoreInstalledAssetBackup(const int version, const std::string& backupName)
{
    namespace fs = std::filesystem;
    if (backupName.empty() || fs::path(backupName).filename() != fs::path(backupName) ||
        !backupName.starts_with(fmt::format("{}-", version)))
        throw stdext::exception("choose a backup for the selected client assets version");

    const auto workPackage = getEditorWorkPackagePath(version);
    const auto installedPackage = findInstalledAssetPackage(version, workPackage);
    const auto thingsDirectory = installedPackage.parent_path();
    const auto backupDirectory = thingsDirectory / "backup";
    const auto selectedBackup = backupDirectory / backupName;
    ensureNoSymlinkPath(thingsDirectory, backupDirectory);
    ensureNoSymlinkPath(backupDirectory, selectedBackup);
    if (!fs::is_directory(selectedBackup) || !fs::is_regular_file(selectedBackup / "catalog-content.json"))
        throw stdext::exception("the selected asset backup is unavailable or incomplete");
    validateAssetDirectory(selectedBackup);
    validateAssetDirectory(installedPackage);

    const auto temporaryPackage = fs::path(installedPackage.generic_string() + ".sprite-editor.restore.tmp");
    const auto rollbackPackage = fs::path(installedPackage.generic_string() + ".sprite-editor.restore-rollback.tmp");
    ensureNoSymlinkPath(thingsDirectory.parent_path(), temporaryPackage);
    ensureNoSymlinkPath(thingsDirectory.parent_path(), rollbackPackage);
    std::error_code error;
    if (fs::exists(temporaryPackage, error) || error)
        throw stdext::exception("a previous asset restore left a temporary folder; inspect '{}' before retrying",
                                temporaryPackage.generic_string());
    if (fs::exists(rollbackPackage, error) || error)
        throw stdext::exception("a previous asset restore left a rollback folder; inspect '{}' before retrying",
                                rollbackPackage.generic_string());
    try {
        copyAssetDirectory(selectedBackup, temporaryPackage);
        verifyAssetCopy(selectedBackup, temporaryPackage);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        throw;
    }

    try {
        fs::rename(installedPackage, rollbackPackage);
    } catch (const std::exception& exception) {
        fs::remove_all(temporaryPackage, error);
        throw stdext::exception("unable to prepare the installed assets for restore: {}", exception.what());
    }
    try {
        fs::rename(temporaryPackage, installedPackage);
    } catch (const std::exception& exception) {
        try {
            fs::rename(rollbackPackage, installedPackage);
        } catch (const std::exception& rollbackError) {
            throw stdext::exception("asset restore failed and rollback could not recover the current package; it remains at '{}': {}",
                                    rollbackPackage.generic_string(), rollbackError.what());
        }
        fs::remove_all(temporaryPackage, error);
        throw stdext::exception("asset restore failed; the current package was restored: {}", exception.what());
    }
    fs::remove_all(rollbackPackage, error);
    if (error)
        g_logger.warning("Unable to remove temporary asset restore rollback folder '{}': {}",
                         rollbackPackage.generic_string(), error.message());
    return {};
}

std::string SpriteAppearances::exportWorkCopy(const int version, const std::string& destination)
{
    namespace fs = std::filesystem;
    if (destination.empty())
        throw stdext::exception("an export destination folder is required");

    const fs::path requestedRoot(destination);
    if (!requestedRoot.is_absolute())
        throw stdext::exception("the export root must be an absolute path");

    const auto catalog = getEditorCatalogPath(version);
    const auto sourcePackage = fs::weakly_canonical(catalog.parent_path());
    validateAssetDirectory(sourcePackage);

    std::error_code error;
    if (fs::exists(requestedRoot, error) && !fs::is_directory(requestedRoot, error))
        throw stdext::exception("the export root must be a directory");
    if (error)
        throw stdext::exception("unable to validate the export root: {}", error.message());

    const auto normalizedRoot = fs::weakly_canonical(requestedRoot, error);
    if (error)
        throw stdext::exception("unable to resolve the export root: {}", error.message());

    const auto requestedDestination = normalizedRoot / "data" / "things" / std::to_string(version);
    const auto normalizedDestination = fs::weakly_canonical(requestedDestination, error);
    if (error)
        throw stdext::exception("unable to resolve the asset package destination: {}", error.message());

    const auto destinationStatus = fs::symlink_status(requestedDestination, error);
    if (!error && fs::exists(destinationStatus))
        throw stdext::exception("the asset package already exists at the export root; it will not be overwritten");
    if (error != std::errc::no_such_file_or_directory && error)
        throw stdext::exception("unable to validate the asset package destination: {}", error.message());

    for (const auto& searchRoot : g_resources.getSearchPaths()) {
        error.clear();
        const auto candidatePackage = fs::path(searchRoot) / "data" / "things" / std::to_string(version);
        if (!fs::is_directory(candidatePackage, error) || error)
            continue;

        const auto normalizedPackage = fs::weakly_canonical(candidatePackage, error);
        if (error)
            throw stdext::exception("unable to validate an installed asset folder: {}", error.message());
        if (normalizedDestination == normalizedPackage ||
            isPathWithin(normalizedPackage, normalizedDestination) ||
            isPathWithin(normalizedDestination, normalizedPackage))
            throw stdext::exception("the export root overlaps an installed or active asset package");
    }

    auto temporaryPackage = requestedDestination;
    temporaryPackage += ".sprite-editor.tmp";
    error.clear();
    const auto temporaryStatus = fs::symlink_status(temporaryPackage, error);
    if (!error && fs::exists(temporaryStatus))
        throw stdext::exception("an export temporary folder already exists; remove it before retrying");
    if (error != std::errc::no_such_file_or_directory && error)
        throw stdext::exception("unable to validate the export temporary folder: {}", error.message());

    fs::create_directories(requestedDestination.parent_path(), error);
    if (error)
        throw stdext::exception("unable to create the destination asset folders: {}", error.message());

    try {
        copyAssetDirectory(sourcePackage, temporaryPackage);
        const auto exportedCatalog = temporaryPackage / "catalog-content.json";
        if (!fs::is_regular_file(exportedCatalog) ||
            fs::file_size(catalog) != fs::file_size(exportedCatalog))
            throw stdext::exception("export verification failed for the asset catalog");
        validateAssetDirectory(temporaryPackage);
        fs::rename(temporaryPackage, requestedDestination);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        throw;
    }

    return normalizedDestination.generic_string();
}

std::string SpriteAppearances::installWorkCopy(const int version)
{
    namespace fs = std::filesystem;
    const auto workPackage = getEditorWorkPackagePath(version);
    const auto catalog = workPackage / "catalog-content.json";
    if (!fs::is_regular_file(catalog))
        throw stdext::exception("the selected sprite editor work copy is incomplete");
    validateAssetDirectory(workPackage);

    const auto existingInstalledPackage = findInstalledAssetPackageIfPresent(version, workPackage);
    const bool hasInstalledPackage = existingInstalledPackage.has_value();
    fs::path installedPackage;
    fs::path thingsDirectory;
    fs::path writableRoot;
    if (existingInstalledPackage) {
        installedPackage = *existingInstalledPackage;
        validateAssetDirectory(installedPackage);
        thingsDirectory = installedPackage.parent_path();
    } else {
        const fs::path writeDirectory(g_resources.getWriteDir());
        if (writeDirectory.empty())
            throw stdext::exception("the client has no writable user directory");
        writableRoot = fs::weakly_canonical(writeDirectory);
        thingsDirectory = writableRoot / "data" / "things";
        installedPackage = thingsDirectory / std::to_string(version);
        ensureNoSymlinkPath(writableRoot, installedPackage);

        std::error_code destinationError;
        const auto destinationStatus = fs::symlink_status(installedPackage, destinationError);
        if (!destinationError && fs::exists(destinationStatus))
            throw stdext::exception("the data/things/{} folder exists but its installed assets could not be verified; refusing to overwrite it", version);
        if (destinationError != std::errc::no_such_file_or_directory && destinationError)
            throw stdext::exception("unable to inspect the asset install destination: {}", destinationError.message());
    }

    const auto backupDirectory = thingsDirectory / "backup";
    ensureNoSymlinkPath(thingsDirectory, backupDirectory);

    const auto temporaryPackage = fs::path(installedPackage.generic_string() + ".sprite-editor.tmp");
    ensureNoSymlinkPath(thingsDirectory.parent_path().parent_path(), temporaryPackage);
    std::error_code error;
    const auto temporaryStatus = fs::symlink_status(temporaryPackage, error);
    if (!error && fs::exists(temporaryStatus))
        throw stdext::exception("an earlier asset export left a temporary folder; inspect '{}' before retrying", temporaryPackage.generic_string());
    if (error != std::errc::no_such_file_or_directory && error)
        throw stdext::exception("unable to validate the asset export folder: {}", error.message());

    try {
        copyAssetDirectory(workPackage, temporaryPackage);
        verifyAssetCopy(workPackage, temporaryPackage);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        throw;
    }

    fs::path backupPath;
    try {
        if (hasInstalledPackage) {
            fs::create_directories(backupDirectory, error);
            if (error)
                throw stdext::exception("unable to create the Things backup folder: {}", error.message());
            ensureNoSymlinkPath(thingsDirectory, backupDirectory);

            const auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();
            for (int suffix = 0; ; ++suffix) {
                backupPath = backupDirectory / (suffix == 0 ?
                    fmt::format("{}-{}", version, timestamp) : fmt::format("{}-{}-{}", version, timestamp, suffix));
                const auto backupStatus = fs::symlink_status(backupPath, error);
                if (error == std::errc::no_such_file_or_directory) {
                    error.clear();
                    break;
                }
                if (error)
                    throw stdext::exception("unable to validate the Things backup path: {}", error.message());
                if (!fs::exists(backupStatus))
                    break;
            }
            ensureNoSymlinkPath(thingsDirectory, backupPath);
        } else {
            fs::create_directories(thingsDirectory, error);
            if (error)
                throw stdext::exception("unable to create the Things folder: {}", error.message());
            ensureNoSymlinkPath(writableRoot, installedPackage);

            const auto destinationStatus = fs::symlink_status(installedPackage, error);
            if (!error && fs::exists(destinationStatus))
                throw stdext::exception("the asset install destination appeared while exporting; no existing files were replaced");
            if (error != std::errc::no_such_file_or_directory && error)
                throw stdext::exception("unable to revalidate the asset install destination: {}", error.message());
        }
    } catch (...) {
        std::error_code cleanupError;
        fs::remove_all(temporaryPackage, cleanupError);
        throw;
    }

    if (hasInstalledPackage) {
        try {
            fs::rename(installedPackage, backupPath);
        } catch (const std::exception& exception) {
            fs::remove_all(temporaryPackage, error);
            throw stdext::exception("unable to move the current asset package to backup: {}", exception.what());
        }
    }

    try {
        fs::rename(temporaryPackage, installedPackage);
    } catch (const std::exception& exception) {
        if (hasInstalledPackage) {
            try {
                fs::rename(backupPath, installedPackage);
            } catch (const std::exception& rollbackError) {
                throw stdext::exception("asset export failed and rollback could not restore the original package; backup remains at '{}': {}",
                    backupPath.generic_string(), rollbackError.what());
            }
        }
        fs::remove_all(temporaryPackage, error);
        if (hasInstalledPackage)
            throw stdext::exception("asset export failed; the original package was restored: {}", exception.what());
        throw stdext::exception("asset export failed; no previous package was changed: {}", exception.what());
    }

    return backupPath.generic_string();
}

std::string SpriteAppearances::installWorkCopyAsNewVersion(const int sourceVersion, const int targetVersion)
{
    namespace fs = std::filesystem;
    if (sourceVersion < 1500 || sourceVersion >= 1600 ||
        targetVersion < 1500 || targetVersion >= 1600 || sourceVersion == targetVersion)
        throw stdext::exception("source and new client versions must be different 15.x versions");

    const auto workPackage = getEditorWorkPackagePath(sourceVersion);
    if (!fs::is_regular_file(workPackage / "catalog-content.json"))
        throw stdext::exception("the selected sprite editor work copy is incomplete");
    validateAssetDirectory(workPackage);

    const fs::path writeDirectory(g_resources.getWriteDir());
    if (writeDirectory.empty())
        throw stdext::exception("the client has no writable user directory");
    const auto writeRoot = fs::weakly_canonical(writeDirectory);
    const auto thingsDirectory = writeRoot / "data" / "things";
    const auto targetPackage = thingsDirectory / std::to_string(targetVersion);
    ensureNoSymlinkPath(writeRoot, targetPackage);

    std::error_code error;
    for (const auto& searchRoot : g_resources.getSearchPaths()) {
        const auto installedPackage = fs::path(searchRoot) / "data" / "things" / std::to_string(targetVersion);
        error.clear();
        const auto status = fs::symlink_status(installedPackage, error);
        if (!error && fs::exists(status))
            throw stdext::exception("client version {} already has an asset folder; choose an unused 15.x version", targetVersion);
        if (error != std::errc::no_such_file_or_directory && error)
            throw stdext::exception("unable to validate the new asset version destination: {}", error.message());
    }

    auto temporaryPackage = targetPackage;
    temporaryPackage += ".sprite-editor.tmp";
    error.clear();
    const auto temporaryStatus = fs::symlink_status(temporaryPackage, error);
    if (!error && fs::exists(temporaryStatus))
        throw stdext::exception("an earlier new-version export left a temporary folder; inspect it before retrying");
    if (error != std::errc::no_such_file_or_directory && error)
        throw stdext::exception("unable to validate the new-version temporary folder: {}", error.message());

    fs::create_directories(thingsDirectory, error);
    if (error)
        throw stdext::exception("unable to create the Things folder: {}", error.message());
    ensureNoSymlinkPath(writeRoot, targetPackage);

    try {
        copyAssetDirectory(workPackage, temporaryPackage);
        verifyAssetCopy(workPackage, temporaryPackage);
        error.clear();
        const auto targetStatus = fs::symlink_status(targetPackage, error);
        if (!error && fs::exists(targetStatus))
            throw stdext::exception("client version {} already has an asset folder; choose an unused 15.x version", targetVersion);
        if (error != std::errc::no_such_file_or_directory && error)
            throw stdext::exception("unable to revalidate the new asset version destination: {}", error.message());
        fs::rename(temporaryPackage, targetPackage);
    } catch (...) {
        fs::remove_all(temporaryPackage, error);
        throw;
    }

    return targetPackage.generic_string();
}

void SpriteAppearances::saveSpriteToWorkCopy(const int id, const ImagePtr& image, const int version)
{
    if (version < 1500 || version >= 1600 || id <= 0 || !image || image->getBpp() != 4)
        throw stdext::exception("invalid sprite editor save request");

    const auto& sheet = getSheetBySpriteId(id);
    if (!sheet || !sheet->data)
        throw stdext::exception("sprite {} is not available in the loaded asset package", id);

    const Size spriteSize = sheet->getSpriteSize();
    if (image->getSize() != spriteSize)
        throw stdext::exception("edited sprite dimensions do not match the selected sprite");

    const auto virtualPackage = fmt::format("/data/things/{}/", version);
    const auto catalogPath = std::filesystem::path(g_resources.getRealPath(virtualPackage + "catalog-content.json")).lexically_normal();
    const auto currentPackage = catalogPath.parent_path();
    const auto normalizedWriteDirectory = std::filesystem::weakly_canonical(
        std::filesystem::path(g_resources.getWriteDir()));
    const auto expectedPackage = normalizedWriteDirectory / "sprite-editor" / "data" / "things" / std::to_string(version);
    ensureNoSymlinkPath(normalizedWriteDirectory, expectedPackage);
    if (!isPathWithin(expectedPackage, catalogPath))
        throw stdext::exception("the selected asset catalog is outside the validated work copy");
    ensureNoSymlinkPath(expectedPackage, catalogPath);
    if (!std::filesystem::is_regular_file(catalogPath) ||
        std::filesystem::weakly_canonical(currentPackage) != std::filesystem::weakly_canonical(expectedPackage))
        throw stdext::exception("saving is allowed only to the sprite editor work copy");

    const auto relativeSheetPath = safeAssetPath(sheet->file);
    const auto virtualSheetPath = virtualPackage + relativeSheetPath.generic_string();
    const auto sheetPath = std::filesystem::path(g_resources.getRealPath(virtualSheetPath)).lexically_normal();
    if (!isPathWithin(expectedPackage, sheetPath))
        throw stdext::exception("sprite sheet is outside the validated work copy");
    ensureNoSymlinkPath(expectedPackage, sheetPath);
    if (!std::filesystem::is_regular_file(sheetPath))
        throw stdext::exception("sprite sheet is outside the validated work copy");

    const std::string originalContents = g_resources.readFileContents(virtualSheetPath);
    if (originalContents.empty())
        throw stdext::exception("unable to read sprite sheet {}", sheet->file);
    const std::vector<uint8_t> original(originalContents.begin(), originalContents.end());
    const SpriteSheetLzmaHeader header = readSpriteSheetHeader(original);
    std::vector<uint8_t> decompressed = decompressSpriteSheet(original, header);

    if (decompressed[0] != 'B' || decompressed[1] != 'M')
        throw stdext::exception("sprite sheet does not contain a Windows bitmap");
    const uint32_t bitmapOffset = readU32(decompressed, 10);
    const uint32_t bitmapWidth = readU32(decompressed, 18);
    const uint32_t bitmapHeight = readU32(decompressed, 22);
    const uint16_t bitmapPlanes = static_cast<uint16_t>(decompressed[26] | (decompressed[27] << 8));
    const uint16_t bitmapBitsPerPixel = static_cast<uint16_t>(decompressed[28] | (decompressed[29] << 8));
    const uint32_t bitmapCompression = readU32(decompressed, 30);
    if (bitmapWidth != SpriteSheet::SIZE || bitmapHeight != SpriteSheet::SIZE ||
        bitmapPlanes != 1 || bitmapBitsPerPixel != 32 || bitmapCompression != 3 ||
        bitmapOffset < 54 || bitmapOffset > decompressed.size() ||
        BYTES_IN_SPRITE_SHEET > decompressed.size() - bitmapOffset)
        throw stdext::exception("sprite sheet bitmap format or pixel offset is unsupported");

    const int spriteOffset = id - sheet->firstId;
    const int spritesPerSheet = sheet->getSpritesPerSheet();
    if (spriteOffset < 0 || spriteOffset >= spritesPerSheet)
        throw stdext::exception("sprite id {} is out of bounds for its sheet", id);

    const int spriteColumn = spriteOffset % sheet->getColumns();
    const int spriteRow = spriteOffset / sheet->getColumns();
    const int originX = spriteColumn * spriteSize.width();
    const int originY = spriteRow * spriteSize.height();
    auto& imagePixels = image->getPixels();
    std::vector<uint8_t> updatedSheet(sheet->data.get(), sheet->data.get() + BYTES_IN_SPRITE_SHEET);
    for (int y = 0; y < spriteSize.height(); ++y) {
        for (int x = 0; x < spriteSize.width(); ++x) {
            const size_t imageOffset = static_cast<size_t>(y * spriteSize.width() + x) * 4;
            const int sheetX = originX + x;
            const int sheetY = SpriteSheet::SIZE - 1 - (originY + y);
            const size_t bitmapPixelOffset = bitmapOffset +
                static_cast<size_t>(sheetY * SpriteSheet::SIZE + sheetX) * 4;
            const uint8_t alpha = imagePixels[imageOffset + 3];
            if (alpha == 0) {
                decompressed[bitmapPixelOffset + 0] = 0xff;
                decompressed[bitmapPixelOffset + 1] = 0x00;
                decompressed[bitmapPixelOffset + 2] = 0xff;
                decompressed[bitmapPixelOffset + 3] = 0x00;
            } else {
                decompressed[bitmapPixelOffset + 0] = imagePixels[imageOffset + 2];
                decompressed[bitmapPixelOffset + 1] = imagePixels[imageOffset + 1];
                decompressed[bitmapPixelOffset + 2] = imagePixels[imageOffset + 0];
                decompressed[bitmapPixelOffset + 3] = 0xff;
            }

            const size_t sheetPixelOffset =
                static_cast<size_t>((originY + y) * SpriteSheet::SIZE + originX + x) * 4;
            std::memcpy(updatedSheet.data() + sheetPixelOffset, imagePixels.data() + imageOffset, 4);
        }
    }

    const auto encoded = compressSpriteSheet(decompressed, header, original);
    writeFileAtomically(sheetPath, encoded);
    std::memcpy(sheet->data.get(), updatedSheet.data(), BYTES_IN_SPRITE_SHEET);
    g_things.invalidateTextureCache();
    g_textures.clearCache();
}

int SpriteAppearances::importSpriteFromFile(const int id, const std::string& fileName, const int version)
{
    if (id > 0) {
        const auto& sheet = getSheetBySpriteId(id);
        if (!sheet)
            throw stdext::exception("sprite {} is not available in the loaded asset package", id);
        const auto image = loadPreparedSprite(fileName, sheet->getSpriteSize());
        saveSpriteToWorkCopy(id, image, version);
        return id;
    }
    if (id < 0)
        throw stdext::exception("sprite ID must be zero to allocate a new sprite");

    const auto image = loadPreparedSprite(fileName, Size(0, 0));
    const auto spriteLayout = getSpriteLayout(image->getSize());
    return importNewSprite(image, version, spriteLayout);
}

int SpriteAppearances::importSpriteForAppearance(const int referenceSpriteId, const std::string& fileName,
                                                 const int version)
{
    if (referenceSpriteId < 1)
        throw stdext::exception("a reference sprite ID is required to allocate a replacement sprite");
    const auto referenceSheet = getSheetBySpriteId(referenceSpriteId);
    if (!referenceSheet)
        throw stdext::exception("reference sprite {} is not available in the loaded asset package", referenceSpriteId);
    const auto image = loadPreparedSprite(fileName, referenceSheet->getSpriteSize());
    return importNewSprite(image, version, referenceSheet->spriteLayout);
}

std::vector<int> SpriteAppearances::importNewSprites(
    const std::vector<std::pair<ImagePtr, SpriteLayout>>& sprites, const int version)
{
    namespace fs = std::filesystem;
    if (sprites.empty())
        throw stdext::exception("no prepared sprites were selected for import");

    const auto catalogPath = getEditorCatalogPath(version);
    const auto package = catalogPath.parent_path();
    std::ifstream catalogStream(catalogPath, std::ios::binary);
    if (!catalogStream)
        throw stdext::exception("unable to read the active sprite catalog");
    json catalog = json::parse(catalogStream);
    if (!catalog.is_array())
        throw stdext::exception("the active sprite catalog has an invalid format");

    int maximumSpriteId = -1;
    std::map<int, std::string> templateFiles;
    for (const auto& entry : catalog) {
        if (!entry.is_object() || entry.value("type", std::string{}) != "sprite")
            continue;
        if (!entry.contains("firstspriteid") || !entry.contains("lastspriteid") ||
            !entry.contains("spritetype") || !entry.contains("file"))
            throw stdext::exception("the active sprite catalog contains an incomplete sprite entry");

        const int firstId = entry.at("firstspriteid").get<int>();
        const int lastId = entry.at("lastspriteid").get<int>();
        const int layout = entry.at("spritetype").get<int>();
        if (firstId < 0 || lastId < firstId || layout < 0 || layout > static_cast<int>(SpriteLayout::SIZE_384_384))
            throw stdext::exception("the active sprite catalog contains an invalid sprite range");
        maximumSpriteId = std::max(maximumSpriteId, lastId);
        templateFiles.try_emplace(layout, entry.at("file").get<std::string>());
    }
    if (maximumSpriteId < 0 || static_cast<uint64_t>(maximumSpriteId) + sprites.size() >=
            static_cast<uint64_t>(std::numeric_limits<int>::max()))
        throw stdext::exception("the active sprite catalog has no room for the imported sprites");

    std::map<int, std::vector<std::pair<size_t, ImagePtr>>> groupedSprites;
    for (size_t index = 0; index < sprites.size(); ++index) {
        const auto& [image, layout] = sprites[index];
        const SpriteSheet layoutTemplate(0, 0, layout, {});
        if (!image || image->getSize() != layoutTemplate.getSpriteSize())
            throw stdext::exception("a prepared sprite does not match its selected sprite layout");
        groupedSprites[static_cast<int>(layout)].emplace_back(index, image);
    }

    std::vector<int> importedIds(sprites.size());
    std::vector<std::pair<fs::path, fs::path>> stagedFiles;
    std::vector<fs::path> committedFiles;
    int nextSpriteId = maximumSpriteId + 1;
    try {
        for (const auto& [layoutValue, layoutSprites] : groupedSprites) {
            const auto templateIt = templateFiles.find(layoutValue);
            if (templateIt == templateFiles.end())
                throw stdext::exception("the active sprite catalog has no sheet for layout {}", layoutValue);

            const auto templateRelative = safeAssetPath(templateIt->second);
            const auto templatePath = package / templateRelative;
            ensureNoSymlinkPath(package, templatePath);
            if (!isPathWithin(package, templatePath) || !fs::is_regular_file(templatePath))
                throw stdext::exception("unable to read a sprite sheet template from the work copy");
            const auto templateData = readBinaryFile(templatePath);
            const auto header = readSpriteSheetHeader(templateData);
            const int capacity = SpriteSheet(0, 0, static_cast<SpriteLayout>(layoutValue), {}).getSpritesPerSheet();

            for (size_t start = 0; start < layoutSprites.size(); start += static_cast<size_t>(capacity)) {
                const size_t count = std::min(static_cast<size_t>(capacity), layoutSprites.size() - start);
                const int firstId = nextSpriteId;
                const int lastId = firstId + static_cast<int>(count) - 1;
                const std::string relativeName = fmt::format("sprite-editor-{}.bmp.lzma", firstId);
                const auto relativePath = safeAssetPath(relativeName);
                const auto targetPath = package / relativePath;
                const auto stagedPath = fs::path(targetPath.string() + ".bulk.tmp");
                ensureNoSymlinkPath(package, targetPath);
                ensureNoSymlinkPath(package, stagedPath);
                if (fs::exists(targetPath) || fs::exists(stagedPath))
                    throw stdext::exception("a sprite sheet file already exists for the next sprite ID");

                auto bitmap = decompressSpriteSheet(templateData, header);
                const uint32_t bitmapOffset = validateSpriteSheetBitmap(bitmap);
                for (size_t offset = bitmapOffset; offset < bitmapOffset + BYTES_IN_SPRITE_SHEET; offset += 4) {
                    bitmap[offset + 0] = 0xff;
                    bitmap[offset + 1] = 0x00;
                    bitmap[offset + 2] = 0xff;
                    bitmap[offset + 3] = 0x00;
                }
                for (size_t index = 0; index < count; ++index) {
                    const auto& [sourceIndex, image] = layoutSprites[start + index];
                    writeSpritePixels(bitmap, bitmapOffset, static_cast<int>(index),
                                      SpriteSheet(0, 0, static_cast<SpriteLayout>(layoutValue), {}).getSpriteSize(), image);
                    importedIds[sourceIndex] = firstId + static_cast<int>(index);
                }
                const auto encoded = compressSpriteSheet(bitmap, header, templateData);
                stagedFiles.emplace_back(stagedPath, targetPath);
                {
                    std::ofstream staged(stagedPath, std::ios::binary | std::ios::trunc);
                    if (!staged)
                        throw stdext::exception("unable to stage an imported sprite sheet");
                    staged.write(reinterpret_cast<const char*>(encoded.data()), static_cast<std::streamsize>(encoded.size()));
                    staged.flush();
                    if (!staged)
                        throw stdext::exception("unable to write a staged sprite sheet");
                }
                catalog.push_back({
                    { "type", "sprite" },
                    { "file", relativePath.generic_string() },
                    { "spritetype", layoutValue },
                    { "firstspriteid", firstId },
                    { "lastspriteid", lastId },
                    { "area", 0 }
                });
                nextSpriteId = lastId + 1;
            }
        }

        for (const auto& [stagedPath, targetPath] : stagedFiles) {
            fs::rename(stagedPath, targetPath);
            committedFiles.push_back(targetPath);
        }

        const std::string serializedCatalog = catalog.dump(2);
        const std::vector<uint8_t> catalogBytes(serializedCatalog.begin(), serializedCatalog.end());
        writeFileAtomically(catalogPath, catalogBytes);
    } catch (...) {
        std::error_code error;
        for (const auto& path : committedFiles)
            fs::remove(path, error);
        for (const auto& [stagedPath, targetPath] : stagedFiles)
            fs::remove(stagedPath, error);
        throw;
    }

    return importedIds;
}

std::string SpriteAppearances::importSpritesFromDirectory(const std::string& directory, const int version)
{
    namespace fs = std::filesystem;
    if (version < 1500 || version >= 1600)
        throw stdext::exception("batch sprite import is supported only for client versions 15.x");

    const fs::path sourceDirectory(directory);
    if (directory.empty() || !sourceDirectory.is_absolute() || !fs::is_directory(sourceDirectory))
        throw stdext::exception("choose an existing absolute folder containing prepared PNG sprites");

    struct PreparedSprite {
        fs::path path;
        ImagePtr image;
        SpriteLayout layout;
    };
    std::vector<fs::path> paths;
    std::error_code error;
    fs::directory_iterator iterator(sourceDirectory, error);
    if (error)
        throw stdext::exception("unable to read the selected PNG folder: {}", error.message());
    for (const fs::directory_iterator end; iterator != end; iterator.increment(error)) {
        if (error)
            throw stdext::exception("unable to read the selected PNG folder: {}", error.message());
        const auto status = iterator->symlink_status(error);
        if (error)
            throw stdext::exception("unable to inspect a file in the selected PNG folder: {}", error.message());
        if (fs::is_symlink(status) || !fs::is_regular_file(status))
            continue;

        auto extension = iterator->path().extension().string();
        std::ranges::transform(extension, extension.begin(), [](const unsigned char value) {
            return static_cast<char>(std::tolower(value));
        });
        if (extension == ".png")
            paths.push_back(iterator->path());
    }
    if (paths.empty())
        throw stdext::exception("the selected folder does not contain any PNG files");
    constexpr size_t MAX_BATCH_SPRITES = 256;
    if (paths.size() > MAX_BATCH_SPRITES)
        throw stdext::exception("select a folder with no more than {} PNG files per batch", MAX_BATCH_SPRITES);

    std::ranges::sort(paths, [](const fs::path& left, const fs::path& right) {
        auto leftName = left.filename().string();
        auto rightName = right.filename().string();
        std::ranges::transform(leftName, leftName.begin(), [](const unsigned char value) {
            return static_cast<char>(std::tolower(value));
        });
        std::ranges::transform(rightName, rightName.begin(), [](const unsigned char value) {
            return static_cast<char>(std::tolower(value));
        });
        return leftName < rightName;
    });

    std::vector<PreparedSprite> sprites;
    sprites.reserve(paths.size());
    size_t decodedBytes = 0;
    for (const auto& path : paths) {
        try {
            auto image = loadPreparedSprite(path.generic_string(), Size(0, 0));
            decodedBytes += image->getSize().area() * 4;
            if (decodedBytes > 64 * 1024 * 1024)
                throw stdext::exception("the batch exceeds the 64 MiB decoded image limit");
            sprites.push_back({ path, image, getSpriteLayout(image->getSize()) });
        } catch (const std::exception& exception) {
            throw stdext::exception("PNG '{}' is invalid: {}. No sprites were imported.",
                path.filename().string(), exception.what());
        }
    }
    std::ranges::stable_sort(sprites, [](const PreparedSprite& left, const PreparedSprite& right) {
        if (left.layout != right.layout)
            return static_cast<int>(left.layout) < static_cast<int>(right.layout);
        return left.path.filename().string() < right.path.filename().string();
    });

    std::vector<std::pair<ImagePtr, SpriteLayout>> prepared;
    prepared.reserve(sprites.size());
    for (const auto& sprite : sprites)
        prepared.emplace_back(sprite.image, sprite.layout);
    const auto ids = importNewSprites(prepared, version);

    json result = { { "imported", ids.size() }, { "items", json::array() }, { "error", "" } };
    for (size_t index = 0; index < sprites.size(); ++index) {
        const auto& sprite = sprites[index];
        result["items"].push_back({
            { "file", sprite.path.filename().string() },
            { "id", ids[index] },
            { "width", sprite.image->getSize().width() },
            { "height", sprite.image->getSize().height() }
        });
    }
    return result.dump();
}

std::string SpriteAppearances::importSpritesFromSheet(const std::string& fileName, const int version,
                                                      const int spriteWidth, const int spriteHeight,
                                                      const int firstCell, const int lastCell,
                                                      const bool skipTransparentCells)
{
    if (version < 1500 || version >= 1600)
        throw stdext::exception("sprite sheet import is supported only for client versions 15.x");
    if (spriteWidth < 1 || spriteHeight < 1 || firstCell < 1 || lastCell < 0)
        throw stdext::exception("sprite sheet cell size and range must be positive");

    const auto sheet = loadPreparedSpriteSheet(fileName);
    const Size spriteSize(spriteWidth, spriteHeight);
    const auto spriteLayout = getSpriteLayout(spriteSize);
    if (sheet->getWidth() % spriteWidth != 0 || sheet->getHeight() % spriteHeight != 0)
        throw stdext::exception("sprite sheet dimensions must be exact multiples of the selected cell size");

    const int columns = sheet->getWidth() / spriteWidth;
    const int rows = sheet->getHeight() / spriteHeight;
    const size_t totalCellCount = static_cast<size_t>(columns) * rows;
    const size_t firstCellIndex = static_cast<size_t>(firstCell - 1);
    const size_t lastCellIndex = lastCell == 0 ? totalCellCount - 1 : static_cast<size_t>(lastCell - 1);
    if (firstCellIndex >= totalCellCount || lastCellIndex >= totalCellCount || lastCellIndex < firstCellIndex)
        throw stdext::exception("sprite sheet cell range is outside the sheet");
    const size_t spriteCount = lastCellIndex - firstCellIndex + 1;
    constexpr size_t MAX_SHEET_SPRITES = 64;
    if (spriteCount > MAX_SHEET_SPRITES)
        throw stdext::exception("select a range containing no more than {} cells per import", MAX_SHEET_SPRITES);

    std::vector<ImagePtr> sprites;
    sprites.reserve(spriteCount);
    std::vector<size_t> sourceCellIndexes;
    sourceCellIndexes.reserve(spriteCount);
    const auto& sourcePixels = sheet->getPixels();
    for (size_t cellIndex = firstCellIndex; cellIndex <= lastCellIndex; ++cellIndex) {
        const int row = static_cast<int>(cellIndex / columns);
        const int column = static_cast<int>(cellIndex % columns);
        std::vector<uint8_t> pixels(static_cast<size_t>(spriteWidth) * spriteHeight * 4);
        bool hasVisiblePixel = false;
        for (int y = 0; y < spriteHeight; ++y) {
            const size_t sourceOffset =
                (static_cast<size_t>(row * spriteHeight + y) * sheet->getWidth() + column * spriteWidth) * 4;
            const size_t targetOffset = static_cast<size_t>(y) * spriteWidth * 4;
            std::memcpy(pixels.data() + targetOffset, sourcePixels.data() + sourceOffset,
                        static_cast<size_t>(spriteWidth) * 4);
            if (!hasVisiblePixel) {
                for (int x = 0; x < spriteWidth; ++x) {
                    if (pixels[targetOffset + static_cast<size_t>(x) * 4 + 3] != 0) {
                        hasVisiblePixel = true;
                        break;
                    }
                }
            }
        }
        if (skipTransparentCells && !hasVisiblePixel)
            continue;
        sprites.push_back(std::make_shared<Image>(spriteSize, 4, pixels.data()));
        sourceCellIndexes.push_back(cellIndex);
    }
    if (sprites.empty())
        throw stdext::exception("the selected range contains no visible sprite cells");

    size_t decodedBytes = 0;
    std::vector<std::pair<ImagePtr, SpriteLayout>> prepared;
    prepared.reserve(sprites.size());
    for (const auto& sprite : sprites) {
        decodedBytes += sprite->getSize().area() * 4;
        if (decodedBytes > 64 * 1024 * 1024)
            throw stdext::exception("the sprite sheet exceeds the 64 MiB decoded image limit");
        prepared.emplace_back(sprite, spriteLayout);
    }
    const auto ids = importNewSprites(prepared, version);
    json result = {
        { "imported", ids.size() },
        { "selected", spriteCount },
        { "skipped", spriteCount - ids.size() },
        { "items", json::array() },
        { "error", "" }
    };
    for (size_t index = 0; index < sprites.size(); ++index) {
        const size_t cellIndex = sourceCellIndexes[index];
        result["items"].push_back({
            { "id", ids[index] },
            { "cell", cellIndex + 1 },
            { "column", static_cast<int>(cellIndex % columns) + 1 },
            { "row", static_cast<int>(cellIndex / columns) + 1 },
            { "width", spriteWidth },
            { "height", spriteHeight }
        });
    }
    return result.dump();
}

int SpriteAppearances::importNewSprite(const ImagePtr& image, const int version, const SpriteLayout spriteLayout)
{
    const SpriteSheet layoutTemplate(0, 0, spriteLayout, {});
    if (!image || image->getSize() != layoutTemplate.getSpriteSize())
        throw stdext::exception("new sprite dimensions do not match the selected sprite layout");

    const auto catalogPath = getEditorCatalogPath(version);
    const auto package = catalogPath.parent_path();
    std::ifstream catalogStream(catalogPath, std::ios::binary);
    if (!catalogStream)
        throw stdext::exception("unable to read the active sprite catalog");
    json catalog = json::parse(catalogStream);
    if (!catalog.is_array())
        throw stdext::exception("the active sprite catalog has an invalid format");

    int maximumSpriteId = -1;
    json* reusableSheet = nullptr;
    const json* templateSheet = nullptr;
    for (auto& entry : catalog) {
        if (!entry.is_object() || entry.value("type", std::string{}) != "sprite")
            continue;
        if (!entry.contains("firstspriteid") || !entry.contains("lastspriteid") || !entry.contains("spritetype") || !entry.contains("file"))
            throw stdext::exception("the active sprite catalog contains an incomplete sprite entry");

        const int firstId = entry.at("firstspriteid").get<int>();
        const int lastId = entry.at("lastspriteid").get<int>();
        const int layout = entry.at("spritetype").get<int>();
        if (firstId < 0 || lastId < firstId)
            throw stdext::exception("the active sprite catalog contains an invalid sprite range");
        maximumSpriteId = std::max(maximumSpriteId, lastId);
        if (layout == static_cast<int>(spriteLayout))
            templateSheet = &entry;

        const auto file = entry.at("file").get<std::string>();
        const int capacity = SpriteSheet(firstId, lastId, static_cast<SpriteLayout>(layout), file).getSpritesPerSheet();
        if (file.starts_with("sprite-editor-") && layout == static_cast<int>(spriteLayout) &&
            lastId == maximumSpriteId &&
            lastId < firstId + capacity - 1 && (!reusableSheet || lastId > reusableSheet->at("lastspriteid").get<int>()))
            reusableSheet = &entry;
    }
    if (reusableSheet && reusableSheet->at("lastspriteid").get<int>() != maximumSpriteId)
        reusableSheet = nullptr;
    if (!templateSheet || maximumSpriteId < 0)
        throw stdext::exception("the active sprite catalog does not contain a sheet with the selected sprite layout");
    if (maximumSpriteId == std::numeric_limits<int>::max())
        throw stdext::exception("no sprite IDs remain in the active catalog");

    const int firstId = reusableSheet ? reusableSheet->at("firstspriteid").get<int>() : maximumSpriteId + 1;
    const int spriteId = reusableSheet ? reusableSheet->at("lastspriteid").get<int>() + 1 : firstId;
    if (spriteId < 1 || static_cast<uint64_t>(spriteId) > std::numeric_limits<uint32_t>::max())
        throw stdext::exception("the next sprite ID is outside the supported range");

    const auto fileNameInCatalog = reusableSheet ? reusableSheet->at("file").get<std::string>()
                                                   : fmt::format("sprite-editor-{}.bmp.lzma", firstId);
    const auto relativeSheetPath = safeAssetPath(fileNameInCatalog);
    const auto sheetPath = package / relativeSheetPath;
    ensureNoSymlinkPath(package, sheetPath);
    if (!isPathWithin(package, sheetPath))
        throw stdext::exception("the new sprite sheet path is outside the active work copy");
    if (!reusableSheet && std::filesystem::exists(sheetPath))
        throw stdext::exception("a file already exists at the next sprite sheet path");

    std::vector<uint8_t> original;
    SpriteSheetLzmaHeader header;
    std::vector<uint8_t> bitmap;
    if (reusableSheet) {
        if (!std::filesystem::is_regular_file(sheetPath))
            throw stdext::exception("the allocated sprite sheet file is missing");
        original = readBinaryFile(sheetPath);
        header = readSpriteSheetHeader(original);
        bitmap = decompressSpriteSheet(original, header);
    } else {
        const auto templateFile = safeAssetPath(templateSheet->at("file").get<std::string>());
        const auto templatePath = package / templateFile;
        ensureNoSymlinkPath(package, templatePath);
        if (!isPathWithin(package, templatePath) || !std::filesystem::is_regular_file(templatePath))
            throw stdext::exception("unable to read a sprite sheet template from the work copy");
        original = readBinaryFile(templatePath);
        header = readSpriteSheetHeader(original);
        bitmap = decompressSpriteSheet(original, header);
    }

    const uint32_t bitmapOffset = validateSpriteSheetBitmap(bitmap);
    if (!reusableSheet) {
        for (size_t offset = bitmapOffset; offset < bitmapOffset + BYTES_IN_SPRITE_SHEET; offset += 4) {
            bitmap[offset + 0] = 0xff;
            bitmap[offset + 1] = 0x00;
            bitmap[offset + 2] = 0xff;
            bitmap[offset + 3] = 0x00;
        }
    }
    writeSpritePixels(bitmap, bitmapOffset, spriteId - firstId, layoutTemplate.getSpriteSize(), image);

    const auto encodedSheet = compressSpriteSheet(bitmap, header, original);
    writeFileAtomically(sheetPath, encodedSheet);
    if (reusableSheet) {
        reusableSheet->at("lastspriteid") = spriteId;
    } else {
        catalog.push_back({
            { "type", "sprite" },
            { "file", relativeSheetPath.generic_string() },
            { "spritetype", static_cast<int>(spriteLayout) },
            { "firstspriteid", firstId },
            { "lastspriteid", spriteId },
            { "area", 0 }
        });
    }

    const std::string serializedCatalog = catalog.dump(2);
    const std::vector<uint8_t> catalogBytes(serializedCatalog.begin(), serializedCatalog.end());
    writeFileAtomically(catalogPath, catalogBytes);
    return spriteId;
}

void SpriteAppearances::releaseSpriteSheetsExcept(const int id)
{
    const auto retainedSheet = getSheetBySpriteId(id, false);
    for (const auto& sheet : m_sheets) {
        if (sheet == retainedSheet || sheet->m_loadingState.load(std::memory_order_acquire) == SpriteLoadState::LOADING)
            continue;
        sheet->data.reset();
        sheet->m_loadingState.store(SpriteLoadState::NONE, std::memory_order_release);
    }
}

void SpriteAppearances::releaseDecodedSpriteSheets()
{
    for (const auto& sheet : m_sheets) {
        if (sheet->m_loadingState.load(std::memory_order_acquire) == SpriteLoadState::LOADING)
            continue;
        sheet->data.reset();
        sheet->m_loadingState.store(SpriteLoadState::NONE, std::memory_order_release);
    }
}
#endif
