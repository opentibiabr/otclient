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

#include "color.h"

#include "framework/stdext/string.h"

 // NOTE: AABBGGRR order
const Color Color::alpha = 0x00000000U;
const Color Color::white = 0xffffffffU;
const Color Color::black = 0xff000000U;
const Color Color::red = 0xff0000ffU;
const Color Color::darkRed = 0xff000080U;
const Color Color::green = 0xff00ff00U;
const Color Color::darkGreen = 0xff008000U;
const Color Color::blue = 0xffff0000U;
const Color Color::darkBlue = 0xff800000U;
const Color Color::pink = 0xffff00ffU;
const Color Color::darkPink = 0xff800080U;
const Color Color::yellow = 0xff00ffffU;
const Color Color::darkYellow = 0xff008080U;
const Color Color::teal = 0xffffff00U;
const Color Color::darkTeal = 0xff808000U;
const Color Color::gray = 0xffa0a0a0U;
const Color Color::darkGray = 0xff808080U;
const Color Color::lightGray = 0xffc0c0c0U;
const Color Color::orange = 0xff008cffU;

constexpr uint32_t rgb_to_abgr(uint32_t rgb) {
    return 0xFF000000u | ((rgb & 0x0000FFu) << 16) | (rgb & 0x00FF00u) | ((rgb & 0xFF0000u) >> 16);
}

constexpr uint32_t transparent_abgr() { return 0x00000000u; }

namespace {
    struct CssPair { std::string_view name; uint32_t abgr; };

