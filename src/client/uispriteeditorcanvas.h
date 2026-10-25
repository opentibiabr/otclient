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

#ifdef FRAMEWORK_EDITOR

#include <framework/graphics/declarations.h>
#include <framework/core/timer.h>
#include <framework/ui/uiwidget.h>

class Image;

class UISpriteEditorCanvas final : public UIWidget
{
public:
    bool setSpriteId(int id);
    bool setThumbnailSpriteId(int id);
    void setThumbnailSizeBadge(int dimension);
    bool setSpriteAnimationIds(const std::vector<uint32_t>& ids);
    int getSpriteId() const { return m_spriteId; }
    int getSpriteWidth() const;
    int getSpriteHeight() const;
    Point getSpriteRenderCenter() const { return m_spriteRenderCenter; }
    int zoomIn();
    int zoomOut();
    int getZoom() const { return m_zoom; }

    void drawSelf(DrawPoolType drawPane) override;

protected:
    bool onMousePress(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseRelease(const Point& mousePos, Fw::MouseButton button) override;
    bool onMouseMove(const Point& mousePos, const Point& mouseMoved) override;
    bool onMouseWheel(const Point& mousePos, Fw::MouseWheelDirection direction) override;
    void onGeometryChange(const Rect& oldRect, const Rect& newRect) override;

private:
    void clearSprite();
    bool setSpriteIdInternal(int id, bool releaseDecodedSheets);
    void updateRenderRect();

    int m_spriteId{ 0 };
    int m_zoom{ 1 };
    ImagePtr m_image;
    TexturePtr m_texture;
    std::vector<TexturePtr> m_animationTextures;
    Timer m_animationTimer;
    Rect m_renderRect;
    Point m_spriteRenderCenter;
    Point m_pan;
    bool m_isPanning{ false };
    bool m_hasUserZoom{ false };
    bool m_isThumbnail{ false };
    int m_thumbnailSizeBadgeDimension{ 0 };
};

#endif
