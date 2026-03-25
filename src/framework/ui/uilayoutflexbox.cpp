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
#include <framework/html/htmlnode.h>

namespace {
    constexpr int MAX_FLEX_DEPTH = 32;
    thread_local int s_flexDepth = 0;
    thread_local std::array<std::vector<UIWidgetPtr>, MAX_FLEX_DEPTH> s_pendingDescendantVersionResetRootsByDepth;
    thread_local std::array<std::unordered_set<UIWidget*>, MAX_FLEX_DEPTH> s_pendingDescendantVersionResetLookupByDepth;

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

        double contentMainSize{ 0.0 };  // intrinsic/content main size for auto-min

        double mainPos{ 0.0 };
        double crossPos{ 0.0 };
        double finalCrossSize{ 0.0 };
        bool crossSizeAuto{ true };
        bool rectChanged{ false };
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

    inline Axis crossAxisForMain(Axis mainAxis)
    {
        return mainAxis == Axis::Horizontal ? Axis::Vertical : Axis::Horizontal;
    }

    inline bool axisUsesContentWhenAuto(DisplayType display, Axis axis, const SizeUnit& unit)
    {
        if (unit.unit == Unit::FitContent)
            return true;
        if (unit.unit != Unit::Auto)
            return false;

        // display:flex (block-level) width:auto uses available containing width.
        // display:inline-flex width:auto shrink-wraps content.
        if (axis == Axis::Horizontal)
            return display == DisplayType::InlineFlex;

        // height:auto remains content-sized in normal flow.
        return true;
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

    // Shared utility: clamp int to positive int32_t range for SizeUnit::value.
    inline int32_t clampToPositiveSize(int value)
    {
        if (value < 0)
            return 0;
        return static_cast<int32_t>(value);
    }

    // RAII guard that saves and restores a SizeUnit on destruction.
    // Prevents state corruption if an exception or early return occurs
    // between temporary mutation and restoration.
    struct SizeUnitGuard {
        SizeUnit& ref;
        const SizeUnit original;
        SizeUnitGuard(SizeUnit& r) : ref(r), original(r) {}
        ~SizeUnitGuard() { ref = original; }
        SizeUnitGuard(const SizeUnitGuard&) = delete;
        SizeUnitGuard& operator=(const SizeUnitGuard&) = delete;
    };

    bool isDescendantOf(UIWidget* node, UIWidget* ancestor)
    {
        if (!node || !ancestor || node == ancestor)
            return false;

        auto parent = node->getParent();
        while (parent) {
            if (parent.get() == ancestor)
                return true;
            parent = parent->getParent();
        }
        return false;
    }

    void resetDescendantVersionsNow(UIWidget* w)
    {
        for (const auto& child : w->getChildrenRef()) {
            if (child->isDestroyed() || child->getDisplay() == DisplayType::None)
                continue;

            auto& cw = child->getWidthHtml();
            if (cw.unit == Unit::Auto || cw.unit == Unit::FitContent || cw.unit == Unit::Percent) {
                cw.pendingUpdate = true;
                cw.version = 0;
            }
            auto& ch = child->getHeightHtml();
            if (ch.unit == Unit::Auto || ch.unit == Unit::FitContent || ch.unit == Unit::Percent) {
                ch.pendingUpdate = true;
                ch.version = 0;
            }
            if (!child->getChildrenRef().empty())
                resetDescendantVersionsNow(child.get());
        }
    }

    void queueDescendantVersionReset(UIWidget* root)
    {
        if (!root || root->isDestroyed() || s_flexDepth <= 0)
            return;

        const size_t depthIndex = static_cast<size_t>(s_flexDepth - 1);
        if (depthIndex >= MAX_FLEX_DEPTH)
            return;

        const UIWidgetPtr rootPtr = root->static_self_cast<UIWidget>();
        if (!rootPtr)
            return;

        auto& roots = s_pendingDescendantVersionResetRootsByDepth[depthIndex];
        auto& lookup = s_pendingDescendantVersionResetLookupByDepth[depthIndex];

        if (lookup.find(rootPtr.get()) != lookup.end())
            return;

        for (auto parent = rootPtr->getParent(); parent; parent = parent->getParent()) {
            if (lookup.find(parent.get()) != lookup.end())
                return;
        }

        for (auto& queuedRoot : roots) {
            if (!queuedRoot)
                continue;

            if (queuedRoot->isDestroyed()) {
                lookup.erase(queuedRoot.get());
                queuedRoot.reset();
                continue;
            }

            if (isDescendantOf(queuedRoot.get(), rootPtr.get())) {
                lookup.erase(queuedRoot.get());
                queuedRoot.reset();
            }
        }

        roots.push_back(rootPtr);
        lookup.insert(rootPtr.get());
    }

    void flushQueuedDescendantVersionResetsForCurrentDepth()
    {
        if (s_flexDepth <= 0)
            return;

        const size_t depthIndex = static_cast<size_t>(s_flexDepth - 1);
        if (depthIndex >= MAX_FLEX_DEPTH)
            return;

        auto& roots = s_pendingDescendantVersionResetRootsByDepth[depthIndex];
        auto& lookup = s_pendingDescendantVersionResetLookupByDepth[depthIndex];

        for (auto& root : roots) {
            if (!root)
                continue;
            if (lookup.erase(root.get()) == 0)
                continue;
            if (root->isDestroyed())
                continue;

            resetDescendantVersionsNow(root.get());
        }

        roots.clear();
        lookup.clear();
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

    // Distribute auto-margins and then flex grow/shrink.
    // Shared between mainAuto and definite-main paths to avoid duplication.
    void distributeAutoMarginsAndSpace(
        std::vector<FlexItemData*>& lineItems,
        int autoMarginCount,
        double& freeSpace)
    {
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
    }
}

void layoutFlex(UIWidget& container)
{
    // Re-entrance guard: prevent the same container from re-entering layoutFlex
    if (container.m_inFlexLayout)
        return;

    // Global depth limit: prevent infinite recursion through nested flex containers
    if (s_flexDepth >= MAX_FLEX_DEPTH) {
        g_logger.warning("layoutFlex: maximum nesting depth ({}) exceeded, skipping layout", MAX_FLEX_DEPTH);
        return;
    }

    struct FlexDepthGuard {
        UIWidget& c;
        FlexDepthGuard(UIWidget& w) : c(w) { c.m_inFlexLayout = true; ++s_flexDepth; }
        ~FlexDepthGuard() {
            flushQueuedDescendantVersionResetsForCurrentDepth();
            c.m_inFlexLayout = false;
            --s_flexDepth;
        }
    } guard(container);

    const auto& style = container.style();
    const Axis mainAxis = mainAxisForDirection(style.flexDirection);
    const bool mainReverse = isMainReverse(style.flexDirection);
    const bool wrapReverse = style.flexWrap == FlexWrap::WrapReverse;
    const bool allowWrap = style.flexWrap != FlexWrap::NoWrap;
    const auto parentWidget = container.getParent();
    const bool isFlexItemInParent =
        parentWidget &&
        container.getPositionType() != PositionType::Absolute &&
        (parentWidget->getDisplay() == DisplayType::Flex || parentWidget->getDisplay() == DisplayType::InlineFlex);
    const Axis parentMainAxis = isFlexItemInParent
        ? mainAxisForDirection(parentWidget->style().flexDirection)
        : Axis::Horizontal;

    const int paddingStart = (mainAxis == Axis::Horizontal) ? container.getPaddingLeft() : container.getPaddingTop();
    const int paddingCrossStart = (mainAxis == Axis::Horizontal) ? container.getPaddingTop() : container.getPaddingLeft();
    const int paddingEnd = (mainAxis == Axis::Horizontal) ? container.getPaddingRight() : container.getPaddingBottom();
    const int paddingCrossEnd = (mainAxis == Axis::Horizontal) ? container.getPaddingBottom() : container.getPaddingRight();

    const int containerMainSize = (mainAxis == Axis::Horizontal) ? container.getWidth() : container.getHeight();
    const int containerCrossSize = (mainAxis == Axis::Horizontal) ? container.getHeight() : container.getWidth();

    const int containerMinMain = (mainAxis == Axis::Horizontal) ? container.getMinWidth() : container.getMinHeight();
    const int containerMaxMain = (mainAxis == Axis::Horizontal) ? container.getMaxWidth() : container.getMaxHeight();
    const double minInnerMainConstraint = containerMinMain > 0
        ? std::max(0, containerMinMain - paddingStart - paddingEnd)
        : 0.0;
    const double maxInnerMainConstraint = containerMaxMain > 0
        ? std::max(0, containerMaxMain - paddingStart - paddingEnd)
        : std::numeric_limits<double>::infinity();

    const auto& containerMainUnit = (mainAxis == Axis::Horizontal) ? container.getWidthHtml() : container.getHeightHtml();
    bool mainAuto = axisUsesContentWhenAuto(style.display, mainAxis, containerMainUnit);
    // Only suppress main-axis auto sizing when the parent controls this same axis.
    // If axes differ (e.g. row parent -> column child), the child's main axis
    // is not directly controlled by the parent and must remain content-sized.
    if (isFlexItemInParent && containerMainSize > 0 && parentMainAxis == mainAxis)
        mainAuto = false;

    double innerMainSize = std::max(0, containerMainSize - paddingStart - paddingEnd);
    double innerCrossSize = std::max(0, containerCrossSize - paddingCrossStart - paddingCrossEnd);

    // Cache the containing-block inner-main-size from ancestor chain.
    // This walk is O(depth) and we may need it in up to two places below,
    // so compute it once and reuse the cached value.
    double cachedContainingInnerMain = -1.0;
    const auto getContainingInnerMain = [&container, &cachedContainingInnerMain]() -> double {
        if (cachedContainingInnerMain >= 0.0)
            return cachedContainingInnerMain;
        double containingInner = 0.0;
        auto p = container.getParent();
        while (p) {
            const double inner = std::max(0, p->getWidth() - p->getPaddingLeft() - p->getPaddingRight());
            if (inner > 0.0) {
                containingInner = (containingInner <= 0.0) ? inner : std::min(containingInner, inner);

                const auto& pw = p->getWidthHtml();
                if (pw.unit == Unit::Px || pw.unit == Unit::Percent)
                    break;
            }
            p = p->getParent();
        }
        cachedContainingInnerMain = containingInner;
        return containingInner;
    };

    // Block-level display:flex with CSS width:auto must wrap against the
    // available containing-block width. Internal unit/state may drift across
    // async passes; rely on CSS width intent (empty/auto) to keep wrapping
    // stable and avoid one-line overflow on subsequent layout runs.
    bool cssWidthAutoLike = true;
    if (const auto node = container.getHtmlNode()) {
        const std::string cssWidth = node->getStyle("width");
        cssWidthAutoLike = cssWidth.empty() || cssWidth == "auto";
    }

    const bool blockFlexAutoMain =
        mainAxis == Axis::Horizontal &&
        style.display == DisplayType::Flex &&
        !isFlexItemInParent &&
        cssWidthAutoLike;

    if (blockFlexAutoMain) {
        // Use the tightest positive inner width in the ancestor chain as a
        // stable containing width. This prevents width inflation feedback
        // loops where an auto-sized ancestor temporarily expands to content.
        const double containingInner = getContainingInnerMain();

        const double margins = std::max(0, container.getMarginLeft()) + std::max(0, container.getMarginRight());
        const double availableBorderBox = std::max(0.0, containingInner - margins);
        const double availableInner = std::max(0.0, availableBorderBox - paddingStart - paddingEnd);
        if (availableInner > 0.0)
            innerMainSize = availableInner;

        // Even if internal units drift to fit-content, block flex width:auto
        // must not content-size its main axis.
        mainAuto = false;
    }

    // Safety net: wrapping cannot work with zero main size. In transient
    // passes, recover from ancestors instead of collapsing all items into one
    // overflowing line.
    if (allowWrap && mainAxis == Axis::Horizontal && innerMainSize <= 0.0) {
        const double containingInner = getContainingInnerMain();
        const double margins = std::max(0, container.getMarginLeft()) + std::max(0, container.getMarginRight());
        const double availableBorderBox = std::max(0.0, containingInner - margins);
        const double availableInner = std::max(0.0, availableBorderBox - paddingStart - paddingEnd);
        if (availableInner > 0.0)
            innerMainSize = availableInner;
    }

    const double mainGap = (mainAxis == Axis::Horizontal) ? style.columnGap : style.rowGap;
    const double crossGap = (mainAxis == Axis::Horizontal) ? style.rowGap : style.columnGap;

    std::vector<FlexItemData> items;
    items.reserve(container.getChildCount());

    size_t index = 0;
    for (const auto& childPtr : container.getChildrenRef()) {
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
        auto& preferredMainUnit = horizontal ? child->getWidthHtml() : child->getHeightHtml();
        auto& preferredCrossUnit = horizontal ? child->getHeightHtml() : child->getWidthHtml();

        // Border widths: OTC draws borders inside the rect, but in CSS the
        // border-box size = content + padding + border. The flex algorithm
        // must use border-box sizes for wrapping and space distribution.
        const int borderMainStart = horizontal ? child->getBorderLeftWidth() : child->getBorderTopWidth();
        const int borderMainEnd = horizontal ? child->getBorderRightWidth() : child->getBorderBottomWidth();
        const int borderCrossStart = horizontal ? child->getBorderTopWidth() : child->getBorderLeftWidth();
        const int borderCrossEnd = horizontal ? child->getBorderBottomWidth() : child->getBorderRightWidth();
        const int borderMain = borderMainStart + borderMainEnd;
        const int borderCross = borderCrossStart + borderCrossEnd;

        const bool crossAutoLike = preferredCrossUnit.unit == Unit::Auto || preferredCrossUnit.unit == Unit::FitContent;

        // For column-wrap, cross size must be based on intrinsic widths.
        // If we keep previously stretched widths, each line can become as
        // wide as the container and all wrapped columns collapse/overlap.
        if (!horizontal && allowWrap && crossAutoLike) {
            const Unit originalUnit = preferredCrossUnit.unit;
            preferredCrossUnit.pendingUpdate = true;
            preferredCrossUnit.version = 0;
            preferredCrossUnit.unit = Unit::FitContent;
            child->updateSize();
            preferredCrossUnit.unit = originalUnit;
        }

        // For column no-wrap with stretch, auto-width items must be measured
        // with the available cross width before deriving auto heights.
        if (!horizontal && !allowWrap && innerCrossSize > 0.0 && crossAutoLike) {
            AlignSelf effectiveAlign = childStyle.alignSelf;
            if (effectiveAlign == AlignSelf::Auto)
                effectiveAlign = alignSelfFromAlignItems(style.alignItems);

            if (effectiveAlign == AlignSelf::Stretch) {
                const double availableCross = std::max(0.0, innerCrossSize - child->getMarginLeft() - child->getMarginRight());
                const int targetContentWidth = std::max(0, roundi(availableCross) - borderCross);
                const bool mainAutoLike = preferredMainUnit.unit == Unit::Auto || preferredMainUnit.unit == Unit::FitContent;

                SizeUnitGuard crossGuard(preferredCrossUnit);

                child->setWidth_px(targetContentWidth);
                preferredCrossUnit.unit = Unit::Px;
                preferredCrossUnit.value = clampToPositiveSize(targetContentWidth);
                preferredCrossUnit.valueCalculed = preferredCrossUnit.value;
                preferredCrossUnit.pendingUpdate = false;

                if (mainAutoLike) {
                    preferredMainUnit.pendingUpdate = true;
                    preferredMainUnit.version = 0;
                }

                queueDescendantVersionReset(child);
                flushQueuedDescendantVersionResetsForCurrentDepth();
                child->updateSize();
            }
        }

        // Flex base size for auto/content should come from intrinsic size on
        // the main axis. Force a fit-content pass here so stale block-sized
        // widths/heights don't leak into row/column wrapping behavior.
        if ((item.basis.type == FlexBasis::Type::Auto || item.basis.type == FlexBasis::Type::Content)
            && (preferredMainUnit.unit == Unit::Auto || preferredMainUnit.unit == Unit::FitContent)) {
            // Only restore `unit` — intentionally leave pendingUpdate=true and
            // version=0 so subsequent passes pick up the measured size.
            const Unit originalUnit = preferredMainUnit.unit;
            preferredMainUnit.pendingUpdate = true;
            preferredMainUnit.version = 0;
            preferredMainUnit.unit = Unit::FitContent;
            child->updateSize();
            preferredMainUnit.unit = originalUnit;
        }

        auto preferredMainSize = getUnitValue(preferredMainUnit, innerMainSize);
        if (preferredMainSize < 0.0)
            preferredMainSize = (horizontal ? child->getWidth() : child->getHeight()) + borderMain;

        auto preferredCrossSize = getUnitValue(preferredCrossUnit, innerCrossSize);
        if (preferredCrossSize < 0.0)
            preferredCrossSize = (horizontal ? child->getHeight() : child->getWidth()) + borderCross;

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
        item.contentMainSize = preferredMainSize;
        item.minMain = horizontal ? child->getMinWidth() : child->getMinHeight();
        double maxMain = horizontal ? child->getMaxWidth() : child->getMaxHeight();
        item.maxMain = availableLimit(maxMain);
        item.mainSize = clampToLimits(item.mainSize, item.minMain, item.maxMain);

        item.crossSize = preferredCrossSize;
        const bool crossUnitAutoLike = (preferredCrossUnit.unit == Unit::Auto || preferredCrossUnit.unit == Unit::FitContent);
        bool cssCrossAutoLike = false;
        if (const auto node = child->getHtmlNode()) {
            const std::string cssCross = node->getStyle(horizontal ? "height" : "width");
            cssCrossAutoLike = cssCross.empty() || cssCross == "auto";
        }
        item.crossSizeAuto = crossUnitAutoLike || cssCrossAutoLike;
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
            item.autoMainStart = child->isMarginTopAuto();
            item.autoMainEnd = child->isMarginBottomAuto();
        }

        if (mainReverse) {
            std::swap(item.marginMainStart, item.marginMainEnd);
            std::swap(item.autoMainStart, item.autoMainEnd);
        }

        items.push_back(item);
    }

    if (items.empty()) {
        for (const auto& childPtr : container.getChildrenRef()) {
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

    const auto& containerCrossUnit = (mainAxis == Axis::Horizontal) ? container.getHeightHtml() : container.getWidthHtml();
    bool crossAuto = axisUsesContentWhenAuto(style.display, crossAxisForMain(mainAxis), containerCrossUnit);
    if (isFlexItemInParent && containerCrossSize > 0)
        crossAuto = false;

    if (crossAuto) {
        double resolvedInnerCross = contentCross;
        if (mainAxis == Axis::Horizontal) {
            const int minH = container.getMinHeight();
            const int maxH = container.getMaxHeight();
            if (minH > 0) {
                const double minInner = std::max(0, minH - paddingCrossStart - paddingCrossEnd);
                resolvedInnerCross = std::max(resolvedInnerCross, minInner);
            }
            if (maxH > 0) {
                const double maxInner = std::max(0, maxH - paddingCrossStart - paddingCrossEnd);
                resolvedInnerCross = std::min(resolvedInnerCross, maxInner);
            }
        } else {
            const int minW = container.getMinWidth();
            const int maxW = container.getMaxWidth();
            if (minW > 0) {
                const double minInner = std::max(0, minW - paddingCrossStart - paddingCrossEnd);
                resolvedInnerCross = std::max(resolvedInnerCross, minInner);
            }
            if (maxW > 0) {
                const double maxInner = std::max(0, maxW - paddingCrossStart - paddingCrossEnd);
                resolvedInnerCross = std::min(resolvedInnerCross, maxInner);
            }
        }
        innerCrossSize = std::max(0.0, resolvedInnerCross);
    }

    // Single-line flex containers ignore align-content; their line cross-size
    // must match the container's definite inner cross-size. This prevents
    // content-sized children from inflating the line on the cross axis.
    if (!crossAuto && lines.size() == 1)
        lines[0].crossSize = std::max(0.0, innerCrossSize);

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

        double availableMain = innerMainSize;
        if (mainAuto) {
            availableMain = std::max(totalOuter, minInnerMainConstraint);
            availableMain = std::min(availableMain, maxInnerMainConstraint);
        }
        double freeSpace = availableMain - totalOuter;

        // When main axis is auto-sized, apply the automatic minimum floor first
        // (CSS automatic minimum size for flex items).
        if (mainAuto) {
            for (auto* item : lineItems) {
                if (item->mainSize < item->contentMainSize)
                    item->mainSize = clampToLimits(item->contentMainSize, item->minMain, item->maxMain);
            }

            totalOuter = 0.0;
            for (size_t j = 0; j < line.itemIndices.size(); ++j) {
                const auto& item = items[line.itemIndices[j]];
                totalOuter += item.marginMainStart + item.mainSize + item.marginMainEnd;
                if (j + 1 < line.itemIndices.size())
                    totalOuter += mainGap;
            }
            availableMain = std::max(totalOuter, minInnerMainConstraint);
            availableMain = std::min(availableMain, maxInnerMainConstraint);
            freeSpace = availableMain - totalOuter;
        }

        distributeAutoMarginsAndSpace(lineItems, autoMarginCount, freeSpace);

        totalOuter = 0.0;
        for (size_t j = 0; j < line.itemIndices.size(); ++j) {
            const auto& item = items[line.itemIndices[j]];
            totalOuter += item.marginMainStart + item.mainSize + item.marginMainEnd;
            if (j + 1 < line.itemIndices.size())
                totalOuter += mainGap;
        }
        freeSpace = availableMain - totalOuter;
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
            // In CSS row-reverse/column-reverse, the first item in DOM order
            // is placed at the main-end edge (right/bottom). Iterate in
            // forward order so the first item ends up at the right/bottom.
            double cursor = availableMain - leadingSpace;
            for (size_t idx = 0; idx < count; ++idx) {
                auto& item = items[line.itemIndices[idx]];
                cursor -= item.marginMainStart;
                cursor -= item.mainSize;
                item.mainPos = cursor;
                cursor -= item.marginMainEnd;
                if (idx + 1 < count)
                    cursor -= betweenSpacing;
            }
        }
    }

    // When main axis is auto-sized, set innerMainSize to content so
    // positioning and container sizing work correctly.
    if (mainAuto) {
        double contentMain = 0.0;
        for (const auto& line : lines)
            contentMain = maxDouble(contentMain, line.mainSize);
        innerMainSize = contentMain;
    }

    // CSS flex spec step 7: hypothetical cross-size.
    // After main-axis distribution, item widths may differ from the initial
    // measurement. Text wrapping depends on width, so cross-sizes (heights)
    // must be recomputed. Set the final width on each item and propagate
    // to children so text re-wraps, then read the new height.
    if (mainAxis == Axis::Horizontal) {
        std::vector<bool> step7WidthChanged(items.size(), false);
        for (size_t i = 0; i < items.size(); ++i) {
            auto& item = items[i];
            if (!item.widget || !item.crossSizeAuto)
                continue;
            const int bL = item.widget->getBorderLeftWidth();
            const int bR = item.widget->getBorderRightWidth();

            const int targetWidth = std::max(0, roundi(item.mainSize) - bL - bR);
            const bool widthChanged = item.widget->getWidth() != targetWidth;
            step7WidthChanged[i] = widthChanged;
            if (widthChanged) {
                item.widget->setWidth_px(targetWidth);
                queueDescendantVersionReset(item.widget);
            }
        }

        flushQueuedDescendantVersionResetsForCurrentDepth();

        for (size_t i = 0; i < items.size(); ++i) {
            auto& item = items[i];
            if (!item.widget || !item.crossSizeAuto)
                continue;
            const int bT = item.widget->getBorderTopWidth();
            const int bB = item.widget->getBorderBottomWidth();
            const bool widthChanged = step7WidthChanged[i];
            const auto itemDisplay = item.widget->getDisplay();
            if (itemDisplay == DisplayType::Flex || itemDisplay == DisplayType::InlineFlex) {
                // Nested flex container (e.g. column-flex card): run its
                // own layout so it computes its content height via mainAuto.
                // Temporarily mark cross-axis (width) as non-pending so the
                // nested layoutFlex doesn't override the parent-assigned width.
                auto& crossUnit = (mainAxis == Axis::Horizontal)
                    ? item.widget->getWidthHtml() : item.widget->getHeightHtml();
                // Only save/restore pendingUpdate — layoutFlex may modify
                // value/valueCalculed on crossUnit, and those changes must persist.
                if (widthChanged || item.widget->getHeight() <= 0) {
                    const bool origPending = crossUnit.pendingUpdate;
                    crossUnit.pendingUpdate = false;
                    layoutFlex(*item.widget);
                    crossUnit.pendingUpdate = origPending;
                }
            } else {
                // Width was assigned directly in this pass. Reflow this item
                // immediately so wrapped text updates its own height before we
                // read it for line cross-size calculations.
                if (widthChanged || item.widget->getHeight() <= 0) {
                    item.widget->updateText();
                    for (const auto& child : item.widget->getChildrenRef())
                        child->updateSize();
                }
            }

            double newCross = item.widget->getHeight() + bT + bB;
            item.crossSize = newCross;
            item.finalCrossSize = clampToLimits(newCross, item.minCross, item.maxCross);
        }

        // Recompute line cross-sizes with updated item heights
        for (auto& line : lines) {
            double lineCross = 0.0;
            for (size_t idx : line.itemIndices) {
                auto& item = items[idx];
                const double cross = item.finalCrossSize + item.marginCrossStart + item.marginCrossEnd;
                lineCross = maxDouble(lineCross, cross);
            }
            line.crossSize = lineCross;
        }
    }

    // Step 7 recomputes line cross-sizes from the items' final dimensions, so
    // re-apply the single-line definite cross-size override before align-content.
    if (!crossAuto && lines.size() == 1)
        lines[0].crossSize = std::max(0.0, innerCrossSize);

    // contentCross must reflect the final per-line cross sizes (after item
    // width assignment and text reflow), otherwise auto cross-size containers
    // can end up shorter than wrapped content.
    contentCross = 0.0;
    for (size_t i = 0; i < lines.size(); ++i) {
        contentCross += lines[i].crossSize;
        if (i + 1 < lines.size())
            contentCross += crossGap;
    }

    double totalCross = contentCross;

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

            if (align == AlignSelf::Stretch && item.crossSizeAuto) {
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

    const int containerX = container.getX();
    const int containerY = container.getY();

    for (auto& item : items) {
        if (!item.widget)
            continue;

        // Subtract border widths: the flex algorithm uses border-box sizes
        // internally, but OTC's setRect expects the rect WITHOUT borders
        // (borders are drawn inside/on-top of the rect).
        const int bL = item.widget->getBorderLeftWidth();
        const int bR = item.widget->getBorderRightWidth();
        const int bT = item.widget->getBorderTopWidth();
        const int bB = item.widget->getBorderBottomWidth();

        const int width = (mainAxis == Axis::Horizontal)
            ? std::max(0, roundi(item.mainSize) - bL - bR)
            : std::max(0, roundi(item.finalCrossSize) - bL - bR);
        const int height = (mainAxis == Axis::Horizontal)
            ? std::max(0, roundi(item.finalCrossSize) - bT - bB)
            : std::max(0, roundi(item.mainSize) - bT - bB);

        const int x = containerX + container.getPaddingLeft() + ((mainAxis == Axis::Horizontal) ? roundi(item.mainPos) : roundi(item.crossPos));
        const int y = containerY + container.getPaddingTop() + ((mainAxis == Axis::Horizontal) ? roundi(item.crossPos) : roundi(item.mainPos));

        item.rectChanged = item.widget->setRect(Rect(Point(x, y), Size(width, height)));
    }

    bool containerSizeChanged = false;

    if (mainAuto) {
        const double totalMainWithPadding = innerMainSize + paddingStart + paddingEnd;
        int desired = std::max(0, roundi(totalMainWithPadding));
        if (mainAxis == Axis::Horizontal) {
            const int minW = container.getMinWidth();
            const int maxW = container.getMaxWidth();
            if (minW >= 0)
                desired = std::max(desired, minW);
            if (maxW > 0)
                desired = std::min(desired, maxW);
            if (container.getWidth() != desired) {
                container.setWidth_px(desired);
                containerSizeChanged = true;
            }
        } else {
            const int minH = container.getMinHeight();
            const int maxH = container.getMaxHeight();
            if (minH >= 0)
                desired = std::max(desired, minH);
            if (maxH > 0)
                desired = std::min(desired, maxH);
            if (container.getHeight() != desired) {
                container.setHeight_px(desired);
                containerSizeChanged = true;
            }
        }
    }

    if (crossAuto) {
        const double totalCrossWithPadding = contentCross + paddingCrossStart + paddingCrossEnd;
        int desired = std::max(0, roundi(totalCrossWithPadding));
        if (mainAxis == Axis::Horizontal) {
            const int minH = container.getMinHeight();
            const int maxH = container.getMaxHeight();
            if (minH >= 0)
                desired = std::max(desired, minH);
            if (maxH > 0)
                desired = std::min(desired, maxH);
            if (container.getHeight() != desired) {
                container.setHeight_px(desired);
                containerSizeChanged = true;
            }
        } else {
            const int minW = container.getMinWidth();
            const int maxW = container.getMaxWidth();
            if (minW >= 0)
                desired = std::max(desired, minW);
            if (maxW > 0)
                desired = std::min(desired, maxW);
            if (container.getWidth() != desired) {
                container.setWidth_px(desired);
                containerSizeChanged = true;
            }
        }
    }

    // Propagate size changes from this flex container to auto/fit-content parents.
    if (containerSizeChanged && container.getPositionType() != PositionType::Absolute) {
        if (const auto& parent = container.getParent()) {
            auto& parentW = parent->m_width;
            if (parentW.unit == Unit::Auto || parentW.unit == Unit::FitContent) {
                parentW.pendingUpdate = true;
                parentW.version = 0;
            }

            auto& parentH = parent->m_height;
            if (parentH.unit == Unit::Auto || parentH.unit == Unit::FitContent) {
                parentH.pendingUpdate = true;
                parentH.version = 0;
            }

            parent->scheduleHtmlTask(PropUpdateSize);
        }
    }

    // Post-layout: flex items now have their final sizes from setRect.
    // Queue recursive resets so descendants are batched and re-measured once
    // at the end of this flex layout pass.
    for (auto& item : items) {
        if (!item.widget || item.widget->getChildrenRef().empty() || !item.rectChanged)
            continue;
        queueDescendantVersionReset(item.widget);
    }

    flushQueuedDescendantVersionResetsForCurrentDepth();

    for (auto& item : items) {
        if (!item.widget || item.widget->getChildrenRef().empty() || !item.rectChanged)
            continue;
        const auto d = item.widget->getDisplay();
        if (d == DisplayType::Flex || d == DisplayType::InlineFlex) {
            // Force definite pixel sizes while running nested layoutFlex.
            // Just clearing pending flags is not enough because Auto/FitContent
            // units would still make nested containers re-content-size and
            // ignore the size assigned by the parent flex item.
            auto& wUnit = item.widget->getWidthHtml();
            auto& hUnit = item.widget->getHeightHtml();
            SizeUnitGuard wGuard(wUnit);
            SizeUnitGuard hGuard(hUnit);

            wUnit.unit = Unit::Px;
            wUnit.value = clampToPositiveSize(item.widget->getWidth());
            wUnit.valueCalculed = wUnit.value;
            wUnit.pendingUpdate = false;

            hUnit.unit = Unit::Px;
            hUnit.value = clampToPositiveSize(item.widget->getHeight());
            hUnit.valueCalculed = hUnit.value;
            hUnit.pendingUpdate = false;

            layoutFlex(*item.widget);
        } else {
            for (const auto& child : item.widget->getChildrenRef())
                child->updateSize();
        }
    }

    for (const auto& childPtr : container.getChildrenRef()) {
        if (childPtr && childPtr->getPositionType() == PositionType::Absolute)
            childPtr->updateSize();
    }
}
