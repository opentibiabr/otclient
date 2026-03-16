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

#include <framework/graphics/declarations.h>
#include <framework/graphics/paintershaderprogram.h>
#include "coordsbuffer.h"

class Painter
{
public:
    Painter();

    void clear(const Color& color);
    void clearRect(const Color& color, const Rect& rect);

    void drawCoords(const CoordsBuffer& coordsBuffer, DrawMode drawMode = DrawMode::TRIANGLES);
    void drawLine(const std::vector<float>& vertex, int size, int width) const;

    float getOpacity() const { return m_opacity; }
    bool getAlphaWriting() const { return m_alphaWriting; }

    const auto& getTextureMatrix() const { return m_textureMatrix; }
    Matrix3 getTransformMatrix(const Size& size) const;
    Matrix3 getTransformMatrix() const { return m_transformMatrix; }
    Matrix3 getProjectionMatrix() const { return m_projectionMatrix; }

    Color getColor() const { return m_color; }
    Rect getClipRect() const { return m_clipRect; }
    Size getResolution() const { return m_resolution; }
    BlendEquation getBlendEquation() const { return m_blendEquation; }
    CompositionMode getCompositionMode() const { return m_compositionMode; }
    PainterShaderProgram* getShaderProgram() const { return m_shaderProgram; }
    PainterShaderProgramPtr getReplaceColorShader() const { return m_drawReplaceColorProgram; }

    void setColor(const Color& color) { if (m_color != color) m_color = color; }
    void setTexture(const TexturePtr&);
    void setTexture(uint32_t textureId, uint16_t textureMatrixId);
    void setOpacity(const float opacity) { m_opacity = opacity; }
    void setClipRect(const Rect& clipRect);
    void setResolution(const Size& resolution, const Matrix3& projectionMatrix = DEFAULT_MATRIX3);
    void setDrawProgram(PainterShaderProgram* drawProgram) { m_drawProgram = drawProgram; }
    void setAlphaWriting(bool enable);
    void setBlendEquation(BlendEquation blendEquation);
    void setShaderProgram(PainterShaderProgram* shaderProgram) { m_shaderProgram = shaderProgram; }
    void setShaderProgram(const PainterShaderProgramPtr& shaderProgram) { setShaderProgram(shaderProgram.get()); }
    void setCompositionMode(CompositionMode compositionMode);

    void setTextureMatrix(const Matrix3* matrix) { if (m_textureMatrix != matrix) m_textureMatrix = matrix; }
    void setTransformMatrix(const Matrix3& matrix) { if (m_transformMatrix != matrix) m_transformMatrix = matrix; }
    void setProjectionMatrix(const Matrix3& matrix) { if (m_projectionMatrix != matrix) m_projectionMatrix = matrix; }

    void resetState();
    void resetBlendEquation() { setBlendEquation(BlendEquation::ADD); }
    void resetTexture() { setTexture(0, 0); }
    void resetAlphaWriting() { setAlphaWriting(false); }
    void resetClipRect() { setClipRect({}); }
    void resetOpacity() { setOpacity(1.f); }
    void resetCompositionMode() { setCompositionMode(CompositionMode::NORMAL); }
    void resetColor() { setColor(Color::white); }
    void resetShaderProgram() { setShaderProgram(nullptr); }
    void resetTransformMatrix() { setTransformMatrix(DEFAULT_MATRIX3); }
    bool isReplaceColorShader(const PainterShaderProgram* shader) const { return m_drawReplaceColorProgram.get() == shader; }

protected:
    void refreshState() const;
    void updateGlTexture() const;
    void updateGlCompositionMode() const;
    void updateGlBlendEquation() const;
    void updateGlClipRect() const;
    void updateGlAlphaWriting() const;
    void updateGlViewport() const;

    Matrix3 m_transformMatrix;
    Matrix3 m_projectionMatrix;
    const Matrix3* m_textureMatrix = nullptr;

    BlendEquation m_blendEquation{ BlendEquation::ADD };
    bool m_alphaWriting{ false };
    uint32_t m_glTextureId{ 0 };

    float m_opacity{ 1.f };

    PainterShaderProgram* m_shaderProgram{ nullptr };
    CompositionMode m_compositionMode{ CompositionMode::NORMAL };
    Color m_color{ Color::white };
    Size m_resolution;
    Rect m_clipRect;

    friend class FrameBuffer;
    friend class DrawPoolManager;
    friend class DrawPool;

    PainterShaderProgram* m_drawProgram{ nullptr };
    PainterShaderProgramPtr m_drawTexturedProgram;
    PainterShaderProgramPtr m_drawSolidColorProgram;
    PainterShaderProgramPtr m_drawReplaceColorProgram;
    PainterShaderProgramPtr m_drawLineProgram;
};

extern std::unique_ptr<Painter> g_painter;
