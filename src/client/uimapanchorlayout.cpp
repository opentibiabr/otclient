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

#include "uimapanchorlayout.h"
#include "uiminimap.h"

int UIPositionAnchor::getHookedPoint(const UIWidgetPtr& hookedWidget, const UIWidgetPtr&)
{
    const auto& minimap = hookedWidget->static_self_cast<UIMinimap>();
    const auto& hookedRect = minimap->getTileRect(m_hookedPosition);
    if (hookedRect.isValid()) {
        switch (m_hookedEdge) {
            case Fw::AnchorTop: return hookedRect.top();
            case Fw::AnchorLeft: return hookedRect.left();
            case Fw::AnchorRight:return hookedRect.right();
            case Fw::AnchorBottom: return hookedRect.bottom();
            case Fw::AnchorVerticalCenter: return hookedRect.verticalCenter();
            case Fw::AnchorHorizontalCenter: return hookedRect.horizontalCenter();
            case Fw::AnchorNone: break;
        }
    }

    return 0;
}

void UIMapAnchorLayout::addPositionAnchor(const UIWidgetPtr& anchoredWidget, Fw::AnchorEdge anchoredEdge, const Position& hookedPosition, Fw::AnchorEdge hookedEdge)
{
    if (!anchoredWidget)
        return;

    assert(anchoredWidget != getParentWidget());

    const auto& anchor = std::make_shared<UIPositionAnchor>(anchoredEdge, hookedPosition, hookedEdge);
    auto& anchorGroup = m_anchorsGroups[anchoredWidget];
    if (!anchorGroup)
        anchorGroup = std::make_shared<UIAnchorGroup>();

    anchorGroup->addAnchor(anchor);

    // layout must be updated because a new anchor got in
    update();
}

void UIMapAnchorLayout::centerInPosition(const UIWidgetPtr& anchoredWidget, const Position& hookedPosition)
{
    addPositionAnchor(anchoredWidget, Fw::AnchorHorizontalCenter, hookedPosition, Fw::AnchorHorizontalCenter);
    addPositionAnchor(anchoredWidget, Fw::AnchorVerticalCenter, hookedPosition, Fw::AnchorVerticalCenter);
}

void UIMapAnchorLayout::fillPosition(const UIWidgetPtr& anchoredWidget, const Position& hookedPosition)
{
    addPositionAnchor(anchoredWidget, Fw::AnchorLeft, hookedPosition, Fw::AnchorLeft);
    addPositionAnchor(anchoredWidget, Fw::AnchorRight, hookedPosition, Fw::AnchorRight);
    addPositionAnchor(anchoredWidget, Fw::AnchorTop, hookedPosition, Fw::AnchorTop);
    addPositionAnchor(anchoredWidget, Fw::AnchorBottom, hookedPosition, Fw::AnchorBottom);
}