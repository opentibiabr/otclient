---@meta

---@class Color
---@field r integer
---@field g integer
---@field b integer
---@field a integer

---@class Position
---@field x integer
---@field y integer
---@field z integer

---@class Size
---@field width integer
---@field height integer

---@class Point
---@field x integer
---@field y integer

---@class Rect
---@field x integer
---@field y integer
---@field width integer
---@field height integer

---@class Light
---@field color integer
---@field intensity integer

---@class Outfit
---@field type integer
---@field auxType integer
---@field addons? integer
---@field head integer
---@field body integer
---@field legs integer
---@field feet integer
---@field mount? integer

---@alias OTMLNode table<string | integer, any>

---@class UnjustifiedPoints
---@field killsDay integer
---@field killsDayRemaining integer
---@field killsWeek integer
---@field killsWeekRemaining integer
---@field killsMonth integer
---@field killsMonthRemaining integer
---@field skullTime integer

---@class MarketData
---@field category integer
---@field name string
---@field requiredLevel integer
---@field restrictVocation integer
---@field showAs integer
---@field tradeAs integer

---@alias WidgetType
--- |UIItem
--- |UISprite
--- |UICreature
--- |UIMap
--- |UIMinimap
--- |UIProgressRect
--- |UIGraph
--- |UITextEdit
--- |UIQrCode
--- |UIParticles

--------------------------------
------- Global Functions -------
--------------------------------

---@param color integer
---@return Color
function getOutfitColor(color) end

---@param fromPos Position | string
---@param toPos Position | string
---@return number
function getAngleFromPos(fromPos, toPos) end

---@param fromPos Position | string
---@param toPos Position | string
---@return integer
function getDirectionFromPos(fromPos, toPos) end

---@param v string
---@return Rect
function torect(v) end

---@param v string
---@return Point
function topoint(v) end

---@param v string
---@return Color
function tocolor(v) end

---@param v string
---@return Size
function tosize(v) end

---@param v Rect
---@return string
function recttostring(v) end

---@param v Point
---@return string
function pointtostring(v) end

---@param v Color
---@return string
function colortostring(v) end

---@param v Size
---@return string
function sizetostring(v) end

---@param v number
---@return string
function iptostring(v) end

---@param v string
---@return number
function stringtoip(v) end

---@param a number
---@param b integer
---@return number[]
function listSubnetAddresses(a, b) end

---@param v string
---@return string
function ucwords(v) end

---@param s string
---@param exp string
---@return string[][]
function regexMatch(s, exp) end

--------------------------------
----------- g_things -----------
--------------------------------

---@class g_things
g_things = {}

---@param file string
---@return boolean
function g_things.loadAppearances(file) end

---@param file string
---@return boolean
function g_things.loadStaticData(file) end

---@param file string
---@return boolean
function g_things.loadDat(file) end

---@param file string
---@return boolean
function g_things.loadOtml(file) end

---@return boolean
function g_things.isDatLoaded() end

---@return number
function g_things.getDatSignature() end

---@return integer
function g_things.getContentRevision() end

---@param id integer
---@param category integer
---@return ThingType | nil
function g_things.getThingType(id, category) end

---@param category integer
---@return ThingType[]
function g_things.getThingTypes(category) end

---@param attr integer
---@param category integer
---@return ThingType[]
function g_things.findThingTypeByAttr(attr, category) end

---@param raceId integer
---@return RaceType[]
function g_things.getRaceData(raceId) end

---@param searchString string
---@return Vector<RaceType>
function g_things.getRacesByName(searchString) end

---* FRAMEWORK_EDITOR
---@param id integer
---@return ThingType | nil
function g_things.getItemType(id) end

---* FRAMEWORK_EDITOR
---@param id integer
---@return ThingType | nil
function g_things.findItemTypeByClientId(id) end

---* FRAMEWORK_EDITOR
---@param name string
---@return ThingType | nil
function g_things.findItemTypeByName(name) end

---* FRAMEWORK_EDITOR
---@param name string
---@return ThingType[]
function g_things.findItemTypesByName(name) end

---* FRAMEWORK_EDITOR
---@param name string
---@return ThingType[]
function g_things.findItemTypesByString(name) end

---* FRAMEWORK_EDITOR
---@param category integer
---@return ThingType[]
function g_things.findItemTypeByCategory(category) end

---* FRAMEWORK_EDITOR
---@param fileName string
function g_things.saveDat(fileName) end

---* FRAMEWORK_EDITOR
---@param file string
function g_things.loadOtb(file) end

---* FRAMEWORK_EDITOR
---@param file string
function g_things.loadXml(file) end

---* FRAMEWORK_EDITOR
---@return boolean
function g_things.isOtbLoaded() end

--------------------------------
----------- g_houses -----------
--------------------------------

---* FRAMEWORK_EDITOR
---@class g_houses
g_houses = {}

function g_houses.clear() end

---@param fileName string
function g_houses.load(fileName) end

---@param fileName string
function g_houses.save(fileName) end

---@param houseId number
---@return House | nil
function g_houses.getHouse(houseId) end

---@param name string
---@return House | nil
function g_houses.getHouseByName(name) end

---@param house House
function g_houses.addHouse(house) end

---@param houseId number
function g_houses.removeHouse(houseId) end

---@return House[]
function g_houses.getHouseList() end

---@param townId number
---@return House[]
function g_houses.filterHouses(townId) end

function g_houses.sort() end

--------------------------------
----------- g_towns ------------
--------------------------------

---* FRAMEWORK_EDITOR
---@class g_towns
g_towns = {}

---@param townId number
---@return Town | nil
function g_towns.getTown(townId) end

---@param name string
---@return Town | nil
function g_towns.getTownByName(name) end

---@param town Town
function g_towns.addTown(town) end

---@param townId number
function g_towns.removeTown(townId) end

---@return Town[]
function g_towns.getTowns() end

function g_towns.sort() end

--------------------------------
---------- g_sprites -----------
--------------------------------

---@class g_sprites
g_sprites = {}

---@param file string
---@return boolean
function g_sprites.loadSpr(file) end

function g_sprites.unload() end

---@return boolean
function g_sprites.isLoaded() end

---@return number
function g_sprites.getSprSignature() end

---@return integer
function g_sprites.getSpritesCount() end

---* FRAMEWORK_EDITOR
---@param fileName string
function g_sprites.saveSpr(fileName) end

--------------------------------
------ g_spriteAppearances -----
--------------------------------

---@class g_spriteAppearances
g_spriteAppearances = {}

---@param id integer
---@param file string
function g_spriteAppearances.saveSpriteToFile(id, file) end

---@param id integer
---@param file string
function g_spriteAppearances.saveSheetToFileBySprite(id, file) end

--------------------------------
------------ g_map -------------
--------------------------------

---@class g_map
g_map = {}

---@param pos Position | string
---@return boolean
function g_map.isLookPossible(pos) end

---@param pos Position | string
---@param firstFloor? integer 0
---@return boolean
function g_map.isCovered(pos, firstFloor) end

---@param pos Position | string
---@param firstFloor? integer 0
---@return boolean
function g_map.isCompletelyCovered(pos, firstFloor) end

---@param thing Thing
---@param pos Position | string
---@param stackPos? integer -1
function g_map.addThing(thing, pos, stackPos) end

---@param txt StaticText
---@param pos Position | string
function g_map.addStaticText(txt, pos) end

---@param txt AnimatedText
---@param pos Position | string
function g_map.addAnimatedText(txt, pos) end

---@param pos Position | string
---@param stackPos integer
---@return Thing | nil
function g_map.getThing(pos, stackPos) end

---@param pos Position | string
---@param stackPos integer
---@return boolean
function g_map.removeThingByPos(pos, stackPos) end

---@param thing Thing
---@return boolean
function g_map.removeThing(thing) end

---@param thing Thing
function g_map.removeThingColor(thing) end

---@param thing Thing
---@param color Color | string
function g_map.colorizeThing(thing, color) end

function g_map.clean() end

---@param pos Position | string
function g_map.cleanTile(pos) end

function g_map.cleanTexts() end

---@param pos Position | string
---@return Tile | nil
function g_map.getTile(pos) end

---@param floor? integer -1
---@return Tile[]
function g_map.getTiles(floor) end

---@param centralPosition Position | string
function g_map.setCentralPosition(centralPosition) end

---@return Position
function g_map.getCentralPosition() end

---@param id number
---@return Creature | nil
function g_map.getCreatureById(id) end

---@param id number
function g_map.removeCreatureById(id) end

---@param centerPos Position | string
---@param multiFloor boolean
---@return Creature[]
function g_map.getSpectators(centerPos, multiFloor) end

---@param centerPos Position | string
---@param multiFloor boolean
---@param xRange integer
---@param yRange integer
---@return Creature[]
function g_map.getSpectatorsInRange(centerPos, multiFloor, xRange, yRange) end

---@param centerPos Position | string
---@param multiFloor boolean
---@param minXRange integer
---@param maxXRange integer
---@param minYRange integer
---@param maxYRange integer
---@return Creature[]
function g_map.getSpectatorsInRangeEx(centerPos, multiFloor, minXRange, maxXRange, minYRange, maxYRange) end

---@param start Position | string
---@param goal Position | string
---@param maxComplexity integer
---@param flags? integer 0
---@return integer[], integer
function g_map.findPath(start, goal, maxComplexity, flags) end

---@param pos Position | string
---@return Tile | nil
function g_map.createTile(pos) end

---@param w integer
function g_map.setWidth(w) end

---@param h integer
function g_map.setHeight(h) end

---@return Size
function g_map.getSize() end

---* FRAMEWORK_EDITOR
---@param fileName string
function g_map.loadOtbm(fileName) end

---* FRAMEWORK_EDITOR
---@param fileName string
function g_map.saveOtbm(fileName) end

---* FRAMEWORK_EDITOR
---@param fileName string
---@return boolean
function g_map.loadOtcm(fileName) end

---* FRAMEWORK_EDITOR
---@param fileName string
function g_map.saveOtcm(fileName) end

---* FRAMEWORK_EDITOR
---@return string
function g_map.getHouseFile() end

---* FRAMEWORK_EDITOR
---@param file string
function g_map.setHouseFile(file) end

---* FRAMEWORK_EDITOR
---@return string
function g_map.getSpawnFile() end

---* FRAMEWORK_EDITOR
---@param file string
function g_map.setSpawnFile(file) end

---* FRAMEWORK_EDITOR
---@param desc string
function g_map.setDescription(desc) end

---* FRAMEWORK_EDITOR
---@return string[]
function g_map.getDescriptions() end

---* FRAMEWORK_EDITOR
function g_map.clearDescriptions() end

---* FRAMEWORK_EDITOR
---@param zone number
---@param show boolean
function g_map.setShowZone(zone, show) end

---* FRAMEWORK_EDITOR
---@param show boolean
function g_map.setShowZones(show) end

---* FRAMEWORK_EDITOR
---@param zone number
---@param color Color | string
function g_map.setZoneColor(zone, color) end

---* FRAMEWORK_EDITOR
---@param opacity number
function g_map.setZoneOpacity(opacity) end

---* FRAMEWORK_EDITOR
---@return number
function g_map.getZoneOpacity() end

---* FRAMEWORK_EDITOR
---@param zone number
---@return Color
function g_map.getZoneColor(zone) end

---* FRAMEWORK_EDITOR
---@return boolean
function g_map.showZones() end

---* FRAMEWORK_EDITOR
---@param zone number
---@return boolean
function g_map.showZone(zone) end

---* FRAMEWORK_EDITOR
---@param force boolean
function g_map.setForceShowAnimations(force) end

---* FRAMEWORK_EDITOR
---@return boolean
function g_map.isForcingAnimations() end

---* FRAMEWORK_EDITOR
---@return boolean
function g_map.isShowingAnimations() end

---* FRAMEWORK_EDITOR
---@param show boolean
function g_map.setShowAnimations(show) end

---@param opacity number
function g_map.beginGhostMode(opacity) end

function g_map.endGhostMode() end

---@param clientId integer
---@param max number
---@return table<Position, Item>
function g_map.findItemsById(clientId, max) end

---@param enable boolean
function g_map.setFloatingEffect(enable) end

---@return boolean
function g_map.isDrawingFloatingEffects() end

---@param pos Position | string
---@return integer
function g_map.getMinimapColor(pos) end

---@param fromPos Position | string
---@param toPos Position | string
---@return boolean
function g_map.isSightClear(fromPos, toPos) end

---@param start Position | string
---@param maxDistance integer
---@param params table<string, string>
---@return table<string, [integer, integer, integer, string]>
function g_map.findEveryPath(start, maxDistance, params) end

---@param centerPos Position | string
---@param pattern string
---@param direction integer
---@return Creature[]
function g_map.getSpectatorsByPattern(centerPos, pattern, direction) end

--------------------------------
---------- g_minimap -----------
--------------------------------

---@class g_minimap
g_minimap = {}

function g_minimap.clean() end

---@param fileName string
---@param topLeft Position | string
---@param colorFactor number
---@return boolean
function g_minimap.loadImage(fileName, topLeft, colorFactor) end

---@param fileName string
---@param mapRect Rect
function g_minimap.saveImage(fileName, mapRect) end

---@param fileName string
---@return boolean
function g_minimap.loadOtmm(fileName) end

---@param fileName string
function g_minimap.saveOtmm(fileName) end

--------------------------------
--------- g_creatures ----------
--------------------------------

---* FRAMEWORK_EDITOR
---@class g_creatures
g_creatures = {}

---@return CreatureType[]
function g_creatures.getCreatures() end

---@param name string
---@return CreatureType | nil
function g_creatures.getCreatureByName(name) end

---@param look integer
---@return CreatureType | nil
function g_creatures.getCreatureByLook(look) end

---@param centerPos Position | string
---@return Spawn | nil
function g_creatures.getSpawn(centerPos) end

---@param pos Position | string
---@return Spawn | nil
function g_creatures.getSpawnForPlacePos(pos) end

---@param centerPos Position | string
---@param radius integer
---@return Spawn
function g_creatures.addSpawn(centerPos, radius) end

---@param file string
function g_creatures.loadMonsters(file) end

---@param folder string
function g_creatures.loadNpcs(folder) end

---@param file string
function g_creatures.loadSingleCreature(file) end

---@param fileName string
function g_creatures.loadSpawns(fileName) end

---@param fileName string
function g_creatures.saveSpawns(fileName) end

---@return boolean
function g_creatures.isLoaded() end

---@return boolean
function g_creatures.isSpawnLoaded() end

function g_creatures.clear() end

function g_creatures.clearSpawns() end

---@return Spawn[]
function g_creatures.getSpawns() end

---@param spawn Spawn
function g_creatures.deleteSpawn(spawn) end

--------------------------------
------------ g_game ------------
--------------------------------

---@class g_game
g_game = {}

---@param account string
---@param password string
---@param worldName string
---@param worldHost string
---@param worldPort integer
---@param characterName string
---@param authenticatorToken string
---@param sessionKey string
---@param recordTo string
function g_game.loginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken,
                           sessionKey, recordTo)
end

