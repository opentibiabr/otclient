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
#include "uimanager.h"
#include <framework/graphics/drawpoolmanager.h>

#include "uiwidget.h"
#include "framework/core/eventdispatcher.h"
#include "framework/core/modulemanager.h"
#include "framework/core/resourcemanager.h"
#include "framework/graphics/graphics.h"
#include "framework/otml/otmldocument.h"
#include "framework/otml/otmlexception.h"
#include "framework/otml/otmlnode.h"
#include <framework/platform/platformwindow.h>
#include <framework/util/stats.h>

UIManager g_ui;

void UIManager::init()
{
    // creates root widget
    m_rootWidget = std::make_shared<UIWidget>();
    m_rootWidget->m_positionType = PositionType::Relative;
    m_rootWidget->setId("root");
    m_mouseReceiver = m_rootWidget;
    m_keyboardReceiver = m_rootWidget;
}

void UIManager::terminate()
{
    // destroy root widget and its children
    m_rootWidget->destroy();
    m_mouseReceiver = nullptr;
    m_keyboardReceiver = nullptr;
    m_rootWidget = nullptr;
    m_draggingWidget = nullptr;
    m_hoveredWidget = nullptr;
    m_pressedWidget = nullptr;
    m_styles.clear();
    m_destroyedWidgets.clear();
    m_checkEvent = nullptr;
    m_hoveredWidgets.clear();
    m_pressedWidgets.clear();
    m_hoveredText.clear();
}

void UIManager::render(DrawPoolType drawPane) const
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    g_drawPool.preDraw(drawPane, [this, drawPane] {
        m_rootWidget->draw(m_rootWidget->getRect(), drawPane);
    }, { 0,0, g_graphics.getViewportSize() }, {});
}

void UIManager::resize(const Size& size) const { m_rootWidget->setSize(size); }

void UIManager::inputEvent(const InputEvent& event)
{
    UIWidgetList widgetList;
    switch (event.type) {
        case Fw::KeyTextInputEvent:
            m_keyboardReceiver->propagateOnKeyText(event.keyText);
            break;
        case Fw::KeyDownInputEvent:
            m_keyboardReceiver->propagateOnKeyDown(event.keyCode, event.keyboardModifiers);
            break;
        case Fw::KeyPressInputEvent:
            m_keyboardReceiver->propagateOnKeyPress(event.keyCode, event.keyboardModifiers, event.autoRepeatTicks);
            break;
        case Fw::KeyUpInputEvent:
            m_keyboardReceiver->propagateOnKeyUp(event.keyCode, event.keyboardModifiers);
            break;
        case Fw::MousePressInputEvent:
            m_mouseReceiver->propagateOnMouseEvent(event.mousePos, widgetList);

            if (event.mouseButton == Fw::MouseLeftButton && m_mouseReceiver->isVisible()) {
                auto pressedWidget = m_mouseReceiver->recursiveGetChildByPos(event.mousePos, false);

                bool isOnHTML = false;
                if (pressedWidget) {
                    isOnHTML = pressedWidget->isOnHtml();

                    if (!pressedWidget->isEnabled())
                        pressedWidget = nullptr;
                }

                if (isOnHTML)
                    updatePressedWidgetHTML(pressedWidget ? widgetList : UIWidgetList{}, event.mousePos);
                else
                    updatePressedWidget(pressedWidget, event.mousePos);
            }

            for (const auto& widget : widgetList) {
                widget->recursiveFocus(Fw::MouseFocusReason);
                if (widget->onMousePress(event.mousePos, event.mouseButton))
                    break;
            }

            break;
        case Fw::MouseReleaseInputEvent:
        {
            // release dragging widget
            bool accepted = false;
            if (m_draggingWidget && event.mouseButton == Fw::MouseLeftButton)
                accepted = updateDraggingWidget(nullptr, event.mousePos);

            if (!accepted) {
                m_mouseReceiver->propagateOnMouseEvent(event.mousePos, widgetList);

                // mouse release is always fired first on the pressed widget
                if (m_pressedWidget) {
                    const auto it = std::ranges::find(widgetList, m_pressedWidget);
                    if (it != widgetList.end())
                        widgetList.erase(it);
                    widgetList.emplace_front(m_pressedWidget);
                }

                for (const auto& widget : widgetList) {
                    if (widget->onMouseRelease(event.mousePos, event.mouseButton))
                        break;
                }
            }

            if (m_pressedWidget && event.mouseButton == Fw::MouseLeftButton) {
                if (m_pressedWidget->isOnHtml())
                    updatePressedWidgetHTML(UIWidgetList{}, event.mousePos, !accepted);
                else
                    updatePressedWidget(nullptr, event.mousePos, !accepted);
            }
            break;
        }
        case Fw::MouseMoveInputEvent:
        {
            // start dragging when moving a pressed widget
            if (m_pressedWidget && m_pressedWidget->isDraggable() && m_draggingWidget != m_pressedWidget) {
                // only drags when moving more than 4 pixels
                if ((event.mousePos - m_pressedWidget->getLastClickPosition()).length() >= 4)
                    updateDraggingWidget(m_pressedWidget, event.mousePos - event.mouseMoved);
            }

            // mouse move can change hovered widgets
            updateHoveredWidget(true);
            updateHoveredText(true);

            // first fire dragging move
            if (m_draggingWidget) {
                if (m_draggingWidget->onDragMove(event.mousePos, event.mouseMoved))
                    break;
            }

            if (m_pressedWidget) {
                if (m_pressedWidget->onMouseMove(event.mousePos, event.mouseMoved)) {
                    break;
                }
            }

            m_mouseReceiver->propagateOnMouseMove(event.mousePos, event.mouseMoved, widgetList);
            for (const auto& widget : widgetList) {
                if (widget->onMouseMove(event.mousePos, event.mouseMoved))
                    break;
            }
            break;
        }
        case Fw::MouseWheelInputEvent:
            m_rootWidget->propagateOnMouseEvent(event.mousePos, widgetList);
            for (const auto& widget : widgetList) {
                if (widget->onMouseWheel(event.mousePos, event.wheelDirection))
                    break;
            }
            break;
        default:
            break;
    }
}

