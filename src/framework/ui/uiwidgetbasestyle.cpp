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
#include <framework/graphics/drawpoolmanager.h>

#include "uianchorlayout.h"
#include "uigridlayout.h"
#include "uihorizontallayout.h"
#include "uilayout.h"
#include "uitranslator.h"
#include "uiverticallayout.h"
#include "uiwidget.h"
#include "framework/core/eventdispatcher.h"
#include "framework/graphics/texturemanager.h"
#include "framework/html/htmlmanager.h"
#include "framework/html/htmlnode.h"
#include "framework/otml/otmlnode.h"

namespace {
    inline std::string toLower(std::string value)
    {
        stdext::tolower(value);
        return value;
    }

    inline bool iequals(std::string_view a, std::string_view b)
    {
        if (a.size() != b.size())
            return false;
        for (size_t i = 0; i < a.size(); ++i) {
            if (std::tolower(static_cast<unsigned char>(a[i])) != std::tolower(static_cast<unsigned char>(b[i])))
                return false;
        }
        return true;
    }

    inline bool isAutoKeyword(std::string value)
    {
        stdext::trim(value);
        stdext::tolower(value);
        return value == "auto";
    }

    inline bool parseFloat(const std::string& token, float& out)
    {
        char* end = nullptr;
        out = std::strtof(token.c_str(), &end);
        return end != token.c_str() && *end == '\0';
    }

    inline bool parseInt(const std::string& token, int& out)
    {
        char* end = nullptr;
        long v = std::strtol(token.c_str(), &end, 10);
        if (end == token.c_str() || *end != '\0')
            return false;
        out = static_cast<int>(v);
        return true;
    }

    int parseGapLength(const std::string& value)
    {
        auto trimmed = value;
        stdext::trim(trimmed);
        if (trimmed.empty())
            return 0;
        if (iequals(trimmed, "normal"))
            return 0;
        if (trimmed.size() > 2 && trimmed.ends_with("px"))
            return stdext::to_number(trimmed.substr(0, trimmed.size() - 2));
        return stdext::to_number(trimmed);
    }

