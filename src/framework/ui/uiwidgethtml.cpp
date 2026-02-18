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
#include "uimanager.h"
#include "uiwidget.h"
#include <framework/core/eventdispatcher.h>
#include <framework/html/htmlmanager.h>
#include <framework/html/htmlnode.h>

namespace {
    inline uint32_t SIZE_VERSION_COUNTER = 1;
    inline bool pendingFlush = false;
    inline std::vector<UIWidgetPtr> pendingWidgets;

    constexpr bool isInlineLike(DisplayType d) noexcept {
        switch (d) {
            case DisplayType::Inline:
            case DisplayType::InlineBlock:
            case DisplayType::InlineFlex:
            case DisplayType::InlineGrid: return true;
            default: return false;
        }
    }
    constexpr bool isFlexContainer(DisplayType d) noexcept {
        return d == DisplayType::Flex || d == DisplayType::InlineFlex;
    }
    constexpr bool isGridContainer(DisplayType d) noexcept {
        return d == DisplayType::Grid || d == DisplayType::InlineGrid;
    }

    constexpr bool isTableContainer(DisplayType d) {
        return d == DisplayType::Table
            || d == DisplayType::TableRowGroup
            || d == DisplayType::TableHeaderGroup
            || d == DisplayType::TableFooterGroup
            || d == DisplayType::TableRow;
    }

    constexpr bool isTableBox(DisplayType d) noexcept {
        return isTableContainer(d)
            || d == DisplayType::TableCell
            || d == DisplayType::TableColumnGroup
            || d == DisplayType::TableColumn
            || d == DisplayType::TableCaption;
    }

    constexpr bool breakLine(DisplayType d) noexcept {
        switch (d) {
            case DisplayType::Block:
            case DisplayType::Flex:
            case DisplayType::Grid:
            case DisplayType::ListItem:
            case DisplayType::Table:
            case DisplayType::TableCaption:
            case DisplayType::TableHeaderGroup:
            case DisplayType::TableRowGroup:
            case DisplayType::TableFooterGroup:
            case DisplayType::TableRow:
                return true;
            default:
                return false;
        }
    }

    static inline bool widthAutoFillsContainingBlock(DisplayType d) {
        switch (d) {
            case DisplayType::Block:
            case DisplayType::ListItem:
            case DisplayType::Flex:
            case DisplayType::Grid:
                return true;

            case DisplayType::InlineBlock:
            case DisplayType::InlineFlex:
            case DisplayType::InlineGrid:
            case DisplayType::Inline:
            case DisplayType::Contents:
            case DisplayType::Table:
            case DisplayType::TableCaption:
            case DisplayType::TableRowGroup:
            case DisplayType::TableHeaderGroup:
            case DisplayType::TableFooterGroup:
            case DisplayType::TableRow:
            case DisplayType::TableCell:
            case DisplayType::TableColumn:
            case DisplayType::TableColumnGroup:
            case DisplayType::None:
            case DisplayType::Initial:
            case DisplayType::Inherit:
            case DisplayType::RunIn:
                return false;
        }
        return false;
    }

    constexpr FloatType mapLogicalFloat(FloatType f) noexcept {
        if (f == FloatType::InlineStart) return FloatType::Left;
        if (f == FloatType::InlineEnd)   return FloatType::Right;
        return f;
    }
    constexpr ClearType mapLogicalClear(ClearType c) noexcept {
        if (c == ClearType::InlineStart) return ClearType::Left;
        if (c == ClearType::InlineEnd)   return ClearType::Right;
        return c;
    }

    struct FlowContext
    {
        UIWidget* lastNormalWidget = nullptr;
        UIWidget* lastLeftFloat = nullptr;
        UIWidget* lastRightFloat = nullptr;
        UIWidget* lastFloatOnSameSide = nullptr;

        int lastNormalIndex = -1;
        int lastLeftIndex = -1;
        int lastRightIndex = -1;
        bool hasLeftFloat = false;
        bool hasRightFloat = false;

        int lineWidthBefore = 0;
        UIWidget* tallestInlineWidget = nullptr;
    };

    inline UIWidget* chooseLowerWidget(UIWidget* a, UIWidget* b) noexcept {
        if (!a) return b;
        if (!b) return a;
        const auto ay = a->getRect().bottomLeft().y;
        const auto by = b->getRect().bottomLeft().y;
        return (by > ay) ? b : a;
    }

    inline bool skipInFlow(UIWidget* c) noexcept {
        return c->getDisplay() == DisplayType::None
            || !c->isAnchorable()
            || c->getPositionType() == PositionType::Absolute;
    }

    [[nodiscard]] inline int computeOuterSize(UIWidget* w, bool horizontal) noexcept {
        const int base = horizontal ? w->getWidth() : w->getHeight();
        if (horizontal)
            return base + w->getMarginLeft() + w->getMarginRight() + w->getPaddingLeft() + w->getPaddingRight();
        return base + w->getMarginTop() + w->getMarginBottom() + w->getPaddingTop() + w->getPaddingBottom();
    }
    [[nodiscard]] inline int computeOuterWidth(UIWidget* w) noexcept { return computeOuterSize(w, true); }
    [[nodiscard]] inline int computeOuterHeight(UIWidget* w) noexcept { return computeOuterSize(w, false); }

    [[nodiscard]] inline int getParentInnerWidth(UIWidget* p) noexcept {
        const int pw = p->getWidth();
        return std::max<int>(0, pw - p->getPaddingLeft() - p->getPaddingRight());
    }

    [[nodiscard]] constexpr bool endsWith(std::string_view str, std::string_view suffix) noexcept {
        return str.size() >= suffix.size() && str.substr(str.size() - suffix.size()) == suffix;
    }

    [[nodiscard]] constexpr Unit detectUnit(std::string_view s) noexcept {
        if (s == "auto") return Unit::Auto;
        if (s == "fit-content") return Unit::FitContent;
        if (endsWith(s, "px")) return Unit::Px;
        if (endsWith(s, "em")) return Unit::Em;
        if (endsWith(s, "%"))  return Unit::Percent;
        return Unit::Px;
    }

    [[nodiscard]] constexpr std::string_view numericPart(std::string_view s) noexcept {
        if (endsWith(s, "px") || endsWith(s, "em")) return s.substr(0, s.size() - 2);
        if (endsWith(s, "%")) return s.substr(0, s.size() - 1);
        return s;
    }

    static FlowContext computeFlowContext(UIWidget* self, DisplayType /*parentDisplay*/, FloatType effFloat) {
        FlowContext ctx;
        if (self->getPositionType() == PositionType::Absolute) return ctx;
        auto* parent = self->getParent().get();
        if (!parent) return ctx;

        int runWidth = 0;
        int lastTop = INT_MIN;
        UIWidget* tallest = nullptr;
        int tallestH = -1;

        int i = 0;
        for (const auto& sp : parent->getChildren()) {
            UIWidget* c = sp.get();
            if (c == self) break;
            if (skipInFlow(c)) { ++i; continue; }

            const FloatType cf = mapLogicalFloat(c->getFloat());
            if (cf == FloatType::None) {
                ctx.lastNormalWidget = c; ctx.lastNormalIndex = i;
            } else if (cf == FloatType::Left) {
                ctx.lastLeftFloat = c; ctx.lastLeftIndex = i;
            } else if (cf == FloatType::Right) {
                ctx.lastRightFloat = c; ctx.lastRightIndex = i;
            }
            if (cf == effFloat) ctx.lastFloatOnSameSide = c;

            if (cf == FloatType::None) {
                if (breakLine(c->getDisplay())) {
                    runWidth = 0; lastTop = INT_MIN; tallest = nullptr; tallestH = -1;
                } else if (isInlineLike(c->getDisplay())) {
                    const int ct = c->getRect().topLeft().y;
                    if (lastTop == INT_MIN) lastTop = ct;
                    if (ct > lastTop) { runWidth = 0; lastTop = ct; tallest = nullptr; tallestH = -1; }
                    const int cw = computeOuterWidth(c);
                    const int ch = computeOuterHeight(c);
                    runWidth += cw;
                    if (ch > tallestH) { tallestH = ch; tallest = c; }
                } else {
                    runWidth = 0; lastTop = INT_MIN; tallest = nullptr; tallestH = -1;
                }
            }
            ++i;
        }

        ctx.hasLeftFloat = (ctx.lastLeftFloat != nullptr);
        ctx.hasRightFloat = (ctx.lastRightFloat != nullptr);
        ctx.lineWidthBefore = runWidth;
        ctx.tallestInlineWidget = tallest;
        return ctx;
    }

