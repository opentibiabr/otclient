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

namespace stdext
{
    inline bool is_power_of_two(const size_t v) { return ((v != 0) && !(v & (v - 1))); }
    inline size_t to_power_of_two(const size_t v) { if (v == 0) return 0; size_t r = 1; while (r < v && r != 0xffffffff) r <<= 1; return r; }

    inline uint16_t readULE16(const uint8_t* addr) { return static_cast<uint16_t>(addr[1]) << 8 | addr[0]; }
    inline uint32_t readULE32(const uint8_t* addr) { return static_cast<uint32_t>(readULE16(addr + 2)) << 16 | readULE16(addr); }
    inline uint64_t readULE64(const uint8_t* addr) { return static_cast<uint64_t>(readULE32(addr + 4)) << 32 | readULE32(addr); }

    inline void writeULE16(uint8_t* addr, const uint16_t value) { addr[1] = value >> 8; addr[0] = static_cast<uint8_t>(value); }
    inline void writeULE32(uint8_t* addr, const uint32_t value) { writeULE16(addr + 2, value >> 16); writeULE16(addr, static_cast<uint16_t>(value)); }
    inline void writeULE64(uint8_t* addr, const uint64_t value) { writeULE32(addr + 4, value >> 32); writeULE32(addr, static_cast<uint32_t>(value)); }

    inline int16_t readSLE16(const uint8_t* addr) { return static_cast<int16_t>(addr[1]) << 8 | addr[0]; }
    inline int32_t readSLE32(const uint8_t* addr) { return static_cast<int32_t>(readSLE16(addr + 2)) << 16 | readSLE16(addr); }
    inline int64_t readSLE64(const uint8_t* addr) { return static_cast<int64_t>(readSLE32(addr + 4)) << 32 | readSLE32(addr); }

    inline void writeSLE16(uint8_t* addr, const int16_t value) { addr[1] = value >> 8; addr[0] = static_cast<int8_t>(value); }
    inline void writeSLE32(uint8_t* addr, const int32_t value) { writeSLE16(addr + 2, value >> 16); writeSLE16(addr, static_cast<int16_t>(value)); }
    inline void writeSLE64(uint8_t* addr, const int64_t value) { writeSLE32(addr + 4, value >> 32); writeSLE32(addr, static_cast<int32_t>(value)); }

    uint32_t computeChecksum(std::span<const uint8_t> data) noexcept;
    int random_range(int min, int max);
    float random_range(float min, float max);
    int32_t normal_random(int32_t minNumber, int32_t maxNumber);
    bool random_bool(double probability = 0.5);
    std::mt19937& random_gen();
}