    FlexDirection parseFlexDirection(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "row-reverse") return FlexDirection::RowReverse;
        if (value == "column") return FlexDirection::Column;
        if (value == "column-reverse") return FlexDirection::ColumnReverse;
        return FlexDirection::Row;
    }

    FlexWrap parseFlexWrap(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "wrap") return FlexWrap::Wrap;
        if (value == "wrap-reverse") return FlexWrap::WrapReverse;
        return FlexWrap::NoWrap;
    }

    JustifyContent parseJustifyContent(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "flex-end" || value == "end" || value == "right") return JustifyContent::FlexEnd;
        if (value == "center") return JustifyContent::Center;
        if (value == "space-between") return JustifyContent::SpaceBetween;
        if (value == "space-around") return JustifyContent::SpaceAround;
        if (value == "space-evenly") return JustifyContent::SpaceEvenly;
        return JustifyContent::FlexStart;
    }

    AlignItems parseAlignItems(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "flex-start" || value == "start" || value == "top") return AlignItems::FlexStart;
        if (value == "flex-end" || value == "end" || value == "bottom") return AlignItems::FlexEnd;
        if (value == "center") return AlignItems::Center;
        if (value == "baseline") return AlignItems::Baseline;
        return AlignItems::Stretch;
    }

    AlignContent parseAlignContent(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "flex-start" || value == "start" || value == "top") return AlignContent::FlexStart;
        if (value == "flex-end" || value == "end" || value == "bottom") return AlignContent::FlexEnd;
        if (value == "center") return AlignContent::Center;
        if (value == "space-between") return AlignContent::SpaceBetween;
        if (value == "space-around") return AlignContent::SpaceAround;
        if (value == "space-evenly") return AlignContent::SpaceEvenly;
        return AlignContent::Stretch;
    }

    AlignSelf parseAlignSelf(std::string value)
    {
        value = toLower(std::move(value));
        if (value == "auto") return AlignSelf::Auto;
        if (value == "flex-start" || value == "start" || value == "top") return AlignSelf::FlexStart;
        if (value == "flex-end" || value == "end" || value == "bottom") return AlignSelf::FlexEnd;
        if (value == "center") return AlignSelf::Center;
        if (value == "baseline") return AlignSelf::Baseline;
        return AlignSelf::Stretch;
    }

    FlexBasis parseFlexBasis(std::string value)
    {
        stdext::trim(value);
        value = toLower(value);
        FlexBasis basis;
        if (value == "auto") {
            basis.type = FlexBasis::Type::Auto;
            basis.value = 0.f;
        } else if (value == "content") {
            basis.type = FlexBasis::Type::Content;
            basis.value = 0.f;
        } else if (value.ends_with("%")) {
            basis.type = FlexBasis::Type::Percent;
            float v = 0.f;
            parseFloat(value.substr(0, value.size() - 1), v);
            basis.value = v;
        } else if (value.ends_with("px")) {
            basis.type = FlexBasis::Type::Px;
            float v = 0.f;
            parseFloat(value.substr(0, value.size() - 2), v);
            basis.value = v;
        } else {
            float v = 0.f;
            if (parseFloat(value, v)) {
                basis.type = FlexBasis::Type::Px;
                basis.value = v;
            }
        }
        return basis;
    }

    void applyFlexShorthand(UIWidget* widget, const std::string& value)
    {
        auto tokens = stdext::split(value, " ");
        std::vector<std::string> filtered;
        filtered.reserve(tokens.size());
        for (auto& t : tokens) {
            stdext::trim(t);
            if (!t.empty())
                filtered.push_back(t);
        }

        if (filtered.empty())
            return;

        if (filtered.size() == 1) {
            auto lower = toLower(filtered[0]);
            if (lower == "auto") {
                widget->setFlexGrow(1.f);
                widget->setFlexShrink(1.f);
                widget->setFlexBasis({ FlexBasis::Type::Auto, 0.f });
                return;
            }
            if (lower == "none") {
                widget->setFlexGrow(0.f);
                widget->setFlexShrink(0.f);
                widget->setFlexBasis({ FlexBasis::Type::Auto, 0.f });
                return;
            }
        }

        float grow = widget->getFlexGrow();
        float shrink = widget->getFlexShrink();
        FlexBasis basis = widget->getFlexBasis();

        size_t idx = 0;
        if (idx < filtered.size() && parseFloat(filtered[idx], grow)) ++idx;
        if (idx < filtered.size() && parseFloat(filtered[idx], shrink)) ++idx;
        if (idx < filtered.size()) basis = parseFlexBasis(filtered[idx]);

        widget->setFlexGrow(grow);
        widget->setFlexShrink(shrink);
        widget->setFlexBasis(basis);
    }
} // namespace

void UIWidget::initBaseStyle()
{
    static std::atomic<uint32_t > UID(0);
    m_borderColor.set(Color::black);

    // generate an unique id, this is need because anchored layouts find widgets by id
    m_id = fmt::format("widget{}", ++UID);
}