function g_game.cancelLogin() end

function g_game.forceLogout() end

function g_game.safeLogout() end

---@param direction integer
---@param isKeyDown? boolean false
---@return boolean
function g_game.walk(direction, isKeyDown) end

---@param scheduleLastWalk boolean
function g_game.setScheduleLastWalk(scheduleLastWalk) end

---@param dirs integer[]
---@param startPos Position | string
function g_game.autoWalk(dirs, startPos) end

---@param direction integer
function g_game.forceWalk(direction) end

---@param direction integer
function g_game.turn(direction) end

function g_game.stop() end

---@param thing Thing
---@param inBattleList? boolean false
function g_game.look(thing, inBattleList) end

---@param thing Thing
---@param toPos Position | string
---@param count integer
function g_game.move(thing, toPos, count) end

---@param thing Thing
---@param count integer
function g_game.moveToParentContainer(thing, count) end

---@param thing Thing
function g_game.rotate(thing) end

---@param thing Thing
function g_game.wrap(thing) end

---@param thing Thing
function g_game.use(thing) end

---@param item Item
---@param toThing Thing
function g_game.useWith(item, toThing) end

---@param itemId integer
function g_game.useInventoryItem(itemId) end

---@param itemId integer
---@param toThing Thing
function g_game.useInventoryItemWith(itemId, toThing) end

---@param itemId number
---@param subType integer
---@return Item | nil
function g_game.findItemInContainers(itemId, subType) end

---@param item Item
---@param previousContainer? Container
---@return integer
function g_game.open(item, previousContainer) end

---@param container Container
function g_game.openParent(container) end

---@param container Container
function g_game.close(container) end

---@param container Container
function g_game.refreshContainer(container) end

---@param creature Creature
function g_game.attack(creature) end

function g_game.cancelAttack() end

---@param creature Creature
function g_game.follow(creature) end

function g_game.cancelFollow() end

function g_game.cancelAttackAndFollow() end

---@param message string
function g_game.talk(message) end

---@param mode integer
---@param channelId integer
---@param message string
function g_game.talkChannel(mode, channelId, message) end

---@param mode integer
---@param receiver string
---@param message string
function g_game.talkPrivate(mode, receiver, message) end

---@param receiver string
function g_game.openPrivateChannel(receiver) end

function g_game.requestChannels() end

---@param channelId integer
function g_game.joinChannel(channelId) end

---@param channelId integer
function g_game.leaveChannel(channelId) end

function g_game.closeNpcChannel() end

function g_game.openOwnChannel() end

---@param name string
function g_game.inviteToOwnChannel(name) end

---@param name string
function g_game.excludeFromOwnChannel(name) end

---@param creatureId integer
function g_game.partyInvite(creatureId) end

---@param creatureId integer
function g_game.partyJoin(creatureId) end

---@param creatureId integer
function g_game.partyRevokeInvitation(creatureId) end

---@param creatureId integer
function g_game.partyPassLeadership(creatureId) end

function g_game.partyLeave() end

---@param active boolean
function g_game.partyShareExperience(active) end

function g_game.requestOutfit() end

---@param outfit Outfit
function g_game.changeOutfit(outfit) end

---@param name string
function g_game.addVip(name) end

---@param playerId integer
function g_game.removeVip(playerId) end

---@param playerId integer
---@param description string
---@param iconId integer
---@param notifyLogin boolean
function g_game.editVip(playerId, description, iconId, notifyLogin) end

---@param chaseMode integer
function g_game.setChaseMode(chaseMode) end

---@param fightMode integer
function g_game.setFightMode(fightMode) end

---@param pvpMode integer
function g_game.setPVPMode(pvpMode) end

---@param on boolean
function g_game.setSafeFight(on) end

---@return integer
function g_game.getChaseMode() end

---@return integer
function g_game.getFightMode() end

---@return integer
function g_game.getPVPMode() end

---@return UnjustifiedPoints
function g_game.getUnjustifiedPoints() end

---@return integer
function g_game.getOpenPvpSituations() end

---@return boolean
function g_game.isSafeFight() end

---@param item Item
function g_game.inspectNpcTrade(item) end

---@param item Item
---@param amount integer
---@param ignoreCapacity boolean
---@param buyWithBackpack boolean
function g_game.buyItem(item, amount, ignoreCapacity, buyWithBackpack) end

---@param item Item
---@param amount integer
---@param ignoreEquipped boolean
function g_game.sellItem(item, amount, ignoreEquipped) end

function g_game.closeNpcTrade() end

---@param item Item
---@param creature Creature
function g_game.requestTrade(item, creature) end

---@param counterOffer boolean
---@param index integer
function g_game.inspectTrade(counterOffer, index) end

function g_game.acceptTrade() end

function g_game.rejectTrade() end

---@param reporter string
function g_game.openRuleViolation(reporter) end

---@param reporter string
function g_game.closeRuleViolation(reporter) end

function g_game.cancelRuleViolation() end

---@param comment string
function g_game.reportBug(comment) end

---@param target string
---@param reason integer
---@param action integer
---@param comment string
---@param statement string
---@param statementId integer
---@param ipBanishment boolean
function g_game.reportRuleViolation(target, reason, action, comment, statement, statementId, ipBanishment) end

---@param a string
---@param b string
---@param c string
---@param d string
function g_game.debugReport(a, b, c, d) end

---@param id number
---@param text string
function g_game.editText(id, text) end

---@param id number
---@param doorId integer
---@param text string
function g_game.editList(id, doorId, text) end

function g_game.requestQuestLog() end

---@param questId integer
function g_game.requestQuestLine(questId) end

---@param item Item
function g_game.equipItem(item) end

---@param mount boolean
function g_game.mount(mount) end

---@param item Item
---@param index integer
function g_game.requestItemInfo(item, index) end

function g_game.ping() end

---@param delay integer
function g_game.setPingDelay(delay) end

---@param xrange integer
---@param yrange integer
function g_game.changeMapAwareRange(xrange, yrange) end

---@return boolean
function g_game.canReportBugs() end

---@return boolean
function g_game.isOnline() end

---@return boolean
function g_game.isLogging() end

---@return boolean
function g_game.isDead() end

---@return boolean
function g_game.isAttacking() end

---@return boolean
function g_game.isFollowing() end

---@return boolean
function g_game.isConnectionOk() end

---@return integer
function g_game.getPing() end

---@param index integer
---@return Container | nil
function g_game.getContainer(index) end

---@return table<integer, Container>
function g_game.getContainers() end

---@return table<integer, [string, number, string, integer, boolean]>
function g_game.getVips() end

---@return Creature | nil
function g_game.getAttackingCreature() end

---@return Creature | nil
function g_game.getFollowingCreature() end

---@return integer
function g_game.getServerBeat() end

---@return LocalPlayer | nil
function g_game.getLocalPlayer() end

---@return ProtocolGame | nil
function g_game.getProtocolGame() end

---@return integer
function g_game.getProtocolVersion() end

---@param version integer
function g_game.setProtocolVersion(version) end

---@return integer
function g_game.getClientVersion() end

---@param version integer
function g_game.setClientVersion(version) end

---@param os integer
function g_game.setCustomOs(os) end

---@return integer
function g_game.getOs() end

---@return string
function g_game.getCharacterName() end

---@return string
function g_game.getWorldName() end

---@return integer[]
function g_game.getGMActions() end

---@param feature integer
---@return boolean
function g_game.getFeature(feature) end

---@param feature integer
---@param enabled boolean
function g_game.setFeature(feature, enabled) end

---@param feature integer
function g_game.enableFeature(feature) end

---@param feature integer
function g_game.disableFeature(feature) end

---@return boolean
function g_game.isGM() end

---@param dialog number
---@param button integer
---@param choice integer
function g_game.answerModalDialog(dialog, button, choice) end

---@param position Position | string
function g_game.browseField(position) end

---@param cid integer
---@param index integer
function g_game.seekInContainer(cid, index) end

---@return integer
function g_game.getLastWalkDir() end

---@param offerId integer
---@param productType integer
---@param name? string
function g_game.buyStoreOffer(offerId, productType, name) end

---@param page integer
---@param entriesPerPage integer
function g_game.requestTransactionHistory(page, entriesPerPage) end

---@param categoryName string
---@param serviceType? integer 0
function g_game.requestStoreOffers(categoryName, serviceType) end

---@param serviceType? integer 0
---@param category? string
function g_game.openStore(serviceType, category) end

---@param recipient string
---@param amount integer
function g_game.transferCoins(recipient, amount) end

---@param entriesPerPage integer
function g_game.openTransactionHistory(entriesPerPage) end

function g_game.leaveMarket() end

---@param browseId integer
---@param browseType integer
function g_game.browseMarket(browseId, browseType) end

---@param type integer
---@param itemId integer
---@param itemTier integer
---@param amount integer
---@param price number
---@param anonymous integer
function g_game.createMarketOffer(type, itemId, itemTier, amount, price, anonymous) end

---@param timestamp number
---@param counter integer
function g_game.cancelMarketOffer(timestamp, counter) end

---@param timestamp number
---@param counter integer
---@param amount integer
function g_game.acceptMarketOffer(timestamp, counter, amount) end

---@param slot integer
---@param actionType integer
---@param index integer
function g_game.preyAction(slot, actionType, index) end

function g_game.preyRequest() end

---@param slot integer
---@param imbuementId integer
---@param protectionCharm boolean
function g_game.applyImbuement(slot, imbuementId, protectionCharm) end

---@param slot integer
function g_game.clearImbuement(slot) end

function g_game.closeImbuingWindow() end

---@return boolean
function g_game.isUsingProtobuf() end

---@param value boolean
function g_game.enableTileThingLuaCallback(value) end

---@return boolean
function g_game.isTileThingLuaCallbackEnabled() end

---@param itemId integer
---@param count number
---@param stackpos boolean
function g_game.stashWithdraw(itemId, count, stackpos) end

---@param position Position | string
---@param itemId integer
---@param count number
---@param stackpos boolean
---@param action number
function g_game.stashStowItem(position, itemId, count, stackpos, action) end

---@param action integer
---@param category integer
---@param vocation number
---@param world string
---@param worldType number
---@param battlEye number
---@param page number
---@param totalPages number
function g_game.requestHighscore(action, category, vocation, world, worldType, battlEye, page, totalPages) end

---@param isOpen? boolean false
function g_game.imbuementDurations(isOpen) end

---@param isOpen? boolean false
function g_game.imbuementDurations(isOpen) end

---@param playerId integer
function g_game.openWheelOfDestiny(playerId) end

---@param wheelPoints table<integer, integer>
---@param activeGems table<integer, integer>
function g_game.applyWheelOfDestiny(wheelPoints, activeGems) end

---@param variant integer
---@param item ItemPtr
function g_game.sendQuickLoot(variant, item) end

---@param filter integer
---@param size integer
---@param listedItems integer[]
function g_game.requestQuickLootBlackWhiteList(filter, size, listedItems) end

---@param action integer
---@param category integer
---@param pos Position
---@param itemId integer
---@param stackpos integer
---@param useMainAsFallback boolean
function g_game.openContainerQuickLoot(action, category, pos, itemId, stackpos, useMainAsFallback) end

--------------------------------
--------- g_gameConfig ---------
--------------------------------

---@class g_gameConfig
g_gameConfig = {}

function g_gameConfig.loadFonts() end

---@return integer
function g_gameConfig.getSpriteSize() end

---@return boolean
function g_gameConfig.isDrawingInformationByWidget() end

---@return boolean
function g_gameConfig.isAdjustCreatureInformationBasedCropSize() end

---@return integer
function g_gameConfig.getShieldBlinkTicks() end

---@return string
function g_gameConfig.getCreatureNameFontName() end

---@return string
function g_gameConfig.getAnimatedTextFontName() end

---@return string
function g_gameConfig.getStaticTextFontName() end

---@return string
function g_gameConfig.getWidgetTextFontName() end

--------------------------------
----------- g_client -----------
--------------------------------

---@class g_client
g_client = {}

---@param v number
function g_client.setEffectAlpha(v) end

---@param v number
function g_client.setMissileAlpha(v) end

--------------------------------
------ g_attachedEffects -------
--------------------------------

---@class g_attachedEffects
g_attachedEffects = {}

---@param id integer
---@return AttachedEffect | nil
function g_attachedEffects.getById(id) end

---@param id integer
---@param name string
---@param thingId integer
---@param category integer
---@return AttachedEffect | nil
function g_attachedEffects.registerByThing(id, name, thingId, category) end

---@param id integer
---@param name string
---@param path string
---@param smooth? boolean false
---@return AttachedEffect | nil
function g_attachedEffects.registerByImage(id, name, path, smooth) end

---@param id integer
function g_attachedEffects.remove(id) end

function g_attachedEffects.clear() end

--------------------------------
--------- ProtocolGame ---------
--------------------------------

---@class ProtocolGame : Protocol
ProtocolGame = {}

---@return ProtocolGame
function ProtocolGame.create() end

---@param opcode integer
---@param buffer string
function ProtocolGame:sendExtendedOpcode(opcode, buffer) end

--------------------------------
---------- Container -----------
--------------------------------

---@class Container
Container = {}

---@param slot integer
---@return Item | nil
function Container:getItem(slot) end

---@return Item[]
function Container:getItems() end

---@return integer
function Container:getItemsCount() end

---@param slot integer
---@return Position
function Container:getSlotPosition(slot) end

---@return string
function Container:getName() end

---@return integer
function Container:getId() end

---@return integer
function Container:getCapacity() end

---@return Item | nil
function Container:getContainerItem() end

---@return boolean
function Container:hasParent() end

---@return boolean
function Container:isClosed() end

---@return boolean
function Container:isUnlocked() end

---@return boolean
function Container:hasPages() end

---@return integer
function Container:getSize() end

---@return integer
function Container:getFirstIndex() end

--------------------------------
------- AttachableObject -------
--------------------------------

---@class AttachableObject
AttachableObject = {}

---@return AttachedEffect[]
function AttachableObject:getAttachedEffects() end

---@param obj AttachedEffect
function AttachableObject:attachEffect(obj) end

---@param obj AttachedEffect
---@return boolean
function AttachableObject:detachEffect(obj) end

---@param id integer
---@return boolean
function AttachableObject:detachEffectById(id) end

---@param id integer
---@return AttachedEffect | nil
function AttachableObject:getAttachedEffectById(id) end

---@param ignoreLuaEvent? false
function AttachableObject:clearAttachedEffects(ignoreLuaEvent) end

---@param name string
function AttachableObject:attachParticleEffect(name) end

---@param name string
---@return boolean
function AttachableObject:detachParticleEffectByName(name) end

function AttachableObject:clearAttachedParticlesEffect() end

---@return WidgetType[]
function AttachableObject:getAttachedWidgets() end

---@param widget UIWidget
function AttachableObject:attachWidget(widget) end

---@param widget UIWidget
---@return boolean
function AttachableObject:detachWidget(widget) end

---@param id string
---@return boolean
function AttachableObject:detachWidgetById(id) end

---@param id string
---@return WidgetType | nil
function AttachableObject:getAttachedWidgetById(id) end

