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

#include "thingtype.h"

#include "animator.h"
#include "game.h"
#include "gameconfig.h"
#include "lightview.h"
#include "spriteappearances.h"
#include "spritemanager.h"
#include "framework/core/asyncdispatcher.h"
#include "framework/core/filestream.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/graphics/image.h"
#include "framework/otml/otmlnode.h"
#include <framework/core/graphicalapplication.h>

const static TexturePtr m_textureNull;

namespace {
    std::string_view categoryName(const ThingCategory category)
    {
        switch (category) {
            case ThingCategoryItem: return "item";
            case ThingCategoryCreature: return "creature";
            case ThingCategoryEffect: return "effect";
            case ThingCategoryMissile: return "missile";
            default: return "unknown";
        }
    }
}

void ThingType::unserializeAppearance(const uint16_t clientId, const ThingCategory category, const appearances::Appearance& appearance)
{
    m_null = false;
    m_id = clientId;
    m_category = category;
    m_name = appearance.name();
    m_description = appearance.description();

    applyAppearanceFlags(appearance.flags());

    if (!g_game.getFeature(Otc::GameLoadSprInsteadProtobuf)) {
        m_animationPhases = 0;
        int totalSpritesCount = 0;

        for (const auto& framegroup : appearance.frame_group()) {
            const int frameGroupType = framegroup.fixed_frame_group();
            const auto& spriteInfo = framegroup.sprite_info();
            const auto& animation = spriteInfo.animation();
            spriteInfo.sprite_id(); // sprites
            const auto& spritesPhases = animation.sprite_phase();

            m_numPatternX = spriteInfo.pattern_width();
            m_numPatternY = spriteInfo.pattern_height();
            m_numPatternZ = spriteInfo.pattern_depth();
            m_layers = spriteInfo.layers();
            m_opaque = spriteInfo.is_opaque();

            m_animationPhases += std::max<int>(1, spritesPhases.size());

            if (const auto& sheet = g_spriteAppearances.getSheetBySpriteId(spriteInfo.sprite_id(0), false)) {
                m_size = sheet->getSpriteSize() / g_gameConfig.getSpriteSize();
            }

            // animations
            if (spritesPhases.size() > 1) {
                auto* animator = new Animator;
                animator->unserializeAppearance(animation);

                if (frameGroupType == FrameGroupMoving)
                    m_animator = animator;
                else if (frameGroupType == FrameGroupIdle || frameGroupType == FrameGroupInitial)
                    m_idleAnimator = animator;
            }

            const int totalSprites = m_layers * m_numPatternX * m_numPatternY * m_numPatternZ * std::max<int>(1, spritesPhases.size());

            if (totalSpritesCount + totalSprites > 4096)
                throw Exception("a thing type has more than 4096 sprites");

            m_spritesIndex.resize(totalSpritesCount + totalSprites);
            for (int j = totalSpritesCount, spriteId = 0; j < (totalSpritesCount + totalSprites); ++j, ++spriteId) {
                m_spritesIndex[j] = spriteInfo.sprite_id(spriteId);
            }

            totalSpritesCount += totalSprites;
        }

        m_textureData.resize(m_animationPhases);
    }
}

