/*
 * Copyright (c) 2010-2025 OTClient
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

#include "ttfloader.h"
#include "bitmapfont.h"
#include "image.h"
#include "texturemanager.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <framework/core/filestream.h>
#include <framework/core/logger.h>
#include <framework/core/resourcemanager.h>
#include <iomanip>
#include <memory>
#include <sstream>
#include <type_traits>

#ifdef max
#undef max
#endif
#ifdef min
#undef min
#endif

FT_Library TTFLoader::s_library = nullptr;
bool TTFLoader::s_initialized = false;

void TTFLoader::init() {
  if (s_initialized)
    return;

  if (FT_Init_FreeType(&s_library)) {
    g_logger.error("Failed to initialize FreeType library");
    return;
  }

  s_initialized = true;
}

void TTFLoader::terminate() {
  if (!s_initialized)
    return;

  FT_Done_FreeType(s_library);
  s_initialized = false;
}

BitmapFontPtr TTFLoader::load(const std::string &file, int fontSize,
                              int strokeWidth, const Color &strokeColor) {
  if (!s_initialized) {
    g_logger.error(
        "FreeType library not initialized. Call TTFLoader::init() first");
    return nullptr;
  }

  struct FTFaceDeleter {
    void operator()(FT_Face face) const noexcept {
      if (face) {
        FT_Done_Face(face);
      }
    }
  };

  struct FTStrokerDeleter {
    void operator()(FT_Stroker stroker) const noexcept {
      if (stroker) {
        FT_Stroker_Done(stroker);
      }
    }
  };

  using FacePtr =
      std::unique_ptr<std::remove_pointer_t<FT_Face>, FTFaceDeleter>;
  using StrokerPtr =
      std::unique_ptr<std::remove_pointer_t<FT_Stroker>, FTStrokerDeleter>;

  try {

    std::string resolvedPath;
    std::string fileName = file;

    std::string lowerFileName = fileName;
    std::transform(lowerFileName.begin(), lowerFileName.end(),
                   lowerFileName.begin(),
                   [](unsigned char c) { return (char)std::tolower(c); });

    const bool hasTtfSuffix =
      lowerFileName.size() >= 4 &&
      lowerFileName.compare(lowerFileName.size() - 4, 4, ".ttf") == 0;
    const bool hasOtfSuffix =
      lowerFileName.size() >= 4 &&
      lowerFileName.compare(lowerFileName.size() - 4, 4, ".otf") == 0;

    if (!hasTtfSuffix && !hasOtfSuffix) {
      fileName += ".ttf";
    }

    // Search paths for the font file
    std::vector<std::string> searchPaths = {
      fileName,                      // Original path
      "/data/fonts/ttf/" + fileName, // Default TTF directory
      "data/fonts/ttf/" + fileName   // Without leading slash
    };

    // If already absolute in resources, don't prepend search paths
    if (fileName.starts_with("/")) {
      searchPaths = {fileName};
    }

    for (const auto &path : searchPaths) {
      if (g_resources.fileExists(path)) {
        resolvedPath = path;
        break;
      }
    }

    if (resolvedPath.empty()) {
      g_logger.error("TTF font file not found: {} (searched in /data/fonts/ "
                     "and other locations)",
                     file);
      return nullptr;
    }

    std::string fontBuffer = g_resources.readFileContents(resolvedPath);

    if (fontBuffer.empty()) {
      g_logger.error("Failed to read TTF file: " + file);
      return nullptr;
    }

    FT_Face face = nullptr;
    if (FT_New_Memory_Face(s_library,
                           reinterpret_cast<const FT_Byte *>(fontBuffer.data()),
                           fontBuffer.size(), 0, &face)) {
      g_logger.error("Failed to load TTF font: " + file);
      return nullptr;
    }

    FacePtr faceGuard(face);

    if (FT_Set_Pixel_Sizes(face, 0, fontSize)) {
      g_logger.error("Failed to set font size: " + file);
      return nullptr;
    }

    std::string fontName = file;

    size_t lastDot = fontName.find_last_of('.');
    if (lastDot != std::string::npos) {
      fontName = fontName.substr(0, lastDot);
    }

    size_t lastSlash = fontName.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
      fontName = fontName.substr(lastSlash + 1);
    }

    fontName = fontName + "_" + std::to_string(fontSize);

    // Include stroke settings in the font cache key
    if (strokeWidth > 0) {
      std::ostringstream colorStream;
      colorStream << std::hex << std::setfill('0') << std::setw(2)
                  << (int)strokeColor.r() << std::setw(2)
                  << (int)strokeColor.g() << std::setw(2)
                  << (int)strokeColor.b() << std::setw(2)
                  << (int)strokeColor.a();
      fontName += "_s" + std::to_string(strokeWidth) + "_" + colorStream.str();
    }

    auto font = std::make_shared<BitmapFont>(fontName);

    // Rasterize glyphs and collect metrics
    const int firstGlyph = 32;
    const int lastGlyph = 255;
    const int padding = 2;

    int maxGlyphWidth = 0;
    int maxGlyphHeight = 0;
    Size glyphsSize[256];    // Bitmap size
    int glyphsAdvance[256];  // Horizontal advance
    int glyphsBearingX[256]; // Bearing X
    int glyphsBearingY[256]; // Bearing Y (baseline)

    // Initialize metrics arrays
    for (int i = 0; i < 256; ++i) {
      glyphsSize[i] = Size(0, 0);
      glyphsAdvance[i] = 0;
      glyphsBearingX[i] = 0;
      glyphsBearingY[i] = 0;
    }

    // Create stroker (optional outline)
    FT_Stroker stroker = nullptr;
    StrokerPtr strokerGuard;
    if (strokeWidth > 0) {
      if (FT_Stroker_New(s_library, &stroker)) {
        g_logger.error("Failed to create FreeType stroker");
        strokeWidth = 0; // Disable stroke on error
      } else {
        strokerGuard.reset(stroker);
        // strokeWidth is in pixels; FreeType uses 26.6 fixed-point units
        FT_Stroker_Set(stroker, strokeWidth * 64, FT_STROKER_LINECAP_ROUND,
                       FT_STROKER_LINEJOIN_ROUND, 0);
      }
    }

    for (int i = firstGlyph; i <= lastGlyph; ++i) {
      if (FT_Load_Char(face, i, FT_LOAD_DEFAULT)) {
        continue;
      }

      FT_GlyphSlot slot = face->glyph;

      int width = 0;
      int height = 0;
      int advance = (int)((slot->advance.x + 32) >> 6);
      if (strokeWidth > 0) {
        advance += strokeWidth;
      }
      int bearingX = 0;
      int bearingY = 0;

      if (strokeWidth > 0 && stroker) {
        // Get outline glyph
        FT_Glyph glyph;
        if (FT_Get_Glyph(slot, &glyph) == 0) {
          if (FT_Glyph_StrokeBorder(&glyph, stroker, 0, 1) != 0) {
            FT_Done_Glyph(glyph);
            continue;
          }
          if (glyph->format == FT_GLYPH_FORMAT_OUTLINE) {
            if (FT_Glyph_To_Bitmap(&glyph, FT_RENDER_MODE_NORMAL, nullptr, 1) != 0) {
              FT_Done_Glyph(glyph);
              continue;
            }
          }
          if (glyph->format != FT_GLYPH_FORMAT_BITMAP) {
            FT_Done_Glyph(glyph);
            continue;
          }
          FT_BitmapGlyph bitmapGlyph = reinterpret_cast<FT_BitmapGlyph>(glyph);
          width = (int)bitmapGlyph->bitmap.width;
          height = (int)bitmapGlyph->bitmap.rows;
          bearingX = bitmapGlyph->left;
          bearingY = bitmapGlyph->top;

          FT_Done_Glyph(glyph);
        }
      } else {
        // Rasterize without stroke
        if (FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) == 0) {
          width = (int)slot->bitmap.width;
          height = (int)slot->bitmap.rows;
          bearingX = (int)slot->bitmap_left;
          bearingY = (int)slot->bitmap_top;
        }
      }

      glyphsSize[i] = Size(width, height);
      glyphsAdvance[i] = advance;
      glyphsBearingX[i] = bearingX;
      glyphsBearingY[i] = bearingY;

      maxGlyphWidth = std::max(maxGlyphWidth, width);
      maxGlyphHeight = std::max(maxGlyphHeight, height);
    }

    // Compute atlas dimensions
    const int glyphsPerRow = 16;
    const int rows = (256 + glyphsPerRow - 1) / glyphsPerRow;
    const int atlasWidth = glyphsPerRow * (maxGlyphWidth + padding);
    const int atlasHeight = rows * (maxGlyphHeight + padding);

    // Create RGBA atlas
    std::vector<uint8_t> atlasPixels(atlasWidth * atlasHeight * 4, 0);

    Rect glyphsCoords[256];
    for (int i = 0; i < 256; ++i) {
      glyphsCoords[i] = Rect(0, 0, 0, 0);
    }

    for (int i = firstGlyph; i <= lastGlyph; ++i) {
      if (glyphsSize[i].width() == 0 || glyphsSize[i].height() == 0) {
        glyphsCoords[i] = Rect(0, 0, 0, 0);
        continue;
      }

      if (FT_Load_Char(face, i, FT_LOAD_DEFAULT)) {
        continue;
      }

      FT_GlyphSlot slot = face->glyph;

      const int col = i % glyphsPerRow;
      const int row = i / glyphsPerRow;
      const int atlasX = col * (maxGlyphWidth + padding);
      const int atlasY = row * (maxGlyphHeight + padding);

      glyphsCoords[i] =
          Rect(atlasX, atlasY, glyphsSize[i].width(), glyphsSize[i].height());

      if (strokeWidth > 0 && stroker) {
        const auto blendPixelRGBA = [&](int dstIdx, uint8_t srcR, uint8_t srcG,
                                        uint8_t srcB, uint8_t srcA) {
          if (srcA == 0)
            return;

          const float srcAf = srcA / 255.f;
          const float dstAf = atlasPixels[dstIdx + 3] / 255.f;
          const float outAf = srcAf + dstAf * (1.f - srcAf);

          if (outAf <= 0.f) {
            atlasPixels[dstIdx + 0] = 0;
            atlasPixels[dstIdx + 1] = 0;
            atlasPixels[dstIdx + 2] = 0;
            atlasPixels[dstIdx + 3] = 0;
            return;
          }

          const float dstRf = atlasPixels[dstIdx + 0] / 255.f;
          const float dstGf = atlasPixels[dstIdx + 1] / 255.f;
          const float dstBf = atlasPixels[dstIdx + 2] / 255.f;

          const float srcRf = srcR / 255.f;
          const float srcGf = srcG / 255.f;
          const float srcBf = srcB / 255.f;

          const float outRf = (srcRf * srcAf + dstRf * dstAf * (1.f - srcAf)) / outAf;
          const float outGf = (srcGf * srcAf + dstGf * dstAf * (1.f - srcAf)) / outAf;
          const float outBf = (srcBf * srcAf + dstBf * dstAf * (1.f - srcAf)) / outAf;

          atlasPixels[dstIdx + 0] = (uint8_t)std::clamp(outRf * 255.f, 0.f, 255.f);
          atlasPixels[dstIdx + 1] = (uint8_t)std::clamp(outGf * 255.f, 0.f, 255.f);
          atlasPixels[dstIdx + 2] = (uint8_t)std::clamp(outBf * 255.f, 0.f, 255.f);
          atlasPixels[dstIdx + 3] = (uint8_t)std::clamp(outAf * 255.f, 0.f, 255.f);
        };

        // Draw stroke first (background)
        FT_Glyph strokeGlyph;
        if (FT_Get_Glyph(slot, &strokeGlyph) == 0) {
          if (FT_Glyph_StrokeBorder(&strokeGlyph, stroker, 0, 1) != 0) {
            FT_Done_Glyph(strokeGlyph);
            continue;
          }
          if (strokeGlyph->format == FT_GLYPH_FORMAT_OUTLINE) {
            if (FT_Glyph_To_Bitmap(&strokeGlyph, FT_RENDER_MODE_NORMAL, nullptr, 1) != 0) {
              FT_Done_Glyph(strokeGlyph);
              continue;
            }
          }
          if (strokeGlyph->format != FT_GLYPH_FORMAT_BITMAP) {
            FT_Done_Glyph(strokeGlyph);
            continue;
          }

          FT_BitmapGlyph strokeBitmapGlyph = reinterpret_cast<FT_BitmapGlyph>(strokeGlyph);
          const FT_Bitmap &strokeBitmap = strokeBitmapGlyph->bitmap;
          const int strokeLeft = strokeBitmapGlyph->left;
          const int strokeTop = strokeBitmapGlyph->top;

          const int copyWidth =
              std::min((int)strokeBitmap.width, glyphsSize[i].width());
          const int copyHeight =
              std::min((int)strokeBitmap.rows, glyphsSize[i].height());

          // Draw stroke
          if (strokeBitmap.buffer && strokeBitmap.pitch != 0) {
            const int pitch = (int)strokeBitmap.pitch;
            const int bmpRows = (int)strokeBitmap.rows;

            for (int y = 0; y < copyHeight; ++y) {
              const int rowOffset = (pitch > 0) ? (y * pitch)
                                               : ((bmpRows - 1 - y) * -pitch);
              for (int x = 0; x < copyWidth; ++x) {
                const int srcIdx = rowOffset + x;
                const int dstX = atlasX + x;
                const int dstY = atlasY + y;
                const int dstIdx = (dstY * atlasWidth + dstX) * 4;

                const uint8_t alpha = strokeBitmap.buffer[srcIdx];
                const uint8_t outAlpha = (uint8_t)((alpha * (int)strokeColor.a() + 127) / 255);

                if (outAlpha > 0)
                  blendPixelRGBA(dstIdx, strokeColor.r(), strokeColor.g(),
                                 strokeColor.b(), outAlpha);
              }
            }
          }

          // Draw original glyph on top, aligned using bearings (baseline origin)
          if (FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) == 0) {
            const FT_Bitmap &bitmap = slot->bitmap;

            // Align fill bitmap to the stroked glyph using FreeType bearings.
            // (Avoid centering, which causes uneven/"textured" outlines at small sizes.)
            const int fillLeft = (int)slot->bitmap_left;
            const int fillTop = (int)slot->bitmap_top;
            const int offsetX = fillLeft - strokeLeft;
            const int offsetY = strokeTop - fillTop;

            const int glyphW = glyphsSize[i].width();
            const int glyphH = glyphsSize[i].height();
            const int bitmapW = (int)bitmap.width;
            const int bitmapH = (int)bitmap.rows;

            if (bitmap.buffer && glyphW > 0 && glyphH > 0 && bitmapW > 0 &&
                bitmapH > 0 && bitmap.pitch != 0) {
              // If offsets are negative, skip pixels from the source and clamp
              // the destination to the glyph cell.
              const int srcX0 = std::max(0, -offsetX);
              const int srcY0 = std::max(0, -offsetY);
              const int dstX0 = atlasX + std::max(0, offsetX);
              const int dstY0 = atlasY + std::max(0, offsetY);

              int copyWidth = bitmapW - srcX0;
              int copyHeight = bitmapH - srcY0;

              copyWidth = std::min(copyWidth, glyphW - std::max(0, offsetX));
              copyHeight = std::min(copyHeight, glyphH - std::max(0, offsetY));

              copyWidth = std::min(copyWidth, atlasWidth - dstX0);
              copyHeight = std::min(copyHeight, atlasHeight - dstY0);

              if (copyWidth > 0 && copyHeight > 0) {
                const int absPitch = std::abs((int)bitmap.pitch);
                const auto getRowPtr = [&](int row) -> const uint8_t * {
                  if (bitmap.pitch > 0) {
                    return bitmap.buffer + row * bitmap.pitch;
                  }
                  // Negative pitch means rows are stored bottom-up.
                  return bitmap.buffer + (bitmapH - 1 - row) * absPitch;
                };

                for (int y = 0; y < copyHeight; ++y) {
                  const int srcRow = srcY0 + y;
                  const int dstY = dstY0 + y;
                  if (dstY < 0 || dstY >= atlasHeight) {
                    continue;
                  }

                  const uint8_t *srcRowPtr = getRowPtr(srcRow);
                  for (int x = 0; x < copyWidth; ++x) {
                    const int srcCol = srcX0 + x;
                    const int dstX = dstX0 + x;
                    if (dstX < 0 || dstX >= atlasWidth) {
                      continue;
                    }

                    const uint8_t alpha = srcRowPtr[srcCol];
                    if (alpha > 0) {
                      const int dstIdx = (dstY * atlasWidth + dstX) * 4;
                      // Composite fill over stroke so the outline stays continuous
                      // through anti-aliased edges (important for small font sizes).
                      blendPixelRGBA(dstIdx, 255, 255, 255, alpha);
                    }
                  }
                }
              }
            }
          }

          FT_Done_Glyph(strokeGlyph);
        }
      } else {
        // Draw without stroke
        if (FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) == 0) {
          const FT_Bitmap &bitmap = slot->bitmap;

          const int copyWidth =
              std::min((int)bitmap.width, glyphsSize[i].width());
          const int copyHeight =
              std::min((int)bitmap.rows, glyphsSize[i].height());

          if (bitmap.buffer && bitmap.pitch != 0) {
            const int pitch = (int)bitmap.pitch;
            const int bmpRows = (int)bitmap.rows;

            for (int y = 0; y < copyHeight; ++y) {
              const int rowOffset = (pitch > 0) ? (y * pitch)
                                               : ((bmpRows - 1 - y) * -pitch);
              for (int x = 0; x < copyWidth; ++x) {
                const int srcIdx = rowOffset + x;
                const int dstX = atlasX + x;
                const int dstY = atlasY + y;
                const int dstIdx = (dstY * atlasWidth + dstX) * 4;

                const uint8_t alpha = bitmap.buffer[srcIdx];

                atlasPixels[dstIdx + 0] = 255;
                atlasPixels[dstIdx + 1] = 255;
                atlasPixels[dstIdx + 2] = 255;
                atlasPixels[dstIdx + 3] = alpha;
              }
            }
          }
        }
      }
    }

    ImagePtr image = std::make_shared<Image>(Size(atlasWidth, atlasHeight), 4,
                                             atlasPixels.data());
    TexturePtr texture = TexturePtr(new Texture(image));
    texture->setSmooth(true);

    // Font metrics for baseline/alignment
    int ascender = (int)(face->size->metrics.ascender >> 6);
    int descender = (int)(face->size->metrics.descender >> 6);
    int lineHeight = (int)(face->size->metrics.height >> 6);

    // Compute vertical extents for baseline normalization
    int minYOffset = 0;
    int maxYOffset = 0;

    for (int i = firstGlyph; i <= lastGlyph; ++i) {
      if (glyphsSize[i].height() > 0) {

        int yOffset = ascender - glyphsBearingY[i];
        minYOffset = std::min(minYOffset, yOffset);
        maxYOffset = std::max(maxYOffset, yOffset + glyphsSize[i].height());
      }
    }

    int yShift = (minYOffset < 0) ? -minYOffset : 0;

    font->m_texture = texture;
    font->m_glyphHeight = std::max(lineHeight, maxYOffset - minYOffset);
    font->m_firstGlyph = 32;
    font->m_yOffset = yShift;
    font->m_glyphSpacing = Size(0, 0);

    for (int i = 0; i < 256; ++i) {

      font->m_glyphsSize[i] = glyphsSize[i];
      font->m_glyphsTextureCoords[i] = glyphsCoords[i];

      if (glyphsSize[i].height() > 0) {
        int offsetY = ascender - glyphsBearingY[i] + yShift;
        font->m_glyphsOffset[i] = Point(glyphsBearingX[i], offsetY);
      } else {

        font->m_glyphsOffset[i] = Point(0, 0);
      }

      if (glyphsAdvance[i] > 0) {
        font->m_glyphsAdvance[i] = glyphsAdvance[i];
      } else if (glyphsSize[i].width() > 0) {

        font->m_glyphsAdvance[i] =
            glyphsSize[i].width() + std::max(0, glyphsBearingX[i]);
      } else {

        font->m_glyphsAdvance[i] = 0;
      }
    }

    if (font->m_glyphsAdvance[32] <= 0) {
      font->m_glyphsAdvance[32] = fontSize / 3;
    }
    font->m_glyphsSize[32] = Size(0, 0);    // Space has no bitmap
    font->m_glyphsOffset[32] = Point(0, 0); // Space has no offset

    // Special characters
    font->m_glyphsSize[127].setWidth(1);
    font->m_glyphsAdvance[127] = 1;
    font->m_glyphsSize[static_cast<int>('\n')] = Size(1, font->m_glyphHeight);
    font->m_glyphsAdvance[static_cast<int>('\n')] = 0;

    return font;

  } catch (const std::exception &e) {
    g_logger.error("Exception loading TTF font " + file + ": " +
                   std::string(e.what()));
    return nullptr;
  }
}
