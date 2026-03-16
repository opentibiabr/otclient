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

template<class T>
class TSize;

template<class T>
class TPoint
{
public:
    T x{}, y{};
    constexpr TPoint() = default;
    constexpr TPoint(const TPoint& other) = default;
    constexpr TPoint(T x, T y) : x{ x }, y{ y } {}
    constexpr TPoint(T xy) : x{ xy }, y{ xy } {}

    constexpr bool isNull() const noexcept { return x == 0 && y == 0; }
    constexpr T manhattanLength() const noexcept { return std::abs(x) + std::abs(y); }
    constexpr float length() const noexcept { return std::sqrt(static_cast<float>(x * x + y * y)); }
    constexpr float distanceFrom(const TPoint& other) const noexcept { return (*this - other).length(); }
    constexpr TPoint translated(T dx, T dy) const noexcept { return { x + dx, y + dy }; }
    constexpr TSize<T> toSize() const noexcept { return { x, y }; }
    constexpr TPoint scale(float v) noexcept {
        if (v != 1.f) {
            float factor = (1.f - (1.f / v));
            x -= x * factor;
            y -= y * factor;
        }
        return *this;
    }

    constexpr TPoint operator-() const noexcept { return { -x, -y }; }

    constexpr TPoint operator+(const TPoint& other) const { return { x + other.x, y + other.y }; }
    constexpr TPoint& operator+=(const TPoint& other) { x += other.x; y += other.y; return *this; }
    constexpr TPoint operator-(const TPoint& other) const { return { x - other.x, y - other.y }; }
    constexpr TPoint& operator-=(const TPoint& other) { x -= other.x; y -= other.y; return *this; }
    constexpr TPoint operator*(const TPoint& other) const { return { x * other.x, y * other.y }; }
    constexpr TPoint& operator*=(const TPoint& other) { x *= other.x; y *= other.y; return *this; }
    constexpr TPoint operator/(const TPoint& other) const { return { x / other.x, y / other.y }; }
    constexpr TPoint& operator/=(const TPoint& other) { x /= other.x; y /= other.y; return *this; }

    constexpr TPoint operator+(T other) const { return { x + other, y + other }; }
    constexpr TPoint& operator+=(T other) { x += other; y += other; return *this; }
    constexpr TPoint operator-(T other) const { return { x - other, y - other }; }
    constexpr TPoint& operator-=(T other) { x -= other; y -= other; return *this; }
    constexpr TPoint operator*(float v) const { return TPoint(x * v, y * v); }
    constexpr TPoint& operator*=(float v) { x *= v; y *= v; return *this; }
    constexpr TPoint operator/(float v) const { return TPoint(x / v, y / v); }
    constexpr TPoint& operator/=(float v) { x /= v; y /= v; return *this; }

    constexpr TPoint operator&(int a) const { return { x & a, y & a }; }
    constexpr TPoint& operator&=(int a) { x &= a; y &= a; return *this; }

    constexpr bool operator<=(const TPoint& other) const { return x <= other.x && y <= other.y; }
    constexpr bool operator>=(const TPoint& other) const { return x >= other.x && y >= other.y; }
    constexpr bool operator<(const TPoint& other) const { return x < other.x && y < other.y; }
    constexpr bool operator>(const TPoint& other) const { return x > other.x && y > other.y; }

    constexpr TPoint& operator=(const TPoint& other) = default;

    constexpr bool operator==(const TPoint& other) const { return other.x == x && other.y == y; }
    constexpr bool operator!=(const TPoint& other) const { return other.x != x || other.y != y; }

    constexpr std::size_t hash() const noexcept { return (7 * 15 + x) * 15 + y; }

    friend std::ostream& operator<<(std::ostream& out, const TPoint& point) {
        return out << point.x << " " << point.y;
    }

    friend std::istream& operator>>(std::istream& in, TPoint& point) {
        return in >> point.x >> point.y;
    }
};

template <class T>
struct fmt::formatter<TPoint<T>, char> {
    constexpr auto parse(format_parse_context& ctx) const
        -> decltype(ctx.begin()) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const TPoint<T>& p, FormatContext& ctx) const
        -> decltype(ctx.out()) {
        return fmt::format_to(ctx.out(), "{} {}", p.x, p.y);
    }
};

using Point = TPoint<int>;
using PointF = TPoint<float>;
