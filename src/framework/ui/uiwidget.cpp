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

#include "uiwidget.h"

#include "uianchorlayout.h"
#include "uimanager.h"
#include "uitranslator.h"
#include "framework/core/eventdispatcher.h"
#include <framework/core/graphicalapplication.h>
#include "framework/graphics/drawpool.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/shadermanager.h"
#include <framework/graphics/bitmapfont.h>
#include "framework/html/htmlmanager.h"
#include "framework/html/htmlnode.h"
#include "framework/otml/otmlnode.h"
#include <framework/platform/platformwindow.h>
#include <framework/util/stats.h>

UIWidget::UIWidget()
{
    m_source = g_lua.getSource(2);
    int level = 3;
    while ((m_source.find("corelib") != std::string::npos || m_source.find("gamelib") != std::string::npos
           || m_source.find("game_bot/functions/ui") != std::string::npos || m_source.find("[C]") != std::string::npos) && level < 8) {
        std::string tmp_src = g_lua.getSource(level);
        if (tmp_src.length() <= 3) break;
        m_source = tmp_src;
        level += 1;
    }

    setProp(PropEnabled, true, false);
    setProp(PropVisible, true, false);
    setProp(PropFocusable, true, false);
    setProp(PropFirstOnStyle, true, false);

    m_positions.set(Unit::Auto);
    m_clickTimer.stop();

    initBaseStyle();
    initText();
    initImage();

    g_stats.addWidget(this);
}

UIWidget::~UIWidget()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
    if (!isDestroyed())
        g_logger.warning("widget '{}' was not explicitly destroyed", m_id);
#endif

    g_stats.removeWidget(this);
}

void UIWidget::draw(const Rect& visibleRect, const DrawPoolType drawPane)
{
    Rect oldClipRect;
    if (isClipping()) {
        oldClipRect = g_drawPool.getClipRect();
        g_drawPool.setClipRect(visibleRect);
    }

    if (m_rotation != 0.0f) {
        g_drawPool.pushTransformMatrix();
        g_drawPool.rotate(m_rect.center(), m_rotation * (Fw::pi / 180.0));
    }

    drawSelf(drawPane);

    if (!m_children.empty()) {
        if (isClipping())
            g_drawPool.setClipRect(visibleRect.intersection(getPaddingRect()));

        drawChildren(visibleRect, drawPane);
    }

    if (m_rotation != 0.0f)
        g_drawPool.popTransformMatrix();

    if (isClipping()) {
        g_drawPool.setClipRect(oldClipRect);
    }
}

void UIWidget::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    if (hasShader())
        g_drawPool.setShaderProgram(m_shader);

    // draw style components in order
    if (m_backgroundColor.aF() > Fw::MIN_ALPHA) {
        Rect backgroundDestRect = m_rect;
        backgroundDestRect.expand(-m_borderWidth.top, -m_borderWidth.right, -m_borderWidth.bottom, -m_borderWidth.left);
        drawBackground(m_rect);
    }

    drawImage(m_rect);
    drawIcon(m_rect);
    drawText(m_rect);
    drawBorder(m_rect);

    if (hasShader())
        g_drawPool.resetShaderProgram();
}

void UIWidget::drawChildren(const Rect& visibleRect, const DrawPoolType drawPane)
{
    // draw children
    for (const auto& child : m_children) {
        // render only visible children with a valid rect inside parent rect
        if (!child || !child->isExplicitlyVisible() || child->getOpacity() <= Fw::MIN_ALPHA)
            continue;

        auto childVisibleRect = visibleRect;
        if (child->getDisplay() == DisplayType::None)
            continue;

        if (!child->isOnHtml() && !child->getRect().isValid())
            continue;

        childVisibleRect = visibleRect.intersection(child->getRect());
        if (!childVisibleRect.isValid()) {
            if (m_overflowType != OverflowType::Visible) {
                continue;
            }

            childVisibleRect = visibleRect;
        }

        // store current graphics opacity
        const float oldOpacity = g_drawPool.getOpacity();

        // decrease to self opacity
        if (child->getOpacity() < oldOpacity)
            g_drawPool.setOpacity(child->getOpacity());

        child->draw(childVisibleRect, drawPane);

        // debug draw box
        if (g_ui.isDrawingDebugBoxes() && drawPane == DrawPoolType::FOREGROUND) {
            if (child->isFocused())
                g_drawPool.addBoundingRect(child->getRect(), Color::yellow);
            else
                g_drawPool.addBoundingRect(child->getRect(), Color::green);
        }

        g_drawPool.setOpacity(oldOpacity);
    }
}

void UIWidget::addChild(const UIWidgetPtr& child)
{
    if (!child) {
        g_logger.traceWarning("attempt to add a null child into a UIWidget");
        return;
    }

    if (child->isDestroyed()) {
        g_logger.traceWarning("attempt to add a destroyed child into a UIWidget");
        return;
    }

    if (hasChild(child)) {
        g_logger.traceWarning("attempt to add a child again into a UIWidget");
        return;
    }

    const auto& oldLastChild = getLastChild();

    m_children.emplace_back(child);
    m_childrenById[child->getId()] = child;

    // cache index
    child->m_childIndex = m_children.size();
    child->setParent(static_self_cast<UIWidget>());

    // create default layout
    if (!m_layout)
        m_layout = std::make_shared<UIAnchorLayout>(static_self_cast<UIWidget>());

    // add to layout and updates it
    m_layout->addWidget(child);
    if (m_htmlNode && child->m_htmlNode) {
        m_htmlNode->append(child->m_htmlNode);
        refreshHtml();
    }

    // update new child states
    child->updateStates();

    // add access to child via widget.childId
    if (child->hasProp(PropCustomId)) {
        const std::string widgetId = child->getId();
        if (!hasLuaField(widgetId)) {
            setLuaField(widgetId, child->static_self_cast<UIWidget>());
        }
    }

    // update old child index states
    if (oldLastChild) {
        oldLastChild->updateState(Fw::MiddleState);
        oldLastChild->updateState(Fw::LastState);
    }

    g_ui.onWidgetAppear(child);
}

void UIWidget::insertChild(int32_t index, const UIWidgetPtr& child)
{
    if (!child) {
        g_logger.traceWarning("attempt to insert a null child into a UIWidget");
        return;
    }

    if (hasChild(child)) {
        g_logger.traceWarning("attempt to insert a child again into a UIWidget");
        return;
    }

    const int32_t childrenSize = m_children.size();

    index = index <= 0 ? (childrenSize + index) : index - 1;

    if (!(index >= 0 && index <= childrenSize)) {
        //g_logger.traceWarning("attempt to insert a child UIWidget into an invalid index, using nearest index...");
        index = std::clamp<int>(index, 0, childrenSize);
    }

    // there was no change of index
    if (child->m_childIndex == index + 1)
        return;

    // retrieve child by index
    const auto it = m_children.begin() + index;
    m_children.insert(it, child);
    m_childrenById[child->getId()] = child;

    { // cache index
        child->m_childIndex = index + 1;
        for (auto i = child->m_childIndex; i < m_children.size(); ++i)
            m_children[i]->m_childIndex = i + 1;
    }

    child->setParent(static_self_cast<UIWidget>());

    // create default layout if needed
    if (!m_layout)
        m_layout = std::make_shared<UIAnchorLayout>(static_self_cast<UIWidget>());

    // add to layout and updates it
    m_layout->addWidget(child);
    if (m_htmlNode && child->m_htmlNode) {
        m_htmlNode->insert(child->m_htmlNode, index);
        refreshHtml(true);
    }

    // update new child states
    child->updateStates();
    updateChildrenIndexStates();

    g_ui.onWidgetAppear(child);
}

void UIWidget::removeChildByIndex(uint32_t index) {
    if (const auto& child = getChildByIndex(index)) {
        removeChild(child);
    }
}

void UIWidget::removeChild(const UIWidgetPtr& child)
{
    // remove from children list
    if (hasChild(child)) {
        // defocus if needed
        bool focusAnother = false;
        if (m_focusedChild == child) {
            focusChild(nullptr, Fw::ActiveFocusReason);
            focusAnother = true;
        }

        if (isChildLocked(child))
            unlockChild(child);

        const auto it = std::ranges::find(m_children, child);
        m_children.erase(it);
        m_childrenById.erase(child->getId());

        { // cache index
            for (size_t i = child->m_childIndex - 1, s = m_children.size(); i < s; ++i)
                m_children[i]->m_childIndex = i + 1;

            child->m_childIndex = -1;
        }

        // reset child parent
        assert(child->getParent() == static_self_cast<UIWidget>());
        child->setParent(nullptr);

        if (m_layout)
            m_layout->removeWidget(child);

        if (m_htmlNode && child->m_htmlNode) {
            m_htmlNode->remove(child->m_htmlNode);
            refreshHtml(true);
        }

        // remove access to child via widget.childId
        if (child->hasProp(PropCustomId)) {
            const std::string widgetId = child->getId();
            if (hasLuaField(widgetId)) {
                clearLuaField(widgetId);
            }
        }

        // update child states
        child->updateStates();
        updateChildrenIndexStates();

        if (m_autoFocusPolicy != Fw::AutoFocusNone && focusAnother && !m_focusedChild)
            focusPreviousChild(Fw::ActiveFocusReason, true);

        g_ui.onWidgetDisappear(child);
    } else
        g_logger.traceError("attempt to remove an unknown child from a UIWidget");
}

