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

#include "painter.h"

#include "framework/graphics/texture.h"
#include "framework/graphics/texturemanager.h"
#include "shader/shadersources.h"
#include <framework/platform/platformwindow.h>

std::unique_ptr<Painter> g_painter = nullptr;

/**
   * Painter using OpenGL 2.0 programmable rendering pipeline,
   * compatible with OpenGL ES 2.0. Only recent cards support
   * this painter engine.
   */
Painter::Painter()
{
    setResolution(g_window.getSize());

    const auto& getProgram = [](const std::string_view vertexSourceCode, const std::string_view fragmentSourceCode) {
        auto program = std::make_shared<PainterShaderProgram>();
        assert(program);
        program->addShaderFromSourceCode(ShaderType::VERTEX, vertexSourceCode);
        program->addShaderFromSourceCode(ShaderType::FRAGMENT, fragmentSourceCode);
        program->link();
        return program;
    };

    m_drawTexturedProgram = getProgram(std::string{ glslMainWithTexCoordsVertexShader } + glslPositionOnlyVertexShader.data(), std::string{ glslMainFragmentShader } + glslTextureSrcFragmentShader.data());
    m_drawSolidColorProgram = getProgram(std::string{ glslMainVertexShader } + glslPositionOnlyVertexShader.data(), std::string{ glslMainFragmentShader } + glslSolidColorFragmentShader.data());
    m_drawReplaceColorProgram = getProgram(std::string{ glslMainWithTexCoordsVertexShader } + glslPositionOnlyVertexShader.data(), std::string{ glslMainFragmentShader } + glslReplaceColorFragmentShader.data());
    m_drawLineProgram = getProgram(lineVertexShader, lineFragmentShader);

    PainterShaderProgram::release();

    refreshState();

    // vertex and texture coord attributes are always enabled
    // to avoid massive enable/disables, thus improving frame rate
    PainterShaderProgram::enableAttributeArray(PainterShaderProgram::VERTEX_ATTR);
    PainterShaderProgram::enableAttributeArray(PainterShaderProgram::TEXCOORD_ATTR);
}

void Painter::drawCoords(const CoordsBuffer& coordsBuffer, DrawMode drawMode)
{
    const int vertexCount = coordsBuffer.getVertexCount();
    if (vertexCount == 0)
        return;

    if (coordsBuffer.getTextureCoordCount() > 0 && m_glTextureId == 0)
        return;

    const bool textured = coordsBuffer.getTextureCoordCount() > 0 && m_glTextureId > 0;

    m_drawProgram = m_shaderProgram ? m_shaderProgram : textured ? m_drawTexturedProgram.get() : m_drawSolidColorProgram.get();

    // update shader with the current painter state
    m_drawProgram->bind();
    m_drawProgram->setTransformMatrix(m_transformMatrix);
    m_drawProgram->setProjectionMatrix(m_projectionMatrix);
    m_drawProgram->setOpacity(m_opacity);
    m_drawProgram->setColor(m_color);
    m_drawProgram->setResolution(m_resolution);
    m_drawProgram->updateTime();

    // only set texture coords arrays when needed
    if (textured) {
        m_drawProgram->setTextureMatrix(m_textureMatrix);
        m_drawProgram->bindMultiTextures();
        m_drawProgram->setAttributeArray(PainterShaderProgram::TEXCOORD_ATTR, coordsBuffer.getTextureCoordArray(), 2);
    } else
        PainterShaderProgram::disableAttributeArray(PainterShaderProgram::TEXCOORD_ATTR);

    // set vertex array
    m_drawProgram->setAttributeArray(PainterShaderProgram::VERTEX_ATTR, coordsBuffer.getVertexArray(), 2);

    // draw the element in coords buffers
    glDrawArrays(static_cast<GLenum>(drawMode), 0, vertexCount);

    if (!textured)
        PainterShaderProgram::enableAttributeArray(PainterShaderProgram::TEXCOORD_ATTR);
}

void Painter::drawLine(const std::vector<float>& vertex, const int size, const int width) const
{
    m_drawLineProgram->bind();
    m_drawLineProgram->setTransformMatrix(m_transformMatrix);
    m_drawLineProgram->setProjectionMatrix(m_projectionMatrix);
    m_drawLineProgram->setTextureMatrix(m_textureMatrix);
    m_drawLineProgram->setColor(m_color);
#ifndef OPENGL_ES
    glEnable(GL_LINE_SMOOTH);
#endif
    glLineWidth(width);

    PainterShaderProgram::disableAttributeArray(PainterShaderProgram::TEXCOORD_ATTR);
    m_drawLineProgram->setAttributeArray(PainterShaderProgram::VERTEX_ATTR, vertex.data(), 2);

    glDrawArrays(GL_LINE_STRIP, 0, size);

    PainterShaderProgram::enableAttributeArray(PainterShaderProgram::TEXCOORD_ATTR);
#ifndef OPENGL_ES
    glDisable(GL_LINE_SMOOTH);
#endif
}