    static constexpr CssPair kCss[] = {
        {"aliceblue",rgb_to_abgr(0xF0F8FF)}, {"antiquewhite",rgb_to_abgr(0xFAEBD7)},
        {"aqua",rgb_to_abgr(0x00FFFF)}, {"aquamarine",rgb_to_abgr(0x7FFFD4)},
        {"azure",rgb_to_abgr(0xF0FFFF)}, {"beige",rgb_to_abgr(0xF5F5DC)},
        {"bisque",rgb_to_abgr(0xFFE4C4)}, {"black",rgb_to_abgr(0x000000)},
        {"blanchedalmond",rgb_to_abgr(0xFFEBCD)}, {"blue",rgb_to_abgr(0x0000FF)},
        {"blueviolet",rgb_to_abgr(0x8A2BE2)}, {"brown",rgb_to_abgr(0xA52A2A)},
        {"burlywood",rgb_to_abgr(0xDEB887)}, {"cadetblue",rgb_to_abgr(0x5F9EA0)},
        {"chartreuse",rgb_to_abgr(0x7FFF00)}, {"chocolate",rgb_to_abgr(0xD2691E)},
        {"coral",rgb_to_abgr(0xFF7F50)}, {"cornflowerblue",rgb_to_abgr(0x6495ED)},
        {"cornsilk",rgb_to_abgr(0xFFF8DC)}, {"crimson",rgb_to_abgr(0xDC143C)},
        {"cyan",rgb_to_abgr(0x00FFFF)}, {"darkblue",rgb_to_abgr(0x00008B)},
        {"darkcyan",rgb_to_abgr(0x008B8B)}, {"darkgoldenrod",rgb_to_abgr(0xB8860B)},
        {"darkgray",rgb_to_abgr(0xA9A9A9)}, {"darkgreen",rgb_to_abgr(0x006400)},
        {"darkgrey",rgb_to_abgr(0xA9A9A9)}, {"darkkhaki",rgb_to_abgr(0xBDB76B)},
        {"darkmagenta",rgb_to_abgr(0x8B008B)}, {"darkolivegreen",rgb_to_abgr(0x556B2F)},
        {"darkorange",rgb_to_abgr(0xFF8C00)}, {"darkorchid",rgb_to_abgr(0x9932CC)},
        {"darkred",rgb_to_abgr(0x8B0000)}, {"darksalmon",rgb_to_abgr(0xE9967A)},
        {"darkseagreen",rgb_to_abgr(0x8FBC8F)}, {"darkslateblue",rgb_to_abgr(0x483D8B)},
        {"darkslategray",rgb_to_abgr(0x2F4F4F)}, {"darkslategrey",rgb_to_abgr(0x2F4F4F)},
        {"darkturquoise",rgb_to_abgr(0x00CED1)}, {"darkviolet",rgb_to_abgr(0x9400D3)},
        {"deeppink",rgb_to_abgr(0xFF1493)}, {"deepskyblue",rgb_to_abgr(0x00BFFF)},
        {"dimgray",rgb_to_abgr(0x696969)}, {"dimgrey",rgb_to_abgr(0x696969)},
        {"dodgerblue",rgb_to_abgr(0x1E90FF)}, {"firebrick",rgb_to_abgr(0xB22222)},
        {"floralwhite",rgb_to_abgr(0xFFFAF0)}, {"forestgreen",rgb_to_abgr(0x228B22)},
        {"fuchsia",rgb_to_abgr(0xFF00FF)}, {"gainsboro",rgb_to_abgr(0xDCDCDC)},
        {"ghostwhite",rgb_to_abgr(0xF8F8FF)}, {"gold",rgb_to_abgr(0xFFD700)},
        {"goldenrod",rgb_to_abgr(0xDAA520)}, {"gray",rgb_to_abgr(0x808080)},
        {"green",rgb_to_abgr(0x008000)}, {"greenyellow",rgb_to_abgr(0xADFF2F)},
        {"grey",rgb_to_abgr(0x808080)}, {"honeydew",rgb_to_abgr(0xF0FFF0)},
        {"hotpink",rgb_to_abgr(0xFF69B4)}, {"indianred",rgb_to_abgr(0xCD5C5C)},
        {"indigo",rgb_to_abgr(0x4B0082)}, {"ivory",rgb_to_abgr(0xFFFFF0)},
        {"khaki",rgb_to_abgr(0xF0E68C)}, {"lavender",rgb_to_abgr(0xE6E6FA)},
        {"lavenderblush",rgb_to_abgr(0xFFF0F5)}, {"lawngreen",rgb_to_abgr(0x7CFC00)},
        {"lemonchiffon",rgb_to_abgr(0xFFFACD)}, {"lightblue",rgb_to_abgr(0xADD8E6)},
        {"lightcoral",rgb_to_abgr(0xF08080)}, {"lightcyan",rgb_to_abgr(0xE0FFFF)},
        {"lightgoldenrodyellow",rgb_to_abgr(0xFAFAD2)}, {"lightgray",rgb_to_abgr(0xD3D3D3)},
        {"lightgreen",rgb_to_abgr(0x90EE90)}, {"lightgrey",rgb_to_abgr(0xD3D3D3)},
        {"lightpink",rgb_to_abgr(0xFFB6C1)}, {"lightsalmon",rgb_to_abgr(0xFFA07A)},
        {"lightseagreen",rgb_to_abgr(0x20B2AA)}, {"lightskyblue",rgb_to_abgr(0x87CEFA)},
        {"lightslategray",rgb_to_abgr(0x778899)}, {"lightslategrey",rgb_to_abgr(0x778899)},
        {"lightsteelblue",rgb_to_abgr(0xB0C4DE)}, {"lightyellow",rgb_to_abgr(0xFFFFE0)},
        {"lime",rgb_to_abgr(0x00FF00)}, {"limegreen",rgb_to_abgr(0x32CD32)},
        {"linen",rgb_to_abgr(0xFAF0E6)}, {"magenta",rgb_to_abgr(0xFF00FF)},
        {"maroon",rgb_to_abgr(0x800000)}, {"mediumaquamarine",rgb_to_abgr(0x66CDAA)},
        {"mediumblue",rgb_to_abgr(0x0000CD)}, {"mediumorchid",rgb_to_abgr(0xBA55D3)},
        {"mediumpurple",rgb_to_abgr(0x9370DB)}, {"mediumseagreen",rgb_to_abgr(0x3CB371)},
        {"mediumslateblue",rgb_to_abgr(0x7B68EE)}, {"mediumspringgreen",rgb_to_abgr(0x00FA9A)},
        {"mediumturquoise",rgb_to_abgr(0x48D1CC)}, {"mediumvioletred",rgb_to_abgr(0xC71585)},
        {"midnightblue",rgb_to_abgr(0x191970)}, {"mintcream",rgb_to_abgr(0xF5FFFA)},
        {"mistyrose",rgb_to_abgr(0xFFE4E1)}, {"moccasin",rgb_to_abgr(0xFFE4B5)},
        {"navajowhite",rgb_to_abgr(0xFFDEAD)}, {"navy",rgb_to_abgr(0x000080)},
        {"oldlace",rgb_to_abgr(0xFDF5E6)}, {"olive",rgb_to_abgr(0x808000)},
        {"olivedrab",rgb_to_abgr(0x6B8E23)}, {"orange",rgb_to_abgr(0xFFA500)},
        {"orangered",rgb_to_abgr(0xFF4500)}, {"orchid",rgb_to_abgr(0xDA70D6)},
        {"palegoldenrod",rgb_to_abgr(0xEEE8AA)}, {"palegreen",rgb_to_abgr(0x98FB98)},
        {"paleturquoise",rgb_to_abgr(0xAFEEEE)}, {"palevioletred",rgb_to_abgr(0xDB7093)},
        {"papayawhip",rgb_to_abgr(0xFFEFD5)}, {"peachpuff",rgb_to_abgr(0xFFDAB9)},
        {"peru",rgb_to_abgr(0xCD853F)}, {"pink",rgb_to_abgr(0xFFC0CB)},
        {"plum",rgb_to_abgr(0xDDA0DD)}, {"powderblue",rgb_to_abgr(0xB0E0E6)},
        {"purple",rgb_to_abgr(0x800080)}, {"rebeccapurple",rgb_to_abgr(0x663399)},
        {"red",rgb_to_abgr(0xFF0000)}, {"rosybrown",rgb_to_abgr(0xBC8F8F)},
        {"royalblue",rgb_to_abgr(0x4169E1)}, {"saddlebrown",rgb_to_abgr(0x8B4513)},
        {"salmon",rgb_to_abgr(0xFA8072)}, {"sandybrown",rgb_to_abgr(0xF4A460)},
        {"seagreen",rgb_to_abgr(0x2E8B57)}, {"seashell",rgb_to_abgr(0xFFF5EE)},
        {"sienna",rgb_to_abgr(0xA0522D)}, {"silver",rgb_to_abgr(0xC0C0C0)},
        {"skyblue",rgb_to_abgr(0x87CEEB)}, {"slateblue",rgb_to_abgr(0x6A5ACD)},
        {"slategray",rgb_to_abgr(0x708090)}, {"slategrey",rgb_to_abgr(0x708090)},
        {"snow",rgb_to_abgr(0xFFFAFA)}, {"springgreen",rgb_to_abgr(0x00FF7F)},
        {"steelblue",rgb_to_abgr(0x4682B4)}, {"tan",rgb_to_abgr(0xD2B48C)},
        {"teal",rgb_to_abgr(0x008080)}, {"thistle",rgb_to_abgr(0xD8BFD8)},
        {"tomato",rgb_to_abgr(0xFF6347)}, {"turquoise",rgb_to_abgr(0x40E0D0)},
        {"violet",rgb_to_abgr(0xEE82EE)}, {"wheat",rgb_to_abgr(0xF5DEB3)},
        {"white",rgb_to_abgr(0xFFFFFF)}, {"whitesmoke",rgb_to_abgr(0xF5F5F5)},
        {"yellow",rgb_to_abgr(0xFFFF00)}, {"yellowgreen",rgb_to_abgr(0x9ACD32)},
    };