--------------------------------
------------ Thing -------------
--------------------------------

---@class Thing : AttachableObject
Thing = {}

---@param id number
function Thing:setId(id) end

---@param name string
function Thing:setShader(name) end

---@param position Position | string
---@param stackPos? integer 0
---@param hasElevation? boolean false
function Thing:setPosition(position, stackPos, hasElevation) end

---@param color string
function Thing:setMarked(color) end

---@return boolean
function Thing:isMarked() end

---@return number
function Thing:getId() end

---@return Tile | nil
function Thing:getTile() end

---@return Position
function Thing:getPosition() end

---@return integer
function Thing:getStackPos() end

---@return MarketData
function Thing:getMarketData() end

---@return integer
function Thing:getStackPriority() end

---@return Container | nil
function Thing:getParentContainer() end

---@return boolean
function Thing:isItem() end

---@return boolean
function Thing:isMonster() end

---@return boolean
function Thing:isNpc() end

---@return boolean
function Thing:isCreature() end

---@return boolean
function Thing:isEffect() end

---@return boolean
function Thing:isMissile() end

---@return boolean
function Thing:isPlayer() end

---@return boolean
function Thing:isLocalPlayer() end

---@return boolean
function Thing:isGround() end

---@return boolean
function Thing:isGroundBorder() end

---@return boolean
function Thing:isOnBottom() end

---@return boolean
function Thing:isOnTop() end

---@return boolean
function Thing:isContainer() end

---@return boolean
function Thing:isForceUse() end

---@return boolean
function Thing:isMultiUse() end

---@return boolean
function Thing:isRotateable() end

---@return boolean
function Thing:isNotMoveable() end

---@return boolean
function Thing:isPickupable() end

---@return boolean
function Thing:isIgnoreLook() end

---@return boolean
function Thing:isStackable() end

---@return boolean
function Thing:isHookSouth() end

---@return boolean
function Thing:isTranslucent() end

---@return boolean
function Thing:isFullGround() end

---@return boolean
function Thing:isMarketable() end

---@return boolean
function Thing:isUsable() end

---@return boolean
function Thing:isWrapable() end

---@return boolean
function Thing:isUnwrapable() end

---@return boolean
function Thing:isTopEffect() end

---@return boolean
function Thing:isLyingCorpse() end

---@return integer
function Thing:getDefaultAction() end

---@return integer
function Thing:getClassification() end

---@param color string
function Thing:setHighlight(color) end

---@return integer
function Thing:isHighlighted() end

---@param layer? integer 0
---@param xPattern? integer 0
---@param yPattern? integer 0
---@param zPattern? integer 0
---@param animationPhase? integer 0
---@return integer
function Thing:getExactSize(layer, xPattern, yPattern, zPattern, animationPhase) end

--------------------------------
------------ House -------------
--------------------------------

---* FRAMEWORK_EDITOR
---@class House
House = {}

---@return House
function House.create() end

---@param id number
function House:setId(id) end

---@return number
function House:getId() end

---@param name string
function House:setName(name) end

---@return string
function House:getName() end

---@param tid number
function House:setTownId(tid) end

---@return number
function House:getTownId() end

---@param tile Tile
function House:setTile(tile) end

---@param pos Position | string
---@return Tile | nil
function House:getTile(pos) end

---@param pos Position | string
function House:setEntry(pos) end

---@return Position
function House:getEntry() end

---@param door Item
function House:addDoor(door) end

---@param door Item
function House:removeDoor(door) end

---@param doorId integer
function House:removeDoorById(doorId) end

---@param size number
function House:setSize(size) end

---@return number
function House:getSize() end

---@param rent number
function House:setRent(rent) end

---@return number
function House:getRent() end

--------------------------------
------------ Spawn -------------
--------------------------------

---* FRAMEWORK_EDITOR
---@class Spawn
Spawn = {}

---@return Spawn
function Spawn.create() end

---@param rent integer
function Spawn:setRadius(rent) end

---@return integer
function Spawn:getRadius() end

---@param pos Position | string
function Spawn:setCenterPos(pos) end

---@return Position
function Spawn:getCenterPos() end

---@param placePos Position | string
---@param creatureType CreatureType
function Spawn:addCreature(placePos, creatureType) end

---@param pos Position | string
function Spawn:removeCreature(pos) end

---@return CreatureType[]
function Spawn:getCreatures() end

--------------------------------
------------- Town -------------
--------------------------------

---* FRAMEWORK_EDITOR
---@class Town
Town = {}

---@return Town
function Town.create() end

---@param tid number
function Town:setId(tid) end

---@param name string
function Town:setName(name) end

---@param pos Position | string
function Town:setPos(pos) end

---@param pos Position | string
function Town:setTemplePos(pos) end

---@return number
function Town:getId() end

---@return string
function Town:getName() end

---@return Position
function Town:getPos() end

---@return Position
function Town:getTemplePos() end

--------------------------------
--------- CreatureType ---------
--------------------------------

---* FRAMEWORK_EDITOR
---@class CreatureType
CreatureType = {}

---@return CreatureType
function CreatureType.create() end

---@param name string
function CreatureType:setName(name) end

---@param outfit Outfit
function CreatureType:setOutfit(outfit) end

---@param spawnTime integer
function CreatureType:setSpawnTime(spawnTime) end

---@return string
function CreatureType:getName() end

---@return Outfit
function CreatureType:getOutfit() end

---@return integer
function CreatureType:getSpawnTime() end

---@return Creature
function CreatureType:cast() end

--------------------------------
----------- Creature -----------
--------------------------------

---@class Creature : Thing
Creature = {}

---@return Creature
function Creature.create() end

---@return number
function Creature:getId() end

---@return number
function Creature:getMasterId() end

---@return string
function Creature:getName() end

---@return integer
function Creature:getHealthPercent() end

---@return integer
function Creature:getSpeed() end

---@return integer
function Creature:getBaseSpeed() end

---@return integer
function Creature:getSkull() end

---@return integer
function Creature:getShield() end

---@return integer
function Creature:getEmblem() end

---@return integer
function Creature:getType() end

---@return integer
function Creature:getIcon() end

---@param outfit Outfit
function Creature:setOutfit(outfit) end

---@return Outfit
function Creature:getOutfit() end

---@return integer
function Creature:getDirection() end

---@param ignoreDiagonal? boolean false
---@param direction? integer
---@return integer
function Creature:getStepDuration(ignoreDiagonal, direction) end

---@return number
function Creature:getStepProgress() end

---@return number
function Creature:getWalkTicksElapsed() end

---@return number
function Creature:getStepTicksLeft() end

---@param direction integer
function Creature:setDirection(direction) end

---@param filename string
function Creature:setSkullTexture(filename) end

---@param filename string
---@param blink boolean
function Creature:setShieldTexture(filename, blink) end

---@param filename string
function Creature:setEmblemTexture(filename) end

---@param filename string
function Creature:setTypeTexture(filename) end

---@param filename string
function Creature:setIconTexture(filename) end

---@param v integer
function Creature:setStaticWalking(v) end

---@param color Color | string
function Creature:showStaticSquare(color) end

function Creature:hideStaticSquare() end

---@return boolean
function Creature:isWalking() end

---@return boolean
function Creature:isInvisible() end

---@return boolean
function Creature:isDead() end

---@return boolean
function Creature:isRemoved() end

---@return boolean
function Creature:canBeSeen() end

---@param height integer
---@param duration integer
function Creature:jump(height, duration) end

---@param name string
function Creature:setMountShader(name) end

---@param draw boolean
function Creature:setDrawOutfitColor(draw) end

---@param v boolean
function Creature:setDisableWalkAnimation(v) end

---@return boolean
function Creature:isDisabledWalkAnimation() end

---@return boolean
function Creature:isTimedSquareVisible() end

---@return Color
function Creature:getTimedSquareColor() end

---@return boolean
function Creature:isStaticSquareVisible() end

---@return Color
function Creature:getStaticSquareColor() end

---@param minHeight integer
---@param height integer
---@param speed integer
function Creature:setBounce(minHeight, height, speed) end

---@param typing boolean
function Creature:setTyping(typing) end

---@return boolean
function Creature:getTyping() end

function Creature:sendTyping() end

---@param filename string
function Creature:setTypingIconTexture(filename) end

---@return WidgetType | nil
function Creature:getWidgetInformation() end

---@param info UIWidget
function Creature:setWidgetInformation(info) end

---@return boolean
function Creature:isFullHealth() end

---@return boolean
function Creature:isCovered() end

---@param text string
---@param color Color | string
function Creature:setText(text, color) end

---@return string
function Creature:getText() end

function Creature:clearText() end

---@param distance integer
---@return boolean
function Creature:canShoot(distance) end

--------------------------------
----------- ItemType -----------
--------------------------------

---* FRAMEWORK_EDITOR
---@class ItemType
ItemType = {}

---@return integer
function ItemType:getServerId() end

---@return integer
function ItemType:getClientId() end

---@return boolean
function ItemType:isWritable() end

--------------------------------
---------- ThingType -----------
--------------------------------

---@class ThingType
ThingType = {}

---@return ThingType
function ThingType.create() end

---@return integer
function ItemType:getId() end

---@return integer
function ItemType:getClothSlot() end

---@return integer
function ItemType:getCategory() end

---@return Size
function ItemType:getSize() end

---@return integer
function ItemType:getWidth() end

---@return integer
function ItemType:getHeight() end

---@return Point
function ItemType:getDisplacement() end

---@return integer
function ItemType:getDisplacementX() end

---@return integer
function ItemType:getDisplacementY() end

---@return integer
function ItemType:getRealSize() end

---@return integer
function ItemType:getLayers() end

---@return integer
function ItemType:getNumPatternX() end

---@return integer
function ItemType:getNumPatternY() end

---@return integer
function ItemType:getNumPatternZ() end

---@return integer
function ItemType:getAnimationPhases() end

---@return integer
function ItemType:getGroundSpeed() end

---@return integer
function ItemType:getMaxTextLength() end

---@return Light
function ItemType:getLight() end

---@return integer
function ItemType:getMinimapColor() end

---@return integer
function ItemType:getLensHelp() end

---@return integer
function ItemType:getElevation() end

---@return boolean
function ItemType:isGround() end

---@return boolean
function ItemType:isGroundBorder() end

---@return boolean
function ItemType:isOnBottom() end

---@return boolean
function ItemType:isOnTop() end

---@return boolean
function ItemType:isContainer() end

---@return boolean
function ItemType:isStackable() end

---@return boolean
function ItemType:isForceUse() end

---@return boolean
function ItemType:isMultiUse() end

---@return boolean
function ItemType:isWritable() end

---@return boolean
function ItemType:isChargeable() end

---@return boolean
function ItemType:isWritableOnce() end

---@return boolean
function ItemType:isFluidContainer() end

---@return boolean
function ItemType:isSplash() end

---@return boolean
function ItemType:isNotWalkable() end

---@return boolean
function ItemType:isNotMoveable() end

---@return boolean
function ItemType:blockProjectile() end

---@return boolean
function ItemType:isNotPathable() end

---@param pathable boolean
function ItemType:setPathable(pathable) end

---@return boolean
function ItemType:isPickupable() end

---@return boolean
function ItemType:isHangable() end

---@return boolean
function ItemType:isHookSouth() end

---@return boolean
function ItemType:isHookEast() end

---@return boolean
function ItemType:isRotateable() end

---@return boolean
function ItemType:hasLight() end

---@return boolean
function ItemType:isDontHide() end

---@return boolean
function ItemType:isTranslucent() end

---@return boolean
function ItemType:hasDisplacement() end

---@return boolean
function ItemType:hasElevation() end

---@return boolean
function ItemType:isLyingCorpse() end

---@return boolean
function ItemType:isAnimateAlways() end

---@return boolean
function ItemType:hasMiniMapColor() end

---@return boolean
function ItemType:hasLensHelp() end

---@return boolean
function ItemType:isFullGround() end

---@return boolean
function ItemType:isIgnoreLook() end

---@return boolean
function ItemType:isCloth() end

---@return boolean
function ItemType:isMarketable() end

---@return MarketData
function ItemType:getMarketData() end

---@return boolean
function ItemType:isUsable() end

---@return boolean
function ItemType:isWrapable() end

---@return boolean
function ItemType:isUnwrapable() end

---@return boolean
function ItemType:isTopEffect() end

---@return number[]
function ItemType:getSprites() end

---@param attr integer
---@return boolean
function ItemType:hasAttribute(attr) end

---@return integer
function ItemType:getClassification() end

---@return boolean
function ItemType:hasWearOut() end

---@return boolean
function ItemType:hasClockExpire() end

---@return boolean
function ItemType:hasExpire() end

---@return boolean
function ItemType:hasExpireStop() end

---@return boolean
function ItemType:isPodium() end

---@return integer
function ItemType:getDefaultAction() end

---@return string
function ItemType:getName() end

---@return string
function ItemType:getDescription() end

---@return number
function ItemType:getOpacity() end

---* FRAMEWORK_EDITOR
---@param fileName string
function ItemType:exportImage(fileName) end

--------------------------------
------------- Item -------------
--------------------------------

---@class Item : Thing
Item = {}

---@param id integer
---@return Item
function Item.create(id) end

---@return Item
function Item:clone() end

---@param count integer
function Item:setCount(count) end

---@param tooltip string
function Item:setTooltip(tooltip) end

---@return integer
function Item:getCount() end

---@return integer
function Item:getSubType() end

---@return integer
function Item:getCountOrSubType() end

---@return number
function Item:getId() end

---@return string
function Item:getTooltip() end

---@return boolean
function Item:isStackable() end

---@return boolean
function Item:isMarketable() end

---@return boolean
function Item:isFluidContainer() end

---@return MarketData
function Item:getMarketData() end

---@return integer
function Item:getClothSlot() end

---@return boolean
function Item:hasWearOut() end

---@return boolean
function Item:hasClockExpire() end

---@return boolean
function Item:hasExpire() end

---@return boolean
function Item:hasExpireStop() end

---* FRAMEWORK_EDITOR
---@return string
function Item:getName() end

---* FRAMEWORK_EDITOR
---@return integer
function Item:getServerId() end

---* FRAMEWORK_EDITOR
---@param id integer
---@return Item
function Item:createOtb(id) end

---* FRAMEWORK_EDITOR
---@return Item[]
function Item:getContainerItems() end

---* FRAMEWORK_EDITOR
---@param slot integer
---@return Item | nil
function Item:getContainerItem(slot) end

---* FRAMEWORK_EDITOR
---@param item Item
function Item:addContainerItem(item) end

---* FRAMEWORK_EDITOR
---@param item Item
---@param slot integer
function Item:addContainerItemIndexed(item, slot) end

---* FRAMEWORK_EDITOR
---@param slot integer
function Item:removeContainerItem(slot) end

---* FRAMEWORK_EDITOR
function Item:clearContainerItems() end

---* FRAMEWORK_EDITOR
---@return string
function Item:getDescription() end

---* FRAMEWORK_EDITOR
---@return string
function Item:getText() end

