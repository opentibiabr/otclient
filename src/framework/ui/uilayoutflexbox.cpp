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

#include "uilayoutflexbox.h"

#include "uiwidget.h"

namespace {
    enum class Axis { Horizontal, Vertical };

    struct FlexItemData
    {
        UIWidget* widget{ nullptr };
        size_t sourceIndex{ 0 };
        int order{ 0 };
        float flexGrow{ 0.f };
        float flexShrink{ 1.f };
        FlexBasis basis;
        AlignSelf alignSelf{ AlignSelf::Auto };

        double baseSize{ 0.0 };
        double mainSize{ 0.0 };
        double minMain{ 0.0 };
        double maxMain{ std::numeric_limits<double>::infinity() };

        double crossSize{ 0.0 };
        double minCross{ 0.0 };
        double maxCross{ std::numeric_limits<double>::infinity() };

        double marginMainStart{ 0.0 };
        double marginMainEnd{ 0.0 };
        double marginCrossStart{ 0.0 };
        double marginCrossEnd{ 0.0 };
        bool autoMainStart{ false };
        bool autoMainEnd{ false };

        double mainPos{ 0.0 };
        double crossPos{ 0.0 };
        double finalCrossSize{ 0.0 };
    };

    struct FlexLine
    {
        std::vector<size_t> itemIndices;
        double crossSize{ 0.0 };
        double mainSize{ 0.0 };
    };

    inline Axis mainAxisForDirection(FlexDirection direction)
    {
        return (direction == FlexDirection::Row || direction == FlexDirection::RowReverse) ? Axis::Horizontal : Axis::Vertical;
    }

    inline bool isMainReverse(FlexDirection direction)
    {
        return direction == FlexDirection::RowReverse || direction == FlexDirection::ColumnReverse;
    }

    inline double getUnitValue(const SizeUnit& unit, double reference)
    {
        switch (unit.unit) {
            case Unit::Px:
                return unit.value;
            case Unit::Percent:
                return (reference > 0.0) ? (reference * unit.value) / 100.0 : 0.0;
            default:
                return -1.0;
        }
    }

    inline double clampToLimits(double value, double minValue, double maxValue)
    {
        if (value < minValue)
            value = minValue;
        if (value > maxValue)
            value = maxValue;
        return value;
    }

    inline double availableLimit(double maxValue)
    {
        return maxValue <= 0.0 ? std::numeric_limits<double>::infinity() : maxValue;
    }

    inline int roundi(double value)
    {
        return static_cast<int>(std::round(value));
    }

    inline double maxDouble(double a, double b)
    {
        return a > b ? a : b;
    }

    void distributePositiveSpace(std::vector<FlexItemData*>& items, double& freeSpace)
    {
        if (freeSpace <= 0.0)
            return;

        const double epsilon = 0.1;
        std::vector<bool> frozen(items.size(), false);

        while (freeSpace > epsilon) {
            double totalFlex = 0.0;
            for (size_t i = 0; i < items.size(); ++i) {
                if (!frozen[i])
                    totalFlex += items[i]->flexGrow;
            }

            if (totalFlex <= 0.0)
                break;

            bool anyFrozen = false;
            const double share = freeSpace / totalFlex;

            for (size_t i = 0; i < items.size(); ++i) {
                if (frozen[i])
                    continue;

                auto& item = *items[i];
                double addition = item.flexGrow * share;
                double newSize = item.mainSize + addition;
                const double maxLimit = availableLimit(item.maxMain);
                if (newSize > maxLimit) {
                    addition = maxLimit - item.mainSize;
                    newSize = maxLimit;
                    frozen[i] = true;
                    anyFrozen = true;
                }

                item.mainSize = newSize;
                freeSpace -= addition;
                if (freeSpace <= epsilon)
                    break;
            }

            if (!anyFrozen)
                break;
        }

        if (freeSpace < 0.0)
            freeSpace = 0.0;
    }

    AlignSelf alignSelfFromAlignItems(AlignItems alignItems)
    {
        switch (alignItems) {
            case AlignItems::Stretch:
                return AlignSelf::Stretch;
            case AlignItems::FlexStart:
                return AlignSelf::FlexStart;
            case AlignItems::FlexEnd:
                return AlignSelf::FlexEnd;
            case AlignItems::Center:
                return AlignSelf::Center;
            case AlignItems::Baseline:
                return AlignSelf::Baseline;
            default:
                return AlignSelf::Stretch;
        }
    }

