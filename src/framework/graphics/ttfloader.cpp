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
#include <cmath>
#include <framework/core/filestream.h>
#include <framework/core/logger.h>
#include <framework/core/resourcemanager.h>
#include <iomanip>
#include <sstream>

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

  try {

    std::string resolvedPath;
    std::string fileName = file;

    if (fileName.find(".ttf") == std::string::npos &&
        fileName.find(".otf") == std::string::npos) {
      fileName += ".ttf";
    }

    // Lista de diretórios para procurar a fonte
    std::vector<std::string> searchPaths = {
        fileName,                      // Caminho original
        "/data/fonts/ttf/" + fileName, // Diretório padrão de fontes TTF
        "data/fonts/ttf/" + fileName   // Sem barra inicial
    };

    // Se fileName já começa com /, não duplicar
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

    FT_Face face;
    if (FT_New_Memory_Face(s_library,
                           reinterpret_cast<const FT_Byte *>(fontBuffer.data()),
                           fontBuffer.size(), 0, &face)) {
      g_logger.error("Failed to load TTF font: " + file);
      return nullptr;
    }

    if (FT_Set_Pixel_Sizes(face, 0, fontSize)) {
      g_logger.error("Failed to set font size: " + file);
      FT_Done_Face(face);
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

    // Adicionar stroke ao nome se houver
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

    // Renderizar glyphs
    const int firstGlyph = 32;
    const int lastGlyph = 255;
    const int padding = 2;

    int maxGlyphWidth = 0;
    int maxGlyphHeight = 0;
    Size glyphsSize[256];    // Tamanho visual do glyph (bitmap)
    int glyphsAdvance[256];  // Advance horizontal (para posicionamento)
    int glyphsBearingX[256]; // Offset X do bearing
    int glyphsBearingY[256]; // Offset Y do bearing (para baseline)

    // Inicializar
    for (int i = 0; i < 256; ++i) {
      glyphsSize[i] = Size(0, 0);
      glyphsAdvance[i] = 0;
      glyphsBearingX[i] = 0;
      glyphsBearingY[i] = 0;
    }

    // Criar stroker se necessário
    FT_Stroker stroker = nullptr;
    if (strokeWidth > 0) {
      if (FT_Stroker_New(s_library, &stroker)) {
        g_logger.error("Failed to create FreeType stroker");
        strokeWidth = 0; // Desabilitar stroke em caso de erro
      } else {
        // Configurar stroker (strokeWidth em pixels * 64 para unidades
        // FreeType)
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
        // Obter o glyph como outline
        FT_Glyph glyph;
        if (FT_Get_Glyph(slot, &glyph) == 0) {
          // Aplicar stroke
          FT_Glyph_StrokeBorder(&glyph, stroker, 0, 1);

          // Renderizar o glyph com stroke
          if (glyph->format == FT_GLYPH_FORMAT_OUTLINE) {
            FT_Glyph_To_Bitmap(&glyph, FT_RENDER_MODE_NORMAL, nullptr, 1);
          }

          FT_BitmapGlyph bitmapGlyph = (FT_BitmapGlyph)glyph;
          width = (int)bitmapGlyph->bitmap.width;
          height = (int)bitmapGlyph->bitmap.rows;
          bearingX = bitmapGlyph->left;
          bearingY = bitmapGlyph->top;

          FT_Done_Glyph(glyph);
        }
      } else {
        // Renderizar normalmente sem stroke
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

    // Calcular dimensões do atlas
    const int glyphsPerRow = 16;
    const int rows = (256 + glyphsPerRow - 1) / glyphsPerRow;
    const int atlasWidth = glyphsPerRow * (maxGlyphWidth + padding);
    const int atlasHeight = rows * (maxGlyphHeight + padding);

    // Criar atlas RGBA
    std::vector<uint8_t> atlasPixels(atlasWidth * atlasHeight * 4, 0);

    Rect glyphsCoords[256];

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
        // Renderizar stroke primeiro (fundo)
        FT_Glyph strokeGlyph;
        if (FT_Get_Glyph(slot, &strokeGlyph) == 0) {
          FT_Glyph_StrokeBorder(&strokeGlyph, stroker, 0, 1);

          if (strokeGlyph->format == FT_GLYPH_FORMAT_OUTLINE) {
            FT_Glyph_To_Bitmap(&strokeGlyph, FT_RENDER_MODE_NORMAL, nullptr, 1);
          }

          FT_BitmapGlyph strokeBitmapGlyph = (FT_BitmapGlyph)strokeGlyph;
          const FT_Bitmap &strokeBitmap = strokeBitmapGlyph->bitmap;

          const int copyWidth =
              std::min((int)strokeBitmap.width, glyphsSize[i].width());
          const int copyHeight =
              std::min((int)strokeBitmap.rows, glyphsSize[i].height());

          // Desenhar stroke
          for (int y = 0; y < copyHeight; ++y) {
            for (int x = 0; x < copyWidth; ++x) {
              const int srcIdx = y * strokeBitmap.pitch + x;
              const int dstX = atlasX + x;
              const int dstY = atlasY + y;
              const int dstIdx = (dstY * atlasWidth + dstX) * 4;

              const uint8_t alpha = strokeBitmap.buffer[srcIdx];

              if (alpha > 0) {
                atlasPixels[dstIdx + 0] = strokeColor.r(); // R
                atlasPixels[dstIdx + 1] = strokeColor.g(); // G
                atlasPixels[dstIdx + 2] = strokeColor.b(); // B
                atlasPixels[dstIdx + 3] = alpha;           // A
              }
            }
          }

          FT_Done_Glyph(strokeGlyph);
        }

        // Renderizar glyph original por cima
        if (FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) == 0) {
          const FT_Bitmap &bitmap = slot->bitmap;

          // Calcular offset para centralizar o glyph original sobre o stroke
          int offsetX = (glyphsSize[i].width() - (int)bitmap.width) / 2;
          int offsetY = (glyphsSize[i].height() - (int)bitmap.rows) / 2;

          const int copyWidth =
              std::min((int)bitmap.width, glyphsSize[i].width() - offsetX);
          const int copyHeight =
              std::min((int)bitmap.rows, glyphsSize[i].height() - offsetY);

          for (int y = 0; y < copyHeight; ++y) {
            for (int x = 0; x < copyWidth; ++x) {
              const int srcIdx = y * bitmap.pitch + x;
              const int dstX = atlasX + x + offsetX;
              const int dstY = atlasY + y + offsetY;
              const int dstIdx = (dstY * atlasWidth + dstX) * 4;

              const uint8_t alpha = bitmap.buffer[srcIdx];

              if (alpha > 0) {
                atlasPixels[dstIdx + 0] = 255;   // R
                atlasPixels[dstIdx + 1] = 255;   // G
                atlasPixels[dstIdx + 2] = 255;   // B
                atlasPixels[dstIdx + 3] = alpha; // A
              }
            }
          }
        }
      } else {
        // Renderizar normalmente sem stroke
        if (FT_Render_Glyph(slot, FT_RENDER_MODE_NORMAL) == 0) {
          const FT_Bitmap &bitmap = slot->bitmap;

          const int copyWidth =
              std::min((int)bitmap.width, glyphsSize[i].width());
          const int copyHeight =
              std::min((int)bitmap.rows, glyphsSize[i].height());

          for (int y = 0; y < copyHeight; ++y) {
            for (int x = 0; x < copyWidth; ++x) {
              const int srcIdx = y * bitmap.pitch + x;
              const int dstX = atlasX + x;
              const int dstY = atlasY + y;
              const int dstIdx = (dstY * atlasWidth + dstX) * 4;

              const uint8_t alpha = bitmap.buffer[srcIdx];

              atlasPixels[dstIdx + 0] = 255;   // R
              atlasPixels[dstIdx + 1] = 255;   // G
              atlasPixels[dstIdx + 2] = 255;   // B
              atlasPixels[dstIdx + 3] = alpha; // A
            }
          }
        }
      }
    }

    // Limpar stroker se foi criado
    if (stroker) {
      FT_Stroker_Done(stroker);
    }

    ImagePtr image = std::make_shared<Image>(Size(atlasWidth, atlasHeight), 4,
                                             atlasPixels.data());
    TexturePtr texture = TexturePtr(new Texture(image));
    texture->setSmooth(true);

    // Obter métricas da fonte para calcular a baseline
    int ascender = (int)(face->size->metrics.ascender >> 6);
    int descender = (int)(face->size->metrics.descender >> 6);
    int lineHeight = (int)(face->size->metrics.height >> 6);

    // Calcular o offset Y mínimo e máximo para normalizar
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
    font->m_glyphHeight =
        std::max(lineHeight, maxYOffset - minYOffset + yShift);
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
    font->m_glyphsSize[32] = Size(0, 0);    // Espaço não tem bitmap
    font->m_glyphsOffset[32] = Point(0, 0); // Espaço não tem offset

    // Caracteres especiais
    font->m_glyphsSize[127].setWidth(1);
    font->m_glyphsAdvance[127] = 1;
    font->m_glyphsSize[static_cast<int>('\n')] = Size(1, font->m_glyphHeight);
    font->m_glyphsAdvance[static_cast<int>('\n')] = 0;

    FT_Done_Face(face);

    return font;

  } catch (const std::exception &e) {
    g_logger.error("Exception loading TTF font " + file + ": " +
                   std::string(e.what()));
    return nullptr;
  }
}