void ThingType::applyAppearanceFlags(const appearances::AppearanceFlags& flags)
{
    if (flags.has_bank()) {
        m_groundSpeed = flags.bank().waypoints();
        m_flags |= ThingFlagAttrGround;
    }

    if (flags.has_clip() && flags.clip()) {
        m_flags |= ThingFlagAttrGroundBorder;
    }

    if (flags.has_bottom()) {
        m_flags |= ThingFlagAttrOnBottom;
    }

    if (flags.has_top()) {
        m_flags |= ThingFlagAttrOnTop;
    }

    if (flags.has_container() && flags.container()) {
        m_flags |= ThingFlagAttrContainer;
    }

    if (flags.has_cumulative() && flags.cumulative()) {
        m_flags |= ThingFlagAttrStackable;
    }

    if (flags.has_multiuse() && flags.multiuse()) {
        m_flags |= ThingFlagAttrMultiUse;
    }

    if (flags.has_forceuse() && flags.forceuse()) {
        m_flags |= ThingFlagAttrForceUse;
    }

    if (flags.has_write()) {
        m_flags |= ThingFlagAttrWritable;
        m_maxTextLength = flags.write().max_text_length();
    }

    if (flags.has_write_once()) {
        m_flags |= ThingFlagAttrWritableOnce;
        m_maxTextLength = flags.write_once().max_text_length_once();
    }

    if (flags.has_liquidpool() && flags.liquidpool()) {
        m_flags |= ThingFlagAttrSplash;
    }

    if (flags.has_unpass() && flags.unpass()) {
        m_flags |= ThingFlagAttrNotWalkable;
    }

    if (flags.has_unmove() && flags.unmove()) {
        m_flags |= ThingFlagAttrNotMoveable;
    }

    if (flags.has_unsight() && flags.unsight()) {
        m_flags |= ThingFlagAttrBlockProjectile;
    }

    if (flags.has_avoid() && flags.avoid()) {
        m_flags |= ThingFlagAttrNotPathable;
    }

    // no_movement_animation (?)

    if (flags.has_take() && flags.take()) {
        m_flags |= ThingFlagAttrPickupable;
    }

    if (flags.has_liquidcontainer() && flags.liquidcontainer()) {
        m_flags |= ThingFlagAttrFluidContainer;
    }

    if (flags.has_hang() && flags.hang()) {
        m_flags |= ThingFlagAttrHangable;
    }

    if (flags.has_hook()) {
        const auto& hookDirection = flags.hook();
        if (hookDirection.has_south()) {
            const auto hookType = hookDirection.south();
            if (hookType == appearances::HOOK_TYPE_SOUTH) {
                m_flags |= ThingFlagAttrHookSouth;
            } else if (hookType == appearances::HOOK_TYPE_EAST) {
                m_flags |= ThingFlagAttrHookEast;
            }
        }
        if (hookDirection.has_east()) {
            const auto hookType = hookDirection.east();
            if (hookType == appearances::HOOK_TYPE_SOUTH) {
                m_flags |= ThingFlagAttrHookSouth;
            } else if (hookType == appearances::HOOK_TYPE_EAST) {
                m_flags |= ThingFlagAttrHookEast;
            }
        }
    }

    if (flags.has_light()) {
        m_flags |= ThingFlagAttrLight;
        m_light = { static_cast<uint8_t>(flags.light().brightness()), static_cast<uint8_t>(flags.light().color()) };
    }

    if (flags.has_rotate() && flags.rotate()) {
        m_flags |= ThingFlagAttrRotateable;
    }

    if (flags.has_dont_hide() && flags.dont_hide()) {
        m_flags |= ThingFlagAttrDontHide;
    }

    if (flags.has_translucent() && flags.translucent()) {
        m_flags |= ThingFlagAttrTranslucent;
    }

    if (flags.has_shift()) {
        m_displacement = Point(flags.shift().x(), flags.shift().y());
        m_flags |= ThingFlagAttrDisplacement;
    }

    if (flags.has_height()) {
        m_elevation = flags.height().elevation();
        m_flags |= ThingFlagAttrElevation;
    }

    if (flags.has_lying_object() && flags.lying_object()) {
        m_flags |= ThingFlagAttrLyingCorpse;
    }

    if (flags.has_animate_always() && flags.animate_always()) {
        m_flags |= ThingFlagAttrAnimateAlways;
    }

    if (flags.has_automap()) {
        m_minimapColor = flags.automap().color();
        m_flags |= ThingFlagAttrMinimapColor;
    }

    if (flags.has_lenshelp()) {
        m_lensHelp = flags.lenshelp().id();
        m_flags |= ThingFlagAttrLensHelp;
    }

    if (flags.has_fullbank() && flags.fullbank()) {
        m_flags |= ThingFlagAttrFullGround;
    }

    if (flags.has_ignore_look() && flags.ignore_look()) {
        m_flags |= ThingFlagAttrLook;
    }

    if (flags.has_clothes()) {
        m_clothSlot = flags.clothes().slot();
        m_flags |= ThingFlagAttrCloth;
    }

    // default action

    if (flags.has_market()) {
        m_market.category = static_cast<ITEM_CATEGORY>(flags.market().category());
        m_market.tradeAs = flags.market().trade_as_object_id();
        m_market.showAs = flags.market().show_as_object_id();
        if (g_game.getFeature(Otc::GameLoadSprInsteadProtobuf)) {
            // keep from tibia.dat
            if (m_market.name.empty() && !flags.market().name().empty()) {
                m_market.name = flags.market().name();
            }
        } else {
            m_market.name = m_name;
        }

        for (const int32_t voc : flags.market().restrict_to_profession()) {
            uint16_t vocBitMask = std::pow(2, voc - 1);
            m_market.restrictVocation |= vocBitMask;
        }

        m_market.requiredLevel = flags.market().minimum_level();
        m_flags |= ThingFlagAttrMarket;
    }

    if (flags.has_wrap() && flags.wrap()) {
        m_flags |= ThingFlagAttrWrapable;
    }

    if (flags.has_unwrap() && flags.unwrap()) {
        m_flags |= ThingFlagAttrUnwrapable;
    }

    if (flags.has_topeffect() && flags.topeffect()) {
        m_flags |= ThingFlagAttrTopEffect;
    }

    if (flags.has_default_action()) {
        m_defaultAction = static_cast<PLAYER_ACTION>(flags.default_action().action());
    }

    // npcsaledata
    if (flags.npcsaledata_size() > 0) {
        for (int i = 0; i < flags.npcsaledata_size(); ++i) {
            NPCData data;
            data.name = flags.npcsaledata(i).name();
            data.location = flags.npcsaledata(i).location();
            data.salePrice = flags.npcsaledata(i).sale_price();
            data.buyPrice = flags.npcsaledata(i).buy_price();
            data.currencyObjectTypeId = flags.npcsaledata(i).currency_object_type_id();
            data.currencyQuestFlagDisplayName = flags.npcsaledata(i).currency_quest_flag_display_name();
            m_npcData.push_back(data);
        }
        m_flags |= ThingFlagAttrNPC;
    }

    // charged to expire
    // corpse
    // player_corpse
    // cyclopediaitem
    // ammo
    if (flags.has_ammo() && flags.ammo()) {
        m_flags |= ThingFlagAttrAmmo;
    }
    if (flags.has_show_off_socket() && flags.show_off_socket()) {
        m_flags |= ThingFlagAttrPodium;
    }

    // reportable

    if (flags.has_upgradeclassification()) {
        m_upgradeClassification = flags.upgradeclassification().upgrade_classification();
    }

    // reverse_addons_east
    // reverse_addons_west
    // reverse_addons_south
    // reverse_addons_north

    if (flags.has_wearout() && flags.wearout()) {
        m_flags |= ThingFlagAttrWearOut;
    }

    if (flags.has_clockexpire() && flags.clockexpire()) {
        m_flags |= ThingFlagAttrClockExpire;
    }

    if (flags.has_expire() && flags.expire()) {
        m_flags |= ThingFlagAttrExpire;
    }

    if (flags.has_expirestop() && flags.expirestop()) {
        m_flags |= ThingFlagAttrExpireStop;
    }

    if (flags.has_deco_kit() && flags.deco_kit()) {
        m_flags |= ThingFlagAttrExpireStop;
    }

    // proficiency flag
    if (flags.has_proficiency()) {
        if (g_game.getFeature(Otc::GameProficiency)) {
            m_proficiencyId = flags.proficiency().id();
            m_flags |= ThingFlagAttrProficiency;
        }
    }

    // skill wheel gem
    if (flags.has_skillwheel_gem()) {
        m_skillWheelGem.gem_quality_id = flags.skillwheel_gem().gem_quality_id();
        m_skillWheelGem.vocation_id = flags.skillwheel_gem().vocation_id();
        m_flags |= ThingFlagAttrSkillWheelGem;
    }

    if (flags.has_dual_wielding() && flags.dual_wielding()) {
        m_flags |= ThingFlagAttrDualWield;
    }
}

