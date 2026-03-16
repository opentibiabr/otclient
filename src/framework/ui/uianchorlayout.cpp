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

#include "uianchorlayout.h"
#include "uiwidget.h"

UIWidgetPtr UIAnchor::getHookedWidget(const UIWidgetPtr& widget, const UIWidgetPtr& parentWidget)
{
    if (!parentWidget)
        return nullptr;

    // determine hooked widget
    if (m_hookedWidgetId == "parent")
        return parentWidget;

    if (m_hookedWidgetId == "next")
        return parentWidget->getChildAfter(widget);

    if (m_hookedWidgetId == "prev")
        return parentWidget->getChildBefore(widget);

    return parentWidget->getChildById(m_hookedWidgetId);
}

int UIAnchor::getHookedPoint(const UIWidgetPtr& hookedWidget, const UIWidgetPtr& parentWidget)
{
    // determine hooked widget edge point
    const auto& hookedWidgetRect = hookedWidget == parentWidget ?
        parentWidget->getPaddingRect() : hookedWidget->getRect();

    int point = 0;
    switch (m_hookedEdge) {
        case Fw::AnchorLeft:
            point = hookedWidgetRect.left();
            break;
        case Fw::AnchorRight:
            point = hookedWidgetRect.right();
            break;
        case Fw::AnchorTop:
            point = hookedWidgetRect.top();
            break;
        case Fw::AnchorBottom:
            point = hookedWidgetRect.bottom();
            break;
        case Fw::AnchorHorizontalCenter:
            point = hookedWidgetRect.horizontalCenter();
            break;
        case Fw::AnchorVerticalCenter:
            point = hookedWidgetRect.verticalCenter();
            break;
        default:
            // must never happens
            assert(false);
            break;
    }

    if (hookedWidget == parentWidget) {
        switch (m_hookedEdge) {
            case Fw::AnchorLeft:
            case Fw::AnchorRight:
            case Fw::AnchorHorizontalCenter:
                point -= parentWidget->getVirtualOffset().x;
                break;
            case Fw::AnchorBottom:
            case Fw::AnchorTop:
            case Fw::AnchorVerticalCenter:
                point -= parentWidget->getVirtualOffset().y;
                break;
            default:
                break;
        }
    }

    return point;
}

void UIAnchorGroup::addAnchor(const UIAnchorPtr& anchor)
{
    // duplicated anchors must be replaced
    for (auto& other : m_anchors) {
        if (other->getAnchoredEdge() == anchor->getAnchoredEdge()) {
            other = anchor;
            return;
        }
    }
    m_anchors.emplace_back(anchor);
}

bool UIAnchorGroup::addAnchor(Fw::AnchorEdge anchoredEdge, std::string_view hookedWidgetId, Fw::AnchorEdge hookedEdge)
{
    // duplicated anchors must be replaced
    for (const auto& anchor : m_anchors) {
        if (anchor->getAnchoredEdge() == anchoredEdge) {
            if (anchor->getHookdWidgetId() == hookedWidgetId && anchor->getHookedEdge() == hookedEdge)
                return false;

            anchor->setHook(hookedEdge, hookedWidgetId);
            return true;
        }
    }

    if (hookedWidgetId == "none")
        return false;

    m_anchors.emplace_back(std::make_shared<UIAnchor>(anchoredEdge, hookedWidgetId, hookedEdge));
    return true;
}

void UIAnchorLayout::addAnchor(const UIWidgetPtr& anchoredWidget, Fw::AnchorEdge anchoredEdge,
                               const std::string_view hookedWidgetId, Fw::AnchorEdge hookedEdge)
{
    if (!anchoredWidget)
        return;

    assert(anchoredWidget != getParentWidget());

    auto& anchorGroup = m_anchorsGroups[anchoredWidget];
    if (!anchorGroup)
        anchorGroup = std::make_shared<UIAnchorGroup>();

    if (anchorGroup->addAnchor(anchoredEdge, hookedWidgetId, hookedEdge)) {
        // layout must be updated because a new anchor got in
        update();
    }
}