void UIWidget::focusChild(const UIWidgetPtr& child, const Fw::FocusReason reason)
{
    if (isDestroyed())
        return;

    if (child == m_focusedChild)
        return;

    if (child && !hasChild(child)) {
        g_logger.error("attempt to focus an unknown child in a UIWidget");
        return;
    }

    const auto oldFocused = m_focusedChild;
    m_focusedChild = child;

    if (child) {
        child->setLastFocusReason(reason);
        child->updateState(Fw::FocusState);
        child->updateState(Fw::ActiveState);

        child->onFocusChange(true, reason);
    }

    if (oldFocused) {
        oldFocused->setLastFocusReason(reason);
        oldFocused->updateState(Fw::FocusState);
        oldFocused->updateState(Fw::ActiveState);

        oldFocused->onFocusChange(false, reason);
    }

    onChildFocusChange(child, oldFocused, reason);
}

void UIWidget::focusNextChild(const Fw::FocusReason reason, const bool rotate)
{
    if (isDestroyed())
        return;

    UIWidgetPtr toFocus;
    if (rotate) {
        UIWidgetList rotatedChildren(m_children);

        if (m_focusedChild) {
            const auto focusedIt = std::ranges::find(rotatedChildren, m_focusedChild);
            if (focusedIt != rotatedChildren.end()) {
                std::ranges::rotate(rotatedChildren, focusedIt);
                rotatedChildren.pop_front();
            }
        }

        // finds next child to focus
        for (const auto& child : rotatedChildren) {
            if (child->isFocusable() && child->isExplicitlyEnabled() && child->isVisible()) {
                toFocus = child;
                break;
            }
        }
    } else {
        auto it = m_children.begin();
        if (m_focusedChild)
            it = std::ranges::find(m_children, m_focusedChild);

        for (; it != m_children.end(); ++it) {
            const auto& child = *it;
            if (child != m_focusedChild && child->isFocusable() && child->isExplicitlyEnabled() && child->isVisible()) {
                toFocus = child;
                break;
            }
        }
    }

    if (toFocus && toFocus != m_focusedChild)
        focusChild(toFocus, reason);
}

void UIWidget::focusPreviousChild(const Fw::FocusReason reason, const bool rotate)
{
    if (isDestroyed())
        return;

    UIWidgetPtr toFocus;
    if (rotate) {
        UIWidgetList rotatedChildren(m_children);
        std::ranges::reverse(rotatedChildren);

        if (m_focusedChild) {
            const auto focusedIt = std::ranges::find(rotatedChildren, m_focusedChild);
            if (focusedIt != rotatedChildren.end()) {
                std::ranges::rotate(rotatedChildren, focusedIt);
                rotatedChildren.pop_front();
            }
        }

        // finds next child to focus
        for (const auto& child : rotatedChildren) {
            if (child->isFocusable() && child->isExplicitlyEnabled() && child->isVisible()) {
                toFocus = child;
                break;
            }
        }
    } else {
        auto it = m_children.rbegin();
        if (m_focusedChild)
            it = std::ranges::find(std::ranges::reverse_view(m_children), m_focusedChild);

        for (; it != m_children.rend(); ++it) {
            const auto& child = *it;
            if (child != m_focusedChild && child->isFocusable() && child->isExplicitlyEnabled() && child->isVisible()) {
                toFocus = child;
                break;
            }
        }
    }

    if (toFocus && toFocus != m_focusedChild)
        focusChild(toFocus, reason);
}

void UIWidget::lowerChild(const UIWidgetPtr& child)
{
    if (isDestroyed())
        return;

    if (!child)
        return;

    if (m_children.front() == child)
        return;

    // remove and push child again
    const auto it = std::ranges::find(m_children, child);
    if (it == m_children.end()) {
        g_logger.traceError("cannot find child");
        return;
    }

    m_children.erase(it);
    m_children.emplace_front(child);

    if (m_htmlNode && child->m_htmlNode) {
        m_htmlNode->remove(child->m_htmlNode);
        m_htmlNode->prepend(child->m_htmlNode);
        refreshHtml(true);
    }

    { // cache index
        for (int i = (child->m_childIndex = 1), s = m_children.size(); i < s; ++i)
            m_children[i]->m_childIndex = i + 1;
    }

    updateChildrenIndexStates();
}

void UIWidget::raiseChild(const UIWidgetPtr& child)
{
    if (isDestroyed())
        return;

    if (!child)
        return;

    // remove and push child again
    const auto it = std::ranges::find(m_children, child);
    if (it == m_children.end()) {
        g_logger.traceError("cannot find child");
        return;
    }

    m_children.erase(it);
    m_children.emplace_back(child);

    if (m_htmlNode && child->m_htmlNode) {
        m_htmlNode->remove(child->m_htmlNode);
        m_htmlNode->append(child->m_htmlNode);
        refreshHtml(true);
    }

    { // cache index
        for (int i = child->m_childIndex - 1, s = m_children.size(); i < s; ++i)
            m_children[i]->m_childIndex = i + 1;
    }

    updateChildrenIndexStates();
}

void UIWidget::moveChildToIndex(const UIWidgetPtr& child, const int index)
{
    if (isDestroyed())
        return;

    if (!child)
        return;

    // there was no change of index
    if (child->m_childIndex == index)
        return;

    const size_t childrenSize = m_children.size();

    if (static_cast<size_t>(index) - 1 >= childrenSize) {
        g_logger.traceError("moving {} to index {} on {}", child->getId(), index, m_id);
        return;
    }

    // remove and push child again
    const auto it = std::ranges::find(m_children, child);
    if (it == m_children.end()) {
        g_logger.traceError("cannot find child");
        return;
    }
    m_children.erase(it);
    m_children.insert(m_children.begin() + (index - 1), child);

    if (m_htmlNode && child->m_htmlNode) {
        m_htmlNode->remove(child->m_htmlNode);
        m_htmlNode->insert(child->m_htmlNode, index - 1);
        refreshHtml(true);
    }

    { // cache index
        auto start = child->m_childIndex;
        auto end = index;
        if (start >= index) {
            start = index;
            end = child->m_childIndex;
        }

        for (int i = start - 1; i < end; ++i)
            m_children[i]->m_childIndex = i + 1;
    }

    updateChildrenIndexStates();
    updateLayout();
}

void UIWidget::reorderChildren(const std::vector<UIWidgetPtr>& childrens) {
    if (m_children.size() != childrens.size()) {
        g_logger.error("Invalid parameter for reorderChildren");
        return;
    }

    m_children.clear();
    if (m_htmlNode) m_htmlNode->clear();
    for (const auto& children : childrens) {
        m_children.push_back(children);
        if (m_htmlNode)
            m_htmlNode->append(children->m_htmlNode);
    }

    refreshHtml();

    updateChildrenIndexStates();
    updateLayout();
}

void UIWidget::lockChild(const UIWidgetPtr& child)
{
    if (isDestroyed())
        return;

    if (!child)
        return;

    if (!hasChild(child)) {
        g_logger.traceError("cannot find child");
        return;
    }

    // prevent double locks
    if (isChildLocked(child))
        unlockChild(child);

    // disable all other children
    for (const auto& otherChild : m_children) {
        if (otherChild == child)
            child->setEnabled(true);
        else
            otherChild->setEnabled(false);
    }

    m_lockedChildren.emplace_front(child);

    // lock child focus
    if (child->isFocusable())
        focusChild(child, Fw::ActiveFocusReason);
}

void UIWidget::unlockChild(const UIWidgetPtr& child)
{
    if (isDestroyed())
        return;

    if (!child)
        return;

    if (!hasChild(child)) {
        g_logger.traceError("cannot find child");
        return;
    }

    const auto it = std::ranges::find(m_lockedChildren, child);
    if (it == m_lockedChildren.end())
        return;

    m_lockedChildren.erase(it);

    // find new child to lock
    UIWidgetPtr lockedChild;
    if (!m_lockedChildren.empty()) {
        lockedChild = m_lockedChildren.front();
        assert(hasChild(lockedChild));
    }

    for (const auto& otherChild : m_children) {
        // lock new child
        if (lockedChild) {
            if (otherChild == lockedChild)
                lockedChild->setEnabled(true);
            else
                otherChild->setEnabled(false);
        }
        // else unlock all
        else
            otherChild->setEnabled(true);
    }

    if (lockedChild) {
        if (lockedChild->isFocusable())
            focusChild(lockedChild, Fw::ActiveFocusReason);
    }
}

void UIWidget::mergeStyle(const OTMLNodePtr& styleNode)
{
    applyStyle(styleNode);
    const auto& name = m_style->tag();
    const auto& source = m_style->source();
    m_style->merge(styleNode);
    m_style->setTag(name);
    m_style->setSource(source);
    updateStyle();
}