void ThingType::unserialize(const uint16_t clientId, const ThingCategory category, const FileStreamPtr& fin)
{
    m_null = false;
    m_id = clientId;
    m_category = category;

    int count = 0;
    int attr = -1;
    bool done = false;
    for (int i = 0; i < ThingLastAttr; ++i) {
        ++count;
        attr = fin->getU8();
        if (attr == ThingLastAttr) {
            done = true;
            break;
        }

        if (g_game.getClientVersion() >= 1000) {
            /* In 10.10+ all attributes from 16 and up were
             * incremented by 1 to make space for 16 as
             * "No Movement Animation" flag.
             */
            if (attr == 16)
                attr = ThingAttrNoMoveAnimation;
            else if (attr == 254) { // Usable
                attr = ThingAttrUsable;
            } else if (attr == 35) { // Default Action
                attr = ThingAttrDefaultAction;
            } else if (attr > 16)
                attr -= 1;
        } else if (g_game.getClientVersion() >= 860) {
            /* Default attribute values follow
             * the format of 8.6-9.86.
             * Therefore no changes here.
             */
        } else if (g_game.getClientVersion() >= 780) {
            /* In 7.80-8.54 all attributes from 8 and higher were
             * incremented by 1 to make space for 8 as
             * "Item Charges" flag.
             */
            if (attr == 8) {
                attr = ThingAttrChargeable;
                continue;
            }
            if (attr > 8)
                attr -= 1;
        } else if (g_game.getClientVersion() >= 755) {
            /* In 7.55-7.72 attributes 23 is "Floor Change". */
            if (attr == 23)
                attr = ThingAttrFloorChange;
        } else if (g_game.getClientVersion() >= 740) {
            /* In 7.4-7.5 attribute "Ground Border" did not exist
             * attributes 1-15 have to be adjusted.
             * Several other changes in the format.
             */
            if (attr > 0 && attr <= 15)
                attr += 1;
            else if (attr == 16)
                attr = ThingAttrLight;
            else if (attr == 17)
                attr = ThingAttrFloorChange;
            else if (attr == 18)
                attr = ThingAttrFullGround;
            else if (attr == 19)
                attr = ThingAttrElevation;
            else if (attr == 20)
                attr = ThingAttrDisplacement;
            else if (attr == 22)
                attr = ThingAttrMinimapColor;
            else if (attr == 23)
                attr = ThingAttrRotateable;
            else if (attr == 24)
                attr = ThingAttrLyingCorpse;
            else if (attr == 25)
                attr = ThingAttrHangable;
            else if (attr == 26)
                attr = ThingAttrHookSouth;
            else if (attr == 27)
                attr = ThingAttrHookEast;
            else if (attr == 28)
                attr = ThingAttrAnimateAlways;

            /* "Multi Use" and "Force Use" are swapped */
            if (attr == ThingAttrMultiUse)
                attr = ThingAttrForceUse;
            else if (attr == ThingAttrForceUse)
                attr = ThingAttrMultiUse;
        }

        const auto thingAttr = static_cast<ThingAttr>(attr);
        m_flags |= thingAttrToThingFlagAttr(thingAttr);

        switch (attr) {
            case ThingAttrDisplacement:
            {
                if (g_game.getClientVersion() >= 755) {
                    if (g_game.getFeature(Otc::GameNegativeOffset)) {
                        m_displacement.x = fin->get16();
                        m_displacement.y = fin->get16();
                    } else {
                        m_displacement.x = fin->getU16();
                        m_displacement.y = fin->getU16();
                    }
                } else {
                    m_displacement.x = 8;
                    m_displacement.y = 8;
                }
                break;
            }
            case ThingAttrLight:
            {
                m_light.intensity = fin->getU16();
                m_light.color = fin->getU16();
                break;
            }
            case ThingAttrMarket:
            {
                m_market.category = static_cast<ITEM_CATEGORY>(fin->getU16());
                m_market.tradeAs = fin->getU16();
                m_market.showAs = fin->getU16();
                m_market.name = fin->getString();
                m_market.restrictVocation = fin->getU16();
                m_market.requiredLevel = fin->getU16();
                break;
            }
            case ThingAttrElevation: m_elevation = fin->getU16(); break;
            case ThingAttrGround: m_groundSpeed = fin->getU16(); break;
            case ThingAttrWritable: m_maxTextLength = fin->getU16(); break;
            case ThingAttrWritableOnce:m_maxTextLength = fin->getU16(); break;
            case ThingAttrMinimapColor: m_minimapColor = fin->getU16(); break;
            case ThingAttrCloth: m_clothSlot = fin->getU16(); break;
            case ThingAttrLensHelp: m_lensHelp = fin->getU16(); break;
            case ThingAttrDefaultAction: m_defaultAction = static_cast<PLAYER_ACTION>(fin->getU16()); break;
        }
    }

    if (!done)
        throw Exception("corrupt data (id: {}, category: {}, count: {}, lastAttr: {})", m_id, m_category, count, attr);

    const bool hasFrameGroups = category == ThingCategoryCreature && g_game.getFeature(Otc::GameIdleAnimations);
    const uint8_t groupCount = hasFrameGroups ? fin->getU8() : 1;

    m_animationPhases = 0;
    int totalSpritesCount = 0;
    std::vector<Size> sizes;
    std::vector<int> total_sprites;

    for (int i = 0; i < groupCount; ++i) {
        uint8_t frameGroupType = FrameGroupDefault;
        if (hasFrameGroups)
            frameGroupType = fin->getU8();

        const uint8_t width = fin->getU8();
        const uint8_t height = fin->getU8();
        m_size = { width, height };
        sizes.emplace_back(m_size);
        if (width > 1 || height > 1) {
            m_realSize = std::max<int>(m_realSize, fin->getU8());
        }

        m_layers = fin->getU8();
        m_numPatternX = fin->getU8();
        m_numPatternY = fin->getU8();
        if (g_game.getClientVersion() >= 755)
            m_numPatternZ = fin->getU8();
        else
            m_numPatternZ = 1;

        const int groupAnimationsPhases = fin->getU8();
        m_animationPhases += groupAnimationsPhases;

        if (groupAnimationsPhases > 1 && g_game.getFeature(Otc::GameEnhancedAnimations)) {
            auto* animator = new Animator;
            animator->unserialize(groupAnimationsPhases, fin);

            if (frameGroupType == FrameGroupMoving)
                m_animator = animator;
            else if (frameGroupType == FrameGroupIdle)
                m_idleAnimator = animator;
        }

        const int totalSprites = m_size.area() * m_layers * m_numPatternX * m_numPatternY * m_numPatternZ * groupAnimationsPhases;
        total_sprites.push_back(totalSprites);
        if (totalSpritesCount + totalSprites > 4096)
            throw Exception("a thing type has more than 4096 sprites");

        m_spritesIndex.resize(totalSpritesCount + totalSprites);
        for (int j = totalSpritesCount; j < (totalSpritesCount + totalSprites); ++j)
            m_spritesIndex[j] = g_game.getFeature(Otc::GameSpritesU32) ? fin->getU32() : fin->getU16();

        totalSpritesCount += totalSprites;
    }
    if (sizes.size() > 1) {
        bool hasDifferentSizes = false;
        const Size& firstSize = sizes[0];
        for (size_t i = 1; i < sizes.size(); ++i) {
            if (sizes[i] != firstSize) {
                hasDifferentSizes = true;
                break;
            }
        }
        if (hasDifferentSizes) {
            for (const auto& s : sizes) {
                m_size.setWidth(std::max<int>(m_size.width(), s.width()));
                m_size.setHeight(std::max<int>(m_size.height(), s.height()));
            }
            const size_t expectedSize = m_size.area() * m_layers * m_numPatternX * m_numPatternY * m_numPatternZ * m_animationPhases;
            if (expectedSize != m_spritesIndex.size()) {
                const std::vector sprites(std::move(m_spritesIndex));
                m_spritesIndex.clear();
                m_spritesIndex.reserve(expectedSize);
                for (size_t i = 0, idx = 0; i < sizes.size(); ++i) {
                    const int totalSprites = total_sprites[i];
                    if (m_size == sizes[i]) {
                        for (int j = 0; j < totalSprites; ++j) {
                            m_spritesIndex.push_back(sprites[idx++]);
                        }
                        continue;
                    }
                    const size_t patterns = (totalSprites / sizes[i].area());
                    for (size_t p = 0; p < patterns; ++p) {
                        for (int x = 0; x < m_size.width(); ++x) {
                            for (int y = 0; y < m_size.height(); ++y) {
                                if (x < sizes[i].width() && y < sizes[i].height()) {
                                    m_spritesIndex.push_back(sprites[idx++]);
                                    continue;
                                }
                                m_spritesIndex.push_back(0);
                            }
                        }
                    }
                }
            }
        }
    }
    m_textureData.resize(m_animationPhases);
}

