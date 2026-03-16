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

#pragma once

#include "../const.h"

template <class T>
class TPoint;

template <class T>
class TSize;

template <class T>
class TRect
{
public:
    constexpr TRect() noexcept : x1{ 0 }, y1{ 0 }, x2{ -1 }, y2{ -1 } {}
    constexpr TRect(T x, T y, T width, T height) noexcept : x1{ x }, y1{ y }, x2{ x + width - 1 }, y2{ y + height - 1 } {}
    constexpr TRect(const TPoint<T>& topLeft, const TPoint<T>& bottomRight) noexcept : x1{ topLeft.x }, y1{ topLeft.y }, x2{ bottomRight.x }, y2{ bottomRight.y } {}
    constexpr TRect(T x, T y, const TSize<T>& size) : x1(x), y1(y), x2(x + size.width() - 1), y2(y + size.height() - 1) {}
    constexpr TRect(const TPoint<T>& topLeft, const TSize<T>& size) noexcept : x1{ topLeft.x }, y1{ topLeft.y }, x2{ x1 + size.width() - 1 }, y2{ y1 + size.height() - 1 } {}
    constexpr TRect(const TPoint<T>& topLeft, T width, T height) noexcept : x1{ topLeft.x }, y1{ topLeft.y }, x2{ x1 + width - 1 }, y2{ y1 + height - 1 } {}
    constexpr TRect(const TRect& other) noexcept = default;

    [[nodiscard]] constexpr bool isNull() const noexcept { return x2 == x1 - 1 && y2 == y1 - 1; }
    [[nodiscard]] constexpr bool isEmpty() const noexcept { return x1 > x2 || y1 > y2; }
    [[nodiscard]] constexpr bool isValid() const noexcept { return x1 <= x2 && y1 <= y2; }

    [[nodiscard]] constexpr T left() const noexcept { return x1; }
    [[nodiscard]] constexpr T top() const noexcept { return y1; }
    [[nodiscard]] constexpr T right() const noexcept { return x2; }
    [[nodiscard]] constexpr T bottom() const noexcept { return y2; }
    [[nodiscard]] constexpr T horizontalCenter() const noexcept { return x1 + (x2 - x1) / 2; }
    [[nodiscard]] constexpr T verticalCenter() const noexcept { return y1 + (y2 - y1) / 2; }
    [[nodiscard]] constexpr T x() const noexcept { return x1; }
    [[nodiscard]] constexpr T y() const noexcept { return y1; }
    [[nodiscard]] constexpr TPoint<T> topLeft() const noexcept { return { x1, y1 }; }
    [[nodiscard]] constexpr TPoint<T> bottomRight() const noexcept { return { x2, y2 }; }
    [[nodiscard]] constexpr TPoint<T> topRight() const noexcept { return { x2, y1 }; }
    [[nodiscard]] constexpr TPoint<T> bottomLeft() const noexcept { return { x1, y2 }; }
    [[nodiscard]] constexpr TPoint<T> topCenter() const noexcept { return { (x1 + x2) / 2, y1 }; }
    [[nodiscard]] constexpr TPoint<T> bottomCenter() const noexcept { return { (x1 + x2) / 2, y2 }; }
    [[nodiscard]] constexpr TPoint<T> centerLeft() const noexcept { return { x1, (y1 + y2) / 2 }; }
    [[nodiscard]] constexpr TPoint<T> centerRight() const noexcept { return { x2, (y1 + y2) / 2 }; }
    [[nodiscard]] constexpr TPoint<T> center() const noexcept { return { (x1 + x2) / 2, (y1 + y2) / 2 }; }
    [[nodiscard]] constexpr T width() const noexcept { return x2 - x1 + 1; }
    [[nodiscard]] constexpr T height() const noexcept { return y2 - y1 + 1; }
    [[nodiscard]] constexpr TSize<T> size() const noexcept { return { width(), height() }; }
    constexpr void reset() noexcept { x1 = y1 = 0; x2 = y2 = -1; }
    constexpr void clear() noexcept { x2 = x1 - 1; y2 = y1 - 1; }