void UIWidget::applyStyle(const OTMLNodePtr& styleNode)
{
    if (isDestroyed())
        return;

    if (styleNode->size() == 0)
        return;

    setProp(PropLoadingStyle, true);
    try {
        // translate ! style tags
        for (const auto& node : styleNode->children()) {
            if (node->tag()[0] == '!') {
                std::string tag = node->tag().substr(1);
                std::string code = fmt::format("tostring({})", node->value());
                std::string origin = "@" + node->source() + ": [" + node->tag() + "]";
                g_lua.evaluateExpression(code, origin);
                std::string value = g_lua.popString();

                node->setTag(tag);
                node->setValue(value);
            }
        }

        onStyleApply(styleNode->tag(), styleNode);
        callLuaField("onStyleApply", styleNode->tag(), styleNode);

        if (hasProp(PropFirstOnStyle)) {
            const auto& parent = getParent();
            if (isFocusable() && isExplicitlyVisible() && isExplicitlyEnabled() &&
                parent && ((!parent->getFocusedChild() && parent->getAutoFocusPolicy() == Fw::AutoFocusFirst) ||
                parent->getAutoFocusPolicy() == Fw::AutoFocusLast)) {
                focus();
            }
        }

        setProp(PropFirstOnStyle, false);
    } catch (stdext::exception& e) {
        g_logger.traceError("failed to apply style to widget '{}': {}", m_id, e.what());
    }
    setProp(PropLoadingStyle, false);
}

void UIWidget::addAnchor(const Fw::AnchorEdge anchoredEdge, const std::string_view hookedWidgetId, const Fw::AnchorEdge hookedEdge)
{
    if (isDestroyed())
        return;

    if (const auto& anchorLayout = getAnchoredLayout())
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), anchoredEdge, hookedWidgetId, hookedEdge);
    else
        g_logger.traceError("cannot add anchors to widget '{}': the parent doesn't use anchors layout", m_id);
}

void UIWidget::removeAnchor(const Fw::AnchorEdge anchoredEdge)
{
    addAnchor(anchoredEdge, "none", Fw::AnchorNone);
}

void UIWidget::centerIn(const std::string_view hookedWidgetId)
{
    if (isDestroyed())
        return;

    if (const auto& anchorLayout = getAnchoredLayout()) {
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorHorizontalCenter, hookedWidgetId, Fw::AnchorHorizontalCenter);
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorVerticalCenter, hookedWidgetId, Fw::AnchorVerticalCenter);
    } else
        g_logger.traceError("cannot add anchors to widget '{}': the parent doesn't use anchors layout", m_id);
}

void UIWidget::fill(const std::string_view hookedWidgetId)
{
    if (isDestroyed())
        return;

    if (const auto& anchorLayout = getAnchoredLayout()) {
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorLeft, hookedWidgetId, Fw::AnchorLeft);
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorRight, hookedWidgetId, Fw::AnchorRight);
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorTop, hookedWidgetId, Fw::AnchorTop);
        anchorLayout->addAnchor(static_self_cast<UIWidget>(), Fw::AnchorBottom, hookedWidgetId, Fw::AnchorBottom);
    } else
        g_logger.traceError("cannot add anchors to widget '{}': the parent doesn't use anchors layout", m_id);
}

void UIWidget::breakAnchors()
{
    if (isDestroyed())
        return;

    if (const auto& anchorLayout = getAnchoredLayout())
        anchorLayout->removeAnchors(static_self_cast<UIWidget>());
}

void UIWidget::resetAnchors()
{
    if (isDestroyed())
        return;

    if (const auto& anchorLayout = getAnchoredLayout()) {
        auto it = anchorLayout->getAnchorsGroup().find(static_self_cast<UIWidget>());
        if (it == anchorLayout->getAnchorsGroup().end())
            return;

        it->second->reset();
    }
}

void UIWidget::updateParentLayout()
{
    if (isDestroyed())
        return;

    if (const auto& parent = getParent())
        parent->updateLayout();
    else
        updateLayout();
}

void UIWidget::updateLayout()
{
    if (isDestroyed())
        return;

    if (m_layout)
        m_layout->update();

    // children can affect the parent layout
    if (const auto& parent = getParent()) {
        if (const auto& parentLayout = parent->getLayout())
            parentLayout->updateLater();
    }
}

void UIWidget::lock()
{
    if (isDestroyed())
        return;

    if (const auto& parent = getParent())
        parent->lockChild(static_self_cast<UIWidget>());
}

void UIWidget::unlock()
{
    if (isDestroyed())
        return;

    if (const auto& parent = getParent())
        parent->unlockChild(static_self_cast<UIWidget>());
}

void UIWidget::focus()
{
    if (isDestroyed())
        return;

    if (!isFocusable())
        return;

    if (const auto& parent = getParent())
        parent->focusChild(static_self_cast<UIWidget>(), Fw::ActiveFocusReason);
}

void UIWidget::recursiveFocus(const Fw::FocusReason reason)
{
    if (isDestroyed())
        return;

    if (const auto& parent = getParent()) {
        if (isFocusable())
            parent->focusChild(static_self_cast<UIWidget>(), reason);
        parent->recursiveFocus(reason);
    }
}

void UIWidget::lower()
{
    if (isDestroyed())
        return;

    const auto& parent = getParent();
    if (parent)
        parent->lowerChild(static_self_cast<UIWidget>());
}

void UIWidget::raise()
{
    if (isDestroyed())
        return;

    const auto& parent = getParent();
    if (parent)
        parent->raiseChild(static_self_cast<UIWidget>());
}

void UIWidget::grabMouse()
{
    if (isDestroyed())
        return;

    g_ui.setMouseReceiver(static_self_cast<UIWidget>());
}

void UIWidget::ungrabMouse()
{
    if (g_ui.getMouseReceiver() == static_self_cast<UIWidget>())
        g_ui.resetMouseReceiver();
}

void UIWidget::grabKeyboard()
{
    if (isDestroyed())
        return;

    g_ui.setKeyboardReceiver(static_self_cast<UIWidget>());
}

void UIWidget::ungrabKeyboard()
{
    if (g_ui.getKeyboardReceiver() == static_self_cast<UIWidget>())
        g_ui.resetKeyboardReceiver();
}

void UIWidget::bindRectToParent()
{
    if (isDestroyed())
        return;

    Rect boundRect = m_rect;
    const auto& parent = getParent();
    if (parent) {
        const auto& parentRect = parent->getPaddingRect();
        boundRect.bind(parentRect);
    }

    setRect(boundRect);
}

void UIWidget::internalDestroy()
{
    setProp(PropDestroyed, true);
    setProp(PropVisible, false);
    setProp(PropEnabled, false);
    m_focusedChild = nullptr;
    if (m_layout) {
        m_layout->setParent(nullptr);
        m_layout = nullptr;
    }

    m_parent = nullptr;
    m_lockedChildren.clear();
    m_childrenById.clear();

    for (const auto& child : m_children)
        child->internalDestroy();
    m_children.clear();

    for (const auto& [id, destroyCallback] : m_onDestroyCallbacks)
        destroyCallback();
    m_onDestroyCallbacks.clear();

    callLuaField("onDestroy");

    releaseLuaFieldsTable();

    g_ui.onWidgetDestroy(static_self_cast<UIWidget>());

    if (m_htmlNode) {
        m_htmlNode->destroy();
        m_htmlNode = nullptr;
    }
}

void UIWidget::destroy()
{
    if (isDestroyed())
        g_logger.warning("attempt to destroy widget '{}' ({}) two times", m_id, m_source);

    // hold itself reference
    const UIWidgetPtr self = static_self_cast<UIWidget>();
    setProp(PropDestroyed, true);

    // remove itself from parent
    if (const auto& parent = getParent())
        parent->removeChild(self);

    internalDestroy();
}

void UIWidget::destroyChildren()
{
    const auto& layout = getLayout();
    if (layout)
        layout->disableUpdates();

    m_focusedChild = nullptr;
    m_lockedChildren.clear();
    m_childrenById.clear();

    while (!m_children.empty()) {
        UIWidgetPtr child = m_children.front();
        m_children.pop_front();

        child->setParent(nullptr);
        m_layout->removeWidget(child);
        child->destroy();

        child->m_childIndex = -1;

        // remove access to child via widget.childId
        if (child->hasProp(PropCustomId)) {
            std::string widgetId = child->getId();
            if (hasLuaField(widgetId)) {
                clearLuaField(widgetId);
            }
        }
    }

    if (layout)
        layout->enableUpdates();
}

void UIWidget::removeChildren()
{
    const UILayoutPtr layout = getLayout();
    if (layout)
        layout->disableUpdates();

    m_focusedChild = nullptr;
    m_lockedChildren.clear();
    while (!m_children.empty()) {
        removeChild(m_children.front());
    }

    if (layout)
        layout->enableUpdates();
}

void UIWidget::hideChildren()
{
    for (const auto& child : m_children)
        child->hide();
}

void UIWidget::showChildren()
{
    for (const auto& child : m_children)
        child->show();
}