    void distributeNegativeSpace(std::vector<FlexItemData*>& items, double& freeSpace)
    {
        if (freeSpace >= 0.0)
            return;

        double remaining = -freeSpace;
        const double epsilon = 0.1;
        std::vector<bool> frozen(items.size(), false);

        while (remaining > epsilon) {
            double shrinkFactorSum = 0.0;
            for (size_t i = 0; i < items.size(); ++i) {
                if (!frozen[i])
                    shrinkFactorSum += items[i]->flexShrink * items[i]->baseSize;
            }

            if (shrinkFactorSum <= 0.0)
                break;

            bool anyFrozen = false;
            const double share = remaining / shrinkFactorSum;

            for (size_t i = 0; i < items.size(); ++i) {
                if (frozen[i])
                    continue;

                auto& item = *items[i];
                double shrink = item.flexShrink * item.baseSize * share;
                double newSize = item.mainSize - shrink;
                const double minLimit = item.minMain;
                if (newSize < minLimit) {
                    shrink = item.mainSize - minLimit;
                    newSize = minLimit;
                    frozen[i] = true;
                    anyFrozen = true;
                }

                item.mainSize = newSize;
                remaining -= shrink;
                if (remaining <= epsilon)
                    break;
            }

            if (!anyFrozen)
                break;
        }

        freeSpace = -remaining;
        if (std::abs(freeSpace) < epsilon)
            freeSpace = 0.0;
    }
}

