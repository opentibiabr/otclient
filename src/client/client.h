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
#include "framework/core/graphicalapplication.h"

class Client : public ApplicationDrawEvents
{
public:
    void init(std::vector<std::string>& args);
    void terminate();
    static void registerLuaFunctions();

    void preLoad() override;
    void draw(DrawPoolType type) override;

    bool canDraw(DrawPoolType type) const override;
    bool isLoadingAsyncTexture() override;
    bool isUsingProtobuf() override;

    void onLoadingAsyncTextureChanged(bool loadingAsync) override;
    void doMapScreenshot(std::string fileName) override;

    UIMapPtr getMapWidget() { return m_mapWidget; }

    float getEffectAlpha() const { return m_effectAlpha; }
    void setEffectAlpha(const float v) { m_effectAlpha = v; }

    float getMissileAlpha() const { return m_missileAlpha; }
    void setMissileAlpha(const float v) { m_missileAlpha = v; }

private:
    UIMapPtr m_mapWidget;
    float m_effectAlpha{ 1.f };
    float m_missileAlpha{ 1.f };
};

extern Client g_client;
