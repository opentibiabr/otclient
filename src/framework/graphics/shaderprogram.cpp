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

#include "shaderprogram.h"

#include "graphics.h"
#include "shader.h"
#include "client/creature.h"
#include "framework/core/eventdispatcher.h"
#include "framework/core/graphicalapplication.h"

uint32_t ShaderProgram::m_currentProgram = 0;

ShaderProgram::ShaderProgram() :m_programId(glCreateProgram())
{
    m_uniformLocations.fill(-1);
    if (!m_programId)
        g_logger.fatal("Unable to create GL shader program");
}

ShaderProgram::~ShaderProgram()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    if (g_graphics.ok()) {
        g_mainDispatcher.addEvent([id = m_programId] {
            glDeleteProgram(id);
        });
    }
}

bool ShaderProgram::addShader(const ShaderPtr& shader)
{
    glAttachShader(m_programId, shader->getShaderId());
    m_linked = false;
    m_shaders.emplace_back(shader);
    m_hash = stdext::hash_int(m_programId);
    return true;
}

bool ShaderProgram::addShaderFromSourceCode(ShaderType shaderType, const std::string_view sourceCode)
{
    const auto& shader = std::make_shared<Shader>(shaderType);
    if (shader->compileSourceCode(sourceCode))
        return addShader(shader);

    g_logger.error("failed to compile shader: {}", shader->log());
    return false;
}

bool ShaderProgram::addShaderFromSourceFile(ShaderType shaderType, const std::string_view sourceFile)
{
    const auto& shader = std::make_shared<Shader>(shaderType);
    if (shader->compileSourceFile(sourceFile))
        return addShader(shader);

    g_logger.error("failed to compile shader: {}", shader->log());
    return false;
}

void ShaderProgram::removeShader(const ShaderPtr& shader)
{
    const auto it = std::ranges::find(m_shaders, shader);
    if (it == m_shaders.end())
        return;

    glDetachShader(m_programId, shader->getShaderId());
    m_shaders.erase(it);
    m_linked = false;
    m_hash = 0;
}

void ShaderProgram::removeAllShaders()
{
    while (!m_shaders.empty())
        removeShader(m_shaders.front());
}

bool ShaderProgram::link()
{
    if (m_linked)
        return true;

    glLinkProgram(m_programId);

    int value = GL_FALSE;
    glGetProgramiv(m_programId, GL_LINK_STATUS, &value);
    m_linked = (value != GL_FALSE);

    if (!m_linked)
        g_logger.traceWarning(log());

    return m_linked;
}

bool ShaderProgram::bind()
{
    if (m_currentProgram == m_programId)
        return false;

    if (!m_linked && !link())
        return false;

    glUseProgram(m_programId);
    m_currentProgram = m_programId;
    return true;
}

void ShaderProgram::release()
{
    if (m_currentProgram == 0)
        return;

    m_currentProgram = 0;
    glUseProgram(0);
}

std::string ShaderProgram::log() const
{
    std::string infoLog;
    int infoLogLength = 0;
    glGetProgramiv(m_programId, GL_INFO_LOG_LENGTH, &infoLogLength);
    if (infoLogLength > 1) {
        std::vector<char> buf(infoLogLength);
        glGetShaderInfoLog(m_programId, infoLogLength - 1, nullptr, &buf[0]);
        infoLog = &buf[0];
    }
    return infoLog;
}

int ShaderProgram::getAttributeLocation(const char* name) const { return glGetAttribLocation(m_programId, name); }

void ShaderProgram::bindAttributeLocation(const int location, const char* name) const { return glBindAttribLocation(m_programId, location, name); }

void ShaderProgram::bindUniformLocation(const int location, const char* name)
{
    assert(m_linked);
    assert(location >= 0 && location < MAX_UNIFORM_LOCATIONS);
    m_uniformLocations[location] = glGetUniformLocation(m_programId, name);
}