    bool applyClear(UIWidget* self, const FlowContext& ctx, ClearType effClear) {
        if (effClear == ClearType::None) return false;

        UIWidget* target = nullptr;
        if (effClear == ClearType::Both)      target = chooseLowerWidget(ctx.lastLeftFloat, ctx.lastRightFloat);
        else if (effClear == ClearType::Left) target = ctx.lastLeftFloat;
        else                                  target = ctx.lastRightFloat;

        if (!target)
            return false;

        self->addAnchor(Fw::AnchorTop, target->getId().c_str(), Fw::AnchorBottom);
        return true;
    }

    static inline void applyFloat(UIWidget* self, const FlowContext& ctx, FloatType effFloat, bool topCleared) {
        const bool isLeftF = (effFloat == FloatType::Left);

        const bool blockAfterLeftSameLine =
            (!isLeftF)
            && ctx.lastNormalWidget
            && (ctx.lastNormalIndex > ctx.lastLeftIndex)
            && (ctx.lastLeftIndex >= 0)
            && !isInlineLike(ctx.lastNormalWidget->getDisplay());

        if (ctx.lastFloatOnSameSide) {
            if (isLeftF) self->addAnchor(Fw::AnchorLeft, ctx.lastFloatOnSameSide->getId().c_str(), Fw::AnchorRight);
            else         self->addAnchor(Fw::AnchorRight, ctx.lastFloatOnSameSide->getId().c_str(), Fw::AnchorLeft);
            if (!topCleared) self->addAnchor(Fw::AnchorTop, ctx.lastFloatOnSameSide->getId().c_str(), Fw::AnchorTop);
        } else if (!isLeftF && blockAfterLeftSameLine) {
            self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
            if (!topCleared && ctx.lastNormalWidget)
                self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorTop);
        } else {
            if (isLeftF) self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            else         self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
            if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        }
    }

    static inline void applyFlex(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        if (!ctx.lastNormalWidget) {
            self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        } else {
            self->addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
            if (!topCleared) self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorTop);
        }
    }

    static inline void applyGridOrTable(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        if (!ctx.lastNormalWidget) {
            self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        } else {
            self->addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
            if (!topCleared)
                self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorTop);
        }
    }

    static inline void applyTableChild(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);

        if (!ctx.lastNormalWidget) {
            self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        } else if (!topCleared) {
            self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
        }
    }

    static inline void applyTableRowGroupChild(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);

        if (!ctx.lastNormalWidget) {
            self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        } else if (!topCleared) {
            self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
        }
    }

    static inline void applyTableRowChild(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);

        if (!ctx.lastNormalWidget) {
            self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        } else {
            self->addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
        }
    }

    static inline void applyTableCaption(UIWidget* self, const FlowContext&, bool) {
        self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
        self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
    }

    static inline void applyTableColumnLike(UIWidget* self) {
        self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        self->addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
    }

    static inline void applyInline(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        if (auto* parent = self->getParent().get()) {
            const int innerW = getParentInnerWidth(parent);
            if (innerW > 0) {
                const int nextRun = ctx.lineWidthBefore + computeOuterWidth(self);
                if (nextRun > innerW) {
                    self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                    if (!topCleared) {
                        if (ctx.lastNormalWidget) self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
                        else                      self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                    }
                    return;
                }
            }
        }

        if (!ctx.lastNormalWidget) {
            if (ctx.hasLeftFloat) {
                self->addAnchor(Fw::AnchorLeft, ctx.lastLeftFloat->getId().c_str(), Fw::AnchorRight);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            } else if (ctx.hasRightFloat) {
                self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            } else {
                self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft); self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            }
        } else {
            if (isInlineLike(ctx.lastNormalWidget->getDisplay())) {
                self->addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorTop);
            } else {
                self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
            }
        }
    }

    static inline void applyBlock(UIWidget* self, const FlowContext& ctx, bool topCleared) {
        // Horizontal centering for block elements:
        // (a) CSS standard: margin-left: auto + margin-right: auto
        // (b) Legacy <center> behavior: parent has text-align: center AND this block has an
        //     explicit pixel width (not auto-fill). This covers <table width="N"> inside <center>.
        //     Auto-width blocks like <p> are intentionally excluded — they fill the parent and
        //     rely on text-align: center cascading to their inline children instead.
        const bool marginAutoCenter = self->isMarginLeftAuto() && self->isMarginRightAuto();
        const bool centerTagCenter = !marginAutoCenter
            && self->getParent()
            && self->getParent()->getTextAlign() == Fw::AlignCenter
            && self->getWidthHtml().unit == Unit::Px;
        const bool centerH = marginAutoCenter || centerTagCenter;

        if (ctx.lastNormalWidget && isInlineLike(ctx.lastNormalWidget->getDisplay())) {
            if (auto* tallest = ctx.tallestInlineWidget) {
                self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                if (!topCleared)
                    self->addAnchor(Fw::AnchorTop, tallest->getId().c_str(), Fw::AnchorBottom);
                return;
            }
        }

        if (centerH) {
            // Center horizontally; stack vertically as normal blocks
            self->addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
            if (!topCleared) {
                if (!ctx.lastNormalWidget)
                    self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                else
                    self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
            }
            return;
        }

        if (!ctx.lastNormalWidget) {
            if (ctx.hasLeftFloat) {
                self->addAnchor(Fw::AnchorLeft, ctx.lastLeftFloat->getId().c_str(), Fw::AnchorRight);
                self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            } else if (ctx.hasRightFloat) {
                self->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                if (!topCleared) self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            } else {
                self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft); self->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            }
        } else {
            self->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            if (!topCleared) self->addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
        }
    }

    [[nodiscard]] inline Fw::AlignmentFlag parseTextAlign(std::string_view s) {
        if (s == "center") return Fw::AlignCenter;
        if (s == "right")  return Fw::AlignRight;
        return Fw::AlignLeft;
    }

    enum class VAlign { Top, Middle, Bottom };
    [[nodiscard]] inline VAlign parseVerticalAlign(std::string_view s) {
        if (s == "middle" || s == "center") return VAlign::Middle;
        if (s == "bottom") return VAlign::Bottom;
        return VAlign::Top;
    }

    [[nodiscard]] inline std::string resolveCascadedStyle(UIWidget* w, const char* key) {
        for (auto cur = w; cur; ) {
            if (auto node = cur->getHtmlNode()) {
                const auto val = node->getStyle(key);
                if (!val.empty()) return val;
            }
            const auto p = cur->getParent();
            cur = p ? p.get() : nullptr;
            if (!cur || !isTableBox(cur->getDisplay())) break;
        }
        return {};
    }

    [[nodiscard]] inline Fw::AlignmentFlag resolveCellTextAlign(UIWidget* cellOrContent) {
        const auto s = resolveCascadedStyle(cellOrContent, "text-align");
        return s.empty() ? Fw::AlignLeft : parseTextAlign(s);
    }

    [[nodiscard]] inline VAlign resolveCellVerticalAlign(UIWidget* cellOrContent) {
        const auto s = resolveCascadedStyle(cellOrContent, "vertical-align");
        if (s.empty()) return VAlign::Top;
        return parseVerticalAlign(s);
    }

    static inline void anchorHorizontalInCell(UIWidget* content, Fw::AlignmentFlag ta) {
        if (ta == Fw::AlignCenter) {
            content->addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
        } else if (ta == Fw::AlignRight) {
            content->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
        } else {
            content->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        }
    }

    static inline void anchorVerticalInCell(UIWidget* content, VAlign va) {
        switch (va) {
            case VAlign::Middle:
                content->addAnchor(Fw::AnchorVerticalCenter, "parent", Fw::AnchorVerticalCenter);
                break;
            case VAlign::Bottom:
                content->addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
                break;
            case VAlign::Top:
            default:
                content->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                break;
        }
    }

    static inline bool isRowGroup(DisplayType d) noexcept {
        return d == DisplayType::TableHeaderGroup
            || d == DisplayType::TableRowGroup
            || d == DisplayType::TableFooterGroup;
    }
    static inline bool isRow(DisplayType d) noexcept { return d == DisplayType::TableRow; }
    static inline bool isCell(DisplayType d) noexcept { return d == DisplayType::TableCell; }

    static int detectColumnCount(UIWidget* table) {
        int cols = 0;
        for (const auto& ch : table->getChildren()) {
            UIWidget* g = ch.get();
            if (isRowGroup(g->getDisplay())) {
                for (const auto& rr : g->getChildren()) {
                    UIWidget* r = rr.get();
                    if (!isRow(r->getDisplay())) continue;
                    int c = 0;
                    for (const auto& cc : r->getChildren())
                        if (isCell(cc->getDisplay())) ++c;
                    if (c > cols) cols = c;
                }
            } else if (isRow(g->getDisplay())) {
                int c = 0;
                for (const auto& cc : g->getChildren())
                    if (isCell(cc->getDisplay())) ++c;
                if (c > cols) cols = c;
            }
        }
        return cols;
    }

    static void computeAndApplyTableColumns(UIWidget* table) {
        const int innerW = getParentInnerWidth(table);
        if (innerW <= 0) return;

        const int cols = detectColumnCount(table);
        if (cols <= 0) return;

        std::vector<int> fixed(cols, -1);
        std::vector<int> perc(cols, 0);
        std::vector<int> widths(cols, 0);

        auto scanRow = [&](UIWidget* r) {
            int j = 0;
            for (const auto& cc : r->getChildren()) {
                UIWidget* cell = cc.get();
                if (!isCell(cell->getDisplay())) continue;
                auto& wSpec = cell->getWidthHtml();

                if (wSpec.unit == Unit::Px && wSpec.value > 0) {
                    fixed[j] = std::max<int>(fixed[j], wSpec.value + cell->getPaddingLeft() + cell->getPaddingRight());
                } else if (wSpec.unit == Unit::Percent && wSpec.value > 0) {
                    perc[j] = std::max<int>(perc[j], wSpec.value);
                }
                if (++j >= cols) break;
            }
        };

        for (const auto& ch : table->getChildren()) {
            UIWidget* g = ch.get();
            if (isRowGroup(g->getDisplay())) {
                for (const auto& rr : g->getChildren())
                    if (isRow(rr->getDisplay())) scanRow(rr.get());
            } else if (isRow(g->getDisplay())) scanRow(g);
        }

        int remaining = innerW;
        for (int i = 0; i < cols; ++i) {
            if (fixed[i] > -1) {
                widths[i] = fixed[i];
                remaining -= widths[i];
            }
        }

        for (int i = 0; i < cols; ++i) {
            if (perc[i] > 0 && widths[i] == 0) {
                widths[i] = std::max<int>(0, (innerW * perc[i]) / 100);
                remaining -= widths[i];
            }
        }

        int flexCount = 0;
        for (int i = 0; i < cols; ++i) if (widths[i] == 0) ++flexCount;
        if (flexCount > 0) {
            int each = std::max<int>(0, remaining / flexCount);
            int leftover = std::max<int>(0, remaining - each * flexCount);
            for (int i = 0; i < cols; ++i) if (widths[i] == 0) {
                widths[i] = each + (leftover > 0 ? 1 : 0);
                if (leftover > 0) --leftover;
            }
            remaining = 0;
        }

        int sum = 0; for (int w : widths) sum += w;
        if (sum > innerW && sum > 0) {
            double k = (double)innerW / (double)sum;
            int acc = 0;
            for (int i = 0; i < cols; ++i) {
                widths[i] = std::max<int>(1, (int)std::floor(widths[i] * k));
                acc += widths[i];
            }
            int diff = innerW - acc;
            for (int i = 0; diff > 0 && i < cols; ++i, --diff) ++widths[i];
            for (int i = 0; diff < 0 && i < cols; ++i, ++diff) widths[i] = std::max<int>(1, widths[i] - 1);
        }

        std::function<void(UIWidget*)> applyRow = [&](UIWidget* r) {
            int j = 0;
            for (const auto& cc : r->getChildren()) {
                UIWidget* cell = cc.get();
                if (!isCell(cell->getDisplay())) continue;

                const int totalW = widths[j];
                const int pad = cell->getPaddingLeft() + cell->getPaddingRight();
                cell->setWidth_px(std::max<int>(0, totalW - pad));

                if (++j >= cols) break;
            }
        };

        for (const auto& ch : table->getChildren()) {
            UIWidget* g = ch.get();
            if (isRowGroup(g->getDisplay())) {
                for (const auto& rr : g->getChildren())
                    if (isRow(rr->getDisplay())) applyRow(rr.get());
            } else if (isRow(g->getDisplay())) applyRow(g);
        }
    }

    static inline void updateDimension(UIWidget* widget, int width, int height) {
        bool updateChildren = false;
        auto& wHtml = widget->getWidthHtml();
        auto& hHtml = widget->getHeightHtml();

        if (width > -1 && (wHtml.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER) || wHtml.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER))) {
            if (wHtml.needsUpdate(Unit::Percent))
                width = std::round(width * (wHtml.value / 100.0));

            widget->setWidth_px(width);
            wHtml.applyUpdate(width, SIZE_VERSION_COUNTER);

            updateChildren = true;
        }

        if (height > -1 && hHtml.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER)) {
            height = std::round(height * (hHtml.value / 100.0));
            widget->setHeight_px(height);
            hHtml.applyUpdate(height, SIZE_VERSION_COUNTER);
            updateChildren = true;
        }

        if (updateChildren) {
            for (const auto& child : widget->getChildren()) {
                if (child->getWidthHtml().unit == Unit::Auto ||
                    child->getWidthHtml().unit == Unit::Percent ||
                    child->getHeightHtml().unit == Unit::Percent) {
                    updateDimension(child.get(), width, height);
                }
            }
        }
    }

    static inline void applyFitContentRecursive(UIWidget* w, int& width, int& height) {
        int maxLineWidth = 0, totalHeight = 0, runWidth = 0, runHeight = 0;

        auto flushLine = [&]() {
            if (runWidth > 0 || runHeight > 0) {
                if (runWidth > maxLineWidth) maxLineWidth = runWidth;
                totalHeight += runHeight;
                runWidth = 0;
                runHeight = 0;
            }
        };

        for (auto& childPtr : w->getChildren()) {
            UIWidget* c = childPtr.get();
            if (c->getFloat() != FloatType::None || c->getPositionType() == PositionType::Absolute)
                continue;

            if (c->getHtmlNode() && c->getHtmlNode()->getType() == NodeType::Text)
                c->updateSize();

            int childContentW = c->getWidth();
            int childContentH = c->getHeight();

            const auto& cwSpec = c->getWidthHtml();
            const auto& chSpec = c->getHeightHtml();

            const bool widthExplicit = (childContentW > 0) || (cwSpec.valueCalculed > -1);
            const bool heightExplicit = (childContentH > 0) || (chSpec.valueCalculed > -1);

            const bool widthContentDriven =
                cwSpec.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
                cwSpec.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER) ||
                cwSpec.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

            const bool heightContentDriven =
                chSpec.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
                chSpec.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER) ||
                chSpec.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

            const DisplayType d = c->getDisplay();
            const bool tableLike =
                d == DisplayType::Table || d == DisplayType::TableRowGroup ||
                d == DisplayType::TableHeaderGroup || d == DisplayType::TableFooterGroup ||
                d == DisplayType::TableRow || d == DisplayType::TableCell ||
                d == DisplayType::TableColumnGroup || d == DisplayType::TableColumn ||
                d == DisplayType::TableCaption;

            const bool layoutContentDriven =
                tableLike || d == DisplayType::InlineBlock || d == DisplayType::Inline ||
                d == DisplayType::Flex || d == DisplayType::InlineFlex ||
                d == DisplayType::Grid || d == DisplayType::InlineGrid;

            int subW = 0, subH = 0;
            if ((!widthExplicit || widthContentDriven || layoutContentDriven) ||
                (!heightExplicit || heightContentDriven || layoutContentDriven)) {
                if (!c->getChildren().empty()) {
                    applyFitContentRecursive(c, subW, subH);
                }
            }

            if (childContentW <= 0 && cwSpec.valueCalculed > -1) {
                childContentW = cwSpec.valueCalculed;
            } else if (childContentW <= 0 && cwSpec.valueCalculed < 0) {
                childContentW = subW;
            } else {
                if (subW > 0) childContentW = std::max<int>(childContentW, subW);
            }

            if (childContentH <= 0 && chSpec.valueCalculed > -1) {
                childContentH = chSpec.valueCalculed;
            } else if (childContentH <= 0 && chSpec.valueCalculed < 0) {
                childContentH = subH;
            } else {
                if (subH > 0) childContentH = std::max<int>(childContentH, subH);
            }

            const int childOuterW = std::max<int>(0, childContentW);
            const int childOuterH = std::max<int>(0, childContentH);

            if (breakLine(c->getDisplay())) {
                flushLine();
                if (childOuterW > maxLineWidth) maxLineWidth = childOuterW;
                totalHeight += childOuterH;
            } else {
                runWidth += childOuterW;
                if (childOuterH > runHeight) runHeight = childOuterH;
            }
        }

        flushLine();

        if (maxLineWidth > width) width = maxLineWidth;
        height += totalHeight;

        const bool widthNeedsUpdate =
            w->getWidthHtml().needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
            w->getWidthHtml().needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER) ||
            w->getWidthHtml().needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

        const bool heightNeedsUpdate =
            w->getHeightHtml().needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
            w->getHeightHtml().needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER) ||
            w->getHeightHtml().needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

        if (widthNeedsUpdate) {
            const int paddedW = maxLineWidth + w->getPaddingLeft() + w->getPaddingRight();
            w->setWidth_px(std::max<int>(0, paddedW));
            w->getWidthHtml().applyUpdate(w->getWidth(), SIZE_VERSION_COUNTER);
        }

        if (heightNeedsUpdate) {
            const int paddedH = totalHeight + w->getPaddingTop() + w->getPaddingBottom();
            w->setHeight_px(std::max<int>(0, paddedH));
            w->getHeightHtml().applyUpdate(w->getHeight(), SIZE_VERSION_COUNTER);
        }
    }

    void applyPlacementAnchors(UIWidget* widget)
    {
        if (!widget) return;

        auto align = widget->getPlacement();
        if (align == Fw::AlignNone) return;

        switch (align) {
            case Fw::AlignTopLeft:
                widget->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                widget->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                break;

            case Fw::AlignTopRight:
                widget->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                widget->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                break;

            case Fw::AlignBottomLeft:
                widget->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                widget->addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
                break;

            case Fw::AlignBottomRight:
                widget->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                widget->addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
                break;

            case Fw::AlignLeftCenter:
                widget->addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
                widget->addAnchor(Fw::AnchorVerticalCenter, "parent", Fw::AnchorVerticalCenter);
                break;

            case Fw::AlignRightCenter:
                widget->addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
                widget->addAnchor(Fw::AnchorVerticalCenter, "parent", Fw::AnchorVerticalCenter);
                break;

            case Fw::AlignTopCenter:
                widget->addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
                widget->addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
                break;

            case Fw::AlignBottomCenter:
                widget->addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
                widget->addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
                break;

            case Fw::AlignCenter:
                widget->addAnchor(Fw::AnchorVerticalCenter, "parent", Fw::AnchorVerticalCenter);
                widget->addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
                break;

            default:
                break;
        }
    }
}

