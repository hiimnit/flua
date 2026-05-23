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
  none,
  nil,
  boolean,
  lightuserdata,
  number,
  string,
  table,
  function,
  userdata,
  thread,

  unknown,
}

class LuaState implements Finalizable {
  final bindings.flua_State _state;
  bool _closed = false;
  // TODO: is hashing worth it?
  final Map<int, LuaType> _types = {};

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
      throw LuaException('Failed to create Lua state');
    }
    _types.addAll({
      bindings.FLUA_TNONE: LuaType.none,
      bindings.FLUA_TNIL: LuaType.nil,
      bindings.FLUA_TBOOLEAN: LuaType.boolean,
      bindings.FLUA_TLIGHTUSERDATA: LuaType.lightuserdata,
      bindings.FLUA_TNUMBER: LuaType.number,
      bindings.FLUA_TSTRING: LuaType.string,
      bindings.FLUA_TTABLE: LuaType.table,
      bindings.FLUA_TFUNCTION: LuaType.function,
      bindings.FLUA_TUSERDATA: LuaType.userdata,
      bindings.FLUA_TTHREAD: LuaType.thread,
    });
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
      return _types[bindings.flua_get_global_type(_state, nativeName.cast())] ??
          LuaType.unknown;
    } finally {
      malloc.free(nativeName);
    }
  }

  Object? operator [](String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      final type =
          _types[bindings.flua_get_global_type(_state, nativeName.cast())] ??
          LuaType.unknown; // TODO: getting type and then value? not at once?
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
          throw UnimplementedError();
        case LuaType.table:
          throw UnimplementedError();
        default:
          // TODO: ???
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
        // TODO: luaL_checkstack lua_checkstack
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

    final type = bindings.flua_raw_get_i(
      _state,
      bindings.FLUA_REGISTRYINDEX,
      func.ref,
    );

    if (_types[type] != LuaType.function) {
      throw LuaException('$func is not a function.');
    }
    for (final arg in args) {
      _pushValue(arg);
      // TODO: luaL_checkstack lua_checkstack
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

    bindings.flua_unref(_state, bindings.FLUA_REGISTRYINDEX, ref);
  }

  void pushFunction(
    Pointer<NativeFunction<bindings.flua_CFunctionFunction>> fp,
  ) {
    bindings.flua_push_c_function(_state, fp);
    final nativeName = 'dartprint'.toNativeUtf8();
    bindings.flua_set_global(_state, nativeName.cast());
    malloc.free(nativeName);
  }

  void setGlobal(String name) {
    final nativeName = 'dartprint'.toNativeUtf8();
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

      results.add(getValue(stackIndex));
    }

    bindings.flua_set_top(_state, pretop); // TODO: is this the way?

    return results;
  }

  LuaType type(int idx) {
    _checkValid();

    final type = bindings.flua_type(_state, idx);
    return _types[type] ?? LuaType.unknown;
  }

  Object? getValue(int idx) {
    _checkValid();

    switch (type(idx)) {
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
        final ref = bindings.flua_ref(_state, bindings.FLUA_REGISTRYINDEX);
        return LuaFunction(ref, this);
      case LuaType.lightuserdata:
        return const LuaLightUserData();
      case LuaType.userdata:
        return const LuaUserData();
      case LuaType.thread:
        return const LuaThread();
      case LuaType.unknown:
        // TODO: LuaUnknown?
        throw LuaException('Unknown lua type.');
    }
  }

  Map<Object?, Object?> _traverseTable(int idx) {
    final result = {};
    // TODO: checkstack

    bindings.flua_push_nil(_state);
    // TODO: assumes negative idx // TODO: so convert to abs idx?
    while (bindings.flua_next(_state, idx - 1) != 0) {
      result[getValue(-2)] = getValue(-1);

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