void UIWidget::setId(const std::string_view id)
{
    if (id == m_id)
        return;

    setProp(PropCustomId, true);

    if (m_parent) {
        m_parent->clearLuaField(m_id);
        m_parent->setLuaField(id, static_self_cast<UIWidget>());
        m_parent->m_childrenById.erase(m_id);
        m_parent->m_childrenById[id] = static_self_cast<UIWidget>();
    }

    m_id = id;
    callLuaField("onIdChange", id);
}

void UIWidget::setParent(const UIWidgetPtr& parent)
{
    // remove from old parent
    const auto& oldParent = getParent();

    // the parent is already the same
    if (oldParent == parent)
        return;

    const UIWidgetPtr self = static_self_cast<UIWidget>();
    if (oldParent && oldParent->hasChild(self))
        oldParent->removeChild(self);

    // reset parent
    m_parent.reset();

    // set new parent
    if (parent) {
        m_parent = parent;

        // add to parent if needed
        if (!parent->hasChild(self))
            parent->addChild(self);
    }
}

void UIWidget::setLayout(const UILayoutPtr& layout)
{
    if (!layout)
        throw Exception("attempt to set a nil layout to a widget");

    if (m_layout)
        m_layout->disableUpdates();

    layout->setParent(static_self_cast<UIWidget>());
    layout->disableUpdates();

    for (const auto& child : m_children) {
        if (m_layout)
            m_layout->removeWidget(child);
        layout->addWidget(child);
    }

    if (m_layout) {
        m_layout->enableUpdates();
        m_layout->setParent(nullptr);
        m_layout->update();
    }

    layout->enableUpdates();
    m_layout = layout;
}

bool UIWidget::setRect(const Rect& rect)
{
    Rect clampedRect = rect;
    if (m_minSize.width() != -1 || m_minSize.height() != -1 || m_maxSize.width() != -1 || m_maxSize.height() != -1) {
        Size minSize, maxSize;
        minSize.setWidth(m_minSize.width() >= 0 ? m_minSize.width() : 0);
        minSize.setHeight(m_minSize.height() >= 0 ? m_minSize.height() : 0);
        maxSize.setWidth(m_maxSize.width() >= 0 ? m_maxSize.width() : INT_MAX);
        maxSize.setHeight(m_maxSize.height() >= 0 ? m_maxSize.height() : INT_MAX);
        clampedRect = rect.clamp(minSize, maxSize);
    }

    if (!isOnHtml()) {
        if (m_width.unit == Unit::Px)
            m_width.valueCalculed = clampedRect.width();
        if (m_height.unit == Unit::Px)
            m_height.valueCalculed = clampedRect.height();
    }
    /*
    if(rect.width() > 8192 || rect.height() > 8192) {
        g_logger.error("attempt to set huge rect size ({}) for {}", stdext::to_string(rect), m_id);
        return false;
    }
    */

    // only update if the rect really changed
    if (clampedRect == m_rect)
        return false;

    Rect oldRect = m_rect;
    m_rect = clampedRect;

    // updates own layout
    updateLayout();

    // avoid massive update events
    if (!hasProp(PropUpdateEventScheduled)) {
        auto self = static_self_cast<UIWidget>();
        g_dispatcher.deferEvent([self, oldRect] {
            self->setProp(PropUpdateEventScheduled, false);
            const auto& rect = self->getRect();
            if (oldRect != rect) {
                // update hovered widget when moved behind mouse area
                if (self->containsPoint(g_window.getMousePosition()))
                    g_ui.updateHoveredWidget();

                if (oldRect.width() != rect.width())
                    self->callLuaField("onWidthChange", rect.width(), oldRect.width());
                if (oldRect.height() != rect.height())
                    self->callLuaField("onHeightChange", rect.height(), oldRect.height());

                self->callLuaField("onResize", oldRect, rect);
                self->onGeometryChange(oldRect, rect);
            }
        });
        setProp(PropUpdateEventScheduled, true);
    }

    return true;
}

void UIWidget::setStyle(const std::string_view styleName)
{
    OTMLNodePtr styleNode = g_ui.getStyle(styleName);
    if (!styleNode) {
        g_logger.traceError("unable to retrieve style '{}': not a defined style", styleName);
        return;
    }
    styleNode = styleNode->clone();
    applyStyle(styleNode);
    m_style = styleNode;
    updateStyle();
}

void UIWidget::setStyleFromNode(const OTMLNodePtr& styleNode)
{
    applyStyle(styleNode);
    m_style = styleNode;
    updateStyle();
}

void UIWidget::setEnabled(const bool enabled)
{
    if (hasProp(PropEnabled) == enabled)
        return;

    setProp(PropEnabled, enabled);

    updateState(Fw::DisabledState);
    updateState(Fw::ActiveState);

    callLuaField("onEnabled", enabled);
}

void UIWidget::setVisible(const bool visible)
{
    if (hasProp(PropVisible) == visible)
        return;

    setProp(PropVisible, visible);

    // hiding a widget make it lose focus
    if (!visible && isFocused()) {
        if (const auto& parent = getParent())
            parent->focusPreviousChild(Fw::ActiveFocusReason, true);
    }

    // visibility can change change parent layout
    updateParentLayout();

    updateState(Fw::ActiveState);
    updateState(Fw::HiddenState);

    // visibility can change the current hovered widget
    if (visible)
        g_ui.onWidgetAppear(static_self_cast<UIWidget>());
    else
        g_ui.onWidgetDisappear(static_self_cast<UIWidget>());

    refreshHtml(true);
}

void UIWidget::setOn(const bool on)
{
    setState(Fw::OnState, on);
}

void UIWidget::setChecked(const bool checked)
{
    if (setState(Fw::CheckedState, checked))
        callLuaField("onCheckChange", checked);
}

void UIWidget::setFocusable(const bool focusable)
{
    if (isFocusable() == focusable)
        return;

    setProp(PropFocusable, focusable);

    // make parent focus another child
    if (const auto& parent = getParent()) {
        if (!focusable && isFocused()) {
            parent->focusPreviousChild(Fw::ActiveFocusReason, true);
        } else if (focusable && !parent->getFocusedChild() && parent->getAutoFocusPolicy() != Fw::AutoFocusNone) {
            focus();
        }
    }
}

void UIWidget::setPhantom(const bool phantom)
{
    setProp(PropPhantom, phantom);
}

void UIWidget::setDraggable(const bool draggable)
{
    setProp(PropDraggable, draggable);
}

void UIWidget::setFixedSize(const bool fixed)
{
    setProp(PropFixedSize, fixed);
    updateParentLayout();
}

void UIWidget::setLastFocusReason(const Fw::FocusReason reason)
{
    m_lastFocusReason = reason;
}

void UIWidget::setAutoFocusPolicy(const Fw::AutoFocusPolicy policy)
{
    m_autoFocusPolicy = policy;
}

void UIWidget::setVirtualOffset(const Point& offset)
{
    m_virtualOffset = offset;
    if (m_layout)
        m_layout->update();
}

bool UIWidget::isAnchored()
{
    if (const auto& parent = getParent()) {
        if (const auto& anchorLayout = parent->getAnchoredLayout())
            return anchorLayout->hasAnchors(static_self_cast<UIWidget>());
    }

    return false;
}

bool UIWidget::isChildLocked(const UIWidgetPtr& child)
{
    const auto it = std::ranges::find(m_lockedChildren, child);
    return it != m_lockedChildren.end();
}

bool UIWidget::hasChild(const UIWidgetPtr& child)
{
    const auto it = std::ranges::find(m_children, child);
    if (it != m_children.end())
        return true;

    return false;
}

Rect UIWidget::getPaddingRect()
{
    Rect rect = m_rect;
    rect.expand(-m_padding.top, -m_padding.right, -m_padding.bottom, -m_padding.left);
    return rect;
}

Rect UIWidget::getMarginRect()
{
    Rect rect = m_rect;
    rect.expand(m_margin.top, m_margin.right, m_margin.bottom, m_margin.left);
    return rect;
}

Rect UIWidget::getChildrenRect()
{
    Rect childrenRect;
    for (const auto& child : m_children) {
        if (!child->isExplicitlyVisible() || !child->getRect().isValid())
            continue;
        Rect marginRect = child->getMarginRect();
        if (!childrenRect.isValid())
            childrenRect = marginRect;
        else
            childrenRect = childrenRect.united(marginRect);
    }

    const Rect myClippingRect = getPaddingRect();
    if (!childrenRect.isValid())
        childrenRect = myClippingRect;
    else {
        if (childrenRect.width() < myClippingRect.width())
            childrenRect.setWidth(myClippingRect.width());
        if (childrenRect.height() < myClippingRect.height())
            childrenRect.setHeight(myClippingRect.height());
    }

    return childrenRect;
}

UIAnchorLayoutPtr UIWidget::getAnchoredLayout()
{
    const auto& parent = getParent();
    if (!parent)
        return nullptr;

    const auto& layout = parent->getLayout();
    if (layout->isUIAnchorLayout())
        return layout->static_self_cast<UIAnchorLayout>();

    return nullptr;
}

