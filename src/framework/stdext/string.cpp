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

#include "string.h"
#include "exception.h"
#include "types.h"

#include <charconv>
#include <utf8cpp/utf8.h>
#include <iterator>

#ifdef _MSC_VER
#pragma warning(disable:4267) // '?' : conversion from 'A' to 'B', possible loss of data
#endif

namespace stdext
{
    class string_error : public exception
    {
    public:
        using exception::exception;
    };

    [[nodiscard]] std::string resolve_path(std::string_view filePath, std::string_view sourcePath) {
        if (filePath.starts_with("/"))
            return std::string(filePath);

        auto slashPos = sourcePath.find_last_of('/');
        if (slashPos == std::string::npos)
            throw string_error("Invalid source path '" + std::string(sourcePath) + "' for file '" + std::string(filePath) + "'");

        return std::string(sourcePath.substr(0, slashPos + 1)) + std::string(filePath);
    }

    [[nodiscard]] std::string date_time_string(const char* format) {
        std::time_t tnow = std::time(nullptr);
        std::tm ts{};

        // Platform-specific time handling
#ifdef _WIN32
        localtime_s(&ts, &tnow);
#else
        localtime_r(&tnow, &ts);
#endif

        char date[20];
        if (std::strftime(date, sizeof(date), format, &ts) == 0)
            throw string_error("Failed to format date-time string");

        return std::string(date);
    }

    [[nodiscard]] std::string dec_to_hex(uint64_t num) {
        char buffer[17];
        auto [ptr, ec] = std::to_chars(buffer, buffer + sizeof(buffer) - 1, num, 16);
        *ptr = '\0';
        return std::string(buffer);
    }

    [[nodiscard]] uint64_t hex_to_dec(std::string_view str) {
        uint64_t num = 0;
        auto [ptr, ec] = std::from_chars(str.data(), str.data() + str.size(), num, 16);
        if (ec != std::errc())
            throw string_error("Invalid hexadecimal input");
        return num;
    }

    [[nodiscard]] bool is_valid_utf8(std::string_view src) {
        return utf8::is_valid(src.begin(), src.end());
    }

    [[nodiscard]] std::string utf8_to_latin1(std::string_view src) {
        std::string out;
        out.reserve(src.size());

        try {
            auto it = src.begin();
            const auto end = src.end();

            while (it != end) {
                const uint32_t codepoint = utf8::next(it, end);

                if (codepoint <= 0xFF) {
                    if ((codepoint >= 32 && codepoint < 128) || codepoint == 0x0d || codepoint == 0x0a || codepoint == 0x09 || codepoint >= 0xA0)
                        out += static_cast<char>(codepoint);
                }
            }
        } catch (const utf8::exception&) {
            return "";
        }

        return out;
    }

    [[nodiscard]] std::string latin1_to_utf8(std::string_view src) {
        std::string out;
        out.reserve(src.size() * 2);

        try {
            for (const unsigned char c : src)
                utf8::append(static_cast<uint32_t>(c), std::back_inserter(out));
        } catch (const utf8::exception&) {
            return "";
        }

        return out;
    }

#ifdef WIN32
    std::wstring utf8_to_utf16(const std::string_view src)
    {
        std::wstring out;

        try {
            utf8::utf8to16(src.begin(), src.end(), std::back_inserter(out));
        } catch (const utf8::exception&) {
            return L"";
        }

        return out;
    }

    std::string utf16_to_utf8(const std::wstring_view src)
    {
        std::string out;

        try {
            utf8::utf16to8(src.begin(), src.end(), std::back_inserter(out));
        } catch (const utf8::exception&) {
            return "";
        }

        return out;
    }

    std::wstring latin1_to_utf16(const std::string_view src) { return utf8_to_utf16(latin1_to_utf8(src)); }

    std::string utf16_to_latin1(const std::wstring_view src) { return utf8_to_latin1(utf16_to_utf8(src)); }
#endif

    void tolower(std::string& str) { std::ranges::transform(str, str.begin(), ::tolower); }

    void toupper(std::string& str) { std::ranges::transform(str, str.begin(), ::toupper); }