---* FRAMEWORK_EDITOR
---@param text string
function Item:setDescription(text) end

---* FRAMEWORK_EDITOR
---@param text string
function Item:setText(text) end

---* FRAMEWORK_EDITOR
---@return integer
function Item:getUniqueId() end

---* FRAMEWORK_EDITOR
---@return integer
function Item:getActionId() end

---* FRAMEWORK_EDITOR
---@param uniqueId integer
function Item:setUniqueId(uniqueId) end

---* FRAMEWORK_EDITOR
---@param uniqueId integer
function Item:setActionId(uniqueId) end

---* FRAMEWORK_EDITOR
---@return Position
function Item:getTeleportDestination() end

---* FRAMEWORK_EDITOR
---@param pos Position | string
function Item:setTeleportDestination(pos) end

--------------------------------
------------ Effect ------------
--------------------------------

---@class Effect : Thing
Effect = {}

---@return Effect
function Effect.create() end

---@param id number
function Effect:setId(id) end

--------------------------------
----------- Missile ------------
--------------------------------

---@class Missile : Thing
Missile = {}

---@return Missile
function Missile.create() end

---@param id number
function Missile:setId(id) end

---@param fromPosition Position | string
---@param toPosition Position | string
function Missile:setPath(fromPosition, toPosition) end

--------------------------------
-------- AttachedEffect --------
--------------------------------

---@class AttachedEffect
AttachedEffect = {}

---@param thingId integer
---@param category integer
---@return AttachedEffect
function AttachedEffect.create(thingId, category) end

---@return AttachedEffect
function AttachedEffect:clone() end

---@return integer
function AttachedEffect:getId() end

---@return number
function AttachedEffect:getSpeed() end

---@param onTop boolean
function AttachedEffect:setOnTop(onTop) end

---@param speed number
function AttachedEffect:setSpeed(speed) end

---@param v boolean
function AttachedEffect:setDisableWalkAnimation(v) end

---@param opacity number
function AttachedEffect:setOpacity(opacity) end

---@param duration integer
function AttachedEffect:setDuration(duration) end

---@return integer
function AttachedEffect:getDuration() end

---@param v boolean
function AttachedEffect:setHideOwner(v) end

---@param v integer
function AttachedEffect:setLoop(v) end

---@param permanent boolean
function AttachedEffect:setPermanent(permanent) end

---@return boolean
function AttachedEffect:isPermanent() end

---@param v boolean
function AttachedEffect:setTransform(v) end

---@param x integer
---@param y integer
function AttachedEffect:setOffset(x, y) end

---@param direction integer
---@param x integer
---@param y integer
---@param onTop? boolean false
function AttachedEffect:setDirOffset(direction, x, y, onTop) end

---@param direction integer
---@param onTop boolean
function AttachedEffect:setOnTopByDir(direction, onTop) end

---@param name string
function AttachedEffect:setShader(name) end

---@param size Size | string
function AttachedEffect:setSize(size) end

---@return boolean
function AttachedEffect:canDrawOnUI() end

---@param canDraw boolean
function AttachedEffect:setCanDrawOnUI(canDraw) end

---@param effect AttachedEffect
function AttachedEffect:attachEffect(effect) end

---@param drawOrder integer
function AttachedEffect:setDrawOrder(drawOrder) end

---@param light Light
function AttachedEffect:setLight(light) end

---@param minHeight integer
---@param height integer
---@param speed integer
function AttachedEffect:setBounce(minHeight, height, speed) end

---@param direction integer
function AttachedEffect:setDirection(direction) end

---@return integer
function AttachedEffect:getDirection() end

---@param fromPosition Position | string
---@param toPosition Position | string
function AttachedEffect:move(fromPosition, toPosition) end

--------------------------------
---------- StaticText ----------
--------------------------------

---@class StaticText
StaticText = {}

---@return StaticText
function StaticText.create() end

---@param name string
---@param mode integer
---@param text string
function StaticText:addMessage(name, mode, text) end

---@param text string
function StaticText:setText(text) end

---@param fontName string
function StaticText:setFont(fontName) end

---@param color Color | string
function StaticText:setColor(color) end

---@return Color
function StaticText:getColor() end

--------------------------------
--------- AnimatedText ---------
--------------------------------

---@class AnimatedText
AnimatedText = {}

---@return string
function AnimatedText:getText() end

---@return Point
function AnimatedText:getOffset() end

---@return Color
function AnimatedText:getColor() end

--------------------------------
------------ Player ------------
--------------------------------

---@class Player : Creature
Player = {}

--------------------------------
------------- Npc --------------
--------------------------------

---@class Npc : Creature
Npc = {}

--------------------------------
----------- Monster ------------
--------------------------------

---@class Monster : Creature
Monster = {}

--------------------------------
--------- LocalPlayer ----------
--------------------------------

---@class LocalPlayer : Player
LocalPlayer = {}

function LocalPlayer:unlockWalk() end

---@param millis? integer 250
function LocalPlayer:lockWalk(millis) end

---@param ignoreLock? boolean false
---@return boolean
function LocalPlayer:canWalk(ignoreLock) end

---@param states number
function LocalPlayer:setStates(states) end

---@param skillId integer
---@param level integer
---@param levelPercent integer
function LocalPlayer:setSkill(skillId, level, levelPercent) end

---@param health number
---@param maxHealth number
function LocalPlayer:setHealth(health, maxHealth) end

---@param totalCapacity number
function LocalPlayer:setTotalCapacity(totalCapacity) end

---@param freeCapacity number
function LocalPlayer:setFreeCapacity(freeCapacity) end

---@param experience number
function LocalPlayer:setExperience(experience) end

---@param level integer
---@param levelPercent integer
function LocalPlayer:setLevel(level, levelPercent) end

---@param mana number
---@param maxMana number
function LocalPlayer:setMana(mana, maxMana) end

---@param magicLevel integer
---@param magicLevelPercent integer
function LocalPlayer:setMagicLevel(magicLevel, magicLevelPercent) end

---@param soul integer
function LocalPlayer:setSoul(soul) end

---@param stamina integer
function LocalPlayer:setStamina(stamina) end

---@param known boolean
function LocalPlayer:setKnown(known) end

---@param slot integer
---@param item Item
function LocalPlayer:setInventoryItem(slot, item) end

---@return number
function LocalPlayer:getStates() end

---@param skill integer
---@return integer
function LocalPlayer:getSkillLevel(skill) end

---@param skill integer
---@return integer
function LocalPlayer:getSkillBaseLevel(skill) end

---@param skill integer
---@return integer
function LocalPlayer:getSkillLevelPercent(skill) end

---@return number
function LocalPlayer:getHealth() end

---@return number
function LocalPlayer:getMaxHealth() end

---@return number
function LocalPlayer:getFreeCapacity() end

---@return number
function LocalPlayer:getExperience() end

---@return integer
function LocalPlayer:getLevel() end

---@return integer
function LocalPlayer:getLevelPercent() end

---@return number
function LocalPlayer:getMana() end

---@return number
function LocalPlayer:getMaxMana() end

---@return integer
function LocalPlayer:getMagicLevel() end

---@return integer
function LocalPlayer:getMagicLevelPercent() end

---@return integer
function LocalPlayer:getSoul() end

---@return integer
function LocalPlayer:getStamina() end

---@return integer
function LocalPlayer:getOfflineTrainingTime() end

---@return integer
function LocalPlayer:getRegenerationTime() end

---@return integer
function LocalPlayer:getBaseMagicLevel() end

---@return number
function LocalPlayer:getTotalCapacity() end

---@param slot integer
---@return Item | nil
function LocalPlayer:getInventoryItem(slot) end

---@return integer
function LocalPlayer:getVocation() end

---@return integer
function LocalPlayer:getBlessings() end

---@return boolean
function LocalPlayer:isPremium() end

---@return boolean
function LocalPlayer:isKnown() end

---@return boolean
function LocalPlayer:isPreWalking() end

---@return boolean
function LocalPlayer:isSupplyStashAvailable() end

---@param pos Position | string
---@return boolean
function LocalPlayer:hasSight(pos) end

---@return boolean
function LocalPlayer:isAutoWalking() end

function LocalPlayer:stopAutoWalk() end

---@param destination Position | string
---@param retry? boolean false
---@return boolean
function LocalPlayer:autoWalk(destination, retry) end

---@param resource integer
---@return number
function LocalPlayer:getResourceBalance(resource) end

---@param resource integer
---@param value number
function LocalPlayer:setResourceBalance(resource, value) end

---@return number
function LocalPlayer:getTotalMoney() end

--------------------------------
------------ Tile --------------
--------------------------------

---@class Tile : AttachableObject
Tile = {}

function Tile:clean() end

---@param thing Thing
---@param stackPos integer
function Tile:addThing(thing, stackPos) end

---@param stackPos integer
---@return Thing | nil
function Tile:getThing(stackPos) end

---@return Thing[]
function Tile:getThings() end

---@return Item[]
function Tile:getItems() end

---@param thing Thing
---@return integer
function Tile:getThingStackPos(thing) end

---@return integer
function Tile:getThingCount() end

---@return Thing | nil
function Tile:getTopThing() end

---@param thing Thing
---@return boolean
function Tile:removeThing(thing) end

---@return Thing | nil
function Tile:getTopLookThing() end

---@return Thing | nil
function Tile:getTopUseThing() end

---@param checkAround? boolean false
---@return Creature | nil
function Tile:getTopCreature(checkAround) end

---@return Thing | nil
function Tile:getTopMoveThing() end

---@return Thing | nil
function Tile:getTopMultiUseThing() end

---@return Position
function Tile:getPosition() end

---@return Creature[]
function Tile:getCreatures() end

---@return Item | nil
function Tile:getGround() end

---@param ignoreCreatures? boolean false
---@return boolean
function Tile:isWalkable(ignoreCreatures) end

---@return boolean
function Tile:isFullGround() end

---@return boolean
function Tile:isFullyOpaque() end

---@return boolean
function Tile:isLookPossible() end

---@return boolean
function Tile:hasCreatures() end

---@return boolean
function Tile:isEmpty() end

---@return boolean
function Tile:isClickable() end

---@return boolean
function Tile:isPathable() end

---@param selectType? integer 2
function Tile:select(selectType) end

function Tile:unselect() end

---@return boolean
function Tile:isSelected() end

---@param firstFloor integer
---@return boolean
function Tile:isCovered(firstFloor) end

---@param firstFloor integer
---@param resetCache boolean
---@return boolean
function Tile:isCompletelyCovered(firstFloor, resetCache) end

---@param text string
---@param color Color | string
function Tile:setText(text, color) end

---@return string
function Tile:getText() end

---@param time integer
---@param color Color | string
function Tile:setTimer(time, color) end

---@return integer
function Tile:getTimer() end

---@param color Color | string
function Tile:setFill(color) end

---@param distance integer
---@return boolean
function Tile:canShoot(distance) end

---* FRAMEWORK_EDITOR
---@return boolean
function Tile:isHouseTile() end

---@param color integer
function Tile:overwriteMinimapColor(color) end

---@param flag number
function Tile:remFlag(flag) end

---@param flag number
function Tile:setFlag(flag) end

---@param flags number
function Tile:setFlags(flags) end

---@return number
function Tile:getFlags() end

---@param flag number
---@return boolean
function Tile:hasFlag(flag) end

--------------------------------
----------- UIItem -------------
--------------------------------

---@class UIItem : UIWidget
UIItem = {}

---@return UIItem
function UIItem.create() end

---@param id integer
function UIItem:setItemId(id) end

---@param count integer
function UIItem:setItemCount(count) end

---@param subType integer
function UIItem:setItemSubType(subType) end

---@param visible boolean
function UIItem:setItemVisible(visible) end

---@param item Item
function UIItem:setItem(item) end

---@param virtual boolean
function UIItem:setVirtual(virtual) end

---@param show boolean
function UIItem:setShowCount(show) end

function UIItem:clearItem() end

---@return integer
function UIItem:getItemId() end

---@return integer
function UIItem:getItemCount() end

---@return integer
function UIItem:getItemSubType() end

---@return Item | nil
function UIItem:getItem() end

---@return boolean
function UIItem:isVirtual() end

---@return boolean
function UIItem:isItemVisible() end

--------------------------------
---------- UISprite ------------
--------------------------------

---@class UISprite : UIWidget
UISprite = {}

---@return UISprite
function UISprite.create() end

---@param spriteId integer
function UISprite:setSpriteId(spriteId) end

function UISprite:clearSprite() end

---@return integer
function UISprite:getSpriteId() end

---@param color Color | string
function UISprite:setSpriteColor(color) end

---@return boolean
function UISprite:hasSprite() end

--------------------------------
--------- UICreature -----------
--------------------------------

---@class UICreature : UIWidget
UICreature = {}

---@return UICreature
function UICreature.create() end

---@param creature Creature
function UICreature:setCreature(creature) end

---@param outfit Outfit
function UICreature:setOutfit(outfit) end

---@param size integer
function UICreature:setCreatureSize(size) end

---@return Creature | nil
function UICreature:getCreature() end

---@return integer
function UICreature:getCreatureSize() end

---@return integer
function UICreature:getDirection() end

---@param center boolean
function UICreature:setCenter(center) end

---@return boolean
function UICreature:isCentered() end

--------------------------------
------------ UIMap -------------
--------------------------------

---@class UIMap : UIWidget
UIMap = {}

---@return UIMap
function UIMap.create() end

---@param drawPane integer
function UIMap:drawSelf(drawPane) end

---@param x integer
---@param y integer
function UIMap:movePixels(x, y) end

---@param zoom integer
---@return boolean
function UIMap:setZoom(zoom) end

---@return boolean
function UIMap:zoomIn() end

---@return boolean
function UIMap:zoomOut() end

---@param y integer
function UIMap:movePixels(x, y) end

---@param creature Creature
function UIMap:followCreature(creature) end

---@param pos Position | string
function UIMap:setCameraPosition(pos) end

---@param maxZoomIn integer
function UIMap:setMaxZoomIn(maxZoomIn) end

---@param maxZoomOut integer
function UIMap:setMaxZoomOut(maxZoomOut) end

---@param floor integer
function UIMap:lockVisibleFloor(floor) end

function UIMap:unlockVisibleFloor() end

---@param visibleDimension Size | string
function UIMap:setVisibleDimension(visibleDimension) end

---@param viewMode number
function UIMap:setFloorViewMode(viewMode) end

---@param enable boolean
function UIMap:setDrawNames(enable) end

---@param enable boolean
function UIMap:setDrawHealthBars(enable) end

---@param enable boolean
function UIMap:setDrawLights(enable) end

---@param enable boolean
function UIMap:setLimitVisibleDimension(enable) end

---@param enable boolean
function UIMap:setDrawManaBar(enable) end

---@param enable boolean
function UIMap:setKeepAspectRatio(enable) end

---@param name string
---@param fadeIn integer
---@param fadeOut integer
function UIMap:setShader(name, fadeIn, fadeOut) end

---@return PainterShaderProgram | nil
function UIMap:getShader() end

---@return PainterShaderProgram | nil
function UIMap:getNextShader() end