void UIAnchorLayout::removeAnchors(const UIWidgetPtr& anchoredWidget)
{
    if (m_anchorsGroups.erase(anchoredWidget) > 0)
        update();
}

bool UIAnchorLayout::hasAnchors(const UIWidgetPtr& anchoredWidget) const
{
    return m_anchorsGroups.contains(anchoredWidget);
}

void UIAnchorLayout::centerIn(const UIWidgetPtr& anchoredWidget, const std::string_view hookedWidgetId)
{
    addAnchor(anchoredWidget, Fw::AnchorHorizontalCenter, hookedWidgetId, Fw::AnchorHorizontalCenter);
    addAnchor(anchoredWidget, Fw::AnchorVerticalCenter, hookedWidgetId, Fw::AnchorVerticalCenter);
}

void UIAnchorLayout::fill(const UIWidgetPtr& anchoredWidget, const std::string_view hookedWidgetId)
{
    addAnchor(anchoredWidget, Fw::AnchorLeft, hookedWidgetId, Fw::AnchorLeft);
    addAnchor(anchoredWidget, Fw::AnchorRight, hookedWidgetId, Fw::AnchorRight);
    addAnchor(anchoredWidget, Fw::AnchorTop, hookedWidgetId, Fw::AnchorTop);
    addAnchor(anchoredWidget, Fw::AnchorBottom, hookedWidgetId, Fw::AnchorBottom);
}

void UIAnchorLayout::addWidget(const UIWidgetPtr&)
{
    update();
}

void UIAnchorLayout::removeWidget(const UIWidgetPtr& widget)
{
    removeAnchors(widget);
}

inline bool isInlineish(UIWidget* w) {
    auto d = w->getDisplay();
    return d == DisplayType::Inline || d == DisplayType::InlineBlock;
}

