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

class LuaState {
  final bindings.flua_State _state;
  final _finalizer = Finalizer<bindings.flua_State>(_nativeClose);

  bool get _isValid => _state.address != 0;

  void _checkValid() {
    if (!_isValid) {
      throw LuaException('Lua state has been closed');
    }
  }

  LuaState() : _state = bindings.flua_create() {
    if (_state.address == 0) {
      throw LuaException('Failed to create Lua state');
    }
    _finalizer.attach(this, _state);
  }

  static void _nativeClose(bindings.flua_State ptr) {
    if (ptr.address != 0) {
      bindings.flua_close(ptr);
    }
  }

  bool get isClosed => !_isValid;

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

  dynamic operator [](String name) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      final type = LuaType.fromValue(
        bindings.flua_get_global_type(_state, nativeName.cast()),
      ); // TODO: getting type and then value? not at once?
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

  void operator []=(String name, dynamic value) {
    _checkValid();
    final nativeName = name.toNativeUtf8();
    try {
      if (value == null) {
        bindings.flua_set_global_nil(_state, nativeName.cast());
      } else if (value is bool) {
        bindings.flua_set_global_bool(_state, nativeName.cast(), value ? 1 : 0);
      } else if (value is int) {
        bindings.flua_set_global_int(_state, nativeName.cast(), value);
      } else if (value is double) {
        bindings.flua_set_global_double(_state, nativeName.cast(), value);
      } else if (value is num) {
        bindings.flua_set_global_double(
          _state,
          nativeName.cast(),
          value.toDouble(),
        );
      } else if (value is String) {
        final nativeValue = value.toNativeUtf8();
        try {
          bindings.flua_set_global_string(
            _state,
            nativeName.cast(),
            nativeValue.cast(),
          );
        } finally {
          malloc.free(nativeValue);
        }
      } else {
        throw LuaException('Unsupported type: ${value.runtimeType}');
      }
    } finally {
      malloc.free(nativeName);
    }
  }

  List<dynamic> call(String funcName, [List<dynamic> args = const []]) {
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

      final results = _popResults(pretop);
      if (results.isNotEmpty) {
        bindings.flua_pop(_state, results.length);
      }
      return results;
    } finally {
      malloc.free(nativeName);
    }
  }

  void _pushValue(dynamic value) {
    if (value == null) {
      bindings.flua_push_nil(_state);
    } else if (value is bool) {
      bindings.flua_push_bool(_state, value ? 1 : 0);
    } else if (value is int) {
      bindings.flua_push_int(_state, value);
    } else if (value is double) {
      bindings.flua_push_double(_state, value);
    } else if (value is String) {
      final nativeValue = value.toNativeUtf8();
      try {
        bindings.flua_push_string(_state, nativeValue.cast());
      } finally {
        malloc.free(nativeValue);
      }
    } else {
      // TODO: ???
    }
  }

  List<dynamic> _popResults(int pretop) {
    final count = bindings.flua_gettop(_state) - pretop;
    final results = <dynamic>[];
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
    return results;
  }
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
