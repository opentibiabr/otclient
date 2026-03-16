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

#include "attachableobject.h"

#include "attachedeffect.h"
#include "client.h"
#include "map.h"
#include "uimap.h"
#include "framework/core/eventdispatcher.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/particleeffect.h"
#include "framework/graphics/particlemanager.h"
#include "framework/ui/uiwidget.h"

extern ParticleManager g_particles;

AttachableObject::~AttachableObject()
{
    clearAttachedEffects(true);
    clearAttachedParticlesEffect();
    clearAttachedWidgets(false);
}

void AttachableObject::attachEffect(const AttachedEffectPtr& obj)
{
    if (!obj)
        return;

    onStartAttachEffect(obj);

    if (obj->isHidedOwner())
        ++m_ownerHidden;

    if (obj->getDuration() > 0) {
        g_dispatcher.scheduleEvent([self = std::static_pointer_cast<AttachableObject>(shared_from_this()), effect = obj] {
            self->detachEffect(effect);
        }, obj->getDuration());
    }

    getData()->attachedEffects.emplace_back(obj);
    g_dispatcher.addEvent([effect = obj, self = std::static_pointer_cast<AttachableObject>(shared_from_this())] {
        self->onDispatcherAttachEffect(effect);
        effect->callLuaField("onAttach", self->attachedObjectToLuaObject());
    });
}

bool AttachableObject::detachEffect(const AttachedEffectPtr& obj) {
    if (!hasAttachedEffects()) return false;
    const auto it = std::find(m_data->attachedEffects.begin(), m_data->attachedEffects.end(), obj);

    if (it == m_data->attachedEffects.end())
        return false;

    onDetachEffect(*it);
    m_data->attachedEffects.erase(it);

    return true;
}

bool AttachableObject::detachEffectById(uint16_t id)
{
    if (!hasAttachedEffects()) return false;
    const auto it = std::find_if(m_data->attachedEffects.begin(), m_data->attachedEffects.end(),
                                 [id](const AttachedEffectPtr& obj) { return obj->getId() == id; });

    if (it == m_data->attachedEffects.end())
        return false;

    onDetachEffect(*it);
    m_data->attachedEffects.erase(it);

    return true;
}

void AttachableObject::onDetachEffect(const AttachedEffectPtr& effect, const bool callEvent)
{
    if (effect->isHidedOwner())
        --m_ownerHidden;

    onStartDetachEffect(effect);

    if (callEvent)
        effect->callLuaField("onDetach", attachedObjectToLuaObject());
}

void AttachableObject::clearAttachedEffects(const bool ignoreLuaEvent)
{
    if (!hasAttachedEffects()) return;
    for (const auto& e : m_data->attachedEffects)
        onDetachEffect(e, !ignoreLuaEvent);
    m_data->attachedEffects.clear();
}

void AttachableObject::clearTemporaryAttachedEffects()
{
    if (!hasAttachedEffects()) return;
    std::erase_if(m_data->attachedEffects,
                  [this](const AttachedEffectPtr& obj) {
        if (!obj->isPermanent()) {
            onDetachEffect(obj);
            return true;
        }
        return false;
    });
}

void AttachableObject::clearPermanentAttachedEffects()
{
    if (!hasAttachedEffects()) return;
    std::erase_if(m_data->attachedEffects,
                  [this](const AttachedEffectPtr& obj) {
        if (obj->isPermanent()) {
            onDetachEffect(obj);
            return true;
        }
        return false;
    });
}

AttachedEffectPtr AttachableObject::getAttachedEffectById(uint16_t id)
{
    if (!hasAttachedEffects()) return nullptr;
    const auto it = std::find_if(m_data->attachedEffects.begin(), m_data->attachedEffects.end(),
                                 [id](const AttachedEffectPtr& obj) { return obj->getId() == id; });

    if (it == m_data->attachedEffects.end())
        return nullptr;

    return *it;
}

void AttachableObject::drawAttachedEffect(const Point& originalDest, const Point& dest, LightView* lightView, const bool isOnTop)
{
    if (!hasAttachedEffects()) return;
    for (const auto& effect : m_data->attachedEffects) {
        effect->draw(effect->isFollowingOwner() ? dest : originalDest, isOnTop, lightView);
        if (effect->getLoop() == 0) {
            g_dispatcher.addEvent([self = std::static_pointer_cast<AttachableObject>(shared_from_this()), effect] {
                self->detachEffect(effect);
            });
        }
    }
}

void AttachableObject::drawAttachedLightEffect(const Point& dest, LightView* lightView) {
    if (!hasAttachedEffects()) return;
    for (const auto& effect : m_data->attachedEffects)
        effect->drawLight(dest, lightView);
}

void AttachableObject::attachParticleEffect(const std::string& name)
{
    const ParticleEffectPtr effect = g_particles.createEffect(name);
    if (!effect)
        return;

    getData()->attachedParticles.emplace_back(effect);
}

