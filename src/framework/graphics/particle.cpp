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

#include "particle.h"

#include "animatedtexture.h"
#include "drawpoolmanager.h"

void Particle::render() const
{
    if (!m_texture) {
        g_drawPool.addFilledRect(m_rect, m_color);
        return;
    }

    g_drawPool.setCompositionMode(m_compositionMode, true);
    if (m_animatedTexture) {
        const auto& frame = m_animatedTexture->getCurrentFrame();
        if (frame)
            g_drawPool.addTexturedRect(m_rect, frame, m_color);
        return;
    }
    g_drawPool.addTexturedRect(m_rect, m_texture, m_color);
}

void Particle::update(const float elapsedTime)
{
    // check if finished
    if (m_duration >= 0 && m_elapsedTime >= m_duration) {
        m_finished = true;
        return;
    }

    if (m_animatedTexture)
        m_animatedTexture->update();

    updateColor();
    updateSize();
    updatePosition(elapsedTime);

    m_elapsedTime += elapsedTime;
}

void Particle::updatePosition(const float elapsedTime)
{
    if (m_ignorePhysicsAfter < 0 || m_elapsedTime < m_ignorePhysicsAfter) {
        // update position
        PointF delta = m_velocity * elapsedTime;
        delta.y *= -1; // painter orientate Y axis in the inverse direction

        const auto& position = m_position + delta;

        if (m_position != position) {
            m_position += delta;
        }

        // update acceleration
        m_velocity += m_acceleration * elapsedTime;
    }

    m_rect.move(static_cast<int>(m_position.x) - m_size.width() / 2, static_cast<int>(m_position.y) - m_size.height() / 2);
}

void Particle::updateSize()
{
    m_size = m_startSize + (m_finalSize - m_startSize) / m_duration * m_elapsedTime;
    m_rect.resize(m_size);
}

void Particle::updateColor()
{
    const float currentLife = m_elapsedTime / m_duration;
    if (currentLife < m_colorsStops[1]) {
        const float range = m_colorsStops[1] - m_colorsStops[0];
        const float factor = (currentLife - m_colorsStops[0]) / range;
        m_color = m_colors[0] * (1.0f - factor) + m_colors[1] * factor;
    } else if (m_colors.size() > 1) {
        m_colors.erase(m_colors.begin());
        m_colorsStops.erase(m_colorsStops.begin());
    } else if (m_color != m_colors[0]) {
        m_color = m_colors[0];
    }
}