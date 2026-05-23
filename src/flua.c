#include "flua.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// TODO: inspiration https://github.com/neovim/neovim/blob/d788dd2811bfbfb0daa915ef974d072075a6bceb/src/nvim/lua/executor.c#L916
// TODO: https://www.lua.org/pil/25.2.html
// TODO: no pop no lua_settop?

FFI_PLUGIN_EXPORT flua_State flua_create(void) {
  FLUA_TNONE = LUA_TNONE;
  FLUA_TNIL = LUA_TNIL;
  FLUA_TBOOLEAN = LUA_TBOOLEAN;
  FLUA_TLIGHTUSERDATA = LUA_TLIGHTUSERDATA;
  FLUA_TNUMBER = LUA_TNUMBER;
  FLUA_TSTRING = LUA_TSTRING;
  FLUA_TTABLE = LUA_TTABLE;
  FLUA_TFUNCTION = LUA_TFUNCTION;
  FLUA_TUSERDATA = LUA_TUSERDATA;
  FLUA_TTHREAD = LUA_TTHREAD;
  FLUA_REGISTRYINDEX = LUA_REGISTRYINDEX;

  lua_State* L = luaL_newstate();
  if (L) {
    luaL_openlibs(L);
  }
  return (flua_State)L;
}

FFI_PLUGIN_EXPORT void flua_close(flua_State state) {
  lua_State* L = (lua_State*)state;
  if (L) {
    lua_close(L);
  }
}

FFI_PLUGIN_EXPORT int flua_do_string(flua_State state, const char* code) {
  lua_State* L = (lua_State*)state;
  return luaL_dostring(L, code);
}

