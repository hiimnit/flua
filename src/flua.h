#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef void* flua_State;
typedef int (*flua_CFunction) (flua_State L);

FFI_PLUGIN_EXPORT flua_State flua_create(void);
FFI_PLUGIN_EXPORT void flua_close(flua_State state);

FFI_PLUGIN_EXPORT int flua_dostring(flua_State state, const char* code);
FFI_PLUGIN_EXPORT int flua_loadstring(flua_State state, const char* code);

FFI_PLUGIN_EXPORT void flua_setglobal(flua_State state, const char* name);
FFI_PLUGIN_EXPORT void flua_setglobalint(flua_State state, const char* name, int64_t value);
FFI_PLUGIN_EXPORT void flua_setglobaldouble(flua_State state, const char* name, double value);
FFI_PLUGIN_EXPORT void flua_setglobalstring(flua_State state, const char* name, const char* value);
FFI_PLUGIN_EXPORT void flua_setglobalbool(flua_State state, const char* name, int value);
FFI_PLUGIN_EXPORT void flua_setglobalnil(flua_State state, const char* name);

FFI_PLUGIN_EXPORT void flua_pushint(flua_State state, int64_t value);
FFI_PLUGIN_EXPORT void flua_pushdouble(flua_State state, double value);
FFI_PLUGIN_EXPORT void flua_pushstring(flua_State state, const char* value);
FFI_PLUGIN_EXPORT void flua_pushbool(flua_State state, int value);
FFI_PLUGIN_EXPORT void flua_pushnil(flua_State state);
FFI_PLUGIN_EXPORT void flua_pushvalue(flua_State state, int idx);
FFI_PLUGIN_EXPORT void flua_pushcfunction(flua_State state, flua_CFunction fn);

FFI_PLUGIN_EXPORT void flua_newtable(flua_State state);
FFI_PLUGIN_EXPORT void flua_createtable(flua_State state, int narray, int nrec);
FFI_PLUGIN_EXPORT void flua_setfield(flua_State state, int idx, const char* name);
FFI_PLUGIN_EXPORT void flua_settable(flua_State state, int idx);
FFI_PLUGIN_EXPORT void flua_rawset(flua_State state, int idx);
FFI_PLUGIN_EXPORT void flua_seti(flua_State state, int idx, int64_t n);
FFI_PLUGIN_EXPORT void flua_rawseti(flua_State state, int idx, int64_t n);
FFI_PLUGIN_EXPORT int flua_getglobaltype(flua_State state, const char* name);
FFI_PLUGIN_EXPORT int flua_getglobal(flua_State state, const char *name);
FFI_PLUGIN_EXPORT int flua_gettable(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_rawget(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_geti(flua_State state, int idx, int64_t n);
FFI_PLUGIN_EXPORT int flua_rawgeti(flua_State state, int idx, int64_t n);

FFI_PLUGIN_EXPORT int flua_pcall(flua_State state,  int arg_count);

FFI_PLUGIN_EXPORT int64_t flua_tointeger(flua_State state, int idx);
FFI_PLUGIN_EXPORT double flua_tonumber(flua_State state, int idx);
FFI_PLUGIN_EXPORT const char* flua_tostring(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_toboolean(flua_State state, int idx);
FFI_PLUGIN_EXPORT double flua_checknumber(flua_State state, int arg);
FFI_PLUGIN_EXPORT double flua_optnumber(flua_State state, int arg, double def);
FFI_PLUGIN_EXPORT int64_t flua_checkinteger(flua_State state, int arg);
FFI_PLUGIN_EXPORT int64_t flua_optinteger(flua_State state, int arg, int64_t def);
FFI_PLUGIN_EXPORT const char* flua_checklstring(flua_State state, int arg);
FFI_PLUGIN_EXPORT const char* flua_optlstring(flua_State state, int arg, const char* def);
FFI_PLUGIN_EXPORT void flua_checkstack(flua_State state, int sz, const char* msg);
FFI_PLUGIN_EXPORT void flua_checktype(flua_State state, int arg, int t);
FFI_PLUGIN_EXPORT void flua_checkany(flua_State state, int arg);
FFI_PLUGIN_EXPORT int flua_isnoneornil(flua_State state, int arg);

FFI_PLUGIN_EXPORT int flua_registryindex(void);
FFI_PLUGIN_EXPORT const char* flua_error(flua_State state);
FFI_PLUGIN_EXPORT int flua_gettop(flua_State state);
FFI_PLUGIN_EXPORT void flua_pop(flua_State state, int n);
FFI_PLUGIN_EXPORT void flua_settop(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_absindex(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_type(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_next(flua_State state, int idx);
FFI_PLUGIN_EXPORT int flua_ref(flua_State state, int idx);
FFI_PLUGIN_EXPORT void flua_unref(flua_State state, int idx, int ref);

FFI_PLUGIN_EXPORT flua_State flua_newthread(flua_State state);
FFI_PLUGIN_EXPORT int flua_resume(flua_State thread, flua_State from, int nargs);
FFI_PLUGIN_EXPORT int flua_status(flua_State state);

FFI_PLUGIN_EXPORT void flua_push_async_function(flua_State state, int64_t id);