UIAnchorList UIWidget::getAnchorsGroup() {
    if (const auto& layout = getAnchoredLayout()) {
        auto it = layout->getAnchorsGroup().find(static_self_cast<UIWidget>());
        if (it != layout->getAnchorsGroup().end())
            return it->second->getAnchors();
    }

    return {};
}

std::vector<Fw::AnchorEdge> UIWidget::getAnchors() {
    const auto& anchors = getAnchorsGroup();
    std::vector<Fw::AnchorEdge> anchorsVec;
    anchorsVec.reserve(anchors.size());
    for (const auto& anchor : anchors) {
        anchorsVec.emplace_back(anchor->getAnchoredEdge());
    }

    return anchorsVec;
}

Fw::AnchorEdge UIWidget::getAnchorType(Fw::AnchorEdge anchorType) {
    const auto& anchors = getAnchorsGroup();
    for (const auto& anchor : anchors) {
        if (anchor->getAnchoredEdge() == anchorType) {
            return anchor->getHookedEdge();
        }
    }

    return Fw::AnchorNone;
}

UIWidgetPtr UIWidget::getRootParent()
{
    if (const auto& parent = getParent())
        return parent->getRootParent();

    return static_self_cast<UIWidget>();
}

UIWidgetPtr UIWidget::getChildAfter(const UIWidgetPtr& relativeChild)
{
    return relativeChild->m_childIndex == static_cast<int32_t>(m_children.size()) ?
        nullptr : m_children[relativeChild->m_childIndex];
}

UIWidgetPtr UIWidget::getChildBefore(const UIWidgetPtr& relativeChild)
{
    return relativeChild->m_childIndex <= 1 ? nullptr : m_children[relativeChild->m_childIndex - 2];
}

UIWidgetPtr UIWidget::getChildById(const std::string_view childId)
{
    if (const auto it = m_childrenById.find(childId); it != m_childrenById.end())
        return it->second;

    return nullptr;
}

UIWidgetPtr UIWidget::getChildByPos(const Point& childPos)
{
    if (!containsPaddingPoint(childPos))
        return nullptr;

    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->isExplicitlyVisible() && child->containsPoint(childPos))
            return child;
    }

    return nullptr;
}

UIWidgetPtr UIWidget::getChildByIndex(int index)
{
    index = index <= 0 ? (m_children.size() + index) : index - 1;
    if (index >= 0 && static_cast<size_t>(index) < m_children.size())
        return m_children[index];

    return nullptr;
}

UIWidgetPtr UIWidget::getChildByState(const Fw::WidgetState state)
{
    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->hasState(state))
            return child;
    }

    return nullptr;
}

UIWidgetPtr UIWidget::recursiveGetChildById(const std::string_view id)
{
    const auto& widget = getChildById(id);
    if (widget)
        return widget;

    for (const auto& child : m_children) {
        if (const auto& w = child->recursiveGetChildById(id))
            return w;
    }

    return nullptr;
}

UIWidgetPtr UIWidget::recursiveGetChildByPos(const Point& childPos, const bool wantsPhantom)
{
    if (isClipping() && !containsPaddingPoint(childPos))
        return nullptr;

    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->isExplicitlyVisible()) {
            if (const auto& subChild = child->recursiveGetChildByPos(childPos, wantsPhantom))
                return subChild;

            if (child->containsPoint(childPos) && (wantsPhantom || !child->isPhantom()))
                return child;
        }
    }
    return nullptr;
}

UIWidgetPtr UIWidget::recursiveGetChildByState(const Fw::WidgetState state, const bool wantsPhantom)
{
    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->hasState(state)) {
            if (const auto& subChild = child->recursiveGetChildByState(state, wantsPhantom))
                return subChild;

            if (wantsPhantom || !child->isPhantom())
                return child;
        }
    }
    return nullptr;
}

UIWidgetList UIWidget::recursiveGetChildren()
{
    UIWidgetList children;
    for (const auto& child : m_children) {
        if (const UIWidgetList& subChildren = child->recursiveGetChildren(); !subChildren.empty())
            children.insert(children.end(), subChildren.begin(), subChildren.end());

        children.emplace_back(child);
    }

    return children;
}

UIWidgetList UIWidget::recursiveGetChildrenByPos(const Point& childPos)
{
    UIWidgetList children;
    if (isClipping() && !containsPaddingPoint(childPos))
        return children;

    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->isExplicitlyVisible()) {
            if (const UIWidgetList& subChildren = child->recursiveGetChildrenByPos(childPos); !subChildren.empty())
                children.insert(children.end(), subChildren.begin(), subChildren.end());

            if (child->containsPoint(childPos))
                children.emplace_back(child);
        }
    }

    return children;
}

UIWidgetList UIWidget::recursiveGetChildrenByMarginPos(const Point& childPos)
{
    UIWidgetList children;
    if (isClipping() && !containsPaddingPoint(childPos))
        return children;

    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->isExplicitlyVisible()) {
            UIWidgetList subChildren = child->recursiveGetChildrenByMarginPos(childPos);
            if (!subChildren.empty())
                children.insert(children.end(), subChildren.begin(), subChildren.end());
            if (child->containsMarginPoint(childPos))
                children.emplace_back(child);
        }
    }
    return children;
}

UIWidgetPtr UIWidget::getChildByStyleName(const std::string_view styleName) {
    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->getStyleName() == styleName)
            return child;
    }
    return nullptr;
}

UIWidgetPtr UIWidget::getNearestChild(const Point& pos)
{
    if (m_children.empty())
        return nullptr;

    UIWidgetPtr nearestChild = nullptr;
    float minDistance = (std::numeric_limits<float>::max)();
    for (const auto& child : m_children) {
        if (!child->isExplicitlyVisible())
            continue;

        const Point childCenter = child->getRect().center();
        const auto dx = static_cast<float>(pos.x - childCenter.x);
        const auto dy = static_cast<float>(pos.y - childCenter.y);
        const float distance = std::sqrt(dx * dx + dy * dy);
        if (distance < minDistance) {
            minDistance = distance;
            nearestChild = child;
        }
    }
    return nearestChild;
}

UIWidgetList UIWidget::recursiveGetChildrenByState(const Fw::WidgetState state)
{
    UIWidgetList children;
    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->hasState(state)) {
            UIWidgetList subChildren = child->recursiveGetChildrenByState(state);
            if (!subChildren.empty())
                children.insert(children.end(), subChildren.begin(), subChildren.end());
            children.emplace_back(child);
        }
    }
    return children;
}

UIWidgetList UIWidget::recursiveGetChildrenByStyleName(const std::string_view styleName)
{
    UIWidgetList children;
    for (const auto& child : m_children) {
        if (child->getStyleName() == styleName)
            children.emplace_back(child);

        const auto& subChildren = child->recursiveGetChildrenByStyleName(styleName);
        if (!subChildren.empty())
            children.insert(children.end(), subChildren.begin(), subChildren.end());
    }
    return children;
}

UIWidgetPtr UIWidget::backwardsGetWidgetById(const std::string_view id)
{
    UIWidgetPtr widget = getChildById(id);
    if (!widget) {
        if (const auto& parent = getParent())
            widget = parent->backwardsGetWidgetById(id);
    }

    return widget;
}

void UIWidget::setProp(const FlagProp prop, const bool v, const bool callEvent)
{
    // Note: Be aware that setProp is called many times, there will be a cost,
    // so only call this event if it is really necessary.
    // callEvent = false by default
    if (callEvent) {
        const bool lastProp = hasProp(prop);
        if (lastProp != v)
            callLuaField("onPropertyChange", prop, v, lastProp);
    }

    if (v) m_flagsProp |= prop; else m_flagsProp &= ~prop;
}

bool UIWidget::setState(const Fw::WidgetState state, const bool on)
{
    if (state == Fw::InvalidState)
        return false;

    const int oldStates = m_states;
    if (on)
        m_states |= state;
    else
        m_states &= ~state;

    if (oldStates == m_states)
        return false;

    updateStyle();
    return true;
}

bool UIWidget::hasState(const Fw::WidgetState state)
{
    if (state == Fw::InvalidState)
        return false;

    return (m_states & state);
}