---@return boolean
function UIMap:isSwitchingShader() end

---@param intensity number
function UIMap:setMinimumAmbientLight(intensity) end

---@param intensity number
function UIMap:setShadowFloorIntensity(intensity) end

---@param limitVisibleRange boolean
function UIMap:setLimitVisibleRange(limitVisibleRange) end

---@param force boolean
function UIMap:setDrawViewportEdge(force) end

---@return boolean
function UIMap:isDrawingNames() end

---@return boolean
function UIMap:isDrawingHealthBars() end

---@return boolean
function UIMap:isDrawingLights() end

---@return boolean
function UIMap:isLimitedVisibleDimension() end

---@return boolean
function UIMap:isDrawingManaBar() end

---@return boolean
function UIMap:isLimitVisibleRangeEnabled() end

---@return boolean
function UIMap:isKeepAspectRatioEnabled() end

---@param pos Position | string
---@return boolean
function UIMap:isInRange(pos) end

---@return Size
function UIMap:getVisibleDimension() end

---@return number
function UIMap:getFloorViewMode() end

---@return Creature | nil
function UIMap:getFollowingCreature() end

---@return Position
function UIMap:getCameraPosition() end

---@param mousePos Point | string
---@return Position
function UIMap:getPosition(mousePos) end

---@param mousePos Point | string
---@return Tile | nil
function UIMap:getTile(mousePos) end

---@return integer
function UIMap:getMaxZoomIn() end

---@return integer
function UIMap:getMaxZoomOut() end

---@return integer
function UIMap:getZoom() end

---@return number
function UIMap:getMinimumAmbientLight() end

---@param multiFloor? boolean false
---@return Creature[]
function UIMap:getSpectators(multiFloor) end

---@param multiFloor? boolean false
---@return Creature[]
function UIMap:getSightSpectators(multiFloor) end

---@param texturePath string
function UIMap:setCrosshairTexture(texturePath) end

---@param enable boolean
function UIMap:setDrawHighlightTarget(enable) end

---@param mode integer
function UIMap:setAntiAliasingMode(mode) end

---@param value integer
function UIMap:setFloorFading(value) end

function UIMap:clearTiles() end

--------------------------------
---------- UIMinimap -----------
--------------------------------

---@class UIMinimap : UIWidget
UIMinimap = {}

---@return UIMinimap
function UIMinimap.create() end

---@return boolean
function UIMinimap:zoomIn() end

---@return boolean
function UIMinimap:zoomOut() end

---@param zoom integer
---@return boolean
function UIMinimap:setZoom(zoom) end

---@param minZoom integer
function UIMinimap:setMixZoom(minZoom) end

---@param maxZoom integer
function UIMinimap:setMaxZoom(maxZoom) end

---@return boolean
function UIMinimap:floorUp() end

---@return boolean
function UIMinimap:floorDown() end

---@param pos Position | string
---@return Point
function UIMinimap:getTilePoint(pos) end

---@param mousePos Point | string
---@return Position
function UIMinimap:getTilePosition(mousePos) end

---@param pos Position | string
---@return Rect
function UIMinimap:getTileRect(pos) end

---@return Position
function UIMinimap:getCameraPosition() end

---@return integer
function UIMinimap:getMinZoom() end

---@return integer
function UIMinimap:getMaxZoom() end

---@return integer
function UIMinimap:getZoom() end

---@return number
function UIMinimap:getScale() end

---@param anchoredWidget UIWidget
---@param anchoredEdge integer
---@param hookedPosition Position | string
---@param hookedEdge integer
function UIMinimap:anchorPosition(anchoredWidget, anchoredEdge, hookedPosition, hookedEdge) end

---@param anchoredWidget UIWidget
---@param hookedPosition Position | string
function UIMinimap:fillPosition(anchoredWidget, hookedPosition) end

---@param anchoredWidget UIWidget
---@param hookedPosition Position | string
function UIMinimap:centerInPosition(anchoredWidget, hookedPosition) end

--------------------------------
-------- UIProgressRect --------
--------------------------------

---@class UIProgressRect : UIWidget
UIProgressRect = {}

---@return UIProgressRect
function UIProgressRect.create() end

---@param percent number
function UIProgressRect:setPercent(percent) end

---@return number
function UIProgressRect:getPercent() end

--------------------------------
----------- UIGraph ------------
--------------------------------

---@class UIGraph : UIWidget
UIGraph = {}

---@return UIGraph
function UIGraph.create() end

---@param value integer
---@param ignoreSmallValues? boolean false
function UIGraph:addValue(value, ignoreSmallValues) end

function UIGraph:clear() end

---@param width integer
function UIGraph:setLineWidth(width) end

---@param capacity integer
function UIGraph:setCapacity(capacity) end

---@param title string
function UIGraph:setTitle(title) end

---@param show boolean
function UIGraph:setShowLabels(show) end

--------------------------------
------ UIMapAnchorLayout -------
--------------------------------

---@class UIMapAnchorLayout : UIAnchorLayout
UIMapAnchorLayout = {}

--------------------------------
---------- g_platform ----------
--------------------------------

---@class g_platform
g_platform = {}

---@param process string
---@param args string[]
---@return boolean
function g_platform.spawnProcess(process, args) end

---@return integer
function g_platform.getProcessId() end

---@param name string
---@return integer
function g_platform.isProcessRunning(name) end

---@param from string
---@param to string
---@return boolean
function g_platform.copyFile(from, to) end

---@param file string
---@return boolean
function g_platform.fileExists(file) end

---@param file string
---@return boolean
function g_platform.removeFile(file) end

---@param name string
---@return boolean
function g_platform.killProcess(name) end

---@return string
function g_platform.getTempPath(name) end

---@param url string
---@param now? boolean false
---@return boolean
function g_platform.openUrl(url, now) end

---@return string
function g_platform.getCPUName() end

---@return number
function g_platform.getTotalSystemMemory() end

---@return string
function g_platform.getOSName() end

---@param file string
---@return number
function g_platform.getFileModificationTime(file) end

---@return number
function g_platform.getDevice() end

---@param deviceType? number 0
---@return string
function g_platform.getDeviceShortName(deviceType) end

---@param os? number 0
---@return string
function g_platform.getOsShortName(os) end

---@return boolean
function g_platform.isDesktop() end

---@return boolean
function g_platform.isMobile() end

---@return boolean
function g_platform.isConsole() end

---@param path string
---@param now? boolean false
---@return boolean
function g_platform.openDir(path, now) end

--------------------------------
------------- g_app ------------
--------------------------------

---@class g_app
g_app = {}

---@param name string
function g_app.setName(name) end

---@param name string
function g_app.setCompactName(name) end

---@param name string
function g_app.setOrganizationName(name) end

---@return boolean
function g_app.isRunning() end

---@return boolean
function g_app.isStopping() end

---@return string
function g_app.getName() end

---@return string
function g_app.getCompactName() end

---@return string
function g_app.getVersion() end

---@return string
function g_app.getBuildCompiler() end

---@return string
function g_app.getBuildDate() end

---@return string
function g_app.getBuildRevision() end

---@return string
function g_app.getBuildCommit() end

---@return string
function g_app.getBuildType() end

---@return string
function g_app.getBuildArch() end

---@return string
function g_app.getOs() end

---@return string
function g_app.getStartupOptions() end

function g_app.exit() end

function g_app.restart() end

---@return boolean
function g_app.isOnInputEvent() end

---@param optimize boolean
function g_app.optimize(optimize) end

---@param optimize boolean
function g_app.forceEffectOptimization(optimize) end

---@param draw boolean
function g_app.setDrawEffectOnTop(draw) end

---@return integer
function g_app.getFps(draw) end

---@return integer
function g_app.getMaxFps(draw) end

---@param maxFps integer
function g_app.setMaxFps(maxFps) end

---@return integer
function g_app.getTargetFps() end

---@param targetFps integer
function g_app.setTargetFps(targetFps) end

function g_app.resetTargetFps() end

---@return boolean
function g_app.isDrawingTexts() end

---@param draw boolean
function g_app.setDrawTexts(draw) end

---@param value boolean
function g_app.setLoadingAsyncTexture(value) end

---@return boolean
function g_app.isEncrypted() end

---@return boolean
function g_app.isScaled() end

---@param value number
function g_app.setCreatureInformationScale(value) end

---@param value number
function g_app.setAnimatedTextScale(value) end

---@param value number
function g_app.setStaticTextScale(value) end

---@param file string
function g_app.doScreenshot(file) end

---@param file string
function g_app.doMapScreenshot(file) end

--------------------------------
----------- g_crypt ------------
--------------------------------

---@class g_crypt
g_crypt = {}

---@return string
function g_crypt.genUUID() end

---@param uuid string
---@return boolean
function g_crypt.setMachineUUID(uuid) end

---@param str string
---@return string
function g_crypt.encrypt(str) end

---@param str string
---@return string
function g_crypt.decrypt(str) end

---@param n string
---@param e string
function g_crypt.rsaSetPublicKey(n, e) end

---@param p string
---@param q string
---@param d string
function g_crypt.rsaSetPrivateKey(p, q, d) end

---@return integer
function g_crypt.rsaGetSize() end

--------------------------------
----------- g_clock ------------
--------------------------------

---@class g_clock
g_clock = {}

---@return number
function g_clock.micros() end

---@return number
function g_clock.millis() end

---@return number
function g_clock.seconds() end

---@return number
function g_clock.realMillis() end

---@return number
function g_clock.realMicros() end

--------------------------------
---------- g_configs -----------
--------------------------------

---@class g_configs
g_configs = {}

---@return Config
function g_configs.getSettings() end

---@param file string
---@return Config | nil
function g_configs.get(file) end

---@param file string
---@return Config | nil
function g_configs.loadSettings(file) end

---@param file string
---@return Config | nil
function g_configs.load(file) end

---@param file string
---@return boolean
function g_configs.unload(file) end

---@param file string
---@return Config
function g_configs.create(file) end

--------------------------------
----------- g_logger -----------
--------------------------------

---@class g_logger
g_logger = {}

---@param level integer
---@param message string
function g_logger.log(level, message) end

function g_logger.fireOldMessages() end

---@param file string
function g_logger.setLogFile(file) end

---@param callback function
function g_logger.setOnLog(callback) end

---@param message string
function g_logger.debug(message) end

---@param message string
function g_logger.info(message) end

---@param message string
function g_logger.warning(message) end

---@param message string
function g_logger.error(message) end

---@param message string
function g_logger.fatal(message) end

---@param level integer
function g_logger.setLevel(level) end

---@return integer
function g_logger.getLevel() end

--------------------------------
---------- LoginHttp -----------
--------------------------------

---@class LoginHttp
LoginHttp = {}

---@return LoginHttp
function LoginHttp.create() end

---@param host string
---@param path string
---@param port integer
---@param email string
---@param password string
---@param token string
---@param requestId integer
---@param httpLogin boolean
function LoginHttp:httpLogin(host, path, port, email, password, token, requestId, httpLogin) end

--------------------------------
------------ g_http ------------
--------------------------------

---@class g_http
g_http = {}

---@param userAgent string
function g_http.setUserAgent(userAgent) end

---@param enable boolean
function g_http.setEnableTimeOutOnReadWrite(enable) end

---@param name string
---@param value string
function g_http.addCustomHeader(name, value) end

---@param url string
---@param timeOut? integer 5
---@return integer
function g_http.get(url, timeOut) end

---@param url string
---@param data string
---@param timeOut? integer 5
---@param isJson? boolean false
---@param checkContentLength? boolean true
---@return integer
function g_http.post(url, data, timeOut, isJson, checkContentLength) end

---@param url string
---@param path string
---@param timeOut? integer 5
---@return integer
function g_http.download(url, path, timeOut) end

---@param url string
---@param timeOut? integer 5
---@return integer
function g_http.ws(url, timeOut) end

---@param operationId integer
---@param message string
---@return boolean
function g_http.wsSend(operationId, message) end

---@param operationId integer
---@return boolean
function g_http.wsClose(operationId) end

---@param id integer
---@return boolean
function g_http.cancel(id) end

--------------------------------
---------- g_modules -----------
--------------------------------

---@class g_modules
g_modules = {}

function g_modules.discoverModules() end

---@param maxPriority integer
function g_modules.autoLoadModules(maxPriority) end

---@param moduleFile string
---@return Module | nil
function g_modules.discoverModule(moduleFile) end

---@param moduleName string
function g_modules.ensureModuleLoaded(moduleName) end

function g_modules.unloadModules() end

function g_modules.reloadModules() end

---@param moduleName string
---@return Module | nil
function g_modules.getModule(moduleName) end

---@return Module[]
function g_modules.getModules() end

---@return Module | nil
function g_modules.getCurrentModule() end

function g_modules.enableAutoReload() end

--------------------------------
--------- g_dispatcher ---------
--------------------------------

---@class g_dispatcher
g_dispatcher = {}

---@param callback function
---@return Event | nil
function g_dispatcher.addEvent(callback) end

---@param callback function
---@param delay integer
---@return ScheduledEvent | nil
function g_dispatcher.scheduleEvent(callback, delay) end

---@param callback function
---@param delay integer
---@return ScheduledEvent | nil
function g_dispatcher.cycleEvent(callback, delay) end

--------------------------------
--------- g_resources ----------
--------------------------------

---@class g_resources
g_resources = {}

---@param path string
---@param pushFront? boolean false
---@return boolean
function g_resources.addSearchPath(path, pushFront) end

---@param appWriteDirName string
---@return boolean
function g_resources.setupUserWriteDir(appWriteDirName) end

---@param writeDir string
---@param create? boolean false
---@return boolean
function g_resources.setWriteDir(writeDir, create) end

---@param packagesDir string
---@param packagesExt string
function g_resources.searchAndAddPackages(packagesDir, packagesExt) end

---@param path string
---@return boolean
function g_resources.removeSearchPath(path) end

---@param fileName string
---@return boolean
function g_resources.fileExists(fileName) end

---@param dirName string
---@return boolean
function g_resources.directoryExists(dirName) end

---@param path string
---@return string
function g_resources.getRealDir(path) end

---@return string
function g_resources.getWorkDir() end

---@return string
function g_resources.getUserDir() end

---@return string
function g_resources.getWriteDir() end

---@return string[]
function g_resources.getSearchPaths() end

---@param path string
---@return string
function g_resources.getRealPath(path) end

---@param path string
---@param fullPath? boolean false
---@param raw? boolean false
---@param recursive? boolean false
---@return string[]
function g_resources.listDirectoryFiles(path, fullPath, raw, recursive) end

---@param path string
---@param fileNameOnly boolean
---@param recursive boolean
---@return string[]
function g_resources.getDirectoryFiles(path, fileNameOnly, recursive) end

---@param fileName string
---@return string
function g_resources.readFileContents(fileName) end

---@param fileName string
---@param data string
---@return boolean
function g_resources.writeFileContents(fileName, data) end

---@param fileName string
---@param fileType string
---@return string
function g_resources.guessFilePath(fileName, fileType) end

---@param fileName string
---@param fileType string
---@return boolean
function g_resources.isFileType(fileName, fileType) end

