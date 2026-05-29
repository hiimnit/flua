import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'flua_bindings_generated.dart' as bindings;
export 'flua_bindings_generated.dart' show flua_CFunctionFunction;

class LuaException implements Exception {
  final String message;

  LuaException(this.message);

  @override
  String toString() => 'LuaException: $message';
}

enum LuaType {
  none(-1),
  nil(0),
  boolean(1),
  lightuserdata(2),
  number(3),
  string(4),
  table(5),
  function(6),
  userdata(7),
  thread(8);

  final int value;

  const LuaType(this.value);

  static LuaType? from(int input) {
    for (final type in LuaType.values) {
      if (type.value == input) {
        return type;
      }
    }
    return null;
  }
}

const kLuaRegistryIndex = -1001000;

class LuaState implements Finalizable {
  final bindings.flua_State _state;
  bool _closed = false;

  static final _finalizer = NativeFinalizer(
    Native.addressOf(bindings.flua_close),
  );

  // TODO: is this called everywhere it should be?
  void _checkValid() {
    if (_closed) {
      throw LuaException('Lua state has been closed');
    }
  }

  LuaState() : _state = bindings.flua_create() {
    if (_state.address == 0) {
      throw LuaException('Failed to create Lua state');
    }
    _finalizer.attach(this, _state, detach: this);
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _finalizer.detach(this);
    bindings.flua_close(_state);
  }

  bool get isClosed => _closed;

  void doString(String code) {
    _checkValid();
    final nativeCode = code.toNativeUtf8();
    try {
      final result = bindings.flua_do_string(_state, nativeCode.cast());
      if (result != 0) {
        final errorPtr = bindings.flua_error(_state);
        final error = errorPtr.address != 0
            ? errorPtr.cast<Utf8>().toDartString()
            : 'Unknown error';
        throw LuaException(error);
      }
    } finally {
      malloc.free(nativeCode);
    }
  }

