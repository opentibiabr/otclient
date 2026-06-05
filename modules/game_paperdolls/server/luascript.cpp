void LuaScriptInterface::registerFunctions() {
	// .
	// .
	// .
	
	// add at the end 
// Paperdoll
	registerMethod("Creature", "addPaperdoll", LuaScriptInterface::luaCreatureAddPaperdoll);
	registerMethod("Creature", "getPaperdolls", LuaScriptInterface::luaCreatureGetPaperdolls);
	registerMethod("Creature", "setPaperdoll", LuaScriptInterface::luaCreatureSetPaperdoll);
	registerMethod("Creature", "hasPaperdollById", LuaScriptInterface::luaCreatureHasPaperdollById);
	registerMethod("Creature", "hasPaperdollBySlot", LuaScriptInterface::luaCreatureHasPaperdollBySlot);
	registerMethod("Creature", "getPaperdollById", LuaScriptInterface::luaCreatureGetPaperdollById);
	registerMethod("Creature", "getPaperdollBySlot", LuaScriptInterface::luaCreatureGetPaperdollBySlot);
	registerMethod("Creature", "removePaperdollById", LuaScriptInterface::luaCreatureRemovePaperdollById);
	registerMethod("Creature", "removePaperdollBySlot", LuaScriptInterface::luaCreatureRemovePaperdollBySlot);
}

// Paperdolls
Paperdoll_t LuaScriptInterface::getPaperdoll(lua_State* L, int32_t arg)
{
	Paperdoll_t o;

	o.id = getField<uint16_t>(L, arg, "id");
	o.slot = getField<uint8_t>(L, arg, "slot", 255);
	o.color = getField<uint8_t>(L, arg, "color", 0);
	o.head = getField<uint8_t>(L, arg, "head", 0);
	o.body = getField<uint8_t>(L, arg, "body", 0);
	o.legs = getField<uint8_t>(L, arg, "legs", 0);
	o.feet = getField<uint8_t>(L, arg, "feet", 0);
	o.shader = getFieldString(L, arg, "shader");

	lua_pop(L, 8);
	return o;
}

void LuaScriptInterface::pushPaperdoll(lua_State* L, const Paperdoll_t& paperdoll)
{
	lua_createtable(L, 0, 8);
	setField(L, "id", paperdoll.id);
	setField(L, "slot", paperdoll.slot);
	setField(L, "color", paperdoll.color);
	setField(L, "head", paperdoll.head);
	setField(L, "body", paperdoll.body);
	setField(L, "legs", paperdoll.legs);
	setField(L, "feet", paperdoll.feet);
	setField(L, "shader", paperdoll.shader);
	setMetatable(L, -1, "Paperdoll");
}

int LuaScriptInterface::luaCreatureAddPaperdoll(lua_State* L)
{
	// creature:addPaperdoll(paperdoll)
	Creature* creature = getUserdata<Creature>(L, 1);
	if (creature) {
		creature->addPaperdoll(getPaperdoll(L, 2));
		pushBoolean(L, true);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureGetPaperdolls(lua_State* L)
{
	// creature:getPaperdolls()
	const auto creature = getUserdata<Creature>(L, 1);
	if (!creature) {
		lua_pushnil(L);
		return 1;
	}

	lua_createtable(L, creature->getPaperdolls().size(), 0);

	int index = 0;
	for (const auto& paperdoll : creature->getPaperdolls()) {
		pushPaperdoll(L, paperdoll);
		lua_rawseti(L, -2, ++index);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureSetPaperdoll(lua_State* L)
{
	// creature:setPaperdoll(paperdoll)
	Creature* creature = getUserdata<Creature>(L, 1);
	if (creature) {
		creature->setPaperdoll(getPaperdoll(L, 2));
		pushBoolean(L, true);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureHasPaperdollById(lua_State* L)
{
	// creature:hasPaperdollById(id)
	const Creature* creature = getUserdata<const Creature>(L, 1);
	if (creature) {
		uint16_t id = getNumber<uint16_t>(L, 2);
		pushBoolean(L, creature->hasPaperdollById(id));
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureHasPaperdollBySlot(lua_State* L)
{
	// creature:hasPaperdollBySlot(slot)
	const Creature* creature = getUserdata<const Creature>(L, 1);
	if (creature) {
		uint8_t slot = getNumber<uint8_t>(L, 2);
		pushBoolean(L, creature->hasPaperdollBySlot(slot));
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureGetPaperdollById(lua_State* L)
{
	// creature:getPaperdollById()
	const Creature* creature = getUserdata<const Creature>(L, 1);
	if (creature) {
		uint16_t id = getNumber<uint16_t>(L, 2);
		const auto& paperdoll = creature->getPaperdollById(id);
		if (paperdoll.id < UINT16_MAX)
			pushPaperdoll(L, creature->getPaperdollById(id));
		else
			lua_pushnil(L);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureGetPaperdollBySlot(lua_State* L)
{
	// creature:getPaperdollBySlot()
	const Creature* creature = getUserdata<const Creature>(L, 1);
	if (creature) {
		uint8_t slot = getNumber<uint16_t>(L, 2);
		const auto& paperdoll = creature->getPaperdollBySlot(slot);
		if (paperdoll.id < UINT16_MAX)
			pushPaperdoll(L, creature->getPaperdollBySlot(slot));
		else
			lua_pushnil(L);
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureRemovePaperdollById(lua_State* L)
{
	// creature:removePaperdollById(id)
	Creature* creature = getUserdata<Creature>(L, 1);
	if (creature) {
		uint16_t id = getNumber<uint16_t>(L, 2);
		pushBoolean(L, creature->removePaperdollById(id));
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

int LuaScriptInterface::luaCreatureRemovePaperdollBySlot(lua_State* L)
{
	// creature:removePaperdollBySlot(slot)
	Creature* creature = getUserdata<Creature>(L, 1);
	if (creature) {
		uint8_t slot = getNumber<uint16_t>(L, 2);
		pushBoolean(L, creature->removePaperdollBySlot(slot));
	}
	else {
		lua_pushnil(L);
	}
	return 1;
}

