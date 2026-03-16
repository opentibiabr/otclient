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

#include "../global.h"

#include <fstream>

struct LogMessage
{
    LogMessage(const Fw::LogLevel level, const std::string_view message, const std::size_t when) : level(level), message(message), when(when) {}
    Fw::LogLevel level;
    std::string message;
    std::size_t when;
};

// @bindsingleton g_logger
class Logger
{
    enum
    {
        MAX_LOG_HISTORY = 1000
    };

    using OnLogCallback = std::function<void(Fw::LogLevel, std::string_view, int64_t)>;

public:
    void log(Fw::LogLevel level, std::string_view message);
    void logFunc(Fw::LogLevel level, std::string_view message, std::string_view prettyFunction);

    // Lua-compatible functions
    void fine(const std::string_view what) { log(Fw::LogFine, what); }
    void debug(const std::string_view what) { log(Fw::LogDebug, what); }
    void info(const std::string_view what) { log(Fw::LogInfo, what); }
    void warning(const std::string_view what) { log(Fw::LogWarning, what); }
    void error(const std::string_view what) { log(Fw::LogError, what); }
    void fatal(const std::string_view what) { log(Fw::LogFatal, what); }

    // fmt-compatible overloads (for C++ only)
    template<typename... Args>
    inline void debug(fmt::format_string<Args...> fmtStr, Args&&... args) {
        debug(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    template<typename... Args>
    inline void info(fmt::format_string<Args...> fmtStr, Args&&... args) {
        info(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    template<typename... Args>
    inline void warning(fmt::format_string<Args...> fmtStr, Args&&... args) {
        warning(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    template<typename... Args>
    inline void error(fmt::format_string<Args...> fmtStr, Args&&... args) {
        error(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    template<typename... Args>
    inline void fatal(fmt::format_string<Args...> fmtStr, Args&&... args) {
        fatal(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    template<typename... Args>
    inline void fine(fmt::format_string<Args...> fmtStr, Args&&... args) {
        fine(fmt::format(fmtStr, std::forward<Args>(args)...));
    }

    inline void trace() {
        logFunc(Fw::LogDebug, "", __PRETTY_FUNCTION__);
    }

    template<typename... Args>
    inline void traceDebug(fmt::format_string<Args...> fmtStr, Args&&... args) {
        logFunc(Fw::LogDebug, fmt::format(fmtStr, std::forward<Args>(args)...), __PRETTY_FUNCTION__);
    }

    inline void traceDebug(std::string_view what) {
        logFunc(Fw::LogDebug, what, __PRETTY_FUNCTION__);
    }

    template<typename... Args>
    inline void traceInfo(fmt::format_string<Args...> fmtStr, Args&&... args) {
        logFunc(Fw::LogInfo, fmt::format(fmtStr, std::forward<Args>(args)...), __PRETTY_FUNCTION__);
    }

    inline void traceInfo(std::string_view what) {
        logFunc(Fw::LogInfo, what, __PRETTY_FUNCTION__);
    }

    template<typename... Args>
    inline void traceWarning(fmt::format_string<Args...> fmtStr, Args&&... args) {
        logFunc(Fw::LogWarning, fmt::format(fmtStr, std::forward<Args>(args)...), __PRETTY_FUNCTION__);
    }

    inline void traceWarning(std::string_view what) {
        logFunc(Fw::LogWarning, what, __PRETTY_FUNCTION__);
    }

    template<typename... Args>
    inline void traceError(fmt::format_string<Args...> fmtStr, Args&&... args) {
        logFunc(Fw::LogError, fmt::format(fmtStr, std::forward<Args>(args)...), __PRETTY_FUNCTION__);
    }

    inline void traceError(std::string_view what) {
        logFunc(Fw::LogError, what, __PRETTY_FUNCTION__);
    }

    void fireOldMessages();
    void setLogFile(std::string_view file);
    void setOnLog(const OnLogCallback& onLog) { m_onLog = onLog; }
    void setLevel(const Fw::LogLevel level) { m_level = level; }
    Fw::LogLevel getLevel() { return m_level; }

private:
    std::deque<LogMessage> m_logMessages;
    OnLogCallback m_onLog;
    std::ofstream m_outFile;
    Fw::LogLevel m_level{ Fw::LogDebug };
};

extern Logger g_logger;

#define logTraceCounter() { \
    static int __count = 0; \
    static Timer __timer; \
    __count++; \
    if(__timer.ticksElapsed() >= 1000) { \
        logTraceDebug(__count); \
        __count = 0; \
        __timer.restart(); \
    } \
}

#define logTraceFrameCounter() { \
    static int __count = 0; \
    static Timer __timer; \
    __count++; \
    if(__timer.ticksElapsed() > 0) { \
        logTraceDebug(__count); \
        __count = 0; \
        __timer.restart(); \
    } \
}