    inline std::string to_lower_ascii(std::string_view s) {
        std::string out(s);
        for (char& c : out)
            c += (c >= 'A' && c <= 'Z') ? 0x20 : 0;
        return out;
    }


    inline bool css_lookup(std::string_view name, uint32_t& abgrOut) {
        const auto key = to_lower_ascii(name);

        if (key == "transparent") { abgrOut = 0x00000000u; return true; }

        auto it = std::lower_bound(std::begin(kCss), std::end(kCss), key,
            [](const CssPair& p, const std::string& k) { return p.name < k; });
        if (it != std::end(kCss) && it->name == key) {
            abgrOut = it->abgr;
            return true;
        }

        if (key == "fuchsia" || key == "magenta") { abgrOut = rgb_to_abgr(0xFF00FF); return true; }
        if (key == "aqua" || key == "cyan") { abgrOut = rgb_to_abgr(0x00FFFF); return true; }
        return false;
    }

    static inline void strip_spaces(std::string& s) {
        s.erase(std::remove_if(s.begin(), s.end(),
                [](unsigned char c) { return std::isspace(c); }), s.end());
    }

    static inline int clamp255(int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }

    static inline int parse_byte_or_percent(const std::string& s) {
        if (!s.empty() && s.back() == '%') {
            const double p = std::strtod(s.data(), nullptr);
            return clamp255(static_cast<int>(std::lround(p * 255.0 / 100.0)));
        }
        return clamp255(std::stoi(s));
    }