void UIWidget::parseBaseStyle(const OTMLNodePtr& styleNode)
{
    // parse lua variables and callbacks first
    for (const auto& node : styleNode->children()) {
        // lua functions
        if (node->tag().starts_with("@")) {
            // load once
            if (hasProp(PropFirstOnStyle)) {
                std::string funcName = node->tag().substr(1);
                std::string funcOrigin = "@" + node->source() + ": [" + node->tag() + "]";
                g_lua.loadFunction(node->value(), funcOrigin);
                luaSetField(funcName);
            }
            // lua fields value
        } else if (node->tag().starts_with("&")) {
            std::string fieldName = node->tag().substr(1);
            std::string fieldOrigin = "@" + node->source() + ": [" + node->tag() + "]";

            std::string fieldValue = node->value();
            stdext::trim(fieldValue);

            if (!fieldValue.empty() && fieldValue.front() == '#') {
                g_lua.pushString(fieldValue);
            } else {
                g_lua.evaluateExpression(fieldValue, fieldOrigin);
            }

            luaSetField(fieldName);
        }
    }
    // load styles used by all widgets
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "inherit-text") {
            if (m_htmlNode && node->value<bool>()) {
                bool isExpression = false;

                if (!m_htmlNode->getChildren().empty()) {
                    bool isExpression = m_htmlNode->getChildren()[0]->isExpression();
                    if (isExpression)
                        if (const auto root = g_html.getRoot(m_htmlRootId))
                            callLuaField("__applyOrBindHtmlAttribute", std::string{ "*text" }, m_htmlNode->textContent(), false, root->moduleName, m_htmlNode->toString());
                }

                if (!isExpression)
                    setText(m_htmlNode->textContent());

                destroyChildren();
            }
        } else if (node->tag() == "background-draw-order")
            setBackgroundDrawOrder(node->value<int>());
        else if (node->tag() == "border-draw-order")
            setBorderDrawOrder(node->value<int>());
        else if (node->tag() == "icon-draw-order")
            setIconDrawOrder(node->value<int>());
        else if (node->tag() == "image-draw-order")
            setImageDrawOrder(node->value<int>());
        else if (node->tag() == "text-draw-order")
            setTextDrawOrder(node->value<int>());
        else if (node->tag() == "color")
            setColor(node->value<Color>());
        else if (node->tag() == "shader")
            setShader(node->value());
        else if (node->tag() == "x")
            setX(node->value<int>());
        else if (node->tag() == "y")
            setY(node->value<int>());
        else if (node->tag() == "pos")
            setPosition(node->value<Point>());
        else if (node->tag() == "width")
            setWidth(node->value<std::string>());
        else if (node->tag() == "height")
            setHeight(node->value<std::string>());
        else if (node->tag() == "min-width")
            setMinWidth(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "max-width")
            setMaxWidth(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "min-height")
            setMinHeight(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "max-height")
            setMaxHeight(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "rect")
            setRect(node->value<Rect>());
        else if (node->tag() == "background")
            setBackgroundColor(node->value<Color>());
        else if (node->tag() == "background-color")
            setBackgroundColor(node->value<Color>());
        else if (node->tag() == "background-offset-x")
            setBackgroundOffsetX(node->value<int>());
        else if (node->tag() == "background-offset-y")
            setBackgroundOffsetY(node->value<int>());
        else if (node->tag() == "background-offset")
            setBackgroundOffset(node->value<Point>());
        else if (node->tag() == "background-width")
            setBackgroundWidth(node->value<int>());
        else if (node->tag() == "background-height")
            setBackgroundHeight(node->value<int>());
        else if (node->tag() == "background-size")
            setBackgroundSize(node->value<Size>());
        else if (node->tag() == "background-rect")
            setBackgroundRect(node->value<Rect>());
        else if (node->tag() == "icon")
            setIcon(stdext::resolve_path(node->value(), node->source()));
        else if (node->tag() == "icon-source")
            setIcon(stdext::resolve_path(node->value(), node->source()));
        else if (node->tag() == "icon-color")
            setIconColor(node->value<Color>());
        else if (node->tag() == "icon-offset-x")
            setIconOffsetX(node->value<int>());
        else if (node->tag() == "icon-offset-y")
            setIconOffsetY(node->value<int>());
        else if (node->tag() == "icon-offset")
            setIconOffset(node->value<Point>());
        else if (node->tag() == "icon-width")
            setIconWidth(node->value<int>());
        else if (node->tag() == "icon-height")
            setIconHeight(node->value<int>());
        else if (node->tag() == "icon-size")
            setIconSize(node->value<Size>());
        else if (node->tag() == "icon-rect")
            setIconRect(node->value<Rect>());
        else if (node->tag() == "icon-clip")
            setIconClip(node->value<Rect>());
        else if (node->tag() == "icon-align")
            setIconAlign(Fw::translateAlignment(node->value()));
        else if (node->tag() == "opacity")
            setOpacity(node->value<float>());
        else if (node->tag() == "rotation")
            setRotation(node->value<float>());
        else if (node->tag() == "enabled")
            setEnabled(node->value<bool>());
        else if (node->tag() == "visible")
            setVisible(node->value<bool>());
        else if (node->tag() == "visibility")
            setVisible(node->value<std::string>() == "visible");
        else if (node->tag() == "checked")
            setChecked(node->value<bool>());
        else if (node->tag() == "draggable")
            setDraggable(node->value<bool>());
        else if (node->tag() == "on")
            setOn(node->value<bool>());
        else if (node->tag() == "focusable")
            setFocusable(node->value<bool>());
        else if (node->tag() == "auto-focus")
            setAutoFocusPolicy(Fw::translateAutoFocusPolicy(node->value()));
        else if (node->tag() == "phantom" || node->tag() == "pointer-events") {
            if (node->tag() == "pointer-events")
                setPhantom(node->value<std::string>() == "none");
            else
                setPhantom(node->value<bool>());
        } else if (node->tag() == "size") {
            // Skip the "size" attribute when the widget comes from HTML,
            // since dimensions are managed by CSS (width/height) in that context.
            if (isOnHtml()) return;
            setSize(node->value<Size>());
        } else if (node->tag() == "fixed-size")
            setFixedSize(node->value<bool>());
        else if (node->tag() == "min-size")
            setMinSize(node->value<Size>());
        else if (node->tag() == "max-size")
            setMaxSize(node->value<Size>());
        else if (node->tag() == "clipping")
            setClipping(node->value<bool>());
        else if (node->tag() == "border") {
            const auto& split = stdext::split(node->value(), " ");
            if (split.size() == 2) {
                setBorderWidth(stdext::to_number(stdext::safe_cast<std::string>(split[0])));
                setBorderColor(stdext::safe_cast<Color>(split[1]));
            } else
                throw OTMLException(node, "border param must have its width followed by its color");
        } else if (node->tag() == "border-width")
            setBorderWidth(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "border-width-top" || node->tag() == "border-top-width")
            setBorderWidthTop(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "border-width-right" || node->tag() == "border-right-width")
            setBorderWidthRight(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "border-width-bottom" || node->tag() == "border-bottom-width")
            setBorderWidthBottom(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "border-width-left" || node->tag() == "border-left-width")
            setBorderWidthLeft(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "border-color")
            setBorderColor(node->value<Color>());
        else if (node->tag() == "border-color-top")
            setBorderColorTop(node->value<Color>());
        else if (node->tag() == "border-color-right")
            setBorderColorRight(node->value<Color>());
        else if (node->tag() == "border-color-bottom")
            setBorderColorBottom(node->value<Color>());
        else if (node->tag() == "border-color-left")
            setBorderColorLeft(node->value<Color>());
        else if (node->tag() == "top" || node->tag() == "bottom" || node->tag() == "left" || node->tag() == "right") {
            auto v = node->value<std::string>();
            stdext::trim(v);
            stdext::tolower(v);
            setPositions(node->tag(), v);
        } else if (node->tag() == "display") {
            auto v = node->value<std::string>();
            stdext::tolower(v);
            DisplayType display = DisplayType::Initial;
            if (v == "none") display = DisplayType::None;
            else if (v == "block") display = DisplayType::Block;
            else if (v == "inline") display = DisplayType::Inline;
            else if (v == "inline-block") display = DisplayType::InlineBlock;
            else if (v == "flex") display = DisplayType::Flex;
            else if (v == "inline-flex") display = DisplayType::InlineFlex;
            else if (v == "grid") display = DisplayType::Grid;
            else if (v == "inline-grid") display = DisplayType::InlineGrid;
            else if (v == "table") display = DisplayType::Table;
            else if (v == "table-row-group") display = DisplayType::TableRowGroup;
            else if (v == "table-header-group") display = DisplayType::TableHeaderGroup;
            else if (v == "table-footer-group") display = DisplayType::TableFooterGroup;
            else if (v == "table-row") display = DisplayType::TableRow;
            else if (v == "table-cell") display = DisplayType::TableCell;
            else if (v == "table-column-group") display = DisplayType::TableColumnGroup;
            else if (v == "table-column") display = DisplayType::TableColumn;
            else if (v == "table-caption") display = DisplayType::TableCaption;
            else if (v == "list-item") display = DisplayType::ListItem;
            else if (v == "run-in") display = DisplayType::RunIn;
            else if (v == "contents") display = DisplayType::Contents;
            else if (v == "initial") display = DisplayType::Initial;
            else if (v == "inherit") display = DisplayType::Inherit;
            else throw OTMLException(node, fmt::format("Invalid display value '{}'", v));

            setDisplay(display);
        } else if (node->tag() == "flex-direction") {
            setFlexDirection(parseFlexDirection(node->value<std::string>()));
        } else if (node->tag() == "flex-wrap") {
            setFlexWrap(parseFlexWrap(node->value<std::string>()));
        } else if (node->tag() == "flex-flow") {
            auto flow = node->value<std::string>();
            for (auto part : stdext::split(flow, " ")) {
                stdext::trim(part);
                if (part.empty()) continue;
                auto lower = toLower(part);
                if (lower == "row" || lower == "row-reverse" || lower == "column" || lower == "column-reverse")
                    setFlexDirection(parseFlexDirection(lower));
                else if (lower == "wrap" || lower == "nowrap" || lower == "wrap-reverse")
                    setFlexWrap(parseFlexWrap(lower));
            }
        } else if (node->tag() == "justify-content") {
            setJustifyContent(parseJustifyContent(node->value<std::string>()));
        } else if (node->tag() == "align-items") {
            setAlignItems(parseAlignItems(node->value<std::string>()));
        } else if (node->tag() == "align-content") {
            setAlignContent(parseAlignContent(node->value<std::string>()));
        } else if (node->tag() == "gap") {
            const int gap = parseGapLength(node->value<std::string>());
            setGap(gap, gap);
        } else if (node->tag() == "row-gap") {
            setRowGap(parseGapLength(node->value<std::string>()));
        } else if (node->tag() == "column-gap") {
            setColumnGap(parseGapLength(node->value<std::string>()));
        } else if (node->tag() == "flex") {
            applyFlexShorthand(this, node->value<std::string>());
        } else if (node->tag() == "flex-grow") {
            float value = 0.f;
            auto text = node->value<std::string>();
            if (!parseFloat(text, value))
                value = node->value<float>();
            setFlexGrow(value);
        } else if (node->tag() == "flex-shrink") {
            float value = 0.f;
            auto text = node->value<std::string>();
            if (!parseFloat(text, value))
                value = node->value<float>();
            setFlexShrink(value);
        } else if (node->tag() == "flex-basis") {
            setFlexBasis(parseFlexBasis(node->value<std::string>()));
        } else if (node->tag() == "order") {
            int value = 0;
            auto text = node->value<std::string>();
            if (!parseInt(text, value))
                value = node->value<int>();
            setFlexOrder(value);
        } else if (node->tag() == "align-self") {
            setAlignSelf(parseAlignSelf(node->value<std::string>()));
        } else if (node->tag() == "overflow") {
            auto v = node->value<std::string>();
            stdext::tolower(v);
            OverflowType type = OverflowType::Visible;
            if (v == "hidden") type = OverflowType::Hidden;
            else if (v == "scroll") type = OverflowType::Scroll;
            else if (v == "auto") type = OverflowType::Auto;
            else if (v == "clip") type = OverflowType::Clip;
            setOverflow(type);
            setClipping(type == OverflowType::Clip || type == OverflowType::Scroll || type == OverflowType::Hidden);
        } else if (node->tag() == "position") {
            auto v = node->value<std::string>();
            stdext::tolower(v);

            PositionType type = PositionType::Static;
            if (v == "absolute") type = PositionType::Absolute;
            else if (v == "relative") type = PositionType::Relative;

            setPositionType(type);
        } else if (node->tag() == "float") {
            auto v = node->value<std::string>();
            stdext::tolower(v);
            FloatType type = FloatType::None;
            if (v == "left") type = FloatType::Left;
            else if (v == "right") type = FloatType::Right;
            else if (v == "inline-start") type = FloatType::InlineStart;
            else if (v == "inline-end") type = FloatType::InlineEnd;
            setFloat(type);
        } else if (node->tag() == "clear") {
            auto v = node->value<std::string>();
            ClearType clear = ClearType::None;
            if (v == "left") clear = ClearType::Left;
            else if (v == "right") clear = ClearType::Right;
            else if (v == "both") clear = ClearType::Both;
            else if (v == "inline-start") clear = ClearType::InlineStart;
            else if (v == "inline-end") clear = ClearType::InlineEnd;
        } else if (node->tag() == "justify-items") {
            auto v = node->value<std::string>();
            JustifyItemsType justify = JustifyItemsType::Normal;

            if (v == "center") justify = JustifyItemsType::Center;
            else if (v == "left" || v == "flex-start" || v == "start" || v == "inline-start")
                justify = JustifyItemsType::Left;
            else if (v == "right" || v == "flex-end" || v == "end" || v == "inline-end")
                justify = JustifyItemsType::Right;
            setJustifyItems(justify);
        } else if (node->tag() == "line-height") {
            setLineHeight(node->value<std::string>());
        } else if (node->tag() == "margin-top")
            setMarginTop(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "margin-right") {
            auto value = node->value<std::string>();
            if (isAutoKeyword(value)) {
                m_margin.right = 0;
                setMarginRightAuto(true);
            } else {
                setMarginRight(stdext::to_number(value));
            }
        } else if (node->tag() == "margin-bottom")
            setMarginBottom(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "margin-left") {
            auto value = node->value<std::string>();
            if (isAutoKeyword(value)) {
                m_margin.left = 0;
                setMarginLeftAuto(true);
            } else {
                setMarginLeft(stdext::to_number(value));
            }
        } else if (node->tag() == "margin") {
            std::string marginDesc = node->value();
            std::vector<std::string> parts = stdext::split(marginDesc, " ");
            std::vector<std::string> values;
            values.reserve(parts.size());
            for (auto part : parts) {
                stdext::trim(part);
                if (!part.empty())
                    values.push_back(part);
            }

            if (values.empty())
                continue;

            std::string topStr, rightStr, bottomStr, leftStr;
            if (values.size() == 1) {
                topStr = rightStr = bottomStr = leftStr = values[0];
            } else if (values.size() == 2) {
                topStr = bottomStr = values[0];
                rightStr = leftStr = values[1];
            } else if (values.size() == 3) {
                topStr = values[0];
                rightStr = leftStr = values[1];
                bottomStr = values[2];
            } else {
                topStr = values[0];
                rightStr = values[1];
                bottomStr = values[2];
                leftStr = values[3];
            }

            const bool rightAuto = isAutoKeyword(rightStr);
            const bool leftAuto = isAutoKeyword(leftStr);
            const int top = isAutoKeyword(topStr) ? 0 : stdext::to_number(topStr);
            const int bottom = isAutoKeyword(bottomStr) ? 0 : stdext::to_number(bottomStr);
            const int right = rightAuto ? 0 : stdext::to_number(rightStr);
            const int left = leftAuto ? 0 : stdext::to_number(leftStr);

            setMarginTop(top);
            setMarginBottom(bottom);

            if (rightAuto) {
                m_margin.right = right;
                setMarginRightAuto(true);
            } else {
                setMarginRight(right);
            }

            if (leftAuto) {
                m_margin.left = left;
                setMarginLeftAuto(true);
            } else {
                setMarginLeft(left);
            }
        } else if (node->tag() == "padding-top")
            setPaddingTop(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "padding-right")
            setPaddingRight(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "padding-bottom")
            setPaddingBottom(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "padding-left")
            setPaddingLeft(stdext::to_number(node->value<std::string>()));
        else if (node->tag() == "padding") {
            std::string paddingDesc = node->value();
            std::vector<std::string> split = stdext::split(paddingDesc, " ");
            if (split.size() == 4) {
                setPaddingTop(stdext::to_number(stdext::safe_cast<std::string>(split[0])));
                setPaddingRight(stdext::to_number(stdext::safe_cast<std::string>(split[1])));
                setPaddingBottom(stdext::to_number(stdext::safe_cast<std::string>(split[2])));
                setPaddingLeft(stdext::to_number(stdext::safe_cast<std::string>(split[3])));
            } else if (split.size() == 3) {
                int paddingTop = stdext::to_number(stdext::safe_cast<std::string>(split[0]));
                int paddingHorizontal = stdext::to_number(stdext::safe_cast<std::string>(split[1]));
                int paddingBottom = stdext::to_number(stdext::safe_cast<std::string>(split[2]));
                setPaddingTop(paddingTop);
                setPaddingRight(paddingHorizontal);
                setPaddingBottom(paddingBottom);
                setPaddingLeft(paddingHorizontal);
            } else if (split.size() == 2) {
                int paddingVertical = stdext::to_number(stdext::safe_cast<std::string>(split[0]));
                int paddingHorizontal = stdext::to_number(stdext::safe_cast<std::string>(split[1]));
                setPaddingTop(paddingVertical);
                setPaddingRight(paddingHorizontal);
                setPaddingBottom(paddingVertical);
                setPaddingLeft(paddingHorizontal);
            } else if (split.size() == 1) {
                int padding = stdext::to_number(stdext::safe_cast<std::string>(split[0]));
                setPaddingTop(padding);
                setPaddingRight(padding);
                setPaddingBottom(padding);
                setPaddingLeft(padding);
            }
        }
        // layouts
        else if (node->tag() == "layout") {
            std::string layoutType;
            if (node->hasValue())
                layoutType = node->value();
            else
                layoutType = node->valueAt<std::string>("type", "");

            if (!layoutType.empty()) {
                UILayoutPtr layout;
                if (layoutType == "horizontalBox")
                    layout = std::make_shared<UIHorizontalLayout>(static_self_cast<UIWidget>());
                else if (layoutType == "verticalBox")
                    layout = std::make_shared<UIVerticalLayout>(static_self_cast<UIWidget>());
                else if (layoutType == "grid")
                    layout = std::make_shared<UIGridLayout>(static_self_cast<UIWidget>());
                else if (layoutType == "anchor")
                    layout = std::make_shared<UIAnchorLayout>(static_self_cast<UIWidget>());
                else
                    throw OTMLException(node, "cannot determine layout type");
                setLayout(layout);
            }

            if (node->hasChildren())
                m_layout->applyStyle(node);
        }
        // anchors
        else if (node->tag().starts_with("anchors.")) {
            const auto& parent = getParent();
            if (!parent) {
                if (hasProp(PropFirstOnStyle))
                    throw OTMLException(node, "cannot create anchor, there is no parent widget!");
                continue;
            }

            const auto& layout = parent->getLayout();
            UIAnchorLayoutPtr anchorLayout;
            if (layout->isUIAnchorLayout())
                anchorLayout = layout->static_self_cast<UIAnchorLayout>();

            if (!anchorLayout)
                throw OTMLException(node, "cannot create anchor, the parent widget doesn't use anchor layout!");

            std::string what = node->tag().substr(8);
            if (what == "fill") {
                fill(node->value());
            } else if (what == "centerIn") {
                centerIn(node->value());
            } else {
                Fw::AnchorEdge anchoredEdge = Fw::translateAnchorEdge(what);

                if (node->value() == "none") {
                    removeAnchor(anchoredEdge);
                } else {
                    std::vector<std::string> split = stdext::split(node->value(), ".");
                    if (split.size() != 2)
                        throw OTMLException(node, "invalid anchor description");

                    std::string hookedWidgetId = split[0];
                    Fw::AnchorEdge hookedEdge = Fw::translateAnchorEdge(split[1]);

                    if (anchoredEdge == Fw::AnchorNone)
                        throw OTMLException(node, "invalid anchor edge");

                    if (hookedEdge == Fw::AnchorNone)
                        throw OTMLException(node, "invalid anchor target edge");

                    addAnchor(anchoredEdge, hookedWidgetId, hookedEdge);
                }
            }
        }
        else if (node->tag() == "events") {
            auto split = stdext::split(node->value(), " ");
            for (const auto& event : split) {
                auto it = eventMap.find(event);
                if (it != eventMap.end()) {
                    setEventListener(it->second);
                }
            }
        }
    }
}