void ThingType::unserializeOtml(const OTMLNodePtr& node)
{
    for (const auto& node2 : node->children()) {
        if (node2->tag() == "opacity")
            m_opacity = node2->value<float>();
        else if (node2->tag() == "image")
            m_customImage = node2->value();
        else if (node2->tag() == "full-ground") {
            if (node2->value<bool>())
                m_flags &= ~ThingFlagAttrFullGround;
            else
                m_flags |= ThingFlagAttrFullGround;
        }
    }
}

void ThingType::drawWithFrameBuffer(const TexturePtr& texture, const Rect& screenRect, const Rect& textureRect, const Color& color) {
    const int size = static_cast<int>(g_gameConfig.getSpriteSize() * std::max<int>(m_size.area(), 2) * g_drawPool.getScaleFactor());
    const auto& p = (Point(size) - screenRect.size().toPoint()) / 2;
    const auto& destDiff = Rect(screenRect.topLeft() - p, Size{ size });

    g_drawPool.bindFrameBuffer(destDiff.size()); {
        // Debug
        // g_drawPool.addBoundingRect(Rect(Point(0), destDiff.size()), Color::red);

        g_drawPool.addTexturedRect(Rect(p, screenRect.size()), texture, textureRect, color);
    } g_drawPool.releaseFrameBuffer(destDiff);
    g_drawPool.resetShaderProgram();
}

