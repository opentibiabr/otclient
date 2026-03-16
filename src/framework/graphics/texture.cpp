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

#include "texture.h"

#include "drawpoolmanager.h"
#include "graphics.h"
#include "image.h"
#include "textureatlas.h"
#include "texturemanager.h"
#include "framework/core/eventdispatcher.h"
#include <framework/core/graphicalapplication.h>
#include <framework/util/stats.h>

 // UINT16_MAX = just to avoid conflicts with GL generated ID.
static std::atomic_uint32_t UID(UINT16_MAX);

Texture::Texture() : m_uniqueId(UID.fetch_add(1)) {
    generateHash();
    g_stats.addTexture();
}
Texture::Texture(const Size& size) : m_uniqueId(UID.fetch_add(1))
{
    generateHash();
    g_stats.addTexture();
    if (!setupSize(size))
        return;

    createTexture();
    bind();
    setupPixels(0, size, nullptr, 4);
    setupWrap();
    setupFilters();
}

Texture::Texture(const ImagePtr& image, const bool buildMipmaps, const bool compress) : m_uniqueId(UID.fetch_add(1))
{
    generateHash();
    g_stats.addTexture();

    setProp(Prop::compress, compress);
    setProp(Prop::buildMipmaps, buildMipmaps);
    m_image = image;
    setupSize(image->getSize());
}

Texture::~Texture()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    if (g_graphics.ok() && m_id != 0) {
        g_mainDispatcher.addEvent([id = m_id, smooth = isSmooth()]() mutable {
            g_drawPool.removeTextureFromAtlas(id, smooth);
            glDeleteTextures(1, &id);
        });
    }
    g_stats.removeTexture();
}

void Texture::create()
{
    if (m_image) {
        createTexture();
        uploadPixels(m_image, getProp(buildMipmaps), getProp(compress));
        m_image = nullptr;
    }
}

void Texture::updateImage(const ImagePtr& image) { m_image = image; setupSize(image->getSize()); }

void Texture::updatePixels(uint8_t* pixels, const int level, const int channels, const bool compress) {
    bind();
    setupPixels(level, m_size, pixels, channels, compress);
}
void Texture::uploadPixels(const ImagePtr& image, const bool buildMipmaps, const bool compress)
{
    if (!setupSize(image->getSize()))
        return;

    bind();

    uint_fast8_t level = 0;
    do {
        setupPixels(level++, image->getSize(), image->getPixelData(), image->getBpp(), compress);
    } while (buildMipmaps && image->nextMipmap());
    if (buildMipmaps) setProp(Prop::buildMipmaps, true);

    setupWrap();
    setupFilters();
}

void Texture::bind() { if (m_id) glBindTexture(GL_TEXTURE_2D, m_id); }

void Texture::buildHardwareMipmaps()
{
    if (getProp(hasMipMaps))
        return;

#ifndef OPENGL_ES
    if (!glGenerateMipmap)
        return;
#endif

    setProp(hasMipMaps, true);

    bind();
    setupFilters();
    glGenerateMipmap(GL_TEXTURE_2D);
}

void Texture::setSmooth(const bool smooth)
{
    if (smooth == getProp(Prop::smooth))
        return;

    setProp(Prop::smooth, smooth);

    if (!m_id) return;

    if (!canCacheInAtlas()) {
        bind();
        setupFilters();
    } else
        g_drawPool.removeTextureFromAtlas(m_id, !smooth);
}

void Texture::allowAtlasCache() {
    bool smooth = isSmooth();
    if (smooth) setSmooth(false);
    setProp(Prop::_allowAtlasCache, true);
    setSmooth(smooth);
}

void Texture::setRepeat(const bool repeat)
{
    if (getProp(Prop::repeat) == repeat)
        return;

    setProp(Prop::repeat, repeat);

    if (!m_id) return;

    bind();
    setupWrap();
}

void Texture::setUpsideDown(const bool upsideDown)
{
    if (getProp(Prop::upsideDown) == upsideDown)
        return;

    setProp(Prop::upsideDown, upsideDown);
    setupTranformMatrix();
}

void Texture::createTexture()
{
    if (g_graphics.ok() && m_id != 0)
        glDeleteTextures(1, &m_id);

    glGenTextures(1, &m_id);
    assert(m_id != 0);

    generateHash();
}

bool Texture::setupSize(const Size& size)
{
    if (m_size == size)
        return true;

    // checks texture max size
    if (std::max<int>(size.width(), size.height()) > g_graphics.getMaxTextureSize()) {
        g_logger.error(
            "loading texture with size {}x{} failed, "
            "the maximum size allowed by the graphics card is {}x{}, "
            "to prevent crashes the texture will be displayed as a blank texture",
            size.width(), size.height(), g_graphics.getMaxTextureSize(), g_graphics.getMaxTextureSize()
        );
        return false;
    }

    m_size = size;

    setupTranformMatrix();

    return true;
}

void Texture::setupWrap() const
{
    const GLint texParam = getProp(repeat) ? GL_REPEAT : GL_CLAMP_TO_EDGE;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, texParam);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, texParam);
}

void Texture::setupFilters() const
{
    if (!m_id) return;

    GLenum minFilter;
    GLenum magFilter;
    if (getProp(smooth)) {
        minFilter = getProp(hasMipMaps) ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR;
        magFilter = GL_LINEAR;
    } else {
        minFilter = getProp(hasMipMaps) ? GL_NEAREST_MIPMAP_NEAREST : GL_NEAREST;
        magFilter = GL_NEAREST;
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
}

void Texture::setupTranformMatrix()
{
    m_transformMatrixId = g_textures.getMatrixId(m_size, getProp(upsideDown));
}

const AtlasRegion* Texture::getAtlasRegion() const {
    if (g_drawPool.isValid() && g_drawPool.getAtlas()) {
        if (const auto region = m_atlas[g_drawPool.getAtlas()->getType()]) {
            return region->isEnabled() ? region : nullptr;
        }
    }

    return nullptr;
}

void Texture::setupPixels(const int level, const Size& size, const uint8_t* pixels, const int channels, const bool
#ifndef OPENGL_ES
                          compress
#endif
) const
{
    GLenum format = 0;
    GLenum internalFormat = GL_R8;
    switch (channels) {
        case 4:
            format = GL_RGBA;
            internalFormat = GL_RGBA;
            break;
        case 3:
            format = GL_RGB;
            internalFormat = GL_RGB;
            break;
        case 2:
            format = GL_LUMINANCE_ALPHA;
            break;
        case 1:
            format = GL_LUMINANCE;
            break;
    }

#ifdef OPENGL_ES
    //TODO
#else
    if (compress)
        internalFormat = GL_COMPRESSED_RGBA;
#endif

    glTexImage2D(GL_TEXTURE_2D, level, internalFormat, size.width(), size.height(), 0, format, GL_UNSIGNED_BYTE, pixels);
}