    static inline int parse_alpha_any(const std::string& s) {
        if (!s.empty() && s.back() == '%') {
            const double p = std::strtod(s.data(), nullptr);
            return clamp255(static_cast<int>(std::lround(p * 255.0 / 100.0)));
        }
        if (s.find_first_of(".eE") != std::string::npos) {
            double f = std::strtod(s.data(), nullptr);
            if (f < 0) f = 0; if (f > 1) f = 1;
            return clamp255(static_cast<int>(std::lround(f * 255.0)));
        }
        return clamp255(std::stoi(s));
    }

    static inline std::vector<std::string> split_commas(std::string s) {
        std::vector<std::string> parts; parts.reserve(4);
        size_t pos = 0;
        while (true) {
            size_t p = s.find(',', pos);
            if (p == std::string::npos) { parts.emplace_back(s.substr(pos)); break; }
            parts.emplace_back(s.substr(pos, p - pos));
            pos = p + 1;
        }
        return parts;
    }

    static inline void hsl_to_rgb(double h, double s, double l, int& r, int& g, int& b) {
        h = std::fmod(h, 360.0); if (h < 0) h += 360.0;
        s = std::clamp(s, 0.0, 1.0);
        l = std::clamp(l, 0.0, 1.0);
        auto hue2rgb = [](double p, double q, double t) {
            if (t < 0) t += 1; if (t > 1) t -= 1;
            if (t < 1.0 / 6) return p + (q - p) * 6 * t;
            if (t < 1.0 / 2) return q;
            if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
            return p;
        };
        double rF, gF, bF;
        if (s == 0) { rF = gF = bF = l; } else {
            const double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            const double p = 2 * l - q;
            const double hk = h / 360.0;
            rF = hue2rgb(p, q, hk + 1.0 / 3);
            gF = hue2rgb(p, q, hk);
            bF = hue2rgb(p, q, hk - 1.0 / 3);
        }
        r = clamp255(static_cast<int>(std::lround(rF * 255.0)));
        g = clamp255(static_cast<int>(std::lround(gF * 255.0)));
        b = clamp255(static_cast<int>(std::lround(bF * 255.0)));
    }
}

Color::Color(const std::string_view coltext)
{
    std::stringstream ss((std::string(coltext)));
    ss >> *this;
    update();
}

void Color::update() { m_hash = rgba(); }

std::ostream& operator<<(std::ostream& out, const Color& color)
{
    return out << '#'
        << std::hex << std::setfill('0')
        << std::setw(2) << static_cast<int>(color.r())
        << std::setw(2) << static_cast<int>(color.g())
        << std::setw(2) << static_cast<int>(color.b())
        << std::setw(2) << static_cast<int>(color.a())
        << std::dec << std::setfill(' ');
}