void  UIManager::updatePressedWidgetHTML(const UIWidgetList& newPressed, const Point& clickedPos, bool fireClicks) {
    auto oldPressedWidgets = std::move(m_pressedWidgets);
    m_pressedWidgets = newPressed;
    m_pressedWidget = !newPressed.empty() ? newPressed.front() : nullptr;

    for (const auto& p : newPressed) {
        const auto w = p.get();
        if (!w->isEnabled())
            continue;

        w->updateState(Fw::PressedState, true);
    }

    for (const auto& p : std::views::reverse(oldPressedWidgets)) {
        const auto w = p.get();

        if (fireClicks && w->isEnabled() && w->containsPoint(clickedPos))
            w->onClick(clickedPos);

        w->updateState(Fw::PressedState, false);
    }
}

void UIManager::updatePressedWidget(const UIWidgetPtr& newPressedWidget, const Point& clickedPos, const bool fireClicks)
{
    const UIWidgetPtr oldPressedWidget = m_pressedWidget;
    m_pressedWidget = newPressedWidget;

    // when releasing mouse inside pressed widget area send onClick event
    if (fireClicks && oldPressedWidget && oldPressedWidget->isEnabled() && oldPressedWidget->containsPoint(clickedPos))
        oldPressedWidget->onClick(clickedPos);

    if (newPressedWidget)
        newPressedWidget->updateState(Fw::PressedState);

    if (oldPressedWidget)
        oldPressedWidget->updateState(Fw::PressedState);
}