void ThingType::draw(const Point& dest, const int layer, const int xPattern, const int yPattern, const int zPattern, const int animationPhase, const Color& color, const bool drawThings, LightView* lightView)
{
    // items:
    // layer - item layer (example: in old clients, a modified dat file was using this to show which tiles could be fished)
    // xPattern - ground pattern 1 / count or fluid based coordinate
    // yPattern - ground pattern 2 / count or fluid based coordinate
    // zPattern - ground pattern 3 (eg. zaoan roofs)

    // outfits:
    // layer = outfit layer (normal / mask)
    // xPattern = direction
    // yPattern = addon layer
    // zPattern = mounted state

    if (m_null || m_animationPhases == 0)
        return;

    // outfits like 126 and 127 don't have animation
    // this line fixes a bug that makes them disappear while moving
    int animationFrameId = animationPhase % m_animationPhases;

    const auto& texture = getTexture(animationFrameId);
    if (!texture) {
        // Reset any pending onlyOnce state to prevent stale opacity/shader
        // from affecting subsequent draws when texture is still loading
        g_drawPool.resetOnlyOnceParameters();
        return; // texture might not exists, neither its rects.
    }

    const auto& textureData = m_textureData[animationFrameId];

    const uint32_t frameIndex = getTextureIndex(layer, xPattern, yPattern, zPattern);
    if (frameIndex >= textureData.pos.size()) {
        g_drawPool.resetOnlyOnceParameters();
        return;
    }

    const auto& textureOffset = textureData.pos[frameIndex].offsets;
    const auto& textureRect = textureData.pos[frameIndex].rects;

    const Rect screenRect(dest + (textureOffset - m_displacement - (m_size.toPoint() - Point(1)) * g_gameConfig.getSpriteSize()) * g_drawPool.getScaleFactor(), textureRect.size() * g_drawPool.getScaleFactor());

    if (drawThings && texture) {
        const auto& newColor = m_opacity < 1.0f ? Color(color, m_opacity) : color;

        if (g_drawPool.shaderNeedFramebuffer())
            drawWithFrameBuffer(texture, screenRect, textureRect, newColor);
        else
            g_drawPool.addTexturedRect(screenRect, texture, textureRect, newColor);
    } else {
        // Reset any pending onlyOnce state when not drawing things
        // to prevent stale opacity/shader from affecting subsequent draws
        g_drawPool.resetOnlyOnceParameters();
    }

    if (lightView && hasLight()) {
        lightView->addLightSource(screenRect.center(), m_light);
    }
}

const TexturePtr& ThingType::getTexture(const int animationPhase)
{
    if (m_null) return m_textureNull;

    m_lastTimeUsage.restart();

    auto& textureData = m_textureData[animationPhase];

    if (textureData.source)
        return textureData.source;

    bool expected = false;
    if (m_loading.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) {
        bool async = g_app.isLoadingAsyncTexture();
        if (g_game.isUsingProtobuf() && g_drawPool.getCurrentType() == DrawPoolType::FOREGROUND)
            async = false;

        if (!async) {
            loadTexture(animationPhase);
            m_loading.store(false, std::memory_order_release);
            return textureData.source;
        }

        auto action = [this] {
            for (int_fast8_t i = -1; ++i < m_animationPhases;)
                loadTexture(i);
            m_loading.store(false, std::memory_order_release);
        };

        g_asyncDispatcher.detach_task(std::move(action));
    }

    return m_textureNull;
}

