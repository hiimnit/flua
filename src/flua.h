#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef void* flua_State;

FFI_PLUGIN_EXPORT flua_State flua_create(void);
FFI_PLUGIN_EXPORT void flua_close(flua_State state);

FFI_PLUGIN_EXPORT int flua_do_string(flua_State state, const char* code);

FFI_PLUGIN_EXPORT void flua_set_global(flua_State state, const char* name);
FFI_PLUGIN_EXPORT void flua_set_global_int(flua_State state, const char* name, int64_t value);
FFI_PLUGIN_EXPORT void flua_set_global_double(flua_State state, const char* name, double value);
FFI_PLUGIN_EXPORT void flua_set_global_string(flua_State state, const char* name, const char* value);
FFI_PLUGIN_EXPORT void flua_set_global_bool(flua_State state, const char* name, int value);
FFI_PLUGIN_EXPORT void flua_set_global_nil(flua_State state, const char* name);

FFI_PLUGIN_EXPORT void flua_push_int(flua_State state, int64_t value);
FFI_PLUGIN_EXPORT void flua_push_double(flua_State state, double value);
FFI_PLUGIN_EXPORT void flua_push_string(flua_State state, const char* value);
FFI_PLUGIN_EXPORT void flua_push_bool(flua_State state, int value);
FFI_PLUGIN_EXPORT void flua_push_nil(flua_State state);
FFI_PLUGIN_EXPORT void flua_new_table(flua_State state);
FFI_PLUGIN_EXPORT void flua_create_table(flua_State state, int narray, int nrec);
FFI_PLUGIN_EXPORT void flua_set_field(flua_State state, int idx, const char* name);
FFI_PLUGIN_EXPORT void flua_set_table(flua_State state, int idx);
FFI_PLUGIN_EXPORT void flua_set_index(flua_State state, int idx, int64_t n);
FFI_PLUGIN_EXPORT void flua_raw_set_index(flua_State state, int idx, int64_t n);
// TODO: flua_push_function - generic c function that calls dart?

FFI_PLUGIN_EXPORT int flua_get_global_type(flua_State state, const char* name);
FFI_PLUGIN_EXPORT int64_t flua_get_global_int(flua_State state, const char* name);
FFI_PLUGIN_EXPORT double flua_get_global_double(flua_State state, const char* name);
FFI_PLUGIN_EXPORT const char* flua_get_global_string(flua_State state, const char* name);
FFI_PLUGIN_EXPORT int flua_get_global_bool(flua_State state, const char* name);

FFI_PLUGIN_EXPORT int flua_prepare_pcall(flua_State state, const char* func_name);
FFI_PLUGIN_EXPORT int flua_pcall(flua_State state, int arg_count);

FFI_PLUGIN_EXPORT int64_t flua_call_result_int(flua_State state, int index);
FFI_PLUGIN_EXPORT double flua_call_result_double(flua_State state, int index);
FFI_PLUGIN_EXPORT const char* flua_call_result_string(flua_State state, int index);
FFI_PLUGIN_EXPORT int flua_call_result_bool(flua_State state, int index);

FFI_PLUGIN_EXPORT const char* flua_error(flua_State state);
FFI_PLUGIN_EXPORT int flua_gettop(flua_State state);
FFI_PLUGIN_EXPORT void flua_pop(flua_State state, int n);
FFI_PLUGIN_EXPORT int flua_type(flua_State state, int idx);

enum {
  FLUA_TYPE_NIL = 0,
  FLUA_TYPE_BOOLEAN = 1,
  FLUA_TYPE_NUMBER = 3,
  FLUA_TYPE_STRING = 4,
  FLUA_TYPE_TABLE = 5,
  FLUA_TYPE_FUNCTION = 6,
  FLUA_TYPE_NONE = -1,
};
