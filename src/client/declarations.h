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

#include "global.h"

enum FrameGroupType : uint8_t;
enum ThingCategory : uint8_t;
enum StaticDataCategory : uint8_t;
enum ThingAttr : uint8_t;
enum ThingFlagAttr : uint64_t;
enum STACK_PRIORITY : uint8_t;
enum PLAYER_ACTION : uint8_t;
enum ITEM_CATEGORY : uint8_t;
enum SpriteMask : uint8_t;

// core
class Map;
class Game;
class MapView;
class LightView;
class Tile;
class Thing;
class Item;
class Container;
class Creature;
class Monster;
class Npc;
class Player;
class LocalPlayer;
class Effect;
class Missile;
class AnimatedText;
class StaticText;
class Animator;
class ThingType;
class ItemType;
class TileBlock;
class AttachedEffect;
class AttachableObject;
class Paperdoll;

#ifdef FRAMEWORK_EDITOR
class House;
class Town;
class CreatureType;
class Spawn;
#endif

using MapViewPtr = std::shared_ptr<MapView>;
using LightViewPtr = std::unique_ptr<LightView>;
using TilePtr = std::shared_ptr<Tile>;
using ThingPtr = std::shared_ptr<Thing>;
using ItemPtr = std::shared_ptr<Item>;
using ContainerPtr = std::shared_ptr<Container>;
using CreaturePtr = std::shared_ptr<Creature>;
using MonsterPtr = std::shared_ptr<Monster>;
using NpcPtr = std::shared_ptr<Npc>;
using PlayerPtr = std::shared_ptr<Player>;
using LocalPlayerPtr = std::shared_ptr<LocalPlayer>;
using EffectPtr = std::shared_ptr<Effect>;
using MissilePtr = std::shared_ptr<Missile>;
using AnimatedTextPtr = std::shared_ptr<AnimatedText>;
using StaticTextPtr = std::shared_ptr<StaticText>;
using ThingTypePtr = std::shared_ptr<ThingType>;
using ItemTypePtr = std::shared_ptr<ItemType>;
using AttachedEffectPtr = std::shared_ptr<AttachedEffect>;
using AttachableObjectPtr = std::shared_ptr<AttachableObject>;
using PaperdollPtr = std::shared_ptr<Paperdoll>;

#ifdef FRAMEWORK_EDITOR
using HousePtr = std::shared_ptr<House>;
using TownPtr = std::shared_ptr<Town>;
using CreatureTypePtr = std::shared_ptr<CreatureType>;
using SpawnPtr = std::shared_ptr<Spawn>;

using HouseList = std::list<HousePtr>;
using TownList = std::list<TownPtr>;
using CreatureMap = std::unordered_map<Position, CreatureTypePtr, Position::Hasher>;
using SpawnMap = std::unordered_map<Position, SpawnPtr, Position::Hasher>;
#endif

using ThingList = std::vector<ThingPtr>;
using ThingTypeList = std::vector<ThingTypePtr>;
using ItemTypeList = std::vector<ItemTypePtr>;

using TileList = std::list<TilePtr>;
using ItemVector = std::vector<ItemPtr>;

// net
class ProtocolLogin;
class ProtocolGame;

using ProtocolGamePtr = std::shared_ptr<ProtocolGame>;
using ProtocolLoginPtr = std::shared_ptr<ProtocolLogin>;

// ui
class UIItem;
class UIEffect;
class UIMissile;
class UICreature;
class UIGraph;
class UIMap;
class UIMinimap;
class UIProgressRect;
class UIMapAnchorLayout;
class UIPositionAnchor;
class UISprite;

using UIItemPtr = std::shared_ptr<UIItem>;
using UIEffectPtr = std::shared_ptr<UIEffect>;
using UIMissilePtr = std::shared_ptr<UIMissile>;
using UICreaturePtr = std::shared_ptr<UICreature>;
using UIGraphPtr = std::shared_ptr<UIGraph>;
using UISpritePtr = std::shared_ptr<UISprite>;
using UIMapPtr = std::shared_ptr<UIMap>;
using UIMinimapPtr = std::shared_ptr<UIMinimap>;
using UIProgressRectPtr = std::shared_ptr<UIProgressRect>;
using UIMapAnchorLayoutPtr = std::shared_ptr<UIMapAnchorLayout>;
using UIPositionAnchorPtr = std::shared_ptr<UIPositionAnchor>;