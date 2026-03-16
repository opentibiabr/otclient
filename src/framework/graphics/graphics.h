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

 // @bindsingleton g_graphics
class Graphics
{
public:
    // @dontbind
    void init();
    // @dontbind
    void terminate();

    void resize(const Size& size);

    int getMaxTextureSize() const { return m_maxTextureSize; }
    const Size& getViewportSize() { return m_viewportSize; }

    std::string getVendor() { return m_vendor; }
    std::string getRenderer() { return m_renderer; }
    std::string getVersion() { return m_version; }
    std::string getExtensions() { return m_extensions; }

    bool ok() const { return m_ok; }

private:
    bool m_ok{ false };

    std::string m_vendor;
    std::string m_renderer;
    std::string m_version;
    std::string m_extensions;

    int m_maxTextureSize{ -1 };
    int m_alphaBits{ 0 };

    Size m_viewportSize;
};

extern Graphics g_graphics;