---@param filePath string
---@return string
function g_resources.getFileName(filePath) end

---@param filePath string
---@return number
function g_resources.getFileTime(filePath) end

---@param dir string
---@return boolean
function g_resources.makeDir(dir) end

---@param fileName string
---@return boolean
function g_resources.deleteFile(fileName) end

---@param path string
---@return string
function g_resources.resolvePath(path) end

---@param path string
---@return string
function g_resources.fileChecksum(path) end

---@return table<string, string>
function g_resources.filesChecksums() end

---@return string
function g_resources.selfChecksum() end

---@param files string[]
function g_resources.updateFiles(files) end

---@param fileName string
function g_resources.updateExecutable(fileName) end

---@param files table<string, string>
---@return string
function g_resources.createArchive(files) end

---@param dataOrPath string
---@return table<string, string>
function g_resources.decompressArchive(dataOrPath) end

--------------------------------
------------ Config ------------
--------------------------------

---@class Config
Config = {}

---@return boolean
function Config:save() end

---@param key string
---@param value string
function Config:setValue(key, value) end

---@param key string
---@param list string[]
function Config:setList(key, list) end

---@param key string
---@return string
function Config:getValue(key) end

---@param key string
---@return string[]
function Config:getList(key) end

---@param key string
---@return boolean
function Config:exists(key) end

---@param key string
function Config:remove(key) end

---@param key string
---@param node OTMLNode
function Config:setNode(key, node) end

---@param key string
---@return OTMLNode | nil
function Config:getNode(key) end

---@param key string
---@return integer
function Config:getNodeSize(key) end

---@param key string
---@param node OTMLNode
---@return OTMLNode
function Config:getOrCreateNode(key, node) end

---@param key string
---@param node OTMLNode
function Config:mergeNode(key, node) end

---@return string
function Config:getFileName() end

--------------------------------
------------ Module ------------
--------------------------------

---@class Module
Module = {}

---@return boolean
function Module:load() end

function Module:unload() end

---@return boolean
function Module:reload() end

---@return boolean
function Module:canReload() end

---@return boolean
function Module:canUnload() end

---@return boolean
function Module:isLoaded() end

---@return boolean
function Module:isReloadble() end

---@return boolean
function Module:isSandboxed() end

---@return string
function Module:getDescription() end

---@return string
function Module:getName() end

---@return string
function Module:getAuthor() end

---@return string
function Module:getWebsite() end

---@return string
function Module:getVersion() end

---@return table
function Module:getSandbox() end

---@return boolean
function Module:isAutoLoad() end

---@return integer
function Module:getAutoLoadPriority() end

--------------------------------
------------ Event -------------
--------------------------------

---@class Event
Event = {}

function Event:cancel() end

function Event:execute() end

---@return boolean
function Event:isCanceled() end

---@return boolean
function Event:isExecuted() end

--------------------------------
-------- ScheduledEvent --------
--------------------------------

---@class ScheduledEvent : Event
ScheduledEvent = {}

---@return boolean
function ScheduledEvent:nextCycle() end

---@return integer
function ScheduledEvent:ticks() end

---@return integer
function ScheduledEvent:remainingTicks() end

---@return integer
function ScheduledEvent:delay() end

---@return integer
function ScheduledEvent:cyclesExecuted() end

---@return integer
function ScheduledEvent:maxCycles() end

--------------------------------
---------- g_window ------------
--------------------------------

---@class g_window
g_window = {}

---@param pos Point | string
function g_window.move(pos) end

---@param size Size | string
function g_window.resize(size) end

function g_window.show() end

function g_window.hide() end

function g_window.poll() end

function g_window.maximize() end

function g_window.restoreMouseCursor() end

function g_window.showMouse() end

function g_window.hideMouse() end

---@param title string
function g_window.setTitle(title) end

---@param cursorId integer
function g_window.setMouseCursor(cursorId) end

---@param minSize Size | string
function g_window.setMinimumSize(minSize) end

---@param fullscreen boolean
function g_window.setFullscreen(fullscreen) end

---@param enable boolean
function g_window.setVerticalSync(enable) end

---@param iconFile string
function g_window.setIcon(iconFile) end

---@param text string
function g_window.setClipboardText(text) end

---@return Size
function g_window.getDisplaySize() end

---@return string
function g_window.getClipboardText() end

---@return string
function g_window.getPlatformType() end

---@return integer
function g_window.getDisplayWidth() end

---@return integer
function g_window.getDisplayHeight() end

---@return Size
function g_window.getUnmaximizedSize() end

---@return Size
function g_window.getSize() end

---@return integer
function g_window.getWidth() end

---@return integer
function g_window.getHeight() end

---@return Point
function g_window.getUnmaximizedPos() end

---@return Point
function g_window.getPosition() end

---@return integer
function g_window.getX() end

---@return integer
function g_window.getY() end

---@return Point
function g_window.getMousePosition() end

---@return integer
function g_window.getKeyboardModifiers() end

---@param key integer
---@return boolean
function g_window.isKeyPressed(key) end

---@param mouseButton integer
---@return boolean
function g_window.isMouseButtonPressed(mouseButton) end

---@return boolean
function g_window.isVisible() end

---@return boolean
function g_window.isFullscreen() end

---@return boolean
function g_window.isMaximized() end

---@return boolean
function g_window.hasFocus() end

---@return number
function g_window.getDisplayDensity() end

--------------------------------
----------- g_mouse ------------
--------------------------------

---@class g_mouse
g_mouse = {}

---@param fileName string
function g_mouse.loadCursors(fileName) end

---@param name string
---@param file string
---@param hotSpot Point | string
function g_mouse.addCursor(name, file, hotSpot) end

---@param name string
---@return boolean
function g_mouse.pushCursor(name) end

---@param name string
function g_mouse.popCursor(name) end

---@return boolean
function g_mouse.isCursorChanged() end

---@param mouseButton? integer 0
---@return boolean
function g_mouse.isPressed(mouseButton) end

--------------------------------
---------- g_graphics ----------
--------------------------------

---@class g_graphics
g_graphics = {}

---@return Size
function g_graphics.getViewportSize() end

---@return string
function g_graphics.getVendor() end

---@return string
function g_graphics.getRenderer() end

---@return string
function g_graphics.getVersion() end

--------------------------------
---------- g_textures ----------
--------------------------------

---@class g_textures
g_textures = {}

---@param fileName string
---@param smooth? boolean true
function g_textures.preload(fileName, smooth) end

function g_textures.clearCache() end

function g_textures.liveReload() end

--------------------------------
------------- g_ui -------------
--------------------------------

---@class g_ui
g_ui = {}

function g_ui.clearStyles() end

---@param fileName string
---@param checkDeviceStyles? boolean true
---@return boolean
function g_ui.importStyle(fileName, checkDeviceStyles) end

---@param styleName string
---@return OTMLNode | nil
function g_ui.getStyle(styleName) end

---@param styleName string
---@return string
function g_ui.getStyleName(styleName) end

---@param styleName string
---@return string
function g_ui.getStyleClass(styleName) end

---@param file string
---@param parent? UIWidget
---@return WidgetType | nil
function g_ui.loadUI(file, parent) end

---@param data string
---@param parent UIWidget
---@return WidgetType | nil
function g_ui.loadUIFromString(data, parent) end

---@param file string
---@return WidgetType | nil
function g_ui.displayUI(file) end

---@param styleName string
---@param parent? UIWidget
---@return WidgetType | nil
function g_ui.createWidget(styleName, parent) end

---@param node OTMLNode
---@param parent UIWidget
---@return WidgetType | nil
function g_ui.createWidgetFromOTML(node, parent) end

---@return WidgetType
function g_ui.getRootWidget() end

---@return WidgetType | nil
function g_ui.getDraggingWidget() end

---@return WidgetType | nil
function g_ui.getPressedWidget() end

---@param enable boolean
function g_ui.setDebugBoxesDrawing(enable) end

---@return boolean
function g_ui.isDrawingDebugBoxes() end

---@return boolean
function g_ui.isMouseGrabbed() end

---@return boolean
function g_ui.isKeyboardGrabbed() end

--------------------------------
----------- g_fonts ------------
--------------------------------

---@class g_fonts
g_fonts = {}

function g_fonts.clearFonts() end

---@param file string
---@return boolean
function g_fonts.importFont(file) end

---@param fontName string
---@return boolean
function g_fonts.fontExists(fontName) end

--------------------------------
--------- g_particles ----------
--------------------------------

---@class g_particles
g_particles = {}

---@param file string
---@return boolean
function g_particles.importParticle(file) end

---@return ParticleEffectType[]
function g_particles.getEffectsTypes() end

function g_particles.terminate() end

--------------------------------
---------- g_shaders -----------
--------------------------------

---@class g_shaders
g_shaders = {}

---@param name string
---@param useFramebuffer? boolean false
function g_shaders.createShader(name, useFramebuffer) end

---@param name string
---@param file string
---@param useFramebuffer? boolean false
function g_shaders.createFragmentShader(name, file, useFramebuffer) end

---@param name string
---@param code string
---@param useFramebuffer? boolean false
function g_shaders.createFragmentShaderFromCode(name, code, useFramebuffer) end

---@param name string
function g_shaders.setupMapShader(name) end

---@param name string
function g_shaders.setupItemShader(name) end

---@param name string
function g_shaders.setupOutfitShader(name) end

---@param name string
function g_shaders.setupMountShader(name) end

---@param name string
---@param file string
function g_shaders.addMultiTexture(name, file) end

---@param name string
---@return PainterShaderProgram | nil
function g_shaders.getShader(name) end

function g_shaders.clear() end

--------------------------------
----------- UIWidget -----------
--------------------------------

---@class UIWidget
UIWidget = {}

---@return UIWidget
function UIWidget.create() end

---@param child UIWidget
function UIWidget:addChild(child) end

---@param index integer
---@param child UIWidget
function UIWidget:insertChild(index, child) end

---@param child UIWidget
function UIWidget:removeChild(child) end

---@param child UIWidget
---@param reason? integer 0
function UIWidget:focusChild(child, reason) end

---@param reason integer
---@param rotate? boolean false
function UIWidget:focusNextChild(reason, rotate) end

---@param reason integer
---@param rotate? boolean false
function UIWidget:focusPreviousChild(reason, rotate) end

---@param child UIWidget
function UIWidget:lowerChild(child) end

---@param child UIWidget
function UIWidget:raiseChild(child) end

---@param child UIWidget
---@param index integer
function UIWidget:moveChildToIndex(child, index) end

---@param children UIWidget[]
function UIWidget:reorderChildren(children) end

---@param child UIWidget
function UIWidget:lockChild(child) end

---@param child UIWidget
function UIWidget:unlockChild(child) end

---@param styleNode OTMLNode
function UIWidget:mergeStyle(styleNode) end

---@param styleNode OTMLNode
function UIWidget:applyStyle(styleNode) end

---@param anchoredEdge integer
---@param hookedWidgetId string
---@param hookedEdge integer
function UIWidget:addAnchor(anchoredEdge, hookedWidgetId, hookedEdge) end

---@param anchoredEdge integer
function UIWidget:removeAnchor(anchoredEdge) end

---@param hookedWidgetId string
function UIWidget:fill(hookedWidgetId) end

---@param hookedWidgetId string
function UIWidget:centerIn(hookedWidgetId) end

function UIWidget:breakAnchors() end

function UIWidget:updateParentLayout() end

function UIWidget:updateLayout() end

function UIWidget:lock() end

function UIWidget:unlock() end

function UIWidget:focus() end

function UIWidget:lower() end

function UIWidget:raise() end

function UIWidget:grabMouse() end

function UIWidget:ungrabMouse() end

function UIWidget:grabKeyboard() end

function UIWidget:ungrabKeyboard() end

function UIWidget:bindRectToParent() end

function UIWidget:destroy() end

function UIWidget:destroyChildren() end

function UIWidget:removeChildren() end

function UIWidget:hideChildren() end

function UIWidget:showChildren() end

---@param id string
function UIWidget:setId(id) end

---@param parent UIWidget
function UIWidget:setParent(parent) end

---@param layout UILayout
function UIWidget:setLayout(layout) end

---@param rect Rect | string
---@return boolean
function UIWidget:setRect(rect) end

---@param styleName string
function UIWidget:setStyle(styleName) end

---@param styleNode OTMLNode
function UIWidget:setStyleFromNode(styleNode) end

---@param enabled boolean
function UIWidget:setEnabled(enabled) end

---@param visible boolean
function UIWidget:setVisible(visible) end

---@param on boolean
function UIWidget:setOn(on) end

---@param checked boolean
function UIWidget:setChecked(checked) end

---@param focusable boolean
function UIWidget:setFocusable(focusable) end

---@param phantom boolean
function UIWidget:setPhantom(phantom) end

---@param draggable boolean
function UIWidget:setPhantom(draggable) end

---@param fixed boolean
function UIWidget:setFixedSize(fixed) end

---@param clipping boolean
function UIWidget:setClipping(clipping) end

---@param reason integer
function UIWidget:setLastFocusReason(reason) end

---@param policy integer
function UIWidget:setAutoFocusPolicy(policy) end

---@param delay integer
function UIWidget:setAutoRepeatDelay(delay) end

---@param offset Point | string
function UIWidget:setVirtualOffset(offset) end

---@return boolean
function UIWidget:isVisible() end

---@param child UIWidget
---@return boolean
function UIWidget:isChildLocked(child) end

---@param child UIWidget
---@return boolean
function UIWidget:hasChild(child) end

---@param child? UIWidget
---@return integer
function UIWidget:getChildIndex(child) end

---@return Rect
function UIWidget:getMarginRect() end

---@return Rect
function UIWidget:getPaddingRect() end

---@return Rect
function UIWidget:getChildrenRect() end

---@return UIAnchorLayout
function UIWidget:getAnchoredLayout() end

---@return WidgetType
function UIWidget:getRootParent() end

---@param relativeChild UIWidget
---@return WidgetType | nil
function UIWidget:getChildAfter(relativeChild) end

---@param relativeChild UIWidget
---@return WidgetType | nil
function UIWidget:getChildBefore(relativeChild) end

---@param id string
---@return WidgetType | nil
function UIWidget:getChildById(id) end

---@param pos Point | string
---@return WidgetType | nil
function UIWidget:getChildByPos(pos) end

---@param index integer
---@return WidgetType | nil
function UIWidget:getChildByIndex(index) end

---@param state number
---@return WidgetType | nil
function UIWidget:getChildByState(state) end

---@param styleName string
---@return WidgetType | nil
function UIWidget:getChildByStyleName(styleName) end

---@param id string
---@return WidgetType | nil
function UIWidget:recursiveGetChildById(id) end

---@param pos Point | string
---@param wantsPhantom? boolean false
---@return WidgetType | nil
function UIWidget:recursiveGetChildByPos(pos, wantsPhantom) end

---@param state number
---@param wantsPhantom? boolean false
---@return WidgetType | nil
function UIWidget:recursiveGetChildByState(state, wantsPhantom) end

---@return WidgetType[]
function UIWidget:recursiveGetChildren() end