bool UIManager::updateDraggingWidget(const UIWidgetPtr& draggingWidget, const Point& clickedPos)
{
    bool accepted = false;

    const auto oldDraggingWidget = m_draggingWidget;
    m_draggingWidget = nullptr;

    if (oldDraggingWidget) {
        UIWidgetPtr droppedWidget;
        if (!clickedPos.isNull()) {
            const auto clickedChildren = m_rootWidget->recursiveGetChildrenByPos(clickedPos);
            for (const auto& child : clickedChildren) {
                if (child->onDrop(oldDraggingWidget, clickedPos)) {
                    droppedWidget = child;
                    break;
                }
            }
        }

        accepted = oldDraggingWidget->onDragLeave(droppedWidget, clickedPos);
        oldDraggingWidget->updateState(Fw::DraggingState);
    }

    if (draggingWidget) {
        if (draggingWidget->onDragEnter(clickedPos)) {
            m_draggingWidget = draggingWidget;
            draggingWidget->updateState(Fw::DraggingState);
            accepted = true;
        }
    }

    return accepted;
}

void UIManager::updateHoveredWidget(const bool now)
{
    if (m_hoverUpdateScheduled && !now)
        return;

    auto func = [this] {
        if (!m_rootWidget)
            return;

        m_hoverUpdateScheduled = false;

        const auto& mousePos = g_window.getMousePosition();
        auto hoveredWidget = m_rootWidget->recursiveGetChildByPos(mousePos, false);

        if (hoveredWidget && hoveredWidget->isOnHtml()) {
            UIWidgetList newHovered;
            m_mouseReceiver->propagateOnMouseEvent(mousePos, newHovered);

            for (const auto& p : std::views::reverse(m_hoveredWidgets)) {
                const auto w = p.get();

                bool still = std::any_of(newHovered.begin(), newHovered.end(),
                                         [&](const UIWidgetPtr& p) { return p.get() == w; });
                if (!still) {
                    w->updateState(Fw::HoverState, false);
                    w->onHoverChange(false);
                }
            }

            for (const auto& p : newHovered) {
                const auto w = p.get();
                if (!w->isEnabled())
                    continue;

                bool was = std::any_of(m_hoveredWidgets.begin(), m_hoveredWidgets.end(),
                                       [&](const UIWidgetPtr& q) { return q.get() == w; });
                if (!was) {
                    w->updateState(Fw::HoverState, true);
                    w->onHoverChange(true);
                }
            }

            m_hoveredWidgets = std::move(newHovered);
        }

        if (hoveredWidget && !hoveredWidget->isEnabled())
            hoveredWidget = nullptr;

        if (hoveredWidget != m_hoveredWidget) {
            const UIWidgetPtr oldHovered = m_hoveredWidget;
            m_hoveredWidget = hoveredWidget;
            if (oldHovered) {
                oldHovered->updateState(Fw::HoverState);
                oldHovered->onHoverChange(false);
                if (oldHovered->hasEventListener(EVENT_TEXT_HOVER) && m_hoveredText.length() > 0) {
                    oldHovered->onTextHoverChange(m_hoveredText, false);
                    m_hoveredText.clear();
                }
            }
            if (hoveredWidget) {
                hoveredWidget->updateState(Fw::HoverState);
                hoveredWidget->onHoverChange(true);
            }
        }
    };

    if (now)
        func();
    else {
        m_hoverUpdateScheduled = true;
        g_dispatcher.deferEvent(func);
    }
}

void UIManager::onWidgetAppear(const UIWidgetPtr& widget)
{
    if (widget->containsPoint(g_window.getMousePosition())) {
        updateHoveredWidget();
        updateHoveredText();
    }
}

void UIManager::onWidgetDisappear(const UIWidgetPtr& widget)
{
    if (widget->containsPoint(g_window.getMousePosition())) {
        updateHoveredWidget();
        updateHoveredText();
    }
}