    constexpr void setLeft(T pos) noexcept { x1 = pos; }
    constexpr void setTop(T pos) noexcept { y1 = pos; }
    constexpr void setRight(T pos) noexcept { x2 = pos; }
    constexpr void setBottom(T pos) noexcept { y2 = pos; }
    constexpr void setX(T x) noexcept { x1 = x; }
    constexpr void setY(T y) noexcept { y1 = y; }
    constexpr void setTopLeft(const TPoint<T>& p) noexcept { x1 = p.x; y1 = p.y; }
    constexpr void setBottomRight(const TPoint<T>& p) noexcept { x2 = p.x; y2 = p.y; }
    constexpr void setTopRight(const TPoint<T>& p) noexcept { x2 = p.x; y1 = p.y; }
    constexpr void setBottomLeft(const TPoint<T>& p) noexcept { x1 = p.x; y2 = p.y; }
    constexpr void setWidth(T width) noexcept { x2 = x1 + width - 1; }
    constexpr void setHeight(T height) noexcept { y2 = y1 + height - 1; }
    constexpr void setSize(const TSize<T>& size) noexcept { x2 = x1 + size.width - 1; y2 = y1 + size.height - 1; }
    constexpr void setRect(T x, T y, T width, T height) noexcept { x1 = x; y1 = y; x2 = x + width - 1; y2 = y + height - 1; }
    constexpr void setCoords(T left, T top, T right, T bottom) noexcept { x1 = left; y1 = top; x2 = right; y2 = bottom; }

    constexpr void expandLeft(T add) noexcept { x1 -= add; }
    constexpr void expandTop(T add) noexcept { y1 -= add; }
    constexpr void expandRight(T add) noexcept { x2 += add; }
    constexpr void expandBottom(T add) noexcept { y2 += add; }
    constexpr void expand(T top, T right, T bottom, T left) noexcept { x1 -= left; y1 -= top; x2 += right; y2 += bottom; }
    constexpr void expand(T add) noexcept { x1 -= add; y1 -= add; x2 += add; y2 += add; }

    constexpr void translate(T x, T y) noexcept { x1 += x; y1 += y; x2 += x; y2 += y; }
    constexpr void translate(const TPoint<T>& p) noexcept { x1 += p.x; y1 += p.y; x2 += p.x; y2 += p.y; }
    constexpr void resize(const TSize<T>& size) noexcept { x2 = x1 + size.width() - 1; y2 = y1 + size.height() - 1; }
    constexpr void resize(T width, T height) noexcept { x2 = x1 + width - 1; y2 = y1 + height - 1; }
    constexpr void move(T x, T y) noexcept { x2 += x - x1; y2 += y - y1; x1 = x; y1 = y; }
    constexpr void move(const TPoint<T>& p) noexcept { x2 += p.x - x1; y2 += p.y - y1; x1 = p.x; y1 = p.y; }
    constexpr void moveLeft(T pos) noexcept { x2 += (pos - x1); x1 = pos; }
    constexpr void moveTop(T pos) noexcept { y2 += (pos - y1); y1 = pos; }
    constexpr void moveRight(T pos) noexcept { x1 += (pos - x2); x2 = pos; }
    constexpr void moveBottom(T pos) noexcept { y1 += (pos - y2); y2 = pos; }
    constexpr void moveTopLeft(const TPoint<T>& p) noexcept { moveLeft(p.x); moveTop(p.y); }
    constexpr void moveBottomRight(const TPoint<T>& p) noexcept { moveRight(p.x); moveBottom(p.y); }
    constexpr void moveTopRight(const TPoint<T>& p) noexcept { moveRight(p.x); moveTop(p.y); }
    constexpr void moveBottomLeft(const TPoint<T>& p) noexcept { moveLeft(p.x); moveBottom(p.y); }
    constexpr void moveTopCenter(const TPoint<T>& p) noexcept { moveHorizontalCenter(p.x); moveTop(p.y); }
    constexpr void moveBottomCenter(const TPoint<T>& p) noexcept { moveHorizontalCenter(p.x); moveBottom(p.y); }
    constexpr void moveCenterLeft(const TPoint<T>& p) noexcept { moveLeft(p.x); moveVerticalCenter(p.y); }
    constexpr void moveCenterRight(const TPoint<T>& p) noexcept { moveRight(p.x); moveVerticalCenter(p.y); }

    constexpr TRect translated(T x, T y) const noexcept { return TRect(TPoint<T>(x1 + x, y1 + y), TPoint<T>(x2 + x, y2 + y)); }
    constexpr TRect translated(const TPoint<T>& p) const noexcept { return TRect(TPoint<T>(x1 + p.x, y1 + p.y), TPoint<T>(x2 + p.x, y2 + p.y)); }
    constexpr TRect expanded(T add) const noexcept { return TRect(TPoint<T>(x1 - add, y1 - add), TPoint<T>(x2 + add, y2 + add)); }
    constexpr TRect clamp(const TSize<T>& min, const TSize<T>& max) const noexcept {
        return TRect(x1, y1,
            std::min<T>(max.width(), std::max<T>(min.width(), width())),
            std::min<T>(max.height(), std::max<T>(min.height(), height())));
    }