bool UIAnchorLayout::updateWidget(const UIWidgetPtr& widget, const UIAnchorGroupPtr& anchorGroup, UIWidgetPtr first)
{
    auto parentWidget = getParentWidget();
    if (!parentWidget)
        return false;

    if (first == widget) {
        g_logger.error("child '{}' of parent widget '{}' is recursively anchored to itself, please fix this", widget->getId(), parentWidget->getId());
        return false;
    }

    if (!first)
        first = widget;

    Rect newRect = widget->getRect();
    bool verticalMoved = false;
    bool horizontalMoved = false;

    int realMarginTop = 0;
    int ajustCenterPos = 0;
    if (widget->isOnHtml()) {
        const auto isInline = isInlineish(widget.get());
        bool getMargin = false, getCenterPos = false;
        if ((widget->getPrevWidget() == nullptr || widget->getPrevWidget()->getDisplay() == DisplayType::Block) && isInline) {
            realMarginTop = widget->getDisplay() == DisplayType::InlineBlock ? widget->getMarginTop() : 0;
            getMargin = true;
        }

        if (isInline && (parentWidget->getTextAlign() == Fw::AlignCenter || parentWidget->getJustifyItems() == JustifyItemsType::Center)) {
            if (!widget->getPrevWidget() || !isInlineish(widget->getPrevWidget().get())) {
                getCenterPos = true;
                ajustCenterPos += (widget->getPaddingLeft() + widget->getPaddingRight()) / 2;
            }
        }
        if (getMargin || getCenterPos) {
            for (auto p = widget->getNextWidget(); p && p->isAnchorable() && p->getPositionType() != PositionType::Absolute && isInlineish(p.get()); p = p->getNextWidget()) {
                if (getCenterPos)
                    ajustCenterPos += p->getWidth() + p->getMarginLeft() + p->getPaddingLeft() + p->getPaddingRight();

                if (getMargin && p->getDisplay() == DisplayType::InlineBlock)
                    realMarginTop = std::max<int>(realMarginTop, p->getMarginTop());
            }
        }
    }

    const auto& virtualParentWidget = widget->getPositionType() == PositionType::Absolute ? widget->getVirtualParent() : nullptr;

    // calculates new rect based on anchors
    for (const auto& anchor : anchorGroup->getAnchors()) {
        // skip invalid anchors
        if (anchor->getHookedEdge() == Fw::AnchorNone)
            continue;

        if (widget->getPositionType() == PositionType::Absolute) {
            parentWidget =
                ((anchor->getAnchoredEdge() == Fw::AnchorTop && widget->getPositions().top.unit != Unit::Auto) ||
                 (anchor->getAnchoredEdge() == Fw::AnchorLeft && widget->getPositions().left.unit != Unit::Auto) ||
                 (anchor->getAnchoredEdge() == Fw::AnchorRight && widget->getPositions().right.unit != Unit::Auto) ||
                 (anchor->getAnchoredEdge() == Fw::AnchorBottom && widget->getPositions().bottom.unit != Unit::Auto))
                ? virtualParentWidget
                : getParentWidget();
        }

        // determine hooked widget
        const auto& hookedWidget = anchor->getHookedWidget(widget, parentWidget);

        // skip invalid anchors
        if (!hookedWidget)
            continue;

        if (hookedWidget != getParentWidget()) {
            // update this hooked widget anchors
            auto it = m_anchorsGroups.find(hookedWidget);
            if (it != m_anchorsGroups.end()) {
                const auto& hookedAnchorGroup = it->second;
                if (!hookedAnchorGroup->isUpdated())
                    updateWidget(hookedWidget, hookedAnchorGroup, first);
            }
        }

        const int point = anchor->getHookedPoint(hookedWidget, parentWidget);
        switch (anchor->getAnchoredEdge()) {
            case Fw::AnchorHorizontalCenter: {
                auto margin = widget->getMarginLeft() - widget->getMarginRight();
                if (widget->isOnHtml()) {
                    if (ajustCenterPos > 0) {
                        margin = -(ajustCenterPos / 2);
                    }
                }

                newRect.moveHorizontalCenter(point + margin);
                horizontalMoved = true;
                break;
            }case Fw::AnchorLeft: {
                auto margin = widget->getMarginLeft();
                if (widget->isOnHtml()) {
                    if (parentWidget != hookedWidget) {
                        if (isInlineish(hookedWidget.get())) {
                            margin += hookedWidget->getMarginRight();
                        }
                    }

                    if (widget->getPositionType() == PositionType::Relative || widget->getPositionType() == PositionType::Absolute) {
                        if (widget->getPositions().left.unit != Unit::Auto)
                            margin -= hookedWidget->getPaddingLeft();
                        margin += widget->getPositions().left.value;
                    }

                    // Fix anchor position
                    margin += (anchor->getAnchoredEdge() == anchor->getHookedEdge() ? 0 : 1);
                }
                if (!horizontalMoved) {
                    newRect.moveLeft(point + margin);
                    horizontalMoved = true;
                } else
                    newRect.setLeft(point + margin);
                break;
            }
            case Fw::AnchorRight: {
                auto margin = widget->getMarginRight();
                if (widget->isOnHtml()) {
                    if (widget->getPositionType() == PositionType::Absolute && widget->getPositions().right.unit != Unit::Auto)
                        margin -= hookedWidget->getPaddingRight();

                    if (widget->getPositions().left.unit == Unit::Auto && (widget->getPositionType() == PositionType::Relative || widget->getPositionType() == PositionType::Absolute)) {
                        margin += widget->getPositions().right.value;
                    }
                }

                if (!horizontalMoved) {
                    newRect.moveRight(point - margin);
                    horizontalMoved = true;
                } else
                    newRect.setRight(point - margin);
                break;
            }
            case Fw::AnchorVerticalCenter:
                newRect.moveVerticalCenter(point + widget->getMarginTop() - widget->getMarginBottom());
                verticalMoved = true;
                break;
            case Fw::AnchorTop: {
                auto margin = widget->getMarginTop();
                if (widget->isOnHtml()) {
                    if (parentWidget != hookedWidget) {
                        if (isInlineish(widget.get())) {
                            margin = realMarginTop;
                        } else if (widget->getFloat() != FloatType::None) {
                            margin -= hookedWidget->getMarginTop();
                        } else  if (hookedWidget->getDisplay() == DisplayType::Block) {
                            if (widget->getMarginBottom() > 0 && hookedWidget->getMarginBottom() > 0)
                                margin = std::max<int>(margin, hookedWidget->getMarginBottom());
                            else
                                margin += hookedWidget->getMarginBottom();
                        }

                        if (hookedWidget->getPositionType() == PositionType::Relative)
                            margin -= hookedWidget->getPositions().top.value;
                    } else if (isInlineish(widget.get())) {
                        margin = realMarginTop;
                    }

                    if (isInlineish(widget.get())) {
                        margin += widget->getLineHeight().valueCalculed - hookedWidget->getLineHeight().valueCalculed;
                    }

                    if (widget->getPositionType() == PositionType::Relative || widget->getPositionType() == PositionType::Absolute) {
                        if (widget->getPositions().top.unit != Unit::Auto)
                            margin -= hookedWidget->getPaddingTop();

                        margin += widget->getPositions().top.value;
                    }

                    // Fix anchor position
                    margin += (anchor->getAnchoredEdge() == anchor->getHookedEdge() ? 0 : 1);
                }

                if (!verticalMoved) {
                    newRect.moveTop(point + margin);
                    verticalMoved = true;
                } else
                    newRect.setTop(point + margin);
                break;
            }

            case Fw::AnchorBottom: {
                auto margin = widget->getMarginBottom();
                if (widget->isOnHtml()) {
                    if (parentWidget != hookedWidget) {
                        if (widget->getFloat() != FloatType::None) {
                            margin -= hookedWidget->getMarginBottom();
                        } else if (widget->getDisplay() == DisplayType::Inline) {
                            margin = 0;
                        } else if (hookedWidget->getDisplay() == DisplayType::Block) {
                            if (widget->getMarginBottom() > 0 && hookedWidget->getMarginTop() > 0)
                                margin = std::max<int>(margin, hookedWidget->getMarginTop());
                            else
                                margin += hookedWidget->getMarginTop();
                        }

                        if (hookedWidget->getPositionType() == PositionType::Relative)
                            margin += hookedWidget->getPositions().bottom.value;
                    }

                    if (widget->getPositionType() == PositionType::Absolute && widget->getPositions().bottom.unit != Unit::Auto)
                        margin -= hookedWidget->getPaddingBottom();

                    if (widget->getPositions().top.unit == Unit::Auto && (widget->getPositionType() == PositionType::Relative || widget->getPositionType() == PositionType::Absolute)) {
                        margin += widget->getPositions().bottom.value;
                    }
                }

                if (!verticalMoved) {
                    newRect.moveBottom(point - margin);
                    verticalMoved = true;
                } else
                    newRect.setBottom(point - margin);
                break;
            }
            default:
                break;
        }
    }

    anchorGroup->setUpdated(true);
    return widget->setRect(newRect);
}

bool UIAnchorLayout::internalUpdate()
{
    // reset all anchors groups update state
    for (const auto& it : m_anchorsGroups)
        it.second->setUpdated(false);

    bool changed = false;

    // update all anchors
    for (const auto& [widget, anchorGroup] : m_anchorsGroups) {
        if (anchorGroup->isUpdated())
            continue;

        if (updateWidget(widget, anchorGroup))
            changed = true;
    }

    return changed;
}