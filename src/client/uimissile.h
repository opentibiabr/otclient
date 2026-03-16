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
#include <framework/ui/uiwidget.h>

class UIMissile final : public UIWidget
{
public:
    UIMissile();
    void drawSelf(DrawPoolType drawPane) override;

    void setMissileId(int id);
    void setMissileVisible(const bool visible) { m_missileVisible = visible; }
    void setMissile(const MissilePtr& missile);
    void setVirtual(const bool virt) { m_virtual = virt; }
    void setDirection(const Otc::Direction dir);
    void clearMissile() { setMissileId(0); }

    int getMissileId();
    Otc::Direction getDirection();
    auto getMissile() { return m_missile; }
    bool isVirtual() { return m_virtual; }
    bool isMissileVisible() { return m_missileVisible; }

    void setShader(std::string_view name) override;
    bool hasShader() override;

protected:
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;

    std::string m_shaderName;
    MissilePtr m_missile;
    bool m_virtual{ false };
    bool m_showId{ false };
    bool m_missileVisible{ true };
};
