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

#include "asyncdispatcher.h"
#include "eventdispatcher.h"
#include <framework/util/stats.h>

thread_local DispatcherContext EventDispatcher::dispacherContext;

EventDispatcher g_dispatcher, g_textDispatcher, g_mainDispatcher;
int16_t g_mainThreadId = stdext::getThreadId();
int16_t g_eventThreadId = -1;

void EventDispatcher::init() {
    for (size_t i = 0; i < g_asyncDispatcher.get_thread_count(); ++i) {
        m_threads.emplace_back(std::make_unique<ThreadTask>());
    }
}

void EventDispatcher::shutdown()
{
    do {
        executeEvents();
        mergeEvents();
    } while (!m_eventList.empty());

    m_scheduledEventList.clear();
    m_deferEventList.clear();
    m_threads.clear();

    m_disabled = true;
}

void EventDispatcher::poll()
{
    AutoStat s(this == &g_dispatcher ? STATS_MAIN : STATS_RENDER, "PollDispatcher");
    mergeEvents();
    executeEvents();
    executeScheduledEvents();
    executeDeferEvents();
}

ScheduledEventPtr EventDispatcher::scheduleEvent(const std::function<void()>& callback, int delay)
{
    return scheduleEventEx("ScheduledEvent", callback, delay);
}

ScheduledEventPtr EventDispatcher::scheduleEventEx(const std::string& function, const std::function<void()>& callback, int delay)
{
    if (m_disabled)
        return std::make_shared<ScheduledEvent>(function, nullptr, delay, 1);

    assert(delay >= 0);

    return pushThreadTask<ScheduledEventPtr>([&](const std::unique_ptr<ThreadTask>& thread) {
        return thread->scheduledEventList.emplace_back(std::make_shared<ScheduledEvent>(function, callback, delay, 1));
    });
}

ScheduledEventPtr EventDispatcher::cycleEvent(const std::function<void()>& callback, int delay)
{
    return cycleEventEx("CycleEvent", callback, delay);
}

ScheduledEventPtr EventDispatcher::cycleEventEx(const std::string& function, const std::function<void()>& callback, int delay)
{
    if (m_disabled)
        return std::make_shared<ScheduledEvent>(function, nullptr, delay, 0);

    assert(delay > 0);

    return pushThreadTask<ScheduledEventPtr>([&](const std::unique_ptr<ThreadTask>& thread) {
        return thread->scheduledEventList.emplace_back(std::make_shared<ScheduledEvent>(function, callback, delay, 0));
    });
}

EventPtr EventDispatcher::addEvent(const std::function<void()>& callback)
{
    return addEventEx("Event", callback);
}

EventPtr EventDispatcher::addEventEx(const std::string& function, const std::function<void()>& callback)
{
    if (m_disabled)
        return std::make_shared<Event>(nullptr);

    if (&g_mainDispatcher == this && g_mainThreadId == stdext::getThreadId()) {
        callback();
        return std::make_shared<Event>(nullptr);
    }

    return pushThreadTask<EventPtr>([&](const std::unique_ptr<ThreadTask>& thread) {
        return thread->events.emplace_back(std::make_shared<Event>(callback, function));
    });
}

void EventDispatcher::deferEvent(const std::function<void()>& callback) {
    deferEventEx("DeferEvent", callback);
}

void EventDispatcher::deferEventEx(const std::string& function, const std::function<void()>& callback) {
    if (m_disabled)
        return;

    pushThreadTask([&](const std::unique_ptr<ThreadTask>& thread) {
        thread->deferEvents.emplace_back(callback, function);
    });
}

void EventDispatcher::executeEvents() {
    if (m_eventList.empty()) {
        return;
    }

    dispacherContext.group = TaskGroup::Serial;
    dispacherContext.type = DispatcherType::Event;

    for (const auto& event : m_eventList) {
        AutoStat s(STATS_DISPATCHER, event->getFunction());
        event->execute();
    }

    m_eventList.clear();
    dispacherContext.reset();
}

void EventDispatcher::executeDeferEvents() {
    dispacherContext.group = TaskGroup::Serial;
    dispacherContext.type = DispatcherType::DeferEvent;

    do {
        for (auto& event : m_deferEventList) {
            AutoStat s(STATS_DISPATCHER, event.getFunction());
            event.execute();
        }
        m_deferEventList.clear();

        for (const auto& thread : m_threads) {
            SpinLock::Guard guard(thread->lock);
            if (m_deferEventList.size() < thread->deferEvents.size())
                m_deferEventList.swap(thread->deferEvents);
            if (!thread->deferEvents.empty()) {
                m_deferEventList.insert(m_deferEventList.end(), make_move_iterator(thread->deferEvents.begin()), make_move_iterator(thread->deferEvents.end()));
                thread->deferEvents.clear();
            }
        }
    } while (!m_deferEventList.empty());

    dispacherContext.reset();
}

void EventDispatcher::executeScheduledEvents() {
    auto& threadScheduledTasks = getThreadTask()->scheduledEventList;

    auto it = m_scheduledEventList.begin();
    while (it != m_scheduledEventList.end()) {
        const auto& scheduledEvent = *it;
        if (scheduledEvent->remainingTicks() > 0)
            break;

        dispacherContext.type = scheduledEvent->maxCycles() > 0 ? DispatcherType::CycleEvent : DispatcherType::ScheduledEvent;
        dispacherContext.group = TaskGroup::Serial;

        AutoStat s(STATS_DISPATCHER, scheduledEvent->getFunction());
        scheduledEvent->execute();

        if (scheduledEvent->nextCycle())
            threadScheduledTasks.emplace_back(scheduledEvent);

        ++it;
    }

    if (it != m_scheduledEventList.begin()) {
        m_scheduledEventList.erase(m_scheduledEventList.begin(), it);
    }

    dispacherContext.reset();
}

void EventDispatcher::mergeEvents() {
    for (const auto& thread : m_threads) {
        SpinLock::Guard guard(thread->lock);
        if (!thread->events.empty()) {
            if (m_eventList.size() < thread->events.size())
                m_eventList.swap(thread->events);

            if (!thread->events.empty()) {
                m_eventList.insert(m_eventList.end(), make_move_iterator(thread->events.begin()), make_move_iterator(thread->events.end()));
                thread->events.clear();
            }
        }

        if (!thread->scheduledEventList.empty()) {
            m_scheduledEventList.insert(make_move_iterator(thread->scheduledEventList.begin()), make_move_iterator(thread->scheduledEventList.end()));
            thread->scheduledEventList.clear();
        }
    }
}
