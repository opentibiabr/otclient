#include <gtest/gtest.h>

#define private public
#define protected public
#include "client/map.h"

#include "client/creature.h"
#include "client/gameconfig.h"
#include "client/tile.h"
#include "client/thingtype.h"

#undef protected
#undef private

#include <framework/core/logger.h>
#include <framework/core/resourcemanager.h>
#include <framework/graphics/texturemanager.h>

namespace {

class DummyCreature final : public Creature
{
public:
    DummyCreature()
    {
        setRemovedSilently(false);
    }

    void onPositionChange(const Position&, const Position& oldPos) override
    {
        setOldPositionSilently(oldPos);
    }

    void onAppear() override
    {
        setRemovedSilently(false);
    }

    void onDisappear() override
    {
        setRemovedSilently(true);
        setOldPositionSilently({});
    }

    ThingType* getThingType() const override
    {
        static ThingType type;

        static const bool initialized = [] {
            type.m_null = false;
            type.m_category = ThingCategoryCreature;
            type.m_size = Size(1, 1);
            type.m_realSize = 32;
            type.m_layers = 1;
            type.m_animationPhases = 1;
            type.m_opacity = 1.f;
            return true;
        }();

        (void)initialized;
        return &type;
    }

    void terminateWalk() override
    {
        m_walking = false;
        m_walkedPixels = 0;
        m_walkOffset = {};
    }
};

class DummyItem final : public Thing
{
public:
    DummyItem()
    {
        m_clientId = 1;
    }

    bool isItem() const override { return true; }

    ThingType* getThingType() const override
    {
        static ThingType type;

        static const bool initialized = [] {
            type.m_null = false;
            type.m_category = ThingCategoryItem;
            type.m_size = Size(1, 1);
            type.m_realSize = 32;
            type.m_layers = 1;
            type.m_animationPhases = 1;
            type.m_opacity = 1.f;
            return true;
        }();

        (void)initialized;
        return &type;
    }
};

class FrameworkEnvironment : public testing::Environment
{
public:
    void SetUp() override
    {
        m_previousLogLevel = g_logger.getLevel();
        g_logger.setLevel(Fw::LogFatal);
        g_resources.init(".");
        g_resources.addSearchPath(".");
        g_textures.init();
    }

    void TearDown() override
    {
        g_textures.terminate();
        g_resources.terminate();
        g_logger.setLevel(m_previousLogLevel);
    }

private:
    Fw::LogLevel m_previousLogLevel{ Fw::LogFatal };
};

[[maybe_unused]] testing::Environment* const g_frameworkEnv = testing::AddGlobalTestEnvironment(new FrameworkEnvironment);

CreaturePtr makeCreature(const uint32_t id, const Position& position)
{
    auto creature = std::make_shared<DummyCreature>();
    creature->setId(id);
    creature->setPosition(position);
    return creature;
}

ThingPtr makeItem(const Position& position)
{
    auto item = std::make_shared<DummyItem>();
    item->setPosition(position);
    return item;
}

std::vector<CreaturePtr> expectedSpectatorsFromTile(Tile& tile)
{
    std::vector<CreaturePtr> creatures;
    for (const auto& thing : tile.getThings()) {
        if (thing->isCreature()) {
            creatures.emplace_back(thing->static_self_cast<Creature>());
        }
    }
    return { creatures.rbegin(), creatures.rend() };
}

std::pair<int16_t, int16_t> expectedCreatureSpan(const Tile& tile)
{
    int16_t first = -1;
    int16_t last = -1;

    for (int16_t i = 0; i < static_cast<int16_t>(tile.m_things.size()); ++i) {
        if (!tile.m_things[i]->isCreature()) {
            continue;
        }

        if (first == -1) {
            first = i;
        }

        last = i;
    }

    return { first, last };
}

} // namespace

