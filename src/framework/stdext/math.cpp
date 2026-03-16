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

#ifdef _MSC_VER
#pragma warning(disable:4267) // '?' : conversion from 'A' to 'B', possible loss of data
#endif

namespace stdext
{
    uint32_t computeChecksum(std::span<const uint8_t> data) noexcept
    {
        const uInt n = static_cast<uInt>(data.size());
        return ::adler32(::adler32(0L, Z_NULL, 0),
                        reinterpret_cast<const Bytef*>(data.data()), n);
    }

    std::mt19937& random_gen() {
        thread_local static std::mt19937 generator([] {
            std::random_device rd;
            std::seed_seq seq{ rd(), rd(), rd(), rd(), rd(), rd(), rd(), rd() };
            return std::mt19937(seq);
        }());

        return generator;
    }

    int random_range(int min, int max)
    {
        if (min > max) std::swap(min, max);

        std::uniform_int_distribution<int> dis(min, max);
        return dis(random_gen());
    }

    float random_range(float min, float max)
    {
        if (min > max) std::swap(min, max);

        std::uniform_real_distribution<float> dis(min, max);
        return dis(random_gen());
    }

    bool random_bool(double probability)
    {
        if (probability < 0.0 || probability > 1.0)
            throw std::invalid_argument("Probability must be between 0 and 1");

        std::bernoulli_distribution dis(probability);
        return dis(random_gen());
    }

    int32_t normal_random(int32_t minNumber, int32_t maxNumber)
    {
        if (minNumber > maxNumber) std::swap(minNumber, maxNumber);

        thread_local static std::normal_distribution<float> normalRand(0.5f, 0.25f);

        float v;
        do {
            v = normalRand(random_gen());
        } while (v < 0.0f || v > 1.0f);

        return static_cast<int32_t>(std::round(minNumber + v * (maxNumber - minNumber)));
    }
}