    constexpr void moveCenter(const TPoint<T>& p) noexcept {
        T w = x2 - x1;
        T h = y2 - y1;
        x1 = p.x - w / 2;
        y1 = p.y - h / 2;
        x2 = x1 + w;
        y2 = y1 + h;
    }
    constexpr void moveHorizontalCenter(T x) noexcept {
        T w = x2 - x1;
        x1 = x - w / 2;
        x2 = x1 + w;
    }
    constexpr void moveVerticalCenter(T y) noexcept {
        T h = y2 - y1;
        y1 = y - h / 2;
        y2 = y1 + h;
    }

    constexpr std::size_t hash() const noexcept {
        std::size_t h = 37;
        h = (h * 54059) ^ (x1 * 76963);
        h = (h * 54059) ^ (y1 * 76963);
        return h;
    }

    constexpr bool contains(const TPoint<T>& p, bool insideOnly = false) const noexcept {
        return (insideOnly ? (p.x > x1 && p.x < x2) : (p.x >= x1 && p.x <= x2)) &&
            (insideOnly ? (p.y > y1 && p.y < y2) : (p.y >= y1 && p.y <= y2));
    }

    constexpr bool contains(const TRect& r, bool insideOnly = false) const noexcept {
        return contains(r.topLeft(), insideOnly) && contains(r.bottomRight(), insideOnly);
    }

    constexpr bool intersects(const TRect& r) const noexcept {
        return !(r.x2 < x1 || r.x1 > x2 || r.y2 < y1 || r.y1 > y2);
    }

    constexpr TRect united(const TRect& r) const noexcept {
        return { std::min<T>(x1, r.x1), std::min<T>(y1, r.y1),
                std::max<T>(x2, r.x2) - std::min<T>(x1, r.x1) + 1,
                std::max<T>(y2, r.y2) - std::min<T>(y1, r.y1) + 1 };
    }

    constexpr TRect intersection(const TRect& r) const noexcept {
        if (!intersects(r)) return {};
        return { std::max<T>(x1, r.x1), std::max<T>(y1, r.y1),
                std::min<T>(x2, r.x2) - std::max<T>(x1, r.x1) + 1,
                std::min<T>(y2, r.y2) - std::max<T>(y1, r.y1) + 1 };
    }

    constexpr void alignIn(const TRect& r, const Fw::AlignmentFlag align)
    {
        if (align == Fw::AlignTopLeft)
            moveTopLeft(r.topLeft());
        else if (align == Fw::AlignTopRight)
            moveTopRight(r.topRight());
        else if (align == Fw::AlignTopCenter)
            moveTopCenter(r.topCenter());
        else if (align == Fw::AlignBottomLeft)
            moveBottomLeft(r.bottomLeft());
        else if (align == Fw::AlignBottomRight)
            moveBottomRight(r.bottomRight());
        else if (align == Fw::AlignBottomCenter)
            moveBottomCenter(r.bottomCenter());
        else if (align == Fw::AlignLeftCenter)
            moveCenterLeft(r.centerLeft());
        else if (align == Fw::AlignCenter)
            moveCenter(r.center());
        else if (align == Fw::AlignRightCenter)
            moveCenterRight(r.centerRight());
    }

    constexpr void bind(const TRect& r)
    {
        if (isNull() || r.isNull())
            return;

        if (right() > r.right())
            moveRight(r.right());
        if (bottom() > r.bottom())
            moveBottom(r.bottom());
        if (left() < r.left())
            moveLeft(r.left());
        if (top() < r.top())
            moveTop(r.top());
    }

    constexpr TRect& operator=(const TRect& other) noexcept = default;
    constexpr bool operator!=(const TRect& other) const noexcept { return !(*this == other); }
    constexpr TRect& operator|=(const TRect& other) noexcept { return *this = united(other); }
    constexpr TRect& operator&=(const TRect& other) noexcept { return *this = intersection(other); }

    [[nodiscard]] constexpr bool operator==(const TRect& other) const noexcept = default;

    friend std::ostream& operator<<(std::ostream& out, const TRect& rect) {
        return out << rect.x1 << ' ' << rect.y1 << ' ' << rect.width() << ' ' << rect.height();
    }

    friend std::istream& operator>>(std::istream& in, TRect& rect) {
        T x, y, w, h;
        in >> x >> y >> w >> h;
        rect.setRect(x, y, w, h);
        return in;
    }

private:
    T x1, y1, x2, y2;
};

using Rect = TRect<int>;
using RectF = TRect<float>;