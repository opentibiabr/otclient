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

#include "graphics.h"

#include "fontmanager.h"
#include "painter.h"
#include "texturemanager.h"
#include <framework/core/logger.h>

Graphics g_graphics;

inline std::string_view glString(GLenum name) {
    const GLubyte* str = glGetString(name);
    return str ? reinterpret_cast<const char*>(str) : "";
}

void Graphics::init()
{
    if (const auto* v = reinterpret_cast<const char*>(glGetString(GL_VENDOR)))
        m_vendor = v;

    if (const auto* v = reinterpret_cast<const char*>(glGetString(GL_RENDERER)))
        m_renderer = v;

    if (const auto* v = reinterpret_cast<const char*>(glGetString(GL_VERSION)))
        m_version = v;

    if (const auto* v = reinterpret_cast<const char*>(glGetString(GL_EXTENSIONS)))
        m_extensions = v;

    g_logger.info("GPU {}", glString(GL_RENDERER));
    g_logger.info("OpenGL {}", glString(GL_VERSION));

#ifndef OPENGL_ES
    // init GL extensions
    const GLenum err = glewInit();
    if (err != GLEW_OK)
        g_logger.fatal("Unable to init GLEW: {}", glString(err));

    // overwrite framebuffer API if needed
    if (GLEW_EXT_framebuffer_object && !GLEW_ARB_framebuffer_object) {
        glGenFramebuffers = glGenFramebuffersEXT;
        glDeleteFramebuffers = glDeleteFramebuffersEXT;
        glBindFramebuffer = glBindFramebufferEXT;
        glFramebufferTexture2D = glFramebufferTexture2DEXT;
        glCheckFramebufferStatus = glCheckFramebufferStatusEXT;
        glGenerateMipmap = glGenerateMipmapEXT;
    }
#endif

    // blending is always enabled
    glEnable(GL_BLEND);

    // determine max texture size
    int maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    if (m_maxTextureSize == -1 || m_maxTextureSize > maxTextureSize)
        m_maxTextureSize = maxTextureSize;

    m_alphaBits = 0;
    glGetIntegerv(GL_ALPHA_BITS, &m_alphaBits);

    m_ok = true;

    g_painter = std::make_unique<Painter>();

    g_textures.init();

    g_fonts.init();   

}

void Graphics::terminate()
{
    g_painter = nullptr;
    g_fonts.terminate();
    g_textures.terminate();

    m_ok = false;
}

void Graphics::resize(const Size& size) { m_viewportSize = size; }