void UIWidget::refreshHtml(bool siblingsTo) {
    if (!isOnHtml() || !m_parent)
        return;

    UIWidget* parent_fitWidth = nullptr;
    UIWidget* parent_fitHeight = nullptr;

    auto parent = m_parent.get();
    while (parent && parent->isOnHtml()) {
        if (parent->m_width.unit == Unit::FitContent)
            parent_fitWidth = parent;
        if (parent->m_height.unit == Unit::FitContent)
            parent_fitHeight = parent;

        parent = parent->m_parent.get();
    }

    if (parent_fitWidth)
        parent_fitWidth->applyDimension(true, parent_fitWidth->m_width.unit, parent_fitWidth->m_width.value);

    if (parent_fitHeight)
        parent_fitHeight->applyDimension(false, parent_fitHeight->m_height.unit, parent_fitHeight->m_height.value);

    if (siblingsTo) {
        if (m_parent.get() != g_ui.getRootWidget().get()) {
            for (const auto& child : m_parent->m_children) {
                child->scheduleHtmlTask(PropApplyAnchorAlignment);
            }
        }
    }
}

void UIWidget::setLineHeight(std::string valueStr) {
    stdext::trim(valueStr);
    stdext::tolower(valueStr);

    const std::string_view sv = valueStr;
    const Unit unit = detectUnit(sv);
    int16_t num = stdext::to_number(std::string(numericPart(sv)));
    m_lineHeight = { unit, num, num, true };
}

