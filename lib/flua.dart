import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'flua_bindings_generated.dart' as bindings;

class LuaException implements Exception {
  final String message;

  LuaException(this.message);

  @override
  String toString() => 'LuaException: $message';
}

enum LuaType {
  none(-1),
  nil(bindings.FLUA_TYPE_NIL),
  boolean(bindings.FLUA_TYPE_BOOLEAN),
  number(bindings.FLUA_TYPE_NUMBER),
  string(bindings.FLUA_TYPE_STRING),
  table(bindings.FLUA_TYPE_TABLE),
  function(bindings.FLUA_TYPE_FUNCTION);

  final int value;
  const LuaType(this.value);

  static LuaType fromValue(int value) {
    for (final type in LuaType.values) {
      if (type.value == value) return type;
    }
    return LuaType.none;
  }
}

class LuaState implements Finalizable {
  final bindings.flua_State _state;
  bool _closed = false;

  static final _finalizer = NativeFinalizer(
    Native.addressOf(bindings.flua_close),
  );

  void _checkValid() {
    if (_closed) {
      throw LuaException('Lua state has been closed');
    }
  }

  LuaState() : _state = bindings.flua_create() {
    if (_state.address == 0) {
      // TODO is this necessary?
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

  LuaType typeOf(String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      return LuaType.fromValue(
        bindings.flua_get_global_type(_state, nativeName.cast()),
      );
    } finally {
      malloc.free(nativeName);
    }
  }

  Object? operator [](String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      final type = LuaType.fromValue(
        bindings.flua_get_global_type(_state, nativeName.cast()),
      ); // TODO: getting type and then value? not at once?
      // TODO: wrap the returned value?
      switch (type) {
        case LuaType.nil:
          return null;
        case LuaType.boolean:
          return bindings.flua_get_global_bool(_state, nativeName.cast()) != 0;
        case LuaType.number:
          return bindings.flua_get_global_double(_state, nativeName.cast());
        case LuaType.string:
          final ptr = bindings.flua_get_global_string(
            _state,
            nativeName.cast(),
          );
          return ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : null;
        case LuaType.function:
          return _LuaFunction(this, name);
        case LuaType.table:
          return _LuaTable(this, name);
        default:
          return null;
      }
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
    bindings.flua_new_table(_state); // TODO: lua_createtable?

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
    bindings.flua_new_table(_state); // TODO: lua_createtable?

    for (final MapEntry(:key, :value) in table.entries) {
      _pushValue(key);
      _pushValue(value);
      bindings.flua_set_table(_state, -3);
    }
  }

  void _pushNewListTable(List<dynamic> list) {
    bindings.flua_new_table(_state); // TODO: lua_createtable?

    for (final (i, value) in list.indexed) {
      _pushValue(value);
      bindings.flua_raw_set_index(_state, -2, i + 1);
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
        // TODO: luaL_checkstack
      }
      final status = bindings.flua_pcall(_state, args.length);
      if (status != 0) {
        final errorPtr = bindings.flua_error(_state);
        final error = errorPtr.address != 0
            ? errorPtr.cast<Utf8>().toDartString()
            : 'Unknown error';
        throw LuaException(error);
      }

      return _popResults(pretop);
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

  List<Object?> _popResults(int pretop) {
    final count = bindings.flua_gettop(_state) - pretop;
    final results = <Object?>[];
    for (int i = 0; i < count; ++i) {
      final stackIndex = -(count - i);
      final type = bindings.flua_type(_state, stackIndex);

      switch (LuaType.fromValue(type)) {
        case LuaType.nil:
          results.add(null);
          break;
        case LuaType.boolean:
          results.add(bindings.flua_call_result_bool(_state, stackIndex) != 0);
          break;
        case LuaType.number:
          results.add(bindings.flua_call_result_double(_state, stackIndex));
          break;
        case LuaType.string:
          final ptr = bindings.flua_call_result_string(_state, stackIndex);
          results.add(
            ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : null,
          );
          break;
        default:
          // TODO: what happens here?
          results.add(null);
      }
    }

    if (results.isNotEmpty) {
      bindings.flua_pop(_state, results.length);
    }

    return results;
  }

  // TODO: tmp methods? doStringWithReturn?
  int top() => bindings.flua_gettop(_state);

  List<Object?> popResults(int pretop) => _popResults(pretop);
}

class _LuaFunction {
  final String _name;

  _LuaFunction(LuaState state, this._name);

  List<dynamic> call([List<dynamic> args = const []]) {
    throw UnimplementedError('Use LuaState.call instead');
  }

  @override
  String toString() => 'LuaFunction($_name)';
}

class _LuaTable {
  final String _name;

  _LuaTable(LuaState state, this._name);

  @override
  String toString() => 'LuaTable($_name)';
}