void UIWidget::drawBackground(const Rect& screenCoords) const
{
    if (m_backgroundColor.aF() > 0.0f) {
        Rect drawRect = screenCoords;
        drawRect.translate(m_backgroundRect.topLeft());
        if (m_backgroundRect.isValid())
            drawRect.resize(m_backgroundRect.size());

        g_drawPool.setDrawOrder(m_backgroundDrawOrder);
        g_drawPool.addFilledRect(drawRect, m_backgroundColor);
        g_drawPool.resetDrawOrder();
    }
}

void UIWidget::drawBorder(const Rect& screenCoords) const
{
    g_drawPool.setDrawOrder(m_borderDrawOrder);

    // top
    if (m_borderWidth.top > 0) {
        const Rect borderRect(screenCoords.topLeft(), screenCoords.width(), m_borderWidth.top);
        g_drawPool.addFilledRect(borderRect, m_borderColor.top);
    }
    // right
    if (m_borderWidth.right > 0) {
        const Rect borderRect(screenCoords.topRight() - Point(m_borderWidth.right - 1, 0), m_borderWidth.right, screenCoords.height());
        g_drawPool.addFilledRect(borderRect, m_borderColor.right);
    }
    // bottom
    if (m_borderWidth.bottom > 0) {
        const Rect borderRect(screenCoords.bottomLeft() - Point(0, m_borderWidth.bottom - 1), screenCoords.width(), m_borderWidth.bottom);
        g_drawPool.addFilledRect(borderRect, m_borderColor.bottom);
    }
    // left
    if (m_borderWidth.left > 0) {
        const Rect borderRect(screenCoords.topLeft(), m_borderWidth.left, screenCoords.height());
        g_drawPool.addFilledRect(borderRect, m_borderColor.left);
    }
    g_drawPool.resetDrawOrder();
}