void UIWidget::applyDimension(bool isWidth, std::string valueStr) {
    stdext::trim(valueStr);
    stdext::tolower(valueStr);

    const std::string_view sv = valueStr;
    const Unit unit = detectUnit(sv);
    int16_t num = stdext::to_number(std::string(numericPart(sv)));
    applyDimension(isWidth, unit, num);
    if (m_htmlNode)
        m_htmlNode->getStyles()["styles"][isWidth ? "width" : "height"] = { valueStr , "" };
}

void UIWidget::applyDimension(bool isWidth, Unit unit, int16_t value) {
    int16_t valueCalculed = -1;

    bool needUpdate = false;

    if (m_positionType == PositionType::Absolute && unit == Unit::Auto) {
        unit = Unit::FitContent;
    }

    switch (unit) {
        case Unit::Auto: {
            if (isWidth && widthAutoFillsContainingBlock(m_displayType)) {
                needUpdate = m_parent != nullptr;
            } else {
                unit = Unit::FitContent;
                needUpdate = true;
            }
            break;
        }
        case Unit::FitContent: {
            needUpdate = true;
            break;
        }
        case Unit::Percent: {
            needUpdate = m_displayType != DisplayType::Inline;
            break;
        }

        case Unit::Em:
        case Unit::Px:
        case Unit::Invalid:
        default: {
            valueCalculed = value;

            if (isWidth) {
                if (isOnHtml())
                    value += getPaddingLeft() + getPaddingRight();
                setWidth_px(value);
            } else {
                if (isOnHtml())
                    value += getPaddingTop() + getPaddingBottom();
                setHeight_px(value);
            }
            break;
        }
    }

    if (isWidth) {
        m_width = { unit , value, valueCalculed, needUpdate };
    } else {
        m_height = { unit , value, valueCalculed, needUpdate };
    }

    if (!isOnHtml())
        return;

    if (needUpdate) {
        scheduleHtmlTask(PropUpdateSize);
    }

    refreshHtml(true);
}

