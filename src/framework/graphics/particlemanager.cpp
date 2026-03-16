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

#include "particlemanager.h"

#include "particleeffect.h"
#include "particletype.h"
#include "framework/core/resourcemanager.h"

ParticleManager g_particles;

bool ParticleManager::importParticle(std::string file)
{
    try {
        file = g_resources.guessFilePath(file, "otps");

        const auto& doc = OTMLDocument::parse(file);
        for (const auto& node : doc->children()) {
            if (node->tag() == "Effect") {
                const auto& particleEffectType = std::make_shared<ParticleEffectType>();
                particleEffectType->load(node);
                m_effectsTypes[particleEffectType->getName()] = particleEffectType;
            } else if (node->tag() == "Particle") {
                const auto& particleType = std::make_shared<ParticleType>();
                particleType->load(node);
                m_particleTypes[particleType->getName()] = particleType;
            }
        }
        return true;
    } catch (const stdext::exception& e) {
        g_logger.error("could not load particles file {}: {}", file, e.what());
        return false;
    }
}

ParticleEffectPtr ParticleManager::createEffect(const std::string_view name)
{
    try {
        const auto& particleEffect = std::make_shared<ParticleEffect>();
        particleEffect->load(m_effectsTypes[std::string(name)]);
        m_effects.emplace_back(particleEffect);
        return particleEffect;
    } catch (const stdext::exception& e) {
        g_logger.error("failed to create effect '{}': {}", name, e.what());
        return nullptr;
    }
}

bool ParticleManager::removeEffect(const ParticleEffectPtr& particle) {
    return m_effects.remove(particle) > 0;
}

void ParticleManager::terminate()
{
    m_effects.clear();
    m_effectsTypes.clear();
    m_particleTypes.clear();
}

void ParticleManager::poll()
{
    for (auto it = m_effects.begin(); it != m_effects.end();) {
        const auto& particleEffect = *it;

        if (particleEffect->hasFinished()) {
            it = m_effects.erase(it);
        } else {
            particleEffect->update();
            ++it;
        }
    }
}