void UIManager::onWidgetDestroy(const UIWidgetPtr& widget)
{
    std::string extra = widget->getId();
    if (widget->getParent())
        extra += " (" + widget->getParent()->getId() + ")";
    AutoStat s(STATS_MAIN, "UIManager::onWidgetDestroy", extra);

    // release input grabs
    if (m_keyboardReceiver == widget)
        resetKeyboardReceiver();

    if (m_mouseReceiver == widget)
        resetMouseReceiver();

    if (m_hoveredWidget == widget) {
        updateHoveredWidget();
        updateHoveredText();
    }

    if (m_pressedWidget == widget) {
        updatePressedWidget(nullptr);
    }

    if (m_draggingWidget == widget)
        updateDraggingWidget(nullptr);

    if (widget->isOnHtml()) {
        { // Pressed Widgets
            auto it = std::find(m_pressedWidgets.begin(), m_pressedWidgets.end(), widget);
            if (it != m_pressedWidgets.end()) {
                m_pressedWidgets.erase(it);
            }
        }
        {  // Hovered Widgets
            auto it = std::find(m_hoveredWidgets.begin(), m_hoveredWidgets.end(), widget);
            if (it != m_hoveredWidgets.end()) {
                m_hoveredWidgets.erase(it);
            }
        }
    }

    // Avoid the garbage collector
    if (!g_modules.isAutoReloadEnabled())
        return;

    if (widget == m_rootWidget || !m_rootWidget)
        return;

    m_destroyedWidgets.emplace_back(widget);

    if (m_checkEvent && !m_checkEvent->isExecuted())
        return;

    m_checkEvent = g_dispatcher.scheduleEvent([this] {
        g_lua.collectGarbage();
        UIWidgetList backupList = m_destroyedWidgets;
        m_destroyedWidgets.clear();
        g_dispatcher.scheduleEvent([backupList] {
            g_lua.collectGarbage();
            for (const auto& widget : backupList) {
                if (widget.use_count() != 1)
                    g_logger.warning("widget '{}' destroyed but still have {} reference(s) left", widget->getId(), widget.use_count() - 1);
            }
        }, 1);
    }, 1000);
}

void UIManager::clearStyles()
{
    m_styles.clear();
}

bool UIManager::importStyle(const std::string& fl, const bool checkDeviceStyles)
{
    const std::string file{ g_resources.guessFilePath(fl, "otui") };
    try {
        const auto& doc = OTMLDocument::parse(file);

        for (const auto& styleNode : doc->children()) {
            const std::string tag = styleNode->tag();
            if (!tag.empty() && tag.front() == '&')
                continue;
            if (tag.find('<') == std::string::npos)
                continue;
            importStyleFromOTML(styleNode);
        }
    } catch (stdext::exception& e) {
        g_logger.error("Failed to import UI styles from '{}': {}", file, e.what());
        return false;
    }

    if (checkDeviceStyles) {
        // check for device styles
        const auto fileName = fl.substr(0, fl.find("."));

        const auto deviceName = g_platform.getDeviceShortName();
        if (!deviceName.empty())
            importStyle(deviceName + "." + fileName, false);

        const auto osName = g_platform.getOsShortName();
        if (!osName.empty())
            importStyle(osName + "." + fileName, false);
    }

    return true;
}

void UIManager::importStyleFromOTML(const OTMLNodePtr& styleNode)
{
    const std::string tag = styleNode->tag();
    const std::vector<std::string> split = stdext::split(tag, "<");
    if (split.size() != 2)
        throw OTMLException(styleNode, "not a valid style declaration");

    std::string name = split[0];
    std::string base = split[1];
    bool unique = false;

    stdext::trim(name);
    stdext::trim(base);

    if (name[0] == '#') {
        name = name.substr(1);
        unique = true;

        styleNode->setTag(name);
        styleNode->writeAt("__unique", true);
    }

    const auto oldStyle = m_styles[name];

    // Warn about redefined styles
    /*
    if(!g_app.isRunning() && (oldStyle && !oldStyle->valueAt("__unique", false))) {
        auto it = m_styles.find(name);
        if(it != m_styles.end())
            g_logger.warning("style '{}' is being redefined", name);
    }
    */

    if (!oldStyle || !oldStyle->valueAt("__unique", false) || unique) {
        const auto& originalStyle = getStyle(base);
        if (!originalStyle)
            throw Exception("base style '{}', is not defined", base);

        const auto& style = originalStyle->clone();
        style->merge(styleNode);
        style->setTag(name);
        m_styles[name] = style;

        // lowercase cache
        stdext::tolower(name);
        m_styles[name] = style;
    }
}