void UIWidget::updateTableLayout()
{
    if (m_displayType != DisplayType::Table)
        return;

    std::vector<UIWidget*> rowGroups;
    std::vector<UIWidget*> rows;
    std::vector<UIWidget*> captions;
    std::unordered_map<UIWidget*, UIWidget*> rowToGroup;

    std::vector<std::pair<UIWidget*, UIWidget*>> stack;
    stack.emplace_back(this, nullptr);

    while (!stack.empty()) {
        const auto [container, currentGroup] = stack.back();
        stack.pop_back();

        for (const auto& childPtr : container->m_children) {
            UIWidget* child = childPtr.get();
            switch (child->m_displayType) {
                case DisplayType::TableRow: {
                    rows.push_back(child);
                    if (currentGroup)
                        rowToGroup.emplace(child, currentGroup);
                    break;
                }
                case DisplayType::TableRowGroup:
                case DisplayType::TableHeaderGroup:
                case DisplayType::TableFooterGroup: {
                    rowGroups.push_back(child);
                    stack.emplace_back(child, child);
                    break;
                }
                case DisplayType::TableCaption: {
                    if (container == this)
                        captions.push_back(child);
                    break;
                }
                default:
                    break;
            }
        }
    }

    if (rows.empty())
        return;

    const int tablePaddingX = m_padding.left + m_padding.right;
    const int tableContentWidth = getWidth() > 0 ? std::max<int>(0, getWidth() - tablePaddingX) : 0;

    struct TableCellInfo
    {
        UIWidget* widget = nullptr;
        std::size_t column = 0;
        std::size_t columnSpan = 1;
        std::size_t rowSpan = 1;
        int requiredOuterWidth = 0;
        bool widthFixed = false;
        int outerHeight = 0;
    };

    constexpr std::size_t kMaxSpan = 1000;

    auto parseSpanValue = [kMaxSpan](const HtmlNodePtr& node, std::string_view primary, std::string_view fallback) -> std::size_t {
        if (!node)
            return 1;

        std::string value = node->getAttr(std::string(primary));
        if (value.empty() && !fallback.empty())
            value = node->getAttr(std::string(fallback));

        if (value.empty())
            return 1;

        const long long parsed = stdext::to_number(value);
        if (parsed <= 0)
            return 1;

        return std::min<std::size_t>(static_cast<std::size_t>(parsed), kMaxSpan);
    };

    std::vector<std::vector<TableCellInfo>> rowCellInfo(rows.size());
    std::vector<std::size_t> rowSpanOccupancy;
    std::size_t columnCount = 0;

    for (std::size_t rowIndex = 0; rowIndex < rows.size(); ++rowIndex) {
        UIWidget* row = rows[rowIndex];
        std::size_t columnIndex = 0;

        auto advanceToNextFreeColumn = [&]() {
            while (columnIndex < rowSpanOccupancy.size() && rowSpanOccupancy[columnIndex] > 0)
                ++columnIndex;
        };

        for (const auto& childPtr : row->m_children) {
            UIWidget* cell = childPtr.get();
            if (cell->m_displayType != DisplayType::TableCell)
                continue;

            advanceToNextFreeColumn();

            const auto& node = cell->getHtmlNode();
            std::size_t colSpan = parseSpanValue(node, "colspan", "");
            std::size_t rowSpan = parseSpanValue(node, "rowspan", "colrows");

            colSpan = std::max<std::size_t>(1, std::min<std::size_t>(colSpan, kMaxSpan));
            rowSpan = std::max<std::size_t>(1, std::min<std::size_t>(rowSpan, kMaxSpan));

            while (true) {
                if (rowSpanOccupancy.size() < columnIndex + colSpan)
                    rowSpanOccupancy.resize(columnIndex + colSpan, 0);

                bool blocked = false;
                for (std::size_t c = 0; c < colSpan; ++c) {
                    if (rowSpanOccupancy[columnIndex + c] > 0) {
                        columnIndex += c + 1;
                        advanceToNextFreeColumn();
                        blocked = true;
                        break;
                    }
                }

                if (!blocked)
                    break;
            }

            columnCount = std::max<std::size_t>(columnCount, columnIndex + colSpan);

            const std::size_t effectiveRowSpan = std::max<std::size_t>(1, std::min<std::size_t>(rowSpan, rows.size() - rowIndex));

            const int marginX = cell->m_margin.left + cell->m_margin.right;
            const int paddingX = cell->m_padding.left + cell->m_padding.right;

            int candidate = cell->getWidth();
            if (candidate < 0 && cell->m_width.valueCalculed > -1)
                candidate = cell->m_width.valueCalculed;

            candidate = std::max<int>(candidate, 0) + marginX + paddingX;

            bool fixedWidth = false;
            if (cell->m_width.unit == Unit::Px) {
                candidate = cell->m_width.value + marginX + paddingX;
                fixedWidth = true;
            } else if (cell->m_width.unit == Unit::Percent && tableContentWidth > 0) {
                candidate = std::lround((tableContentWidth * cell->m_width.value) / 100.0) + marginX + paddingX;
                fixedWidth = true;
            }

            int cellHeight = cell->getHeight();
            if (cellHeight < 0 && cell->m_height.valueCalculed > -1)
                cellHeight = cell->m_height.valueCalculed;
            if (cell->m_height.unit == Unit::Px)
                cellHeight = cell->m_height.value;

            const int outerHeight = std::max<int>(0, cellHeight) + cell->m_padding.top + cell->m_padding.bottom;

            rowCellInfo[rowIndex].push_back(TableCellInfo{
                cell,
                columnIndex,
                colSpan,
                effectiveRowSpan,
                candidate,
                fixedWidth,
                outerHeight,
            });

            const std::size_t occupancyValue = effectiveRowSpan;
            for (std::size_t c = 0; c < colSpan; ++c)
                rowSpanOccupancy[columnIndex + c] = std::max<std::size_t>(rowSpanOccupancy[columnIndex + c], occupancyValue);

            columnIndex += colSpan;
        }

        for (auto& remaining : rowSpanOccupancy) {
            if (remaining > 0)
                --remaining;
        }
    }

    if (columnCount == 0)
        return;

    std::vector<int> columnWidths(columnCount, 0);
    std::vector<bool> columnFixed(columnCount, false);

    for (std::size_t rowIndex = 0; rowIndex < rowCellInfo.size(); ++rowIndex) {
        for (const auto& info : rowCellInfo[rowIndex]) {
            const std::size_t span = std::min<std::size_t>(info.columnSpan, columnCount - info.column);
            if (span == 0)
                continue;

            if (span == 1) {
                columnWidths[info.column] = std::max<int>(columnWidths[info.column], info.requiredOuterWidth);
                if (info.widthFixed)
                    columnFixed[info.column] = true;
            } else {
                const int perColumn = (info.requiredOuterWidth + static_cast<int>(span) - 1) / static_cast<int>(span);
                for (std::size_t c = 0; c < span; ++c) {
                    const std::size_t column = info.column + c;
                    columnWidths[column] = std::max<int>(columnWidths[column], perColumn);
                    if (info.widthFixed)
                        columnFixed[column] = true;
                }
            }
        }
    }

    int currentTotal = 0;
    for (int width : columnWidths)
        currentTotal += width;

    int targetTotal = currentTotal;
    if (tableContentWidth > 0)
        targetTotal = std::max<int>(tableContentWidth, currentTotal);

    if (targetTotal > currentTotal && !columnWidths.empty()) {
        const int delta = targetTotal - currentTotal;
        int expandable = 0;
        for (bool fixed : columnFixed)
            if (!fixed)
                ++expandable;

        const bool noFlexibleColumns = (expandable == 0);
        if (noFlexibleColumns)
            expandable = columnWidths.size();

        int base = delta / expandable;
        int remainder = delta % expandable;

        for (std::size_t i = 0; i < columnWidths.size(); ++i) {
            if (noFlexibleColumns || !columnFixed[i]) {
                columnWidths[i] += base;
                if (remainder > 0) {
                    ++columnWidths[i];
                    --remainder;
                }
            }
        }
    }

    int resolvedContentWidth = 0;
    for (int width : columnWidths)
        resolvedContentWidth += width;

    const int resolvedTableWidth = resolvedContentWidth + tablePaddingX;

    if ((m_width.unit == Unit::Auto || m_width.unit == Unit::FitContent) && resolvedTableWidth > 0) {
        setWidth_px(resolvedContentWidth);
        m_width.applyUpdate(getWidth(), SIZE_VERSION_COUNTER);
    }

    std::unordered_map<UIWidget*, int> groupHeights;
    std::vector<int> rowContentHeights(rows.size(), 0);

    for (std::size_t rowIndex = 0; rowIndex < rows.size(); ++rowIndex) {
        UIWidget* row = rows[rowIndex];

        if ((row->m_width.unit == Unit::Auto || row->m_width.unit == Unit::FitContent || row->m_width.unit == Unit::Percent) && resolvedContentWidth > 0) {
            row->setWidth_px(resolvedContentWidth);
            row->m_width.applyUpdate(row->getWidth(), SIZE_VERSION_COUNTER);
        }

        const auto& cells = rowCellInfo[rowIndex];
        for (const auto& info : cells) {
            UIWidget* cell = info.widget;
            if (!cell)
                continue;

            const std::size_t span = std::min<std::size_t>(info.columnSpan, columnCount - info.column);
            if (span == 0)
                continue;

            int spanWidth = 0;
            for (std::size_t c = 0; c < span; ++c)
                spanWidth += columnWidths[info.column + c];

            const int marginX = cell->m_margin.left + cell->m_margin.right;
            const int paddingX = cell->m_padding.left + cell->m_padding.right;
            const int targetOuterWidth = std::max<int>(spanWidth - marginX, 0);
            const int targetContentWidth = std::max<int>(targetOuterWidth - paddingX, 0);

            if ((cell->m_width.unit == Unit::Auto || cell->m_width.unit == Unit::FitContent || cell->m_width.unit == Unit::Percent) && spanWidth > 0) {
                cell->setWidth_px(targetContentWidth);
                cell->m_width.applyUpdate(cell->getWidth(), SIZE_VERSION_COUNTER);
            }

            int distributedHeight = info.outerHeight;
            if (info.rowSpan > 1)
                distributedHeight = (info.outerHeight + static_cast<int>(info.rowSpan) - 1) / static_cast<int>(info.rowSpan);

            for (std::size_t r = 0; r < info.rowSpan && rowIndex + r < rowContentHeights.size(); ++r)
                rowContentHeights[rowIndex + r] = std::max<int>(rowContentHeights[rowIndex + r], distributedHeight);
        }
    }

    for (std::size_t rowIndex = 0; rowIndex < rows.size(); ++rowIndex) {
        const int tallestInRow = rowContentHeights[rowIndex];
        auto& cells = rowCellInfo[rowIndex];
        for (auto& info : cells) {
            if (!info.widget || tallestInRow <= 0) continue;

            UIWidget* cell = info.widget;
            const int padY = cell->getPaddingTop() + cell->getPaddingBottom();
            const int contentH = std::max<int>(0, tallestInRow - padY);

            if (cell->m_height.unit == Unit::Auto || cell->m_height.unit == Unit::FitContent) {
                cell->setHeight_px(contentH);
                cell->m_height.applyUpdate(cell->getHeight(), SIZE_VERSION_COUNTER);
            }
        }
    }

    for (std::size_t rowIndex = 0; rowIndex < rows.size(); ++rowIndex) {
        UIWidget* row = rows[rowIndex];
        const int rowContentHeight = rowContentHeights[rowIndex];

        if ((row->m_height.unit == Unit::Auto || row->m_height.unit == Unit::FitContent) && rowContentHeight > 0) {
            row->setHeight_px(rowContentHeight);
            row->m_height.applyUpdate(row->getHeight(), SIZE_VERSION_COUNTER);
        }

        int effectiveContentHeight = rowContentHeight;
        if (effectiveContentHeight <= 0) {
            int explicitHeight = row->getHeight();
            if (explicitHeight < 0 && row->m_height.valueCalculed > -1)
                explicitHeight = row->m_height.valueCalculed;
            effectiveContentHeight = std::max<int>(0, explicitHeight);
        }

        const int rowOuterHeight = effectiveContentHeight + row->m_padding.top + row->m_padding.bottom + row->m_margin.top + row->m_margin.bottom;

        if (const auto it = rowToGroup.find(row); it != rowToGroup.end())
            groupHeights[it->second] += rowOuterHeight;
    }

    for (UIWidget* group : rowGroups) {
        if ((group->m_width.unit == Unit::Auto || group->m_width.unit == Unit::FitContent || group->m_width.unit == Unit::Percent) && resolvedContentWidth > 0) {
            group->setWidth_px(resolvedContentWidth);
            group->m_width.applyUpdate(group->getWidth(), SIZE_VERSION_COUNTER);
        }

        const int contentHeight = groupHeights[group];
        if ((group->m_height.unit == Unit::Auto || group->m_height.unit == Unit::FitContent) && contentHeight > 0) {
            group->setHeight_px(contentHeight);
            group->m_height.applyUpdate(group->getHeight(), SIZE_VERSION_COUNTER);
        }
    }

    for (UIWidget* caption : captions) {
        if ((caption->m_width.unit == Unit::Auto || caption->m_width.unit == Unit::FitContent || caption->m_width.unit == Unit::Percent) && resolvedContentWidth > 0) {
            caption->setWidth_px(resolvedContentWidth);
            caption->m_width.applyUpdate(caption->getWidth(), SIZE_VERSION_COUNTER);
        }
    }

    int totalContentHeight = 0;
    for (const auto& childPtr : m_children) {
        UIWidget* child = childPtr.get();
        if (!isTableBox(child->m_displayType))
            continue;

        int childHeight = child->getHeight();
        if (childHeight < 0 && child->m_height.valueCalculed > -1)
            childHeight = child->m_height.valueCalculed;

        const int outerHeight = std::max<int>(0, childHeight) + child->m_padding.top + child->m_padding.bottom + child->m_margin.top + child->m_margin.bottom;
        totalContentHeight += outerHeight;
    }

    if ((m_height.unit == Unit::Auto || m_height.unit == Unit::FitContent) && totalContentHeight > 0) {
        setHeight_px(totalContentHeight);
        m_height.applyUpdate(getHeight(), SIZE_VERSION_COUNTER);
    }
}

