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

#include "logger.h"

#include "eventdispatcher.h"
#include "framework/platform/platform.h"

#include <spdlog/logger.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

#ifdef FRAMEWORK_GRAPHICS
#include <framework/platform/platformwindow.h>
#endif

#ifdef ANDROID
#include <android/log.h>
#endif // ANDROID

Logger g_logger;

namespace
{
    constexpr std::string_view s_logPrefixes[] = { "", "", "", "WARNING: ", "ERROR: ", "FATAL ERROR: " };
    constexpr std::string_view s_spdConsolePattern = "[%Y-%d-%m %H:%M:%S.%e] [%^%l%$] %v";
    constexpr std::string_view s_spdConsolePatternDebug = "[%Y-%d-%m %H:%M:%S.%e] [thread %t] [%^%l%$] %v";
    constexpr std::string_view s_spdFilePattern = "[%Y-%d-%m %H:%M:%S.%e] [%l] %v";
    constexpr std::string_view s_spdFilePatternDebug = "[%Y-%d-%m %H:%M:%S.%e] [thread %t] [%l] %v";
#if ENABLE_ENCRYPTION == 1
    bool s_ignoreLogs = true;
#else
    bool s_ignoreLogs = false;
#endif

    std::string_view getConsolePattern()
    {
#ifdef DEBUG_LOG
        return s_spdConsolePatternDebug;
#else
        return s_spdConsolePattern;
#endif
    }

    std::string_view getFilePattern()
    {
#ifdef DEBUG_LOG
        return s_spdFilePatternDebug;
#else
        return s_spdFilePattern;
#endif
    }

    spdlog::level::level_enum toSpdLogLevel(const Fw::LogLevel level)
    {
        switch (level) {
            case Fw::LogFine:
                return spdlog::level::trace;
            case Fw::LogDebug:
                return spdlog::level::debug;
            case Fw::LogInfo:
                return spdlog::level::info;
            case Fw::LogWarning:
                return spdlog::level::warn;
            case Fw::LogError:
                return spdlog::level::err;
            case Fw::LogFatal:
                return spdlog::level::critical;
            default:
                return spdlog::level::info;
        }
    }

    std::shared_ptr<spdlog::logger> createSpdLogger()
    {
        try {
            auto sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
            sink->set_color_mode(spdlog::color_mode::always);
            sink->set_pattern(std::string{ getConsolePattern() });

            auto logger = std::make_shared<spdlog::logger>("otclient", sink);
            logger->set_level(spdlog::level::trace);
            logger->flush_on(spdlog::level::warn);
            spdlog::set_default_logger(logger);

            return logger;
        } catch (...) {
            return nullptr;
        }
    }

    std::shared_ptr<spdlog::logger>& getSpdLogger()
    {
        static std::shared_ptr<spdlog::logger> s_logger = createSpdLogger();
        return s_logger;
    }

    std::shared_ptr<spdlog::sinks::sink>& getSpdLogFileSink()
    {
        static std::shared_ptr<spdlog::sinks::sink> s_fileSink;
        return s_fileSink;
    }
}

void Logger::log(Fw::LogLevel level, const std::string_view message)
{
#ifdef NDEBUG
    if (level == Fw::LogDebug || level == Fw::LogFine)
        return;
#endif

    if (level < m_level)
        return;

    if (s_ignoreLogs)
        return;

    if (g_eventThreadId > -1 && g_eventThreadId != stdext::getThreadId()) {
        g_dispatcher.addEvent([this, level, msg = std::string{ message }] {
            log(level, msg);
        });
        return;
    }

    std::string outmsg{ s_logPrefixes[static_cast<std::size_t>(level)] };
    outmsg.append(message);

#ifdef ANDROID
    __android_log_print(ANDROID_LOG_INFO, "OTClientMobile", "%s", outmsg.c_str());
#endif // ANDROID

    auto& spdLogger = getSpdLogger();
    if (spdLogger) {
        spdLogger->log(toSpdLogLevel(level), "{}", message);
        if (level >= Fw::LogError) {
            spdLogger->flush();
        }
    } else {
        if (const auto fallbackLogger = spdlog::default_logger(); fallbackLogger) {
            fallbackLogger->log(toSpdLogLevel(level), "{}", message);
            if (level >= Fw::LogError) {
                fallbackLogger->flush();
            }
        }
    }

    if (m_outFile.good()) {
        m_outFile << outmsg << std::endl;
        m_outFile.flush();
    }

    std::size_t now = std::time(nullptr);
    m_logMessages.emplace_back(level, outmsg, now);
    if (m_logMessages.size() > MAX_LOG_HISTORY)
        m_logMessages.pop_front();

    if (m_onLog) {
        // schedule log callback, because this callback can run lua code that may affect the current state
        g_dispatcher.addEvent([this, level, outmsg, now] {
            if (m_onLog)
                m_onLog(level, outmsg, now);
        });
    }

    if (level == Fw::LogFatal) {
#ifdef FRAMEWORK_GRAPHICS
        g_window.displayFatalError(message);
#endif
        s_ignoreLogs = true;

        exit(-1);
    }
}

void Logger::logFunc(Fw::LogLevel level, const std::string_view message, const std::string_view prettyFunction)
{
    if (g_eventThreadId > -1 && g_eventThreadId != stdext::getThreadId()) {
        g_dispatcher.addEvent([this, level, msg = std::string{ message }, prettyFunction = std::string{ prettyFunction }] {
            logFunc(level, msg, prettyFunction);
        });
        return;
    }

    auto fncName = prettyFunction.substr(0, prettyFunction.find_first_of('('));
    if (fncName.find_last_of(' ') != std::string::npos)
        fncName = fncName.substr(fncName.find_last_of(' ') + 1);

    std::stringstream ss;
    ss << message;

    if (!fncName.empty()) {
        if (g_lua.isInCppCallback())
            ss << g_lua.traceback("", 1);
        ss << g_platform.traceback(fncName, 1, 8);
    }

    log(level, ss.str());
}

void Logger::fireOldMessages()
{
    if (m_onLog) {
        for (const LogMessage& logMessage : m_logMessages) {
            m_onLog(logMessage.level, logMessage.message, logMessage.when);
        }
    }
}

void Logger::setLogFile(const std::string_view file)
{
    auto& spdLogger = getSpdLogger();
    if (spdLogger) {
        try {
            auto fileSink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(stdext::utf8_to_latin1(file), true);
            fileSink->set_pattern(std::string{ getFilePattern() });

            auto& currentLogFileSink = getSpdLogFileSink();
            auto& sinks = spdLogger->sinks();
            if (currentLogFileSink) {
                std::erase(sinks, currentLogFileSink);
            }

            currentLogFileSink = fileSink;
            sinks.push_back(currentLogFileSink);
            spdLogger->flush();
            return;
        } catch (const spdlog::spdlog_ex& e) {
            g_logger.error("Unable to save log to '{}' using spdlog: {}", file, e.what());
        }
    }

    m_outFile.open(stdext::utf8_to_latin1(file), std::ios::out | std::ios::app);
    if (!m_outFile.is_open() || !m_outFile.good()) {
        g_logger.error("Unable to save log to '{}'", file);
        return;
    }
    m_outFile.flush();
}