void UIWidget::updateState(const Fw::WidgetState state, bool newState)
{
    if (isDestroyed())
        return;

    bool newStatus = true;
    const bool oldStatus = hasState(state);
    bool updateChildren = false;

    switch (state) {
        case Fw::FirstState: { newStatus = isFirstChild(); break; }
        case Fw::MiddleState: { newStatus = isMiddleChild(); break; }
        case Fw::LastState: { newStatus = isLastChild(); break; }
        case Fw::AlternateState: { newStatus = (getParent() && (getParent()->getChildIndex(static_self_cast<UIWidget>()) % 2) == 1); break; }
        case Fw::FocusState: { newStatus = (getParent() && getParent()->getFocusedChild() == static_self_cast<UIWidget>()); break; }
        case Fw::HoverState: { newStatus = isOnHtml() ? newState : (g_ui.getHoveredWidget() == static_self_cast<UIWidget>() && isEnabled()); break; }
        case Fw::PressedState: { newStatus = isOnHtml() ? newState : (g_ui.getPressedWidget() == static_self_cast<UIWidget>()); break; }
        case Fw::DraggingState: { newStatus = (g_ui.getDraggingWidget() == static_self_cast<UIWidget>()); break; }
        case Fw::ActiveState:
        {
            UIWidgetPtr widget = static_self_cast<UIWidget>();
            UIWidgetPtr parent;
            do {
                parent = widget->getParent();
                if (!widget->isExplicitlyEnabled() ||
                    ((parent && parent->getFocusedChild() != widget))) {
                    newStatus = false;
                    break;
                }
            } while ((widget = parent));

            updateChildren = newStatus != oldStatus;
            break;
        }
        case Fw::DisabledState:
        {
            bool enabled = true;
            UIWidgetPtr widget = static_self_cast<UIWidget>();
            do {
                if (!widget->isExplicitlyEnabled()) {
                    enabled = false;
                    break;
                }
            } while ((widget = widget->getParent()));
            newStatus = !enabled;
            updateChildren = newStatus != oldStatus;
            break;
        }
        case Fw::HiddenState:
        {
            bool visible = true;
            UIWidgetPtr widget = static_self_cast<UIWidget>();
            do {
                if (!widget->isExplicitlyVisible()) {
                    visible = false;
                    break;
                }
            } while ((widget = widget->getParent()));
            newStatus = !visible;
            updateChildren = newStatus != oldStatus;
            break;
        }
        case Fw::MobileState:
        {
            newStatus = g_platform.isMobile();
            break;
        }

        default:
            return;
    }

    if (updateChildren) {
        // do a backup of children list, because it may change while looping it
        const UIWidgetList& children = m_children;
        for (const auto& child : children)
            child->updateState(state);
    }

    if (setState(state, newStatus)) {
        // disabled widgets cannot have hover state
        if (state == Fw::DisabledState && !newStatus && isHovered()) {
            g_ui.updateHoveredWidget();
        } else if (state == Fw::HiddenState) {
            onVisibilityChange(!newStatus);
        }
    }
}

void UIWidget::updateStates()
{
    if (isDestroyed())
        return;

    for (int state = 1; state != Fw::LastWidgetState; state <<= 1)
        updateState(static_cast<Fw::WidgetState>(state));
}

void UIWidget::updateChildrenIndexStates()
{
    if (isDestroyed())
        return;

    if (hasProp(PropUpdateChildrenIndexStates))
        return;

    setProp(PropUpdateChildrenIndexStates, true);

    g_dispatcher.deferEvent([self = static_self_cast<UIWidget>()] {
        for (const auto& child : self->m_children) {
            child->updateState(Fw::FirstState);
            child->updateState(Fw::MiddleState);
            child->updateState(Fw::LastState);
            child->updateState(Fw::AlternateState);
        }
        self->setProp(PropUpdateChildrenIndexStates, false);
    });
}

void UIWidget::updateStyle()
{
    if (isDestroyed())
        return;

    if (hasProp(PropLoadingStyle) && !hasProp(PropUpdateStyleScheduled)) {
        UIWidgetPtr self = static_self_cast<UIWidget>();
        g_dispatcher.deferEvent([self] {
            self->setProp(PropUpdateStyleScheduled, false);
            self->updateStyle();
        });
        setProp(PropUpdateStyleScheduled, true);
        return;
    }

    if (!m_style)
        return;

    const auto& newStateStyle = OTMLNode::create();

    // copy only the changed styles from default style
    if (m_stateStyle) {
        for (const auto& node : m_stateStyle->children()) {
            if (const auto& otherNode = m_style->get(node->tag()))
                newStateStyle->addChild(otherNode->clone());
        }
    }

    // checks for states combination
    for (const auto& style : m_style->children()) {
        if (style->tag().starts_with("$")) {
            std::string statesStr = style->tag().substr(1);
            std::vector<std::string> statesSplit = stdext::split(statesStr, " ");

            bool match = true;
            for (std::string stateStr : statesSplit) {
                if (stateStr.length() == 0)
                    continue;

                const bool notstate = (stateStr[0] == '!');
                if (notstate)
                    stateStr = stateStr.substr(1);

                const bool stateOn = hasState(Fw::translateState(stateStr));
                if ((!notstate && !stateOn) || (notstate && stateOn))
                    match = false;
            }

            // merge states styles
            if (match) {
                newStateStyle->merge(style);
            }
        }
    }

    //TODO: prevent setting already set proprieties

    applyStyle(newStateStyle);
    m_stateStyle = newStateStyle;
}

void UIWidget::onStyleApply(const std::string_view, const OTMLNodePtr& styleNode)
{
    if (isDestroyed())
        return;

    // first set id
    if (const auto& node = styleNode->get("id"))
        setId(node->value());

    parseBaseStyle(styleNode);
    parseImageStyle(styleNode);
    parseTextStyle(styleNode);
    parseCustomStyle(styleNode);

    repaint();
}

void UIWidget::onGeometryChange(const Rect& oldRect, const Rect& newRect)
{
    if (isTextWrap() && oldRect.size() != newRect.size())
        updateText();

    // move children that is outside the parent rect to inside again
    for (const auto& child : m_children) {
        if (!child->isAnchored() && child->isVisible())
            child->bindRectToParent();
    }

    callLuaField("onGeometryChange", newRect, oldRect);

    repaint();
}

void UIWidget::onLayoutUpdate()
{
    callLuaField("onLayoutUpdate");
}

void UIWidget::onFocusChange(const bool focused, const Fw::FocusReason reason)
{
    callLuaField("onFocusChange", focused, reason);
}

void UIWidget::onChildFocusChange(const UIWidgetPtr& focusedChild, const UIWidgetPtr& unfocusedChild, const Fw::FocusReason reason)
{
    callLuaField("onChildFocusChange", focusedChild, unfocusedChild, reason);
}

void UIWidget::onHoverChange(const bool hovered)
{
    callLuaField("onHoverChange", hovered);
}

void UIWidget::onTextHoverChange(const std::string& text, bool hovered)
{
    callLuaField("onTextHoverChange", text, hovered);
}

void UIWidget::onVisibilityChange(const bool visible)
{
    if (!isAnchored())
        bindRectToParent();
    callLuaField("onVisibilityChange", visible);
}

bool UIWidget::onDragEnter(const Point& mousePos)
{
    return callLuaField<bool>("onDragEnter", mousePos);
}

bool UIWidget::onDragLeave(const UIWidgetPtr droppedWidget, const Point& mousePos)
{
    return callLuaField<bool>("onDragLeave", droppedWidget, mousePos);
}

bool UIWidget::onDragMove(const Point& mousePos, const Point& mouseMoved)
{
    return callLuaField<bool>("onDragMove", mousePos, mouseMoved);
}

bool UIWidget::onDrop(const UIWidgetPtr draggedWidget, const Point& mousePos)
{
    return callLuaField<bool>("onDrop", draggedWidget, mousePos);
}

bool UIWidget::onKeyText(const std::string_view keyText)
{
    return callLuaField<bool>("onKeyText", keyText);
}

bool UIWidget::onKeyDown(const uint8_t keyCode, const int keyboardModifiers)
{
    return callLuaField<bool>("onKeyDown", keyCode, keyboardModifiers);
}

bool UIWidget::onKeyPress(const uint8_t keyCode, const int keyboardModifiers, const int autoRepeatTicks)
{
    return callLuaField<bool>("onKeyPress", keyCode, keyboardModifiers, autoRepeatTicks);
}

bool UIWidget::onKeyUp(const uint8_t keyCode, const int keyboardModifiers)
{
    return callLuaField<bool>("onKeyUp", keyCode, keyboardModifiers);
}

bool UIWidget::onMousePress(const Point& mousePos, const Fw::MouseButton button)
{
    if (button == Fw::MouseLeftButton) {
        if (m_clickTimer.running() && m_clickTimer.ticksElapsed() <= 200) {
            if (onDoubleClick(mousePos))
                return true;
            m_clickTimer.stop();
        } else
            m_clickTimer.restart();
        m_lastClickPosition = mousePos;
    }

    return callLuaField<bool>("onMousePress", mousePos, button);
}

bool UIWidget::onMouseRelease(const Point& mousePos, const Fw::MouseButton button)
{
    return callLuaField<bool>("onMouseRelease", mousePos, button);
}

bool UIWidget::onMouseMove(const Point& mousePos, const Point& mouseMoved)
{
    return callLuaField<bool>("onMouseMove", mousePos, mouseMoved);
}

bool UIWidget::onMouseWheel(const Point& mousePos, const Fw::MouseWheelDirection direction)
{
    return callLuaField<bool>("onMouseWheel", mousePos, direction);
}

bool UIWidget::onClick(const Point& mousePos)
{
    if (hasEventListener(EVENT_TEXT_CLICK)) {
        std::string clickedText = getTextByPos(mousePos);
        if (!clickedText.empty()) {
            callLuaField("onTextClick", clickedText, mousePos);
        }
    }
    return callLuaField<bool>("onClick", mousePos);
}

