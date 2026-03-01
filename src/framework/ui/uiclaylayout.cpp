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

#ifdef FRAMEWORK_CLAY

#define CLAY_IMPLEMENTATION
#include "clay/clay.h"

#include "uiclaylayout.h"
#include "uiwidget.h"
#include <framework/otml/otmlnode.h>
#include <framework/graphics/fontmanager.h>
#include <framework/graphics/bitmapfont.h>

struct ClayData {
    Clay_Arena arena{};
    Clay_Context* context{ nullptr };
    void* memory{ nullptr };

    ~ClayData() {
        if (memory) {
            free(memory);
            memory = nullptr;
        }
    }
};

static Clay_Dimensions clayMeasureText(Clay_StringSlice text, Clay_TextElementConfig* config, void* /*userData*/)
{
    const auto& font = g_fonts.getDefaultWidgetFont();
    if (!font)
        return { 0.f, 0.f };

    const std::string_view textView(text.chars, text.length);
    const Size size = font->calculateTextRectSize(textView);
    return { static_cast<float>(size.width()), static_cast<float>(size.height()) };
}

static void clayErrorHandler(Clay_ErrorData errorData)
{
    g_logger.error(stdext::format("[Clay] Error %d: %.*s",
        static_cast<int>(errorData.errorType),
        errorData.errorText.length,
        errorData.errorText.chars));
}

UIClayLayout::UIClayLayout(UIWidgetPtr parentWidget)
    : UILayout(std::move(parentWidget)),
      m_clay(std::make_unique<ClayData>())
{
    Clay_SetMaxElementCount(256);
    const uint32_t memSize = Clay_MinMemorySize();
    m_clay->memory = malloc(memSize);
    m_clay->arena = Clay_CreateArenaWithCapacityAndMemory(memSize, m_clay->memory);
    m_clay->context = Clay_Initialize(
        m_clay->arena,
        Clay_Dimensions{ 0.f, 0.f },
        Clay_ErrorHandler{ clayErrorHandler, nullptr }
    );
}

UIClayLayout::~UIClayLayout() = default;

void UIClayLayout::applyStyle(const OTMLNodePtr& styleNode)
{
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "direction") {
            const auto& v = node->value<std::string>();
            if (v == "horizontal" || v == "left-to-right")
                setDirection(0);
            else if (v == "vertical" || v == "top-to-bottom")
                setDirection(1);
        } else if (node->tag() == "child-gap") {
            setChildGap(node->value<int>());
        } else if (node->tag() == "align-x") {
            const auto& v = node->value<std::string>();
            if (v == "left") setAlignX(0);
            else if (v == "center") setAlignX(1);
            else if (v == "right") setAlignX(2);
        } else if (node->tag() == "align-y") {
            const auto& v = node->value<std::string>();
            if (v == "top") setAlignY(0);
            else if (v == "center") setAlignY(1);
            else if (v == "bottom") setAlignY(2);
        }
    }
}

void UIClayLayout::setDirection(int direction) { m_direction = direction; update(); }
void UIClayLayout::setChildGap(int gap) { m_childGap = gap; update(); }
void UIClayLayout::setPaddingX(int padding) { (void)padding; update(); }
void UIClayLayout::setPaddingY(int padding) { (void)padding; update(); }
void UIClayLayout::setAlignX(int align) { m_alignX = align; update(); }
void UIClayLayout::setAlignY(int align) { m_alignY = align; update(); }

static Clay_SizingAxis mapWidgetSizing(const SizeUnit& sizeUnit, float flexGrow, int minSize, int maxSize)
{
    const float fMin = static_cast<float>(minSize > 0 ? minSize : 0);
    const float fMax = maxSize > 0 ? static_cast<float>(maxSize) : static_cast<float>(CLAY__MAX(0, 100000));

    // flex-grow takes priority: if widget wants to grow, use GROW sizing
    if (flexGrow > 0.f) {
        return Clay_SizingAxis{
            .size = { .minMax = { fMin, fMax } },
            .type = CLAY__SIZING_TYPE_GROW
        };
    }

    switch (sizeUnit.unit) {
        case Unit::Percent:
            return Clay_SizingAxis{
                .size = { .percent = static_cast<float>(sizeUnit.value) / 100.0f },
                .type = CLAY__SIZING_TYPE_PERCENT
            };

        case Unit::Px:
            if (sizeUnit.value > 0) {
                const float fixed = static_cast<float>(sizeUnit.value);
                return Clay_SizingAxis{
                    .size = { .minMax = { fixed, fixed } },
                    .type = CLAY__SIZING_TYPE_FIXED
                };
            }
            // fallthrough to FIT for 0 or negative px
            [[fallthrough]];

        case Unit::Auto:
        case Unit::FitContent:
        default:
            return Clay_SizingAxis{
                .size = { .minMax = { fMin, fMax } },
                .type = CLAY__SIZING_TYPE_FIT
            };
    }
}

