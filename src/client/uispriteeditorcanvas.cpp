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

#include "uispriteeditorcanvas.h"

#ifdef FRAMEWORK_EDITOR

#include <algorithm>
#include <cmath>

#include "spriteappearances.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/image.h"
#include "framework/graphics/texture.h"

namespace {
constexpr int MAX_ZOOM = 64;
constexpr int CHECKER_SIZE = 12;
}

bool UISpriteEditorCanvas::setSpriteId(const int id)
{
    m_isThumbnail = false;
    return setSpriteIdInternal(id, true);
}

bool UISpriteEditorCanvas::setThumbnailSpriteId(const int id)
{
    m_isThumbnail = true;
    return setSpriteIdInternal(id, false);
}

void UISpriteEditorCanvas::clearSprite()
{
    m_spriteId = 0;
    m_thumbnailSizeBadgeDimension = 0;
    m_zoom = 1;
    m_image.reset();
    m_texture.reset();
    m_animationTextures.clear();
    m_hasUserZoom = false;
    m_isPanning = false;
    m_pan = {};
    updateRenderRect();
    callLuaField("onStateChange");
}

bool UISpriteEditorCanvas::setSpriteIdInternal(const int id, const bool releaseDecodedSheets)
{
    m_thumbnailSizeBadgeDimension = 0;
    if (id <= 0) {
        clearSprite();
        return false;
    }

    const auto image = g_spriteAppearances.getSpriteImage(id);
    if (!image) {
        clearSprite();
        return false;
    }

    m_spriteId = id;
    m_image = image;
    m_animationTextures.clear();
    m_texture = std::make_shared<Texture>(m_image);
    m_texture->setSmooth(false);
    m_hasUserZoom = false;
    m_pan = {};
    updateRenderRect();
    callLuaField("onStateChange");
    if (releaseDecodedSheets)
        g_spriteAppearances.releaseSpriteSheetsExcept(id);
    return true;
}

void UISpriteEditorCanvas::setThumbnailSizeBadge(const int dimension)
{
    m_thumbnailSizeBadgeDimension = std::max(0, dimension);
    repaint();
}

bool UISpriteEditorCanvas::setSpriteAnimationIds(const std::vector<uint32_t>& ids)
{
    m_thumbnailSizeBadgeDimension = 0;
    if (ids.empty())
        return false;
    if (ids.size() == 1)
        return setThumbnailSpriteId(static_cast<int>(ids.front()));

    std::vector<TexturePtr> textures;
    textures.reserve(ids.size());
    ImagePtr firstImage;
    for (const auto id : ids) {
        const auto image = g_spriteAppearances.getSpriteImage(static_cast<int>(id));
        if (!image)
            return false;

        auto texture = std::make_shared<Texture>(image);
        texture->setSmooth(false);
        if (textures.empty())
            firstImage = image;
        textures.push_back(std::move(texture));
    }

    m_spriteId = static_cast<int>(ids.front());
    m_image = std::move(firstImage);
    m_texture = textures.front();
    m_animationTextures = std::move(textures);
    m_animationTimer.restart();
    m_hasUserZoom = false;
    m_pan = {};
    m_isThumbnail = true;
    updateRenderRect();
    callLuaField("onStateChange");
    return true;
}

int UISpriteEditorCanvas::getSpriteWidth() const
{
    return m_image ? m_image->getWidth() : 0;
}

int UISpriteEditorCanvas::getSpriteHeight() const
{
    return m_image ? m_image->getHeight() : 0;
}

int UISpriteEditorCanvas::zoomIn()
{
    if (!m_image)
        return m_zoom;

    m_zoom = std::min(MAX_ZOOM, m_zoom + 1);
    m_hasUserZoom = true;
    updateRenderRect();
    callLuaField("onStateChange");
    return m_zoom;
}

int UISpriteEditorCanvas::zoomOut()
{
    if (!m_image)
        return m_zoom;

    m_zoom = std::max(1, m_zoom - 1);
    m_hasUserZoom = true;
    updateRenderRect();
    callLuaField("onStateChange");
    return m_zoom;
}