bool UIWidget::onDoubleClick(const Point& mousePos)
{
    return callLuaField<bool>("onDoubleClick", mousePos);
}

int UIWidget::getImageTextureWidth() { return m_imageTexture ? m_imageTexture->getWidth() : 0; }
int UIWidget::getImageTextureHeight() { return m_imageTexture ? m_imageTexture->getHeight() : 0; }
std::string UIWidget::getStyleName() { return m_style->tag(); }
UIWidgetPtr UIWidget::getHoveredChild()
{
    const auto& hovered = g_ui.getHoveredWidget();
    return hovered ? getChildById(hovered->getId()) : nullptr;
}

bool UIWidget::propagateOnKeyText(const std::string_view keyText)
{
    // do a backup of children list, because it may change while looping it
    UIWidgetList children;
    for (const auto& child : m_children) {
        // events on hidden or disabled widgets are discarded
        if (!child->isExplicitlyEnabled() || !child->isExplicitlyVisible())
            continue;

        // key events go only to containers or focused child
        if (child->isFocused())
            children.emplace_back(child);
    }

    for (const auto& child : children) {
        if (child->propagateOnKeyText(keyText))
            return true;
    }

    return onKeyText(keyText);
}

bool UIWidget::propagateOnKeyDown(const uint8_t keyCode, const int keyboardModifiers)
{
    // do a backup of children list, because it may change while looping it
    UIWidgetList children;
    for (const auto& child : m_children) {
        // events on hidden or disabled widgets are discarded
        if (!child->isExplicitlyEnabled() || !child->isExplicitlyVisible())
            continue;

        // key events go only to containers or focused child
        if (child->isFocused())
            children.emplace_back(child);
    }

    for (const auto& child : children) {
        if (child->propagateOnKeyDown(keyCode, keyboardModifiers))
            return true;
    }

    return onKeyDown(keyCode, keyboardModifiers);
}

bool UIWidget::propagateOnKeyPress(const uint8_t keyCode, const int keyboardModifiers, const int autoRepeatTicks)
{
    // do a backup of children list, because it may change while looping it
    UIWidgetList children;
    for (const auto& child : m_children) {
        // events on hidden or disabled widgets are discarded
        if (!child->isExplicitlyEnabled() || !child->isExplicitlyVisible())
            continue;

        // key events go only to containers or focused child
        if (child->isFocused())
            children.emplace_back(child);
    }

    for (const auto& child : children) {
        if (child->propagateOnKeyPress(keyCode, keyboardModifiers, autoRepeatTicks))
            return true;
    }

    if (autoRepeatTicks == 0 || autoRepeatTicks >= m_autoRepeatDelay)
        return onKeyPress(keyCode, keyboardModifiers, autoRepeatTicks);
    return false;
}

bool UIWidget::propagateOnKeyUp(const uint8_t keyCode, const int keyboardModifiers)
{
    // do a backup of children list, because it may change while looping it
    UIWidgetList children;
    for (const auto& child : m_children) {
        // events on hidden or disabled widgets are discarded
        if (!child->isExplicitlyEnabled() || !child->isExplicitlyVisible())
            continue;

        // key events go only to focused child
        if (child->isFocused())
            children.emplace_back(child);
    }

    for (const auto& child : children) {
        if (child->propagateOnKeyUp(keyCode, keyboardModifiers))
            return true;
    }

    return onKeyUp(keyCode, keyboardModifiers);
}

bool UIWidget::propagateOnMouseEvent(const Point& mousePos, UIWidgetList& widgetList, bool checkContainsPoint)
{
    if (isClipping() && !containsPaddingPoint(mousePos))
        return false;

    bool ret = false;
    for (auto& child : std::ranges::reverse_view(m_children)) {
        if (child->isExplicitlyEnabled() && child->isExplicitlyVisible()) {
            if (child->propagateOnMouseEvent(mousePos, widgetList, true)) {
                ret = true;
                break;
            }
        }
    }

    if (!checkContainsPoint || containsPoint(mousePos)) {
        widgetList.emplace_back(static_self_cast<UIWidget>());

        if (!isPhantom() && !isOnHtml() || isDraggable())
            ret = true;
    }

    return ret;
}

bool UIWidget::propagateOnMouseMove(const Point& mousePos, const Point& mouseMoved, UIWidgetList& widgetList)
{
    if (containsPaddingPoint(mousePos)) {
        for (const auto& child : m_children) {
            if (child->isExplicitlyVisible() && child->isExplicitlyEnabled() && child->containsPoint(mousePos))
                child->propagateOnMouseMove(mousePos, mouseMoved, widgetList);
        }
    }

    widgetList.emplace_back(static_self_cast<UIWidget>());

    return true;
}

void UIWidget::move(int x, int y) {
    if (getX() == x && getY() == y)
        return;

    if (!hasProp(PropUpdatingMove)) {
        setProp(PropUpdatingMove, true);
        g_dispatcher.deferEvent([self = static_self_cast<UIWidget>()] {
            const auto rect = self->m_rect;
            self->m_rect = {}; // force update
            self->setRect(rect);
            self->setProp(PropUpdatingMove, false);
        });
    }

    m_rect = { x, y, getSize() };
}

void UIWidget::setShader(const std::string_view name) {
    if (name.empty()) {
        m_shader = nullptr;
        return;
    }

    g_dispatcher.addEvent([this, shader = std::string(name.data())] {
        m_shader = g_shaders.getShader(shader);
    });
}

void UIWidget::repaint() { g_drawPool.repaint(DrawPoolType::FOREGROUND); }

void UIWidget::disableUpdateTemporarily() {
    if (hasProp(PropDisableUpdateTemporarily) || !m_layout)
        return;

    setProp(PropDisableUpdateTemporarily, true);
    m_layout->disableUpdates();
    g_dispatcher.deferEvent([this, self = static_self_cast<UIWidget>()] {
        if (m_layout) {
            m_layout->enableUpdates();
            updateLayout();
        }
        setProp(PropDisableUpdateTemporarily, false);
    });
}
void UIWidget::addOnDestroyCallback(const std::string& id, const std::function<void()>&& callback)
{
    m_onDestroyCallbacks.emplace(id, callback);
}

void UIWidget::removeOnDestroyCallback(const std::string& id)
{
    if (hasProp(PropDestroyed))
        return;

    const auto it = m_onDestroyCallbacks.find(id);
    if (it != m_onDestroyCallbacks.end())
        m_onDestroyCallbacks.erase(it);
}

std::vector<UIWidgetPtr> UIWidget::querySelectorAll(const std::string& selector) {
    std::vector<UIWidgetPtr> list;
    if (!m_htmlNode)
        return list;

    const auto& nodeList = m_htmlNode->querySelectorAll(selector);
    list.reserve(nodeList.size());
    for (const auto& node : nodeList) {
        if (const auto& widget = node->getWidget())
            list.emplace_back(widget);
    }

    return list;
}

UIWidgetPtr UIWidget::querySelector(const std::string& selector) {
    const auto& node = m_htmlNode->querySelector(selector);
    if (node) {
        if (const auto& widget = node->getWidget())
            return widget;
    }
    return nullptr;
}

UIWidgetPtr UIWidget::insert(int32_t index, const std::string& html) {
    if (!isOnHtml()) return nullptr;
    m_insertChildIndex = index;
    return g_html.createWidgetFromHTML(html, static_self_cast<UIWidget>(), m_htmlRootId);
}

UIWidgetPtr UIWidget::append(const std::string& html) {
    if (!isOnHtml()) return nullptr;
    return g_html.createWidgetFromHTML(html, static_self_cast<UIWidget>(), m_htmlRootId);
}

UIWidgetPtr UIWidget::prepend(const std::string& html) {
    return insert(1, html);
}

UIWidgetPtr UIWidget::html(const std::string& html) {
    destroyChildren();
    return append(html);
}

size_t UIWidget::remove(const std::string& queryString) {
    if (!isOnHtml()) return 0;

    const auto& nodes = querySelectorAll(queryString);
    for (const auto& node : nodes) {
        node->destroy();
    }

    return nodes.size();
}

const UIWidgetStyle& UIWidget::style() const
{
    m_styleCache.display = m_displayType;
    m_styleCache.position = m_positionType;
    m_styleCache.flexDirection = m_flexContainer.direction;
    m_styleCache.flexWrap = m_flexContainer.wrap;
    m_styleCache.justifyContent = m_flexContainer.justify;
    m_styleCache.alignItems = m_flexContainer.alignItems;
    m_styleCache.alignContent = m_flexContainer.alignContent;
    m_styleCache.rowGap = m_flexContainer.rowGap;
    m_styleCache.columnGap = m_flexContainer.columnGap;
    m_styleCache.order = m_flexItem.order;
    m_styleCache.flexGrow = m_flexItem.flexGrow;
    m_styleCache.flexShrink = m_flexItem.flexShrink;
    m_styleCache.flexBasis = m_flexItem.basis;
    m_styleCache.alignSelf = m_flexItem.alignSelf;
    m_styleCache.width = m_width;
    m_styleCache.height = m_height;
    m_styleCache.minWidth = m_minSize.width();
    m_styleCache.minHeight = m_minSize.height();
    m_styleCache.maxWidth = m_maxSize.width();
    m_styleCache.maxHeight = m_maxSize.height();
    m_styleCache.marginLeftAuto = m_marginLeftAuto;
    m_styleCache.marginRightAuto = m_marginRightAuto;
    return m_styleCache;
}