void UIWidget::scheduleHtmlTask(FlagProp prop) {
    if (!isOnHtml())
        return;

    bool schedule = false;

    switch (prop) {
        case PropUpdateSize:
        case PropApplyAnchorAlignment:
            schedule = true;
            break;

        default: return;
    }

    if (schedule && !hasProp(PropApplyAnchorAlignment) && !hasProp(PropUpdateSize))
        pendingWidgets.emplace_back(static_self_cast<UIWidget>());

    setProp(prop, true);

    if (pendingFlush)
        return;

    pendingFlush = true;
    g_dispatcher.deferEvent([self = static_self_cast<UIWidget>()] {
        for (const auto& widget : pendingWidgets) {
            if (widget->hasProp(PropUpdateSize)) {
                widget->updateSize();
                widget->setProp(PropUpdateSize, false);
            }

            if (widget->hasProp(PropApplyAnchorAlignment)) {
                widget->applyAnchorAlignment();
                widget->setProp(PropApplyAnchorAlignment, false);
            }
        }

        pendingWidgets.clear();
        pendingFlush = false;
        ++SIZE_VERSION_COUNTER;
    });
}

void UIWidget::setOverflow(OverflowType type) {
    if (m_overflowType == type)
        return;

    m_overflowType = type;

    if (type == OverflowType::Scroll) {
        auto scrollWidget = g_ui.createWidget("VerticalScrollBar", nullptr);
        scrollWidget->setDisplay(m_displayType);
        scrollWidget->setAnchorable(false);
        m_parent->insertChild(getChildIndex() + 1, scrollWidget);
        callLuaField("setVerticalScrollBar", scrollWidget);

        scrollWidget->addAnchor(Fw::AnchorTop, m_id, Fw::AnchorTop);
        scrollWidget->addAnchor(Fw::AnchorRight, m_id, Fw::AnchorRight);
        scrollWidget->addAnchor(Fw::AnchorBottom, m_id, Fw::AnchorBottom);
        scrollWidget->callLuaField("setStep", 48);
        scrollWidget->callLuaField("setPixelsScroll", true);
    }
}

void UIWidget::setPositions(std::string_view type, std::string_view value) {
    const Unit unit = detectUnit(value);
    int16_t v = stdext::to_number(std::string(numericPart(value)));

    if (type == "top") {
        m_positions.top.unit = unit;
        m_positions.top.value = v;
    } else if (type == "bottom") {
        m_positions.bottom.unit = unit;
        m_positions.bottom.value = v;
    } else if (type == "left") {
        m_positions.left.unit = unit;
        m_positions.left.value = v;
    } else if (type == "right") {
        m_positions.right.unit = unit;
        m_positions.right.value = v;
    }
}

void UIWidget::setDisplay(DisplayType type) {
    if (m_displayType == type)
        return;

    auto old = m_displayType;
    m_displayType = type;

    if (type == DisplayType::None) {
        setVisible(false);
    } else if (old == DisplayType::None)
        setVisible(true);

    scheduleHtmlTask(PropApplyAnchorAlignment);
}

void UIWidget::ensureUniqueId() {
    static uint_fast32_t LAST_UNIQUE_ID = 0;
    if (!m_htmlNode)
        return;

    const std::string newId = "html_" + std::to_string(++LAST_UNIQUE_ID);
    m_htmlId = newId;

    const auto& id = m_htmlNode->getAttr("id");
    if (id.empty())
        return;

    const auto parentNode = m_parent ? m_parent->getHtmlNode() : nullptr;
    if (parentNode && parentNode->getById(id) != m_htmlNode) {
        setId(newId);

        if (const auto root = g_html.getRoot(m_htmlRootId)) {
            g_logger.warning("[" + root->moduleName + "] Duplicate id '" + id + "' detected. "
                             "Widget id reassigned to '" + newId + "'.");
        }
    } else setId(id);
}