---@param pos Point | string
---@return WidgetType[]
function UIWidget:recursiveGetChildrenByPos(pos) end

---@param pos Point | string
---@return WidgetType[]
function UIWidget:recursiveGetChildrenByMarginPos(pos) end

---@param state number
---@return WidgetType[]
function UIWidget:recursiveGetChildrenByState(state) end

---@param styleName string
---@return WidgetType[]
function UIWidget:recursiveGetChildrenByStyleName(styleName) end

---@param id string
---@return WidgetType | nil
function UIWidget:backwardsGetWidgetById(id) end

---@param width integer
---@param height integer
function UIWidget:resize(width, height) end

---@param x integer
---@param y integer
function UIWidget:move(x, y) end

---@param degress number
function UIWidget:rotate(degress) end

function UIWidget:hide() end

function UIWidget:show() end

function UIWidget:disable() end

function UIWidget:enable() end

---@return boolean
function UIWidget:isActive() end

---@return boolean
function UIWidget:isEnabled() end

---@return boolean
function UIWidget:isDisabled() end

---@return boolean
function UIWidget:isFocused() end

---@return boolean
function UIWidget:isHovered() end

---@return boolean
function UIWidget:isChildHovered() end

---@return boolean
function UIWidget:isPressed() end

---@return boolean
function UIWidget:isFirst() end

---@return boolean
function UIWidget:isMiddle() end

---@return boolean
function UIWidget:isLast() end

---@return boolean
function UIWidget:isAlternate() end

---@return boolean
function UIWidget:isChecked() end

---@return boolean
function UIWidget:isOn() end

---@return boolean
function UIWidget:isDragging() end

---@return boolean
function UIWidget:isHidden() end

---@return boolean
function UIWidget:isExplicitlyEnabled() end

---@return boolean
function UIWidget:isExplicitlyVisible() end

---@return boolean
function UIWidget:isFocusable() end

---@return boolean
function UIWidget:isPhantom() end

---@return boolean
function UIWidget:isDraggable() end

---@return boolean
function UIWidget:isFixedSize() end

---@return boolean
function UIWidget:isClipping() end

---@return boolean
function UIWidget:isDestroyed() end

---@return boolean
function UIWidget:isFirstOnStyle() end

---@return boolean
function UIWidget:isTextWrap() end

---@return boolean
function UIWidget:hasChildren() end

---@param point Point | string
---@return boolean
function UIWidget:containsMarginPoint(point) end

---@param point Point | string
---@return boolean
function UIWidget:containsPaddingPoint(point) end

---@param point Point | string
---@return boolean
function UIWidget:containsPoint(point) end

---@param rect Rect | string
---@return boolean
function UIWidget:intersects(rect) end

---@param rect Rect | string
---@return boolean
function UIWidget:intersectsMargin(rect) end

---@param rect Rect | string
---@return boolean
function UIWidget:intersectsPadding(rect) end

---@return string
function UIWidget:getId() end

---@return string
function UIWidget:getSource() end

---@return WidgetType | nil
function UIWidget:getParent() end

---@return WidgetType | nil
function UIWidget:getFocusedChild() end

---@return WidgetType | nil
function UIWidget:getHoveredChild() end

---@return WidgetType[]
function UIWidget:getChildren() end

---@return WidgetType | nil
function UIWidget:getFirstChild() end

---@return WidgetType | nil
function UIWidget:getLastChild() end

---@return UILayout | nil
function UIWidget:getLayout() end

---@return OTMLNode | nil
function UIWidget:getStyle() end

---@return integer
function UIWidget:getChildCount() end

---@return integer
function UIWidget:getLastFocusReason() end

---@return integer
function UIWidget:getAutoFocusPolicy() end

---@return integer
function UIWidget:getAutoRepeatDelay() end

---@return Point
function UIWidget:getVirtualOffset() end

---@return string
function UIWidget:getStyleName() end

---@return Point
function UIWidget:getLastClickPosition() end

---@param x integer
function UIWidget:setX(x) end

---@param y integer
function UIWidget:setY(y) end

---@param width integer
function UIWidget:setWidth(width) end

---@param height integer
function UIWidget:setHeight(height) end

---@param size Size | string
function UIWidget:setSize(size) end

---@param minWidth integer
function UIWidget:setMinWidth(minWidth) end

---@param maxWidth integer
function UIWidget:setMaxWidth(maxWidth) end

---@param minHeight integer
function UIWidget:setMinHeight(minHeight) end

---@param maxHeight integer
function UIWidget:setMaxHeight(maxHeight) end

---@param minSize Size | string
function UIWidget:setMinSize(minSize) end

---@param maxSize Size | string
function UIWidget:setMaxSize(maxSize) end

---@param pos Point | string
function UIWidget:setPosition(pos) end

---@param color Color | string
function UIWidget:setColor(color) end

---@param color Color | string
function UIWidget:setBackgroundColor(color) end

---@param x integer
function UIWidget:setBackgroundOffsetX(x) end

---@param y integer
function UIWidget:setBackgroundOffsetY(y) end

---@param pos Point | string
function UIWidget:setBackgroundOffset(pos) end

---@param width integer
function UIWidget:setBackgroundWidth(width) end

---@param height integer
function UIWidget:setBackgroundHeight(height) end

---@param size Size | string
function UIWidget:setBackgroundSize(size) end

---@param rect Rect | string
function UIWidget:setBackgroundRect(rect) end

---@param iconFile string
function UIWidget:setIcon(iconFile) end

---@param color Color | string
function UIWidget:setIconColor(color) end

---@param x integer
function UIWidget:setIconOffsetX(x) end

---@param y integer
function UIWidget:setIconOffsetY(y) end

---@param pos Point | string
function UIWidget:setIconOffset(pos) end

---@param width integer
function UIWidget:setIconWidth(width) end

---@param height integer
function UIWidget:setIconHeight(height) end

---@param size Size | string
function UIWidget:setIconSize(size) end

---@param rect Size | string
function UIWidget:setIconRect(rect) end

---@param rect Rect | string
function UIWidget:setIconClip(rect) end

---@param align integer
function UIWidget:setIconAlign(align) end

---@param width integer
function UIWidget:setBorderWidth(width) end

---@param width integer
function UIWidget:setBorderWidthTop(width) end

---@param width integer
function UIWidget:setBorderWidthRight(width) end

---@param width integer
function UIWidget:setBorderWidthBottom(width) end

---@param width integer
function UIWidget:setBorderWidthLeft(width) end

---@param color Color | string
function UIWidget:setBorderColor(color) end

---@param color Color | string
function UIWidget:setBorderColorTop(color) end

---@param color Color | string
function UIWidget:setBorderColorRight(color) end

---@param color Color | string
function UIWidget:setBorderColorBottom(color) end

---@param color Color | string
function UIWidget:setBorderColorLeft(color) end

---@param margin integer
function UIWidget:setMargin(margin) end

---@param margin integer
function UIWidget:setMarginHorizontal(margin) end

---@param margin integer
function UIWidget:setMarginVertical(margin) end

---@param margin integer
function UIWidget:setMarginTop(margin) end

---@param margin integer
function UIWidget:setMarginRight(margin) end

---@param margin integer
function UIWidget:setMarginBottom(margin) end

---@param margin integer
function UIWidget:setMarginLeft(margin) end

---@param padding integer
function UIWidget:setPadding(padding) end

---@param padding integer
function UIWidget:setPaddingHorizontal(padding) end

---@param padding integer
function UIWidget:setPaddingVertical(padding) end

---@param padding integer
function UIWidget:setPaddingTop(padding) end

---@param padding integer
function UIWidget:setPaddingRight(padding) end

---@param padding integer
function UIWidget:setPaddingBottom(padding) end

---@param padding integer
function UIWidget:setPaddingLeft(padding) end

---@param opacity number
function UIWidget:setOpacity(opacity) end

---@param degress number
function UIWidget:setRotation(degress) end

---@return integer
function UIWidget:getX() end

---@return integer
function UIWidget:getY() end

---@return Point
function UIWidget:getPosition() end

---@return Point
function UIWidget:getCenter() end

---@return integer
function UIWidget:getWidth() end

---@return integer
function UIWidget:getHeight() end

---@return Size
function UIWidget:getSize() end

---@return Rect
function UIWidget:getRect() end

---@return integer
function UIWidget:getMinWidth() end

---@return integer
function UIWidget:getMaxWidth() end

---@return integer
function UIWidget:getMinHeight() end

---@return integer
function UIWidget:getMaxHeight() end

---@return Size
function UIWidget:getMinSize() end

---@return Size
function UIWidget:getMaxSize() end

---@return Color
function UIWidget:getColor() end

---@return Color
function UIWidget:getBackgroundColor() end

---@return integer
function UIWidget:getBackgroundOffsetX() end

---@return integer
function UIWidget:getBackgroundOffsetY() end

---@return Point
function UIWidget:getBackgroundOffset() end

---@return integer
function UIWidget:getBackgroundWidth() end

---@return integer
function UIWidget:getBackgroundHeight() end

---@return Size
function UIWidget:getBackgroundSize() end

---@return Rect
function UIWidget:getBackgroundRect() end

---@return Color
function UIWidget:getIconColor() end

---@return integer
function UIWidget:getIconOffsetX() end

---@return integer
function UIWidget:getIconOffsetY() end

---@return Point
function UIWidget:getIconOffset() end

---@return integer
function UIWidget:getIconHeight() end

---@return Size
function UIWidget:getIconSize() end

---@return Rect
function UIWidget:getIconRect() end

---@return Rect
function UIWidget:getIconClip() end

---@return integer
function UIWidget:getIconAlign() end

---@return Color
function UIWidget:getBorderTopColor() end

---@return Color
function UIWidget:getBorderRightColor() end

---@return Color
function UIWidget:getBorderBottomColor() end

---@return Color
function UIWidget:getBorderLeftColor() end

---@return integer
function UIWidget:getBorderTopWidth() end

---@return integer
function UIWidget:getBorderRightWidth() end

---@return integer
function UIWidget:getBorderBottomWidth() end

---@return integer
function UIWidget:getBorderLeftWidth() end

---@return string
function UIWidget:getImageSource() end

---@return integer
function UIWidget:getMarginTop() end

---@return integer
function UIWidget:getMarginRight() end

---@return integer
function UIWidget:getMarginBottom() end

---@return integer
function UIWidget:getMarginLeft() end

---@return integer
function UIWidget:getPaddingTop() end

---@return integer
function UIWidget:getPaddingRight() end

---@return integer
function UIWidget:getPaddingBottom() end

---@return integer
function UIWidget:getPaddingLeft() end

---@return number
function UIWidget:getOpacity() end

---@return number
function UIWidget:getRotation() end

---@param source string
---@param base64? boolean false
function UIWidget:setImageSource(source, base64) end

---@param rect Rect | string
function UIWidget:setImageClip(rect) end

---@param x integer
function UIWidget:setImageOffsetX(x) end

---@param y integer
function UIWidget:setImageOffsetY(y) end

---@param pos Point | string
function UIWidget:setImageOffset(pos) end

---@param width integer
function UIWidget:setImageWidth(width) end

---@param height integer
function UIWidget:setImageHeight(height) end

---@param size Size | string
function UIWidget:setImageSize(size) end

---@param rect Rect | string
function UIWidget:setImageRect(rect) end

---@param color Color | string
function UIWidget:setImageColor(color) end

---@param fixedRatio boolean
function UIWidget:setImageFixedRatio(fixedRatio) end

---@param repeated boolean
function UIWidget:setImageRepeated(repeated) end

---@param smooth boolean
function UIWidget:setImageSmooth(smooth) end

---@param autoResize boolean
function UIWidget:setImageAutoResize(autoResize) end

---@param border integer
function UIWidget:setImageBorderTop(border) end

---@param border integer
function UIWidget:setImageBorderRight(border) end

---@param border integer
function UIWidget:setImageBorderBottom(border) end

---@param border integer
function UIWidget:setImageBorderLeft(border) end

---@param border integer
function UIWidget:setImageBorder(border) end

---@return Rect
function UIWidget:getImageClip() end

---@return integer
function UIWidget:getImageOffsetX() end

---@return integer
function UIWidget:getImageOffsetY() end

---@return Point
function UIWidget:getImageOffset() end

---@return integer
function UIWidget:getImageWidth() end

---@return integer
function UIWidget:getImageHeight() end

---@return Size
function UIWidget:getImageSize() end

---@return Rect
function UIWidget:getImageRect() end

---@return Color
function UIWidget:getImageColor() end

---@return boolean
function UIWidget:isImageFixedRatio() end

---@return boolean
function UIWidget:isImageSmooth() end

---@return boolean
function UIWidget:isImageAutoResize() end

---@return integer
function UIWidget:getImageBorderTop() end

---@return integer
function UIWidget:getImageBorderRight() end

---@return integer
function UIWidget:getImageBorderBottom() end

---@return integer
function UIWidget:getImageBorderLeft() end

---@return integer
function UIWidget:getImageTextureWidth() end

---@return integer
function UIWidget:getImageTextureHeight() end

function UIWidget:resizeToText() end

function UIWidget:clearText() end

---@param text string
---@param dontFireLuaCall? boolean false
function UIWidget:setText(text, dontFireLuaCall) end

---@param coloredText string
---@param dontFireLuaCall? boolean false
function UIWidget:setColoredText(coloredText, dontFireLuaCall) end

---@param align integer
function UIWidget:setTextAlign(align) end

---@param offset Point | string
function UIWidget:setTextOffset(offset) end

---@param textWrap boolean
function UIWidget:setTextWrap(textWrap) end

---@param autoResize boolean
function UIWidget:setTextAutoResize(autoResize) end

---@param autoResize boolean
function UIWidget:setTextVerticalAutoResize(autoResize) end

---@param autoResize boolean
function UIWidget:setTextHorizontalAutoResize(autoResize) end

---@param fontName string
function UIWidget:setFont(fontName) end

---@param scale number
function UIWidget:setFontScale(scale) end

---@param name string
function UIWidget:setShader(name) end

---@return string
function UIWidget:getText() end

---@return string
function UIWidget:getDrawText() end

---@return integer
function UIWidget:getTextAlign() end

---@return Point
function UIWidget:getTextOffset() end

---@return string
function UIWidget:getFont() end

---@return Size
function UIWidget:getTextSize() end

---@return boolean
function UIWidget:hasShader() end

function UIWidget:disableUpdateTemporarily() end

---@return WidgetType | nil
function UIWidget:getNextWidget() end

---@return WidgetType | nil
function UIWidget:getPrevWidget() end

---@return boolean
function UIWidget:hasAnchoredLayout() end

---@param v boolean
function UIWidget:setOnHtml(v) end

---@return boolean
function UIWidget:isOnHtml() end

---@param order integer
function UIWidget:setBackgroundDrawOrder(order) end

---@param order integer
function UIWidget:setImageDrawOrder(order) end

---@param order integer
function UIWidget:setIconDrawOrder(order) end

---@param order integer
function UIWidget:setTextDrawOrder(order) end

---@param order integer
function UIWidget:setBorderDrawOrder(order) end