TEST(TileSpectators, AppendSpectatorsMatchesThingOrder)
{
    const Position position(100, 100, 7);
    Tile tile(position);

    EXPECT_FALSE(tile.hasCreatures());
    EXPECT_TRUE(tile.getCreatures().empty());

    auto first = makeCreature(1, position);
    auto second = makeCreature(2, position);
    auto third = makeCreature(3, position);

    tile.addThing(first, -1);
    tile.addThing(second, -1);
    tile.addThing(third, -1);

    const auto expected = expectedSpectatorsFromTile(tile);

    std::vector<CreaturePtr> actual;
    tile.appendSpectators(actual);

    ASSERT_EQ(expected.size(), actual.size());
    EXPECT_EQ(expected, actual);

    const auto forward = tile.getCreatures();
    EXPECT_EQ(forward.size(), expected.size());

    for (size_t i = 0; i < forward.size(); ++i) {
        EXPECT_EQ(forward[i], expected[expected.size() - 1 - i]);
    }
}

TEST(TileSpectators, CreatureRangeTracksMixedInsertions)
{
    const Position position(200, 200, 7);
    Tile tile(position);

    tile.addThing(makeItem(position), -1);

    tile.addThing(makeItem(position), 0);

    auto bottom = makeCreature(1, position);
    tile.addThing(bottom, -1);

    tile.addThing(makeItem(position), -1);

    auto middle = makeCreature(2, position);
    tile.addThing(middle, -1);

    tile.addThing(makeItem(position), -1);

    auto top = makeCreature(3, position);
    tile.addThing(top, -1);

    tile.addThing(makeItem(position), -1);

    const auto expected = expectedSpectatorsFromTile(tile);

    std::vector<CreaturePtr> actual;
    tile.appendSpectators(actual);

    EXPECT_EQ(expected, actual);

    const auto [expectedFirst, expectedLast] = expectedCreatureSpan(tile);
    EXPECT_EQ(expectedFirst, tile.m_firstCreatureIndex);
    EXPECT_EQ(expectedLast, tile.m_lastCreatureIndex);
}

TEST(TileSpectators, RemovingCreaturesUpdatesSpan)
{
    const Position position(210, 210, 7);
    Tile tile(position);

    auto first = makeCreature(1, position);
    auto second = makeCreature(2, position);

    tile.addThing(makeItem(position), -1);
    tile.addThing(first, -1);
    tile.addThing(makeItem(position), -1);
    tile.addThing(second, -1);

    ASSERT_TRUE(tile.hasCreatures());

    const auto expectedBeforeRemoval = expectedSpectatorsFromTile(tile);
    ASSERT_FALSE(expectedBeforeRemoval.empty());

    std::vector<CreaturePtr> actualBeforeRemoval;
    tile.appendSpectators(actualBeforeRemoval);
    EXPECT_EQ(expectedBeforeRemoval, actualBeforeRemoval);

    const auto forwardBeforeRemoval = tile.getCreatures();
    ASSERT_EQ(expectedBeforeRemoval.size(), forwardBeforeRemoval.size());
    EXPECT_EQ(expectedBeforeRemoval.back(), forwardBeforeRemoval.front());

    const auto [expectedFirst, expectedLast] = expectedCreatureSpan(tile);
    EXPECT_EQ(expectedFirst, tile.m_firstCreatureIndex);
    EXPECT_EQ(expectedLast, tile.m_lastCreatureIndex);

    ASSERT_TRUE(tile.removeThing(first));
    EXPECT_TRUE(tile.hasCreatures());

    const auto expectedAfterFirstRemoval = expectedSpectatorsFromTile(tile);
    ASSERT_FALSE(expectedAfterFirstRemoval.empty());

    std::vector<CreaturePtr> actualAfterFirstRemoval;
    tile.appendSpectators(actualAfterFirstRemoval);
    EXPECT_EQ(expectedAfterFirstRemoval, actualAfterFirstRemoval);

    const auto forwardAfterFirstRemoval = tile.getCreatures();
    ASSERT_EQ(expectedAfterFirstRemoval.size(), forwardAfterFirstRemoval.size());
    EXPECT_EQ(expectedAfterFirstRemoval.back(), forwardAfterFirstRemoval.front());

    const auto [expectedFirstAfterRemoval, expectedLastAfterRemoval] = expectedCreatureSpan(tile);
    EXPECT_EQ(expectedFirstAfterRemoval, tile.m_firstCreatureIndex);
    EXPECT_EQ(expectedLastAfterRemoval, tile.m_lastCreatureIndex);

    ASSERT_TRUE(tile.removeThing(second));
    EXPECT_FALSE(tile.hasCreatures());
    EXPECT_TRUE(tile.getCreatures().empty());

    const auto [expectedFirstAfterSecondRemoval, expectedLastAfterSecondRemoval] = expectedCreatureSpan(tile);
    EXPECT_EQ(expectedFirstAfterSecondRemoval, tile.m_firstCreatureIndex);
    EXPECT_EQ(expectedLastAfterSecondRemoval, tile.m_lastCreatureIndex);
}