void ThingType::loadTexture(const int animationPhase)
{
    auto& textureData = m_textureData[animationPhase];
    if (textureData.source)
        return;

    // we don't need layers in common items, they will be pre-drawn
    int textureLayers = 1;
    int numLayers = m_layers;
    if (m_category == ThingCategoryCreature && numLayers >= 2) {
        // 5 layers: outfit base, red mask, green mask, blue mask, yellow mask
        textureLayers = 5;
        numLayers = 5;
    }

    const bool useCustomImage = animationPhase == 0 && !m_customImage.empty();
    const int indexSize = textureLayers * m_numPatternX * m_numPatternY * m_numPatternZ;
    const auto& textureSize = getBestTextureDimension(m_size.width(), m_size.height(), indexSize);
    const auto& fullImage = useCustomImage ? Image::load(m_customImage) : std::make_shared<Image>(textureSize * g_gameConfig.getSpriteSize());
    const bool protobufSupported = g_game.isUsingProtobuf();

    static Color maskColors[] = { Color::red, Color::green, Color::blue, Color::yellow };

    textureData.pos.resize(indexSize);
    for (int z = 0; z < m_numPatternZ; ++z) {
        for (int y = 0; y < m_numPatternY; ++y) {
            for (int x = 0; x < m_numPatternX; ++x) {
                for (int l = 0; l < numLayers; ++l) {
                    const bool spriteMask = m_category == ThingCategoryCreature && l > 0;
                    const int frameIndex = getTextureIndex(l % textureLayers, x, y, z);

                    const auto& framePos = Point(frameIndex % (textureSize.width() / m_size.width()) * m_size.width(),
                        frameIndex / (textureSize.width() / m_size.width()) * m_size.height()) * g_gameConfig.getSpriteSize();

                    if (!useCustomImage) {
                        if (protobufSupported) {
                            const uint32_t spriteIndex = getSpriteIndex(-1, -1, spriteMask ? 1 : l, x, y, z, animationPhase);
                            auto spriteId = m_spritesIndex[spriteIndex];
                            bool isLoading = false;
                            const auto& spriteImage = g_sprites.getSpriteImage(spriteId, isLoading);

                            if (isLoading)
                                return;

                            if (!spriteImage) {
                                g_logger.error("Failed to fetch sprite id {} for thing {} ({}, {}), layer {}, pattern {}x{}x{}, frame {}", spriteId, m_name, m_id, categoryName(m_category), l, x, y, z, animationPhase);
                                return;
                            }

                            // verifies that the first block in the lower right corner is transparent.
                            if (!spriteImage || spriteImage->hasTransparentPixel()) {
                                fullImage->setTransparentPixel(true);
                            }

                            if (spriteMask) {
                                spriteImage->overwriteMask(maskColors[(l - 1)]);
                            }

                            auto spriteSize = spriteImage->getSize() / g_gameConfig.getSpriteSize();

                            const Point& spritePos = Point(m_size.width() - spriteSize.width(), m_size.height() - spriteSize.height()) * g_gameConfig.getSpriteSize();
                            fullImage->blit(framePos + spritePos, spriteImage);
                        } else {
                            for (int h = 0; h < m_size.height(); ++h) {
                                for (int w = 0; w < m_size.width(); ++w) {
                                    const uint32_t spriteIndex = getSpriteIndex(w, h, spriteMask ? 1 : l, x, y, z, animationPhase);
                                    auto spriteId = m_spritesIndex[spriteIndex];
                                    bool isLoading = false;
                                    const auto& spriteImage = g_sprites.getSpriteImage(spriteId, isLoading);

                                    if (isLoading)
                                        return;

                                    if (!spriteImage) {
                                        // Skip blank sprites silently (clients converted with Assets Editor have blank sprites with non-zero IDs)
                                        continue;
                                    }

                                    // verifies that the first block in the lower right corner is transparent.
                                    if (h == 0 && w == 0 && (!spriteImage || spriteImage->hasTransparentPixel())) {
                                        fullImage->setTransparentPixel(true);
                                    }

                                    if (spriteMask) {
                                        spriteImage->overwriteMask(maskColors[(l - 1)]);
                                    }

                                    const Point& spritePos = Point(m_size.width() - w - 1, m_size.height() - h - 1) * g_gameConfig.getSpriteSize();
                                    fullImage->blit(framePos + spritePos, spriteImage);
                                }
                            }
                        }
                    }

                    auto& posData = textureData.pos[frameIndex];
                    posData.rects = { framePos + Point(m_size.width(), m_size.height()) * g_gameConfig.getSpriteSize() - Point(1), framePos };
                    for (int fx = framePos.x; fx < framePos.x + m_size.width() * g_gameConfig.getSpriteSize(); ++fx) {
                        for (int fy = framePos.y; fy < framePos.y + m_size.height() * g_gameConfig.getSpriteSize(); ++fy) {
                            const uint8_t* p = fullImage->getPixel(fx, fy);
                            if (p[3] == 0x00)
                                continue;

                            posData.rects.setTop(std::min<int>(fy, posData.rects.top()));
                            posData.rects.setLeft(std::min<int>(fx, posData.rects.left()));
                            posData.rects.setBottom(std::max<int>(fy, posData.rects.bottom()));
                            posData.rects.setRight(std::max<int>(fx, posData.rects.right()));
                        }
                    }

                    posData.originRects = Rect(framePos, Size(m_size.width(), m_size.height()) * g_gameConfig.getSpriteSize());
                    posData.offsets = posData.rects.topLeft() - framePos;
                }
            }
        }
    }

    if (m_opacity < 1.0f)
        fullImage->setTransparentPixel(true);

    if (m_opaque == -1)
        m_opaque = !fullImage->hasTransparentPixel();

    textureData.source = std::make_shared<Texture>(fullImage, true, false);
    textureData.source->allowAtlasCache();
}

Size ThingType::getBestTextureDimension(int w, int h, const int count)
{
    int k = 1;
    while (k < w)
        k <<= 1;
    w = k;

    k = 1;
    while (k < h)
        k <<= 1;
    h = k;

    const int numSprites = w * h * count;
    assert(numSprites <= g_gameConfig.getSpriteSize() * g_gameConfig.getSpriteSize());
    assert(w <= g_gameConfig.getSpriteSize());
    assert(h <= g_gameConfig.getSpriteSize());

    Size bestDimension = { g_gameConfig.getSpriteSize() };
    for (int i = w; i <= g_gameConfig.getSpriteSize(); i <<= 1) {
        for (int j = h; j <= g_gameConfig.getSpriteSize(); j <<= 1) {
            Size candidateDimension = { i, j };
            if (candidateDimension.area() < numSprites)
                continue;
            if ((candidateDimension.area() < bestDimension.area()) ||
                (candidateDimension.area() == bestDimension.area() && candidateDimension.width() + candidateDimension.height() < bestDimension.width() + bestDimension.height()))
                bestDimension = candidateDimension;
        }
    }

    return bestDimension;
}

