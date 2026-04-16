/*
 * Copyright (c) 2010-2022 OTClient <https://github.com/edubart/otclient>
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

#ifdef ANDROID

#include "unzipper.h"
#include "logger.h"
#include "resourcemanager.h"
#include <filesystem>
#include "minizip/ioapi.h"
#include "minizip/ioapi_mem.h"
#include "minizip/unzip.h"

const int MAX_FILENAME = 512;
const int READ_SIZE = 8192;
const char dir_delimiter = '/';

void unzipper::extract(const char* fileBuffer, uint fileLength, std::string& destinationPath) {
    const std::filesystem::path destinationFolder { destinationPath };
    if (!std::filesystem::exists(destinationFolder)) {
        std::filesystem::create_directories(destinationFolder);
    }

    zlib_filefunc_def filefunc32 = { nullptr };
    ourmemory_t unzmem = {nullptr};

    unzmem.size = fileLength;
    unzmem.base = (char *)malloc(unzmem.size);
    memcpy(unzmem.base, fileBuffer, unzmem.size);
    fill_memory_filefunc(&filefunc32, &unzmem);
    unzFile zipfile = unzOpen2(nullptr, &filefunc32);

    // Get info about the zip file
    unz_global_info global_info;
    if ( unzGetGlobalInfo( zipfile, &global_info ) != UNZ_OK )
    {
        unzClose( zipfile );
        g_logger.fatal("could not read file global info");
    }

    uint readSize = 8192;
    // Buffer to hold data read from the zip file.
    char read_buffer[ readSize ];

    // Loop to extract all files
    u_long i;
    for ( i = 0; i < global_info.number_entry; ++i )
    {
        // Get info about current file.
        unz_file_info file_info;
        char filename[ MAX_FILENAME ];
        if ( unzGetCurrentFileInfo(
                zipfile,
                &file_info,
                filename,
                MAX_FILENAME,
                nullptr, 0, nullptr, 0 ) != UNZ_OK )
        {
            unzClose( zipfile );
            g_logger.fatal("could not read file info");
        }

        // Check if this entry is a directory or file.
        const size_t filename_length = strlen( filename );

        // Guard against zip-slip: reject entries that escape the destination folder
        const auto entryPath = std::filesystem::path(filename).lexically_normal();
        if (entryPath.is_absolute() || entryPath.string().starts_with("..")) {
            g_logger.warning("skipping zip entry with unsafe path: {}", filename);
            if ( ( i+1 ) < global_info.number_entry )
                unzGoToNextFile( zipfile );
            continue;
        }
        const auto outputPath = destinationFolder / entryPath;

        if (filename[ filename_length-1 ] == dir_delimiter )
        {
            std::filesystem::create_directories(outputPath);
        }
        else
        {
            // Entry is a file, so extract it.
            if ( unzOpenCurrentFile( zipfile ) != UNZ_OK )
            {
                unzClose( zipfile );
                g_logger.fatal("could not open file");
            }

            // Open a file to write out the data.
            const std::string destFilePath = outputPath.string();
            // Ensure parent directory exists (zip may not have explicit directory entries)
            const std::filesystem::path parentDir = outputPath.parent_path();
            if (!std::filesystem::exists(parentDir)) {
                std::filesystem::create_directories(parentDir);
            }
            FILE *out = fopen(destFilePath.c_str(), "wb");
            if ( out == nullptr )
            {
                unzCloseCurrentFile( zipfile );
                unzClose( zipfile );
                g_logger.fatal("could not open destination file");
            }

            int error = UNZ_OK;
            do
            {
                error = unzReadCurrentFile( zipfile, read_buffer, READ_SIZE );
                if (error < 0)
                {
                    unzCloseCurrentFile( zipfile );
                    unzClose(zipfile);
                    g_logger.fatal( &"error: " [ error] );
                }

                // Write data to file.
                if (error > 0)
                {
                    fwrite(read_buffer, error, 1, out);
                }
            } while (error > 0);

            fclose(out);
        }

        unzCloseCurrentFile( zipfile );

        // Go the the next entry listed in the zip file.
        if ( ( i+1 ) < global_info.number_entry )
        {
            if ( unzGoToNextFile( zipfile ) != UNZ_OK )
            {
                unzClose( zipfile );
                g_logger.fatal("cound not read next file");
            }
        }
    }

    unzClose(zipfile);
}

#endif