    void ltrim(std::string& s) { s.erase(s.begin(), std::ranges::find_if(s, [](unsigned char ch) { return !std::isspace(ch); })); }

    void rtrim(std::string& s) { s.erase(std::ranges::find_if(s | std::views::reverse, [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end()); }

    void trim(std::string& s) { ltrim(s); rtrim(s); }

    void trimSpacesAndNewlines(std::string& s) {
        if (s.empty()) return;

        const unsigned char* data = reinterpret_cast<const unsigned char*>(s.data());
        size_t start = 0;
        size_t end = s.size();

        while (start < end && std::isspace(data[start]))
            ++start;

        while (end > start && std::isspace(data[end - 1]))
            --end;

        if (start > 0 || end < s.size()) {
            const size_t newSize = end - start;
            if (start > 0)
                s.erase(0, start);
            if (newSize < s.size())
                s.resize(newSize);
        }
    }

    void ucwords(std::string& str) {
        bool capitalize = true;
        for (char& c : str) {
            if (std::isspace(static_cast<unsigned char>(c)))
                capitalize = true;
            else if (capitalize) {
                c = std::toupper(static_cast<unsigned char>(c));
                capitalize = false;
            }
        }
    }

    void replace_all(std::string& str, std::string_view search, std::string_view replacement) {
        size_t pos = 0;
        while ((pos = str.find(search, pos)) != std::string::npos) {
            str.replace(pos, search.length(), replacement);
            pos += replacement.length();
        }
    }

    std::string join(const std::vector<std::string>& vec, const std::string& sep) {
        if (vec.empty()) return {};

        size_t total_size = (vec.size() - 1) * sep.size();
        for (const auto& s : vec) total_size += s.size();

        std::string result;
        result.reserve(total_size);

        for (size_t i = 0; i < vec.size(); ++i) {
            if (i > 0) result += sep;
            result += vec[i];
        }
        return result;
    }

    void eraseWhiteSpace(std::string& str) { std::erase_if(str, isspace); }

    [[nodiscard]] std::vector<std::string> split(std::string_view str, std::string_view separators) {
        std::vector<std::string> result;

        const char* begin = str.data();
        const char* end = begin + str.size();
        const char* p = begin;

        while (p < end) {
            const char* token_start = p;

            while (p < end && !separators.contains(*p)) {
                ++p;
            }

            if (p > token_start) {
                result.emplace_back(token_start, p - token_start);
            }

            while (p < end && separators.contains(*p)) {
                ++p;
            }
        }

        return result;
    }

    long long to_number(std::string_view s) {
        const char* p = s.data();
        const char* end = p + s.size();

        long long num = 0;
        bool found = false;
        bool negative = false;
        int frac = 0;
        bool hasFrac = false;

        while (p < end) {
            unsigned char c = static_cast<unsigned char>(*p++);
            if (!found && c == '-') {
                negative = true;
            } else if (c >= '0' && c <= '9') {
                found = true;
                if (!hasFrac) {
                    num = num * 10 + (c - '0');
                } else {
                    if (frac == 0) frac = c - '0';
                }
            } else if (c == '.') {
                hasFrac = true;
            }
        }

        if (!found) return 0;

        if (hasFrac && frac >= 5) {
            num += 1;
        }

        return negative ? -num : num;
    }

    std::vector<long long> extractNumbers(std::string_view s) {
        std::vector<long long> out;
        out.reserve(s.size() / 3);

        const char* p = s.data();
        const char* end = p + s.size();

        long long val = 0;
        bool building = false;
        bool neg = false;

        while (p < end) {
            unsigned char c = static_cast<unsigned char>(*p);

            if (c >= '0' && c <= '9') {
                if (!building) { building = true; val = 0; }
                val = val * 10 + (c - '0');
            } else {
                if (building) {
                    out.emplace_back(neg ? -val : val);
                    building = false;
                    neg = false;
                    val = 0;
                } else {
                    neg = (c == '-');
                }
            }
            ++p;
        }

        if (building) out.emplace_back(neg ? -val : val);
        if (out.empty()) out.emplace_back(0);

        return out;
    }
}