uint32_t ThingType::getSpriteIndex(const int w, const int h, const int l, const int x, const int y, const int z, const int a) const
{
    uint32_t index = ((((((a % m_animationPhases)
                      * m_numPatternZ + z)
                      * m_numPatternY + y)
                      * m_numPatternX + x)
                      * m_layers + l)
        * m_size.height() + h)
        * m_size.width() + w;

    if (w == -1 && h == -1) { // protobuf does not use width and height, because sprite image is the exact sprite size, not split by 32x32, so -1 is passed instead
        index = ((((a % m_animationPhases)
                 * m_numPatternZ + z)
                 * m_numPatternY + y)
            * m_numPatternX + x)
            * m_layers + l;
    }

    assert(index < m_spritesIndex.size());
    return index;
}

uint32_t ThingType::getTextureIndex(const int l, const int x, const int y, const int z) const
{
    return ((l * m_numPatternZ + z)
        * m_numPatternY + y)
        * m_numPatternX + x;
}

int ThingType::getExactSize(const int layer, const int xPattern, const int yPattern, const int zPattern, const int animationPhase)
{
    if (m_null)
        return 0;

    if (!getTexture(animationPhase)) // we must calculate it anyway.
        return 0;

    const int frameIndex = getTextureIndex(layer, xPattern, yPattern, zPattern);
    const auto& pos = m_textureData[animationPhase].pos;

    const auto& textureDataPos = pos[std::min<int>(frameIndex, pos.size() - 1)];
    const auto& size = textureDataPos.originRects.size() - textureDataPos.offsets.toSize();
    return std::max<int>(size.width(), size.height());
}

void ThingType::setPathable(const bool var)
{
    if (var == true)
        m_flags &= ~ThingFlagAttrNotPathable;
    else
        m_flags |= ThingFlagAttrNotPathable;
}

int ThingType::getExactHeight()
{
    if (m_null)
        return 0;

    if (m_exactHeight != 0)
        return m_exactHeight;

    getTexture(0);
    const int frameIndex = getTextureIndex(0, 0, 0, 0);

    const auto& textureDataPos = m_textureData[0].pos[frameIndex];
    const Size& size = textureDataPos.originRects.size() - textureDataPos.offsets.toSize();
    return m_exactHeight = size.height();
}

ThingFlagAttr ThingType::thingAttrToThingFlagAttr(const ThingAttr attr) {
    switch (attr) {
        case ThingAttrDisplacement: return ThingFlagAttrDisplacement;
        case ThingAttrLight: return ThingFlagAttrLight;
        case ThingAttrElevation: return ThingFlagAttrElevation;
        case ThingAttrFloorChange: return ThingFlagAttrFloorChange;
        case ThingAttrGround: return ThingFlagAttrGround;
        case ThingAttrWritable: return ThingFlagAttrWritable;
        case ThingAttrWritableOnce: return ThingFlagAttrWritableOnce;
        case ThingAttrMinimapColor: return ThingFlagAttrMinimapColor;
        case ThingAttrCloth: return ThingFlagAttrCloth;
        case ThingAttrLensHelp: return ThingFlagAttrLensHelp;
        case ThingAttrDefaultAction: return ThingFlagAttrDefaultAction;
        case ThingAttrUsable: return ThingFlagAttrUsable;
        case ThingAttrGroundBorder: return ThingFlagAttrGroundBorder;
        case ThingAttrOnBottom: return ThingFlagAttrOnBottom;
        case ThingAttrOnTop: return ThingFlagAttrOnTop;
        case ThingAttrContainer: return ThingFlagAttrContainer;
        case ThingAttrStackable: return ThingFlagAttrStackable;
        case ThingAttrForceUse: return ThingFlagAttrForceUse;
        case ThingAttrMultiUse: return ThingFlagAttrMultiUse;
        case ThingAttrChargeable: return ThingFlagAttrChargeable;
        case ThingAttrFluidContainer: return ThingFlagAttrFluidContainer;
        case ThingAttrSplash: return ThingFlagAttrSplash;
        case ThingAttrNotWalkable: return ThingFlagAttrNotWalkable;
        case ThingAttrNotMoveable: return ThingFlagAttrNotMoveable;
        case ThingAttrBlockProjectile: return ThingFlagAttrBlockProjectile;
        case ThingAttrNotPathable: return ThingFlagAttrNotPathable;
        case ThingAttrPickupable: return ThingFlagAttrPickupable;
        case ThingAttrHangable: return ThingFlagAttrHangable;
        case ThingAttrHookSouth: return ThingFlagAttrHookSouth;
        case ThingAttrHookEast: return ThingFlagAttrHookEast;
        case ThingAttrRotateable: return ThingFlagAttrRotateable;
        case ThingAttrDontHide: return ThingFlagAttrDontHide;
        case ThingAttrTranslucent: return ThingFlagAttrTranslucent;
        case ThingAttrLyingCorpse: return ThingFlagAttrLyingCorpse;
        case ThingAttrAnimateAlways: return ThingFlagAttrAnimateAlways;
        case ThingAttrFullGround: return ThingFlagAttrFullGround;
        case ThingAttrLook: return ThingFlagAttrLook;
        case ThingAttrWrapable: return ThingFlagAttrWrapable;
        case ThingAttrUnwrapable: return ThingFlagAttrUnwrapable;
        case ThingAttrWearOut: return ThingFlagAttrWearOut;
        case ThingAttrClockExpire: return ThingFlagAttrClockExpire;
        case ThingAttrExpire: return ThingFlagAttrExpire;
        case ThingAttrExpireStop: return ThingFlagAttrExpireStop;
        case ThingAttrPodium: return ThingFlagAttrPodium;
        case ThingAttrTopEffect: return ThingFlagAttrTopEffect;
        case ThingAttrMarket: return ThingFlagAttrMarket;
        case ThingAttrDecoKit: return ThingFlagAttrDecoKit;
        default: break;
    }

    return ThingFlagAttrNone;
}