void UIManager::importStyleFromOTML(const OTMLDocumentPtr& doc)
{
    for (const auto& node : doc->children()) {
        std::string tag = node->tag();

        // import styles in these files too
        if (tag.find('<') != std::string::npos)
            importStyleFromOTML(node);
    }
}

OTMLNodePtr UIManager::getStyle(const std::string_view sn)
{
    auto styleName = std::string(sn);
    const auto it = m_styles.find(styleName);
    if (it != m_styles.end())
        return m_styles[styleName];

    // styles starting with UI are automatically defined
    if (sn.starts_with("UI")) {
        const auto& node = OTMLNode::create(styleName);
        node->writeAt("__class", styleName);
        m_styles[styleName] = node;

        // lowercase cache
        stdext::tolower(styleName);
        m_styles[styleName] = node;

        return node;
    }

    return nullptr;
}

std::string UIManager::getStyleName(const std::string_view styleName)
{
    if (const auto& style = getStyle(styleName))
        return style->tag();
    return "";
}

std::string UIManager::getStyleClass(const std::string_view styleName)
{
    if (const auto& style = getStyle(styleName)) {
        if (style->get("__class"))
            return style->valueAt("__class");
    }
    return "";
}

OTMLNodePtr UIManager::findMainWidgetNode(const OTMLDocumentPtr& doc)
{
    OTMLNodePtr mainNode = nullptr;
    for (const auto& node : doc->children()) {
        std::string tag = node->tag();

        if (!tag.empty() && tag.front() == '&')
            continue;

        if (tag.find('<') == std::string::npos) {
            if (mainNode)
                throw Exception("cannot have multiple main widgets in otui files");
            mainNode = node;
        }
    }
    return mainNode;
}

OTMLNodePtr UIManager::loadDeviceUI(const std::string& file, const OperatingSystem os)
{
    const auto rawName = file.substr(0, file.find("."));
    const auto osName = g_platform.getOsShortName(os);

    const auto& doc = OTMLDocument::parse(g_resources.guessFilePath(rawName + "." + osName, "otui"));
    if (doc) {
        g_logger.info("found os style '{}' for '{}'", osName, rawName);
        importStyleFromOTML(doc);
        return findMainWidgetNode(doc);
    }
    return nullptr;
}

OTMLNodePtr UIManager::loadDeviceUI(const std::string& file, const DeviceType deviceType)
{
    const auto rawName = file.substr(0, file.find("."));
    const auto deviceName = g_platform.getDeviceShortName(deviceType);

    const auto& doc = OTMLDocument::parse(g_resources.guessFilePath(rawName + "." + deviceName, "otui"));
    if (doc) {
        g_logger.info("found device style '{}' for '{}'", deviceName, rawName);
        importStyleFromOTML(doc);
        return findMainWidgetNode(doc);
    }
    return nullptr;
}

UIWidgetPtr UIManager::loadUI(const std::string& file, const UIWidgetPtr& parent)
{
    try {
        OTMLNodePtr widgetNode = nullptr;
        const auto& doc = OTMLDocument::parse(g_resources.guessFilePath(file, "otui"));

        for (const auto& node : doc->children()) {
            std::string tag = node->tag();

            if (!tag.empty() && tag.front() == '&')
                continue;

            // import styles in these files too
            if (tag.find('<') != std::string::npos)
                importStyleFromOTML(node);
            else {
                if (widgetNode)
                    throw Exception("cannot have multiple main widgets in otui files");
                widgetNode = node;
            }
        }

        // load device styles and widget
        const auto device = g_platform.getDevice();
        try {
            const auto& deviceWidgetNode = loadDeviceUI(file, device.type);
            if (deviceWidgetNode)
                widgetNode = deviceWidgetNode;
        } catch (stdext::exception& e) {
            g_logger.fine("no device ui found for '{}', reason: '{}'", file, e.what());
        }
        try {
            const auto osWidgetNode = loadDeviceUI(file, device.os);
            if (osWidgetNode)
                widgetNode = osWidgetNode;
        } catch (stdext::exception& e) {
            g_logger.fine("no os ui found for '{}', reason: '{}'", file, e.what());
        }

        if (!widgetNode) {
            g_logger.debug("failed to load a widget from '{}'", file);
            return nullptr;
        }

        return createWidgetFromOTML(widgetNode, parent);
    } catch (stdext::exception& e) {
        g_logger.error("failed to load UI from '{}': {}", file, e.what());
        return nullptr;
    }
}