void Painter::resetState()
{
    resetColor();
    resetOpacity();
    resetCompositionMode();
    resetBlendEquation();
    resetClipRect();
    resetShaderProgram();
    resetAlphaWriting();
    resetTransformMatrix();
}

void Painter::refreshState() const {
    updateGlViewport();
    updateGlCompositionMode();
    updateGlBlendEquation();
    updateGlClipRect();
    updateGlTexture();
    updateGlAlphaWriting();
}

void Painter::clear(const Color& color)
{
    glClearColor(color.rF(), color.gF(), color.bF(), color.aF());
    glClear(GL_COLOR_BUFFER_BIT);
}

void Painter::clearRect(const Color& color, const Rect& rect)
{
    const auto& oldClipRect = m_clipRect;
    setClipRect(rect);
    glClearColor(color.rF(), color.gF(), color.bF(), color.aF());
    glClear(GL_COLOR_BUFFER_BIT);
    setClipRect(oldClipRect);
}

void Painter::setCompositionMode(const CompositionMode compositionMode)
{
    if (m_compositionMode == compositionMode)
        return;

    m_compositionMode = compositionMode;
    updateGlCompositionMode();
}

void Painter::setBlendEquation(const BlendEquation blendEquation)
{
    if (m_blendEquation == blendEquation)
        return;

    m_blendEquation = blendEquation;
    updateGlBlendEquation();
}

void Painter::setClipRect(const Rect& clipRect)
{
    if (m_clipRect == clipRect)
        return;

    m_clipRect = clipRect;
    updateGlClipRect();
}

void Painter::setTexture(const TexturePtr& texture) {
    if (texture) setTexture(texture->getId(), texture->getTransformMatrixId());
    else resetTexture();
}

void Painter::setTexture(uint32_t textureId, uint16_t textureMatrixId)
{
    if (m_glTextureId == textureId)
        return;

    m_glTextureId = textureId;
    if (textureId == 0) {
        return;
    }

    setTextureMatrix(g_textures.getMatrixById(textureMatrixId));
    updateGlTexture();
}

void Painter::setAlphaWriting(const bool enable)
{
    if (m_alphaWriting == enable)
        return;

    m_alphaWriting = enable;
    updateGlAlphaWriting();
}

void Painter::setResolution(const Size& resolution, const Matrix3& projectionMatrix)
{
    if (resolution == m_resolution)
        return;

    setProjectionMatrix(projectionMatrix == DEFAULT_MATRIX3 ? getTransformMatrix(resolution) : projectionMatrix);

    m_resolution = resolution;
    updateGlViewport();
}

Matrix3 Painter::getTransformMatrix(const Size& resolution) const
{
    // The projection matrix converts from Painter's coordinate system to GL's coordinate system
    //    * GL's viewport is 2x2, Painter's is width x height
    //    * GL has +y -> -y going from bottom -> top, Painter is the other way round
    //    * GL has [0,0] in the center, Painter has it in the top-left
    //
    // This results in the Projection matrix below.
    //
    //                                    Projection Matrix
    //   Painter Coord     ------------------------------------------------        GL Coord
    //   -------------     | 2.0 / width  |      0.0      |      0.0      |     ---------------
    //   |  x  y  1  |  *  |     0.0      | -2.0 / height |      0.0      |  =  |  x'  y'  1  |
    //   -------------     |    -1.0      |      1.0      |      1.0      |     ---------------

    return { 2.0f / resolution.width(),  0.0f,                       0.0f,
                                  0.0f, -2.0f / resolution.height(), 0.0f,
                                 -1.0f,  1.0f,                       1.0f };
}

void Painter::updateGlCompositionMode() const
{
    switch (m_compositionMode) {
        case CompositionMode::NORMAL:
            glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
            break;
        case CompositionMode::MULTIPLY:
            glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
            break;
        case CompositionMode::ADD:
            glBlendFunc(GL_ONE_MINUS_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR);
            break;
        case CompositionMode::REPLACE:
            glBlendFunc(GL_ONE, GL_ZERO);
            break;
        case CompositionMode::DESTINATION_BLENDING:
            glBlendFunc(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA);
            break;
        case CompositionMode::LIGHT:
            glBlendFunc(GL_ZERO, GL_SRC_COLOR);
            break;
    }
}

void Painter::updateGlClipRect() const
{
    if (m_clipRect.isValid()) {
        glEnable(GL_SCISSOR_TEST);
        glScissor(m_clipRect.left(), m_resolution.height() - m_clipRect.bottom() - 1, m_clipRect.width(), m_clipRect.height());
    } else {
        glScissor(0, 0, m_resolution.width(), m_resolution.height());
        glDisable(GL_SCISSOR_TEST);
    }
}
void Painter::updateGlTexture() const { if (m_glTextureId != 0) glBindTexture(GL_TEXTURE_2D, m_glTextureId); }
void Painter::updateGlBlendEquation() const { glBlendEquation(static_cast<GLenum>(m_blendEquation)); }
void Painter::updateGlAlphaWriting() const { glColorMask(1, 1, 1, m_alphaWriting); }
void Painter::updateGlViewport() const { glViewport(0, 0, m_resolution.width(), m_resolution.height()); }