bool UIClayLayout::internalUpdate()
{
    const auto& parentWidget = getParentWidget();
    if (!parentWidget)
        return false;

    const auto& children = parentWidget->getChildren();
    if (children.empty())
        return false;

    // Collect visible children
    std::vector<UIWidgetPtr> visibleChildren;
    visibleChildren.reserve(children.size());
    for (const auto& child : children) {
        if (child->isExplicitlyVisible())
            visibleChildren.push_back(child);
    }
    if (visibleChildren.empty())
        return false;

    // Set Clay context for this layout instance
    Clay_SetCurrentContext(m_clay->context);

    const Rect paddingRect = parentWidget->getPaddingRect();
    const float containerW = static_cast<float>(paddingRect.width());
    const float containerH = static_cast<float>(paddingRect.height());

    Clay_SetLayoutDimensions(Clay_Dimensions{ containerW, containerH });
    Clay_SetMeasureTextFunction(clayMeasureText, nullptr);

    // Map alignment
    Clay_LayoutAlignmentX alignX = CLAY_ALIGN_X_LEFT;
    if (m_alignX == 1) alignX = CLAY_ALIGN_X_CENTER;
    else if (m_alignX == 2) alignX = CLAY_ALIGN_X_RIGHT;

    Clay_LayoutAlignmentY alignY = CLAY_ALIGN_Y_TOP;
    if (m_alignY == 1) alignY = CLAY_ALIGN_Y_CENTER;
    else if (m_alignY == 2) alignY = CLAY_ALIGN_Y_BOTTOM;

    const auto layoutDirection = (m_direction == 0)
        ? CLAY_LEFT_TO_RIGHT
        : CLAY_TOP_TO_BOTTOM;

    // Begin Clay layout
    Clay_BeginLayout();

    // Root container element
    Clay__OpenElement();
    Clay__ConfigureOpenElement(Clay_ElementDeclaration{
        .layout = {
            .sizing = {
                .width = { .size = { .minMax = { containerW, containerW } }, .type = CLAY__SIZING_TYPE_FIXED },
                .height = { .size = { .minMax = { containerH, containerH } }, .type = CLAY__SIZING_TYPE_FIXED }
            },
            .padding = {},
            .childGap = static_cast<uint16_t>(m_childGap),
            .childAlignment = { alignX, alignY },
            .layoutDirection = layoutDirection,
        }
    });

    // Declare each visible child as a Clay element
    for (size_t i = 0; i < visibleChildren.size(); ++i) {
        const auto& child = visibleChildren[i];

        const Clay_SizingAxis widthSizing = mapWidgetSizing(
            child->getWidthHtml(), child->getFlexGrow(),
            child->getMinWidth(), child->getMaxWidth()
        );

        const Clay_SizingAxis heightSizing = mapWidgetSizing(
            child->getHeightHtml(), child->getFlexGrow(),
            child->getMinHeight(), child->getMaxHeight()
        );

        // Use child's own content size as fallback for FIT sizing
        // If the child has explicit size and sizing is FIT, use the current widget size as min
        Clay_SizingAxis finalWidth = widthSizing;
        Clay_SizingAxis finalHeight = heightSizing;

        if (widthSizing.type == CLAY__SIZING_TYPE_FIT && child->getWidth() > 0) {
            finalWidth.size.minMax.min = static_cast<float>(child->getWidth());
            finalWidth.size.minMax.max = static_cast<float>(child->getWidth());
            finalWidth.type = CLAY__SIZING_TYPE_FIXED;
        }
        if (heightSizing.type == CLAY__SIZING_TYPE_FIT && child->getHeight() > 0) {
            finalHeight.size.minMax.min = static_cast<float>(child->getHeight());
            finalHeight.size.minMax.max = static_cast<float>(child->getHeight());
            finalHeight.type = CLAY__SIZING_TYPE_FIXED;
        }

        Clay_String idStr{ true, 5, "child" };
        Clay__OpenElementWithId(Clay__HashStringWithOffset(idStr, static_cast<uint32_t>(i), 0));
        Clay__ConfigureOpenElement(Clay_ElementDeclaration{
            .layout = {
                .sizing = { finalWidth, finalHeight }
            }
        });
        Clay__CloseElement();
    }

    // Close root container
    Clay__CloseElement();

    // Compute layout
    Clay_RenderCommandArray commands = Clay_EndLayout();

    // Map computed positions back to widgets
    bool changed = false;
    const Point basePos = paddingRect.topLeft();
    const Point virtualOffset = parentWidget->getVirtualOffset();

    for (size_t i = 0; i < visibleChildren.size(); ++i) {
        Clay_String idStr{ true, 5, "child" };
        Clay_ElementId elementId = Clay__HashStringWithOffset(idStr, static_cast<uint32_t>(i), 0);
        Clay_ElementData data = Clay_GetElementData(elementId);

        if (!data.found)
            continue;

        const auto& child = visibleChildren[i];
        const Rect newRect(
            basePos.x + static_cast<int>(data.boundingBox.x) - virtualOffset.x,
            basePos.y + static_cast<int>(data.boundingBox.y) - virtualOffset.y,
            static_cast<int>(data.boundingBox.width),
            static_cast<int>(data.boundingBox.height)
        );

        if (child->setRect(newRect))
            changed = true;
    }

    return changed;
}

#endif // FRAMEWORK_CLAY
