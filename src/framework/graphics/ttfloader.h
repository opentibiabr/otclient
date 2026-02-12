/*
 * Copyright (c) 2010-2024 OTClient
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
 */

#pragma once

#include "declarations.h"
#include "bitmapfont.h"
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_STROKER_H

class TTFLoader
{
public:
    static void init();
    static void terminate();
    static BitmapFontPtr load(const std::string& file, int fontSize, int strokeWidth = 0, const Color& strokeColor = Color::black);

private:
    static FT_Library s_library;
    static bool s_initialized;

    static bool renderGlyphsToAtlas(FT_Face face, int fontSize, 
                                    std::vector<uint8_t>& atlasPixels,
                                    int& atlasWidth, int& atlasHeight,
                                    Size glyphsSize[256],
                                    Rect glyphsCoords[256],
                                    int& glyphHeight,
                                    int strokeWidth,
                                    const Color& strokeColor);
};
