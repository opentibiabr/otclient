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

#include "declarations.h"
#include "framework/luaengine/luaobject.h"

 // @bindclass
class SoundChannel final : public LuaObject
{
public:
    SoundChannel(const int id) : m_id(id)
    {}

    SoundSourcePtr play(const std::string& filename, float fadetime = 0, float gain = 1.0f, float pitch = 1.0f);
    void stop(float fadetime = 0);
    void enqueue(const std::string& filename, float fadetime = 0, float gain = 1.0f, float pitch = 1.0f);
    void enable() { setEnabled(true); }
    void disable() { setEnabled(false); }

    void setGain(float gain);
    float getGain() { return m_gain; }

    void setPitch(float pitch);
    float getPitch() { return m_pitch; }

    void setPosition(const Point& pos);
    Point getPosition() { return m_pos; }

    void setEnabled(bool enable);
    bool isEnabled() { return m_enabled; }

    int getId() { return m_id; }

protected:
    void update();
    friend class SoundManager;

private:
    struct QueueEntry
    {
        QueueEntry(std::string fn, const float ft, const float g, const float p) : filename(std::move(fn)), fadetime(ft), gain(g), pitch(p) {};

        std::string filename;
        float fadetime;
        float gain;
        float pitch;
    };
    std::deque<QueueEntry> m_queue;
    SoundSourcePtr m_currentSource;
    bool m_enabled{ true };
    int m_id;
    float m_gain{ 1 };
    float m_pitch{ 1 };
    Point m_pos;
};
