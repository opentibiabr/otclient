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

class Color
{
public:
    constexpr Color(const Color& color) = default;
    constexpr Color() { m_hash = white.hash(); };
    constexpr Color(const int r, const int g, const int b, const int a = 0xFF) : m_r(r / 255.f), m_g(g / 255.f), m_b(b / 255.f), m_a(a / 255.f), m_hash(rgba()) {}
    constexpr Color(const float r, const float g, const float b, const float a = 1.0f) : m_r(r), m_g(g), m_b(b), m_a(a), m_hash(rgba()) {}
    constexpr Color(const uint8_t r, const uint8_t g, const uint8_t b, const uint8_t a = 0xFF) : m_r(r / 255.f), m_g(g / 255.f), m_b(b / 255.f), m_a(a / 255.f), m_hash(rgba()) {}
    constexpr Color(const Color& color, const float a) : m_r(color.m_r), m_g(color.m_g), m_b(color.m_b), m_a(a), m_hash(rgba()) {}

    Color(std::string_view coltext);
    Color(const uint32_t rgba) { setRGBA(rgba); }
    Color(const uint8_t byteColor, const uint8_t intensity, const float formule = 0.5f)
    {
        const float brightness = formule + (intensity / 8.f) * formule;
        const auto& colorMap = from8bit(byteColor);

        m_a = colorMap.aF();
        m_b = colorMap.bF() * brightness;
        m_g = colorMap.gF() * brightness;
        m_r = colorMap.rF() * brightness;
        update();
    }

    constexpr uint8_t a() const { return static_cast<uint8_t>(m_a * 255.f); }
    constexpr uint8_t b() const { return static_cast<uint8_t>(m_b * 255.f); }
    constexpr uint8_t g() const { return static_cast<uint8_t>(m_g * 255.f); }
    constexpr uint8_t r() const { return static_cast<uint8_t>(m_r * 255.f); }

    constexpr float aF() const { return m_a; }
    constexpr float bF() const { return m_b; }
    constexpr float gF() const { return m_g; }
    constexpr float rF() const { return m_r; }

    constexpr uint32_t rgba() const { return static_cast<uint32_t>(a() << 24 | b() << 16 | g() << 8 | r()); }
    constexpr size_t hash() const { return m_hash; }

    void setRed(const int r) { m_r = static_cast<uint8_t>(r) / 255.f; update(); }
    void setGreen(const int g) { m_g = static_cast<uint8_t>(g) / 255.f; update(); }
    void setBlue(const int b) { m_b = static_cast<uint8_t>(b) / 255.f; update(); }
    void setAlpha(const int a) { m_a = static_cast<uint8_t>(a) / 255.f; update(); }

    void setRed(const float r) { m_r = r; update(); }
    void setGreen(const float g) { m_g = g; update(); }
    void setBlue(const float b) { m_b = b; update(); }
    void setAlpha(const float a) { m_a = a; update(); }

    void setRGBA(const uint8_t r, const uint8_t g, const uint8_t b, const uint8_t a = 0xFF) { m_r = r / 255.f; m_g = g / 255.f; m_b = b / 255.f; m_a = a / 255.f; update(); }
    void setRGBA(const uint32_t rgba) { setRGBA((rgba >> 0) & 0xff, (rgba >> 8) & 0xff, (rgba >> 16) & 0xff, (rgba >> 24) & 0xff); }

    Color& operator=(const uint32_t rgba) { setRGBA(rgba); return *this; }
    constexpr Color& operator=(const Color& other) = default;

    void blend(const Color& color)
    {
        m_r *= (1 - color.m_a) + color.m_r * color.m_a;
        m_g *= (1 - color.m_a) + color.m_g * color.m_a;
        m_b *= (1 - color.m_a) + color.m_b * color.m_a;
        update();
    }

    constexpr static uint8_t to8bit(const Color& color)
    {
        uint8_t c = 0;
        c += (color.r() / 51) * 36;
        c += (color.g() / 51) * 6;
        c += (color.b() / 51);

        return c;
    }

    constexpr static Color from8bit(const int color, const float brightness = 1.0f)
    {
        if (color >= 216 || color <= 0)
            return alpha;

        const int r = static_cast<int>((color / 36 % 6 * 51) * brightness);
        const int g = static_cast<int>((color / 6 % 6 * 51) * brightness);
        const int b = static_cast<int>((color % 6 * 51) * brightness);

        return Color(r, g, b);
    }

    static const Color
        alpha, white, black, red, darkRed,
        green, darkGreen, blue, darkBlue,
        pink, darkPink, yellow, darkYellow,
        teal, darkTeal, gray, darkGray,
        lightGray, orange;

    friend std::ostream& operator<<(std::ostream& out, const Color& color);
    friend std::istream& operator>>(std::istream& in, Color& color);
    friend constexpr Color operator+(const Color& lhs, const Color& rhs) { return Color(lhs.m_r + rhs.m_r, lhs.m_g + rhs.m_g, lhs.m_b + rhs.m_b, lhs.m_a + rhs.m_a); }
    friend constexpr Color operator-(const Color& lhs, const Color& rhs) { return Color(lhs.m_r - rhs.m_r, lhs.m_g - rhs.m_g, lhs.m_b - rhs.m_b, lhs.m_a - rhs.m_a); }
    friend constexpr Color operator*(const Color& lhs, float v) { return Color(lhs.m_r * v, lhs.m_g * v, lhs.m_b * v, lhs.m_a * v); }
    friend constexpr Color operator/(const Color& lhs, float v) { return Color(lhs.m_r / v, lhs.m_g / v, lhs.m_b / v, lhs.m_a / v); }

    friend constexpr bool operator==(const Color& lhs, const Color& rhs) { return lhs.m_hash == rhs.m_hash; }
    friend constexpr bool operator!=(const Color& lhs, const Color& rhs) { return lhs.m_hash != rhs.m_hash; }
    friend constexpr bool operator==(const Color& lhs, uint32_t rgba) { return lhs.rgba() == rgba; }

private:
    void update();

    float m_r{ 1.f };
    float m_g{ 1.f };
    float m_b{ 1.f };
    float m_a{ 1.f };

    size_t m_hash{ 0 };
};