void layoutFlex(UIWidget& container)
{
    const auto& style = container.style();
    const Axis mainAxis = mainAxisForDirection(style.flexDirection);
    const bool mainReverse = isMainReverse(style.flexDirection);
    const bool wrapReverse = style.flexWrap == FlexWrap::WrapReverse;
    const bool allowWrap = style.flexWrap != FlexWrap::NoWrap;

    const int paddingStart = (mainAxis == Axis::Horizontal) ? container.getPaddingLeft() : container.getPaddingTop();
    const int paddingCrossStart = (mainAxis == Axis::Horizontal) ? container.getPaddingTop() : container.getPaddingLeft();
    const int paddingEnd = (mainAxis == Axis::Horizontal) ? container.getPaddingRight() : container.getPaddingBottom();
    const int paddingCrossEnd = (mainAxis == Axis::Horizontal) ? container.getPaddingBottom() : container.getPaddingRight();

    const int containerMainSize = (mainAxis == Axis::Horizontal) ? container.getWidth() : container.getHeight();
    const int containerCrossSize = (mainAxis == Axis::Horizontal) ? container.getHeight() : container.getWidth();

    const double innerMainSize = std::max(0, containerMainSize - paddingStart - paddingEnd);
    double innerCrossSize = std::max(0, containerCrossSize - paddingCrossStart - paddingCrossEnd);

    const double mainGap = (mainAxis == Axis::Horizontal) ? style.columnGap : style.rowGap;
    const double crossGap = (mainAxis == Axis::Horizontal) ? style.rowGap : style.columnGap;

    std::vector<FlexItemData> items;
    items.reserve(container.getChildCount());

    size_t index = 0;
    for (const auto& childPtr : container.getChildren()) {
        UIWidget* child = childPtr.get();
        if (!child)
            continue;
        if (child->getDisplay() == DisplayType::None)
            continue;
        if (child->getPositionType() == PositionType::Absolute)
            continue;

        child->updateSize();

        FlexItemData item;
        item.widget = child;
        item.sourceIndex = index++;

        const auto& childStyle = child->style();
        item.order = childStyle.order;
        item.flexGrow = std::max(0.f, childStyle.flexGrow);
        item.flexShrink = std::max(0.f, childStyle.flexShrink);
        item.basis = childStyle.flexBasis;
        item.alignSelf = childStyle.alignSelf;

        const bool horizontal = (mainAxis == Axis::Horizontal);
        const SizeUnit& preferredMainUnit = horizontal ? child->getWidthHtml() : child->getHeightHtml();
        const SizeUnit& preferredCrossUnit = horizontal ? child->getHeightHtml() : child->getWidthHtml();

        auto preferredMainSize = getUnitValue(preferredMainUnit, innerMainSize);
        if (preferredMainSize < 0.0)
            preferredMainSize = horizontal ? child->getWidth() : child->getHeight();

        auto preferredCrossSize = getUnitValue(preferredCrossUnit, innerCrossSize);
        if (preferredCrossSize < 0.0)
            preferredCrossSize = horizontal ? child->getHeight() : child->getWidth();

        switch (item.basis.type) {
            case FlexBasis::Type::Px:
                item.baseSize = item.basis.value;
                break;
            case FlexBasis::Type::Percent:
                item.baseSize = (innerMainSize > 0.0) ? (innerMainSize * item.basis.value) / 100.0 : 0.0;
                break;
            case FlexBasis::Type::Content:
                item.baseSize = preferredMainSize;
                break;
            case FlexBasis::Type::Auto:
            default:
                item.baseSize = preferredMainSize;
                break;
        }

        item.mainSize = item.baseSize;
        item.minMain = horizontal ? child->getMinWidth() : child->getMinHeight();
        double maxMain = horizontal ? child->getMaxWidth() : child->getMaxHeight();
        item.maxMain = availableLimit(maxMain);
        item.mainSize = clampToLimits(item.mainSize, item.minMain, item.maxMain);

        item.crossSize = preferredCrossSize;
        item.minCross = horizontal ? child->getMinHeight() : child->getMinWidth();
        double maxCross = horizontal ? child->getMaxHeight() : child->getMaxWidth();
        item.maxCross = availableLimit(maxCross);
        item.finalCrossSize = clampToLimits(item.crossSize, item.minCross, item.maxCross);

        if (horizontal) {
            item.marginMainStart = child->getMarginLeft();
            item.marginMainEnd = child->getMarginRight();
            item.marginCrossStart = child->getMarginTop();
            item.marginCrossEnd = child->getMarginBottom();
            item.autoMainStart = child->isMarginLeftAuto();
            item.autoMainEnd = child->isMarginRightAuto();
        } else {
            item.marginMainStart = child->getMarginTop();
            item.marginMainEnd = child->getMarginBottom();
            item.marginCrossStart = child->getMarginLeft();
            item.marginCrossEnd = child->getMarginRight();
            item.autoMainStart = false;
            item.autoMainEnd = false;
        }

        if (mainReverse) {
            std::swap(item.marginMainStart, item.marginMainEnd);
            std::swap(item.autoMainStart, item.autoMainEnd);
        }

        items.push_back(item);
    }

    if (items.empty()) {
        for (const auto& childPtr : container.getChildren()) {
            if (childPtr && childPtr->getPositionType() == PositionType::Absolute)
                childPtr->updateSize();
        }
        return;
    }

    std::stable_sort(items.begin(), items.end(), [](const FlexItemData& a, const FlexItemData& b) {
        if (a.order != b.order)
            return a.order < b.order;
        return a.sourceIndex < b.sourceIndex;
    });

    std::vector<FlexLine> lines;
    FlexLine currentLine;
    double currentLineSize = 0.0;

    for (size_t i = 0; i < items.size(); ++i) {
        auto& item = items[i];
        const double outerSize = item.marginMainStart + item.mainSize + item.marginMainEnd;

        if (allowWrap && !currentLine.itemIndices.empty() && innerMainSize > 0.0) {
            const double projected = currentLineSize + mainGap + outerSize;
            if (projected - 0.5 > innerMainSize) {
                lines.push_back(currentLine);
                currentLine = FlexLine{};
                currentLineSize = 0.0;
            } else {
                currentLineSize += mainGap;
            }
        }

        currentLine.itemIndices.push_back(i);
        currentLineSize += outerSize;
    }

    if (!currentLine.itemIndices.empty())
        lines.push_back(currentLine);

    for (auto& line : lines) {
        double lineCross = 0.0;
        for (size_t idx : line.itemIndices) {
            auto& item = items[idx];
            const double cross = item.finalCrossSize + item.marginCrossStart + item.marginCrossEnd;
            lineCross = maxDouble(lineCross, cross);
        }
        line.crossSize = lineCross;
    }

    double contentCross = 0.0;
    for (size_t i = 0; i < lines.size(); ++i) {
        contentCross += lines[i].crossSize;
        if (i + 1 < lines.size())
            contentCross += crossGap;
    }

    const bool crossAuto = (mainAxis == Axis::Horizontal)
        ? (container.getHeightHtml().needsUpdate(Unit::Auto) || container.getHeightHtml().needsUpdate(Unit::FitContent))
        : (container.getWidthHtml().needsUpdate(Unit::Auto) || container.getWidthHtml().needsUpdate(Unit::FitContent));

    if (crossAuto)
        innerCrossSize = contentCross;

    for (auto& line : lines) {
        std::vector<FlexItemData*> lineItems;
        lineItems.reserve(line.itemIndices.size());
        double totalOuter = 0.0;
        int autoMarginCount = 0;
        for (size_t idx : line.itemIndices) {
            auto& item = items[idx];
            lineItems.push_back(&item);
            totalOuter += item.marginMainStart + item.mainSize + item.marginMainEnd;
            if (&item != &items[line.itemIndices.front()])
                totalOuter += mainGap;
            if (item.autoMainStart)
                ++autoMarginCount;
            if (item.autoMainEnd)
                ++autoMarginCount;
        }

        double freeSpace = innerMainSize - totalOuter;
        if (autoMarginCount > 0 && freeSpace > 0.0) {
            const double share = freeSpace / autoMarginCount;
            for (auto* item : lineItems) {
                if (item->autoMainStart)
                    item->marginMainStart = share;
                if (item->autoMainEnd)
                    item->marginMainEnd = share;
            }
            freeSpace = 0.0;
        }

        if (freeSpace > 0.0)
            distributePositiveSpace(lineItems, freeSpace);
        else if (freeSpace < 0.0)
            distributeNegativeSpace(lineItems, freeSpace);

        totalOuter = 0.0;
        for (size_t j = 0; j < line.itemIndices.size(); ++j) {
            const auto& item = items[line.itemIndices[j]];
            totalOuter += item.marginMainStart + item.mainSize + item.marginMainEnd;
            if (j + 1 < line.itemIndices.size())
                totalOuter += mainGap;
        }
        freeSpace = innerMainSize - totalOuter;
        line.mainSize = totalOuter;

        double betweenSpacing = mainGap;
        double leadingSpace = 0.0;
        const size_t count = line.itemIndices.size();
        const double positiveFree = std::max(0.0, freeSpace);
        switch (style.justifyContent) {
            case JustifyContent::FlexStart:
                break;
            case JustifyContent::FlexEnd:
                leadingSpace = freeSpace;
                break;
            case JustifyContent::Center:
                leadingSpace = freeSpace / 2.0;
                break;
            case JustifyContent::SpaceBetween:
                if (count > 1)
                    betweenSpacing = mainGap + positiveFree / (count - 1);
                break;
            case JustifyContent::SpaceAround:
                if (count > 0) {
                    betweenSpacing = mainGap + positiveFree / count;
                    leadingSpace = betweenSpacing / 2.0;
                }
                break;
            case JustifyContent::SpaceEvenly:
                betweenSpacing = mainGap + positiveFree / (count + 1);
                leadingSpace = betweenSpacing;
                break;
        }

        if (!mainReverse) {
            double cursor = leadingSpace;
            for (size_t idx = 0; idx < count; ++idx) {
                auto& item = items[line.itemIndices[idx]];
                cursor += item.marginMainStart;
                item.mainPos = cursor;
                cursor += item.mainSize + item.marginMainEnd;
                if (idx + 1 < count)
                    cursor += betweenSpacing;
            }
        } else {
            double cursor = innerMainSize - leadingSpace;
            for (size_t offset = 0; offset < count; ++offset) {
                auto& item = items[line.itemIndices[count - 1 - offset]];
                cursor -= item.marginMainStart;
                cursor -= item.mainSize;
                item.mainPos = cursor;
                cursor -= item.marginMainEnd;
                if (offset + 1 < count)
                    cursor -= betweenSpacing;
            }
        }
    }

    double totalCross = 0.0;
    for (const auto& line : lines)
        totalCross += line.crossSize;
    totalCross += crossGap * (lines.size() > 0 ? (lines.size() - 1) : 0);

    double crossFreeSpace = innerCrossSize - totalCross;
    double betweenCross = crossGap;
    double crossLeading = 0.0;
    const size_t lineCount = lines.size();
    const double positiveCrossFree = std::max(0.0, crossFreeSpace);

    if (style.alignContent == AlignContent::Stretch && lineCount > 0) {
        if (positiveCrossFree > 0.0) {
            const double addition = positiveCrossFree / lineCount;
            for (auto& line : lines)
                line.crossSize += addition;
            double recomputed = 0.0;
            for (const auto& line : lines)
                recomputed += line.crossSize;
            recomputed += crossGap * (lineCount > 0 ? (lineCount - 1) : 0);
            crossFreeSpace = innerCrossSize - recomputed;
        }
        crossLeading = 0.0;
        betweenCross = crossGap;
    } else {
        switch (style.alignContent) {
            case AlignContent::FlexStart:
                break;
            case AlignContent::FlexEnd:
                crossLeading = crossFreeSpace;
                break;
            case AlignContent::Center:
                crossLeading = crossFreeSpace / 2.0;
                break;
            case AlignContent::SpaceBetween:
                if (lineCount > 1)
                    betweenCross = crossGap + positiveCrossFree / (lineCount - 1);
                break;
            case AlignContent::SpaceAround:
                if (lineCount > 0) {
                    betweenCross = crossGap + positiveCrossFree / lineCount;
                    crossLeading = betweenCross / 2.0;
                }
                break;
            case AlignContent::SpaceEvenly:
                betweenCross = crossGap + positiveCrossFree / (lineCount + 1);
                crossLeading = betweenCross;
                break;
            case AlignContent::Stretch:
                break;
        }
    }

    std::vector<size_t> lineOrder(lineCount);
    for (size_t i = 0; i < lineCount; ++i)
        lineOrder[i] = i;
    if (wrapReverse)
        std::reverse(lineOrder.begin(), lineOrder.end());

    std::vector<double> lineOffsets(lineCount, 0.0);
    double crossCursor = crossLeading;
    for (size_t pos = 0; pos < lineCount; ++pos) {
        const size_t idx = lineOrder[pos];
        lineOffsets[idx] = crossCursor;
        crossCursor += lines[idx].crossSize;
        if (pos + 1 < lineCount)
            crossCursor += betweenCross;
    }

    for (size_t lineIdx = 0; lineIdx < lineCount; ++lineIdx) {
        const double lineCrossSize = lines[lineIdx].crossSize;
        for (size_t itemIdx : lines[lineIdx].itemIndices) {
            auto& item = items[itemIdx];
            AlignSelf align = item.alignSelf;
            if (align == AlignSelf::Auto)
                align = alignSelfFromAlignItems(style.alignItems);

            double available = lineCrossSize - item.marginCrossStart - item.marginCrossEnd;
            available = std::max(0.0, available);

            if (align == AlignSelf::Stretch) {
                item.finalCrossSize = clampToLimits(available, item.minCross, item.maxCross);
            } else {
                item.finalCrossSize = clampToLimits(item.finalCrossSize, item.minCross, item.maxCross);
                item.finalCrossSize = std::min(item.finalCrossSize, available);
            }

            const double baseOffset = lineOffsets[lineIdx];
            switch (align) {
                case AlignSelf::FlexEnd:
                    item.crossPos = baseOffset + lineCrossSize - item.marginCrossEnd - item.finalCrossSize;
                    break;
                case AlignSelf::Center:
                    item.crossPos = baseOffset + (lineCrossSize - item.finalCrossSize - item.marginCrossStart - item.marginCrossEnd) / 2.0 + item.marginCrossStart;
                    break;
                case AlignSelf::Baseline:
                case AlignSelf::FlexStart:
                case AlignSelf::Stretch:
                default:
                    item.crossPos = baseOffset + item.marginCrossStart;
                    break;
            }
        }
    }

    for (auto& item : items) {
        if (!item.widget)
            continue;
        const int width = (mainAxis == Axis::Horizontal) ? std::max(0, roundi(item.mainSize)) : std::max(0, roundi(item.finalCrossSize));
        const int height = (mainAxis == Axis::Horizontal) ? std::max(0, roundi(item.finalCrossSize)) : std::max(0, roundi(item.mainSize));

        const int x = container.getPaddingLeft() + ((mainAxis == Axis::Horizontal) ? roundi(item.mainPos) : roundi(item.crossPos));
        const int y = container.getPaddingTop() + ((mainAxis == Axis::Horizontal) ? roundi(item.crossPos) : roundi(item.mainPos));

        item.widget->setRect(Rect(Point(x, y), Size(width, height)));
    }

    if (crossAuto) {
        const double totalCrossWithPadding = contentCross + paddingCrossStart + paddingCrossEnd;
        int desired = std::max(0, roundi(totalCrossWithPadding));
        if (mainAxis == Axis::Horizontal) {
            const int minH = container.getMinHeight();
            const int maxH = container.getMaxHeight();
            if (minH >= 0)
                desired = std::max(desired, minH);
            if (maxH >= 0)
                desired = std::min(desired, maxH);
            if (container.getHeight() != desired)
                container.setHeight_px(desired);
        } else {
            const int minW = container.getMinWidth();
            const int maxW = container.getMaxWidth();
            if (minW >= 0)
                desired = std::max(desired, minW);
            if (maxW >= 0)
                desired = std::min(desired, maxW);
            if (container.getWidth() != desired)
                container.setWidth_px(desired);
        }
    }

    for (const auto& childPtr : container.getChildren()) {
        if (childPtr && childPtr->getPositionType() == PositionType::Absolute)
            childPtr->updateSize();
    }
}