  LuaType? typeOf(String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      final type = bindings.flua_get_global_type(_state, nativeName.cast());
      return LuaType.from(type);
    } finally {
      malloc.free(nativeName);
    }
  }

  LuaType? typeAt(int idx) {
    _checkValid();

    final type = bindings.flua_type(_state, idx);
    return LuaType.from(type);
  }

  Object? operator [](String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      final type = bindings.flua_get_global(_state, nativeName.cast());
      return _getValueOfType(-1, LuaType.from(type));
    } finally {
      malloc.free(nativeName);
    }
  }

  void operator []=(String name, Object? value) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      _pushValue(value);
      bindings.flua_set_global(_state, nativeName.cast());
    } finally {
      malloc.free(nativeName);
    }
  }

  void _pushNewStringMapTable(Map<String, dynamic> table) {
    bindings.flua_new_table(_state); // TODO: lua_createtable? we know the len

    for (final MapEntry(:key, :value) in table.entries) {
      final nativeKey = key.toNativeUtf8();
      try {
        _pushValue(value);
        bindings.flua_set_field(_state, -2, nativeKey.cast());
      } finally {
        malloc.free(nativeKey);
      }
    }
  }

  void _pushNewMapTable(Map table) {
    bindings.flua_new_table(_state); // TODO: lua_createtable? we know the len

    for (final MapEntry(:key, :value) in table.entries) {
      _pushValue(key);
      _pushValue(value);
      bindings.flua_set_table(_state, -3);
    }
  }

  void _pushNewListTable(List<dynamic> list) {
    bindings.flua_new_table(_state); // TODO: lua_createtable? we know the len

    for (final (i, value) in list.indexed) {
      _pushValue(value);
      bindings.flua_raw_set_i(_state, -2, i + 1);
    }
  }

  List<Object?> call(String funcName, [List<Object?> args = const []]) {
    _checkValid();

    final nativeName = funcName.toNativeUtf8();
    try {
      final pretop = bindings.flua_gettop(_state);

      final prepareResult = bindings.flua_prepare_pcall(
        _state,
        nativeName.cast(),
      );
      if (prepareResult != 0) {
        throw LuaException('$funcName is not a function.');
      }

      for (final arg in args) {
        _pushValue(arg);
      }

      final status = bindings.flua_pcall(_state, args.length);
      if (status != 0) {
        final errorPtr = bindings.flua_error(_state);
        final error = errorPtr.address != 0
            ? errorPtr.cast<Utf8>().toDartString()
            : 'Unknown error';
        throw LuaException(error);
      }

      return popResults(pretop);
    } finally {
      malloc.free(nativeName);
    }
  }

  List<Object?> _callLuaFunction(
    LuaFunction func, [
    List<Object?> args = const [],
  ]) {
    _checkValid();

    final pretop = bindings.flua_gettop(_state);

    final type = bindings.flua_raw_get_i(_state, kLuaRegistryIndex, func.ref);

    if (LuaType.from(type) != LuaType.function) {
      throw LuaException('$func is not a function.');
    }

    for (final arg in args) {
      _pushValue(arg);
    }

    final status = bindings.flua_pcall(_state, args.length);
    if (status != 0) {
      final errorPtr = bindings.flua_error(_state);
      final error = errorPtr.address != 0
          ? errorPtr.cast<Utf8>().toDartString()
          : 'Unknown error';
      throw LuaException(error);
    }

    return popResults(pretop);
  }

  void _unref(int ref) {
    _checkValid();

    bindings.flua_unref(_state, kLuaRegistryIndex, ref);
  }

  void pushFunction(
    Pointer<NativeFunction<bindings.flua_CFunctionFunction>> fp,
  ) {
    bindings.flua_push_c_function(_state, fp);
  }

  void setGlobal(String name) {
    final nativeName = name.toNativeUtf8();
    try {
      bindings.flua_set_global(_state, nativeName.cast());
    } finally {
      malloc.free(nativeName);
    }
  }

  void _pushValue(Object? value) {
    if (value == null) {
      bindings.flua_push_nil(_state);
    } else if (value is bool) {
      bindings.flua_push_bool(_state, value ? 1 : 0);
    } else if (value is int) {
      bindings.flua_push_int(_state, value);
    } else if (value is double) {
      bindings.flua_push_double(_state, value);
    } else if (value is num) {
      bindings.flua_push_double(_state, value.toDouble());
    } else if (value is String) {
      final nativeValue = value.toNativeUtf8();
      try {
        bindings.flua_push_string(_state, nativeValue.cast());
      } finally {
        malloc.free(nativeValue);
      }
    } else if (value is Map<String, dynamic>) {
      _pushNewStringMapTable(value);
    } else if (value is Map) {
      _pushNewMapTable(value);
    } else if (value is List<dynamic>) {
      _pushNewListTable(value);
    } else {
      // TODO: ???
    }
  }

  List<Object?> popResults(int pretop) {
    _checkValid();

    final count = bindings.flua_gettop(_state) - pretop;
    final results = <Object?>[];
    for (int i = 0; i < count; ++i) {
      final stackIndex = -(count - i);

      results.add(getValueAt(stackIndex));
    }

    bindings.flua_set_top(_state, pretop); // TODO: is this the way?

    return results;
  }

  Object? getValueAt(int idx) {
    _checkValid();

    final type = typeAt(idx);
    return _getValueOfType(idx, type);
  }

  Object? _getValueOfType(int idx, LuaType? type) {
    switch (type) {
      case LuaType.none: // TODO: different handling for none?
      case LuaType.nil:
        return null;
      case LuaType.boolean:
        return bindings.flua_to_boolean(_state, idx) != 0;
      case LuaType.number:
        return bindings.flua_to_number(_state, idx);
      case LuaType.string:
        final ptr = bindings.flua_to_string(_state, idx);
        return ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : null;
      case LuaType.table:
        return _traverseTable(idx);
      case LuaType.function:
        // copy the value to the top of the stack
        bindings.flua_push_value(_state, idx);
        // create a reference in registry
        final ref = bindings.flua_ref(_state, kLuaRegistryIndex);
        return LuaFunction(ref, this);
      case LuaType.lightuserdata:
        return const LuaLightUserData();
      case LuaType.userdata:
        return const LuaUserData();
      case LuaType.thread:
        return const LuaThread();
      default:
        // TODO: LuaUnknown?
        throw LuaException('Unknown lua type.');
    }
  }

  double checkNumber(int arg) {
    _checkValid();
    return bindings.flua_check_number(_state, arg);
  }

  double optNumber(int arg, double defaultValue) {
    _checkValid();
    return bindings.flua_opt_number(_state, arg, defaultValue);
  }

  int checkInteger(int arg) {
    _checkValid();
    return bindings.flua_check_integer(_state, arg);
  }

  int optInteger(int arg, int defaultValue) {
    _checkValid();
    return bindings.flua_opt_integer(_state, arg, defaultValue);
  }

  String checkString(int arg) {
    _checkValid();
    final ptr = bindings.flua_check_string(_state, arg);
    return ptr.cast<Utf8>().toDartString();
  }

  String optString(int arg, String defaultValue) {
    _checkValid();
    final nativeDef = defaultValue.toNativeUtf8();
    try {
      final ptr = bindings.flua_opt_string(_state, arg, nativeDef.cast());
      return ptr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(nativeDef);
    }
  }

  void checkStack(int extraSlots, String message) {
    _checkValid();
    final nativeMsg = message.toNativeUtf8();
    try {
      bindings.flua_check_stack(_state, extraSlots, nativeMsg.cast());
    } finally {
      malloc.free(nativeMsg);
    }
  }

  void checkType(int arg, LuaType type) {
    _checkValid();
    bindings.flua_check_type(_state, arg, type.value);
  }

  void checkAny(int arg) {
    _checkValid();
    bindings.flua_check_any(_state, arg);
  }

  bool isNoneOrNil(int arg) {
    _checkValid();
    return bindings.flua_is_none_or_nil(_state, arg) != 0;
  }

  Map<Object?, Object?> _traverseTable(int idx) {
    idx = bindings.flua_abs_index(_state, idx);

    final result = {};
    // TODO: checkstack

    bindings.flua_push_nil(_state);
    while (bindings.flua_next(_state, idx) != 0) {
      result[getValueAt(-2)] = getValueAt(-1);

      // pop value, keep key on stack for flua_next
      bindings.flua_pop(_state, 1);
    }

    return result;
  }

  // TODO: _checkValid();
  int get top => bindings.flua_gettop(_state);
}

// TODO: ref counting => auto unref?
class LuaFunction {
  final int ref;
  final LuaState _state;
  bool _valid;

  LuaFunction(this.ref, LuaState state) : _state = state, _valid = true;

  bool get valid => _valid;

  List<Object?> call([List<Object?> args = const []]) {
    if (!_valid) {
      throw LuaException('Function reference is not valid.');
    }
    return _state._callLuaFunction(this, args);
  }

  void unref() {
    _state._unref(ref);
    _valid = false;
  }
}

class LuaLightUserData {
  const LuaLightUserData();
}

class LuaUserData {
  const LuaUserData();
}

class LuaThread {
  const LuaThread();
}
