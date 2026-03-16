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
#include "point.h"

template<class T>
class TSize
{
public:
    constexpr TSize() : wd(-1), ht(-1) {}
    constexpr TSize(T widthHeight) : wd(widthHeight), ht(widthHeight) {}
    constexpr TSize(T width, T height) : wd(width), ht(height) {}
    constexpr TSize(const TSize& other) = default;

    constexpr TPoint<T> toPoint() const { return { wd, ht }; }

    constexpr bool isNull() const { return wd == 0 && ht == 0; }
    constexpr bool isEmpty() const { return wd < 1 || ht < 1; }
    constexpr bool isValid() const { return wd >= 0 && ht >= 0; }
    constexpr bool isUnset() const { return wd == -1 && ht == -1; }

    constexpr T width() const { return wd; }
    constexpr T height() const { return ht; }

    constexpr void resize(T w, T h) { wd = w; ht = h; }
    constexpr void setWidth(T w) { wd = w; }
    constexpr void setHeight(T h) { ht = h; }

    constexpr TSize operator-() const { return TSize(-wd, -ht); }
    constexpr TSize operator+(const TSize& other) const { return TSize(wd + other.wd, ht + other.ht); }
    constexpr TSize& operator+=(const TSize& other) { wd += other.wd; ht += other.ht; return *this; }
    constexpr TSize operator-(const TSize& other) const { return TSize(wd - other.wd, ht - other.ht); }
    constexpr TSize& operator-=(const TSize& other) { wd -= other.wd; ht -= other.ht; return *this; }
    constexpr TSize operator*(const TSize& other) const { return TSize(static_cast<T>(other.wd) * wd, static_cast<T>(ht) * other.ht); }
    constexpr TSize& operator*=(const TSize& other) { wd = static_cast<T>(other.wd) * wd; ht = static_cast<T>(ht) * other.ht; return *this; }
    constexpr TSize operator/(const TSize& other) const { return TSize(static_cast<T>(wd) / other.wd, static_cast<T>(ht) / other.ht); }
    constexpr TSize& operator/=(const TSize& other) { static_cast<T>(wd) /= other.wd; static_cast<T>(ht) /= other.ht; return *this; }
    constexpr TSize operator*(const float v) const { return TSize(static_cast<T>(wd) * v, static_cast<T>(ht) * v); }
    constexpr TSize& operator*=(const float v) { wd = static_cast<T>(wd) * v; ht = static_cast<T>(ht) * v; return *this; }
    constexpr TSize operator/(const float v) const { return TSize(static_cast<T>(wd) / v, static_cast<T>(ht) / v); }
    constexpr TSize& operator/=(const float v) { wd /= v; ht /= v; return *this; }

    constexpr bool operator<=(const TSize& other) const { return wd <= other.wd || ht <= other.ht; }
    constexpr bool operator>=(const TSize& other) const { return wd >= other.wd || ht >= other.ht; }
    constexpr bool operator<(const TSize& other) const { return wd < other.wd || ht < other.ht; }
    constexpr bool operator>(const TSize& other) const { return wd > other.wd || ht > other.ht; }

    constexpr TSize& operator=(const TSize& other) = default;
    constexpr bool operator==(const TSize& other) const { return other.wd == wd && other.ht == ht; }
    constexpr bool operator!=(const TSize& other) const { return other.wd != wd || other.ht != ht; }

    constexpr bool operator<=(const T other) const { return wd <= other || ht <= other; }
    constexpr bool operator>=(const T other) const { return wd >= other || ht >= other; }
    constexpr bool operator<(const T other) const { return wd < other || ht < other; }
    constexpr bool operator>(const T other) const { return wd > other || ht > other; }

    constexpr TSize& operator=(const T other) { wd = other; ht = other; return *this; }
    constexpr bool operator==(const T other) const { return other == wd && other == ht; }
    constexpr bool operator!=(const T other) const { return other != wd || other != ht; }

    constexpr TSize expandedTo(const TSize& other) const { return { std::max<T>(wd, other.wd), std::max<T>(ht, other.ht) }; }
    constexpr TSize boundedTo(const TSize& other) const { return { std::min<T>(wd, other.wd), std::min<T>(ht, other.ht) }; }

    constexpr void scale(const TSize& s, const Fw::AspectRatioMode mode)
    {
        if (mode == Fw::IgnoreAspectRatio || wd == 0 || ht == 0) {
            wd = s.wd;
            ht = s.ht;
            return;
        }

        T rw = (s.ht * wd) / ht;
        const bool useHeight = (mode == Fw::KeepAspectRatio) ? (rw <= s.wd) : (rw >= s.wd);

        if (useHeight) {
            wd = rw;
            ht = s.ht;
        } else {
            ht = (s.wd * ht) / wd;
            wd = s.wd;
        }
    }

    constexpr void scale(int w, int h, const Fw::AspectRatioMode mode)const { scale(TSize(w, h), mode); }

    constexpr T smaller() const { return std::min<T>(ht, wd); }
    constexpr T bigger() const { return std::max<T>(ht, wd); }

    constexpr float ratio() const { return static_cast<float>(wd) / ht; }
    constexpr T area() const { return wd * ht; }
    constexpr T dimension() const { return wd + ht; }

    friend std::ostream& operator<<(std::ostream& out, const TSize& size) {
        out << size.width() << " " << size.height();
        return out;
    }

    friend std::istream& operator>>(std::istream& in, TSize& size) {
        T w, h;
        in >> w >> h;
        size.resize(w, h);
        return in;
    }

private:
    T wd, ht;
};

using Size = TSize<int>;
using SizeF = TSize<float>;