UIWidgetPtr UIManager::loadUIFromString(const std::string& data, const UIWidgetPtr& parent)
{
    try {
        std::stringstream sstream;
        sstream.clear(std::ios::goodbit);
        sstream.write(&data[0], data.length());
        sstream.seekg(0, std::ios::beg);
        const OTMLDocumentPtr doc = OTMLDocument::parse(sstream, "(string)");
        UIWidgetPtr widget;
        for (const OTMLNodePtr& node : doc->children()) {
            std::string tag = node->tag();

            if (!tag.empty() && tag.front() == '&')
                continue;

            // import styles in these files too
            if (tag.find('<') != std::string::npos)
                importStyleFromOTML(node);
            else {
                if (widget)
                    throw Exception("cannot have multiple main widgets in otui files");
                widget = createWidgetFromOTML(node, parent);
            }
        }

        return widget;
    } catch (stdext::exception& e) {
        g_logger.error("failed to load UI from string: {}", e.what());
        return nullptr;
    }
}

UIWidgetPtr UIManager::createWidget(const std::string_view styleName, const UIWidgetPtr& parent)
{
    const auto& node = OTMLNode::create(styleName);
    try {
        return createWidgetFromOTML(node, parent);
    } catch (stdext::exception& e) {
        g_logger.error("failed to create widget from style '{}': {}", styleName, e.what());
        return nullptr;
    }
}

UIWidgetPtr UIManager::createWidgetFromOTML(const OTMLNodePtr& widgetNode, const UIWidgetPtr& parent)
{
    const auto& originalStyleNode = getStyle(widgetNode->tag());
    if (!originalStyleNode)
        throw Exception("'{}' is not a defined style", widgetNode->tag());

    const auto& styleNode = originalStyleNode->clone();
    styleNode->merge(widgetNode);

    const std::string widgetType = styleNode->valueAt("__class");

    // call widget creation from lua
    const auto& widget = g_lua.callGlobalField<UIWidgetPtr>(widgetType, "create");
    if (!widget)
        throw Exception("unable to create widget of type '{}'", widgetType);

    if (parent) {
        if (parent->m_insertChildIndex > -1) {
            parent->insertChild(parent->m_insertChildIndex, widget);
            parent->m_insertChildIndex = -1;
        } else
            parent->addChild(widget);
    }

    widget->callLuaField("onCreate");

    widget->setStyleFromNode(styleNode);

    for (const auto& childNode : styleNode->children()) {
        if (!childNode->isUnique()) {
            createWidgetFromOTML(childNode, widget);
            styleNode->removeChild(childNode);
        }
    }

    widget->callLuaField("onSetup");
    return widget;
}

void UIManager::updateHoveredText(bool now)
{
    if (m_hoverTextUpdateScheduled && !now || !m_hoveredWidget)
        return;

    auto func = [this] {
        if (!m_rootWidget || !m_hoveredWidget)
            return;

        m_hoverTextUpdateScheduled = false;

        if (m_hoveredWidget->hasEventListener(EVENT_TEXT_HOVER)) {
            std::string hoveredText = m_hoveredWidget->getTextByPos(g_window.getMousePosition());

            if (hoveredText != m_hoveredText) {
                std::string oldHovered = m_hoveredText;
                m_hoveredText = hoveredText;

                if (oldHovered.length() > 0)
                    m_hoveredWidget->onTextHoverChange(oldHovered, false);

                if (m_hoveredText.length() > 0)
                    m_hoveredWidget->onTextHoverChange(m_hoveredText, true);
            }
        }
    };

    if (now)
        func();
    else {
        m_hoverTextUpdateScheduled = true;
        g_dispatcher.deferEvent(func);
    }
}
