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

#include <framework/graphics/bitmapfont.h>
#include <framework/otml/declarations.h>

 // @bindclass
class GameConfig
{
public:
    void init();
    void terminate();

    uint8_t getSpriteSize() { return m_spriteSize; }
    uint16_t getLastSupportedVersion() const { return m_lastSupportedVersion; }
    bool drawTyping() const { return m_drawTyping; }
    std::string getTypingIcon() const { return m_typingIcon; }

    Size getMapViewPort() const { return m_mapViewPort; }
    uint8_t getMapMaxZ() const { return m_mapMaxZ; }
    uint8_t getMapSeaFloor() const { return m_mapSeaFloor; }
    uint8_t getMapUndergroundFloorRange() const { return m_mapUndergroundFloorRange; }
    uint8_t getMapAwareUndergroundFloorRange() const { return m_mapAwareUndergroundFloorRange; }

    uint8_t getTileMaxElevation() const { return m_tileMaxElevation; }
    uint8_t getTileMaxThings() const { return m_tileMaxThings; }
    uint8_t getTileTransparentFloorViewRange() const { return m_tileTransparentFloorViewRange; }

    bool isDrawingInformationByWidget() { return m_drawInformationByWidget; }
    bool isForcingNewWalkingFormula() const { return m_forceNewWalkingFormula; }
    bool isAdjustCreatureInformationBasedCropSize() { return m_adjustCreatureInformationBasedCropSize; }
    bool isUseCropSizeForUIDraw() { return m_useCropSizeForUIDraw; }
    uint16_t getShieldBlinkTicks() { return m_shieldBlinkTicks; }
    uint16_t getVolatileSquareDuration() const { return m_volatileSquareDuration; }

    uint16_t getInvisibleTicksPerFrame() const { return m_invisibleTicksPerFrame; }
    uint16_t getItemTicksPerFrame() const { return m_itemTicksPerFrame; }
    uint16_t getEffectTicksPerFrame() const { return m_effectTicksPerFrame; }
    uint16_t getMissileTicksPerFrame() const { return m_missileTicksPerFrame; }
    uint16_t getAnimatedTextDuration() const { return m_animatedTextDuration; }
    uint16_t getStaticDurationPerCharacter() const { return m_staticDurationPerCharacter; }
    uint16_t getMinStatictextDuration() const { return m_minStatictextDuration; }

    double getPlayerDiagonalWalkSpeed() const { return m_playerDiagonalWalkSpeed; }
    double getCreatureDiagonalWalkSpeed() const { return m_creatureDiagonalWalkSpeed; }

    BitmapFontPtr getCreatureNameFont()  const { return m_creatureNameFont; }
    BitmapFontPtr getAnimatedTextFont()  const { return m_animatedTextFont; }
    BitmapFontPtr getStaticTextFont()  const { return m_staticTextFont; }
    BitmapFontPtr getWidgetTextFont()  const { return m_widgetTextFont; }

    std::string getCreatureNameFontName() { return m_creatureNameFont->getName(); }
    std::string getAnimatedTextFontName() { return m_animatedTextFont->getName(); }
    std::string getStaticTextFontName() { return m_staticTextFont->getName(); }
    std::string getWidgetTextFontName() { return m_widgetTextFont->getName(); }

    void loadFonts();

private:
    void loadGameNode(const OTMLNodePtr& node);
    void loadFontNode(const OTMLNodePtr& node);
    void loadMapNode(const OTMLNodePtr& node);
    void loadTileNode(const OTMLNodePtr& node);
    void loadCreatureNode(const OTMLNodePtr& node);
    void loadPlayerNode(const OTMLNodePtr& node);
    void loadRenderNode(const OTMLNodePtr& node);

    // Game
    uint8_t m_spriteSize{ 32 };
    uint16_t m_lastSupportedVersion{ 1511 };
    bool m_drawTyping{ false };
    std::string m_typingIcon{ "/images/game/console/typing" };

    // Map
    Size m_mapViewPort{ 8,6 };
    uint8_t m_mapMaxZ{ 15 };
    uint8_t m_mapSeaFloor{ 7 };
    uint8_t m_mapUndergroundFloorRange{ 2 };
    uint8_t m_mapAwareUndergroundFloorRange{ 2 };

    // Tile
    uint8_t m_tileMaxElevation{ 24 };
    uint8_t m_tileMaxThings{ 10 };
    uint8_t m_tileTransparentFloorViewRange{ 2 };

    // Creature
    bool m_drawInformationByWidget{ false };
    bool m_forceNewWalkingFormula{ true };
    bool m_adjustCreatureInformationBasedCropSize{ false };
    bool m_useCropSizeForUIDraw{ true };
    uint16_t m_shieldBlinkTicks{ 500 };
    uint16_t m_volatileSquareDuration{ 1000 };
    double m_creatureDiagonalWalkSpeed{ 3 };

    // Player
    double m_playerDiagonalWalkSpeed{ 3 };

    // Render
    uint16_t m_invisibleTicksPerFrame{ 500 };
    uint16_t m_itemTicksPerFrame{ 500 };
    uint16_t m_effectTicksPerFrame{ 75 };
    uint16_t m_missileTicksPerFrame{ 75 };
    uint16_t m_animatedTextDuration{ 1000 };
    uint16_t m_staticDurationPerCharacter{ 60 };
    uint16_t m_minStatictextDuration{ 3000 };

    std::string m_creatureNameFontName{ "verdana-11px-rounded" };
    std::string m_animatedTextFontName{ "verdana-11px-rounded" };
    std::string m_staticTextFontName{ "verdana-11px-rounded" };
    std::string m_widgetTextFontName{ "verdana-11px-antialised" };

    BitmapFontPtr m_creatureNameFont;
    BitmapFontPtr m_animatedTextFont;
    BitmapFontPtr m_staticTextFont;
    BitmapFontPtr m_widgetTextFont;

    friend class FontManager;
};

extern GameConfig g_gameConfig;