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

#include "player.h"

bool Player::isMage() const {
    switch (m_vocation) {
        case Otc::Vocations_t::SORCERER:
        case Otc::Vocations_t::DRUID:
        case Otc::Vocations_t::MASTER_SORCERER:
        case Otc::Vocations_t::ELDER_DRUID:
            return true;
        default: return false;
    }
}

bool Player::isMonk() const {
    switch (m_vocation) {
        case Otc::Vocations_t::MONK:
        case Otc::Vocations_t::EXALTED_MONK:
            return true;
        default: return false;
    }
}

void Player::setVocation(const uint8_t vocation)
{
    if (m_vocation == vocation)
        return;

    const uint8_t oldVocation = m_vocation;
    m_vocation = vocation;

    callLuaField("onVocationChange", vocation, oldVocation);
}