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
#include "painter.h"
#include <framework/core/timer.h>

class Particle
{
public:
    Particle(const Point& pos, const Size& startSize, const Size& finalSize, const PointF& velocity,
                       const PointF& acceleration, const float duration, const float ignorePhysicsAfter, const std::vector<Color>& colors,
                       const std::vector<float>& colorsStops, const CompositionMode compositionMode, TexturePtr texture,
                       AnimatedTexturePtr animatedTexture) :
        m_colors(colors), m_colorsStops(colorsStops), m_texture(std::move(texture)), m_animatedTexture(std::move(
        animatedTexture)), m_position(PointF(pos.x, pos.y)),
        m_velocity(velocity), m_acceleration(acceleration), m_startSize(startSize), m_finalSize(finalSize),
        m_duration(duration), m_ignorePhysicsAfter(ignorePhysicsAfter), m_compositionMode(compositionMode)
    {
    }

    void render() const;
    void update(float elapsedTime);

    bool hasFinished() const { return m_finished; }

    PointF getPosition() { return m_position; }
    PointF getVelocity() { return m_velocity; }

    void setPosition(const PointF& position) { m_position = position; }
    void setVelocity(const PointF& velocity) { m_velocity = velocity; }

private:
    void updateColor();
    void updatePosition(float elapsedTime);
    void updateSize();

    std::vector<Color> m_colors;
    std::vector<float> m_colorsStops;

    TexturePtr m_texture;
    AnimatedTexturePtr m_animatedTexture;

    PointF m_position;
    PointF m_velocity;
    PointF m_acceleration;

    Rect m_rect;

    Color m_color;

    Size m_size;
    Size m_startSize;
    Size m_finalSize;

    Timer m_animationTimer;

    float m_duration;
    float m_ignorePhysicsAfter;
    float m_elapsedTime{ 0 };

    CompositionMode m_compositionMode;

    bool m_finished{ false };
};