void UIWidget::drawIcon(const Rect& screenCoords) const
{
    if (!m_icon)
        return;

    Rect drawRect;
    if (m_iconRect.isValid()) {
        drawRect = screenCoords;
        drawRect.translate(m_iconRect.topLeft());
        drawRect.resize(m_iconRect.size());
    } else {
        drawRect.resize(m_iconClipRect.size());

        if (m_iconAlign == Fw::AlignNone)
            drawRect.moveCenter(screenCoords.center());
        else
            drawRect.alignIn(screenCoords, m_iconAlign);
    }
    drawRect.translate(m_iconOffset);
    g_drawPool.setDrawOrder(m_iconDrawOrder);
    g_drawPool.addTexturedRect(drawRect, m_icon, m_iconClipRect, m_iconColor);
    g_drawPool.resetDrawOrder();
}

void UIWidget::setIcon(const std::string& iconFile)
{
     const auto self = static_self_cast<UIWidget>();
    g_dispatcher.addEvent([self, iconFile = iconFile] {
        if (self->isDestroyed())
            return;

        self->m_icon = iconFile.empty() ? nullptr : g_textures.getTexture(iconFile);
        if (self->m_icon && !self->m_iconClipRect.isValid()) {
            self->m_iconClipRect = Rect(0, 0, self->m_icon->getSize());
        }

        self->repaint();
    });
}
