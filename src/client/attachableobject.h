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
#include "framework/graphics/declarations.h"
#include "framework/luaengine/luaobject.h"
#include "framework/ui/declarations.h"

static const std::vector<UIWidgetPtr> EMPTY_ATTACHED_WIDGETS;
static const std::vector<AttachedEffectPtr> EMPTY_ATTACHED_EFFECTS;

class AttachableObject : public LuaObject
{
public:
    AttachableObject() = default;
    ~AttachableObject() override;

    virtual LuaObjectPtr attachedObjectToLuaObject() = 0;
    virtual bool isTile() { return false; }
    virtual bool isThing() { return false; }

    void attachEffect(const AttachedEffectPtr& obj);
    void clearAttachedEffects(bool ignoreLuaEvent = false);
    void clearTemporaryAttachedEffects();
    void clearPermanentAttachedEffects();
    bool detachEffectById(uint16_t id);
    bool detachEffect(const AttachedEffectPtr& obj);
    AttachedEffectPtr getAttachedEffectById(uint16_t id);

    virtual void onStartAttachEffect(const AttachedEffectPtr& /*effect*/) {};
    virtual void onDispatcherAttachEffect(const AttachedEffectPtr& /*effect*/) {};
    virtual void onStartDetachEffect(const AttachedEffectPtr& /*effect*/) {};

    bool isOwnerHidden() { return m_ownerHidden > 0; }

    const std::vector<AttachedEffectPtr>& getAttachedEffects() { return m_data ? m_data->attachedEffects : EMPTY_ATTACHED_EFFECTS; };

    void attachParticleEffect(const std::string& name);
    void clearAttachedParticlesEffect();
    bool detachParticleEffectByName(const std::string& name);
    void updateAndAttachParticlesEffects(std::vector<std::string>& newElements);

    const std::vector<UIWidgetPtr>& getAttachedWidgets() { return m_data ? m_data->attachedWidgets : EMPTY_ATTACHED_WIDGETS; };
    bool hasAttachedWidgets() const { return m_data && !m_data->attachedWidgets.empty(); };
    bool hasAttachedEffects()  const { return m_data && !m_data->attachedEffects.empty(); };
    bool hasAttachedParticles()  const { return m_data && !m_data->attachedParticles.empty(); };

    bool isWidgetAttached(const UIWidgetPtr& widget);
    void attachWidget(const UIWidgetPtr& widget);
    void clearAttachedWidgets(bool callEvent = true);
    bool detachWidgetById(const std::string& id);
    bool detachWidget(UIWidgetPtr widget);
    UIWidgetPtr getAttachedWidgetById(const std::string& id);

protected:
    struct Data
    {
        std::vector<AttachedEffectPtr> attachedEffects;
        std::vector<ParticleEffectPtr> attachedParticles;
        std::vector<UIWidgetPtr> attachedWidgets;
    };

    void drawAttachedEffect(const Point& originalDest, const Point& dest, LightView* lightView, bool isOnTop);
    void drawAttachedLightEffect(const Point& dest, LightView* lightView);

    void onDetachEffect(const AttachedEffectPtr& effect, bool callEvent = true);
    void drawAttachedParticlesEffect(const Point& dest);

    auto getData() {
        if (!m_data)
            m_data = std::make_shared<Data>();
        return m_data;
    }

    std::shared_ptr<Data> m_data;

    uint8_t m_ownerHidden{ 0 };
};
