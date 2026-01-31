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

#include <framework/core/declarations.h>
#include <framework/core/timer.h>

#include <appearances.pb.h>

using namespace otclient::protobuf;

enum AnimationPhase : int16_t
{
    AnimPhaseAutomatic = -1,
    AnimPhaseRandom = 254,
    AnimPhaseAsync = 255,
};

enum AnimationDirection : uint8_t
{
    AnimDirForward = 0,
    AnimDirBackward = 1
};

class Animator : public std::enable_shared_from_this<Animator>
{
public:
    void unserializeAppearance(const appearances::SpriteAnimation& animation);
    void unserialize(int animationPhases, const FileStreamPtr& fin);
    void serialize(const FileStreamPtr& fin) const;
    void setPhase(int phase);
    void resetAnimation();

    int getPhase();
    int getPhaseAt(Timer& timer, float durationFactor = 1.f) const;
    int getStartPhase() const;
    int getAnimationPhases() const { return m_animationPhases; }
    int getAverageDuration() const { return getTotalDuration() / getAnimationPhases(); }

    uint16_t getMinDuration() const { return m_minDuration; }

    bool isAsync() const { return m_async; }
    bool isComplete() const { return m_isComplete; }
    bool isInfiniteLoop() const { return m_loopType == appearances::ANIMATION_LOOP_TYPE_INFINITE || m_loopType == appearances::ANIMATION_LOOP_TYPE_PINGPONG; }
    int8_t getLoopCount() const { return m_loopCount; }
    appearances::ANIMATION_LOOP_TYPE getLoopType() const { return m_loopType; }

    uint16_t getTotalDuration() const;

private:
    int getPingPongPhase();
    int getLoopPhase();
    int getPhaseDuration(int phase) const;

    void calculateSynchronous();

    int8_t m_startPhase{ 0 };
    int8_t m_loopCount{ 0 };
    appearances::ANIMATION_LOOP_TYPE m_loopType{ appearances::ANIMATION_LOOP_TYPE_COUNTED };

    uint8_t m_currentLoop{ 0 };
    uint8_t m_phase{ 0 };

    uint16_t m_minDuration{ 0 };
    uint16_t m_currentDuration{ 0 };
    uint16_t m_animationPhases{ 0 };

    bool m_isComplete{ false };
    bool m_async{ false };

    std::vector<std::pair<uint16_t, uint16_t>> m_phaseDurations;
    AnimationDirection m_currentDirection{ AnimDirForward };
    ticks_t m_lastPhaseTicks{ 0 };
};