--------------------------------
----------- UILayout -----------
--------------------------------

---@class UILayout
UILayout = {}

function UILayout:update() end

function UILayout:updateLater() end

---@param styleNode OTMLNode
function UILayout:applyStyle(styleNode) end

---@param widget UIWidget
function UILayout:addWidget(widget) end

---@param widget UIWidget
function UILayout:removeWidget(widget) end

function UILayout:disableUpdates() end

function UILayout:enableUpdates() end

---@param parent UIWidget
function UILayout:setParent(parent) end

---@return WidgetType
function UILayout:getParentWidget() end

---@return boolean
function UILayout:isUpdateDisabled() end

---@return boolean
function UILayout:isUpdating() end

---@return boolean
function UILayout:isUIAnchorLayout() end

---@return boolean
function UILayout:isUIBoxLayout() end

---@return boolean
function UILayout:isUIHorizontalLayout() end

---@return boolean
function UILayout:isUIVerticalLayout() end

---@return boolean
function UILayout:isUIGridLayout() end

--------------------------------
--------- UIBoxLayout ----------
--------------------------------

---@class UIBoxLayout : UILayout
UIBoxLayout = {}

---@param spacing integer
function UIBoxLayout:setSpacing(spacing) end

---@param fitChildren boolean
function UIBoxLayout:setFitChildren(fitChildren) end

--------------------------------
------- UIVerticalLayout -------
--------------------------------

---@class UIVerticalLayout : UIBoxLayout
UIVerticalLayout = {}

---@param parent UIWidget
---@return UIVerticalLayout
function UIVerticalLayout.create(parent) end

---@param alignBottom boolean
function UIVerticalLayout:setAlignBottom(alignBottom) end

---@return boolean
function UIVerticalLayout:isAlignBottom() end

--------------------------------
------ UIHorizontalLayout ------
--------------------------------

---@class UIHorizontalLayout : UIBoxLayout
UIHorizontalLayout = {}

---@param parent UIWidget
---@return UIHorizontalLayout
function UIHorizontalLayout.create(parent) end

---@param alignRight boolean
function UIHorizontalLayout:setAlignRight(alignRight) end

--------------------------------
--------- UIGridLayout ---------
--------------------------------

---@class UIGridLayout : UILayout
UIGridLayout = {}

---@param parent UIWidget
---@return UIGridLayout
function UIGridLayout.create(parent) end

---@param cellSize Size | string
function UIGridLayout:setCellSize(cellSize) end

---@param width integer
function UIGridLayout:setCellWidth(width) end

---@param heigth integer
function UIGridLayout:setCellHeight(heigth) end

---@param spacing integer
function UIGridLayout:setCellSpacing(spacing) end

---@param enable boolean
function UIGridLayout:setFlow(enable) end

---@param columns integer
function UIGridLayout:setNumColumns(columns) end

---@param lines integer
function UIGridLayout:setNumLines(lines) end

---@return integer
function UIGridLayout:getNumColumns() end

---@return integer
function UIGridLayout:getNumLines() end

---@return Size
function UIGridLayout:getCellSize() end

---@return integer
function UIGridLayout:getCellSpacing() end

---@return boolean
function UIGridLayout:isUIGridLayout() end

--------------------------------
--------- UIGridLayout ---------
--------------------------------

---@class UIAnchorLayout : UILayout
UIAnchorLayout = {}

---@param parent UIWidget
---@return UIAnchorLayout
function UIAnchorLayout.create(parent) end

---@param anchoredWidget UIWidget
function UIAnchorLayout:removeAnchors(anchoredWidget) end

---@param anchoredWidget UIWidget
---@param hookedWidgetId string
function UIAnchorLayout:centerIn(anchoredWidget, hookedWidgetId) end

---@param anchoredWidget UIWidget
---@param hookedWidgetId string
function UIAnchorLayout:fill(anchoredWidget, hookedWidgetId) end

--------------------------------
---------- UITextEdit ----------
--------------------------------

---@class UITextEdit : UIWidget
UITextEdit = {}

---@return UITextEdit
function UITextEdit.create() end

---@param pos integer
function UITextEdit:setCursorPos(pos) end

---@param start integer
---@param ending integer
function UITextEdit:setSelection(start, ending) end

---@param visible boolean
function UITextEdit:setCursorVisible(visible) end

---@param enable boolean
function UITextEdit:setChangeCursorImage(enable) end

---@param hidden boolean
function UITextEdit:setTextHidden(hidden) end

---@param validCharacters string
function UITextEdit:setValidCharacters(validCharacters) end

---@param enable boolean
function UITextEdit:setShiftNavigation(enable) end

---@param enable boolean
function UITextEdit:setMultiline(enable) end

---@param editable boolean
function UITextEdit:setEditable(editable) end

---@param selectable boolean
function UITextEdit:setSelectable(selectable) end

---@param color Color | string
function UITextEdit:setSelectionColor(color) end

---@param color Color | string
function UITextEdit:setSelectionBackgroundColor(color) end

---@param maxLength number
function UITextEdit:setMaxLength(maxLength) end

---@param offset Point | string
function UITextEdit:setTextVirtualOffset(offset) end

---@return Point
function UITextEdit:getTextVirtualOffset() end

---@return Size
function UITextEdit:getTextVirtualSize() end

---@return Size
function UITextEdit:getTextTotalSize() end

---@param right boolean
function UITextEdit:moveCursorHorizontally(right) end

---@param up boolean
function UITextEdit:moveCursorVertically(up) end

---@param text string
function UITextEdit:appendText(text) end

function UITextEdit:wrapText() end

---@param right boolean
function UITextEdit:removeCharacter(right) end

function UITextEdit:blinkCursor() end

---@param right? boolean false
function UITextEdit:del(right) end

---@return string
function UITextEdit:copy() end

---@return string
function UITextEdit:cut() end

function UITextEdit:selectAll() end

function UITextEdit:clearSelection() end

---@return string
function UITextEdit:getDisplayedText() end

---@return string
function UITextEdit:getSelection() end

---@param pos Point | string
---@return integer
function UITextEdit:getTextPos(pos) end

---@return integer
function UITextEdit:getCursorPos() end

---@return number
function UITextEdit:getMaxLength() end

---@return integer
function UITextEdit:getSelectionStart() end

---@return integer
function UITextEdit:getSelectionEnd() end

---@return Color
function UITextEdit:getSelectionColor() end

---@return Color
function UITextEdit:getSelectionBackgroundColor() end

---@return boolean
function UITextEdit:hasSelection() end

---@return boolean
function UITextEdit:isEditable() end

---@return boolean
function UITextEdit:isSelectable() end

---@return boolean
function UITextEdit:isCursorVisible() end

---@return boolean
function UITextEdit:isChangingCursorImage() end

---@return boolean
function UITextEdit:isTextHidden() end

---@return boolean
function UITextEdit:isShiftNavigation() end

---@return boolean
function UITextEdit:isMultiline() end

--------------------------------
----------- UIQrCode -----------
--------------------------------

---@class UIQrCode : UIWidget
UIQrCode = {}

---@return UIQrCode
function UIQrCode.create() end

---@return string
function UIQrCode:getCode() end

---@return integer
function UIQrCode:getCodeBorder() end

---@param code string
---@param border integer
function UIQrCode:setCode(code, border) end

---@param border integer
function UIQrCode:setCodeBorder(border) end

--------------------------------
--------- ShaderProgram --------
--------------------------------

---@class ShaderProgram
ShaderProgram = {}

--------------------------------
----- PainterShaderProgram -----
--------------------------------

---@class PainterShaderProgram
PainterShaderProgram = {}

---@param file string
function PainterShaderProgram:addMultiTexture(file) end

--------------------------------
------ ParticleEffectType ------
--------------------------------

---@class ParticleEffectType
ParticleEffectType = {}

---@return ParticleEffectType
function ParticleEffectType.create() end

---@return string
function ParticleEffectType:getName() end

---@return string
function ParticleEffectType:getDescription() end

--------------------------------
---------- UIParticles ---------
--------------------------------

---@class UIParticles : UIWidget
UIParticles = {}

---@return UIParticles
function UIParticles.create() end

---@param name string
function UIParticles:addEffect(name) end

--------------------------------
------------ Server ------------
--------------------------------

---@class Server
Server = {}

---@param port integer
---@return Server
function Server.create(port) end

function Server:close() end

---@return boolean
function Server:isOpen() end

function Server:acceptNext() end

--------------------------------
---------- Connection ----------
--------------------------------

---@class Connection
Connection = {}

---@return integer
function Connection:getIp() end

--------------------------------
----------- Protocol -----------
--------------------------------

---@class Protocol
Protocol = {}

---@return Protocol
function Protocol.create() end

---@param host string
---@param port integer
function Protocol:connect(host, port) end

function Protocol:disconnect() end

---@return boolean
function Protocol:isConnected() end

---@return boolean
function Protocol:isConnecting() end

---@return Connection | nil
function Protocol:getConnection() end

---@param connection Connection
function Protocol:setConnection(connection) end

---@param outputMessage OutputMessage
function Protocol:send(outputMessage) end

function Protocol:recv() end

---@param a number
---@param b number
---@param c number
---@param d number
function Protocol:setXteaKey(a, b, c, d) end

---@return number[]
function Protocol:getXteaKey() end

function Protocol:generateXteaKey() end

function Protocol:enableXteaEncryption() end

function Protocol:enabledSequencedPackets() end

function Protocol:enableChecksum() end

--------------------------------
--------- InputMessage ---------
--------------------------------

---@class InputMessage
InputMessage = {}

---@return InputMessage
function InputMessage.create() end

---@param buffer string
function InputMessage:setBuffer(buffer) end

---@return string
function InputMessage:getBuffer() end

---@param bytes integer
function InputMessage:skipBytes(bytes) end

---@return integer
function InputMessage:getU8() end

---@return integer
function InputMessage:getU16() end

---@return number
function InputMessage:getU32() end

---@return number
function InputMessage:getU64() end

---@return string
function InputMessage:getString() end

---@return integer
function InputMessage:peekU8() end

---@return integer
function InputMessage:peekU16() end

---@return number
function InputMessage:peekU32() end

---@return number
function InputMessage:peekU64() end

---@param size integer
---@return boolean
function InputMessage:decryptRsa(size) end

---@return integer
function InputMessage:getReadSize() end

---@return integer
function InputMessage:getUnreadSize() end

---@return integer
function InputMessage:getMessageSize() end

---@return boolean
function InputMessage:eof() end

--------------------------------
-------- OutputMessage ---------
--------------------------------

---@class OutputMessage
OutputMessage = {}

---@return OutputMessage
function OutputMessage.create() end

---@param buffer string
function OutputMessage:setBuffer(buffer) end

---@return string
function OutputMessage:getBuffer() end

function OutputMessage:reset() end

---@param value integer
function OutputMessage:addU8(value) end

---@param value integer
function OutputMessage:addU16(value) end

---@param value number
function OutputMessage:addU32(value) end

---@param value number
function OutputMessage:addU64(value) end

---@param value string
function OutputMessage:addString(value) end

---@param value string
function OutputMessage:addBytes(value) end

---@param bytes integer
---@param byte integer
function OutputMessage:addPaddingBytes(bytes, byte) end

function OutputMessage:encryptRsa() end

---@return integer
function OutputMessage:getMessageSize() end

---@param size integer
function OutputMessage:setMessageSize(size) end

---@return integer
function OutputMessage:getWritePos() end

---@param writePos integer
function OutputMessage:setWritePos(writePos) end

--------------------------------
----------- g_sounds -----------
--------------------------------

---* FRAMEWORK_SOUND
---@class g_sounds
g_sounds = {}

---@param fileName string
function g_sounds.preload(fileName) end

---@param fileName string
---@param fadeTime? number 0.0
---@param gain? number 0.0
---@param pitch? number 0.0
---@return SoundSource
function g_sounds.play(fileName, fadeTime, gain, pitch) end

---@param channelId integer
---@return SoundChannel
function g_sounds.getChannel(channelId) end

function g_sounds.stopAll() end

function g_sounds.enableAudio() end

function g_sounds.disableAudio() end

---@return boolean
function g_sounds.isAudioEnabled() end

---@param pos Point | string
function g_sounds.setPosition(pos) end

---@return SoundSource
function g_sounds.createSoundEffect() end

---@return boolean
function g_sounds.isEaxEnabled() end

---@param file string
---@return boolean
function g_sounds.loadClientFiles(directory) end

---@param audioFileId string
---@return string
function g_sounds.getAudioFileNameById(audioFileId) end

--------------------------------
--------- SoundSource ----------
--------------------------------

---* FRAMEWORK_SOUND
---@class SoundSource
SoundSource = {}

---@return SoundSource
function SoundSource.create(fileName) end

---@param name string
function SoundSource:setName(name) end

function SoundSource:play() end

function SoundSource:stop() end

---@return boolean
function SoundSource:isPlaying() end

---@param gain number
function SoundSource:setGain(gain) end

---@param pos Point | string
function SoundSource:setPosition(pos) end

---@param velocity Point | string
function SoundSource:setVelocity(velocity) end

---@param state number
---@param fadeTime number
function SoundSource:setFading(state, fadeTime) end

---@param looping boolean
function SoundSource:setLooping(looping) end

---@param relative boolean
function SoundSource:setRelative(relative) end

---@param distance number
function SoundSource:setReferenceDistance(distance) end

---@param soundEffect SoundEffect
function SoundSource:setEffect(soundEffect) end

function SoundSource:removeEffect() end

--------------------------------
------ CombinedSoundSource -----
--------------------------------

---* FRAMEWORK_SOUND
---@class CombinedSoundSource : SoundSource
CombinedSoundSource = {}

--------------------------------
------ StreamSoundSource -------
--------------------------------

---* FRAMEWORK_SOUND
---@class StreamSoundSource : SoundSource
StreamSoundSource = {}

--------------------------------
--------- SoundEffect ----------
--------------------------------

---* FRAMEWORK_SOUND
---@class SoundEffect
SoundEffect = {}

---@param presetName string
function SoundEffect:setPreset(presetName) end

--------------------------------
--------- SoundChannel ---------
--------------------------------

---* FRAMEWORK_SOUND
---@class SoundChannel
SoundChannel = {}

---@param fileName string
---@param fadeTime? number 0.0
---@param gain? number 1.0
---@param pitch? number 1.0
---@return SoundSource
function SoundChannel:play(fileName, fadeTime, gain, pitch) end

---@param fadeTime? number 0.0
function SoundChannel:stop(fadeTime) end

---@param fileName string
---@param fadeTime? number 0.0
---@param gain? number 1.0
---@param pitch? number 1.0
function SoundChannel:enqueue(fileName, fadeTime, gain, pitch) end

function SoundChannel:enable() end

function SoundChannel:disable() end

---@param gain number
function SoundChannel:setGain(gain) end

---@return number
function SoundChannel:getGain() end

---@param enabled boolean
function SoundChannel:setEnabled(enabled) end

---@return boolean
function SoundChannel:isEnabled() end

---@return integer
function SoundChannel:getId() end