bool ThingType::isTall(const bool useRealSize) { return useRealSize ? getRealSize() > g_gameConfig.getSpriteSize() : getHeight() > 1; }
int ThingType::getAnimationPhases() const { return m_animator ? m_animator->getAnimationPhases() : m_animationPhases; }

int ThingType::getMeanPrice() {
    static constexpr std::array<std::pair<uint32_t, uint32_t>, 3> forcedPrices = { {
        {3043, 10000},// Crystal Coin
        {3031, 1}, // Gold Coin
        {3035, 100} // Platinum Coin
    } };

    const uint32_t itemId = getId();

    const auto it = std::ranges::find_if(forcedPrices, [itemId](const auto& pair) { return pair.first == itemId; });

    if (it != forcedPrices.end()) {
        return it->second;
    }

    const auto npcCount = m_npcData.size();
    if (npcCount == 0) {
        return 0;
    }

    const int totalBuyPrice = std::accumulate(m_npcData.begin(), m_npcData.end(), 0,
        [](int sum, const auto& npc) { return sum + npc.buyPrice; });

    return totalBuyPrice / static_cast<int>(npcCount);
}

#ifdef FRAMEWORK_EDITOR
void ThingType::serialize(const FileStreamPtr& fin)
{
    for (int i = 0; i < ThingLastAttr; ++i) {
        int attr = i;
        if (g_game.getClientVersion() >= 780) {
            if (attr == ThingAttrChargeable)
                attr = ThingAttrWritable;
            else if (attr >= ThingAttrWritable)
                attr += 1;
        } else if (g_game.getClientVersion() >= 1000) {
            if (attr == ThingAttrNoMoveAnimation)
                attr = 16;
            else if (attr >= ThingAttrPickupable)
                attr += 1;
        }

        if (!hasAttr(static_cast<ThingAttr>(attr)))
            continue;

        switch (attr) {
            case ThingAttrDisplacement:
            {
                fin->addU16(m_displacement.x);
                fin->addU16(m_displacement.y);
                break;
            }
            case ThingAttrLight:
            {
                fin->addU16(m_light.intensity);
                fin->addU16(m_light.color);
                break;
            }
            case ThingAttrMarket:
            {
                fin->addU16(m_market.category);
                fin->addU16(m_market.tradeAs);
                fin->addU16(m_market.showAs);
                fin->addString(m_market.name);
                fin->addU16(m_market.restrictVocation);
                fin->addU16(m_market.requiredLevel);
                break;
            }

            case ThingAttrElevation: fin->addU16(m_elevation); break;
            case ThingAttrMinimapColor: fin->add16(m_minimapColor); break;
            case ThingAttrCloth: fin->add16(m_clothSlot); break;
            case ThingAttrLensHelp: fin->add16(m_lensHelp); break;
            case ThingAttrUsable: fin->add16(isUsable()); break;
            case ThingAttrGround:  fin->add16(isGround()); break;
            case ThingAttrWritable:   fin->add16(isWritable()); break;
            case ThingAttrWritableOnce:   fin->add16(isWritableOnce()); break;
                break;

            default:
                break;
        }
    }
    fin->addU8(ThingLastAttr);

    fin->addU8(m_size.width());
    fin->addU8(m_size.height());

    if (m_size.width() > 1 || m_size.height() > 1)
        fin->addU8(m_realSize);

    fin->addU8(m_layers);
    fin->addU8(m_numPatternX);
    fin->addU8(m_numPatternY);
    fin->addU8(m_numPatternZ);
    fin->addU8(m_animationPhases);

    if (g_game.getFeature(Otc::GameEnhancedAnimations)) {
        if (m_animationPhases > 1 && m_animator) {
            m_animator->serialize(fin);
        }
    }

    for (const int i : m_spritesIndex) {
        if (g_game.getFeature(Otc::GameSpritesU32))
            fin->addU32(i);
        else
            fin->addU16(i);
    }
}

void ThingType::exportImage(const std::string& fileName)
{
    if (m_null)
        throw Exception("cannot export null thingtype");

    if (m_spritesIndex.empty())
        throw Exception("cannot export thingtype without sprites");

    const auto& image = std::make_shared<Image>(Size(g_gameConfig.getSpriteSize() * m_size.width() * m_layers * m_numPatternX, g_gameConfig.getSpriteSize() * m_size.height() * m_animationPhases * m_numPatternY * m_numPatternZ));
    for (int z = 0; z < m_numPatternZ; ++z) {
        for (int y = 0; y < m_numPatternY; ++y) {
            for (int x = 0; x < m_numPatternX; ++x) {
                for (int l = 0; l < m_layers; ++l) {
                    for (int a = 0; a < m_animationPhases; ++a) {
                        for (int w = 0; w < m_size.width(); ++w) {
                            for (int h = 0; h < m_size.height(); ++h) {
                                image->blit(Point(g_gameConfig.getSpriteSize() * (m_size.width() - w - 1 + m_size.width() * x + m_size.width() * m_numPatternX * l),
                                            g_gameConfig.getSpriteSize() * (m_size.height() - h - 1 + m_size.height() * y + m_size.height() * m_numPatternY * a + m_size.height() * m_numPatternY * m_animationPhases * z)),
                                    g_sprites.getSpriteImage(m_spritesIndex[getSpriteIndex(w, h, l, x, y, z, a)]));
                            }
                        }
                    }
                }
            }
        }
    }

    image->savePNG(fileName);
}
#endif
