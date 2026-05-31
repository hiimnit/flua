#include "flua.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

FFI_PLUGIN_EXPORT flua_State flua_create(void) {
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

FFI_PLUGIN_EXPORT int flua_dostring(flua_State state, const char* code) {
  lua_State* L = (lua_State*)state;
  return luaL_dostring(L, code);
}

FFI_PLUGIN_EXPORT int flua_absindex(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_absindex(L, idx);
}

FFI_PLUGIN_EXPORT void flua_setglobal(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_setglobalint(flua_State state, const char* name, int64_t value) {
  lua_State* L = (lua_State*)state;
  lua_pushinteger(L, (lua_Integer)value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_setglobaldouble(flua_State state, const char* name, double value) {
  lua_State* L = (lua_State*)state;
  lua_pushnumber(L, (lua_Number)value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_setglobalstring(flua_State state, const char* name, const char* value) {
  lua_State* L = (lua_State*)state;
  lua_pushstring(L, value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_setglobalbool(flua_State state, const char* name, int value) {
  lua_State* L = (lua_State*)state;
  lua_pushboolean(L, value);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_setglobalnil(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_pushnil(L);
  lua_setglobal(L, name);
}

FFI_PLUGIN_EXPORT void flua_pushint(flua_State state, int64_t value) {
  lua_State* L = (lua_State*)state;
  lua_pushinteger(L, (lua_Integer)value);
}

FFI_PLUGIN_EXPORT void flua_pushdouble(flua_State state, double value) {
  lua_State* L = (lua_State*)state;
  lua_pushnumber(L, (lua_Number)value);
}

FFI_PLUGIN_EXPORT void flua_pushstring(flua_State state, const char* value) {
  lua_State* L = (lua_State*)state;
  lua_pushstring(L, value);
}

FFI_PLUGIN_EXPORT void flua_pushbool(flua_State state, int value) {
  lua_State* L = (lua_State*)state;
  lua_pushboolean(L, value);
}

FFI_PLUGIN_EXPORT void flua_pushnil(flua_State state) {
  lua_State* L = (lua_State*)state;
  lua_pushnil(L);
}

FFI_PLUGIN_EXPORT void flua_pushvalue(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_pushvalue(L, idx);
}

FFI_PLUGIN_EXPORT void flua_pushcfunction(flua_State state, flua_CFunction fn) {
  lua_State* L = (lua_State*)state;
  lua_CFunction f = (lua_CFunction)fn;
  lua_pushcfunction(L, f);
}

FFI_PLUGIN_EXPORT void flua_newtable(flua_State state) {
  lua_State* L = (lua_State*)state;
  lua_newtable(L);
}

FFI_PLUGIN_EXPORT void flua_createtable(flua_State state, int narray, int nrec) {
  lua_State* L = (lua_State*)state;
  lua_createtable(state, narray, nrec);
}

FFI_PLUGIN_EXPORT void flua_setfield(flua_State state, int idx, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_setfield(L, idx, name);
}

FFI_PLUGIN_EXPORT void flua_settable(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_settable(L, idx);
}

FFI_PLUGIN_EXPORT void flua_rawset(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  lua_rawset(L, idx);
}

FFI_PLUGIN_EXPORT void flua_seti(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  lua_seti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT void flua_rawseti(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  lua_rawseti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_getglobaltype(flua_State state, const char* name) {
  lua_State* L = (lua_State*)state;
  lua_getglobal(L, name);
  int type = lua_type(L, -1);
  lua_pop(L, 1);
  return type;
}

FFI_PLUGIN_EXPORT int flua_getglobal(flua_State state, const char *name) {
  lua_State* L = (lua_State*)state;
  return lua_getglobal(L, name);
}

FFI_PLUGIN_EXPORT int flua_gettable(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_gettable(L, idx);
}

FFI_PLUGIN_EXPORT int flua_rawget(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_rawget(L, idx);
}

FFI_PLUGIN_EXPORT int flua_geti(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  return lua_geti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_rawgeti(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  return lua_rawgeti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT int flua_pcall(flua_State state,  int arg_count) {
  lua_State* L = (lua_State*)state;
  int status = lua_pcall(L, arg_count, LUA_MULTRET, 0);
  if (status != LUA_OK) {
    return status;
  }
  return 0;
}

FFI_PLUGIN_EXPORT int64_t flua_tointeger(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int64_t value = (int64_t)lua_tointeger(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT double flua_tonumber(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  double value = lua_tonumber(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT const char* flua_tostring(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_tostring(L, idx);
}

FFI_PLUGIN_EXPORT int flua_toboolean(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int value = lua_toboolean(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT double flua_checknumber(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return (double)luaL_checknumber(L, arg);
}

FFI_PLUGIN_EXPORT double flua_optnumber(flua_State state, int arg, double def) {
  lua_State* L = (lua_State*)state;
  return (double)luaL_optnumber(L, arg, (lua_Number)def);
}

FFI_PLUGIN_EXPORT int64_t flua_checkinteger(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return (int64_t)luaL_checkinteger(L, arg);
}

FFI_PLUGIN_EXPORT int64_t flua_optinteger(flua_State state, int arg, int64_t def) {
  lua_State* L = (lua_State*)state;
  return (int64_t)luaL_optinteger(L, arg, (lua_Integer)def);
}

FFI_PLUGIN_EXPORT const char* flua_checklstring(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return luaL_checklstring(L, arg, NULL);
}

FFI_PLUGIN_EXPORT const char* flua_optlstring(flua_State state, int arg, const char* def) {
  lua_State* L = (lua_State*)state;
  return luaL_optlstring(L, arg, def, NULL);
}

FFI_PLUGIN_EXPORT void flua_checkstack(flua_State state, int sz, const char* msg) {
  lua_State* L = (lua_State*)state;
  luaL_checkstack(L, sz, msg);
}

FFI_PLUGIN_EXPORT void flua_checktype(flua_State state, int arg, int t) {
  lua_State* L = (lua_State*)state;
  luaL_checktype(L, arg, t);
}

FFI_PLUGIN_EXPORT void flua_checkany(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  luaL_checkany(L, arg);
}

FFI_PLUGIN_EXPORT int flua_isnoneornil(flua_State state, int arg) {
  lua_State* L = (lua_State*)state;
  return lua_isnoneornil(L, arg);
}

FFI_PLUGIN_EXPORT int flua_registryindex(void) {
  return LUA_REGISTRYINDEX;
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

FFI_PLUGIN_EXPORT void flua_settop(flua_State state, int idx) {
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