void UISpriteEditorCanvas::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    UIWidget::drawSelf(drawPane);
    if (!m_image || !m_texture)
        return;

    auto texture = m_texture;
    if (m_animationTextures.size() > 1) {
        const auto frame = (m_animationTimer.ticksElapsed() / 180) % m_animationTextures.size();
        texture = m_animationTextures[frame];
    }

    updateRenderRect();
    const Rect viewRect = getPaddingRect();
    const Rect visibleRect = m_renderRect.intersection(viewRect);
    if (!visibleRect.isValid())
        return;

    const Rect oldClipRect = g_drawPool.getClipRect();
    g_drawPool.setClipRect(oldClipRect.isValid() ? oldClipRect.intersection(viewRect) : viewRect);
    for (int y = visibleRect.top(); y <= visibleRect.bottom(); y += CHECKER_SIZE) {
        for (int x = visibleRect.left(); x <= visibleRect.right(); x += CHECKER_SIZE) {
            const int column = (x - m_renderRect.left()) / CHECKER_SIZE;
            const int row = (y - m_renderRect.top()) / CHECKER_SIZE;
            const Color color = (column + row) % 2 == 0 ? Color(0xff555555) : Color(0xff3f3f3f);
            const Rect tile(x, y, CHECKER_SIZE, CHECKER_SIZE);
            g_drawPool.addFilledRect(tile.intersection(visibleRect), color);
        }
    }

    const Rect sourceRect = m_isThumbnail
        ? Rect(0, 0, m_image->getSize())
        : Rect((visibleRect.left() - m_renderRect.left()) / m_zoom,
               (visibleRect.top() - m_renderRect.top()) / m_zoom,
               visibleRect.width() / m_zoom,
               visibleRect.height() / m_zoom);
    g_drawPool.addTexturedRect(visibleRect, texture, sourceRect, Color::white);

    if (oldClipRect.isValid())
        g_drawPool.setClipRect(oldClipRect);
    else
        g_drawPool.resetClipRect();

    if (m_isThumbnail && m_thumbnailSizeBadgeDimension > 0) {
        const auto parent = getParent();
        const Rect badgeRect = parent ? parent->getRect() : getRect();
        constexpr int BADGE_SIZE = 22;
        const auto topRight = badgeRect.topRight();
        const Color badgeColor = m_thumbnailSizeBadgeDimension <= 32 ? Color(49, 155, 84) :
                                 m_thumbnailSizeBadgeDimension <= 64 ? Color(210, 170, 40) : Color(216, 141, 35);
        g_drawPool.addFilledTriangle(topRight - Point(BADGE_SIZE - 1, 0), topRight,
                                     topRight + Point(0, BADGE_SIZE - 1), badgeColor);
    }
}

bool UISpriteEditorCanvas::onMousePress(const Point& mousePos, const Fw::MouseButton button)
{
    if (button == Fw::MouseMidButton && m_image && getPaddingRect().contains(mousePos)) {
        m_isPanning = true;
        return true;
    }
    return UIWidget::onMousePress(mousePos, button);
}

bool UISpriteEditorCanvas::onMouseRelease(const Point& mousePos, const Fw::MouseButton button)
{
    if (button == Fw::MouseMidButton && m_isPanning) {
        m_isPanning = false;
        return true;
    }
    return UIWidget::onMouseRelease(mousePos, button);
}

bool UISpriteEditorCanvas::onMouseMove(const Point& mousePos, const Point& mouseMoved)
{
    if (!m_isPanning)
        return UIWidget::onMouseMove(mousePos, mouseMoved);

    m_pan.x += mouseMoved.x;
    m_pan.y += mouseMoved.y;
    updateRenderRect();
    callLuaField("onPositionChange");
    return true;
}

bool UISpriteEditorCanvas::onMouseWheel(const Point& mousePos, const Fw::MouseWheelDirection direction)
{
    if (m_isThumbnail || !getPaddingRect().contains(mousePos))
        return UIWidget::onMouseWheel(mousePos, direction);

    if (direction == Fw::MouseWheelUp)
        zoomIn();
    else
        zoomOut();
    return true;
}

void UISpriteEditorCanvas::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    UIWidget::onGeometryChange(oldRect, newRect);
    updateRenderRect();
}

void UISpriteEditorCanvas::updateRenderRect()
{
    if (!m_image) {
        m_renderRect = {};
        m_spriteRenderCenter = {};
        return;
    }

    const Rect viewRect = getPaddingRect();
    if (!m_hasUserZoom && viewRect.width() > 0 && viewRect.height() > 0) {
        m_zoom = 1;
    }

    Size renderSize;
    if (m_isThumbnail) {
        const float scale = std::min({ 1.0f,
                                       static_cast<float>(viewRect.width()) / m_image->getWidth(),
                                       static_cast<float>(viewRect.height()) / m_image->getHeight() });
        renderSize = Size(std::min(viewRect.width(), std::max(1, static_cast<int>(std::lround(m_image->getWidth() * scale)))),
                          std::min(viewRect.height(), std::max(1, static_cast<int>(std::lround(m_image->getHeight() * scale)))));
    } else {
        renderSize = Size(m_image->getWidth() * m_zoom, m_image->getHeight() * m_zoom);
    }
    const Point origin(viewRect.x() + (viewRect.width() - renderSize.width()) / 2 + m_pan.x,
                       viewRect.y() + (viewRect.height() - renderSize.height()) / 2 + m_pan.y);
    m_renderRect = Rect(origin, renderSize);
    m_spriteRenderCenter = Point(origin.x + renderSize.width() / 2 - viewRect.x(),
                                 origin.y + renderSize.height() / 2 - viewRect.y());
}

#endif