std::istream& operator>>(std::istream& in, Color& color)
{
    auto clamp255 = [](int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); };

    auto strip_spaces = [](std::string& s) {
        s.erase(std::remove_if(s.begin(), s.end(),
                [](unsigned char c) { return std::isspace(c); }), s.end());
    };

    auto split_commas = [](std::string s) {
        std::vector<std::string> parts; parts.reserve(4);
        size_t pos = 0;
        while (true) {
            size_t p = s.find(',', pos);
            if (p == std::string::npos) { parts.emplace_back(s.substr(pos)); break; }
            parts.emplace_back(s.substr(pos, p - pos));
            pos = p + 1;
        }
        return parts;
    };

    auto parse_byte_or_percent = [&](const std::string& s) {
        if (!s.empty() && s.back() == '%') {
            const double p = std::strtod(s.data(), nullptr);
            return clamp255(static_cast<int>(std::lround(p * 255.0 / 100.0)));
        }
        return clamp255(std::stoi(s));
    };

    auto parse_alpha_any = [&](const std::string& s) {
        if (!s.empty() && s.back() == '%') {
            const double p = std::strtod(s.data(), nullptr);
            return clamp255(static_cast<int>(std::lround(p * 255.0 / 100.0)));
        }
        if (s.find_first_of(".eE") != std::string::npos) {
            double f = std::strtod(s.data(), nullptr);
            if (f < 0) f = 0; if (f > 1) f = 1;
            return clamp255(static_cast<int>(std::lround(f * 255.0)));
        }
        return clamp255(std::stoi(s));
    };

    auto hsl_to_rgb = [&](double h, double s, double l, int& r, int& g, int& b) {
        h = std::fmod(h, 360.0); if (h < 0) h += 360.0;
        s = std::clamp(s, 0.0, 1.0);
        l = std::clamp(l, 0.0, 1.0);
        auto hue2rgb = [](double p, double q, double t) {
            if (t < 0) t += 1; if (t > 1) t -= 1;
            if (t < 1.0 / 6) return p + (q - p) * 6 * t;
            if (t < 1.0 / 2) return q;
            if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6;
            return p;
        };
        double rF, gF, bF;
        if (s == 0) { rF = gF = bF = l; } else {
            const double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            const double p = 2 * l - q;
            const double hk = h / 360.0;
            rF = hue2rgb(p, q, hk + 1.0 / 3);
            gF = hue2rgb(p, q, hk);
            bF = hue2rgb(p, q, hk - 1.0 / 3);
        }
        r = clamp255(static_cast<int>(std::lround(rF * 255.0)));
        g = clamp255(static_cast<int>(std::lround(gF * 255.0)));
        b = clamp255(static_cast<int>(std::lround(bF * 255.0)));
    };

    std::string tmp;

    if (in.peek() == '#') {
        in.ignore() >> tmp;
        if (tmp.length() == 6 || tmp.length() == 8) {
            color.setRed(static_cast<uint8_t>(stdext::hex_to_dec(tmp.substr(0, 2))));
            color.setGreen(static_cast<uint8_t>(stdext::hex_to_dec(tmp.substr(2, 2))));
            color.setBlue(static_cast<uint8_t>(stdext::hex_to_dec(tmp.substr(4, 2))));
            if (tmp.length() == 8)
                color.setAlpha(static_cast<uint8_t>(stdext::hex_to_dec(tmp.substr(6, 2))));
            else
                color.setAlpha(255);
        } else {
            in.seekg(0 - static_cast<std::streamoff>(tmp.length()) - 1, std::ios_base::cur);
        }
        return in;
    }

    in >> tmp;
    if (tmp.empty())
        return in;

    auto starts = [&](const char* k) { return tmp.rfind(k, 0) == 0; };
    auto is_func_like =
        starts("rgb(") || starts("rgba(") ||
        starts("hsl(") || starts("hsla(");

    if (is_func_like && tmp.find(')') == std::string::npos) {
        std::string tail;
        std::getline(in, tail, ')');
        tmp += tail;
        tmp.push_back(')');
    }

    if (tmp == "alpha") { color = Color::alpha; return in; } else if (tmp == "black") { color = Color::black; return in; } else if (tmp == "white") { color = Color::white; return in; } else if (tmp == "red") { color = Color::red; return in; } else if (tmp == "darkRed") { color = Color::darkRed; return in; } else if (tmp == "green") { color = Color::green; return in; } else if (tmp == "darkGreen") { color = Color::darkGreen; return in; } else if (tmp == "blue") { color = Color::blue; return in; } else if (tmp == "darkBlue") { color = Color::darkBlue; return in; } else if (tmp == "pink") { color = Color::pink; return in; } else if (tmp == "darkPink") { color = Color::darkPink; return in; } else if (tmp == "yellow") { color = Color::yellow; return in; } else if (tmp == "darkYellow") { color = Color::darkYellow; return in; } else if (tmp == "teal") { color = Color::teal; return in; } else if (tmp == "darkTeal") { color = Color::darkTeal; return in; } else if (tmp == "gray") { color = Color::gray; return in; } else if (tmp == "darkGray") { color = Color::darkGray; return in; } else if (tmp == "lightGray") { color = Color::lightGray; return in; } else if (tmp == "orange") { color = Color::orange; return in; }

    {
        std::string t = tmp;
        strip_spaces(t);
        auto sw = [&](const char* k) { return t.rfind(k, 0) == 0; };
        bool parsed = false;

        if (sw("rgb(") || sw("rgba(")) {
            const bool hasA = sw("rgba(");
            const size_t o = t.find('('), c = t.rfind(')');
            if (o != std::string::npos && c != std::string::npos && c > o + 1) {
                auto parts = split_commas(t.substr(o + 1, c - o - 1));
                if ((!hasA && parts.size() == 3) || (hasA && parts.size() == 4)) {
                    const int r = parse_byte_or_percent(parts[0]);
                    const int g = parse_byte_or_percent(parts[1]);
                    const int b = parse_byte_or_percent(parts[2]);
                    const int a = hasA ? parse_alpha_any(parts[3]) : 255;
                    color.setRed(static_cast<uint8_t>(r));
                    color.setGreen(static_cast<uint8_t>(g));
                    color.setBlue(static_cast<uint8_t>(b));
                    color.setAlpha(static_cast<uint8_t>(a));
                    parsed = true;
                }
            }
        } else if (sw("hsl(") || sw("hsla(")) {
            const bool hasA = sw("hsla(");
            const size_t o = t.find('('), c = t.rfind(')');
            if (o != std::string::npos && c != std::string::npos && c > o + 1) {
                auto parts = split_commas(t.substr(o + 1, c - o - 1));
                if ((!hasA && parts.size() == 3) || (hasA && parts.size() == 4)) {
                    const double h = std::strtod(parts[0].data(), nullptr);
                    auto pct = [](const std::string& s) {
                        const double v = std::strtod(s.data(), nullptr);
                        return (!s.empty() && s.back() == '%') ? std::clamp(v / 100.0, 0.0, 1.0)
                            : std::clamp(v, 0.0, 1.0);
                    };
                    const double s = pct(parts[1]);
                    const double l = pct(parts[2]);
                    int r, g, b; hsl_to_rgb(h, s, l, r, g, b);
                    const int a = hasA ? parse_alpha_any(parts[3]) : 255;
                    color.setRed(static_cast<uint8_t>(r));
                    color.setGreen(static_cast<uint8_t>(g));
                    color.setBlue(static_cast<uint8_t>(b));
                    color.setAlpha(static_cast<uint8_t>(a));
                    parsed = true;
                }
            }
        }

        if (parsed) {
            in >> std::ws;
            return in;
        }

        uint32_t abgr;
        if (css_lookup(tmp, abgr)) {
            color = Color(abgr);
        } else {
            in.seekg(0 - static_cast<std::streamoff>(tmp.length()), std::ios_base::cur);
        }
    }

    return in;
}