UIWidgetPtr UIWidget::getVirtualParent() const {
    if (m_positionType != PositionType::Absolute)
        return m_parent;

    auto parent = m_parent;
    while (parent->m_positionType == PositionType::Static) {
        parent = parent->m_parent;
    }

    return parent;
}
void UIWidget::updateSize() {
    if (!isAnchorable() || !m_parent)
        return;

    if (m_htmlNode && (m_htmlNode->getType() == NodeType::Text || m_htmlNode->getStyle("inherit-text") == "true")) {
        setProp(PropTextVerticalAutoResize, true);

        // If this text node shares a block parent with inline element siblings (e.g. <a> tags),
        // size it to fit its actual text content instead of filling the full parent width.
        // Filling the full width would push those inline siblings past the right edge.
        bool hasInlineElementSibling = false;
        if (m_parent->m_width.unit != Unit::FitContent) {
            for (const auto& sibling : m_parent->getChildren()) {
                if (sibling.get() == this) continue;
                if (sibling->getHtmlNode()
                        && sibling->getHtmlNode()->getType() == NodeType::Element
                        && isInlineLike(sibling->getDisplay())) {
                    hasInlineElementSibling = true;
                    break;
                }
            }
        }

        if (m_parent->m_width.unit == Unit::FitContent || hasInlineElementSibling) {
            setProp(PropTextHorizontalAutoResize, true);
            setWidth_px(m_realTextSize.width());
        } else {
            setProp(PropTextHorizontalAutoResize, false);
            setWidth_px(m_parent->getSize().width());
        }
        updateText();
        return;
    }

    const bool widthNeedsUpdate = m_width.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) || m_width.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER);
    const bool heightNeedsUpdate = m_height.needsUpdate(Unit::Percent, SIZE_VERSION_COUNTER);

    if (widthNeedsUpdate || heightNeedsUpdate) {
        auto width = -1;
        auto height = -1;
        auto parent = m_parent;
        while (m_positionType == PositionType::Absolute && parent->m_positionType == PositionType::Static) {
            parent = parent->m_parent;
        }
        if (widthNeedsUpdate) {
            width = parent->getWidth();
            if (width > -1 && m_positionType != PositionType::Absolute)
                width -= parent->getPaddingLeft() + parent->getPaddingRight();
        }
        if (heightNeedsUpdate) {
            height = parent->getHeight();
            if (height > -1 && m_positionType != PositionType::Absolute)
                height -= parent->getPaddingTop() + parent->getPaddingBottom();
        }
        if (width > -1 || height > -1) {
            updateDimension(this, width, height);
        }
    }

    if (m_positionType == PositionType::Absolute) {
        UIWidgetPtr cb = getVirtualParent();
        if (!cb) return;
        cb->updateSize();

        const int pl = cb->getPaddingLeft();
        const int pr = cb->getPaddingRight();
        const int pt = cb->getPaddingTop();
        const int pb = cb->getPaddingBottom();

        const int cbw_content = std::max(0, cb->getWidth());
        const int cbh_content = std::max(0, cb->getHeight());
        const int cbw_padding = std::max(0, cbw_content + pl + pr);
        const int cbh_padding = std::max(0, cbh_content + pt + pb);

        auto toPx = [&](const SizeUnit& u, int base) -> int {
            switch (u.unit) {
                case Unit::Percent: return std::lround(base * (u.value / 100.0));
                case Unit::Px: return u.value;
                default: return 0;
            }
        };

        const bool hasL = m_positions.left.unit != Unit::Auto;
        const bool hasR = m_positions.right.unit != Unit::Auto;
        const bool hasT = m_positions.top.unit != Unit::Auto;
        const bool hasB = m_positions.bottom.unit != Unit::Auto;

        const int baseW_for_offsets = (hasL || hasR) ? cbw_content : cbw_padding;
        const int baseH_for_offsets = (hasT || hasB) ? cbh_content : cbh_padding;

        int left = hasL ? toPx(m_positions.left, baseW_for_offsets) : pl;
        int right = hasR ? toPx(m_positions.right, baseW_for_offsets) : pr;
        int top = hasT ? toPx(m_positions.top, baseH_for_offsets) : pt;
        int bottom = hasB ? toPx(m_positions.bottom, baseH_for_offsets) : pb;

        const int ml = getMarginLeft();
        const int mr = getMarginRight();
        const int mt = getMarginTop();
        const int mb = getMarginBottom();

        bool widthAutoLike =
            m_width.unit == Unit::Auto || m_width.unit == Unit::FitContent ||
            m_width.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
            m_width.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

        int resolvedW = getWidth();
        if (resolvedW < 0 && m_width.valueCalculed > -1) resolvedW = m_width.valueCalculed;

        auto shrinkToFitWidth = [&]() -> int {
            int w = 0, h = 0;
            applyFitContentRecursive(this, w, h);
            return std::max(0, w);
        };

        const int cbw_for_size = (hasL || hasR) ? cbw_content : cbw_padding;

        if (hasL && hasR && widthAutoLike) {
            int w = cbw_for_size - left - right - ml - mr;
            if (w < 0) w = 0;
            setWidth_px(w);
            m_width.applyUpdate(getWidth(), SIZE_VERSION_COUNTER);
            resolvedW = getWidth();
        } else if ((hasL && !hasR && !widthAutoLike) || (hasR && !hasL && !widthAutoLike)) {
            int w = std::max(0, resolvedW);
            int other = cbw_for_size - (hasL ? left : right) - w - ml - mr;
            if (hasL) right = other; else left = other;
        } else if (hasL && hasR && !widthAutoLike) {
            int w = std::max(0, resolvedW);
            right = cbw_for_size - left - w - ml - mr;
        } else {
            if (widthAutoLike) {
                int w = shrinkToFitWidth();
                setWidth_px(w);
                m_width.applyUpdate(getWidth(), SIZE_VERSION_COUNTER);
                resolvedW = getWidth();
            }
            if (!hasL && !hasR) {
                left = pl;
                right = cbw_for_size - left - std::max(0, resolvedW) - ml - mr;
            } else if (!hasL) {
                left = cbw_for_size - right - std::max(0, resolvedW) - ml - mr;
            } else {
                right = cbw_for_size - left - std::max(0, resolvedW) - ml - mr;
            }
        }

        if (m_minSize.width() > 0 || m_maxSize.width() > 0) {
            int clamped = std::max(m_minSize.width(), std::max(0, resolvedW));
            if (m_maxSize.width() > 0) clamped = std::min(m_maxSize.width(), clamped);
            if (clamped != resolvedW) {
                setWidth_px(clamped);
                m_width.applyUpdate(getWidth(), SIZE_VERSION_COUNTER);
                resolvedW = clamped;
                if (hasL) right = cbw_for_size - left - resolvedW - ml - mr;
                else left = cbw_for_size - right - resolvedW - ml - mr;
            }
        }

        bool heightAutoLike =
            m_height.unit == Unit::Auto || m_height.unit == Unit::FitContent ||
            m_height.needsUpdate(Unit::Auto, SIZE_VERSION_COUNTER) ||
            m_height.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER);

        int resolvedH = getHeight();
        if (resolvedH < 0 && m_height.valueCalculed > -1) resolvedH = m_height.valueCalculed;

        auto shrinkToFitHeight = [&]() -> int {
            int w = 0, h = 0;
            applyFitContentRecursive(this, w, h);
            return std::max(0, h);
        };

        const int cbh_for_size = (hasT || hasB) ? cbh_content : cbh_padding;

        if (hasT && hasB && heightAutoLike) {
            int h = cbh_for_size - top - bottom - mt - mb;
            if (h < 0) h = 0;
            setHeight_px(h);
            m_height.applyUpdate(getHeight(), SIZE_VERSION_COUNTER);
            resolvedH = getHeight();
        } else if ((hasT && !hasB && !heightAutoLike) || (hasB && !hasT && !heightAutoLike)) {
            int h = std::max(0, resolvedH);
            int other = cbh_for_size - (hasT ? top : bottom) - h - mt - mb;
            if (hasT) bottom = other; else top = other;
        } else if (hasT && hasB && !heightAutoLike) {
            int h = std::max(0, resolvedH);
            bottom = cbh_for_size - top - h - mt - mb;
        } else {
            if (heightAutoLike) {
                int h = shrinkToFitHeight();
                setHeight_px(h);
                m_height.applyUpdate(getHeight(), SIZE_VERSION_COUNTER);
                resolvedH = getHeight();
            }
            if (!hasT && !hasB) {
                top = pt;
                bottom = cbh_for_size - top - std::max(0, resolvedH) - mt - mb;
            } else if (!hasT) {
                top = cbh_for_size - bottom - std::max(0, resolvedH) - mt - mb;
            } else {
                bottom = cbh_for_size - top - std::max(0, resolvedH) - mt - mb;
            }
        }

        if (m_minSize.height() > 0 || m_maxSize.height() > 0) {
            int clamped = std::max(m_minSize.height(), std::max(0, resolvedH));
            if (m_maxSize.height() > 0) clamped = std::min(m_maxSize.height(), clamped);
            if (clamped != resolvedH) {
                setHeight_px(clamped);
                m_height.applyUpdate(getHeight(), SIZE_VERSION_COUNTER);
                resolvedH = clamped;
                if (hasT) bottom = cbh_for_size - top - resolvedH - mt - mb;
                else top = cbh_for_size - bottom - resolvedH - mt - mb;
            }
        }

        setMarginLeft(0);
        setMarginRight(0);
        setMarginTop(0);
        setMarginBottom(0);

        if (hasL && hasR) {
            setMarginLeft(std::max(0, left));
            setMarginRight(std::max(0, right));
        } else if (hasL) {
            setMarginLeft(std::max(0, (left == INT_MIN ? 0 : left)));
        } else if (hasR) {
            setMarginRight(std::max(0, (right == INT_MIN ? 0 : right)));
        }

        if (hasT && hasB) {
            setMarginTop(std::max(0, top));
            setMarginBottom(std::max(0, bottom));
        } else if (hasT) {
            setMarginTop(std::max(0, (top == INT_MIN ? 0 : top)));
        } else if (hasB) {
            setMarginBottom(std::max(0, (bottom == INT_MIN ? 0 : bottom)));
        }
    }

    if (m_children.empty()) {
        m_width.pendingUpdate = false;
        m_height.pendingUpdate = false;
        return;
    }

    if (m_width.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER) || m_height.needsUpdate(Unit::FitContent, SIZE_VERSION_COUNTER)) {
        int width = 0;
        int height = 0;
        applyFitContentRecursive(this, width, height);
    }

    if (m_displayType == DisplayType::Flex || m_displayType == DisplayType::InlineFlex) {
        layoutFlex(*this);
        m_width.pendingUpdate = false;
        m_height.pendingUpdate = false;
        return;
    }

    if (m_displayType == DisplayType::Table) {
        updateTableLayout();
        computeAndApplyTableColumns(this);
    } else if (isTableBox(m_displayType)) {
        UIWidget* tableAncestor = m_parent.get();
        while (tableAncestor && tableAncestor->m_displayType != DisplayType::Table) {
            tableAncestor = tableAncestor->m_parent.get();
        }
        if (tableAncestor && tableAncestor->m_displayType == DisplayType::Table)
            tableAncestor->updateTableLayout();
    }
}