TEST(MapSpectators, AggregatesCreaturesFromTiles)
{
    const Position center(105, 205, 7);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto& tile = map.createTile(center);

    auto first = makeCreature(10, center);
    auto second = makeCreature(20, center);

    tile->addThing(first, -1);
    tile->addThing(second, -1);

    map.m_knownCreatures.try_emplace(first->getId(), first);
    map.m_knownCreatures.try_emplace(second->getId(), second);

    const auto expected = expectedSpectatorsFromTile(*tile);

    const auto inRange = map.getSpectatorsInRangeEx(center, false, 0, 0, 0, 0);
    EXPECT_EQ(expected, inRange);

    const auto byPattern = map.getSpectatorsByPattern(center, "1", Otc::North);
    EXPECT_EQ(expected, byPattern);
}

std::vector<CreaturePtr> emulateLegacySpectatorCollection(Map& map, const Position& center, const bool multiFloor, const int32_t minXRange, const int32_t maxXRange, const int32_t minYRange, const int32_t maxYRange)
{
    std::vector<CreaturePtr> result;

    uint8_t minZRange = 0;
    uint8_t maxZRange = 0;

    if (multiFloor) {
        minZRange = center.z - map.getFirstAwareFloor();
        maxZRange = map.getLastAwareFloor() - center.z;
    }

    for (int iz = -minZRange; iz <= maxZRange; ++iz) {
        for (int iy = -minYRange; iy <= maxYRange; ++iy) {
            for (int ix = -minXRange; ix <= maxXRange; ++ix) {
                const Position position = center.translated(ix, iy, iz);
                if (const auto& tile = map.getTile(position)) {
                    auto tileCreatures = tile->getCreatures();
                    result.insert(result.end(), tileCreatures.rbegin(), tileCreatures.rend());
                }
            }
        }
    }

    return result;
}

TEST(MapSpectators, AggregationMatchesLegacyTraversal)
{
    const Position center(250, 350, 6);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto centerTile = map.createTile(center);
    const auto eastTile = map.createTile(center.translated(2, 0));
    const auto northTile = map.createTile(center.translated(0, -1));
    const auto aboveTile = map.createTile(center.translated(0, 0, 1));

    auto first = makeCreature(30, center);
    auto second = makeCreature(40, center.translated(2, 0));
    auto third = makeCreature(50, center.translated(0, -1));
    auto fourth = makeCreature(60, center.translated(0, 0, 1));

    centerTile->addThing(first, -1);
    eastTile->addThing(second, -1);
    northTile->addThing(third, -1);
    aboveTile->addThing(fourth, -1);

    map.m_knownCreatures.try_emplace(first->getId(), first);
    map.m_knownCreatures.try_emplace(second->getId(), second);
    map.m_knownCreatures.try_emplace(third->getId(), third);
    map.m_knownCreatures.try_emplace(fourth->getId(), fourth);

    const bool multiFloor = true;
    const int range = 3;

    const auto expected = emulateLegacySpectatorCollection(map, center, multiFloor, range, range, range, range);
    const auto actual = map.getSpectatorsInRangeEx(center, multiFloor, range, range, range, range);

    EXPECT_EQ(expected, actual);
}