void AttachableObject::clearAttachedParticlesEffect()
{
    if (m_data)
        m_data->attachedParticles.clear();
}

bool AttachableObject::detachParticleEffectByName(const std::string& name)
{
    if (!hasAttachedParticles()) return false;

    auto findFunc = [name](const ParticleEffectPtr& obj) {
        if (const auto& effectType = obj->getEffectType()) {
            return effectType->getName() == name;
        }
        return false;
    };
    const auto it = std::find_if(m_data->attachedParticles.begin(), m_data->attachedParticles.end(), findFunc);

    if (it == m_data->attachedParticles.end())
        return false;

    m_data->attachedParticles.erase(it);

    return true;
}

void AttachableObject::drawAttachedParticlesEffect(const Point& dest)
{
    if (!hasAttachedParticles())
        return;

    g_drawPool.pushTransformMatrix();
    g_drawPool.translate(dest);

    for (const auto& effect : m_data->attachedParticles)
        effect->render();

    g_drawPool.popTransformMatrix();
}

void AttachableObject::updateAndAttachParticlesEffects(std::vector<std::string>& newElements)
{
    if (!hasAttachedParticles()) return;

    std::vector<std::string> toRemove;
    toRemove.reserve(m_data->attachedParticles.size());

    for (const auto& effect : m_data->attachedParticles) {
        auto findPos = std::ranges::find(newElements, effect->getEffectType()->getName());
        if (findPos == newElements.end())
            toRemove.emplace_back(effect->getEffectType()->getName());
        else
            newElements.erase(findPos);
    }

    for (const auto& name : toRemove)
        detachParticleEffectByName(name);

    for (const auto& name : newElements)
        attachParticleEffect(name);
}

bool AttachableObject::isWidgetAttached(const UIWidgetPtr& widget) {
    if (!hasAttachedWidgets()) return false;
    return std::find_if(m_data->attachedWidgets.begin(), m_data->attachedWidgets.end(),
                        [widget](const UIWidgetPtr& obj) { return obj == widget; }) != m_data->attachedWidgets.end();
}

void AttachableObject::attachWidget(const UIWidgetPtr& widget) {
    if (!widget || isWidgetAttached(widget))
        return;

    if (g_map.isWidgetAttached(widget)) {
        g_logger.error("Failed to attach widget {}, this widget is already attached to map.", widget->getId());
        return;
    }

    widget->setDraggable(false);
    widget->setParent(g_client.getMapWidget());
    getData()->attachedWidgets.emplace_back(widget);
    g_map.addAttachedWidgetToObject(widget, std::static_pointer_cast<AttachableObject>(shared_from_this()));
    widget->callLuaField("onAttached", asLuaObject());
    widget->addOnDestroyCallback("attached-widget-destroy", [this, widget] {
        detachWidget(widget);
    });
}

bool AttachableObject::detachWidgetById(const std::string& id)
{
    if (!hasAttachedWidgets()) return false;
    const auto it = std::find_if(m_data->attachedWidgets.begin(), m_data->attachedWidgets.end(),
                                 [id](const UIWidgetPtr& obj) { return obj->getId() == id; });

    if (it == m_data->attachedWidgets.end())
        return false;

    const auto widget = (*it);
    m_data->attachedWidgets.erase(it);
    g_map.removeAttachedWidgetFromObject(widget);
    widget->removeOnDestroyCallback("attached-widget-destroy");
    widget->callLuaField("onDetached", asLuaObject());
    return true;
}

bool AttachableObject::detachWidget(const UIWidgetPtr widget)
{
    if (!hasAttachedWidgets()) return false;

    const auto it = std::remove(m_data->attachedWidgets.begin(), m_data->attachedWidgets.end(), widget);
    if (it == m_data->attachedWidgets.end())
        return false;

    widget->removeOnDestroyCallback("attached-widget-destroy");
    widget->callLuaField("onDetached", asLuaObject());

    g_map.removeAttachedWidgetFromObject(widget);
    m_data->attachedWidgets.erase(it);

    return true;
}

void AttachableObject::clearAttachedWidgets(const bool callEvent)
{
    if (!hasAttachedWidgets()) return;

    // keep the same behavior as detachWidget
    const auto oldList = std::move(m_data->attachedWidgets);
    m_data->attachedWidgets.clear();

    for (const auto& widget : oldList) {
        g_map.removeAttachedWidgetFromObject(widget);
        widget->removeOnDestroyCallback("attached-widget-destroy");

        if (callEvent)
            widget->callLuaField("onDetached", asLuaObject());
    }
}

UIWidgetPtr AttachableObject::getAttachedWidgetById(const std::string& id)
{
    if (!hasAttachedWidgets()) return nullptr;
    const auto it = std::find_if(m_data->attachedWidgets.begin(), m_data->attachedWidgets.end(),
                                 [id](const UIWidgetPtr& obj) { return obj->getId() == id; });

    if (it == m_data->attachedWidgets.end())
        return nullptr;

    return *it;
}