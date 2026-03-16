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

#if defined(__x86_64__) || defined(_M_X64) || defined(__i386) || defined(_M_IX86)
#endif

class SpinLock
{
    alignas(64) std::atomic_bool m_flag{ false };

public:
    SpinLock() noexcept = default;
    SpinLock(const SpinLock&) = delete;
    SpinLock& operator=(const SpinLock&) = delete;

    void lock() noexcept {
        for (;;) {
            if (!m_flag.exchange(true, std::memory_order_acquire))
                return;
            while (m_flag.load(std::memory_order_relaxed))
                cpu_relax();
        }
    }

    void unlock() noexcept {
        m_flag.store(false, std::memory_order_release);
    }

    bool try_lock() noexcept {
        return !m_flag.exchange(true, std::memory_order_acquire);
    }

    class Guard
    {
    public:
        explicit Guard(SpinLock& lock) : m_lock(lock) { m_lock.lock(); }
        ~Guard() { m_lock.unlock(); }

        Guard(const Guard&) = delete;
        Guard& operator=(const Guard&) = delete;

    private:
        SpinLock& m_lock;
    };

private:
    static inline void cpu_relax() {
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386) || defined(_M_IX86)
        _mm_pause();
#elif defined(__aarch64__) || defined(__arm__)
        __asm__ __volatile__("yield");
#else
        std::this_thread::yield();
#endif
    }
};