TEST(MapSpectators, RangeFiltering)
{
    const Position center(101, 101, 8);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto centerTile = map.createTile(center);
    const auto adjTile = map.createTile(center.translated(-1, -1));
    const auto farTile = map.createTile(center.translated(2, 2));

    auto c1 = makeCreature(1, center);
    auto c2 = makeCreature(2, adjTile->getPosition());
    auto c3 = makeCreature(3, farTile->getPosition());

    centerTile->addThing(c1, -1);
    adjTile->addThing(c2, -1);
    farTile->addThing(c3, -1);

    map.m_knownCreatures.try_emplace(c1->getId(), c1);
    map.m_knownCreatures.try_emplace(c2->getId(), c2);
    map.m_knownCreatures.try_emplace(c3->getId(), c3);

    {
        const auto nearSpectators = map.getSpectatorsInRangeEx(center, false, 1, 1, 1, 1);
        const std::vector<CreaturePtr> expected{ c2, c1 };
        EXPECT_EQ(expected, nearSpectators);
    }

    {
        const auto farSpectators = map.getSpectatorsInRangeEx(center, false, 2, 2, 2, 2);
        const std::vector<CreaturePtr> expected{ c2, c1, c3 };
        EXPECT_EQ(expected, farSpectators);
    }
}

TEST(MapSpectators, CreatureOrderingIsDeterministic)
{
    const Position center(180, 280, 7);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto westTile = map.createTile(center.translated(-1, 0));
    const auto centerTile = map.createTile(center);
    const auto eastTile = map.createTile(center.translated(1, 0));

    auto west = makeCreature(1, westTile->getPosition());
    auto middle = makeCreature(2, centerTile->getPosition());
    auto east = makeCreature(3, eastTile->getPosition());

    westTile->addThing(west, -1);
    centerTile->addThing(middle, -1);
    eastTile->addThing(east, -1);

    map.m_knownCreatures.try_emplace(west->getId(), west);
    map.m_knownCreatures.try_emplace(middle->getId(), middle);
    map.m_knownCreatures.try_emplace(east->getId(), east);

    const auto expected = std::vector<CreaturePtr>{ west, middle, east };

    const auto spectators = map.getSpectatorsInRangeEx(center, false, 1, 1, 0, 0);
    ASSERT_EQ(expected.size(), spectators.size());
    EXPECT_EQ(expected, spectators);

    const auto repeated = map.getSpectatorsInRangeEx(center, false, 1, 1, 0, 0);
    EXPECT_EQ(spectators, repeated);
}

TEST(MapSpectators, MultiFloorRangeIncludesVerticalNeighbors)
{
    const Position center(190, 290, 8);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto belowTile = map.createTile(center.translated(0, 0, -1));
    const auto centerTile = map.createTile(center);
    const auto aboveTile = map.createTile(center.translated(0, 0, 1));

    auto below = makeCreature(11, belowTile->getPosition());
    auto middle = makeCreature(12, centerTile->getPosition());
    auto above = makeCreature(13, aboveTile->getPosition());

    belowTile->addThing(below, -1);
    centerTile->addThing(middle, -1);
    aboveTile->addThing(above, -1);

    map.m_knownCreatures.try_emplace(below->getId(), below);
    map.m_knownCreatures.try_emplace(middle->getId(), middle);
    map.m_knownCreatures.try_emplace(above->getId(), above);

    const auto spectators = map.getSpectatorsInRangeEx(center, true, 0, 0, 0, 0);
    const auto expected = std::vector<CreaturePtr>{ below, middle, above };

    ASSERT_EQ(expected.size(), spectators.size());
    EXPECT_EQ(expected, spectators);
}

TEST(MapSpectators, UniqueCreatures)
{
    const Position center(220, 320, 7);

    Map map;
    map.m_floors.resize(g_gameConfig.getMapMaxZ() + 1);
    map.m_centralPosition = center;

    const auto firstTile = map.createTile(center);
    const auto secondTile = map.createTile(center.translated(1, 0));

    auto shared = makeCreature(42, firstTile->getPosition());

    firstTile->addThing(shared, -1);
    secondTile->addThing(shared, -1);

    map.m_knownCreatures.try_emplace(shared->getId(), shared);

    const auto spectators = map.getSpectatorsInRangeEx(center, false, 1, 1, 0, 0);
    ASSERT_EQ(1u, spectators.size());
    EXPECT_EQ(shared, spectators.front());
}
