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

#include "uicreature.h"

#include "creature.h"
#include "framework/otml/otmlnode.h"

void UICreature::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    UIWidget::drawSelf(drawPane);

    if (m_creature) {
        if (m_creature->getOutfit() != m_outfit) {
            m_creature->setOutfit(m_outfit, false);
        }

        m_creature->setMarked(m_imageColor);
        m_creature->draw(getPaddingRect(), m_creatureSize, m_center);
    }
}

void UICreature::setCreature(const CreaturePtr& creature) {
    m_creature = creature;
    if (m_creature) {
        m_direction = m_creature->getDirection();
        m_outfit = m_creature->getOutfit();
    } else
        m_outfit = {};
}

void UICreature::setOutfit(const Outfit& outfit)
{
    m_outfit = outfit;

    if (!m_creature)
        m_creature = std::make_shared<Creature>();

    m_creature->setDirection(m_direction);
    m_creature->setOutfit(outfit);
    if (m_creature)
        m_creature->setShader(m_shaderName);
}

Otc::Direction UICreature::getDirection() {
    if (m_creature != nullptr) {
        return m_creature->getDirection();
    }
    return Otc::InvalidDirection;
}

void UICreature::setDirection(Otc::Direction dir) {
    m_direction = dir;
    if (m_creature)
        m_creature->setDirection(dir);
}

Outfit UICreature::getOutfit() { if (!m_creature) setOutfit({}); return m_creature->getOutfit(); }

void UICreature::onStyleApply(const std::string_view styleName, const OTMLNodePtr& styleNode)
{
    for (const auto& node : styleNode->children()) {
        if (node->tag() == "creature-center") {
            m_center = node->value<bool>();
        } else if (node->tag() == "creature-size") {
            setCreatureSize(node->value<int>());
        } else if (node->tag() == "outfit-id") {
            auto outfit = getOutfit();
            outfit.setCategory(ThingCategoryCreature);
            outfit.setId(node->value<int>());
            setOutfit(outfit);
        } else if (node->tag() == "outfit-head") {
            getOutfit().setHead(node->value<int>());
        } else if (node->tag() == "outfit-body") {
            getOutfit().setBody(node->value<int>());
        } else if (node->tag() == "outfit-legs") {
            getOutfit().setLegs(node->value<int>());
        } else if (node->tag() == "outfit-feet") {
            getOutfit().setFeet(node->value<int>());
        } else if (node->tag() == "outfit-direction") {
            m_direction = static_cast<Otc::Direction>(node->value<int>());
        }
    }
    UIWidget::onStyleApply(styleName, styleNode);
}

void UICreature::setShader(std::string_view name) {
    m_shaderName = name;
    if (getCreature()) getCreature()->setShader(name);
}

bool UICreature::hasShader() { return getCreature() ? getCreature()->getShader() != nullptr : false; }