FFI_PLUGIN_EXPORT void flua_set_global(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_set_global_int(flua_State state, const char* name, int64_t value) {
  lua_State* L = (lua_State*)state;
  lua_pushinteger(L, (lua_Integer)value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_set_global_double(flua_State state, const char* name, double value) {
  lua_State* L = (lua_State*)state;
  lua_pushnumber(L, (lua_Number)value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_set_global_string(flua_State state, const char* name, const char* value) {
  lua_State* L = (lua_State*)state;
  lua_pushstring(L, value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_set_global_bool(flua_State state, const char* name, int value) {
  lua_State* L = (lua_State*)state;
  lua_pushboolean(L, value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_set_global_nil(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_pushnil(L);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_push_int(flua_State state, int64_t value) {
  lua_State* L = (lua_State*)state;
  lua_pushinteger(L, (lua_Integer)value);
}

FFI_PLUGIN_EXPORT void flua_push_double(flua_State state, double value) {
  lua_State* L = (lua_State*)state;
  lua_pushnumber(L, (lua_Number)value);
}

FFI_PLUGIN_EXPORT void flua_push_string(flua_State state, const char* value) {
  lua_State* L = (lua_State*)state;
  lua_pushstring(L, value);
}

FFI_PLUGIN_EXPORT void flua_push_bool(flua_State state, int value) {
  lua_State* L = (lua_State*)state;
  lua_pushboolean(L, value);
}

FFI_PLUGIN_EXPORT void flua_push_nil(flua_State state) {
  lua_State* L = (lua_State*)state;
  lua_pushnil(L);
}

FFI_PLUGIN_EXPORT void flua_push_value(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_pushvalue(L, idx);
}

FFI_PLUGIN_EXPORT void flua_push_c_function(flua_State state, flua_CFunction fn) {
  lua_State* L = (lua_State*)state;
  lua_CFunction f = (lua_CFunction)fn;
  lua_pushcfunction(L, f);
}

FFI_PLUGIN_EXPORT void flua_new_table(flua_State state) {
  lua_State* L = (lua_State*)state;
  lua_newtable(L);
}

FFI_PLUGIN_EXPORT void flua_create_table(flua_State state, int narray, int nrec) {
  lua_State* L = (lua_State*)state;
  lua_createtable(state, narray, nrec);
}

FFI_PLUGIN_EXPORT void flua_set_field(flua_State state, int idx, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_setfield(L, idx, name);
}

FFI_PLUGIN_EXPORT void flua_set_table(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_settable(L, idx);
}

FFI_PLUGIN_EXPORT void flua_raw_set(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_rawset(L, idx);
}

FFI_PLUGIN_EXPORT void flua_set_i(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  lua_seti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT void flua_raw_set_i(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  lua_rawseti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_get_global_type(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  int type = lua_type(L, -1);
  lua_pop(L, 1);
  return type;
}

FFI_PLUGIN_EXPORT int64_t flua_get_global_int(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  int64_t value = (int64_t)lua_tointeger(L, -1);
  lua_pop(L, 1);
  return value;
}

FFI_PLUGIN_EXPORT double flua_get_global_double(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  double value = lua_tonumber(L, -1);
  lua_pop(L, 1);
  return value;
}

FFI_PLUGIN_EXPORT const char* flua_get_global_string(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  const char* string = lua_tostring(L, -1);
  lua_pop(L, 1);
  return string;
}

FFI_PLUGIN_EXPORT int flua_get_global_bool(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  int value = lua_toboolean(L, -1);
  lua_pop(L, 1);
  return value;
}

FFI_PLUGIN_EXPORT int flua_get_global(flua_State state, const char *name) {
  lua_State* L = (lua_State*)state;
  return lua_getglobal(L, name);
}

FFI_PLUGIN_EXPORT int flua_get_table(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_gettable(L, idx);
}

FFI_PLUGIN_EXPORT int flua_raw_get(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_rawget(L, idx);
}

FFI_PLUGIN_EXPORT int flua_get_i(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  return lua_geti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_raw_get_i(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  return lua_rawgeti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_prepare_pcall(flua_State state, const char* func_name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, func_name);
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 1);
    return 1; // FIXME: why is this not named?
  }
  return LUA_OK; // FIXME: or just stop misusing LUA_OK?
}

FFI_PLUGIN_EXPORT int flua_pcall(flua_State state,  int arg_count) {
  lua_State* L = (lua_State*)state;
  int status = lua_pcall(L, arg_count, LUA_MULTRET, 0);
  if (status != LUA_OK) {
    return status;
  }
  return LUA_OK;
}

FFI_PLUGIN_EXPORT int64_t flua_to_integer(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int64_t value = (int64_t)lua_tointeger(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT double flua_to_number(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  double value = lua_tonumber(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT const char* flua_to_string(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_tostring(L, idx);
}

FFI_PLUGIN_EXPORT int flua_to_boolean(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int value = lua_toboolean(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT double flua_check_number(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return (double)luaL_checknumber(L, arg);
}

FFI_PLUGIN_EXPORT double flua_opt_number(flua_State state, int arg, double def) {
  lua_State* L = (lua_State*)state;
  return (double)luaL_optnumber(L, arg, (lua_Number)def);
}

FFI_PLUGIN_EXPORT int64_t flua_check_integer(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return (int64_t)luaL_checkinteger(L, arg);
}

FFI_PLUGIN_EXPORT int64_t flua_opt_integer(flua_State state, int arg, int64_t def) {
  lua_State* L = (lua_State*)state;
  return (int64_t)luaL_optinteger(L, arg, (lua_Integer)def);
}

FFI_PLUGIN_EXPORT const char* flua_check_string(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return luaL_checklstring(L, arg, NULL);
}

FFI_PLUGIN_EXPORT const char* flua_opt_string(flua_State state, int arg, const char* def) {
  lua_State* L = (lua_State*)state;
  return luaL_optlstring(L, arg, def, NULL);
}

FFI_PLUGIN_EXPORT void flua_check_stack(flua_State state, int sz, const char* msg) {
  lua_State* L = (lua_State*)state;
  luaL_checkstack(L, sz, msg);
}

FFI_PLUGIN_EXPORT void flua_check_type(flua_State state, int arg, int t) {
  lua_State* L = (lua_State*)state;
  luaL_checktype(L, arg, t);
}

FFI_PLUGIN_EXPORT void flua_check_any(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  luaL_checkany(L, arg);
}

FFI_PLUGIN_EXPORT int flua_is_none_or_nil(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return lua_isnoneornil(L, arg);
}

FFI_PLUGIN_EXPORT const char* flua_error(flua_State state) {
  lua_State* L = (lua_State*)state;
  if (lua_gettop(L) > 0) {
    return lua_tostring(L, -1);
  }
  return NULL;
}

FFI_PLUGIN_EXPORT int flua_gettop(flua_State state) {
  lua_State* L = (lua_State*)state;
  return lua_gettop(L);
}

FFI_PLUGIN_EXPORT void flua_pop(flua_State state, int n) {
  lua_State* L = (lua_State*)state;
  lua_pop(L, n);
}

FFI_PLUGIN_EXPORT void flua_set_top(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_settop(L, idx);
}

FFI_PLUGIN_EXPORT int flua_type(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_type(L, idx);
}

FFI_PLUGIN_EXPORT int flua_next(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_next(L, idx);
}

FFI_PLUGIN_EXPORT int flua_ref(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return luaL_ref(L, idx);
}

FFI_PLUGIN_EXPORT void flua_unref(flua_State state, int idx, int ref) {
  lua_State* L = (lua_State*)state;
  luaL_unref(L, idx, ref);
}