void UIWidget::setFlexDirection(FlexDirection direction)
{
    if (m_flexContainer.direction == direction)
        return;
    m_flexContainer.direction = direction;
    updateLayout();
}

void UIWidget::setFlexWrap(FlexWrap wrap)
{
    if (m_flexContainer.wrap == wrap)
        return;
    m_flexContainer.wrap = wrap;
    updateLayout();
}

void UIWidget::setJustifyContent(JustifyContent justify)
{
    if (m_flexContainer.justify == justify)
        return;
    m_flexContainer.justify = justify;
    updateLayout();
}

void UIWidget::setAlignItems(AlignItems align)
{
    if (m_flexContainer.alignItems == align)
        return;
    m_flexContainer.alignItems = align;
    updateLayout();
}

void UIWidget::setAlignContent(AlignContent align)
{
    if (m_flexContainer.alignContent == align)
        return;
    m_flexContainer.alignContent = align;
    updateLayout();
}

void UIWidget::setRowGap(int gap)
{
    gap = std::max(0, gap);
    if (m_flexContainer.rowGap == gap)
        return;
    m_flexContainer.rowGap = gap;
    updateLayout();
}

void UIWidget::setColumnGap(int gap)
{
    gap = std::max(0, gap);
    if (m_flexContainer.columnGap == gap)
        return;
    m_flexContainer.columnGap = gap;
    updateLayout();
}

void UIWidget::setGap(int rowGap, int columnGap)
{
    rowGap = std::max(0, rowGap);
    columnGap = std::max(0, columnGap);
    bool changed = false;
    if (m_flexContainer.rowGap != rowGap) {
        m_flexContainer.rowGap = rowGap;
        changed = true;
    }
    if (m_flexContainer.columnGap != columnGap) {
        m_flexContainer.columnGap = columnGap;
        changed = true;
    }
    if (changed)
        updateLayout();
}

void UIWidget::setFlexOrder(int order)
{
    if (m_flexItem.order == order)
        return;
    m_flexItem.order = order;
    updateParentLayout();
}

void UIWidget::setFlexGrow(float grow)
{
    grow = std::max(0.f, grow);
    if (std::abs(m_flexItem.flexGrow - grow) < 1e-6f)
        return;
    m_flexItem.flexGrow = grow;
    updateParentLayout();
}

void UIWidget::setFlexShrink(float shrink)
{
    shrink = std::max(0.f, shrink);
    if (std::abs(m_flexItem.flexShrink - shrink) < 1e-6f)
        return;
    m_flexItem.flexShrink = shrink;
    updateParentLayout();
}

void UIWidget::setFlexBasis(const FlexBasis& basis)
{
    if (m_flexItem.basis.type == basis.type && std::abs(m_flexItem.basis.value - basis.value) < 1e-6f)
        return;
    m_flexItem.basis = basis;
    updateParentLayout();
}

void UIWidget::setAlignSelf(AlignSelf align)
{
    if (m_flexItem.alignSelf == align)
        return;
    m_flexItem.alignSelf = align;
    updateParentLayout();
}

void UIWidget::setPlacement(const std::string& placement) {
    m_placement = Fw::translatePlacement(placement);
    scheduleHtmlTask(PropApplyAnchorAlignment);
}

std::string UIWidget::getTextByPos(const Point& mousePos)
{
    for (const auto& pair : m_rectToWord) {
        if (pair.first.contains(mousePos))
            return pair.second;
    }

    return "";
}

void UIWidget::setEventListener(WidgetEvents event)
{
    if (hasEventListener(event))
        return;

    m_events |= event;

    if ((event == EVENT_TEXT_CLICK || event == EVENT_TEXT_HOVER) && m_rectToWord.empty())
        cacheRectToWord();
}

void UIWidget::removeEventListener(WidgetEvents event)
{
    if (!hasEventListener(event))
        return;

    m_events &= ~event;

    if (event == EVENT_TEXT_CLICK || event == EVENT_TEXT_HOVER) {
        m_rectToWord.clear();
        m_rectToWord.shrink_to_fit();
        m_textUnderline = std::make_shared<CoordsBuffer>();
    }
}

void UIWidget::cacheRectToWord()
{
    if (m_rect.isEmpty())
        return;

    const auto& text = m_drawText;
    const int textLength = text.length();

    // map glyphs positions
    Size textBoxSize;
    m_font->calculateGlyphsPositions(text, m_textAlign, m_glyphsPositionsCache, &textBoxSize);
    if (m_glyphsCoordsCache.size() != static_cast<size_t>(textLength))
        m_glyphsCoordsCache.resize(textLength);

    auto& glyphsCoords = m_glyphsCoordsCache;
    const auto& glyphsPositions = m_glyphsPositionsCache;
    const Rect* glyphsTextureCoords = m_font->getGlyphsTextureCoords();
    const Size* glyphsSize = m_font->getGlyphsSize();
    int glyph;

    // update rect size
    if (!m_rect.isValid() || hasProp(PropTextHorizontalAutoResize) || hasProp(PropTextVerticalAutoResize)) {
        textBoxSize += Size(m_padding.left + m_padding.right, m_padding.top + m_padding.bottom) + m_textOffset.toSize();
        Size size = getSize();
        if (size.width() <= 0 || (hasProp(PropTextHorizontalAutoResize) && !hasProp(PropTextWrap)))
            size.setWidth(textBoxSize.width());
        if (size.height() <= 0 || hasProp(PropTextVerticalAutoResize))
            size.setHeight(textBoxSize.height());
        setSize(size);
    }

    Rect textScreenCoords = m_rect;
    textScreenCoords.expandLeft(-m_padding.left);
    textScreenCoords.expandRight(-m_padding.right);
    textScreenCoords.expandBottom(-m_padding.bottom);
    textScreenCoords.expandTop(-m_padding.top);

    for (int i = 0; i < textLength; ++i) {
        glyph = (uchar)text[i];
        glyphsCoords[i].clear();

        // skip invalid glyphs
        if (glyph < 32)
            continue;

        // calculate initial glyph rect and texture coords
        Rect glyphScreenCoords(glyphsPositions[i], glyphsSize[glyph]);
        Rect glyphTextureCoords = glyphsTextureCoords[glyph];

        // first translate to align position
        if (m_textAlign & Fw::AlignBottom) {
            glyphScreenCoords.translate(0, textScreenCoords.height() - textBoxSize.height());
        } else if (m_textAlign & Fw::AlignVerticalCenter) {
            glyphScreenCoords.translate(0, (textScreenCoords.height() - textBoxSize.height()) / 2);
        } else { // AlignTop
            // nothing to do
        }

        if (m_textAlign & Fw::AlignRight) {
            glyphScreenCoords.translate(textScreenCoords.width() - textBoxSize.width(), 0);
        } else if (m_textAlign & Fw::AlignHorizontalCenter) {
            glyphScreenCoords.translate((textScreenCoords.width() - textBoxSize.width()) / 2, 0);
        } else { // AlignLeft
            // nothing to do
        }

        // translate rect to screen coords
        glyphScreenCoords.translate(textScreenCoords.topLeft());

        // only render if glyph rect is visible on screenCoords
        if (!textScreenCoords.intersects(glyphScreenCoords))
            continue;

        // bound glyph bottomRight to screenCoords bottomRight
        if (glyphScreenCoords.bottom() > textScreenCoords.bottom()) {
            glyphTextureCoords.setBottom(glyphTextureCoords.bottom() + (textScreenCoords.bottom() - glyphScreenCoords.bottom()));
            glyphScreenCoords.setBottom(textScreenCoords.bottom());
        }
        if (glyphScreenCoords.right() > textScreenCoords.right()) {
            glyphTextureCoords.setRight(glyphTextureCoords.right() + (textScreenCoords.right() - glyphScreenCoords.right()));
            glyphScreenCoords.setRight(textScreenCoords.right());
        }

        // render glyph
        glyphsCoords[i] = glyphScreenCoords;
    }

    updateRectToWord(glyphsCoords);
}

void UIWidget::setColor(const Color& color)
{
    if (m_color == color)
        return;

    if (!m_textColors.empty()) {
        for (auto& pair : m_textColors) {
            if (pair.second == m_baseTextColor)
                pair.second = color;
        }
        for (auto& pair : m_drawTextColors) {
            if (pair.second == m_baseTextColor)
                pair.second = color;
        }
        m_baseTextColor = color;
        m_colorCoordsBuffer.clear();
        m_coordsBuffer->clear();
        m_textCachedScreenCoords = {};
    }

    m_color = color;
    repaint();
}