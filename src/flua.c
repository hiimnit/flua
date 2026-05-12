#include "flua.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <string.h>

// TODO: inspiration https://github.com/neovim/neovim/blob/d788dd2811bfbfb0daa915ef974d072075a6bceb/src/nvim/lua/executor.c#L916
// TODO: https://www.lua.org/pil/25.2.html
// TODO: no pop no lua_settop?

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


FFI_PLUGIN_EXPORT void flua_set_index(flua_State state, int idx, int64_t n) {
  lua_State* L = (lua_State*)state;
  lua_seti(L, idx, (lua_Integer)n);
}

FFI_PLUGIN_EXPORT void flua_raw_set_index(flua_State state, int idx, int64_t n) {
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
  char* string = lua_tostring(L, -1);
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

FFI_PLUGIN_EXPORT int64_t flua_call_result_int(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int64_t value = (int64_t)lua_tointeger(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT double flua_call_result_double(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  double value = lua_tonumber(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT const char* flua_call_result_string(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  return lua_tostring(L, idx);
}

FFI_PLUGIN_EXPORT int flua_call_result_bool(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int value = lua_toboolean(L, idx);
  return value;
}

FFI_PLUGIN_EXPORT const char* flua_error(flua_State state) {
  lua_State* L = (lua_State*)state;
  if (lua_gettop(L) > 0) { // FIXME: remove this?
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

FFI_PLUGIN_EXPORT int flua_type(flua_State state, int idx) {
  lua_State* L = (lua_State*)state;
  int type = lua_type(L, idx);
  return type;
}