void UIWidget::applyAnchorAlignment() {
    if (!isOnHtml() || !isAnchorable() || !m_parent)
        return;

    resetAnchors();

    if (m_displayType == DisplayType::None)
        return;

    if (!hasAnchoredLayout())
        return;

    if (m_placement != Fw::AlignNone) {
        applyPlacementAnchors(this);
        return;
    }

    if (m_parent && m_parent->getDisplay() == DisplayType::TableCell) {
        const auto ta = resolveCellTextAlign(this);
        const auto va = resolveCellVerticalAlign(this);
        anchorHorizontalInCell(this, ta);
        anchorVerticalInCell(this, va);
        return;
    }

    if (m_positionType == PositionType::Absolute) {
        const auto& pos = getPositions();
        const bool L = pos.left.unit != Unit::Auto;
        const bool R = pos.right.unit != Unit::Auto;
        const bool T = pos.top.unit != Unit::Auto;
        const bool B = pos.bottom.unit != Unit::Auto;

        if (L && R) {
            addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
        } else if (R && !L) {
            addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
        } else {
            addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
        }

        if (T && B) {
            addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
        } else if (B && !T) {
            addAnchor(Fw::AnchorBottom, "parent", Fw::AnchorBottom);
        } else {
            addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
        }
        return;
    }

    const DisplayType parentDisplay = m_parent ? m_parent->m_displayType : DisplayType::Block;

    FloatType effFloat = mapLogicalFloat(getFloat());
    if (isFlexContainer(parentDisplay) || isGridContainer(parentDisplay) || isTableContainer(parentDisplay) || m_positionType == PositionType::Absolute) {
        effFloat = FloatType::None;
    }

    FlowContext ctx = computeFlowContext(this, parentDisplay, effFloat);

    if (parentDisplay == DisplayType::InlineBlock || parentDisplay == DisplayType::Block || parentDisplay == DisplayType::TableCell) {
        bool anchored = true;
        const auto isInline = isInlineLike(m_displayType);

        if (isInline && m_parent->getTextAlign() == Fw::AlignCenter ||
            !isInline && m_parent->getJustifyItems() == JustifyItemsType::Center) {
            if (ctx.lastNormalWidget)
                addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
            else
                addAnchor(Fw::AnchorHorizontalCenter, "parent", Fw::AnchorHorizontalCenter);
        } else if (m_positionType != PositionType::Absolute) {
            if (isInline && m_parent->getTextAlign() == Fw::AlignLeft ||
                !isInline && m_parent->getJustifyItems() == JustifyItemsType::Left) {
                if (ctx.lastNormalWidget)
                    addAnchor(Fw::AnchorLeft, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorRight);
                else
                    addAnchor(Fw::AnchorLeft, "parent", Fw::AnchorLeft);
            } else if (isInline && m_parent->getTextAlign() == Fw::AlignRight ||
                       !isInline && m_parent->getJustifyItems() == JustifyItemsType::Right) {
                if (ctx.lastNormalWidget)
                    addAnchor(Fw::AnchorRight, "next", Fw::AnchorLeft);
                else
                    addAnchor(Fw::AnchorRight, "parent", Fw::AnchorRight);
            } else anchored = false;
        } else anchored = false;

        if (m_positionType != PositionType::Absolute) {
            bool addVertical = false;
            if (parentDisplay == DisplayType::InlineBlock)
                addVertical = m_parent->getHtmlNode()->getStyle("vertical-align") == "middle";
            else
                addVertical = m_parent->getHtmlNode()->getStyle("align-items") == "center";

            if (addVertical) {
                addAnchor(Fw::AnchorVerticalCenter, "parent", Fw::AnchorVerticalCenter);
                return;
            }
        }

        if (anchored) {
            if (!ctx.lastNormalWidget) {
                addAnchor(Fw::AnchorTop, "parent", Fw::AnchorTop);
            } else {
                if (isInlineLike(m_displayType) && isInlineLike(ctx.lastNormalWidget->getDisplay()))
                    addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorTop);
                else
                    addAnchor(Fw::AnchorTop, ctx.lastNormalWidget->getId().c_str(), Fw::AnchorBottom);
            }
            return;
        }
    }

    const ClearType effClear = mapLogicalClear(m_clearType);
    const bool topCleared = applyClear(this, ctx, effClear);

    if (effFloat == FloatType::Left || effFloat == FloatType::Right)
        applyFloat(this, ctx, effFloat, topCleared);
    else if (isFlexContainer(parentDisplay))
        applyFlex(this, ctx, topCleared);
    else if (isGridContainer(parentDisplay))
        applyGridOrTable(this, ctx, topCleared);
    else if (isTableBox(parentDisplay)) {
        switch (parentDisplay) {
            case DisplayType::Table: {
                if (m_displayType == DisplayType::TableCaption)
                    applyTableCaption(this, ctx, topCleared);
                else if (m_displayType == DisplayType::TableColumnGroup || m_displayType == DisplayType::TableColumn)
                    applyTableColumnLike(this);
                else
                    applyTableChild(this, ctx, topCleared);
                break;
            }
            case DisplayType::TableRowGroup:
            case DisplayType::TableHeaderGroup:
            case DisplayType::TableFooterGroup: {
                applyTableRowGroupChild(this, ctx, topCleared);
                break;
            }
            case DisplayType::TableRow: {
                applyTableRowChild(this, ctx, topCleared);
                break;
            }
            default: {
                applyGridOrTable(this, ctx, topCleared);
                break;
            }
        }
    } else if (isInlineLike(m_displayType))
        applyInline(this, ctx, topCleared);
    else
        applyBlock(this, ctx, topCleared);
}