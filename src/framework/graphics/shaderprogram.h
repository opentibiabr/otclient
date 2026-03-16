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

#include "declarations.h"
#include <framework/luaengine/luaobject.h>

 // @bindclass
class ShaderProgram : public LuaObject
{
    enum
    {
        MAX_UNIFORM_LOCATIONS = 30
    };

public:
    ShaderProgram();
    ~ShaderProgram() override;

    bool addShader(const ShaderPtr& shader);
    bool addShaderFromSourceCode(ShaderType shaderType, std::string_view sourceCode);
    bool addShaderFromSourceFile(ShaderType shaderType, std::string_view sourceFile);
    void removeShader(const ShaderPtr& shader);
    void removeAllShaders();
    virtual bool link();
    bool bind();
    static void release();
    std::string log() const;

    static void disableAttributeArray(const int location) { glDisableVertexAttribArray(location); }
    static void enableAttributeArray(const int location) { glEnableVertexAttribArray(location); }
    void disableAttributeArray(const char* name) const
    { glDisableVertexAttribArray(getAttributeLocation(name)); }
    void enableAttributeArray(const char* name) const
    { glEnableVertexAttribArray(getAttributeLocation(name)); }

    int getAttributeLocation(const char* name) const;
    void bindAttributeLocation(int location, const char* name) const;
    void bindUniformLocation(int location, const char* name);

    void setAttributeArray(const int location, const float* values, const int size, const int stride = 0) { glVertexAttribPointer(location, size, GL_FLOAT, GL_FALSE, stride, values); }
    void setAttributeValue(const int location, const float value) { glVertexAttrib1f(location, value); }
    void setAttributeValue(const int location, const float x, const float y) { glVertexAttrib2f(location, x, y); }
    void setAttributeValue(const int location, const float x, const float y, const float z) { glVertexAttrib3f(location, x, y, z); }
    void setAttributeArray(const char* name, const float* values, const int size, const int stride = 0) const
    { glVertexAttribPointer(getAttributeLocation(name), size, GL_FLOAT, GL_FALSE, stride, values); }
    void setAttributeValue(const char* name, const float value) const
    { glVertexAttrib1f(getAttributeLocation(name), value); }
    void setAttributeValue(const char* name, const float x, const float y) const
    { glVertexAttrib2f(getAttributeLocation(name), x, y); }
    void setAttributeValue(const char* name, const float x, const float y, const float z) const
    { glVertexAttrib3f(getAttributeLocation(name), x, y, z); }

    void setUniformValue(const int location, const Color& color) const
    { glUniform4f(m_uniformLocations[location], color.rF(), color.gF(), color.bF(), color.aF()); }
    void setUniformValue(const int location, const int value) const
    { glUniform1i(m_uniformLocations[location], value); }
    void setUniformValue(const int location, const float value) const
    { glUniform1f(m_uniformLocations[location], value); }
    void setUniformValue(const int location, const float x, const float y) const
    { glUniform2f(m_uniformLocations[location], x, y); }
    void setUniformValue(const int location, const float x, const float y, const float z) const
    { glUniform3f(m_uniformLocations[location], x, y, z); }
    void setUniformValue(const int location, const float x, const float y, const float z, const float w) const
    { glUniform4f(m_uniformLocations[location], x, y, z, w); }
    void setUniformValue(const int location, const Matrix2& mat) const
    { glUniformMatrix2fv(m_uniformLocations[location], 1, GL_FALSE, mat.data()); }
    void setUniformValue(const int location, const Matrix3& mat) const
    { glUniformMatrix3fv(m_uniformLocations[location], 1, GL_FALSE, mat.data()); }
    void setUniformValue(const char* name, const Color& color) const
    { glUniform4f(glGetUniformLocation(m_programId, name), color.rF(), color.gF(), color.bF(), color.aF()); }
    void setUniformValue(const char* name, const int value) const
    { glUniform1i(glGetUniformLocation(m_programId, name), value); }
    void setUniformValue(const char* name, const float value) const
    { glUniform1f(glGetUniformLocation(m_programId, name), value); }
    void setUniformValue(const char* name, const float x, const float y) const
    { glUniform2f(glGetUniformLocation(m_programId, name), x, y); }
    void setUniformValue(const char* name, const float x, const float y, const float z) const
    { glUniform3f(glGetUniformLocation(m_programId, name), x, y, z); }
    void setUniformValue(const char* name, const float x, const float y, const float z, const float w) const
    { glUniform4f(glGetUniformLocation(m_programId, name), x, y, z, w); }
    void setUniformValue(const char* name, const Matrix2& mat) const
    { glUniformMatrix2fv(glGetUniformLocation(m_programId, name), 1, GL_FALSE, mat.data()); }
    void setUniformValue(const char* name, const Matrix3& mat) const
    { glUniformMatrix3fv(glGetUniformLocation(m_programId, name), 1, GL_FALSE, mat.data()); }
    // TODO: Point, PointF, Color, Size, SizeF ?

    bool isLinked() const { return m_linked; }
    uint32_t getProgramId() const { return m_programId; }
    size_t hash() const { return m_hash; }
    ShaderList getShaders() { return m_shaders; }

private:
    bool m_linked{ false };
    uint32_t m_programId;
    size_t m_hash{ 0 };
    static uint32_t m_currentProgram;
    ShaderList m_shaders;
    std::array<int, MAX_UNIFORM_LOCATIONS> m_uniformLocations{ };
};
