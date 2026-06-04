// put inside class LuaScriptInterface
public:
	template<typename T>
	static T getField(lua_State* L, int32_t arg, const std::string& key, T defaultValue)
	{
		lua_getfield(L, arg, key.c_str());
		if (lua_isnil(L, -1) == 1)
			return defaultValue;

		return getNumber<T>(L, -1);
	}

	// Paperdoll
	static Paperdoll_t getPaperdoll(lua_State* L, int32_t arg);
	static void pushPaperdoll(lua_State* L, const Paperdoll_t& paperdoll);

	static int luaCreatureAddPaperdoll(lua_State* L);
	static int luaCreatureGetPaperdolls(lua_State* L);
	static int luaCreatureSetPaperdoll(lua_State* L);
	static int luaCreatureHasPaperdollById(lua_State* L);
	static int luaCreatureHasPaperdollBySlot(lua_State* L);
	static int luaCreatureGetPaperdollById(lua_State* L);
	static int luaCreatureGetPaperdollBySlot(lua_State* L);
	static int luaCreatureRemovePaperdollById(lua_State* L);
	static int luaCreatureRemovePaperdollBySlot(lua_State* L);